extends Node3D
## One square of farmland. Press E on it to: till -> plant -> water -> harvest.
## Watered crops grow one stage each night. The tile's data lives in
## Game.farm[index] so it gets saved.

var index := 0
var interact_range := 1.3
var game_world: Node   # main.gd

var soil: MeshInstance3D
var soil_mat: StandardMaterial3D
var plant_root: Node3D
var furrows: Node3D
var furrow_mat: StandardMaterial3D
var _shown := ""   # cache key so we only rebuild the plant model when it changes


func _ready() -> void:
	add_to_group("interactable")
	soil = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.5, 0.12, 1.5)
	soil.mesh = box
	soil.position.y = 0.03
	soil_mat = StandardMaterial3D.new()
	soil.material_override = soil_mat
	add_child(soil)
	# Raised furrows, shown once the soil is tilled
	furrows = Node3D.new()
	furrow_mat = StandardMaterial3D.new()
	for i in 3:
		var ridge := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(1.3, 0.08, 0.22)
		ridge.mesh = rb
		ridge.position = Vector3(0, 0.12, (i - 1) * 0.45)
		ridge.material_override = furrow_mat
		furrows.add_child(ridge)
	add_child(furrows)
	plant_root = Node3D.new()
	plant_root.position.y = 0.09
	add_child(plant_root)
	refresh()


func data() -> Dictionary:
	return Game.farm[index]


func is_ready_to_harvest() -> bool:
	var t := data()
	return t["crop"] != "" and t["stage"] >= Game.CROPS[t["crop"]]["days"]


func distance_to_player(player: Node3D) -> float:
	return Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()


func get_prompt(_player: Node3D) -> String:
	var t := data()
	if not t["tilled"]:
		return "E: Till soil"
	if t["crop"] == "":
		if Game.count(Game.selected_seed) > 0:
			return "E: Plant %s  (Q: change seed)" % Game.item_name(Game.selected_seed)
		return "No seeds -- buy some at the market"
	if is_ready_to_harvest():
		return "E: Harvest %s" % Game.item_name(Game.CROPS[t["crop"]]["crop"])
	if not t["watered"]:
		return "E: Water"
	var left: int = Game.CROPS[t["crop"]]["days"] - t["stage"]
	return "Watered. Ready in %d day%s" % [left, "" if left == 1 else "s"]


func interact(player: Node3D) -> void:
	var t := data()
	if not t["tilled"]:
		t["tilled"] = true
		Audio.play("till")
	elif t["crop"] == "":
		if Game.remove_item(Game.selected_seed):
			t["crop"] = Game.selected_seed
			t["stage"] = 0
			t["watered"] = false
			Audio.play("plant")
			if Game.count(Game.selected_seed) == 0:
				Game.cycle_seed()
	elif is_ready_to_harvest():
		var crop: String = Game.CROPS[t["crop"]]["crop"]
		if Game.farming_mode == "minigame":
			# "Pull!" -- a perfect pull gives a bonus crop
			game_world.play_minigame("harvest", func(quality): _finish_harvest(crop, quality), crop)
			return
		_finish_harvest(crop, -1)   # simple mode: always exactly one
	elif not t["watered"]:
		t["watered"] = true
		Audio.play("water")
	player.play_action_bounce()
	refresh()


## Updates the soil color and the plant model to match the saved data.
func refresh() -> void:
	var t := data()
	furrows.visible = t["tilled"]
	soil_mat.roughness = 1.0
	if not t["tilled"]:
		soil_mat.albedo_color = Color(0.42, 0.45, 0.24)    # grassy, untouched
	elif t["watered"]:
		soil_mat.albedo_color = Color(0.2, 0.13, 0.08)     # dark, damp soil
		soil_mat.roughness = 0.45
	else:
		soil_mat.albedo_color = Color(0.4, 0.27, 0.16)
	furrow_mat.albedo_color = soil_mat.albedo_color.lightened(0.08)
	furrow_mat.roughness = soil_mat.roughness

	var key := "%s:%d:%s" % [t["crop"], t["stage"], is_ready_to_harvest()]
	if key == _shown:
		return
	_shown = key
	for c in plant_root.get_children():
		c.queue_free()
	if t["crop"] == "":
		return
	var info: Dictionary = Game.CROPS[t["crop"]]
	var growth: float = float(t["stage"]) / float(info["days"])      # 0 .. 1
	if not is_ready_to_harvest():
		# Sprout that gets taller each day
		var h: float = 0.15 + growth * 0.45
		for i in 3:
			var a := TAU * i / 3.0
			_leaf(Vector3(cos(a) * 0.08, h * 0.5, sin(a) * 0.08), Vector3(0.06, h, 0.06), Color(0.3, 0.7, 0.25), a)
		return
	match t["crop"]:
		"wheat_seed":
			for i in 7:
				var p := Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4))
				_leaf(p + Vector3(0, 0.35, 0), Vector3(0.04, 0.7, 0.04), Color(0.75, 0.65, 0.3), 0)
				_leaf(p + Vector3(0, 0.75, 0), Vector3(0.09, 0.2, 0.09), info["color"], 0)
		"carrot_seed":
			for i in 4:
				var a := TAU * i / 4.0
				_leaf(Vector3(cos(a) * 0.1, 0.3, sin(a) * 0.1), Vector3(0.05, 0.5, 0.05), Color(0.25, 0.65, 0.2), a)
			_leaf(Vector3(0, 0.05, 0), Vector3(0.22, 0.12, 0.22), info["color"], 0)
		"pumpkin_seed":
			var s := MeshInstance3D.new()
			var sphere := SphereMesh.new()
			sphere.radius = 0.4
			sphere.height = 0.6
			s.mesh = sphere
			s.position.y = 0.28
			var m := StandardMaterial3D.new()
			m.albedo_color = info["color"]
			s.material_override = m
			plant_root.add_child(s)
			_leaf(Vector3(0, 0.62, 0), Vector3(0.06, 0.15, 0.06), Color(0.35, 0.5, 0.2), 0)
		"tomato_seed":
			# a leafy vine up a wooden stake, hung with red tomatoes
			_leaf(Vector3(0, 0.45, 0), Vector3(0.04, 0.9, 0.04), Color(0.55, 0.4, 0.25), 0)
			for i in 5:
				var a := TAU * i / 5.0
				_leaf(Vector3(cos(a) * 0.14, 0.25 + i * 0.1, sin(a) * 0.14), Vector3(0.2, 0.05, 0.12), Color(0.25, 0.6, 0.2), a)
			for i in 5:
				var a := TAU * i / 5.0 + 0.6
				_ball(Vector3(cos(a) * 0.16, 0.3 + (i % 3) * 0.18, sin(a) * 0.16), 0.08, info["color"])
		"strawberry_seed":
			# a low leafy clump dotted with berries
			for i in 6:
				var a := TAU * i / 6.0
				_leaf(Vector3(cos(a) * 0.18, 0.1, sin(a) * 0.18), Vector3(0.18, 0.05, 0.14), Color(0.2, 0.55, 0.2), a)
			for i in 6:
				var a := TAU * i / 6.0 + 0.5
				_ball(Vector3(cos(a) * 0.26, 0.08, sin(a) * 0.26), 0.06, info["color"])
		"corn_seed":
			# a tall stalk with long leaves and golden cobs
			_leaf(Vector3(0, 0.65, 0), Vector3(0.07, 1.3, 0.07), Color(0.4, 0.65, 0.25), 0)
			for i in 4:
				var a := TAU * i / 4.0
				_leaf(Vector3(cos(a) * 0.15, 0.4 + i * 0.2, sin(a) * 0.15), Vector3(0.35, 0.04, 0.08), Color(0.35, 0.62, 0.22), a)
			for side in [-1, 1]:
				_leaf(Vector3(side * 0.09, 0.8, 0), Vector3(0.09, 0.25, 0.09), info["color"], 0)
			_leaf(Vector3(0, 1.35, 0), Vector3(0.12, 0.12, 0.12), Color(0.85, 0.7, 0.4), 0)


## quality from the Pull! minigame: 0 weak, 1 good, 2 perfect.
## Perfect = 2 crops; good = 1 crop with a 25% chance of a bonus one.
func _finish_harvest(crop: String, quality: int) -> void:
	var t := data()
	if t["crop"] == "":
		return
	var n := 1
	if quality == 2 or (quality == 1 and randf() < 0.25):
		n = 2
	Game.add_item(crop, n)
	Game.crops_harvested += n
	t["crop"] = ""
	t["stage"] = 0
	t["watered"] = false
	Audio.play("harvest")
	var what := Game.item_name(crop, n > 1).to_lower()
	game_world.hud.show_toast(("Harvested %d %s!" % [n, what]) if n > 1 else ("Harvested a %s!" % what), 2.0)
	refresh()


func _ball(pos: Vector3, r: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = r
	sphere.height = r * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	mi.mesh = sphere
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mi.material_override = m
	plant_root.add_child(mi)


func _leaf(pos: Vector3, size: Vector3, color: Color, rot: float) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.rotation = Vector3(0.15, rot, 0.1)
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	mi.material_override = m
	plant_root.add_child(mi)
