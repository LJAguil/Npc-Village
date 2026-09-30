extends Area3D
## A collectible quest item. Walk into it to pick it up.
##  - flour sacks tumble along in the wind, so you have to chase them a little
##  - buried coins are invisible: find them with Otto's metal detector, then
##    press E to dig when you're standing on one

const COIN_MODEL := preload("res://models/coin.glb")

var item_type := "coin"
var game: Node   # main.gd
var visual: Node3D
var light: OmniLight3D
var t := 0.0
var buried := false          # set before adding to the tree
var interact_range := 1.4
var wind := Vector3.ZERO
var digging := false


func _ready() -> void:
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.9
	col.shape = shape
	col.position.y = 0.5
	add_child(col)

	visual = Node3D.new()
	add_child(visual)
	match item_type:
		"coin":
			var coin := COIN_MODEL.instantiate()
			coin.scale = Vector3.ONE * 1.6
			visual.add_child(coin)
		"flour":
			visual.add_child(_box(Vector3(0.55, 0.6, 0.4), Color(0.95, 0.93, 0.85), Vector3(0, 0.3, 0)))
			visual.add_child(_box(Vector3(0.25, 0.15, 0.2), Color(0.95, 0.93, 0.85), Vector3(0, 0.66, 0)))
			visual.add_child(_box(Vector3(0.28, 0.05, 0.23), Color(0.6, 0.4, 0.2), Vector3(0, 0.6, 0)))
			visual.add_child(_box(Vector3(0.3, 0.15, 0.02), Color(0.8, 0.3, 0.25), Vector3(0, 0.32, -0.21)))
		"flower":
			var petal_color: Color = [Color(1, 0.4, 0.6), Color(0.6, 0.5, 1), Color(1, 0.6, 0.2)].pick_random()
			visual.add_child(_box(Vector3(0.06, 0.6, 0.06), Color(0.2, 0.6, 0.2), Vector3(0, 0.3, 0)))
			for i in 5:
				var a := TAU * i / 5.0
				visual.add_child(_ball(0.14, petal_color, Vector3(cos(a) * 0.15, 0.65, sin(a) * 0.15)))
			visual.add_child(_ball(0.1, Color(1, 0.9, 0.3), Vector3(0, 0.67, 0)))

	# A soft light so items are easier to spot from a distance
	light = OmniLight3D.new()
	light.light_color = Color(1, 0.95, 0.7)
	light.light_energy = 0.8
	light.omni_range = 2.5
	light.position.y = 0.8
	add_child(light)

	if buried:
		visual.visible = false
		light.visible = false
		add_to_group("interactable")
	else:
		body_entered.connect(_on_body_entered)
	if item_type == "flour":
		var a := randf() * TAU
		wind = Vector3(cos(a), 0, sin(a)) * randf_range(0.5, 0.9)
		t = randf() * 10.0


func _process(delta: float) -> void:
	t += delta
	if buried:
		return
	if item_type == "flour":
		# Tumble along in the wind; turn back before leaving the village.
		# They skitter faster when you get close.
		var speed := 1.0
		if game and game.player.global_position.distance_to(global_position) < 4.0:
			speed = 2.2
		# Look before tumbling: if the next step would hit a house, tree or
		# the edge of the village, turn to a clear direction instead of moving.
		var next := position + wind * speed * delta
		if not _free(next):
			var turned := false
			for k in 12:
				var cand := wind.rotated(Vector3.UP, randf_range(0.5, 1.5) * PI * (1 if k % 2 == 0 else -1))
				if _free(position + cand.normalized() * 0.6):
					wind = cand
					turned = true
					break
			if not turned:
				_push_out()
		else:
			position = next
		visual.rotation.z = sin(t * 4.0) * 0.3
		visual.position.y = abs(sin(t * 4.0)) * 0.35
		return
	visual.rotation.y += delta * 1.5
	visual.position.y = 0.15 + sin(t * 3.0) * 0.1


func _free(p: Vector3) -> bool:
	return Vector2(p.x, p.z).length() < 25.0 and game.is_clear(p, 0.7)


## Somehow inside something (e.g. spawned there): step away from the nearest obstacle.
func _push_out() -> void:
	if Vector2(position.x, position.z).length() >= 25.0:
		position -= Vector3(position.x, 0, position.z).normalized() * 0.15   # back toward the village
		return
	var best: Dictionary = {}
	var bd := INF
	for lm in game.landmarks:
		var d: float = Vector2(position.x - lm["pos"].x, position.z - lm["pos"].z).length() - lm["radius"]
		if d < bd:
			bd = d
			best = lm
	var away := Vector3(position.x, 0, position.z) * -1.0 if best.is_empty() else position - (best["pos"] as Vector3)
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3(1, 0, 0)
	position += away.normalized() * 0.15


func _on_body_entered(body: Node) -> void:
	if game and body == game.player:
		game.collect(self)


# ---------------------------------------------------------------- buried coins

func distance_to_player(player: Node3D) -> float:
	return Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()


func get_prompt(_player: Node3D) -> String:
	return "" if digging else "E: Dig here!"


func interact(player: Node3D) -> void:
	if digging:
		return
	digging = true
	remove_from_group("interactable")
	player.play_action_bounce()
	Audio.play("dig")
	# pop the coin up out of the ground, then collect it
	visual.visible = true
	light.visible = true
	visual.position.y = -0.4
	var tw := create_tween()
	tw.tween_property(visual, "position:y", 1.0, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.25)
	tw.tween_callback(func(): game.collect(self))


func _box(size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = _mat(color)
	return mi


func _ball(r: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	mi.mesh = s
	mi.position = pos
	mi.material_override = _mat(color)
	return mi


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m
