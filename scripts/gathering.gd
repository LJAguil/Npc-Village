extends Node3D
## Wood and stone. Every tree and rock in the village can be gathered (only
## the palm trees on the beach and the crab rocks are left alone). Press E to
## swing: a few hits fells a tree or breaks a boulder (and sometimes a
## gemstone). The named landmarks ("the big oak", "the grey rock"...) work the
## same way. Stumps and rubble grow back after a couple of days.

const TREES := 28
const BOULDERS := 10
const TREE_HITS := 3
const ROCK_HITS := 4
const TREE_REGROW := 2      # days
const ROCK_REGROW := 2
const TREE_KINDS := ["oak0", "pine0", "birch0", "oak1", "pine1", "birch1"]

var world: Node3D
var nodes := {}             # id -> {"kind", "pos", "hp", "body", "stump", "scale", "tree_kind"}


## A fixed tree or rock placed by the village layout (the named landmarks).
## Call before build().
func add_fixed(id: String, kind: String, pos: Vector3, s: float, lm_name: String, tree_kind := "") -> void:
	nodes[id] = {"kind": kind, "pos": pos, "hp": 0, "body": null, "stump": null, "scale": s, "tree_kind": tree_kind}
	world.landmarks.append({"name": lm_name, "pos": pos, "radius": (1.0 if kind == "tree" else 1.1 * s)})
	world._spot(pos, 1.6 + 0.3 * s, _prompt.bind(id), func(_pl): _hit(id))


## The rest are scattered around the edge of the village (the same layout
## every game), clear of the paths, buildings and Pip's race course.
func build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242        # the same layout every game
	var placed := 0
	var tries := 0
	while placed < TREES + BOULDERS and tries < 5000:
		tries += 1
		var is_tree := placed < TREES
		var a := rng.randf() * TAU
		var r := rng.randf_range(18.5, 28.0) if is_tree else rng.randf_range(17.0, 27.5)   # keep the middle tidy
		var p := Vector3(cos(a), 0, sin(a)) * r
		var sc := rng.randf_range(1.0, 1.35) if is_tree else 1.05
		var tk: String = TREE_KINDS[rng.randi() % TREE_KINDS.size()]
		if not world.is_clear(p, 1.6) or world._dist_to_paths(p) < 2.5 or world.scenery.is_sand(p) or _on_race_course(p):
			continue
		var id := "%s%d" % ["tree" if is_tree else "rock", placed]
		nodes[id] = {"kind": "tree" if is_tree else "rock", "pos": p, "hp": 0, "body": null, "stump": null, "scale": sc, "tree_kind": tk}
		world.landmarks.append({"name": "", "pos": p, "radius": 0.8 if is_tree else 1.0})
		world._spot(p, 1.9, _prompt.bind(id), func(_pl): _hit(id))
		placed += 1
	refresh()


## How much a tree or rock gives: big ones give a bit more.
func _bonus(n: Dictionary) -> int:
	return 1 if float(n.get("scale", 1.0)) >= 1.25 else 0


## Keep Pip's race course clear.
func _on_race_course(p: Vector3) -> bool:
	return world.activities.on_race_course(p)


## Put back anything that has grown back (called on start and each morning).
func refresh() -> void:
	var cut := Game.xdict("cut")
	for id in nodes:
		var n: Dictionary = nodes[id]
		var regrow := TREE_REGROW if n["kind"] == "tree" else ROCK_REGROW
		var gone: bool = cut.has(id) and Game.day - int(cut[id]) < regrow
		if gone:
			_remove_body(n)
			_show_stump(n)
		else:
			cut.erase(id)
			if n["body"] == null:
				_make_body(id, n)
			n["hp"] = TREE_HITS if n["kind"] == "tree" else ROCK_HITS
			if n["stump"]:
				n["stump"].queue_free()
				n["stump"] = null


func _prompt(_pl, id: String) -> String:
	var n: Dictionary = nodes[id]
	if n["body"] == null:
		return ""
	if n["kind"] == "tree":
		return "E: Chop the tree  (%d/%d)" % [TREE_HITS - n["hp"], TREE_HITS] if n["hp"] < TREE_HITS else "E: Chop the tree for wood"
	return "E: Break the boulder  (%d/%d)" % [ROCK_HITS - n["hp"], ROCK_HITS] if n["hp"] < ROCK_HITS else "E: Break the boulder for stone"


func _hit(id: String) -> void:
	var n: Dictionary = nodes[id]
	var body: Node3D = n["body"]
	if body == null:
		return
	var p: CharacterBody3D = world.player
	var to: Vector3 = n["pos"] - p.global_position
	p.face_direction(to)
	var is_tree: bool = n["kind"] == "tree"
	# minigame style: Timber! (trees) or Strike! (boulders), then it falls
	if Game.gathering_mode == "minigame":
		world.play_minigame("chop" if is_tree else "mine", func(points: int):
			if n["body"] == null:
				return
			var amount: int = 2 + points / 2 + (1 if (is_tree and points >= 6) or (not is_tree and points >= 8) else 0) + _bonus(n)
			var gem_chance: float = 0.08 + (0.04 * world.minigames.mine_perfects if not is_tree else 0.0)
			_fell(id, amount, gem_chance, to))
		return
	p.play_action_bounce()
	n["hp"] -= 1
	Audio.play("chop" if is_tree else "crack", 0.12)
	_chips(n["pos"] + Vector3(0, 0.9 if is_tree else 0.5, 0), Color(0.75, 0.55, 0.3) if is_tree else Color(0.6, 0.6, 0.62))
	# shake
	var base_rot: Vector3 = body.rotation
	var tw := body.create_tween()
	tw.tween_property(body, "rotation:z", base_rot.z + 0.06, 0.05)
	tw.tween_property(body, "rotation:z", base_rot.z - 0.05, 0.07)
	tw.tween_property(body, "rotation:z", base_rot.z, 0.06)
	if n["hp"] > 0:
		return
	_fell(id, randi_range(3, 4) + _bonus(n), 0.08, to)


## Knock it down and hand out the wood or stone.
func _fell(id: String, amount: int, gem_chance: float, to: Vector3) -> void:
	var n: Dictionary = nodes[id]
	var body: Node3D = n["body"]
	if body == null:
		return
	var is_tree: bool = n["kind"] == "tree"
	var base_rot: Vector3 = body.rotation
	var base_scale: Vector3 = body.scale
	Game.xdict("cut")[id] = Game.day
	var item := "wood" if is_tree else "stone"
	Game.add_item(item, amount)
	Game.extra["gathered"] = Game.xi("gathered") + amount
	var msg := "+%d %s" % [amount, item]
	if not is_tree and randf() < gem_chance:
		Game.add_item("gem")
		msg += "  ...and a gemstone!"
		Audio.play("chime")
	world.hud.show_toast(msg, 2.0)
	n["body"] = null
	_chips(n["pos"] + Vector3(0, 0.9 if is_tree else 0.5, 0), Color(0.75, 0.55, 0.3) if is_tree else Color(0.6, 0.6, 0.62))
	for c in body.get_children():
		if c is CollisionShape3D:
			c.set_deferred("disabled", true)
	if is_tree:
		Audio.play("timber")
		var fall := Vector3(-to.x, 0, -to.z).normalized()   # falls away from you
		var axis := Vector3(fall.z, 0, -fall.x)
		var ft := body.create_tween()
		ft.tween_method(func(k: float):
			if is_instance_valid(body):
				body.transform.basis = (Basis(axis, k * PI * 0.48) * Basis(Vector3.UP, base_rot.y)).scaled(base_scale), 0.0, 1.0, 0.8).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		ft.tween_interval(0.6)
		ft.tween_property(body, "scale", Vector3.ONE * 0.01, 0.35)
		ft.tween_callback(body.queue_free)
	else:
		Audio.play("crack")
		var rt := body.create_tween()
		rt.tween_property(body, "scale", Vector3(1.2, 0.2, 1.2) * base_scale, 0.25)
		rt.tween_property(body, "scale", Vector3.ONE * 0.01, 0.2)
		rt.tween_callback(body.queue_free)
	_show_stump(n)
	world.update_quest_log()


func _make_body(_id: String, n: Dictionary) -> void:
	var p: Vector3 = n["pos"]
	var sc: float = n.get("scale", 1.0)
	if n["kind"] == "tree":
		n["body"] = world.scenery.add_tree(self, p, n.get("tree_kind", "oak0"), sc)
	else:
		n["body"] = world.scenery.add_rock(self, p, sc)


func _remove_body(n: Dictionary) -> void:
	if n["body"] and is_instance_valid(n["body"]):
		n["body"].queue_free()
	n["body"] = null


func _show_stump(n: Dictionary) -> void:
	if n["stump"] and is_instance_valid(n["stump"]):
		return
	var s := Node3D.new()
	add_child(s)
	s.global_position = n["pos"]
	s.scale = Vector3.ONE * float(n.get("scale", 1.0))
	if n["kind"] == "tree":
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.28
		cm.bottom_radius = 0.34
		cm.height = 0.3
		mi.mesh = cm
		mi.position.y = 0.15
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.5, 0.36, 0.22)
		mi.material_override = m
		s.add_child(mi)
		var top := MeshInstance3D.new()
		var tc := CylinderMesh.new()
		tc.top_radius = 0.26
		tc.bottom_radius = 0.26
		tc.height = 0.02
		top.mesh = tc
		top.position.y = 0.31
		var tm := StandardMaterial3D.new()
		tm.albedo_color = Color(0.85, 0.7, 0.45)
		top.material_override = tm
		s.add_child(top)
	else:
		for k in 5:
			var pebble := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.12
			sm.height = 0.14
			pebble.mesh = sm
			pebble.position = Vector3(randf_range(-0.4, 0.4), 0.05, randf_range(-0.4, 0.4))
			var pm := StandardMaterial3D.new()
			pm.albedo_color = Color(0.55, 0.56, 0.58)
			pebble.material_override = pm
			s.add_child(pebble)
	n["stump"] = s


func _chips(pos: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 12
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 3.5
	p.gravity = Vector3(0, -9, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 0.07
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	bm.material = m
	p.mesh = bm
	add_child(p)
	p.global_position = pos
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
