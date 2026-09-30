extends Node3D
## Walk-in houses. Every house has a furnished room you enter through its
## front door (press E). The rooms are built far outside the village (they
## never show up in the world) and each has a fixed "dollhouse" camera looking
## in through the missing front wall.
##
## Each room has a minigame station, playable once a day (except cooking):
##   Bram  -- bake bread in his oven         (baking)  -> bread loaves
##   Ivy   -- help in her flower shop         (bouquet) -> bouquets
##   Pip   -- build a block tower             (stack)   -> coins
##   Otto  -- his curio matching game         (pairs)   -> coins
##   Sal   -- sort the day's catch            (sort)    -> coins
##   You   -- cook at your stove (any time, needs ingredients) and sleep in your bed
## The town hall (once built) has the request board, the village records book,
## and the museum: an aquarium and display shelves for everything you donate.
## Villagers lock their doors at night (9 PM - 7 AM). Your house is always open.

const ROOM_ORIGIN := Vector3(-500, 0, 0)
const ROOM_SPACING := 30.0
const ROOM_H := 3.8
const OPEN_FROM := 7.0
const OPEN_UNTIL := 21.0

var world: Node3D           # main.gd
var houses := {}            # id -> {"name", "owner", "outside", "facing", "origin", "size", "camera"}
var current := ""           # id of the house you're in ("" = outside)
var moving := false         # mid fade in/out
var window_mats: Array = []
var was_night := false
var windows_set := false


func build() -> void:
	var i := 0
	for def in world.npc_defs:
		var id: String = (def["name"] as String).to_lower()
		var pos: Vector3 = def["home"]
		var hut: bool = def.get("hut", false)
		_add(id, def["name"], pos, 1.5 if hut else 2.0, i, Color.from_hsv(def["hue"], 0.25, 0.92))
		i += 1
	_add("home", "", world.PLAYER_HOUSE, 2.0, i, Color(0.93, 0.87, 0.75))
	_add("townhall", "", world.townhall.HALL_POS, 2.5, i + 1, Color(0.9, 0.86, 0.78))


func _add(id: String, owner: String, pos: Vector3, half_depth: float, index: int, wall: Color) -> void:
	var facing := -Vector3(pos.x, 0, pos.z).normalized()
	var origin := ROOM_ORIGIN + Vector3(0, 0, index * ROOM_SPACING)
	var size := Vector2(12, 9) if id == "home" else (Vector2(14, 10) if id == "townhall" else Vector2(11, 8.5))
	var h := {"id": id, "owner": owner, "outside": pos + facing * (half_depth + 1.3), "facing": facing,
		"origin": origin, "size": size}
	houses[id] = h
	_build_room(h, wall)
	var door_spot: Vector3 = pos + facing * (half_depth + 0.6)
	world._spot(door_spot, 1.7, _door_prompt.bind(id), func(_p): _try_enter(id))


func _process(delta: float) -> void:
	_swim(delta)
	var night := Game.is_night()
	if night == was_night and windows_set:
		return
	was_night = night
	windows_set = true
	if true:
		var c := Color(0.08, 0.1, 0.25) if night else Color(0.65, 0.85, 1.0)
		for m in window_mats:
			m.albedo_color = c
			m.emission = c
			m.emission_energy_multiplier = 0.3 if night else 0.6


# ================================================================ entering / leaving

func _open(id: String) -> bool:
	if id == "home":
		return true
	if id == "townhall":
		return Game.hall_built()
	var hr := Game.hour()
	return hr >= OPEN_FROM and hr < OPEN_UNTIL


func _door_prompt(_p, id: String) -> String:
	if moving or world.activities.racing or world.activities.counting_down:
		return ""
	var h: Dictionary = houses[id]
	if id == "home":
		return "E: Go inside your house"
	if id == "townhall":
		return "E: Go into the Town Hall" if Game.hall_built() else ""
	if not _open(id):
		return "%s's door is locked. Everyone's asleep." % h["owner"]
	return "E: Go into %s's %s" % [h["owner"], "hut" if id == "sal" else "house"]


func _try_enter(id: String) -> void:
	if moving or not _open(id):
		return
	var h: Dictionary = houses[id]
	moving = true
	world.player.busy = true
	world.hud.show_prompt("")
	Audio.play("click")
	world.hud.fade_through_black(func():
		_place_inside(id)
		if id == "townhall":
			world.hud.show_toast("The Town Hall", 2.0)
		elif id != "home":
			world.hud.show_toast("%s's %s" % [h["owner"], "hut" if id == "sal" else "house"], 2.0))
	await get_tree().create_timer(1.7).timeout
	moving = false
	world.player.busy = false


func _place_inside(id: String) -> void:
	var h: Dictionary = houses[id]
	current = id
	var p: CharacterBody3D = world.player
	var o: Vector3 = h["origin"]
	var sz: Vector2 = h["size"]
	if id == "townhall":
		refresh_museum()
	p.global_position = o + Vector3(0, 1, sz.y / 2 - 2.0)
	p.velocity = Vector3.ZERO
	p.cam_yaw = 0.0
	p.visual.rotation.y = 0.0
	p.fixed_camera = true
	(h["camera"] as Camera3D).current = true


func leave() -> void:
	if moving or current == "":
		return
	moving = true
	world.player.busy = true
	world.hud.show_prompt("")
	Audio.play("click")
	world.hud.fade_through_black(leave_instantly)
	await get_tree().create_timer(1.7).timeout
	moving = false
	world.player.busy = false


## Pop straight back outside the current house (also used when passing out).
func leave_instantly() -> void:
	if current == "":
		return
	var h: Dictionary = houses[current]
	current = ""
	var p: CharacterBody3D = world.player
	p.fixed_camera = false
	p.camera.current = true
	var out: Vector3 = h["outside"]
	p.global_position = Vector3(out.x, 1, out.z)
	p.velocity = Vector3.ZERO
	var f: Vector3 = h["facing"]
	p.cam_yaw = atan2(-f.x, -f.z)
	p.visual.rotation.y = p.cam_yaw


## Where you wake up after sleeping in your bed.
func bed_side() -> Vector3:
	var h: Dictionary = houses["home"]
	return h["origin"] + Vector3(-2.2, 1, 0.3)


# ================================================================ minigame stations

func _station_prompt(_p, id: String) -> String:
	if id != "home" and Game.house_done_today(id):
		return {
			"bram": "The oven is cooling down. Come back tomorrow!",
			"ivy": "The shop is sold out today. Come back tomorrow!",
			"pip": "Pip's blocks are all over the floor. Tomorrow!",
			"otto": "Otto is dusting his curios. Come back tomorrow.",
			"sal": "Today's catch is all sorted. Come back tomorrow!",
		}.get(id, "Come back tomorrow!")
	return {
		"bram": "E: Bake bread in Bram's oven",
		"ivy": "E: Help out in Ivy's flower shop",
		"pip": "E: Build a block tower with Pip",
		"otto": "E: Play Otto's curio matching game",
		"sal": "E: Sort today's catch with Sal",
		"home": "E: Cook at the stove",
	}.get(id, "")


func _play_station(id: String) -> void:
	if id != "home" and Game.house_done_today(id):
		return
	var game_kind: String = {"bram": "baking", "ivy": "bouquet", "pip": "stack", "otto": "pairs", "sal": "sort", "home": "cooking"}[id]
	if id != "home":
		Game.house_day[id] = Game.day
	world.play_minigame(game_kind, func(result): _reward(id, result))


func _reward(id: String, result) -> void:
	var hud = world.hud
	match id:
		"bram":
			var loaves: int = 3 if result else world.minigames.bakes
			if loaves > 0:
				Game.add_item("bread", loaves)
				hud.show_toast("You baked %d loa%s of bread! Sell them at the market." % [loaves, "f" if loaves == 1 else "ves"], 4.0)
			else:
				hud.show_toast("\"Don't worry, even I burn one now and then,\" says Bram.", 3.5)
		"ivy":
			var n: int = result
			if n > 0:
				Game.add_item("bouquet", n)
				hud.show_toast("Ivy lets you keep %d bouquet%s! (%d coins each at the market)" % [n, "" if n == 1 else "s", Game.ITEMS["bouquet"]["sell"]], 4.0)
			else:
				hud.show_toast("\"Flowers are tricky! Try again tomorrow,\" says Ivy.", 3.5)
		"pip":
			var n: int = result
			var pay := n * 5
			Game.add_coins(pay)
			hud.show_toast("A %d-block tower! Pip pays you %d coins from her piggy bank." % [n, pay], 4.0)
		"otto":
			var n: int = result
			var pay := n * 8 + (40 if n >= 6 else 0)
			Game.add_coins(pay)
			hud.show_toast(("You found every pair! Otto gives you %d coins." if n >= 6 else "%d pairs found. Otto gives you " % n + "%d coins.") % pay, 4.0)
		"sal":
			var n: int = result
			var pay := n * 4 + (20 if n >= 15 else 0)
			Game.add_coins(pay)
			hud.show_toast("You sorted %d fish right. Sal pays you %d coins." % [n, pay], 4.0)
		"home":
			var d: Dictionary = result
			if d.is_empty():
				return
			var stars: int = d["stars"]
			var n := 2 if stars == 3 else (1 if stars > 0 else 0)
			if n > 0:
				Game.add_item(d["recipe"], n)
				Game.dishes_cooked += n
				hud.show_toast("Cooked %d %s! (%d coins each at the market)" % [n, Game.item_name(d["recipe"], n > 1).to_lower(), Game.ITEMS[d["recipe"]]["sell"]], 4.0)
			else:
				hud.show_toast("That one got burnt. Try again!", 3.0)


# ================================================================ building the rooms

func _mat(c: Color, emissive := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissive
	return m


func _box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid := false, emissive := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = _mat(color, emissive)
	parent.add_child(mi)
	if solid:
		_solid(parent, pos, size)
	return mi


func _solid(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	parent.add_child(body)


func _cyl(parent: Node3D, pos: Vector3, r: float, h: float, color: Color, top := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r if top < 0.0 else top
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 14
	mi.mesh = c
	mi.position = pos
	mi.material_override = _mat(color)
	parent.add_child(mi)
	return mi


func _ball(parent: Node3D, pos: Vector3, r: float, color: Color, emissive := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = 10
	s.rings = 6
	mi.mesh = s
	mi.position = pos
	mi.material_override = _mat(color, emissive)
	parent.add_child(mi)
	return mi


func _label(parent: Node3D, text: String, pos: Vector3, size := 64, color := Color(1, 0.95, 0.8)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = pos
	l.font_size = size
	l.pixel_size = 0.006
	l.outline_size = 12
	l.modulate = color
	parent.add_child(l)
	return l


func _spot(pos: Vector3, r: float, prompt_f: Callable, action_f: Callable) -> void:
	world._spot(pos, r, prompt_f, action_f)


func _build_room(h: Dictionary, wall: Color) -> void:
	var id: String = h["id"]
	var room := Node3D.new()
	room.position = h["origin"]
	add_child(room)
	var sz: Vector2 = h["size"]
	var w := sz.x
	var d := sz.y
	# floor, walls, ceiling
	_box(room, Vector3(0, -0.1, 0), Vector3(w, 0.2, d), Color(0.62, 0.45, 0.3), true)
	for k in int(w / 0.9):
		_box(room, Vector3(-w / 2 + 0.45 + k * 0.9, 0.003, 0), Vector3(0.04, 0.01, d), Color(0.5, 0.36, 0.24))
	_box(room, Vector3(0, ROOM_H / 2, -d / 2 - 0.1), Vector3(w + 0.4, ROOM_H, 0.2), wall, true)
	_box(room, Vector3(-w / 2 - 0.1, ROOM_H / 2, 0), Vector3(0.2, ROOM_H, d), wall.darkened(0.08), true)
	_box(room, Vector3(w / 2 + 0.1, ROOM_H / 2, 0), Vector3(0.2, ROOM_H, d), wall.darkened(0.08), true)
	_box(room, Vector3(0, ROOM_H + 0.1, 0), Vector3(w + 0.4, 0.2, d), wall.darkened(0.3))
	# baseboards
	_box(room, Vector3(0, 0.08, -d / 2 + 0.02), Vector3(w, 0.16, 0.05), Color(0.45, 0.32, 0.22))
	# an invisible wall keeps you away from the camera
	_solid(room, Vector3(0, 1.5, d / 2 - 0.9), Vector3(w, 3, 0.2))
	# a window on the back wall (sky blue) and a warm ceiling lamp
	for x in [-w / 4, w / 4]:
		_box(room, Vector3(x, 1.9, -d / 2 + 0.01), Vector3(1.3, 1.0, 0.04), Color(0.45, 0.32, 0.22))
		var glass := _box(room, Vector3(x, 1.9, -d / 2 + 0.035), Vector3(1.1, 0.8, 0.02), Color(0.65, 0.85, 1.0), false, 0.6)
		window_mats.append(glass.material_override)
		_box(room, Vector3(x, 1.9, -d / 2 + 0.05), Vector3(0.05, 0.8, 0.02), Color(0.45, 0.32, 0.22))
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, ROOM_H - 0.6, -0.5)
	lamp.light_color = Color(1, 0.88, 0.7)
	lamp.light_energy = 1.4
	lamp.omni_range = 13.0
	lamp.shadow_enabled = true
	room.add_child(lamp)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 2.2, d / 2 - 1.0)
	fill.light_color = Color(1, 0.95, 0.85)
	fill.light_energy = 0.6
	fill.omni_range = 9.0
	room.add_child(fill)
	# rug and the doormat (exit)
	_box(room, Vector3(0, 0.01, 0.6), Vector3(3.2, 0.02, 2.2), wall.darkened(0.45).lerp(Color(0.6, 0.2, 0.2), 0.4))
	var mat_pos := Vector3(0, 0, d / 2 - 1.5)
	_box(room, mat_pos + Vector3(0, 0.015, 0), Vector3(1.4, 0.03, 0.8), Color(0.35, 0.5, 0.3))
	_label(room, "EXIT", mat_pos + Vector3(0, 0.04, 0), 48, Color(1, 1, 0.85)).rotation.x = -PI / 2   # lying on the mat
	_spot(room.position + mat_pos, 1.3, func(_p): return "E: Go outside" if not moving else "", func(_p): leave())
	# camera: sits just inside the open front, looking down into the room
	var cam := Camera3D.new()
	cam.fov = 70.0
	room.add_child(cam)
	cam.position = Vector3(0, ROOM_H - 0.3, d / 2 - 0.15)
	cam.look_at(room.to_global(Vector3(0, 0.2, -1.3)))
	h["camera"] = cam
	# the rest depends on who lives here
	match id:
		"bram":
			_bram(room, h)
		"ivy":
			_ivy(room, h)
		"pip":
			_pip(room, h)
		"otto":
			_otto(room, h)
		"sal":
			_sal(room, h)
		"home":
			_home(room, h)
		"townhall":
			_townhall(room, h)


func _table(room: Node3D, pos: Vector3, top := Color(0.55, 0.38, 0.24)) -> void:
	_box(room, pos + Vector3(0, 0.75, 0), Vector3(1.6, 0.08, 1.0), top, true)
	for sx in [-0.7, 0.7]:
		for sz in [-0.4, 0.4]:
			_box(room, pos + Vector3(sx, 0.37, sz), Vector3(0.08, 0.74, 0.08), top.darkened(0.2))
	for sx in [-1.1, 1.1]:
		_box(room, pos + Vector3(sx, 0.45, 0), Vector3(0.45, 0.06, 0.45), top.darkened(0.1))
		_box(room, pos + Vector3(sx, 0.22, 0), Vector3(0.08, 0.44, 0.08), top.darkened(0.25))
		_box(room, pos + Vector3(sx + sign(sx) * 0.2, 0.75, 0), Vector3(0.06, 0.6, 0.45), top.darkened(0.1))


func _shelf(room: Node3D, pos: Vector3, colors: Array) -> void:
	_box(room, pos + Vector3(0, 1.0, 0), Vector3(1.4, 2.0, 0.4), Color(0.45, 0.3, 0.2), true)
	for row in 3:
		_box(room, pos + Vector3(0, 0.45 + row * 0.6, 0.18), Vector3(1.3, 0.04, 0.05), Color(0.35, 0.24, 0.16))
		for k in 4:
			var c: Color = colors[(row * 4 + k) % colors.size()]
			_box(room, pos + Vector3(-0.45 + k * 0.3, 0.62 + row * 0.6, 0.12), Vector3(0.18, 0.3, 0.2), c)


func _sign(room: Node3D, h: Dictionary, text: String) -> void:
	var d: float = (h["size"] as Vector2).y
	_label(room, text, Vector3(0, 3.05, -d / 2 + 0.06), 80)


func _station(room: Node3D, h: Dictionary, local: Vector3) -> void:
	var id: String = h["id"]
	_spot(room.position + local, 1.5, _station_prompt.bind(id), func(_p): _play_station(id))


# ---------------------------------------------------------------- Bram's bakery

func _bram(room: Node3D, h: Dictionary) -> void:
	var d: float = (h["size"] as Vector2).y
	_sign(room, h, "Bram's Bakery")
	# brick oven with a glowing mouth and a chimney
	var ov := Vector3(-2.6, 0, -d / 2 + 1.0)
	_box(room, ov + Vector3(0, 0.8, 0), Vector3(1.8, 1.6, 1.4), Color(0.7, 0.35, 0.25), true)
	_box(room, ov + Vector3(0, 1.75, 0), Vector3(1.9, 0.3, 1.5), Color(0.55, 0.28, 0.2))
	_box(room, ov + Vector3(0, 0.75, 0.71), Vector3(0.9, 0.6, 0.02), Color(1, 0.5, 0.15), false, 2.5)
	_box(room, ov + Vector3(0, 2.6, -0.3), Vector3(0.4, 1.6, 0.4), Color(0.6, 0.3, 0.22))
	var glow := OmniLight3D.new()
	glow.position = ov + Vector3(0, 0.8, 1.0)
	glow.light_color = Color(1, 0.55, 0.2)
	glow.light_energy = 1.2
	glow.omni_range = 3.0
	room.add_child(glow)
	_station(room, h, ov + Vector3(0, 0, 1.6))
	# a counter full of bread and some flour sacks
	var ct := Vector3(1.8, 0, -d / 2 + 0.7)
	_box(room, ct + Vector3(0, 0.5, 0), Vector3(2.6, 1.0, 0.9), Color(0.55, 0.38, 0.24), true)
	for k in 5:
		var loaf := _ball(room, ct + Vector3(-1.0 + k * 0.5, 1.1, 0), 0.18, Color(0.85, 0.58, 0.28))
		loaf.scale = Vector3(1.4, 0.8, 0.9)
	for k in 3:
		_box(room, Vector3(3.6, 0.35, -0.5 + k * 0.7), Vector3(0.55, 0.7, 0.45), Color(0.95, 0.93, 0.85), true)
	_table(room, Vector3(0.8, 0, 0.6))
	for k in 2:
		_ball(room, Vector3(0.5 + k * 0.6, 0.9, 0.6), 0.14, Color(0.85, 0.58, 0.28)).scale = Vector3(1.4, 0.8, 0.9)


# ---------------------------------------------------------------- Ivy's flower shop

func _ivy(room: Node3D, h: Dictionary) -> void:
	var d: float = (h["size"] as Vector2).y
	var w: float = (h["size"] as Vector2).x
	_sign(room, h, "Ivy's Flowers")
	var colors := [Color(1, 0.45, 0.6), Color(1, 0.85, 0.25), Color(0.55, 0.55, 1), Color(0.97, 0.97, 0.97), Color(1, 0.55, 0.2)]
	# the workbench (station) with a vase
	var wb := Vector3(0, 0, -d / 2 + 0.8)
	_box(room, wb + Vector3(0, 0.5, 0), Vector3(2.4, 1.0, 1.0), Color(0.5, 0.65, 0.4), true)
	_cyl(room, wb + Vector3(0, 1.25, 0), 0.18, 0.5, Color(0.6, 0.8, 0.95), 0.12)
	for k in 7:
		var a := TAU * k / 7.0
		_ball(room, wb + Vector3(cos(a) * 0.18, 1.6 + (k % 2) * 0.1, sin(a) * 0.12), 0.1, colors[k % colors.size()])
	_station(room, h, wb + Vector3(0, 0, 1.4))
	# flower pots along the walls
	for k in 6:
		var side := -1 if k < 3 else 1
		var p := Vector3(side * (w / 2 - 0.5), 0, -d / 2 + 1.2 + (k % 3) * 1.4)
		_cyl(room, p + Vector3(0, 0.25, 0), 0.28, 0.5, Color(0.75, 0.42, 0.3), 0.32)
		_solid(room, p + Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.6))
		_box(room, p + Vector3(0, 0.7, 0), Vector3(0.05, 0.5, 0.05), Color(0.3, 0.6, 0.25))
		for j in 5:
			var a := TAU * j / 5.0
			_ball(room, p + Vector3(cos(a) * 0.12, 1.0, sin(a) * 0.12), 0.09, colors[(k + 1) % colors.size()])
	# hanging baskets
	for x in [-2.5, 2.5]:
		_cyl(room, Vector3(x, 2.6, -1.0), 0.3, 0.3, Color(0.55, 0.4, 0.25), 0.36)
		for j in 6:
			var a := TAU * j / 6.0
			_ball(room, Vector3(x + cos(a) * 0.3, 2.45, -1.0 + sin(a) * 0.3), 0.1, Color(0.35, 0.7, 0.3))
	_table(room, Vector3(1.2, 0, 0.9), Color(0.75, 0.6, 0.45))


# ---------------------------------------------------------------- Pip's playroom

func _pip(room: Node3D, h: Dictionary) -> void:
	var d: float = (h["size"] as Vector2).y
	var w: float = (h["size"] as Vector2).x
	_sign(room, h, "Pip's Room - KEEP OUT (unless fun)")
	var colors := [Color(1, 0.45, 0.4), Color(1, 0.75, 0.3), Color(0.5, 0.85, 0.45), Color(0.4, 0.7, 1), Color(0.75, 0.5, 1)]
	# a wobbly block tower on a play mat (station)
	var mat := Vector3(-1.2, 0, -0.6)
	_box(room, mat + Vector3(0, 0.01, 0), Vector3(2.2, 0.02, 2.0), Color(0.3, 0.6, 0.85))
	for k in 6:
		var b := _box(room, mat + Vector3(sin(k * 1.3) * 0.08, 0.15 + k * 0.28, 0), Vector3(0.5, 0.26, 0.5), colors[k % colors.size()])
		b.rotation.y = k * 0.3
	for k in 5:
		_box(room, mat + Vector3(-0.8 + k * 0.4, 0.13, 0.7), Vector3(0.26, 0.26, 0.26), colors[(k + 2) % colors.size()]).rotation.y = k
	_solid(room, mat + Vector3(0, 0.9, 0), Vector3(0.7, 1.8, 0.7))
	_station(room, h, mat + Vector3(0, 0, 1.4))
	# little bed, a ball and a toy chest
	var bed := Vector3(w / 2 - 1.1, 0, -d / 2 + 1.3)
	_box(room, bed + Vector3(0, 0.25, 0), Vector3(1.3, 0.5, 2.2), Color(0.95, 0.8, 0.3), true)
	_box(room, bed + Vector3(0, 0.55, 0.2), Vector3(1.2, 0.12, 1.6), Color(0.4, 0.7, 1))
	_box(room, bed + Vector3(0, 0.6, -0.8), Vector3(0.9, 0.15, 0.45), Color.WHITE)
	_ball(room, Vector3(1.0, 0.3, 1.0), 0.3, Color(1, 0.35, 0.3))
	var chest := Vector3(-w / 2 + 0.8, 0, -d / 2 + 0.8)
	_box(room, chest + Vector3(0, 0.35, 0), Vector3(1.1, 0.7, 0.7), Color(0.75, 0.45, 0.25), true)
	_box(room, chest + Vector3(0, 0.72, 0), Vector3(1.15, 0.08, 0.75), Color(0.6, 0.35, 0.2))
	# paper stars on the wall
	for k in 5:
		_box(room, Vector3(-2.5 + k * 1.2, 2.3 + sin(k * 2.0) * 0.3, -d / 2 + 0.03), Vector3(0.25, 0.25, 0.02), Color(1, 0.9, 0.4), false, 0.5).rotation.z = 0.78


# ---------------------------------------------------------------- Otto's study

func _otto(room: Node3D, h: Dictionary) -> void:
	var d: float = (h["size"] as Vector2).y
	var w: float = (h["size"] as Vector2).x
	_sign(room, h, "Otto's Curiosities")
	# the curio cabinet (station): a glass-front cabinet full of treasures
	var cab := Vector3(0, 0, -d / 2 + 0.5)
	_box(room, cab + Vector3(0, 1.1, 0), Vector3(2.2, 2.2, 0.6), Color(0.35, 0.22, 0.15), true)
	var treasures := [Color(1, 0.8, 0.3), Color(0.45, 0.7, 1), Color(1, 0.5, 0.7), Color(1, 0.4, 0.3), Color(0.9, 0.9, 0.95), Color(0.5, 0.9, 0.6)]
	for row in 3:
		_box(room, cab + Vector3(0, 0.45 + row * 0.62, 0.2), Vector3(2.0, 0.04, 0.3), Color(0.5, 0.35, 0.22))
		for k in 4:
			_ball(room, cab + Vector3(-0.7 + k * 0.47, 0.6 + row * 0.62, 0.2), 0.11, treasures[(row + k) % treasures.size()], 0.3)
	var glass := _box(room, cab + Vector3(0, 1.1, 0.31), Vector3(2.0, 2.0, 0.02), Color(0.8, 0.9, 1.0))
	var gm: StandardMaterial3D = glass.material_override
	gm.albedo_color = Color(0.8, 0.92, 1.0, 0.18)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.roughness = 0.05
	_station(room, h, cab + Vector3(0, 0, 1.6))
	# armchair, grandfather clock, books
	var ac := Vector3(-w / 2 + 1.3, 0, 0.3)
	_box(room, ac + Vector3(0, 0.3, 0), Vector3(1.1, 0.6, 1.0), Color(0.55, 0.2, 0.25), true)
	_box(room, ac + Vector3(-0.45, 0.8, 0), Vector3(0.2, 1.0, 1.0), Color(0.5, 0.18, 0.22))
	for sz in [-0.45, 0.45]:
		_box(room, ac + Vector3(0, 0.7, sz), Vector3(1.1, 0.2, 0.15), Color(0.5, 0.18, 0.22))
	var clock := Vector3(w / 2 - 0.6, 0, -d / 2 + 0.6)
	_box(room, clock + Vector3(0, 1.1, 0), Vector3(0.6, 2.2, 0.45), Color(0.4, 0.26, 0.16), true)
	_cyl(room, clock + Vector3(0, 1.75, 0.23), 0.2, 0.03, Color(0.95, 0.92, 0.8)).rotation.x = PI / 2
	_shelf(room, Vector3(-w / 2 + 1.2, 0, -d / 2 + 0.3), [Color(0.5, 0.2, 0.2), Color(0.2, 0.3, 0.5), Color(0.3, 0.45, 0.25), Color(0.6, 0.5, 0.2)])
	_table(room, Vector3(1.0, 0, 0.8), Color(0.4, 0.26, 0.16))


# ---------------------------------------------------------------- Sal's hut

func _sal(room: Node3D, h: Dictionary) -> void:
	var d: float = (h["size"] as Vector2).y
	var w: float = (h["size"] as Vector2).x
	_sign(room, h, "Sal's Bait & Tackle")
	# the sorting table (station) with three baskets
	var st := Vector3(0, 0, -d / 2 + 0.9)
	_box(room, st + Vector3(0, 0.45, 0), Vector3(3.0, 0.9, 1.0), Color(0.5, 0.4, 0.3), true)
	var basket_colors := [Color(0.35, 0.6, 0.3), Color(0.45, 0.4, 0.35), Color(0.25, 0.45, 0.75)]
	for k in 3:
		_cyl(room, st + Vector3(-1.0 + k * 1.0, 1.1, 0), 0.35, 0.4, basket_colors[k], 0.42)
	for k in 3:
		var f := _ball(room, st + Vector3(-1.0 + k * 1.0, 1.35, 0), 0.12, [Color(0.7, 0.75, 0.8), Color(0.4, 0.3, 0.2), Color(0.35, 0.6, 0.75)][k])
		f.scale = Vector3(2.0, 0.8, 0.8)
	_station(room, h, st + Vector3(0, 0, 1.5))
	# nets and a life ring on the walls, crates of fish
	_box(room, Vector3(-w / 2 + 0.04, 1.8, -0.8), Vector3(0.02, 1.4, 2.2), Color(0.85, 0.8, 0.65))
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.25
	torus.outer_radius = 0.4
	ring.mesh = torus
	ring.rotation.z = PI / 2
	ring.position = Vector3(w / 2 - 0.05, 1.9, -1.0)
	ring.material_override = _mat(Color(0.95, 0.35, 0.25))
	room.add_child(ring)
	for k in 3:
		var c := Vector3(w / 2 - 0.8, 0, 0.2 + k * 0.8)
		_box(room, c + Vector3(0, 0.3, 0), Vector3(0.8, 0.6, 0.7), Color(0.6, 0.45, 0.3), true)
		for j in 3:
			_ball(room, c + Vector3(-0.2 + j * 0.2, 0.62, 0), 0.08, Color(0.6, 0.7, 0.8)).scale = Vector3(2.0, 0.8, 0.8)
	# a rod rack
	for k in 3:
		_box(room, Vector3(-w / 2 + 0.5 + k * 0.25, 1.3, -d / 2 + 0.2), Vector3(0.03, 2.4, 0.03), Color(0.4, 0.3, 0.2)).rotation.z = 0.08


# ---------------------------------------------------------------- your house

func _home(room: Node3D, h: Dictionary) -> void:
	var d: float = (h["size"] as Vector2).y
	var w: float = (h["size"] as Vector2).x
	home_sign_label = _label(room, home_sign_text(), Vector3(0, 3.05, -d / 2 + 0.06), 80)
	_spot(room.position + Vector3(0.9, 0, -d / 2 + 1.25), 1.1, func(_p): return "E: Change the sign", func(_p):
		world.panels.open_rename("Name your home", "Write anything you like on the sign over your room.", home_sign_text(), func(t):
			Game.extra["home_sign"] = t
			refresh_home_sign()))
	# a framed map of the village on the wall (shows where everything is)
	var mp := Vector3(-1.75, 1.9, -d / 2 + 0.05)
	_box(room, mp, Vector3(1.15, 0.85, 0.04), Color(0.4, 0.28, 0.18))
	_box(room, mp + Vector3(0, 0, 0.025), Vector3(1.0, 0.7, 0.02), Color(0.93, 0.85, 0.65))
	for k in 4:
		_box(room, mp + Vector3(-0.3 + k * 0.2, -0.1 + (k % 2) * 0.2, 0.04), Vector3(0.08, 0.08, 0.01), [Color(0.85, 0.3, 0.3), Color(0.3, 0.6, 0.85), Color(0.4, 0.75, 0.4), Color(0.95, 0.75, 0.2)][k])
	_spot(room.position + Vector3(-1.75, 0, -d / 2 + 1.25), 1.1, func(_p): return "E: Look at the village map", func(_p):
		world.panels.journal_tab = "map"
		world.panels.open_journal())
	# a cushion for the pup
	var pb := Vector3(w / 2 - 1.6, 0, 2.6)
	_cyl(room, pb + Vector3(0, 0.08, 0), 0.55, 0.16, Color(0.75, 0.3, 0.3))
	_cyl(room, pb + Vector3(0, 0.12, 0), 0.4, 0.1, Color(0.95, 0.85, 0.7))
	# kitchen: stove (station) with a pot, counters
	var stove := Vector3(2.4, 0, -d / 2 + 0.6)
	_box(room, stove + Vector3(0, 0.45, 0), Vector3(1.1, 0.9, 0.9), Color(0.25, 0.25, 0.28), true)
	for sx in [-0.25, 0.25]:
		_cyl(room, stove + Vector3(sx, 0.91, 0.1), 0.16, 0.02, Color(0.9, 0.3, 0.15))
	_cyl(room, stove + Vector3(0.25, 1.08, 0.1), 0.2, 0.3, Color(0.55, 0.55, 0.6))
	_box(room, stove + Vector3(0, 0.45, 0.46), Vector3(0.8, 0.5, 0.02), Color(0.15, 0.15, 0.17))
	_box(room, stove + Vector3(1.4, 0.45, 0), Vector3(1.6, 0.9, 0.9), Color(0.85, 0.82, 0.75), true)
	_box(room, stove + Vector3(1.4, 0.92, 0), Vector3(1.7, 0.06, 1.0), Color(0.5, 0.4, 0.3))
	for k in 3:
		_ball(room, stove + Vector3(1.0 + k * 0.35, 1.05, 0), 0.1, [Color(0.9, 0.2, 0.15), Color(1, 0.55, 0.1), Color(0.95, 0.8, 0.3)][k])
	_station(room, h, stove + Vector3(0, 0, 1.4))
	# bed (sleep)
	var bed := Vector3(-w / 2 + 1.3, 0, -d / 2 + 1.5)
	_box(room, bed + Vector3(0, 0.3, 0), Vector3(1.6, 0.6, 2.6), Color(0.5, 0.35, 0.25), true)
	_box(room, bed + Vector3(0, 0.65, 0.25), Vector3(1.5, 0.15, 1.9), Color(0.35, 0.5, 0.8))
	_box(room, bed + Vector3(0, 0.7, -0.95), Vector3(1.1, 0.18, 0.5), Color.WHITE)
	_box(room, bed + Vector3(0, 0.8, -1.3), Vector3(1.6, 1.0, 0.1), Color(0.45, 0.3, 0.2))
	_spot(room.position + bed + Vector3(1.3, 0, 0.3), 1.5,
		func(_p): return "E: Sleep until morning (saves the game)",
		func(_p): world.sleep())
	# table, bookshelf and a plant
	_table(room, Vector3(0.2, 0, 0.8))
	_shelf(room, Vector3(-0.3, 0, -d / 2 + 0.3), [Color(0.6, 0.25, 0.2), Color(0.25, 0.4, 0.6), Color(0.35, 0.55, 0.3), Color(0.8, 0.65, 0.3)])
	var pot := Vector3(w / 2 - 0.5, 0, 1.2)
	_cyl(room, pot + Vector3(0, 0.3, 0), 0.3, 0.6, Color(0.75, 0.42, 0.3), 0.35)
	_ball(room, pot + Vector3(0, 0.95, 0), 0.45, Color(0.3, 0.6, 0.3))


# ---------------------------------------------------------------- the town hall

var home_sign_label: Label3D


func home_sign_text() -> String:
	var t := str(Game.extra.get("home_sign", ""))
	return t if t.strip_edges() != "" else "Home Sweet Home"


func refresh_home_sign() -> void:
	if home_sign_label:
		home_sign_label.text = home_sign_text()


## The village records, one [label, value] per line (shown in the records book).
func records() -> Array:
	return [
		["Fish caught", str(Game.fish_caught)],
		["Crops harvested", str(Game.crops_harvested)],
		["Dishes cooked", str(Game.dishes_cooked)],
		["Requests done", str(Game.xi("board_done"))],
		["Treasures found", str(Game.xi("treasures"))],
		["Things foraged", str(Game.xi("foraged"))],
		["Wood & stone gathered", str(Game.xi("gathered"))],
		["Best stone skip", str(Game.xi("skip_best"))],
		["Best race vs Pip", ("%.1f s" % Game.race_best) if Game.race_best > 0 else "-"],
		["Wishes in the fountain", str(Game.xi("wishes"))],
		["Museum pieces", "%d / %d" % [Game.xarr("museum").size(), Game.museum_items().size()]],
	]


const TANK_Z := Vector2(-4.2, -0.4)     # the aquarium and the display shelves run along the side walls, here
const MUSEUM_COLORS := {
	"wheat": Color(0.95, 0.8, 0.35), "carrot": Color(1, 0.55, 0.15), "pumpkin": Color(1, 0.55, 0.1),
	"tomato": Color(0.9, 0.2, 0.15), "corn": Color(1, 0.85, 0.25), "strawberry": Color(0.95, 0.2, 0.3),
	"berries": Color(0.45, 0.25, 0.7), "mushroom": Color(0.85, 0.35, 0.3), "herb": Color(0.35, 0.65, 0.3),
	"shell": Color(1, 0.85, 0.8), "truffle": Color(0.3, 0.22, 0.18), "pearl": Color(0.97, 0.95, 1.0),
	"gem": Color(0.35, 0.8, 1.0), "old_coin": Color(1, 0.8, 0.3), "relic": Color(0.8, 0.65, 0.35),
	"golden_carp": Color(1, 0.75, 0.2), "moonfish": Color(0.8, 0.85, 1.0),
}
var tank_root: Node3D           # donated fish swim in here
var shelf_root: Node3D          # donated crops, finds and treasures sit here
var tank_fish: Array = []       # [{"node", "z0", "z1", "phase", "speed", "y"}]
var shelf_slots: Array = []     # local positions, in Game.museum_items() order (non-fish only)
var hall_room: Node3D


func _townhall(room: Node3D, h: Dictionary) -> void:
	hall_room = room
	var d: float = (h["size"] as Vector2).y
	var w: float = (h["size"] as Vector2).x
	_sign(room, h, "Town Hall")
	# banners in the villagers' colors, flanking the podium
	var hues := [0.0, 0.36, 0.13, 0.6]
	for k in 4:
		var x: float = [-2.4, -1.6, 1.6, 2.4][k]
		_box(room, Vector3(x, 2.3, -d / 2 + 0.05), Vector3(0.6, 1.3, 0.03), Color.from_hsv(hues[k], 0.55, 0.85))
		_box(room, Vector3(x, 1.62, -d / 2 + 0.05), Vector3(0.6, 0.06, 0.04), Color(1, 0.84, 0.3))
	# a podium, a meeting table and benches
	_box(room, Vector3(0, 0.5, -d / 2 + 1.4), Vector3(1.2, 1.0, 0.7), Color(0.5, 0.33, 0.2), true)
	_box(room, Vector3(0, 1.02, -d / 2 + 1.4), Vector3(1.3, 0.06, 0.8), Color(0.4, 0.26, 0.16))
	_box(room, Vector3(0, 0.75, 0.9), Vector3(4.0, 0.08, 1.1), Color(0.55, 0.38, 0.24), true)
	for x in [-1.7, 1.7]:
		for z in [0.55, 1.25]:
			_box(room, Vector3(x, 0.37, z), Vector3(0.1, 0.74, 0.1), Color(0.45, 0.3, 0.2))
	for z in [0.0, 1.8]:
		_box(room, Vector3(0, 0.4, z), Vector3(3.6, 0.08, 0.4), Color(0.5, 0.35, 0.22), true)
	# the request board (inside copy) on the back wall, left
	var bp := Vector3(-w / 2 + 1.5, 0, -d / 2 + 0.08)
	_box(room, bp + Vector3(0, 1.5, 0), Vector3(1.8, 1.1, 0.1), Color(0.72, 0.55, 0.35))
	for k in 4:
		_box(room, bp + Vector3(-0.6 + k * 0.4, 1.5 + (0.1 if k % 2 == 0 else -0.1), 0.06), Vector3(0.3, 0.34, 0.01), Color(1, 0.95, 0.8))
	_label(room, "REQUESTS", bp + Vector3(0, 2.25, 0.06), 48)
	_spot(room.position + bp + Vector3(0, 0, 1.4), 1.6, func(_p): return "E: Read the request board", func(_p): world.panels.open_board())
	# the village records: a book on a lectern (press E to read it)
	var lp := Vector3(3.2, 0, -d / 2 + 1.7)
	_box(room, lp + Vector3(0, 0.5, 0), Vector3(0.5, 1.0, 0.4), Color(0.4, 0.26, 0.16), true)
	var top := _box(room, lp + Vector3(0, 1.08, 0.02), Vector3(0.7, 0.06, 0.5), Color(0.45, 0.3, 0.18))
	top.rotation.x = 0.35
	var book := _box(room, lp + Vector3(0, 1.14, 0.02), Vector3(0.56, 0.05, 0.4), Color(0.55, 0.15, 0.15))
	book.rotation.x = 0.35
	var pages := _box(room, lp + Vector3(0, 1.17, 0.02), Vector3(0.5, 0.02, 0.36), Color(0.97, 0.94, 0.85))
	pages.rotation.x = 0.35
	_label(room, "RECORDS", lp + Vector3(0, 0.62, 0.21), 34, Color(1, 0.88, 0.55))
	_spot(room.position + lp + Vector3(0, 0, 0.9), 1.5, func(_p): return "E: Read the village records", func(_p): world.panels.open_records())
	# trophies on a little side table beside it
	var tp := Vector3(-3.2, 0, -d / 2 + 1.0)
	_box(room, tp + Vector3(0, 0.45, 0), Vector3(0.8, 0.9, 0.6), Color(0.45, 0.3, 0.2), true)
	for k in 3:
		var cup := _cyl(room, tp + Vector3(-0.25 + k * 0.25, 1.05, 0), 0.08, 0.2 + 0.05 * (k % 2), Color(1, 0.8, 0.3), 0.12)
		(cup.material_override as StandardMaterial3D).metallic = 0.9
		(cup.material_override as StandardMaterial3D).roughness = 0.3
	_build_aquarium(room, w, d)
	_build_museum_shelves(room, w, d)
	refresh_museum()
	var chand := OmniLight3D.new()
	chand.position = Vector3(0, ROOM_H - 0.5, 0.5)
	chand.light_color = Color(1, 0.9, 0.7)
	chand.light_energy = 1.0
	chand.omni_range = 12.0
	room.add_child(chand)


## A long fish tank along the left wall. Every fish you donate swims in it.
func _build_aquarium(room: Node3D, w: float, _d: float) -> void:
	var x := -w / 2 + 0.6
	var z0 := TANK_Z.x
	var z1 := TANK_Z.y
	var zc := (z0 + z1) / 2
	var length := z1 - z0
	# cabinet, sand, rocks and weed
	_box(room, Vector3(x, 0.35, zc), Vector3(1.0, 0.7, length + 0.2), Color(0.35, 0.24, 0.16), true)
	_box(room, Vector3(x, 0.75, zc), Vector3(0.86, 0.1, length), Color(0.9, 0.82, 0.6))
	for k in 5:
		var z := lerpf(z0 + 0.4, z1 - 0.4, k / 4.0)
		_ball(room, Vector3(x + 0.15 * (1 if k % 2 == 0 else -1), 0.84, z), 0.12, Color(0.5, 0.5, 0.55))
		for s in 3:
			var weed := _box(room, Vector3(x - 0.2 + s * 0.2, 1.0, z + 0.3), Vector3(0.04, 0.4 + 0.1 * s, 0.04), Color(0.25, 0.6, 0.35))
			weed.rotation.z = 0.15 * (s - 1)
	# water and glass
	var water := _box(room, Vector3(x, 1.28, zc), Vector3(0.86, 0.96, length), Color(0.35, 0.65, 0.9))
	var wm: StandardMaterial3D = water.material_override
	wm.albedo_color = Color(0.35, 0.65, 0.9, 0.28)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.cull_mode = BaseMaterial3D.CULL_DISABLED
	for zz in [z0, z1]:
		_box(room, Vector3(x, 1.28, zz), Vector3(0.94, 1.02, 0.06), Color(0.3, 0.3, 0.32))
	_box(room, Vector3(x, 1.8, zc), Vector3(0.96, 0.08, length + 0.08), Color(0.3, 0.3, 0.32))
	# a little light over the tank
	var glow := OmniLight3D.new()
	glow.position = Vector3(x + 0.3, 2.0, zc)
	glow.light_color = Color(0.6, 0.85, 1.0)
	glow.light_energy = 0.8
	glow.omni_range = 3.0
	room.add_child(glow)
	var bubbles := CPUParticles3D.new()
	bubbles.position = Vector3(x, 0.85, zc)
	bubbles.amount = 16
	bubbles.lifetime = 1.6
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bubbles.emission_box_extents = Vector3(0.3, 0.0, length / 2 - 0.2)
	bubbles.direction = Vector3.UP
	bubbles.spread = 5.0
	bubbles.gravity = Vector3(0, 0.3, 0)
	bubbles.initial_velocity_min = 0.4
	bubbles.initial_velocity_max = 0.6
	var bm := SphereMesh.new()
	bm.radius = 0.025
	bm.height = 0.05
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.9, 0.97, 1.0, 0.6)
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.material = bmat
	bubbles.mesh = bm
	room.add_child(bubbles)
	var title := _label(room, "AQUARIUM", Vector3(-w / 2 + 0.03, 2.35, zc), 44, Color(0.7, 0.9, 1.0))
	title.rotation.y = PI / 2
	tank_root = Node3D.new()
	room.add_child(tank_root)
	_spot(room.position + Vector3(x + 1.3, 0, z1 - 0.2), 1.5, _museum_prompt, func(_p): world.panels.open_museum())


## Stepped display shelves along the right wall for crops, finds and treasures.
func _build_museum_shelves(room: Node3D, w: float, _d: float) -> void:
	var z0 := TANK_Z.x
	var z1 := TANK_Z.y
	var zc := (z0 + z1) / 2
	var length := z1 - z0
	var wood := Color(0.42, 0.28, 0.18)
	var cloth := Color(0.3, 0.2, 0.45)
	for tier in 3:
		var x := w / 2 - 0.35 - (2 - tier) * 0.32
		var y := 0.45 + tier * 0.38
		_box(room, Vector3(x, y / 2, zc), Vector3(0.34, y, length), wood, true)
		_box(room, Vector3(x, y + 0.01, zc), Vector3(0.34, 0.02, length), cloth)
	var items := Game.museum_items().filter(func(id): return Game.ITEMS[id]["kind"] != "fish")
	shelf_slots = []
	var per_tier := int(ceil(items.size() / 3.0))
	for i in items.size():
		var tier := i / per_tier
		var k := i % per_tier
		var x := w / 2 - 0.35 - (2 - tier) * 0.32
		var y := 0.45 + tier * 0.38 + 0.02
		shelf_slots.append(Vector3(x, y, lerpf(z0 + 0.3, z1 - 0.3, (k + 0.5) / per_tier)))
	var title := _label(room, "MUSEUM", Vector3(w / 2 - 0.03, 2.35, zc), 44, Color(1, 0.88, 0.55))
	title.rotation.y = -PI / 2
	shelf_root = Node3D.new()
	room.add_child(shelf_root)
	_spot(room.position + Vector3(w / 2 - 1.9, 0, z1 - 0.2), 1.5, _museum_prompt, func(_p): world.panels.open_museum())


func _museum_prompt(_p) -> String:
	var ready := 0
	for id in Game.museum_items():
		if not Game.museum_has(id) and Game.count(id) > 0:
			ready += 1
	return "E: Visit the museum  (%d new to donate)" % ready if ready > 0 else "E: Visit the museum"


## Donate one of this item to the museum. Returns the reward text ("" if none).
func donate(id: String) -> String:
	if Game.museum_has(id) or Game.count(id) <= 0 or not Game.museum_items().has(id):
		return ""
	Game.remove_item(id)
	Game.xarr("museum").append(id)
	var msg := ""
	var n: int = Game.xarr("museum").size()
	while Game.xi("museum_rewards") < Game.MUSEUM_REWARDS.size() and n >= int(Game.MUSEUM_REWARDS[Game.xi("museum_rewards")][0]):
		var r: Array = Game.MUSEUM_REWARDS[Game.xi("museum_rewards")]
		Game.extra["museum_rewards"] = Game.xi("museum_rewards") + 1
		Game.add_coins(int(r[1]))
		msg = "%d pieces! The village thanks you: +%d coins" % [int(r[0]), int(r[1])]
		if str(r[2]) != "":
			Game.add_item(r[2])
			msg += " and a %s" % Game.item_name(r[2]).to_lower()
	refresh_museum()
	return msg


## Put the donated pieces on display.
func refresh_museum() -> void:
	if tank_root == null:
		return
	for c in tank_root.get_children():
		c.queue_free()
	for c in shelf_root.get_children():
		c.queue_free()
	tank_fish = []
	var w: float = (houses["townhall"]["size"] as Vector2).x
	var x := -w / 2 + 0.6
	var fish_i := 0
	var slot_i := 0
	for id in Game.museum_items():
		var is_fish: bool = Game.ITEMS[id]["kind"] == "fish"
		if not Game.museum_has(id):
			if not is_fish:
				slot_i += 1
			continue
		if is_fish:
			var f := _fish_model(id)
			tank_root.add_child(f)
			var y := 1.0 + fmod(fish_i * 0.37, 0.6)
			tank_fish.append({"node": f, "phase": fish_i * 1.7, "speed": 0.25 + fmod(fish_i * 0.13, 0.2), "y": y,
				"x": x + (fmod(fish_i * 0.29, 0.5) - 0.25)})
			fish_i += 1
		else:
			var m := _item_model(id)
			m.position = shelf_slots[slot_i]
			shelf_root.add_child(m)
			slot_i += 1


func _fish_model(id: String) -> Node3D:
	var root := Node3D.new()
	var tints: Dictionary = load("res://scripts/house_games.gd").FISH_TINT
	var c: Color = MUSEUM_COLORS.get(id, tints.get(id, Color(0.6, 0.7, 0.8)))
	var big: float = {"swordfish": 1.5, "tuna": 1.4, "eel": 1.3, "catfish": 1.2, "minnow": 0.6, "sardine": 0.7}.get(id, 1.0)
	var body := _ball(root, Vector3.ZERO, 0.1, c, 0.15 if id in ["golden_carp", "moonfish"] else 0.0)
	body.scale = Vector3(0.7, 0.9, 1.8 if id != "eel" else 3.0) * big
	if id == "pufferfish":
		body.scale = Vector3(1.4, 1.4, 1.5)
	var tail := MeshInstance3D.new()
	var tp := PrismMesh.new()
	tp.size = Vector3(0.18, 0.16, 0.03)
	tail.mesh = tp
	tail.position = Vector3(0, 0, -0.2 * big)
	tail.rotation = Vector3(PI / 2, 0, 0)
	tail.material_override = _mat(c.darkened(0.2))
	root.add_child(tail)
	if id == "swordfish":
		var nose := _cyl(root, Vector3(0, 0, 0.32), 0.012, 0.3, c.darkened(0.3), 0.004)
		nose.rotation.x = PI / 2
	_ball(root, Vector3(0.05, 0.03, 0.12 * big), 0.018, Color(0.05, 0.05, 0.05))
	_ball(root, Vector3(-0.05, 0.03, 0.12 * big), 0.018, Color(0.05, 0.05, 0.05))
	return root


## A little model of a crop, forage find or treasure for the shelves.
func _item_model(id: String) -> Node3D:
	var root := Node3D.new()
	var c: Color = MUSEUM_COLORS.get(id, Color(0.8, 0.8, 0.8))
	match id:
		"wheat", "corn":
			for k in 5:
				var st := _cyl(root, Vector3(-0.04 + k * 0.02, 0.14, 0), 0.012, 0.28, c)
				st.rotation.z = (k - 2) * 0.12
			if id == "corn":
				_cyl(root, Vector3(0, 0.12, 0), 0.05, 0.2, c)
				_box(root, Vector3(0.05, 0.1, 0), Vector3(0.02, 0.2, 0.06), Color(0.4, 0.65, 0.3))
		"carrot":
			var cone := _cyl(root, Vector3(0, 0.1, 0), 0.05, 0.2, c, 0.0)
			cone.rotation.z = PI
			_box(root, Vector3(0, 0.24, 0), Vector3(0.04, 0.1, 0.04), Color(0.35, 0.65, 0.3))
		"pumpkin":
			_ball(root, Vector3(0, 0.09, 0), 0.11, c).scale = Vector3(1.2, 0.8, 1.2)
			_cyl(root, Vector3(0, 0.2, 0), 0.015, 0.06, Color(0.35, 0.5, 0.25))
		"mushroom":
			_cyl(root, Vector3(0, 0.06, 0), 0.03, 0.12, Color(0.95, 0.92, 0.85))
			_ball(root, Vector3(0, 0.13, 0), 0.08, c).scale = Vector3(1, 0.55, 1)
		"berries":
			for k in 5:
				_ball(root, Vector3(cos(k * 1.3) * 0.05, 0.05 + 0.03 * (k % 2), sin(k * 1.3) * 0.05), 0.035, c)
		"herb":
			for k in 4:
				var leaf := _box(root, Vector3(0, 0.1, 0), Vector3(0.03, 0.2, 0.08), c)
				leaf.rotation = Vector3(0.3, k * 0.8, 0.2)
		"shell":
			_ball(root, Vector3(0, 0.04, 0), 0.08, c).scale = Vector3(1, 0.45, 0.8)
		"pearl":
			var pr := _ball(root, Vector3(0, 0.06, 0), 0.05, c, 0.2)
			(pr.material_override as StandardMaterial3D).metallic = 0.4
			_ball(root, Vector3(0, 0.02, 0), 0.08, Color(0.8, 0.7, 0.75)).scale = Vector3(1, 0.3, 1)
		"gem":
			var g := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.08
			sm.height = 0.16
			sm.radial_segments = 4
			sm.rings = 1
			g.mesh = sm
			g.position = Vector3(0, 0.1, 0)
			g.material_override = _mat(c, 0.4)
			root.add_child(g)
		"old_coin":
			var coin := _cyl(root, Vector3(0, 0.08, 0), 0.07, 0.015, c)
			coin.rotation.x = 1.2
			(coin.material_override as StandardMaterial3D).metallic = 0.8
		"relic":
			_cyl(root, Vector3(0, 0.09, 0), 0.05, 0.18, c, 0.035)
			var urn := _ball(root, Vector3(0, 0.08, 0), 0.07, c)
			(urn.material_override as StandardMaterial3D).metallic = 0.6
		_:
			_ball(root, Vector3(0, 0.08, 0), 0.08, c)
	return root


## Donated fish swim back and forth in the tank while you're inside.
func _swim(delta: float) -> void:
	if current != "townhall":
		return
	for f in tank_fish:
		var n: Node3D = f["node"]
		if not is_instance_valid(n):
			continue
		f["phase"] = float(f["phase"]) + delta * float(f["speed"])
		var t: float = f["phase"]
		var span := (TANK_Z.y - TANK_Z.x) / 2 - 0.35
		var zc := (TANK_Z.x + TANK_Z.y) / 2
		var z := zc + sin(t) * span
		var heading := cos(t)   # + means swimming toward +z
		n.position = Vector3(float(f["x"]) + sin(t * 2.3) * 0.08, float(f["y"]) + sin(t * 3.1) * 0.05, z)
		n.rotation.y = 0.0 if heading >= 0.0 else PI
