extends CharacterBody3D
## Your puppy. Before you adopt it, it waits by your front door. Afterwards it
## follows you everywhere (even into houses), sits when you stop, wags its tail,
## and plays fetch. Press E on it to open the pet menu (pet / feed / fetch).
## Its care stats live in Game.pet() so they're saved.

enum S { WAITING, FOLLOW, SIT, FETCH_READY, FETCH_GO, FETCH_BACK, ROAM, HOME }

const WALK := 3.2
const RUN := 6.5
const GRAVITY := 20.0

var world: Node3D           # main.gd
var state := S.WAITING
var interact_range := 1.4   # small, so the pup doesn't steal E from things you're standing at
var t := 0.0
var bark_timer := 6.0
var throws_left := 0
var ball: MeshInstance3D
var ball_target := Vector3.ZERO
var ball_flying := false

var wander_target := Vector3.INF
var wander_timer := 0.0
var stuck_t := 0.0
var detour := Vector3.ZERO
var detour_t := 0.0
var last_pos := Vector3.ZERO

var body_root: Node3D
var legs: Array = []
var tail: Node3D
var head: Node3D


func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 2     # the player and villagers walk through the puppy
	collision_mask = 1
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.25
	shape.height = 0.7
	col.shape = shape
	col.position.y = 0.35
	add_child(col)
	_build_model()


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _box(parent: Node3D, pos: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi


func _build_model() -> void:
	var fur := Color(0.85, 0.62, 0.32)
	var light := Color(0.98, 0.9, 0.75)
	var dark := Color(0.35, 0.22, 0.12)
	body_root = Node3D.new()
	add_child(body_root)
	_box(body_root, Vector3(0, 0.42, 0), Vector3(0.36, 0.3, 0.62), fur)
	_box(body_root, Vector3(0, 0.36, -0.05), Vector3(0.3, 0.12, 0.5), light)
	head = Node3D.new()
	head.position = Vector3(0, 0.62, -0.36)
	body_root.add_child(head)
	_box(head, Vector3.ZERO, Vector3(0.32, 0.3, 0.3), fur)
	_box(head, Vector3(0, -0.05, -0.2), Vector3(0.18, 0.14, 0.16), light)
	_box(head, Vector3(0, -0.01, -0.29), Vector3(0.08, 0.06, 0.04), Color(0.1, 0.08, 0.08))   # nose
	for x in [-0.08, 0.08]:
		_box(head, Vector3(x, 0.05, -0.155), Vector3(0.05, 0.06, 0.02), Color(0.1, 0.08, 0.08))   # eyes
		var ear := _box(head, Vector3(x * 1.9, 0.08, 0.02), Vector3(0.08, 0.2, 0.14), dark)
		ear.rotation.z = -0.35 if x < 0 else 0.35
	_box(head, Vector3(0, -0.12, -0.1), Vector3(0.12, 0.03, 0.06), Color(0.9, 0.35, 0.4)).name = "Tongue"
	for p in [Vector3(-0.11, 0, -0.2), Vector3(0.11, 0, -0.2), Vector3(-0.11, 0, 0.2), Vector3(0.11, 0, 0.2)]:
		var leg := Node3D.new()
		leg.position = p + Vector3(0, 0.3, 0)
		body_root.add_child(leg)
		_box(leg, Vector3(0, -0.15, 0), Vector3(0.1, 0.3, 0.1), fur)
		_box(leg, Vector3(0, -0.29, -0.02), Vector3(0.11, 0.04, 0.13), light)
		legs.append(leg)
	tail = Node3D.new()
	tail.position = Vector3(0, 0.52, 0.3)
	body_root.add_child(tail)
	var tb := _box(tail, Vector3(0, 0.1, 0.04), Vector3(0.07, 0.24, 0.07), fur)
	tb.rotation.x = 0.5
	# a little red collar once adopted
	var collar := _box(body_root, Vector3(0, 0.54, -0.26), Vector3(0.34, 0.06, 0.1), Color(0.85, 0.2, 0.2))
	collar.name = "Collar"
	collar.visible = false


func pet_name() -> String:
	return str(Game.pet().get("name", "Biscuit"))


func adopted() -> bool:
	return bool(Game.pet().get("adopted", false))


func refresh() -> void:
	body_root.get_node("Collar").visible = adopted()
	if adopted() and state in [S.WAITING, S.FOLLOW, S.SIT, S.ROAM, S.HOME]:
		state = mode_state()
	elif not adopted():
		state = S.WAITING


## "follow" (default), "home" (stays in your house) or "roam" (explores the village)
func mode() -> String:
	return str(Game.pet().get("mode", "follow"))


func mode_state() -> int:
	match mode():
		"home":
			return S.HOME
		"roam":
			return S.ROAM
	return S.FOLLOW


func set_mode(m: String) -> void:
	Game.pet()["mode"] = m
	state = mode_state()
	wander_target = Vector3.INF
	if m == "home" and world.interiors.current != "home":
		_go_home_now()


func _home_room() -> Dictionary:
	return world.interiors.houses["home"]


func _in_home_room() -> bool:
	var h := _home_room()
	return global_position.distance_to(h["origin"]) < 9.0


func _go_home_now() -> void:
	var h := _home_room()
	var sz: Vector2 = h["size"]
	global_position = (h["origin"] as Vector3) + Vector3(sz.x / 2 - 1.6, 0.3, 2.6)   # its bed
	velocity = Vector3.ZERO


# ---------------------------------------------------------------- interaction

func distance_to_player(player: Node3D) -> float:
	return Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()


func get_prompt(_player: Node3D) -> String:
	if not adopted():
		return "E: Say hi to the puppy"
	match state:
		S.FETCH_READY:
			return "E: Throw the ball! (%d left)" % throws_left
		S.FETCH_GO, S.FETCH_BACK:
			return ""
	return "E: %s  (pet, feed, play)" % pet_name()


func interact(_player: Node3D) -> void:
	if not adopted():
		world.panels.open_adopt(self)
		return
	if state == S.FETCH_READY:
		_throw()
		return
	world.panels.open_pet(self)


func show_hearts(n := 3) -> void:
	for i in n:
		var h := Node3D.new()
		var mat := _mat(Color(1, 0.4, 0.55))
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for x in [-0.05, 0.05]:
			var s := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.06
			sm.height = 0.12
			s.mesh = sm
			s.position = Vector3(x, 0, 0)
			s.material_override = mat
			h.add_child(s)
		var tip := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.2, 0.12, 0.05)
		tip.mesh = pm
		tip.rotation.z = PI
		tip.position.y = -0.07
		tip.material_override = mat
		h.add_child(tip)
		add_child(h)
		h.position = Vector3(randf_range(-0.3, 0.3), 1.0, randf_range(-0.2, 0.2))
		var tw := h.create_tween().set_parallel(true)
		tw.tween_property(h, "position:y", 1.8, 1.2).set_delay(i * 0.15)
		tw.tween_property(h, "scale", Vector3.ONE * 0.2, 1.2).set_delay(i * 0.15)
		tw.chain().tween_callback(h.queue_free)


# ---------------------------------------------------------------- fetch

func start_fetch() -> void:
	if global_position.distance_to(world.player.global_position) > 14.0:
		_teleport_near(world.player)
	throws_left = 3
	state = S.FETCH_READY
	world.hud.show_toast("%s is ready! Face where you want to throw and press E." % pet_name(), 3.5)
	Audio.play("bark")


func _throw() -> void:
	var p: CharacterBody3D = world.player
	var fwd := Vector3(-sin(p.visual.rotation.y), 0, -cos(p.visual.rotation.y))
	var dist := 3.2 if world.interiors.current != "" else 9.0
	var target := p.global_position + fwd * dist
	target.y = p.global_position.y - 0.85
	if world.interiors.current == "":
		# keep the ball inside the village and out of buildings
		for k in 12:
			var flat := Vector2(target.x, target.z)
			if flat.length() < 27.0 and world.is_clear(target, 0.4) and not world.scenery.is_sand(target):
				break
			target = p.global_position + fwd * dist * (1.0 - (k + 1) * 0.08)
			target.y = p.global_position.y - 0.85
	ball = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.2
	ball.mesh = sm
	ball.material_override = _mat(Color(0.95, 0.3, 0.25))
	world.add_child(ball)
	ball.global_position = p.global_position + Vector3(0, 0.6, 0)
	ball_target = target + Vector3(0, 0.1, 0)
	ball_flying = true
	var start := ball.global_position
	var tw := ball.create_tween()
	tw.tween_method(func(k: float):
		if is_instance_valid(ball):
			ball.global_position = start.lerp(ball_target, k) + Vector3(0, sin(k * PI) * 2.0, 0), 0.0, 1.0, 0.8)
	tw.tween_callback(func(): ball_flying = false)
	p.play_action_bounce()
	Audio.play("cast", 0.1)
	state = S.FETCH_GO


func _catch_ball() -> void:
	if not is_instance_valid(ball):
		return
	ball.get_parent().remove_child(ball)
	head.add_child(ball)
	ball.position = Vector3(0, -0.1, -0.25)
	state = S.FETCH_BACK


func _drop_ball() -> void:
	if is_instance_valid(ball):
		ball.queue_free()
	ball = null
	throws_left -= 1
	show_hearts(2)
	Audio.play("bark")
	if throws_left > 0:
		state = S.FETCH_READY
		return
	state = mode_state()
	var p := Game.pet()
	if int(p.get("played_day", -1)) != Game.day:
		p["played_day"] = Game.day
		p["happiness"] = clampi(int(p.get("happiness", 50)) + 15, 0, 100)
		world.hud.show_toast("%s had the best time playing fetch! (+happiness)" % pet_name(), 3.5)
	else:
		world.hud.show_toast("%s wants to play again tomorrow!" % pet_name(), 3.0)


# ---------------------------------------------------------------- movement

func _physics_process(delta: float) -> void:
	t += delta
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	var p: CharacterBody3D = world.player if world else null
	var moving := false
	if p == null or world.in_title:
		_stop()
	else:
		var to := p.global_position - global_position
		to.y = 0.0
		var d := to.length()
		match state:
			S.WAITING:
				_stop()
				if d < 5.0:
					_face(p.global_position)
			S.FOLLOW, S.SIT, S.FETCH_READY:
				if d > 14.0:
					# you went somewhere far (a house, the other end of the village) -- catch up
					_teleport_near(p)
				elif d > 2.4 and state != S.FETCH_READY:
					moving = true
					state = S.FOLLOW if state != S.SIT or d > 3.2 else S.SIT
					if state == S.FOLLOW:
						_move(to / d, RUN if d > 5.0 else WALK, delta, p.global_position)
						_face(p.global_position)
					else:
						moving = false
						_stop()
				else:
					_stop()
					_face(p.global_position)
					if state == S.FOLLOW:
						state = S.SIT
			S.HOME:
				if world.interiors.current == "home":
					# you're home: come and say hi, then hang around you
					if d > 14.0:
						_go_home_now()
					elif d > 2.4:
						moving = true
						_move(to / d, WALK, delta, p.global_position)
						_face(p.global_position)
					else:
						_stop()
						_face(p.global_position)
				else:
					if not _in_home_room():
						_go_home_now()
					moving = _wander(delta, true)
			S.ROAM:
				if _in_home_room() and world.interiors.current != "home":
					global_position = world.PLAYER_HOUSE + Vector3(1.8, 0.3, -3.8)
				moving = _wander(delta, false)
				if d < 3.0 and world.interiors.current == "":
					_face(p.global_position)
			S.FETCH_GO:
				if not ball_flying and is_instance_valid(ball):
					var tb := ball.global_position - global_position
					tb.y = 0.0
					if tb.length() < 0.5:
						_catch_ball()
					else:
						moving = true
						_move(tb.normalized(), RUN, delta, ball.global_position)
						_face(ball.global_position)
				else:
					_stop()
			S.FETCH_BACK:
				if d > 14.0:
					_teleport_near(p)
				elif d < 1.3:
					_drop_ball()
				else:
					moving = true
					_move(to / d, RUN, delta, p.global_position)
					_face(p.global_position)
	move_and_slide()
	_animate(moving, delta)
	if adopted():
		bark_timer -= delta
		if bark_timer <= 0.0:
			bark_timer = randf_range(20.0, 45.0)
			if p and p.global_position.distance_to(global_position) < 10.0:
				Audio.play("bark", 0.1, -8.0)


func _teleport_near(p: Node3D) -> void:
	var back := Vector3(sin(p.visual.rotation.y), 0, cos(p.visual.rotation.y))
	global_position = p.global_position + back * 1.2
	velocity = Vector3.ZERO
	stuck_t = 0.0


## Walk toward goal, steering around trees, rocks and buildings. If the pup
## still gets stuck it hops and sidesteps, and after a few seconds it just
## finds its way there (so it never stays stuck behind a rock).
func _move(dir: Vector3, speed: float, delta := 0.016, goal := Vector3.INF) -> void:
	var d := _steer(dir)
	if detour_t > 0.0:
		detour_t -= delta
		d = (d + detour * 1.5).normalized()
	velocity.x = d.x * speed
	velocity.z = d.z * speed
	# stuck check: are we actually getting anywhere?
	var moved := Vector2(global_position.x - last_pos.x, global_position.z - last_pos.z).length()
	last_pos = global_position
	if moved < speed * delta * 0.25:
		stuck_t += delta
	else:
		stuck_t = max(stuck_t - delta * 2.0, 0.0)
	if stuck_t > 0.6 and detour_t <= 0.0:
		detour = Vector3(-dir.z, 0, dir.x) * (1.0 if randf() < 0.5 else -1.0)
		detour_t = 0.8
		if is_on_floor():
			velocity.y = 5.0
	if stuck_t > 2.5 and goal != Vector3.INF:
		var back := (global_position - goal)
		back.y = 0.0
		global_position = goal + (back.normalized() if back.length() > 0.01 else Vector3.RIGHT) * 0.8
		global_position.y = goal.y + 0.3 if goal.y > -5.0 else global_position.y
		stuck_t = 0.0
		detour_t = 0.0


func _steer(dir: Vector3) -> Vector3:
	if global_position.x < -300.0:
		return dir     # inside a house: no landmarks there
	var out := dir
	for lm in world.landmarks:
		var to_lm: Vector3 = (lm["pos"] as Vector3) - global_position
		to_lm.y = 0.0
		var dist := to_lm.length()
		var r: float = lm["radius"] + 0.5
		if dist > r + 2.5 or dist < 0.01:
			continue
		var ahead := to_lm.dot(dir)
		if ahead <= 0.0:
			continue
		var lateral := (to_lm - dir * ahead).length()
		if lateral < r:
			var side := Vector3(-dir.z, 0, dir.x)
			if side.dot(to_lm) > 0.0:
				side = -side
			out += side * (1.0 - lateral / r) * 1.6
	return out.normalized()


## Potter about: pick a spot, walk there, sniff around, pick another.
func _wander(delta: float, indoors: bool) -> bool:
	wander_timer -= delta
	if wander_target == Vector3.INF or wander_timer <= 0.0:
		wander_timer = randf_range(4.0, 8.0)
		if indoors:
			var h := _home_room()
			var sz: Vector2 = h["size"]
			wander_target = (h["origin"] as Vector3) + Vector3(randf_range(-sz.x / 2 + 1.0, sz.x / 2 - 1.0), 0, randf_range(-sz.y / 2 + 1.2, sz.y / 2 - 1.5))
		elif Game.is_night():
			wander_target = world.PLAYER_HOUSE + Vector3(1.8, 0, -3.8)   # sleeps by your door at night
		else:
			for k in 20:
				var a := randf() * TAU
				var q := Vector3(cos(a), 0, sin(a)) * randf_range(4.0, 25.0)
				if world.is_clear(q, 1.0) and not world.scenery.is_sand(q):
					wander_target = q
					break
	var to := wander_target - global_position
	to.y = 0.0
	if to.length() < 0.6:
		_stop()
		return false
	_move(to.normalized(), WALK * 0.8, delta, wander_target)
	_face(global_position + to)
	return true


func _stop() -> void:
	velocity.x = move_toward(velocity.x, 0.0, 0.8)
	velocity.z = move_toward(velocity.z, 0.0, 0.8)


func _face(pos: Vector3) -> void:
	var to := pos - global_position
	if Vector2(to.x, to.z).length() > 0.05:
		body_root.rotation.y = lerp_angle(body_root.rotation.y, atan2(-to.x, -to.z), 0.2)


func _animate(moving: bool, _delta: float) -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var happy := float(Game.pet().get("happiness", 50)) / 100.0
	tail.rotation.y = sin(t * (10.0 + happy * 10.0)) * (0.3 + happy * 0.5)
	if moving and speed > 0.3:
		var ph := t * (8.0 + speed * 2.0)
		for i in legs.size():
			legs[i].rotation.x = sin(ph + (PI if i % 3 == 0 else 0.0)) * 0.6
		body_root.position.y = abs(sin(ph)) * 0.04
		body_root.rotation.x = 0.0
		head.rotation.x = 0.0
	else:
		for leg in legs:
			leg.rotation.x = 0.0
		body_root.position.y = 0.0
		var sitting := state == S.SIT or state == S.WAITING
		body_root.rotation.x = lerpf(body_root.rotation.x, -0.25 if sitting else 0.0, 0.1)
		head.rotation.x = sin(t * 1.5) * 0.08
	var tongue := head.get_node_or_null("Tongue")
	if tongue:
		tongue.visible = speed > 3.0 or happy > 0.7
