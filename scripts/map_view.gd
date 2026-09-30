extends Control
## A hand-drawn-looking top-down map of the village for the treasure hunt:
## parchment, the sea to the east, paths, houses, the pond, the farm, the
## market, the dock -- plus a red X on the treasure and an arrow for you.
## North (-Z in the world) is up.

var world: Node3D
var treasure := Vector3.INF
## Guide mode: [{"pos": Vector3, "n": number (0 = small dot), "color": Color}]
var markers: Array = []
var show_player := true
const SPAN := 36.0     # world meters from the center to the edge of the map


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()


func _to_map(p: Vector3) -> Vector2:
	var s := size.x / (SPAN * 2.0)
	return size / 2 + Vector2(p.x, p.z) * s


## Same, but kept inside the map (for markers near the edge).
func _to_map_inside(p: Vector3, margin := 11.0) -> Vector2:
	var m := _to_map(p)
	return Vector2(clampf(m.x, margin, size.x - margin), clampf(m.y, margin, size.y - margin))


func _draw() -> void:
	if world == null:
		return
	var ink := Color(0.45, 0.3, 0.18)
	var sc := size.x / (SPAN * 2.0)
	# parchment
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.93, 0.85, 0.65))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.7, 0.55, 0.35), false, 3.0)
	# the sea (east) and the beach
	var sea := PackedVector2Array()
	var sand := PackedVector2Array()
	for i in 31:
		var a := lerpf(-0.95, 0.95, i / 30.0)
		var r: float = world.scenery.shore_radius(a)
		if r < 0:
			continue
		sea.append(_to_map(Vector3(cos(a), 0, sin(a)) * r))
		sand.append(_to_map(Vector3(cos(a), 0, sin(a)) * (r - 5.0)))
	# drawn as strips of quads (one big polygon can fail to triangulate)
	for i in sea.size() - 1:
		draw_colored_polygon(PackedVector2Array([sand[i], sand[i + 1], sea[i + 1], sea[i]]), Color(0.95, 0.86, 0.6))
		draw_colored_polygon(PackedVector2Array([sea[i], sea[i + 1], Vector2(size.x, sea[i + 1].y), Vector2(size.x, sea[i].y)]), Color(0.55, 0.75, 0.85))
	if sea.size() > 0:
		draw_rect(Rect2(Vector2(sea[0].x, 0), Vector2(size.x - sea[0].x, sea[0].y)), Color(0.55, 0.75, 0.85))
		var last: Vector2 = sea[sea.size() - 1]
		draw_rect(Rect2(Vector2(last.x, last.y), Vector2(size.x - last.x, size.y - last.y)), Color(0.55, 0.75, 0.85))
		draw_polyline(sea, Color(0.35, 0.55, 0.7), 2.0)
	# the village edge
	draw_arc(size / 2, 30.0 * sc, 0, TAU, 48, Color(0.55, 0.65, 0.35, 0.8), 2.0)
	# paths
	for dest in world.path_dests:
		draw_line(_to_map(Vector3.ZERO), _to_map(dest), Color(0.75, 0.6, 0.4), 4.0)
	# pond
	draw_circle(_to_map(world.POND_CENTER), world.POND_RADIUS * sc, Color(0.5, 0.72, 0.85))
	draw_arc(_to_map(world.POND_CENTER), world.POND_RADIUS * sc, 0, TAU, 24, Color(0.35, 0.55, 0.7), 1.5)
	# farm
	var fc: Vector2 = _to_map(world.FARM_CENTER)
	draw_rect(Rect2(fc - Vector2(4, 3) * sc, Vector2(8, 6) * sc), Color(0.6, 0.45, 0.3))
	draw_rect(Rect2(fc - Vector2(4, 3) * sc, Vector2(8, 6) * sc), ink, false, 1.5)
	# dock
	var d: Vector3 = world._dock_dir()
	draw_line(_to_map(d * world.DOCK_START), _to_map(d * world.DOCK_END), Color(0.55, 0.4, 0.25), 4.0)
	# houses, market, well
	var font := ThemeDB.fallback_font
	for def in world.npc_defs:
		_house(def["home"], def["name"], ink, font)
	_house(world.PLAYER_HOUSE, "You", Color(0.2, 0.35, 0.6), font)
	var m: Vector2 = _to_map(world.MARKET_POS)
	draw_rect(Rect2(m - Vector2(6, 4), Vector2(12, 8)), Color(0.85, 0.35, 0.3))
	draw_string(font, m + Vector2(-20, -8), "Market", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
	draw_circle(_to_map(Vector3.ZERO), 4.0, Color(0.4, 0.55, 0.8))
	# the town hall (or its construction site)
	var th: Vector2 = _to_map(world.townhall.HALL_POS)
	if Game.hall_built():
		draw_rect(Rect2(th - Vector2(9, 7), Vector2(18, 14)), Color(0.35, 0.45, 0.6))
	else:
		draw_rect(Rect2(th - Vector2(9, 7), Vector2(18, 14)), ink, false, 1.5)
	draw_string(font, th + Vector2(-12, 20), "Hall", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
	# compass
	draw_string(font, Vector2(size.x - 22, 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ink)
	draw_line(Vector2(size.x - 17, 22), Vector2(size.x - 17, 38), ink, 2.0)
	# the treasure
	if treasure != Vector3.INF:
		var x: Vector2 = _to_map(treasure)
		draw_line(x + Vector2(-8, -8), x + Vector2(8, 8), Color(0.85, 0.15, 0.1), 4.0)
		draw_line(x + Vector2(8, -8), x + Vector2(-8, 8), Color(0.85, 0.15, 0.1), 4.0)
	# guide markers: small dots first, numbered circles on top
	for mk in markers:
		if int(mk["n"]) == 0:
			draw_circle(_to_map_inside(mk["pos"], 3.0), 2.6, mk["color"])
	for mk in markers:
		if int(mk["n"]) > 0:
			var c: Vector2 = _to_map_inside(mk["pos"])
			draw_circle(c, 9.0, Color(0.2, 0.15, 0.1))
			draw_circle(c, 7.5, mk["color"])
			var txt := str(mk["n"])
			draw_string(font, c + Vector2(-3.5 * txt.length(), 4.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	# you (only while you're outside)
	var pl: CharacterBody3D = world.player
	if show_player and world.interiors.current == "":
		var pp: Vector2 = _to_map(pl.global_position)
		var yaw: float = pl.visual.rotation.y
		var fwd := Vector2(-sin(yaw), -cos(yaw))
		var side := Vector2(-fwd.y, fwd.x)
		draw_colored_polygon(PackedVector2Array([pp + fwd * 9, pp - fwd * 5 + side * 6, pp - fwd * 5 - side * 6]), Color(0.55, 0.3, 0.8))


func _house(pos: Vector3, label: String, ink: Color, font: Font) -> void:
	var h: Vector2 = _to_map(pos)
	draw_rect(Rect2(h - Vector2(5, 5), Vector2(10, 10)), Color(0.8, 0.45, 0.35))
	draw_colored_polygon(PackedVector2Array([h + Vector2(-7, -5), h + Vector2(7, -5), h + Vector2(0, -11)]), Color(0.6, 0.25, 0.2))
	draw_string(font, h + Vector2(-14, 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
