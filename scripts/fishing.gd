extends Node3D
const UI := preload("res://scripts/ui_style.gd")
## Fishing: cast -> wait for a bite -> press to hook -> timing-bar minigame.
## In "simple" mode (pause menu > Fishing style) there's no minigame: hooking
## the fish in time catches it. Rarer fish give you less time to react.
##
## Minigame: hold Space / E / left-click to lift the green bar, let go to let
## it fall. Keep the fish inside the green bar to fill the catch meter.
## Harder fish dart around more. The Better Rod makes the green bar bigger.

enum Phase { NONE, CAST, WAIT, BITE, REEL }

const BAR_HEIGHT := 320.0
const FISH_SIZE := 22.0
# Difficulty tuning (fish difficulty 0..1 blends between the MIN and MAX values)
const ZONE_BASIC := 95.0
const ZONE_BETTER_ROD := 108.0
const ZONE_MASTER_ROD := 125.0   # ...and with the Master Rod
const FISH_SPEED_MIN := 35.0
const FISH_SPEED_MAX := 380.0
const FISH_JUMP_MIN := 0.15      # how far (fraction of the bar) the fish darts
const FISH_JUMP_MAX := 0.85

var game_world: Node   # main.gd
var player: CharacterBody3D
var phase := Phase.NONE
var timer := 0.0
var fish: Dictionary = {}
var water := "pond"      # "pond" or "ocean" -- decides which fish can bite
var from_dock := false

# 3D bits
var bobber: Node3D
var line_mesh: MeshInstance3D
var line_im: ImmediateMesh
var rod: Node3D
var cast_from := Vector3.ZERO
var cast_to := Vector3.ZERO
var bob_t := 0.0
var exclaim: Label3D

# minigame state (pixels, measured up from the bottom of the bar)
var zone_pos := 0.0
var zone_vel := 0.0
var zone_size := 80.0
var fish_pos := 0.0
var fish_target := 0.0
var fish_timer := 0.0
var progress := 0.3
var tick_timer := 0.0

# minigame UI
var ui_layer: CanvasLayer
var panel: PanelContainer
var bar_bg: ColorRect
var zone_rect: ColorRect
var fish_rect: ColorRect
var meter_fill: ColorRect
var fish_label: Label


func _ready() -> void:
	_build_3d()
	_build_ui()


func is_active() -> bool:
	return phase != Phase.NONE


## Called when the player presses E at the water's edge. target = where the
## bobber lands; water = "pond" or "ocean"; dock = fishing off the end of the dock.
func start(p: CharacterBody3D, target: Vector3, which_water := "pond", dock := false) -> void:
	player = p
	water = which_water
	from_dock = dock
	var to_target := target - player.global_position
	to_target.y = 0
	var dir := to_target.normalized()
	player.face_direction(dir)
	player.busy = true
	cast_to = target
	cast_from = player.global_position + Vector3(0, 1.4, 0) + dir * 0.6
	_attach_rod()
	phase = Phase.CAST
	timer = 0.0
	Audio.play("cast")


func _process(delta: float) -> void:
	match phase:
		Phase.NONE:
			return
		Phase.CAST:
			timer += delta
			var k: float = min(timer / 0.55, 1.0)
			bobber.visible = true
			bobber.global_position = cast_from.lerp(cast_to, k) + Vector3(0, sin(k * PI) * 2.0, 0)
			if k >= 1.0:
				Audio.play("splash", 0.1, -8.0)
				phase = Phase.WAIT
				timer = randf_range(2.5, 7.0) * (0.5 if Game.upgrades.get("lure", false) else 1.0)
				game_world.hud.show_prompt("Waiting for a bite...  (E to reel in)")
		Phase.WAIT:
			timer -= delta
			bob_t += delta
			bobber.global_position = cast_to + Vector3(0, sin(bob_t * 2.5) * 0.03, 0)
			if timer <= 0.0:
				phase = Phase.BITE
				fish = _pick_fish()
				timer = simple_window(fish) if Game.fishing_mode == "simple" else 1.2
				exclaim.visible = true
				Audio.play("bite")
				game_world.hud.show_prompt("!!  Press SPACE / E now!" if Game.fishing_mode == "simple" else "!!  Press SPACE / E to hook it!")
		Phase.BITE:
			timer -= delta
			bob_t += delta * 6.0
			bobber.global_position = cast_to + Vector3(0, -0.12 + sin(bob_t * 3.0) * 0.06, 0)
			if timer <= 0.0:
				_finish(false, "It got away before you could hook it...")
		Phase.REEL:
			_run_minigame(delta)
	_draw_line()


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.NONE:
		return
	if event.is_action_pressed("reel") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		match phase:
			Phase.WAIT:
				_finish(false, "")
			Phase.BITE:
				if Game.fishing_mode == "simple":
					_catch()
				else:
					_start_minigame()


# ------------------------------------------------------------------ fish choice

func _pick_fish() -> Dictionary:
	var h := Game.hour()
	if h < 6:
		h += 24
	var options: Array = Game.FISH.filter(func(f): return h >= f["hours"][0] and h < f["hours"][1] \
		and f["water"] == water and (from_dock or not f.get("dock", false)))
	var total := 0.0
	for f in options:
		total += _weight(f)
	var r := randf() * total
	for f in options:
		r -= _weight(f)
		if r <= 0.0:
			return f
	return options[0]


func _weight(f: Dictionary) -> float:
	var w: float = f["weight"]
	if Game.upgrades.get("lure", false) and f["difficulty"] >= 0.6:
		w *= 2.0
	if Game.upgrades.get("master_rod", false) and f["difficulty"] >= 0.9:
		w *= 2.0
	return w


# ------------------------------------------------------------------ minigame

func _start_minigame() -> void:
	phase = Phase.REEL
	exclaim.visible = false
	zone_size = ZONE_BASIC
	if Game.upgrades.get("master_rod", false):
		zone_size = ZONE_MASTER_ROD
	elif Game.upgrades.get("rod", false):
		zone_size = ZONE_BETTER_ROD
	zone_pos = 0.0
	zone_vel = 0.0
	fish_pos = BAR_HEIGHT * 0.3
	fish_target = fish_pos
	fish_timer = 0.0
	progress = 0.3
	zone_rect.size = Vector2(40, zone_size)
	fish_label.text = "Something BIG is pulling!" if fish.get("style", "") == "strong" else "Something is on the line!"
	panel.visible = true
	UI.pop_in(panel)
	game_world.hud.show_prompt("Hold SPACE / E / click to raise the green bar")


func _run_minigame(delta: float) -> void:
	var holding := Input.is_action_pressed("reel") or Input.is_action_pressed("interact")
	# Green bar: rises while holding, falls when released, bounces softly at the ends
	zone_vel += (900.0 if holding else -800.0) * delta
	zone_vel = clamp(zone_vel, -420.0, 420.0)
	zone_pos += zone_vel * delta
	if zone_pos < 0.0:
		zone_pos = 0.0
		zone_vel = -zone_vel * 0.3
	elif zone_pos > BAR_HEIGHT - zone_size:
		zone_pos = BAR_HEIGHT - zone_size
		zone_vel = -zone_vel * 0.3

	# Fish: picks a new spot every so often; harder fish move farther and faster
	var diff: float = fish["difficulty"]
	fish_timer -= delta
	if fish_timer <= 0.0:
		fish_timer = randf_range(0.4, 1.6) * (1.2 - diff)
		var jump: float = BAR_HEIGHT * lerpf(FISH_JUMP_MIN, FISH_JUMP_MAX, diff)
		fish_target = clamp(fish_pos + randf_range(-jump, jump), 0.0, BAR_HEIGHT - FISH_SIZE)
		if fish.get("style", "") == "dart" and randf() < 0.3:
			# pufferfish: a sudden panicked dart
			fish_pos = lerpf(fish_pos, fish_target, 0.7)
	fish_pos = move_toward(fish_pos, fish_target, lerpf(FISH_SPEED_MIN, FISH_SPEED_MAX, diff) * delta)

	# Catch meter
	var fish_center := fish_pos + FISH_SIZE * 0.5
	var inside := fish_center >= zone_pos and fish_center <= zone_pos + zone_size
	var drain := 0.3 if fish.get("style", "") == "strong" else 0.2
	progress += (0.3 if inside else -drain) * delta
	tick_timer -= delta
	if inside and tick_timer <= 0.0:
		tick_timer = 0.12
		Audio.play("reel", 0.1, -10.0)

	# Update UI (Control y grows downward, so flip)
	zone_rect.position.y = BAR_HEIGHT - zone_pos - zone_size
	zone_rect.color = Color(0.3, 0.9, 0.4, 0.85) if inside else Color(0.3, 0.75, 0.4, 0.55)
	fish_rect.position.y = BAR_HEIGHT - fish_pos - FISH_SIZE
	meter_fill.size.y = BAR_HEIGHT * clamp(progress, 0.0, 1.0)
	meter_fill.position.y = BAR_HEIGHT - meter_fill.size.y
	meter_fill.color = Color(1, 0.3, 0.2).lerp(Color(0.3, 1, 0.4), clamp(progress, 0.0, 1.0))

	bob_t += delta * 8.0
	bobber.global_position = cast_to + Vector3(sin(bob_t) * 0.1, -0.08, cos(bob_t * 0.7) * 0.1)

	if progress >= 1.0:
		_catch()
	elif progress <= 0.0:
		_finish(false, "The fish got away...")


## Simple mode: how long you have to react to a bite. Easy fish give you
## 1.3 s, the legendary ones about half a second.
func simple_window(f: Dictionary) -> float:
	return lerpf(1.3, 0.5, f["difficulty"])


func _catch() -> void:
	var id: String = fish["id"]
	Game.add_item(id)
	Game.fish_caught += 1
	Audio.play("catch")
	_finish(true, "You caught a %s!  (sells for %d)" % [Game.item_name(id), Game.ITEMS[id]["sell"]])


func _finish(caught: bool, message: String) -> void:
	if not caught and phase == Phase.REEL or message.begins_with("It got away"):
		Audio.play("fail")
	phase = Phase.NONE
	panel.visible = false
	bobber.visible = false
	exclaim.visible = false
	line_im.clear_surfaces()
	if rod:
		rod.queue_free()
		rod = null
	if player:
		player.busy = false
	game_world.hud.show_prompt("")
	if message != "":
		game_world.hud.show_toast(message, 3.0)
	if caught:
		player.show_held_fish(fish["id"])


# ------------------------------------------------------------------ building

func _build_3d() -> void:
	bobber = Node3D.new()
	var top := MeshInstance3D.new()
	var s1 := SphereMesh.new()
	s1.radius = 0.12
	s1.height = 0.24
	top.mesh = s1
	top.material_override = _mat(Color(0.9, 0.15, 0.15))
	top.position.y = 0.06
	bobber.add_child(top)
	var bottom := MeshInstance3D.new()
	var s2 := SphereMesh.new()
	s2.radius = 0.11
	s2.height = 0.14
	bottom.mesh = s2
	bottom.material_override = _mat(Color.WHITE)
	bobber.add_child(bottom)
	bobber.visible = false
	bobber.top_level = true
	add_child(bobber)

	line_im = ImmediateMesh.new()
	line_mesh = MeshInstance3D.new()
	line_mesh.mesh = line_im
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.95, 0.95, 0.95)
	line_mesh.material_override = lm
	line_mesh.top_level = true
	add_child(line_mesh)

	exclaim = Label3D.new()
	exclaim.text = "!"
	exclaim.font_size = 160
	exclaim.pixel_size = 0.006
	exclaim.outline_size = 24
	exclaim.modulate = Color(1, 0.9, 0.2)
	exclaim.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	exclaim.top_level = true
	exclaim.visible = false
	add_child(exclaim)


func _attach_rod() -> void:
	rod = Node3D.new()
	var stick := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.02
	cyl.bottom_radius = 0.04
	cyl.height = 1.6
	stick.mesh = cyl
	var rod_color := Color(0.5, 0.33, 0.18)
	if Game.upgrades.get("master_rod", false):
		rod_color = Color(0.95, 0.75, 0.2)
	elif Game.upgrades.get("rod", false):
		rod_color = Color(0.2, 0.3, 0.6)
	stick.material_override = _mat(rod_color)
	stick.position = Vector3(0, 0.8, 0)
	rod.add_child(stick)
	rod.position = Vector3(0.35, -0.1, -0.2)
	rod.rotation.x = -0.9
	player.visual.add_child(rod)


func _draw_line() -> void:
	line_im.clear_surfaces()
	if not bobber.visible or rod == null:
		return
	var tip: Vector3 = rod.to_global(Vector3(0, 1.6, 0))
	line_im.surface_begin(Mesh.PRIMITIVE_LINES)
	var prev := tip
	for i in range(1, 9):
		var k := i / 8.0
		var p := tip.lerp(bobber.global_position, k) - Vector3(0, sin(k * PI) * 0.3, 0)
		line_im.surface_add_vertex(prev)
		line_im.surface_add_vertex(p)
		prev = p
	line_im.surface_end()
	if exclaim.visible:
		exclaim.global_position = player.global_position + Vector3(0, 1.9, 0)


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 5
	add_child(ui_layer)
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -330
	panel.offset_right = -40
	panel.offset_top = -250
	panel.offset_bottom = 250
	panel.add_theme_stylebox_override("panel", UI.panel_style(Color(0.35, 0.6, 0.85)))
	ui_layer.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var head := UI.header("Reel it in!", "Keep the fish inside the green bar.", Color(0.25, 0.5, 0.75), "fish", Color(1, 0.65, 0.25))
	for c in head.get_children():
		if c is VBoxContainer:
			for l in c.get_children():
				if l is Label and l.get_theme_font_size("font_size") < 20:
					l.custom_minimum_size.x = 150
	vb.add_child(head)
	fish_label = UI.small_label("", UI.CREAM, 16)
	fish_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fish_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	fish_label.custom_minimum_size.x = 140
	vb.add_child(fish_label)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	vb.add_child(row)

	bar_bg = ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(40, BAR_HEIGHT)
	bar_bg.color = Color(0.16, 0.38, 0.62)
	bar_bg.clip_contents = true
	row.add_child(bar_bg)
	zone_rect = ColorRect.new()
	zone_rect.size = Vector2(40, 80)
	bar_bg.add_child(zone_rect)
	fish_rect = ColorRect.new()
	fish_rect.size = Vector2(28, FISH_SIZE)
	fish_rect.position.x = 6
	fish_rect.color = Color(1, 0.6, 0.15)
	bar_bg.add_child(fish_rect)
	var eye := ColorRect.new()
	eye.size = Vector2(4, 4)
	eye.position = Vector2(20, 6)
	eye.color = Color.BLACK
	fish_rect.add_child(eye)

	var meter_bg := ColorRect.new()
	meter_bg.custom_minimum_size = Vector2(14, BAR_HEIGHT)
	meter_bg.color = Color(0.1, 0.1, 0.1)
	row.add_child(meter_bg)
	meter_fill = ColorRect.new()
	meter_fill.size = Vector2(14, 0)
	meter_bg.add_child(meter_fill)
	vb.add_child(UI.hint_row(["SPACE", "E"], "hold to raise"))
	panel.visible = false


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m
