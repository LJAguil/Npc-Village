extends CharacterBody3D
## Player: WASD / arrow keys to move, Space to jump, E to interact with
## whatever is closest (villagers, farm tiles, the pond, the market, your bed).
## Q cycles which seed you plant. Right-mouse drag rotates the camera.

const SPEED := 5.0
const JUMP_VELOCITY := 7.0
const GRAVITY := 20.0
const SPAWN := Vector3(0, 1, 21)
const VISUAL_SCRIPT := preload("res://scripts/character_visual.gd")

var hud: CanvasLayer
var game: Node   # main.gd

var visual: Node3D
var cam_pivot: Node3D
var camera: Camera3D
var cam_yaw := 0.0
var footsteps: AudioStreamPlayer
var was_on_floor := true

var busy := false            # fishing, sleeping, shopping... (can't move)
var fixed_camera := false    # inside a house: a fixed room camera, no camera turning
var controls_enabled := false   # off on the title screen
var talking_to: CharacterBody3D = null
var talk_lines: Array = []
var talk_index := 0
var focus: Node = null       # the interactable currently in range
var held_fish: Node3D
var held_timer := 0.0


func _ready() -> void:
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 1.8
	col.shape = shape
	add_child(col)

	visual = Node3D.new()
	visual.set_script(VISUAL_SCRIPT)
	add_child(visual)
	visual.setup(-1.0, "")   # the original purple robot

	# Camera rig: pivot rotates around the player; camera sits behind & above.
	cam_pivot = Node3D.new()
	cam_pivot.top_level = true   # don't inherit player rotation
	add_child(cam_pivot)
	camera = Camera3D.new()
	camera.position = Vector3(0, 6, 9)
	camera.rotation_degrees.x = -30
	cam_pivot.add_child(camera)

	footsteps = Audio.make_footsteps_player()
	add_child(footsteps)


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled:
		return
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not fixed_camera:
		cam_yaw -= event.relative.x * 0.005

	if busy:
		return
	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		if talking_to:
			_advance_dialogue()
		elif focus and focus.get_prompt(self) != "":
			focus.interact(self)
	elif event.is_action_pressed("gift") and talking_to == null:
		if focus and focus.has_method("receive_gift") and focus.can_receive_gift():
			get_viewport().set_input_as_handled()
			game.panels.open_gift(focus)
	elif event.is_action_pressed("journal") and talking_to == null:
		get_viewport().set_input_as_handled()
		game.panels.open_journal()
	elif event.is_action_pressed("bag") and talking_to == null:
		get_viewport().set_input_as_handled()
		game.panels.open_bag()
	elif event.is_action_pressed("map") and talking_to == null:
		get_viewport().set_input_as_handled()
		game.everyday.show_map()
	elif event.is_action_pressed("cycle_seed") and talking_to == null:
		Game.cycle_seed()
		Audio.play("click")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var input := Vector2.ZERO
	var can_move := controls_enabled and talking_to == null and not busy
	if can_move:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY
			Audio.play("jump", 0.1, -6.0)

	# Move relative to the camera direction
	var dir := Vector3(input.x, 0, input.y).rotated(Vector3.UP, cam_yaw)
	if dir.length() > 0.01:
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-dir.x, -dir.z), 0.25)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	_slide_off_characters()
	visual.animate_from_velocity(velocity, is_on_floor(), SPEED * 0.8)

	# Sounds: footsteps while walking, a thud when landing
	var walking := is_on_floor() and Vector2(velocity.x, velocity.z).length() > 0.5
	if walking and not footsteps.playing:
		footsteps.play()
	elif not walking and footsteps.playing:
		footsteps.stop()
	if is_on_floor() and not was_on_floor:
		Audio.play("land", 0.1, -8.0)
	was_on_floor = is_on_floor()

	# Safety net: if something ever launches or drops the player, put them back.
	if global_position.y < -10.0 or global_position.y > 30.0:
		global_position = SPAWN
		velocity = Vector3.ZERO

	cam_pivot.global_position = global_position
	cam_pivot.rotation.y = cam_yaw
	# Keep the camera above the hills when you walk near the edge of the village
	camera.position = Vector3(0, 6, 9)
	var ground: float = game.scenery.height_at(camera.global_position.x, camera.global_position.z)
	if camera.global_position.y < ground + 2.0:
		camera.global_position.y = ground + 2.0

	if held_timer > 0.0:
		held_timer -= delta
		if held_timer <= 0.0 and held_fish:
			held_fish.queue_free()
			held_fish = null

	_update_focus()


## Finds the closest thing to interact with and shows its prompt.
func _update_focus() -> void:
	if not controls_enabled or busy:
		return
	if talking_to:
		if global_position.distance_to(talking_to.global_position) > 5.0:
			_end_dialogue()
		return
	focus = null
	var best := INF
	for node in get_tree().get_nodes_in_group("interactable"):
		var d: float = node.distance_to_player(self)
		var r: float = node.interact_range
		if d < r and d / r < best and node.get_prompt(self) != "":
			best = d / r
			focus = node
	hud.show_prompt(focus.get_prompt(self) if focus else "")


# ---------------------------------------------------------------- dialogue

func start_dialogue(npc: CharacterBody3D) -> void:
	talking_to = npc
	talk_lines = npc.start_player_talk(self)
	talk_index = 0
	Game.time_running = false
	var to := npc.global_position - global_position
	visual.rotation.y = atan2(-to.x, -to.z)
	hud.show_prompt("")
	Audio.play("click", 0.1, -6.0)
	_show_current_line()


## Show some lines from a villager without their normal conversation
## (used for gift reactions).
func start_dialogue_lines(npc: CharacterBody3D, lines: Array) -> void:
	talking_to = npc
	talk_lines = lines
	talk_index = 0
	npc.state = npc.State.TALKING
	npc.pending_action = ""
	Game.time_running = false
	var to := npc.global_position - global_position
	visual.rotation.y = atan2(-to.x, -to.z)
	hud.show_prompt("")
	_show_current_line()


func _advance_dialogue() -> void:
	talk_index += 1
	Audio.play("click", 0.1, -10.0)
	if talk_index >= talk_lines.size():
		_end_dialogue()
	else:
		_show_current_line()


func _show_current_line() -> void:
	var line: String = talk_lines[talk_index]
	talking_to.say(line, 999.0)
	hud.show_dialogue(talking_to.npc_name, line, talk_index == talk_lines.size() - 1, Game.hearts(talking_to.npc_name))


func _end_dialogue() -> void:
	var npc := talking_to
	talking_to = null
	hud.hide_dialogue()
	Game.time_running = true
	if npc:
		npc.end_player_talk()


# ---------------------------------------------------------------- little helpers

func face_direction(dir: Vector3) -> void:
	visual.rotation.y = atan2(-dir.x, -dir.z)


## A small hop used as feedback for farming actions.
func play_action_bounce() -> void:
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(1.1, 0.85, 1.1), 0.08)
	tw.tween_property(visual, "scale", Vector3.ONE, 0.12)


## Holds a freshly caught fish over your head for a moment.
func show_held_fish(fish_id: String) -> void:
	if held_fish:
		held_fish.queue_free()
	held_fish = Node3D.new()
	var colors := {"minnow": Color(0.7, 0.75, 0.8), "perch": Color(0.6, 0.7, 0.3), "bass": Color(0.35, 0.5, 0.3),
		"catfish": Color(0.45, 0.4, 0.35), "golden_carp": Color(1, 0.8, 0.2),
		"sardine": Color(0.65, 0.75, 0.85), "mackerel": Color(0.3, 0.5, 0.6), "pufferfish": Color(0.9, 0.8, 0.45),
		"swordfish": Color(0.35, 0.4, 0.6), "moonfish": Color(0.85, 0.9, 1.0),
		"trout": Color(0.6, 0.55, 0.5), "eel": Color(0.25, 0.3, 0.2), "squid": Color(0.9, 0.6, 0.65), "tuna": Color(0.25, 0.3, 0.45)}
	var sizes := {"minnow": 0.35, "perch": 0.5, "bass": 0.65, "catfish": 0.8, "golden_carp": 0.75,
		"sardine": 0.4, "mackerel": 0.6, "pufferfish": 0.55, "swordfish": 1.2, "moonfish": 0.85,
		"trout": 0.6, "eel": 1.0, "squid": 0.6, "tuna": 1.1}
	var body := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	body.mesh = s
	var flen: float = sizes.get(fish_id, 0.5)
	body.scale = Vector3(flen, flen * 0.45, flen * 0.25)
	var m := StandardMaterial3D.new()
	m.albedo_color = colors.get(fish_id, Color.GRAY)
	if fish_id == "moonfish":
		m.emission_enabled = true
		m.emission = Color(0.6, 0.75, 1.0)
		m.emission_energy_multiplier = 1.2
	if fish_id == "pufferfish":
		body.scale = Vector3(flen, flen * 0.9, flen * 0.9)   # puffed up!
	if fish_id == "eel":
		body.scale = Vector3(flen, flen * 0.14, flen * 0.12)  # long and thin
	if fish_id == "golden_carp":
		m.emission_enabled = true
		m.emission = Color(1, 0.7, 0.1)
		m.emission_energy_multiplier = 0.6
	body.material_override = m
	held_fish.add_child(body)
	var tail := MeshInstance3D.new()
	var p := PrismMesh.new()
	p.size = Vector3(0.3, 0.25, 0.05)
	tail.mesh = p
	tail.rotation.z = PI / 2
	tail.position.x = -flen * 0.55
	tail.material_override = m
	held_fish.add_child(tail)
	held_fish.position = Vector3(0, 1.3, 0)
	add_child(held_fish)
	held_timer = 2.5


## If we're standing on top of another character, slide off sideways.
func _slide_off_characters() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var other := c.get_collider()
		if other is CharacterBody3D and c.get_normal().y > 0.3:
			var away: Vector3 = global_position - other.global_position
			away.y = 0.0
			if away.length() < 0.01:
				away = Vector3(randf() - 0.5, 0.0, randf() - 0.5)
			global_position += away.normalized() * 0.1
