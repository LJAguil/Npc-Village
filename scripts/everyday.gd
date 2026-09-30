extends Node3D
## Everyday things to do (all refresh each morning):
##   * Foraging  -- wild berries, herbs and mushrooms pop up around the village,
##                  shells (and the odd pearl) on the beach, truffles near trees.
##   * Treasure  -- a message in a bottle washes up on the beach every day. It's
##                  a map (press M to show it) with an X; dig there for treasure.
##   * Stargazing -- the telescope by your house (at night).
##   * Stone skipping -- the flat stones at the pond's edge.
##   * Music     -- the piano in your house and, once built, the bandstand.
##   * Your puppy -- waiting by your door until you adopt it.

const PET_SCRIPT := preload("res://scripts/pet.gd")
const FORAGE_COUNT := 12
const TELESCOPE_POS := Vector3(5.5, 0, 24.0)
const SKIP_POS := Vector3(-16.4, 0, -4.8)
const STAR_REWARD := 40

var world: Node3D
var pet: CharacterBody3D
var forage_nodes: Array = []
var bottle: Node3D
var dig_mound: Node3D
var treasure_pos := Vector3.INF
var bottle_pos := Vector3.ZERO


func build() -> void:
	_build_telescope()
	_build_skip_spot()
	_build_piano()
	_build_bandstand_spot()
	pet = CharacterBody3D.new()
	pet.set_script(PET_SCRIPT)
	pet.world = world
	world.add_child(pet)
	pet.global_position = Vector3(1.8, 0.2, 22.3)


## After loading or starting a new game.
func on_start() -> void:
	pet.refresh()
	if not pet.adopted():
		pet.global_position = Vector3(1.8, 0.2, 22.3)
	else:
		pet.global_position = world.player.global_position + Vector3(1.2, -0.8, 1.0)
	refresh_day()


## Every morning (after sleeping) -- plus the puppy's morning present.
func on_morning() -> void:
	refresh_day()
	var p := Game.pet()
	if p.get("adopted", false) and int(p.get("happiness", 0)) >= 60 and int(p.get("fed_day", -1)) == Game.day - 1:
		var gift: String = ["berries", "mushroom", "herb", "shell", "old_coin", "truffle", "pet_treat"].pick_random()
		Game.add_item(gift)
		world.hud.show_toast("%s brought you a present: %s!" % [p.get("name", "Biscuit"), Game.item_name(gift).to_lower()], 5.0)


func refresh_day() -> void:
	_spawn_forage()
	_place_treasure()
	world.gathering.refresh()
	world.board.refresh_day()


# ================================================================ foraging

## Remove a world object and its "press E" spot (so no prompt is left behind).
func _free_with_spot(n) -> void:
	if n == null or not is_instance_valid(n):
		return
	if n.has_meta("spot"):
		var spot = n.get_meta("spot")
		if spot != null and is_instance_valid(spot):
			spot.queue_free()
	n.queue_free()


func _day_rng(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = Game.day * 7919 + salt
	return r


func _spawn_forage() -> void:
	for n in forage_nodes:
		_free_with_spot(n)
	forage_nodes = []
	if Game.xi("forage_day", -1) != Game.day:
		Game.extra["forage_day"] = Game.day
		Game.extra["forage_taken"] = []
	var taken: Array = Game.xarr("forage_taken")
	var rng := _day_rng(31)
	var spots := []
	# beach finds
	var tries := 0
	while spots.size() < 4 and tries < 200:
		tries += 1
		var a := rng.randf_range(-0.75, 0.75)
		var sr: float = world.scenery.shore_radius(a)
		if sr < 0:
			continue
		var p := Vector3(cos(a), 0, sin(a)) * (sr - rng.randf_range(1.2, 5.0))
		if world.is_clear(p, 1.0) and not world.scenery.dock_gap.call(p):
			spots.append([p, "pearl" if rng.randf() < 0.06 else "shell"])
	# meadow finds
	tries = 0
	while spots.size() < FORAGE_COUNT and tries < 400:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(9.0, 28.0)
		var p := Vector3(cos(a), 0, sin(a)) * r
		if not world.is_clear(p, 1.2) or world._dist_to_paths(p) < 1.4 or world.scenery.is_sand(p):
			continue
		var item := ""
		if r > 21.0:
			item = "truffle" if rng.randf() < 0.07 else "mushroom"
		else:
			item = "berries" if rng.randf() < 0.5 else "herb"
		spots.append([p, item])
	for i in spots.size():
		if taken.has(i):
			continue
		var p: Vector3 = spots[i][0]
		p.y = world.scenery.height_at(p.x, p.z)
		forage_nodes.append(_forage_node(i, p, spots[i][1]))


func _forage_node(index: int, pos: Vector3, item: String) -> Node3D:
	var root := Node3D.new()
	world.add_child(root)
	root.global_position = pos
	_forage_model(root, item)
	var verb: String = {"berries": "Pick wild berries", "herb": "Pick wild herbs", "mushroom": "Pick a mushroom",
		"truffle": "Dig up a truffle!", "shell": "Pick up a seashell", "pearl": "Pick up a shiny shell..."}[item]
	var spot: Node3D = world._spot(pos, 1.4, func(_p): return "E: " + verb, func(_p): _pick(index, item, root))
	spot.set_meta("forage", true)
	root.set_meta("spot", spot)
	return root


func _pick(index: int, item: String, node: Node3D) -> void:
	if not is_instance_valid(node):
		return
	var spot: Node = node.get_meta("spot")
	Game.xarr("forage_taken").append(index)
	Game.extra["foraged"] = Game.xi("foraged") + 1
	Game.add_item(item)
	Audio.play("chime" if item in ["truffle", "pearl"] else "rustle", 0.1)
	world.player.play_action_bounce()
	var msg := "Found %s!" % ("a pearl inside the shell" if item == "pearl" else Game.item_name(item).to_lower())
	world.hud.show_toast(msg, 2.0)
	forage_nodes.erase(node)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector3.ONE * 0.01, 0.2)
	tw.tween_callback(node.queue_free)
	if is_instance_valid(spot):
		spot.queue_free()


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _ball(parent: Node3D, pos: Vector3, r: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = 8
	s.rings = 5
	mi.mesh = s
	mi.position = pos
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi


func _box(parent: Node3D, pos: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi


func _cyl(parent: Node3D, pos: Vector3, r: float, h: float, c: Color, top := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r if top < 0 else top
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _mat(c)
	parent.add_child(mi)
	return mi


func _forage_model(root: Node3D, item: String) -> void:
	match item:
		"berries":
			_ball(root, Vector3(0, 0.3, 0), 0.35, Color(0.25, 0.5, 0.22)).scale = Vector3(1, 0.8, 1)
			for k in 7:
				var a := TAU * k / 7.0
				_ball(root, Vector3(cos(a) * 0.28, 0.35 + (k % 2) * 0.12, sin(a) * 0.28), 0.06, Color(0.45, 0.2, 0.75))
		"herb":
			for k in 5:
				var a := TAU * k / 5.0
				var stem := _box(root, Vector3(cos(a) * 0.08, 0.18, sin(a) * 0.08), Vector3(0.03, 0.36, 0.03), Color(0.3, 0.6, 0.25))
				stem.rotation = Vector3(sin(a) * 0.3, 0, cos(a) * 0.3)
				_ball(root, Vector3(cos(a) * 0.14, 0.36, sin(a) * 0.14), 0.07, Color(0.45, 0.8, 0.35))
		"mushroom", "truffle":
			if item == "mushroom":
				for k in 3:
					var off := Vector3(k * 0.18 - 0.18, 0, (k % 2) * 0.12)
					_cyl(root, off + Vector3(0, 0.1, 0), 0.04, 0.2, Color(0.95, 0.92, 0.85))
					var cap := _ball(root, off + Vector3(0, 0.22, 0), 0.12, Color(0.85, 0.3, 0.25))
					cap.scale = Vector3(1, 0.55, 1)
			else:
				_ball(root, Vector3(0, 0.05, 0), 0.2, Color(0.4, 0.3, 0.2)).scale = Vector3(1, 0.3, 1)
				_ball(root, Vector3(0.05, 0.12, 0), 0.09, Color(0.3, 0.22, 0.15))
				var sparkle := OmniLight3D.new()
				sparkle.light_color = Color(1, 0.9, 0.6)
				sparkle.light_energy = 0.5
				sparkle.omni_range = 1.5
				sparkle.position.y = 0.4
				root.add_child(sparkle)
		"shell", "pearl":
			var sh := _ball(root, Vector3(0, 0.08, 0), 0.22, Color(1, 0.55, 0.5) if item == "shell" else Color(0.75, 0.7, 1))
			sh.scale = Vector3(1, 0.45, 0.8)
			for k in 3:
				_box(root, Vector3(-0.08 + k * 0.08, 0.15, 0), Vector3(0.025, 0.02, 0.3), Color(0.85, 0.35, 0.35))
			var glint := OmniLight3D.new()
			glint.light_color = Color(1, 0.8, 0.8)
			glint.light_energy = 0.6
			glint.omni_range = 1.4
			glint.position.y = 0.4
			root.add_child(glint)


# ================================================================ treasure

func _place_treasure() -> void:
	_free_with_spot(bottle)
	_free_with_spot(dig_mound)
	if Game.xi("treasure_day", -1) != Game.day:
		Game.extra["treasure_day"] = Game.day
		Game.extra["treasure_opened"] = false
		Game.extra["treasure_found"] = false
	var rng := _day_rng(977)
	treasure_pos = Vector3.INF
	for k in 300:
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(7.0, 27.0)
		if world.is_clear(p, 1.6) and world._dist_to_paths(p) > 1.6 and not world.scenery.is_sand(p):
			treasure_pos = p
			break
	for k in 100:
		var a := rng.randf_range(-0.6, 0.6)
		var sr: float = world.scenery.shore_radius(a)
		if sr < 0:
			continue
		bottle_pos = Vector3(cos(a), 0, sin(a)) * (sr - 0.8)
		if not world.scenery.dock_gap.call(bottle_pos) and world.is_clear(bottle_pos, 0.8):
			break
	if not bool(Game.extra.get("treasure_opened", false)):
		_spawn_bottle()
	elif not bool(Game.extra.get("treasure_found", false)):
		_spawn_mound()


func _spawn_bottle() -> void:
	bottle = Node3D.new()
	world.add_child(bottle)
	var p := bottle_pos
	p.y = world.scenery.height_at(p.x, p.z) + 0.08
	bottle.global_position = p
	var glass := _cyl(bottle, Vector3.ZERO, 0.09, 0.35, Color(0.4, 0.75, 0.55))
	glass.rotation.z = PI / 2
	var gm: StandardMaterial3D = glass.material_override
	gm.albedo_color = Color(0.45, 0.8, 0.6, 0.7)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var cork := _cyl(bottle, Vector3(0.21, 0, 0), 0.05, 0.08, Color(0.6, 0.45, 0.3))
	cork.rotation.z = PI / 2
	var paper := _cyl(bottle, Vector3.ZERO, 0.05, 0.25, Color(0.95, 0.9, 0.75))
	paper.rotation.z = PI / 2
	var glint := OmniLight3D.new()
	glint.light_color = Color(0.8, 1, 0.9)
	glint.light_energy = 0.8
	glint.omni_range = 2.0
	glint.position.y = 0.3
	bottle.add_child(glint)
	var spot: Node3D = world._spot(bottle_pos, 1.6, func(_p): return "E: Open the message in a bottle", func(_p): _open_bottle())
	bottle.set_meta("spot", spot)


func _open_bottle() -> void:
	if bool(Game.extra.get("treasure_opened", false)):
		return
	Game.extra["treasure_opened"] = true
	Audio.play("chime")
	world.hud.show_toast("It's a treasure map! X marks the spot. (Press M to show or hide it.)", 5.0)
	var spot: Node = bottle.get_meta("spot")
	if is_instance_valid(spot):
		spot.queue_free()
	bottle.queue_free()
	_spawn_mound()
	world.panels.show_map(treasure_pos)


## A patch of freshly turned earth (visible up close) and the dig spot.
func _spawn_mound() -> void:
	if treasure_pos == Vector3.INF:
		return
	dig_mound = Node3D.new()
	world.add_child(dig_mound)
	dig_mound.global_position = treasure_pos + Vector3(0, 0.01, 0)
	var dirt := _cyl(dig_mound, Vector3.ZERO, 0.45, 0.04, Color(0.45, 0.32, 0.2))
	dirt.visibility_range_end = 5.0
	var spot: Node3D = world._spot(treasure_pos, 1.4, func(_p): return "E: Dig here!", func(_p): _dig())
	dig_mound.set_meta("spot", spot)


func _dig() -> void:
	if bool(Game.extra.get("treasure_found", false)):
		return
	Game.extra["treasure_found"] = true
	Game.extra["treasures"] = Game.xi("treasures") + 1
	world.player.play_action_bounce()
	Audio.play("dig")
	var roll := randf()
	var msg := ""
	if roll < 0.45:
		var c := randi_range(60, 150)
		Game.add_coins(c)
		msg = "A chest of %d coins!" % c
	else:
		var item: String = "gem" if roll < 0.72 else ("old_coin" if roll < 0.9 else "relic")
		Game.add_item(item)
		msg = "You dug up %s!" % ("a " + Game.item_name(item).to_lower() if item != "old_coin" else "an ancient coin")
	await get_tree().create_timer(0.3).timeout
	Audio.play("chime")
	world.hud.show_toast(msg + "  A new map washes up tomorrow.", 4.5)
	world.panels.hide_map()
	var spot: Node = dig_mound.get_meta("spot")
	if is_instance_valid(spot):
		spot.queue_free()
	dig_mound.queue_free()


func show_map() -> void:
	if world.panels.map_visible():
		world.panels.hide_map()
		return
	if not bool(Game.extra.get("treasure_opened", false)):
		world.hud.show_toast("No map yet today. Look for a message in a bottle on the beach!", 3.0)
	elif bool(Game.extra.get("treasure_found", false)):
		world.hud.show_toast("You already found today's treasure. A new bottle washes up tomorrow.", 3.0)
	else:
		world.panels.show_map(treasure_pos)


# ================================================================ telescope, stones, music

func _build_telescope() -> void:
	var root := Node3D.new()
	world.add_child(root)
	root.global_position = TELESCOPE_POS
	for k in 3:
		var a := TAU * k / 3.0
		var leg := _box(root, Vector3(cos(a) * 0.25, 0.55, sin(a) * 0.25), Vector3(0.05, 1.15, 0.05), Color(0.4, 0.3, 0.2))
		leg.rotation = Vector3(sin(a) * 0.25, 0, -cos(a) * 0.25)
	var tube := _cyl(root, Vector3(0, 1.25, 0), 0.1, 1.0, Color(0.5, 0.42, 0.68), 0.07)
	tube.rotation = Vector3(-0.9, 0.6, 0)
	_ball(root, Vector3(0, 1.12, 0), 0.08, Color(0.8, 0.65, 0.3))
	world.landmarks.append({"name": "the telescope", "pos": TELESCOPE_POS, "radius": 0.5})
	world._spot(TELESCOPE_POS, 1.6, func(_p): return "E: Look through the telescope" if Game.is_night() else "The telescope works best at night.",
		func(_p): _stargaze())


func _stargaze() -> void:
	if not Game.is_night():
		return
	world.play_minigame("stars", func(found):
		var charted: Array = Game.xarr("stars_found")
		var new_ones := 0
		var coins := 0
		for nm in found:
			if not charted.has(nm):
				charted.append(nm)
				new_ones += 1
				coins += STAR_REWARD
			else:
				coins += 5
		if coins > 0:
			Game.add_coins(coins)
		if new_ones > 0:
			world.hud.show_toast("%d new constellation%s charted! (+%d coins)  %d / 8 in your journal." % [new_ones, "" if new_ones == 1 else "s", coins, charted.size()], 5.0)
		elif coins > 0:
			world.hud.show_toast("A lovely night for stargazing. (+%d coins)" % coins, 3.5)
		else:
			world.hud.show_toast("The stars were shy tonight.", 3.0))


func _build_skip_spot() -> void:
	var root := Node3D.new()
	world.add_child(root)
	root.global_position = SKIP_POS
	for k in 5:
		var st := _ball(root, Vector3(randf_range(-0.2, 0.2), 0.04 + k * 0.05, randf_range(-0.2, 0.2)), 0.14, Color(0.55, 0.57, 0.6).lightened(k * 0.04))
		st.scale = Vector3(1, 0.3, 0.8)
		st.rotation.y = k
	world._spot(SKIP_POS, 1.3, func(_p): return "E: Skip stones", func(_p): _skip())


func _skip() -> void:
	world.play_minigame("skip", func(best: int):
		var record := best > Game.xi("skip_best")
		if record:
			Game.extra["skip_best"] = best
		var msg := "Best throw: %d skips." % best
		if record and best > 0:
			msg += " New record!"
		if Game.xi("skip_day", -1) != Game.day and best > 0:
			Game.extra["skip_day"] = Game.day
			Game.add_coins(best * 3)
			msg += "  (+%d coins)" % (best * 3)
		world.hud.show_toast(msg, 4.0))


func _build_piano() -> void:
	var h: Dictionary = world.interiors.houses["home"]
	var o: Vector3 = h["origin"]
	var w: float = (h["size"] as Vector2).x
	var local := Vector3(-w / 2 + 0.55, 0, -0.1)
	var p := o + local
	var root := Node3D.new()
	world.interiors.add_child(root)
	root.global_position = p
	_box(root, Vector3(0, 0.55, 0), Vector3(0.7, 1.1, 1.8), Color(0.18, 0.12, 0.1))
	_box(root, Vector3(0.38, 0.78, 0), Vector3(0.12, 0.05, 1.6), Color(0.96, 0.95, 0.9))
	for k in 6:
		_box(root, Vector3(0.36, 0.81, -0.62 + k * 0.25), Vector3(0.1, 0.04, 0.12), Color(0.08, 0.08, 0.08))
	_box(root, Vector3(0.9, 0.25, 0), Vector3(0.4, 0.5, 0.9), Color(0.35, 0.22, 0.15))
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.8, 1.1, 1.8)
	col.shape = shape
	col.position.y = 0.55
	body.add_child(col)
	root.add_child(body)
	world._spot(p + Vector3(1.2, 0, 0), 1.4, func(_p): return "E: Play music", func(_p): _music("home"))


func _build_bandstand_spot() -> void:
	# on the stage -- only once the bandstand has been built
	world._spot(world.activities.bandstand_stage(), 2.4,
		func(_p): return "E: Play music on the bandstand" if Game.is_project_funded("bandstand") else "",
		func(_p): _music("bandstand"))


func _music(place: String) -> void:
	world.minigames.music_place = place
	world.play_minigame("music", func(_r): pass)
