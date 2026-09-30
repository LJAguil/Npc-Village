extends Node3D
## The town hall, built in four stages at the construction site east of the
## well: Foundation -> Frame -> Walls -> Roof (see Game.TOWN_HALL). Each stage
## appears in the world as soon as it's finished. Villagers wander over to help
## while it's going up. When it's done you can walk inside (interiors.gd), the
## request board gets a 4th slot and board rewards go up by 25%.

const HALL_POS := Vector3(15.9, 0, -4.3)
const W := 6.0       # width (across the front)
const D := 5.0       # depth
const H := 3.2       # wall height

var world: Node3D
var root: Node3D
var stage_nodes: Array = []      # one Node3D per stage
var site_node: Node3D
var body: StaticBody3D           # collision for the finished walls


func facing() -> Vector3:
	return -Vector3(HALL_POS.x, 0, HALL_POS.z).normalized()


func build() -> void:
	root = Node3D.new()
	add_child(root)
	root.position = HALL_POS
	var f := facing()
	root.rotation.y = atan2(f.x, f.z)    # local +Z faces the well
	world.landmarks.append({"name": "the town hall", "pos": HALL_POS, "radius": 4.2})
	_build_site()
	for i in Game.TOWN_HALL.size():
		var n := Node3D.new()
		root.add_child(n)
		stage_nodes.append(n)
	_build_foundation(stage_nodes[0])
	_build_frame(stage_nodes[1])
	_build_walls(stage_nodes[2])
	_build_roof(stage_nodes[3])
	world._spot(HALL_POS + f * (D / 2 + 1.6), 2.0,
		func(_p): return "" if Game.hall_built() else "E: Help build the Town Hall  (stage %d/4: %s)" % [Game.xi("hall_stage") + 1, Game.TOWN_HALL[Game.xi("hall_stage")]["name"]],
		func(_p): world.panels.open_townhall(self))
	refresh()


## Where villagers go to help (Vector3.INF when there's nothing to build).
func site_for_helpers() -> Vector3:
	return Vector3.INF if Game.hall_built() else HALL_POS


func refresh() -> void:
	var stage := Game.xi("hall_stage")
	for i in stage_nodes.size():
		stage_nodes[i].visible = i < stage
	site_node.visible = stage < Game.TOWN_HALL.size()
	body.process_mode = Node.PROCESS_MODE_INHERIT if stage >= 3 else Node.PROCESS_MODE_DISABLED
	for post in stage_nodes[1].get_children():
		if post is StaticBody3D:
			post.process_mode = Node.PROCESS_MODE_INHERIT if stage >= 2 and stage < 3 else Node.PROCESS_MODE_DISABLED


## How much of a resource the current stage still needs.
func still_needed(res: String) -> int:
	var stage := Game.xi("hall_stage")
	if stage >= Game.TOWN_HALL.size():
		return 0
	var need: int = Game.TOWN_HALL[stage]["needs"].get(res, 0)
	return max(0, need - int(Game.xdict("hall_given").get(res, 0)))


func have(res: String) -> int:
	return Game.coins if res == "coins" else Game.count(res)


## Give as much of a resource as you can (up to what's needed). Returns amount.
func give(res: String) -> int:
	var n: int = min(still_needed(res), have(res))
	if n <= 0:
		return 0
	if res == "coins":
		Game.add_coins(-n)
	else:
		Game.remove_item(res, n)
	var given := Game.xdict("hall_given")
	given[res] = int(given.get(res, 0)) + n
	Audio.play("hammer" if res != "coins" else "coin")
	_check_stage_done()
	return n


func _check_stage_done() -> void:
	var stage := Game.xi("hall_stage")
	if stage >= Game.TOWN_HALL.size():
		return
	for res in Game.TOWN_HALL[stage]["needs"]:
		if still_needed(res) > 0:
			return
	Game.extra["hall_stage"] = stage + 1
	Game.extra["hall_given"] = {}
	refresh()
	var n: Node3D = stage_nodes[stage]
	n.scale = Vector3(1, 0.05, 1)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3.ONE, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play("hammer")
	if Game.hall_built():
		Audio.play("win")
		world.hud.show_toast("The Town Hall is finished! Step inside -- and the request board now has more (and better paid) jobs.", 6.0)
		world._confetti_at(HALL_POS + Vector3(0, 6, 0))
		for v in world.npcs:
			if v.visible and v.global_position.distance_to(HALL_POS) < 20.0:
				v.say(["Hooray for the Town Hall!", "It's beautiful!", "Speech! Speech!"].pick_random(), 3.0)
	else:
		world.hud.show_toast("%s done! Next: %s." % [Game.TOWN_HALL[stage]["name"], Game.TOWN_HALL[stage + 1]["name"]], 4.0)
		Audio.play("quest")
	Game.save_game()


# ================================================================ models

func _mat(c: Color, fade := false) -> StandardMaterial3D:
	return world._mat(c, fade)


func _box(parent: Node3D, pos: Vector3, size: Vector3, c: Color, fade := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = _mat(c, fade)
	parent.add_child(mi)
	return mi


func _solid(parent: Node3D, pos: Vector3, size: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	sb.add_child(col)
	parent.add_child(sb)
	return sb


func _build_site() -> void:
	site_node = Node3D.new()
	root.add_child(site_node)
	var wood := Color(0.6, 0.45, 0.28)
	# corner stakes and a rope outline
	for x in [-W / 2, W / 2]:
		for z in [-D / 2, D / 2]:
			_box(site_node, Vector3(x, 0.4, z), Vector3(0.1, 0.8, 0.1), wood)
	for z in [-D / 2, D / 2]:
		_box(site_node, Vector3(0, 0.7, z), Vector3(W, 0.03, 0.03), Color(0.9, 0.85, 0.7))
	for x in [-W / 2, W / 2]:
		_box(site_node, Vector3(x, 0.7, 0), Vector3(0.03, 0.03, D), Color(0.9, 0.85, 0.7))
	# a sign in front
	var sign := Node3D.new()
	sign.position = Vector3(-2.2, 0, D / 2 + 1.2)
	site_node.add_child(sign)
	_box(sign, Vector3(0, 0.7, 0), Vector3(0.1, 1.4, 0.1), wood)
	_box(sign, Vector3(0, 1.35, 0.06), Vector3(1.5, 0.7, 0.08), Color(0.85, 0.7, 0.45))
	var l := Label3D.new()
	l.text = "FUTURE\nTOWN HALL"
	l.font_size = 40
	l.pixel_size = 0.005
	l.outline_size = 8
	l.position = Vector3(0, 1.35, 0.11)
	l.visibility_range_end = 16.0
	sign.add_child(l)
	# a little pile of lumber and stone
	for k in 3:
		_box(site_node, Vector3(2.4, 0.1 + k * 0.14, D / 2 + 1.0), Vector3(1.4, 0.12, 0.2), wood.darkened(0.1 * k)).rotation.y = 0.1 * k
	for k in 3:
		var st := _box(site_node, Vector3(1.3 + k * 0.35, 0.15, D / 2 + 1.5), Vector3(0.3, 0.3, 0.3), Color(0.6, 0.6, 0.62))
		st.rotation.y = k


func _build_foundation(n: Node3D) -> void:
	_box(n, Vector3(0, 0.1, 0), Vector3(W + 0.4, 0.2, D + 0.4), Color(0.62, 0.6, 0.57))
	for i in 6:
		_box(n, Vector3(-W / 2 + 0.5 + i * (W - 1.0) / 5.0, 0.205, 0), Vector3(0.03, 0.01, D + 0.3), Color(0.5, 0.48, 0.45))
	_box(n, Vector3(0, 0.08, D / 2 + 0.55), Vector3(2.2, 0.16, 0.7), Color(0.58, 0.56, 0.53))


func _build_frame(n: Node3D) -> void:
	var timber := Color(0.55, 0.38, 0.22)
	var posts := [Vector3(-W / 2, 0, -D / 2), Vector3(0, 0, -D / 2), Vector3(W / 2, 0, -D / 2),
		Vector3(-W / 2, 0, D / 2), Vector3(-1.0, 0, D / 2), Vector3(1.0, 0, D / 2), Vector3(W / 2, 0, D / 2),
		Vector3(-W / 2, 0, 0), Vector3(W / 2, 0, 0)]
	for p in posts:
		_box(n, p + Vector3(0, H / 2 + 0.2, 0), Vector3(0.25, H, 0.25), timber)
		_solid(n, p + Vector3(0, H / 2 + 0.2, 0), Vector3(0.3, H, 0.3))
	for z in [-D / 2, D / 2]:
		_box(n, Vector3(0, H + 0.2, z), Vector3(W + 0.25, 0.22, 0.22), timber)
	for x in [-W / 2, W / 2]:
		_box(n, Vector3(x, H + 0.2, 0), Vector3(0.22, 0.22, D + 0.25), timber)


func _build_walls(n: Node3D) -> void:
	var wall := Color(0.93, 0.88, 0.78)
	var trim := Color(0.55, 0.38, 0.22)
	var y := H / 2 + 0.2
	_box(n, Vector3(0, y, -D / 2), Vector3(W, H, 0.2), wall, true)
	for x in [-W / 2, W / 2]:
		_box(n, Vector3(x, y, 0), Vector3(0.2, H, D), wall.darkened(0.05), true)
	# front wall with a big double door in the middle
	for x in [-(W / 2 + 1.0) / 2, (W / 2 + 1.0) / 2]:
		_box(n, Vector3(x, y, D / 2), Vector3(W / 2 - 1.0, H, 0.2), wall, true)
	_box(n, Vector3(0, H - 0.3, D / 2), Vector3(2.0, 0.9, 0.2), wall, true)
	_box(n, Vector3(0, 1.05, D / 2 + 0.02), Vector3(1.8, 1.9, 0.08), Color(0.45, 0.28, 0.16))
	_box(n, Vector3(0, 1.05, D / 2 + 0.07), Vector3(0.04, 1.9, 0.02), Color(0.3, 0.18, 0.1))
	for x in [-0.25, 0.25]:
		_box(n, Vector3(x, 1.05, D / 2 + 0.08), Vector3(0.06, 0.06, 0.04), Color(1, 0.84, 0.3))
	# windows with warm light and wooden trim
	for x in [-2.1, 2.1]:
		var win := _box(n, Vector3(x, 1.9, D / 2 + 0.11), Vector3(0.9, 0.9, 0.03), Color(1, 0.85, 0.5))
		var wm: StandardMaterial3D = win.material_override
		wm.emission_enabled = true
		wm.emission = Color(1, 0.75, 0.4)
		wm.emission_energy_multiplier = 0.7
		_box(n, Vector3(x, 1.9, D / 2 + 0.13), Vector3(1.05, 0.08, 0.04), trim)
		_box(n, Vector3(x, 1.9, D / 2 + 0.13), Vector3(0.08, 1.05, 0.04), trim)
	for x in [-W / 2, W / 2]:
		for z in [-D / 2, D / 2]:
			_box(n, Vector3(x, y, z), Vector3(0.3, H, 0.3), trim)
	body = _solid(root, Vector3(0, H / 2 + 0.2, 0), Vector3(W, H, D))


func _build_roof(n: Node3D) -> void:
	var roof := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(W + 0.8, 1.9, D + 0.8)
	roof.mesh = pm
	roof.position.y = H + 0.2 + 0.95
	roof.material_override = _mat(Color(0.35, 0.45, 0.6), true)
	n.add_child(roof)
	# bell tower on top, with a clock and a golden bell
	var tower_y := H + 0.2 + 1.5
	_box(n, Vector3(0, tower_y + 0.6, 0), Vector3(1.2, 1.4, 1.2), Color(0.93, 0.88, 0.78), true)
	var clock := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.38
	cm.bottom_radius = 0.38
	cm.height = 0.05
	clock.mesh = cm
	clock.rotation.x = PI / 2
	clock.position = Vector3(0, tower_y + 0.75, 0.62)
	clock.material_override = _mat(Color(0.98, 0.96, 0.9))
	n.add_child(clock)
	_box(n, Vector3(0, tower_y + 0.85, 0.66), Vector3(0.04, 0.26, 0.02), Color(0.1, 0.1, 0.1))
	_box(n, Vector3(0.08, tower_y + 0.75, 0.66), Vector3(0.18, 0.04, 0.02), Color(0.1, 0.1, 0.1))
	var cap := MeshInstance3D.new()
	var cp := PrismMesh.new()
	cp.size = Vector3(1.5, 0.9, 1.5)
	cap.mesh = cp
	cap.position.y = tower_y + 1.75
	cap.material_override = _mat(Color(0.35, 0.45, 0.6), true)
	n.add_child(cap)
	var bell := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.22
	bm.height = 0.35
	bell.mesh = bm
	bell.position.y = tower_y + 1.2
	var gold := _mat(Color(1, 0.8, 0.3))
	gold.metallic = 0.9
	gold.roughness = 0.25
	bell.material_override = gold
	n.add_child(bell)
	# flag
	_box(n, Vector3(0, tower_y + 2.8, 0), Vector3(0.05, 1.5, 0.05), Color(0.85, 0.85, 0.85))
	var flag := _box(n, Vector3(0.35, tower_y + 3.3, 0), Vector3(0.65, 0.4, 0.02), Color(0.9, 0.3, 0.3))
	flag.name = "Flag"
	# name board over the door
	var l := Label3D.new()
	l.text = "TOWN HALL"
	l.font_size = 64
	l.pixel_size = 0.006
	l.outline_size = 12
	l.modulate = Color(1, 0.9, 0.6)
	l.position = Vector3(0, H - 0.15, D / 2 + 0.13)
	n.add_child(l)


func _process(_delta: float) -> void:
	if Game.hall_built():
		var flag: Node3D = stage_nodes[3].get_node_or_null("Flag")
		if flag:
			flag.rotation.y = sin(Time.get_ticks_msec() / 400.0) * 0.25
