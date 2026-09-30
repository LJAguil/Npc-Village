extends Node3D
## Things to do around the village besides quests (mostly for after the
## festival, but some open up earlier):
##   * Crab Rocks on the beach    -- the crab-catching minigame, once a day
##   * Pip's checkpoint race      -- race Pip through glowing rings (after her tag quest)
##   * Fireflies                  -- come out at night; sneak up and catch them
##   * Village projects board     -- beside the market: spend coins on flower
##                                   beds, a fountain, a bandstand and a golden
##                                   statue (after the festival)
##   * Sprinklers on the farm     -- visible once you buy them
## main.gd creates this node, calls build() while building the village, and
## refresh() after loading or funding something.

const NPC := preload("res://scripts/npc.gd")
const VISUAL_SCRIPT := preload("res://scripts/character_visual.gd")
const FIREFLY_SCRIPT := preload("res://scripts/firefly.gd")
const PROJECTS_UI := preload("res://scripts/projects_ui.gd")

# Where things go. The dirt paths leave the well at about 7, 45, 90, 104, 135,
# 185, 225, 270 and 315 degrees. Flower beds hug the square, Pip's race loops
# around just outside them, and the bigger projects sit further out, in the
# gaps between the paths.
const BOARD_POS := Vector3(-3.6, 0, -15.6)      # beside the market (the request board is on the other side)
const RACE_SIGN_AT := Vector2(160, 7.6)         # (angle in degrees, distance from the well): the open lawn by the square
const RACE_START_R := 4.6                       # the start / finish line is painted on the square
const RACE_GAPS := [200, 248, 293, 338, 24, 67, 119]   # checkpoint order (counter-clockwise from the start)
const RACE_RING_R := Vector2(10.0, 13.5)        # rings go this far from the well (as far out as there's room)
const FOUNTAIN_POS := Vector3(6.3, 0, 15.6)     # its own little court between Pip's path and yours
const FOUNTAIN_COURT := 3.4
const BANDSTAND_POS := Vector3(-15.2, 0, 6.4)   # between Otto's path and the pond, facing the square
const BANDSTAND_COURT := 3.9
const STATUE_POS := Vector3(15.2, 0, 7.4)       # between the dock path and Pip's path
const STATUE_COURT := 2.9
const STATUE_ARM := -1.3                        # how the statue's arms are posed (radians)
const STATUE_HIP := -0.6
const BED_INNER := 7.05                         # flower beds hug the square
const BED_OUTER := 8.55
const CRAB_ANGLE := -0.5        # radians, on the north-east beach

const RACE_PIP_SPEED := 4.0     # the player runs at 5.0
const RACE_PRIZE := 50
const RACE_TIME_LIMIT := 90.0
const MAX_FIREFLIES := 8

var world: Node3D               # main.gd
var crab_spot := Vector3.ZERO
var decor := {}                 # project id -> Node3D (hidden until funded)
var decor_landmarks := {}       # project id -> landmark dict (named once funded)
var landmark_names := {"gardens": "the flower gardens", "fountain": "the fountain", "bandstand": "the bandstand", "statue": "the golden statue"}
var projects_ui: CanvasLayer
var sprinklers: Node3D
var sprays: Array = []

# race state
var race_rings: Array = []      # MeshInstance3D per checkpoint
var race_route: Array = []      # Vector3 per checkpoint (the last one is the finish)
var race_start := Vector3.ZERO
var racing := false
var counting_down := false
var race_time := 0.0
var race_next := 0

# fireflies
var fireflies: Array = []
var firefly_timer := 0.0


static func polar(at: Vector2) -> Vector3:
	var a := deg_to_rad(at.x)
	return Vector3(cos(a), 0, sin(a)) * at.y


# ================================================================ building

func build() -> void:
	_build_board()
	_build_crab_rocks()
	_build_gardens()
	_build_fountain()
	_build_bandstand()
	_build_statue()
	_build_sprinklers()


func setup_ui() -> void:
	projects_ui = CanvasLayer.new()
	projects_ui.set_script(PROJECTS_UI)
	add_child(projects_ui)
	projects_ui.closed.connect(func():
		world.menus.can_pause = true
		world.player.busy = false
		Game.time_running = true
		world.update_quest_log())
	projects_ui.funded.connect(func(id):
		refresh()
		world.hud.show_toast("The %s is finished! The villagers are thrilled." % Game.project_info(id)["name"], 4.0)
		Game.save_game())


## Show funded projects and owned upgrades (after loading, funding, buying).
func refresh() -> void:
	for id in decor:
		var on := Game.is_project_funded(id)
		decor[id].visible = on
		var col: Node = decor[id].get_node_or_null("Body")
		if col is StaticBody3D:
			(col as StaticBody3D).process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
		decor_landmarks[id]["name"] = landmark_names[id] if on else ""
	sprinklers.visible = Game.upgrades.get("sprinklers", false)


func bandstand_spot() -> Vector3:
	return BANDSTAND_POS if Game.is_project_funded("bandstand") else Vector3.INF


func _landmark(id: String, pos: Vector3, radius: float) -> void:
	var lm := {"name": "", "pos": pos, "radius": radius}
	world.landmarks.append(lm)
	if id != "":
		decor_landmarks[id] = lm


## fade = true for tall things that may block the camera (they dither out up close).
func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, emissive := 0.0, metal := false, fade := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var m: StandardMaterial3D = world._mat(color, fade)
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emissive
	if metal:
		m.metallic = 0.9
		m.roughness = 0.25
	mi.material_override = m
	parent.add_child(mi)
	return mi


func _cyl(top: float, bottom: float, h: float, sides := 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return c


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _sign(parent: Node3D, text: String, pos: Vector3, facing: Vector3, board_color := Color(0.62, 0.45, 0.28)) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = atan2(facing.x, facing.z)
	parent.add_child(root)
	var wood := Color(0.45, 0.32, 0.2)
	_mesh(root, _box(Vector3(0.12, 1.4, 0.12)), Vector3(0, 0.7, 0), wood)
	_mesh(root, _box(Vector3(1.1, 0.6, 0.08)), Vector3(0, 1.35, 0.05), board_color)
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.005
	l.outline_size = 10
	l.position = Vector3(0, 1.35, 0.1)
	l.visibility_range_end = 14.0
	root.add_child(l)


# ---------------------------------------------------------------- projects board

func _build_board() -> void:
	var pos := BOARD_POS
	var facing := -pos.normalized()      # faces the well
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = atan2(facing.x, facing.z)
	add_child(root)
	var wood := Color(0.45, 0.32, 0.2)
	for x in [-0.8, 0.8]:
		_mesh(root, _box(Vector3(0.14, 2.0, 0.14)), Vector3(x, 1.0, 0), wood)
	_mesh(root, _box(Vector3(1.9, 1.1, 0.1)), Vector3(0, 1.35, 0), Color(0.55, 0.4, 0.25))
	_mesh(root, _box(Vector3(2.1, 0.12, 0.3)), Vector3(0, 1.97, 0), Color(0.3, 0.45, 0.25))
	# pinned-up papers
	var papers := [Color(0.95, 0.92, 0.8), Color(0.9, 0.85, 1.0), Color(1.0, 0.9, 0.8), Color(0.85, 1.0, 0.85)]
	for i in 4:
		_mesh(root, _box(Vector3(0.36, 0.42, 0.01)), Vector3(-0.66 + i * 0.44, 1.25 + (0.06 if i % 2 == 0 else -0.04), 0.06), papers[i])
	var l := Label3D.new()
	l.text = "Village Projects"
	l.font_size = 48
	l.pixel_size = 0.005
	l.outline_size = 12
	l.position = Vector3(0, 1.72, 0.07)
	l.visibility_range_end = 16.0
	root.add_child(l)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9, 2.0, 0.3)
	col.shape = shape
	col.position.y = 1.0
	body.add_child(col)
	root.add_child(body)
	_landmark("", pos, 1.1)
	world._spot(pos + facing * 1.0, 1.8,
		func(_p): return "E: Village projects board" if Game.won else "E: Read the projects board",
		func(_p): _open_board())


func _open_board() -> void:
	if not Game.won:
		Audio.play("click")
		world.hud.show_toast("\"BIG PLANS for after the Harvest Festival: gardens, a fountain, a bandstand... Donations welcome!\"", 5.0)
		return
	world.player.busy = true
	Game.time_running = false
	world.menus.can_pause = false   # Esc closes the board instead of pausing
	world.hud.show_prompt("")
	Audio.play("click")
	projects_ui.open_board()


# ---------------------------------------------------------------- shared bits for the projects

## Everything solid in a project goes under one StaticBody3D called "Body"
## (refresh() switches it off until the project is funded).
func _body_of(root: Node3D) -> StaticBody3D:
	var b := root.get_node_or_null("Body") as StaticBody3D
	if b == null:
		b = StaticBody3D.new()
		b.name = "Body"
		root.add_child(b)
	return b


## A cylinder collider standing on the ground at local position pos.
func _col_cyl(root: Node3D, pos: Vector3, radius: float, height: float) -> void:
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	col.shape = shape
	col.position = pos + Vector3(0, height / 2, 0)
	_body_of(root).add_child(col)


func _col_box(root: Node3D, pos: Vector3, size: Vector3, basis := Basis()) -> void:
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	col.transform = Transform3D(basis, pos)
	_body_of(root).add_child(col)


## A round cobbled court (like the village square, but smaller) with a low
## stone curb. entrance = local angle (radians) where the curb leaves a gap.
func _court(root: Node3D, radius: float, seed_n: int, entrance := INF) -> void:
	var cobble := BoxMesh.new()
	cobble.size = Vector3(0.38, 0.04, 0.38)
	var cm := StandardMaterial3D.new()
	cm.vertex_color_use_as_albedo = true
	cm.vertex_color_is_srgb = true
	cobble.material = cm
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var xforms := []
	var cols := []
	var r := 0.25
	while r < radius:
		var n := maxi(int(TAU * r / 0.43), 3)
		var off := rng.randf() * TAU
		for i in n:
			var a := off + TAU * i / n
			xforms.append(Transform3D(Basis(Vector3.UP, -a + rng.randf_range(-0.08, 0.08)), Vector3(cos(a) * r, 0.025, sin(a) * r)))
			cols.append(Color(0.7, 0.66, 0.6).lerp(Color(0.82, 0.78, 0.7), rng.randf()).darkened(rng.randf() * 0.12))
		r += 0.42
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cobble
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, cols[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	_mesh(root, _cyl(radius + 0.15, radius + 0.15, 0.02, 40), Vector3(0, 0.01, 0), Color(0.52, 0.49, 0.44))
	var curb := _box(Vector3(0.5, 0.12, 0.24))
	var steps := int(TAU * (radius + 0.12) / 0.52)
	var curb_mat: StandardMaterial3D = world._mat(Color(0.6, 0.58, 0.54), false)
	for i in steps:
		var a := TAU * i / steps
		if entrance != INF and abs(wrapf(a - entrance, -PI, PI)) < 0.62 / radius:
			continue
		var c := MeshInstance3D.new()
		c.mesh = curb
		c.position = Vector3(cos(a), 0, sin(a)) * (radius + 0.12) + Vector3(0, 0.06, 0)
		c.rotation.y = -a + PI / 2
		c.material_override = curb_mat
		root.add_child(c)


## Stepping stones from the nearest dirt path to the edge of a court.
## Returns the local angle where they arrive (for the gap in the curb).
func _stones_to_path(root: Node3D, center: Vector3, court_r: float) -> float:
	var best := Vector3.ZERO
	var best_d := INF
	for dest in world.path_dests:
		var d: Vector3 = dest
		var t: float = clamp(center.dot(d) / d.length_squared(), 0.0, 1.0)
		var q := d * t
		var dd := Vector2(center.x - q.x, center.z - q.z).length()
		if dd < best_d:
			best_d = dd
			best = q
	var dir := (best - center)
	dir.y = 0
	dir = dir.normalized()
	var from := center + dir * (court_r + 0.35)
	var to := best - dir * 0.75
	var length := (to - from).length()
	var stone_mesh := _cyl(0.27, 0.3, 0.05, 7)
	var inv := root.transform.affine_inverse()
	if (to - from).dot(dir) > 0.1:
		var n := maxi(1, int(round(length / 0.62)))
		for i in n:
			var p := from.lerp(to, (i + 0.5) / n) + Vector3(0, 0.025, 0)
			var s := _mesh(root, stone_mesh, inv * p, Color(0.66, 0.64, 0.6).darkened(0.05 * (i % 2)))
			s.rotation.y = i * 1.3
	var local_dir: Vector3 = inv.basis * dir
	return atan2(local_dir.z, local_dir.x)


## Animated water (gentle ripples and glints).
var _water_shader: Shader
func _water(root: Node3D, radius: float, y: float) -> MeshInstance3D:
	if _water_shader == null:
		_water_shader = Shader.new()
		_water_shader.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque;
uniform vec4 deep : source_color = vec4(0.16, 0.42, 0.66, 1.0);
uniform vec4 shallow : source_color = vec4(0.5, 0.82, 0.95, 1.0);
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float r = length(lp.xz);
	float ring = sin(r * 16.0 - TIME * 3.2) * 0.5 + 0.5;
	float chop = sin(lp.x * 9.0 + TIME * 1.7) * sin(lp.z * 8.0 - TIME * 1.3) * 0.5 + 0.5;
	float k = ring * 0.55 + chop * 0.45;
	ALBEDO = mix(deep.rgb, shallow.rgb, k * 0.6);
	EMISSION = vec3(0.7, 0.9, 1.0) * pow(k, 10.0) * 0.5;
	ROUGHNESS = 0.06;
	METALLIC = 0.15;
	SPECULAR = 0.8;
	ALPHA = 0.86;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = _water_shader
	var mi := MeshInstance3D.new()
	mi.mesh = _cyl(radius, radius, 0.02, 32)
	mi.position = Vector3(0, y, 0)
	mi.material_override = mat
	root.add_child(mi)
	return mi


var _drop_mesh: SphereMesh
func _water_particles(root: Node3D, pos: Vector3, amount: int, lifetime: float) -> CPUParticles3D:
	if _drop_mesh == null:
		_drop_mesh = SphereMesh.new()
		_drop_mesh.radius = 0.035
		_drop_mesh.height = 0.07
		_drop_mesh.radial_segments = 6
		_drop_mesh.rings = 3
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color(0.75, 0.9, 1.0, 0.75)
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_drop_mesh.material = dm
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = lifetime
	p.mesh = _drop_mesh
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.1
	root.add_child(p)
	return p


## A sheet of water spilling over the lip of a round bowl.
func _water_curtain(root: Node3D, y: float, radius: float, amount: int, fall: float) -> void:
	var p := _water_particles(root, Vector3(0, y, 0), amount, sqrt(2.0 * fall / 9.0))
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = radius
	p.emission_ring_inner_radius = radius * 0.97
	p.emission_ring_height = 0.0
	p.direction = Vector3.DOWN
	p.spread = 5.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.3
	p.radial_accel_min = 1.2
	p.radial_accel_max = 1.8


## A park bench, facing +z of its own little node.
func _bench(root: Node3D, pos: Vector3, facing_angle: float) -> void:
	var b := Node3D.new()
	b.position = pos
	b.rotation.y = facing_angle
	root.add_child(b)
	var wood := Color(0.62, 0.42, 0.26)
	var iron := Color(0.18, 0.18, 0.2)
	for k in 3:
		_mesh(b, _box(Vector3(1.3, 0.05, 0.12)), Vector3(0, 0.46, -0.13 + k * 0.13), wood)
	for k in 2:
		_mesh(b, _box(Vector3(1.3, 0.1, 0.04)), Vector3(0, 0.66 + k * 0.14, -0.24), wood).rotation.x = -0.12
	for x in [-0.55, 0.55]:
		_mesh(b, _box(Vector3(0.06, 0.46, 0.06)), Vector3(x, 0.23, 0.1), iron)
		_mesh(b, _box(Vector3(0.06, 0.9, 0.06)), Vector3(x, 0.45, -0.22), iron)
		_mesh(b, _box(Vector3(0.06, 0.05, 0.42)), Vector3(x, 0.5, -0.03), iron)


## A terracotta pot with a clipped shrub and a few flowers in it.
func _planter(root: Node3D, pos: Vector3, flower: Color) -> void:
	_mesh(root, _cyl(0.34, 0.26, 0.42, 14), pos + Vector3(0, 0.21, 0), Color(0.72, 0.4, 0.26))
	_mesh(root, _cyl(0.36, 0.36, 0.06, 14), pos + Vector3(0, 0.42, 0), Color(0.62, 0.34, 0.22))
	var shrub := _mesh(root, _ball(0.36), pos + Vector3(0, 0.72, 0), Color(0.28, 0.52, 0.24))
	shrub.scale = Vector3(1, 0.9, 1)
	for k in 5:
		var a := TAU * k / 5.0 + pos.x
		_mesh(root, _ball(0.07), pos + Vector3(cos(a) * 0.3, 0.8 + 0.08 * (k % 2), sin(a) * 0.3), flower, 0.15)


func _ball(radius: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2
	s.radial_segments = 10
	s.rings = 6
	return s


## String of little light bulbs between two points, sagging in the middle.
func _bulbs(root: Node3D, a: Vector3, b: Vector3, n: int, sag: float, bulb_mesh: Mesh, colors: Array) -> void:
	for i in n:
		var t := (i + 0.5) / n
		var p := a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		_mesh(root, bulb_mesh, p, colors[i % colors.size()], 2.2)


# ---------------------------------------------------------------- flower gardens

## Curved flower beds around the edge of the square, one in each gap between
## the paths: a stone kerb, dark soil, tall lavender and hollyhocks at the
## back, tulips in the middle and daisies along the front, with a clipped
## shrub at each end.
func _build_gardens() -> void:
	var root := Node3D.new()
	add_child(root)
	decor["gardens"] = root
	var path_angles := []
	for dest in world.path_dests:
		var d: Vector3 = dest
		path_angles.append(fposmod(atan2(d.z, d.x), TAU))
	path_angles.sort()
	var mid_r := (BED_INNER + BED_OUTER) / 2
	var margin := 1.25 / mid_r      # keep clear of the path edges
	var beds := []
	for i in path_angles.size():
		var a1: float = path_angles[i] + margin
		var a2: float = (path_angles[(i + 1) % path_angles.size()] + (TAU if i == path_angles.size() - 1 else 0.0)) - margin
		if a2 - a1 < 0.22:
			continue      # too small a gap
		var lawn := deg_to_rad(RACE_SIGN_AT.x)
		if (lawn > a1 and lawn < a2) or (lawn + TAU > a1 and lawn + TAU < a2):
			continue      # the open lawn by the race sign, in front of the bandstand
		# stay clear of anything solid (e.g. the big oak)
		var blocked := false
		for k in 9:
			var a := lerpf(a1, a2, k / 8.0)
			var p := Vector3(cos(a), 0, sin(a)) * mid_r
			if not world.is_clear(p, 0.9, true):
				blocked = true
		if not blocked:
			beds.append([a1, a2])
	garden_beds = beds

	var soil_mat: StandardMaterial3D = world._mat(Color(0.38, 0.27, 0.17), false)
	soil_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var kerb_mat: StandardMaterial3D = world._mat(Color(0.66, 0.62, 0.56), false)
	var kerb := _box(Vector3(0.36, 0.16, 0.16))
	var themes := [[Color(1.0, 0.42, 0.55), Color(0.62, 0.48, 0.9)], [Color(1.0, 0.82, 0.25), Color(0.95, 0.5, 0.75)],
		[Color(0.95, 0.35, 0.3), Color(0.55, 0.45, 0.95)], [Color(1.0, 0.6, 0.25), Color(0.75, 0.45, 0.85)]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 919
	# flower parts drawn with MultiMesh (hundreds of them)
	var stems := []
	var tulips := []
	var tulip_c := []
	var petals := []
	var petal_c := []
	var centres := []
	var spikes := []
	var spike_c := []
	var holly := []
	var holly_c := []
	var leaves := []
	var leaf_c := []
	for b in beds.size():
		var a1: float = beds[b][0]
		var a2: float = beds[b][1]
		var theme: Array = themes[b % themes.size()]
		# soil: a curved strip
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var segs := int((a2 - a1) * mid_r / 0.3) + 2
		for k in segs:
			var t0 := lerpf(a1, a2, float(k) / segs)
			var t1 := lerpf(a1, a2, float(k + 1) / segs)
			var p0 := Vector3(cos(t0), 0, sin(t0))
			var p1 := Vector3(cos(t1), 0, sin(t1))
			var y := Vector3(0, 0.1, 0)
			st.set_normal(Vector3.UP)
			st.add_vertex(p0 * BED_INNER + y)
			st.add_vertex(p1 * BED_OUTER + y)
			st.add_vertex(p0 * BED_OUTER + y)
			st.add_vertex(p0 * BED_INNER + y)
			st.add_vertex(p1 * BED_INNER + y)
			st.add_vertex(p1 * BED_OUTER + y)
		var soil := MeshInstance3D.new()
		soil.mesh = st.commit()
		soil.material_override = soil_mat
		root.add_child(soil)
		# kerb stones along both edges and across the ends
		for edge_r in [BED_INNER - 0.06, BED_OUTER + 0.06]:
			var n := int((a2 - a1) * edge_r / 0.37) + 1
			for k in n + 1:
				var a := lerpf(a1, a2, float(k) / n)
				var c := MeshInstance3D.new()
				c.mesh = kerb
				c.material_override = kerb_mat
				c.position = Vector3(cos(a), 0, sin(a)) * edge_r + Vector3(0, 0.08, 0)
				c.rotation.y = -a + PI / 2
				root.add_child(c)
		for a in [a1, a2]:
			for k in 4:
				var c := MeshInstance3D.new()
				c.mesh = kerb
				c.material_override = kerb_mat
				c.position = Vector3(cos(a), 0, sin(a)) * lerpf(BED_INNER + 0.12, BED_OUTER - 0.12, k / 3.0) + Vector3(0, 0.08, 0)
				c.rotation.y = -a
				root.add_child(c)
			# a clipped shrub at each end
			var sp := Vector3(cos(a), 0, sin(a)) * mid_r
			sp += Vector3(-sin(a), 0, cos(a)) * (0.42 if a == a1 else -0.42)
			_mesh(root, _ball(0.42), sp + Vector3(0, 0.45, 0), Color(0.24, 0.48, 0.22)).scale = Vector3(1, 1.1, 1)
		# leafy ground cover so the soil only peeks through
		var area := (a2 - a1) * mid_r * (BED_OUTER - BED_INNER)
		for k in int(area / 0.06):
			var a := rng.randf_range(a1 + 0.3 / mid_r, a2 - 0.3 / mid_r)
			var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(BED_INNER + 0.15, BED_OUTER - 0.15)
			leaves.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1, 0.55, 1) * rng.randf_range(0.8, 1.25)), p + Vector3(0, 0.12, 0)))
			leaf_c.append(Color(0.26, 0.5, 0.22).lerp(Color(0.36, 0.6, 0.26), rng.randf()))
		# plants, in three rows
		var inner_a1 := a1 + 0.95 / mid_r
		var inner_a2 := a2 - 0.95 / mid_r
		var tall_kind := b % 2   # lavender or hollyhocks at the back
		var n_back := int((inner_a2 - inner_a1) * BED_OUTER / 0.26) + 1
		for k in n_back:
			var a := lerpf(inner_a1, inner_a2, (k + 0.5) / n_back) + rng.randf_range(-0.01, 0.01)
			var p := Vector3(cos(a), 0, sin(a)) * (BED_OUTER - 0.32 + rng.randf_range(-0.06, 0.06))
			if tall_kind == 0:
				for s in 3:
					var q := p + Vector3(rng.randf_range(-0.09, 0.09), 0, rng.randf_range(-0.09, 0.09))
					var h := rng.randf_range(0.5, 0.68)
					stems.append(Transform3D(Basis().scaled(Vector3(1, h / 0.3, 1)), q + Vector3(0, 0.1 + h / 2, 0)))
					spikes.append(Transform3D(Basis(Vector3.UP, rng.randf()), q + Vector3(0, 0.1 + h + 0.08, 0)))
					spike_c.append(Color(0.58, 0.45, 0.85).lerp(Color(0.72, 0.58, 0.95), rng.randf()))
			else:
				var h := rng.randf_range(0.75, 0.95)
				stems.append(Transform3D(Basis().scaled(Vector3(1.4, h / 0.3, 1.4)), p + Vector3(0, 0.1 + h / 2, 0)))
				var hc: Color = theme[1].lerp(Color(1, 1, 1), rng.randf() * 0.25)
				for s in 4:
					holly.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * (1.0 - s * 0.16)), p + Vector3(0, 0.1 + h - s * 0.15, 0)))
					holly_c.append(hc)
		var n_mid := int((inner_a2 - inner_a1) * mid_r / 0.21) + 1
		for k in n_mid:
			var a := lerpf(inner_a1, inner_a2, (k + 0.5) / n_mid)
			var p := Vector3(cos(a), 0, sin(a)) * (mid_r + rng.randf_range(-0.1, 0.1))
			var h := rng.randf_range(0.3, 0.4)
			stems.append(Transform3D(Basis().scaled(Vector3(1, h / 0.3, 1)), p + Vector3(0, 0.1 + h / 2, 0)))
			tulips.append(Transform3D(Basis(Vector3.UP, rng.randf()), p + Vector3(0, 0.1 + h + 0.05, 0)))
			tulip_c.append(theme[0].lerp(Color(1, 1, 1), rng.randf() * 0.2) if k % 5 != 2 else Color(1, 0.95, 0.85))
		var n_front := int((inner_a2 - inner_a1) * BED_INNER / 0.2) + 1
		for k in n_front:
			var a := lerpf(inner_a1, inner_a2, (k + 0.5) / n_front)
			var p := Vector3(cos(a), 0, sin(a)) * (BED_INNER + 0.3 + rng.randf_range(-0.06, 0.06))
			var h := rng.randf_range(0.12, 0.18)
			stems.append(Transform3D(Basis().scaled(Vector3(1, h / 0.3, 1)), p + Vector3(0, 0.1 + h / 2, 0)))
			var tilt := Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
			petals.append(Transform3D(tilt, p + Vector3(0, 0.1 + h, 0)))
			petal_c.append(Color(1, 1, 1) if k % 3 != 0 else Color(1, 0.8, 0.9))
			centres.append(Transform3D(tilt, p + Vector3(0, 0.1 + h + 0.015, 0)))
		# a named spot for villagers' hints, and soft landmarks so nothing spawns in the flowers
		var nk := int((a2 - a1) * mid_r / 1.4) + 1
		for k in nk + 1:
			var a := lerpf(a1, a2, float(k) / nk)
			var lm := {"name": "", "pos": Vector3(cos(a), 0, sin(a)) * mid_r, "radius": 0.8, "soft": true}
			world.landmarks.append(lm)
			if b == 0 and k == nk / 2:
				decor_landmarks["gardens"] = lm
	var stem_mesh := _box(Vector3(0.025, 0.3, 0.025))
	_multi(root, stem_mesh, stems, [], Color(0.3, 0.58, 0.24))
	_multi(root, _ball(0.14), leaves, leaf_c)
	var cup := _cyl(0.085, 0.045, 0.16, 6)
	_multi(root, cup, tulips, tulip_c)
	var daisy := _cyl(0.095, 0.095, 0.018, 8)
	_multi(root, daisy, petals, petal_c)
	var dot := _cyl(0.035, 0.035, 0.024, 6)
	_multi(root, dot, centres, [], Color(1, 0.8, 0.2))
	var spike := _box(Vector3(0.06, 0.22, 0.06))
	_multi(root, spike, spikes, spike_c)
	var bloom := _cyl(0.1, 0.07, 0.07, 6)
	_multi(root, bloom, holly, holly_c)
	root.visible = false


var garden_beds: Array = []     # [[from_angle, to_angle], ...] in radians


func _multi(root: Node3D, mesh: Mesh, xforms: Array, colors: Array, flat := Color.WHITE) -> void:
	if xforms.is_empty():
		return
	var mat := StandardMaterial3D.new()
	if colors.is_empty():
		mat.albedo_color = flat
	else:
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if not colors.is_empty():
			mm.set_instance_color(i, colors[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	root.add_child(mi)


# ---------------------------------------------------------------- fountain

## A three-tier fountain in its own little cobbled court with benches and
## potted shrubs. Water spills from bowl to bowl; toss a coin for a wish.
func _build_fountain() -> void:
	var root := Node3D.new()
	root.position = FOUNTAIN_POS
	add_child(root)
	decor["fountain"] = root
	var entrance := _stones_to_path(root, FOUNTAIN_POS, FOUNTAIN_COURT)
	_court(root, FOUNTAIN_COURT, 31, entrance)
	var stone := Color(0.82, 0.79, 0.74)
	var trim := Color(0.92, 0.9, 0.86)
	# the basin: floor (with a few wishing coins), water, and a wide rim wall
	_mesh(root, _cyl(1.8, 1.8, 0.3, 32), Vector3(0, 0.15, 0), Color(0.3, 0.42, 0.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 9:
		var a := rng.randf() * TAU
		var c := _mesh(root, _cyl(0.06, 0.06, 0.015, 10), Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.6, 1.5) + Vector3(0, 0.31, 0), Color(1, 0.8, 0.3), 0.0, true)
		c.rotation = Vector3(rng.randf_range(-0.3, 0.3), 0, rng.randf_range(-0.3, 0.3))
	_water(root, 1.8, 0.47)
	var wall := _box(Vector3(0.44, 0.58, 0.3))
	var cap := _box(Vector3(0.46, 0.08, 0.46))
	var segs := 28
	for i in segs:
		var a := TAU * i / segs
		var w := _mesh(root, wall, Vector3(cos(a), 0, sin(a)) * 1.95 + Vector3(0, 0.29, 0), stone)
		w.rotation.y = -a + PI / 2
		var c := _mesh(root, cap, Vector3(cos(a), 0, sin(a)) * 1.98 + Vector3(0, 0.62, 0), trim)
		c.rotation.y = -a + PI / 2
	# pedestal and the middle bowl
	_mesh(root, _cyl(0.46, 0.56, 0.3, 16), Vector3(0, 0.55, 0), trim)
	_mesh(root, _cyl(0.22, 0.3, 1.0, 16), Vector3(0, 1.15, 0), stone)
	_mesh(root, _cyl(0.32, 0.24, 0.12, 16), Vector3(0, 1.62, 0), trim)
	_mesh(root, _cyl(1.08, 0.36, 0.34, 28), Vector3(0, 1.8, 0), stone)
	var lip := TorusMesh.new()
	lip.inner_radius = 0.98
	lip.outer_radius = 1.12
	lip.rings = 32
	lip.ring_segments = 8
	_mesh(root, lip, Vector3(0, 1.97, 0), trim)
	_water(root, 1.0, 1.975)
	# top bowl and the spout
	_mesh(root, _cyl(0.12, 0.17, 0.55, 12), Vector3(0, 2.25, 0), stone)
	_mesh(root, _cyl(0.52, 0.18, 0.22, 20), Vector3(0, 2.6, 0), stone)
	var lip2 := TorusMesh.new()
	lip2.inner_radius = 0.46
	lip2.outer_radius = 0.56
	lip2.rings = 24
	lip2.ring_segments = 8
	_mesh(root, lip2, Vector3(0, 2.71, 0), trim)
	_water(root, 0.48, 2.715)
	_mesh(root, _ball(0.1), Vector3(0, 2.8, 0), trim)
	# water: a jet from the top, and sheets spilling over each lip
	var jet := _water_particles(root, Vector3(0, 2.86, 0), 50, 0.95)
	jet.direction = Vector3.UP
	jet.spread = 7.0
	jet.initial_velocity_min = 2.3
	jet.initial_velocity_max = 2.7
	_water_curtain(root, 2.7, 0.54, 70, 0.72)
	_water_curtain(root, 1.96, 1.1, 150, 1.48)
	# benches and planters around the court
	for k in 3:
		var a := entrance + PI / 2 * (k + 1)
		_bench(root, Vector3(cos(a), 0, sin(a)) * 2.85, atan2(-cos(a), -sin(a)))
	var pots := [Color(1, 0.45, 0.6), Color(1, 0.85, 0.3), Color(0.7, 0.55, 1), Color(1, 0.6, 0.3)]
	for k in 4:
		var a := entrance + PI / 4 + PI / 2 * k
		_planter(root, Vector3(cos(a), 0, sin(a)) * 3.0, pots[k])
	_col_cyl(root, Vector3.ZERO, 2.15, 0.9)
	_landmark("fountain", root.position, FOUNTAIN_COURT)
	world._spot(FOUNTAIN_POS, 3.0,
		func(_p): return "E: Toss a coin in the fountain and make a wish" if Game.is_project_funded("fountain") else "",
		func(_p): _toss_coin())
	root.visible = false


const WISHES := ["You wish for a big catch tomorrow.", "You wish for sunny days and full baskets.",
	"You wish that Pip would let you win a race. Just once.", "You wish for the tastiest pie Bram has ever baked.",
	"You wish for a shiny gemstone in the next boulder.", "You wish everyone in the village a good night's sleep.",
	"You wish for a garden full of giant pumpkins.", "You wish for a treasure map in the next bottle."]


func _toss_coin() -> void:
	if Game.coins < 1:
		world.hud.show_toast("You don't have a coin to toss!", 2.0)
		return
	Game.add_coins(-1)
	Game.extra["wishes"] = Game.xi("wishes") + 1
	Audio.play("coin")
	world.player.play_action_bounce()
	var splash := _water_particles(decor["fountain"], Vector3(randf_range(-0.8, 0.8), 0.5, randf_range(0.6, 1.2)), 16, 0.5)
	splash.one_shot = true
	splash.explosiveness = 1.0
	splash.direction = Vector3.UP
	splash.spread = 35.0
	splash.initial_velocity_min = 1.2
	splash.initial_velocity_max = 2.0
	get_tree().create_timer(0.35).timeout.connect(func(): Audio.play("splash", 0.1, -8.0))
	get_tree().create_timer(1.5).timeout.connect(splash.queue_free)
	world.hud.show_toast("Plink! " + WISHES.pick_random(), 3.0)


# ---------------------------------------------------------------- bandstand

## An octagonal bandstand: a brick base with a wooden stage (walk up the
## steps at the front), white posts and railings, a red roof with a little
## cupola, bunting and strings of lights that glow in the evening.
## The front (steps) faces the well.
func _build_bandstand() -> void:
	var root := Node3D.new()
	root.position = BANDSTAND_POS
	root.rotation.y = atan2(-BANDSTAND_POS.x, -BANDSTAND_POS.z)   # local +z faces the well
	add_child(root)
	decor["bandstand"] = root
	var entrance := _stones_to_path(root, BANDSTAND_POS, BANDSTAND_COURT)
	_court(root, BANDSTAND_COURT, 47, entrance)
	var white := Color(0.96, 0.94, 0.9)
	var R := 2.9            # corner radius of the octagon
	var H := 0.55           # stage height
	var ROOF := 3.05        # underside of the roof
	var oct := deg_to_rad(22.5)   # turn the octagons so a flat side faces the steps
	var base := _mesh(root, _cyl(R + 0.04, R + 0.1, H - 0.08, 8), Vector3(0, (H - 0.08) / 2, 0), Color(0.62, 0.36, 0.3))
	base.rotation.y = oct
	var deck := _mesh(root, _cyl(R + 0.12, R + 0.12, 0.1, 8), Vector3(0, H - 0.05, 0), Color(0.72, 0.54, 0.36))
	deck.rotation.y = oct
	# deck planks (thin dark lines)
	for k in 9:
		_mesh(root, _box(Vector3(0.02, 0.005, 2 * R * 0.92)), Vector3(-R * 0.8 + k * R * 0.2, H + 0.002, 0), Color(0.55, 0.4, 0.26))
	# steps at the front (a gentle ramp underneath so you can walk up)
	var step_w := 1.9
	for k in 3:
		var h := H * (k + 1) / 4.0
		_mesh(root, _box(Vector3(step_w, h, 0.32)), Vector3(0, h / 2, R * 0.924 + 0.12 + (2 - k) * 0.3), white.darkened(0.08 * (k % 2)))
	var ramp_len := 1.35
	var ramp_top := R * 0.924 - 0.15      # tucks just under the stage edge so there's no lip
	var ramp_run := ramp_len + 0.15
	var ramp_slope := atan2(H, ramp_run)
	var ramp_c := Vector3(0, H / 2, ramp_top + ramp_run / 2) - Vector3(0, cos(ramp_slope), sin(ramp_slope)) * 0.125
	_col_box(root, ramp_c, Vector3(step_w, 0.25, sqrt(ramp_run * ramp_run + H * H)), Basis(Vector3.RIGHT, ramp_slope))
	# posts at the corners, railings on every side but the front
	var corners := []
	for i in 8:
		var t := oct + TAU * i / 8.0
		corners.append(Vector3(sin(t), 0, cos(t)) * (R - 0.12))
	for i in 8:
		var c: Vector3 = corners[i]
		_mesh(root, _cyl(0.09, 0.11, ROOF - H, 10), c + Vector3(0, H + (ROOF - H) / 2, 0), white, 0.0, false, true)
		_mesh(root, _box(Vector3(0.26, 0.12, 0.26)), c + Vector3(0, H + 0.06, 0), white)
		_mesh(root, _box(Vector3(0.24, 0.1, 0.24)), c + Vector3(0, ROOF - 0.08, 0), white, 0.0, false, true)
	for i in 8:
		var a: Vector3 = corners[i]
		var b: Vector3 = corners[(i + 1) % 8]
		var mid := (a + b) / 2
		var along := b - a
		var yaw := atan2(along.x, along.z)
		if mid.z > R * 0.8:
			continue      # the front stays open for the steps
		var top_rail := _mesh(root, _box(Vector3(0.07, 0.07, along.length())), mid + Vector3(0, H + 0.82, 0), white)
		top_rail.rotation.y = yaw
		var bottom_rail := _mesh(root, _box(Vector3(0.05, 0.05, along.length())), mid + Vector3(0, H + 0.14, 0), white)
		bottom_rail.rotation.y = yaw
		for k in 7:
			var p := a.lerp(b, (k + 1) / 8.0)
			_mesh(root, _box(Vector3(0.04, 0.68, 0.04)), p + Vector3(0, H + 0.48, 0), white)
		_col_box(root, mid + Vector3(0, H + 0.45, 0), Vector3(0.12, 0.9, along.length()), Basis(Vector3.UP, yaw))
	# roof: a trim ring, the red roof, a cupola and a golden finial
	var eave := _mesh(root, _cyl(R + 0.35, R + 0.35, 0.16, 8), Vector3(0, ROOF + 0.08, 0), white, 0.0, false, true)
	eave.rotation.y = oct
	var roof := _mesh(root, _cyl(0.55, R + 0.55, 1.15, 8), Vector3(0, ROOF + 0.16 + 0.575, 0), Color(0.72, 0.2, 0.2), 0.0, false, true)
	roof.rotation.y = oct
	var cupola := _mesh(root, _cyl(0.45, 0.5, 0.45, 8), Vector3(0, ROOF + 1.5, 0), white, 0.0, false, true)
	cupola.rotation.y = oct
	var cap := _mesh(root, _cyl(0.0, 0.7, 0.55, 8), Vector3(0, ROOF + 2.0, 0), Color(0.72, 0.2, 0.2), 0.0, false, true)
	cap.rotation.y = oct
	_mesh(root, _ball(0.12), Vector3(0, ROOF + 2.35, 0), Color(1, 0.82, 0.3), 0.0, true, true)
	_mesh(root, _cyl(0.015, 0.03, 0.4, 6), Vector3(0, ROOF + 2.6, 0), Color(1, 0.82, 0.3), 0.0, true, true)
	# bunting and little lights along each side, under the eaves
	var flag_colors := [Color(1, 0.3, 0.3), Color(1, 0.85, 0.2), Color(0.3, 0.7, 1), Color(0.5, 1, 0.4), Color(0.95, 0.5, 0.9)]
	var fp := PrismMesh.new()
	fp.size = Vector3(0.24, 0.26, 0.02)
	var bulb := _ball(0.045)
	for i in 8:
		var a: Vector3 = corners[i] * 1.03
		var b: Vector3 = corners[(i + 1) % 8] * 1.03
		var yaw := atan2((b - a).x, (b - a).z) + PI / 2
		for k in 5:
			var t := (k + 0.5) / 5.0
			var p := a.lerp(b, t) + Vector3(0, ROOF - 0.2 - 0.18 * 4.0 * t * (1.0 - t), 0)
			var flag := MeshInstance3D.new()
			flag.mesh = fp
			flag.position = p
			flag.rotation = Vector3(0, yaw, PI)
			flag.material_override = world._mat(flag_colors[(i * 5 + k) % flag_colors.size()], true)
			root.add_child(flag)
		_bulbs(root, a + Vector3(0, ROOF - 0.05, 0), b + Vector3(0, ROOF - 0.05, 0), 6, 0.1, bulb, [Color(1, 0.85, 0.5)])
	# a hanging lantern (joins the street lamps at night)
	_mesh(root, _cyl(0.01, 0.01, 0.5, 4), Vector3(0, ROOF - 0.25, 0), Color(0.2, 0.2, 0.2))
	_mesh(root, _box(Vector3(0.24, 0.3, 0.24)), Vector3(0, ROOF - 0.6, 0), Color(1, 0.85, 0.55), 1.8)
	var light := OmniLight3D.new()
	light.position = Vector3(0, ROOF - 0.7, 0)
	light.light_color = Color(1.0, 0.8, 0.5)
	light.omni_range = 8.0
	root.add_child(light)
	world.lamps.append(light)
	# the band's things: a drum, a music stand, a stool and an upright piano
	var drum := _mesh(root, _cyl(0.34, 0.34, 0.3, 16), Vector3(0.9, H + 0.3, -0.9), Color(0.85, 0.22, 0.22))
	drum.rotation.x = PI / 2
	_mesh(root, _cyl(0.35, 0.35, 0.02, 16), Vector3(0.9, H + 0.3, -0.74), white).rotation.x = PI / 2
	_mesh(root, _cyl(0.2, 0.2, 0.1, 12), Vector3(1.4, H + 0.55, -0.6), Color(0.9, 0.75, 0.3), 0.0, true)
	_mesh(root, _box(Vector3(0.03, 0.55, 0.03)), Vector3(1.4, H + 0.27, -0.6), Color(0.2, 0.2, 0.2))
	_mesh(root, _box(Vector3(0.04, 1.0, 0.04)), Vector3(-0.7, H + 0.5, 0.2), Color(0.2, 0.2, 0.2))
	var stand_top := _mesh(root, _box(Vector3(0.48, 0.34, 0.03)), Vector3(-0.7, H + 1.05, 0.2), Color(0.2, 0.2, 0.2))
	stand_top.rotation.x = -0.4
	_mesh(root, _cyl(0.2, 0.2, 0.06, 12), Vector3(-0.9, H + 0.48, -0.4), Color(0.55, 0.3, 0.2))
	_mesh(root, _box(Vector3(0.04, 0.45, 0.04)), Vector3(-0.9, H + 0.22, -0.4), Color(0.3, 0.2, 0.15))
	_mesh(root, _box(Vector3(1.3, 1.05, 0.5)), Vector3(-0.8, H + 0.53, -1.75), Color(0.35, 0.2, 0.14))
	_mesh(root, _box(Vector3(1.2, 0.05, 0.22)), Vector3(-0.8, H + 0.72, -1.45), Color(0.97, 0.96, 0.92))
	_col_box(root, Vector3(-0.8, H + 0.53, -1.75), Vector3(1.3, 1.05, 0.5))
	# flower boxes either side of the steps
	for x in [-1.45, 1.45]:
		_mesh(root, _box(Vector3(0.7, 0.36, 0.45)), Vector3(x, 0.18, R * 0.924 + 0.5), Color(0.55, 0.38, 0.24))
		for k in 5:
			_mesh(root, _ball(0.1), Vector3(x - 0.24 + k * 0.12, 0.42, R * 0.924 + 0.5 + (0.08 if k % 2 == 0 else -0.08)),
				flag_colors[k % flag_colors.size()], 0.15)
	# the stage itself: solid, so you can stand on it
	_col_cyl(root, Vector3.ZERO, R * 0.924 - 0.03, H)   # round, so it sits inside the octagon's flat sides
	_landmark("bandstand", root.position, BANDSTAND_COURT)
	root.visible = false


## Where to stand to play on the bandstand (on the stage, facing the well).
func bandstand_stage() -> Vector3:
	var toward := -BANDSTAND_POS.normalized()
	return BANDSTAND_POS + toward * 1.0


# ---------------------------------------------------------------- golden statue

## A gilded statue of you on a marble plinth, in a small court with clipped
## topiaries, a gold plaque, and a warm light on it after dark.
func _build_statue() -> void:
	var root := Node3D.new()
	root.position = STATUE_POS
	root.rotation.y = atan2(-STATUE_POS.x, -STATUE_POS.z)   # looks toward the well
	add_child(root)
	decor["statue"] = root
	var entrance := _stones_to_path(root, STATUE_POS, STATUE_COURT)
	_court(root, STATUE_COURT, 63, entrance)
	var marble := Color(0.93, 0.91, 0.87)
	var step := Color(0.78, 0.76, 0.72)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.78, 0.3)
	gold.metallic = 1.0
	gold.roughness = 0.28
	_mesh(root, _box(Vector3(2.2, 0.22, 2.2)), Vector3(0, 0.11, 0), step)
	_mesh(root, _box(Vector3(1.8, 0.22, 1.8)), Vector3(0, 0.33, 0), step.lightened(0.08))
	_mesh(root, _box(Vector3(1.3, 1.15, 1.3)), Vector3(0, 1.015, 0), marble)
	for y in [0.5, 1.56]:
		var band := _mesh(root, _box(Vector3(1.36, 0.07, 1.36)), Vector3(0, y, 0), Color.WHITE)
		band.material_override = gold
	_mesh(root, _box(Vector3(1.5, 0.14, 1.5)), Vector3(0, 1.66, 0), marble)
	# the plaque: a brass plate in a darker frame, with two lines that fit on it
	var frame := _mesh(root, _box(Vector3(0.96, 0.5, 0.03)), Vector3(0, 1.02, 0.662), Color(0.55, 0.4, 0.18))
	(frame.material_override as StandardMaterial3D).metallic = 0.5
	var plate := _mesh(root, _box(Vector3(0.88, 0.42, 0.03)), Vector3(0, 1.02, 0.675), Color(0.92, 0.74, 0.38))
	(plate.material_override as StandardMaterial3D).metallic = 0.35
	(plate.material_override as StandardMaterial3D).roughness = 0.35
	for sx in [-0.39, 0.39]:
		for sy in [-0.17, 0.17]:
			_mesh(root, _cyl(0.018, 0.018, 0.01, 8), Vector3(sx, 1.02 + sy, 0.692), Color(0.55, 0.4, 0.18)).rotation.x = PI / 2
	var plaque := Label3D.new()
	plaque.text = "OUR HERO"
	plaque.font_size = 40
	plaque.pixel_size = 0.0035
	plaque.outline_size = 0
	plaque.modulate = Color(0.3, 0.18, 0.04)
	plaque.position = Vector3(0, 1.07, 0.693)
	plaque.visibility_range_end = 14.0
	root.add_child(plaque)
	var sub := Label3D.new()
	sub.text = "Saved the Harvest Festival"
	sub.font_size = 16
	sub.pixel_size = 0.0035
	sub.outline_size = 0
	sub.modulate = Color(0.3, 0.18, 0.04)
	sub.position = Vector3(0, 0.95, 0.693)
	sub.visibility_range_end = 10.0
	root.add_child(sub)
	# the hero
	var figure := Node3D.new()
	figure.set_script(VISUAL_SCRIPT)
	figure.position = Vector3(0, 1.73 + 0.94, 0)
	figure.scale = Vector3.ONE * 1.35
	figure.rotation.y = PI   # the model faces -Z after setup; turn it to face outward
	root.add_child(figure)
	figure.setup(-1.0, "crown")
	_gild(figure, gold)
	if figure.anim:
		figure.anim.play("idle")
		figure.anim.seek(0.4, true)
		figure.anim.pause()
	# a heroic pose: one arm raised high with a trophy, the other on the hip
	var raised: Node3D = figure.model.find_child("arm-right", true, false)
	var hip: Node3D = figure.model.find_child("arm-left", true, false)
	if raised:
		raised.rotation = Vector3(0, 0, STATUE_ARM)
		var cup := Node3D.new()
		cup.position = Vector3(-0.32, 0.06, 0)    # at the end of the arm
		cup.rotation.z = PI / 2                    # the cup's "up" runs along the arm
		cup.scale = Vector3.ONE * 1.9
		raised.add_child(cup)
		_mesh(cup, _cyl(0.05, 0.07, 0.04, 12), Vector3(0, 0.02, 0), Color.WHITE).material_override = gold
		_mesh(cup, _cyl(0.02, 0.02, 0.1, 8), Vector3(0, 0.09, 0), Color.WHITE).material_override = gold
		_mesh(cup, _cyl(0.11, 0.06, 0.15, 14), Vector3(0, 0.21, 0), Color.WHITE).material_override = gold
		for x in [-0.11, 0.11]:
			var handle := TorusMesh.new()
			handle.inner_radius = 0.025
			handle.outer_radius = 0.045
			var h := _mesh(cup, handle, Vector3(x, 0.22, 0), Color.WHITE)
			h.rotation.x = PI / 2
			h.material_override = gold
	if hip:
		hip.rotation = Vector3(0, 0, STATUE_HIP)
	# glints of light around it
	var glint := CPUParticles3D.new()
	glint.position = Vector3(0, 2.7, 0)
	glint.amount = 12
	glint.lifetime = 1.6
	glint.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	glint.emission_sphere_radius = 0.9
	glint.gravity = Vector3.ZERO
	glint.initial_velocity_min = 0.0
	glint.initial_velocity_max = 0.1
	var star := QuadMesh.new()
	star.size = Vector2(0.09, 0.09)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.albedo_color = Color(1, 0.95, 0.7)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	star.material = sm
	glint.mesh = star
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.5, 1))
	curve.add_point(Vector2(1, 0))
	glint.scale_amount_curve = curve
	root.add_child(glint)
	# clipped topiaries around the court, and an uplight for the evening
	for k in 4:
		var a := entrance + PI / 4 + PI / 2 * k
		var p := Vector3(cos(a), 0, sin(a)) * 2.25
		_mesh(root, _cyl(0.26, 0.2, 0.34, 12), p + Vector3(0, 0.17, 0), Color(0.72, 0.4, 0.26))
		_mesh(root, _ball(0.3), p + Vector3(0, 0.6, 0), Color(0.24, 0.48, 0.22))
		_mesh(root, _ball(0.22), p + Vector3(0, 0.98, 0), Color(0.26, 0.52, 0.23))
		_mesh(root, _ball(0.13), p + Vector3(0, 1.27, 0), Color(0.28, 0.55, 0.24))
	var up := OmniLight3D.new()
	up.position = Vector3(0, 0.6, 1.6)
	up.light_color = Color(1.0, 0.85, 0.55)
	up.omni_range = 5.0
	root.add_child(up)
	world.lamps.append(up)
	_col_box(root, Vector3(0, 1.4, 0), Vector3(2.2, 2.8, 2.2))
	_landmark("statue", root.position, STATUE_COURT)
	root.visible = false


func _gild(node: Node, gold: Material) -> void:
	for c in node.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = gold
		_gild(c, gold)


# ---------------------------------------------------------------- sprinklers

func _build_sprinklers() -> void:
	sprinklers = Node3D.new()
	add_child(sprinklers)
	var c: Vector3 = world.FARM_CENTER
	var half: float = world.FARM_SPACING / 2
	for off in [Vector3(0, 0, -half), Vector3(0, 0, half)]:
		var p: Vector3 = c + off
		_mesh(sprinklers, _cyl(0.04, 0.04, 0.5, 8), p + Vector3(0, 0.25, 0), Color(0.5, 0.5, 0.55), 0.0, true)
		_mesh(sprinklers, _cyl(0.09, 0.06, 0.1, 10), p + Vector3(0, 0.52, 0), Color(0.3, 0.55, 0.3))
		var spray := CPUParticles3D.new()
		spray.position = p + Vector3(0, 0.58, 0)
		spray.amount = 40
		spray.lifetime = 0.9
		spray.direction = Vector3.UP
		spray.spread = 70.0
		spray.initial_velocity_min = 2.2
		spray.initial_velocity_max = 3.0
		spray.gravity = Vector3(0, -8, 0)
		var drop := SphereMesh.new()
		drop.radius = 0.035
		drop.height = 0.07
		var dm := StandardMaterial3D.new()
		dm.albedo_color = Color(0.7, 0.88, 1.0, 0.8)
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		drop.material = dm
		spray.mesh = drop
		spray.emitting = false
		sprinklers.add_child(spray)
		sprays.append(spray)
	sprinklers.visible = false


# ---------------------------------------------------------------- crab rocks

func _build_crab_rocks() -> void:
	var r: float = world.scenery.shore_radius(CRAB_ANGLE)
	if r < 0.0:
		r = 34.0
	var out := Vector3(cos(CRAB_ANGLE), 0, sin(CRAB_ANGLE))
	var side := Vector3(-out.z, 0, out.x)
	var c := out * (r - 1.2)
	crab_spot = c
	for k in 3:
		var p := c + side * (k - 1) * 1.6 + out * (0.4 if k == 1 else 0.0)
		p.y = world.scenery.height_at(p.x, p.z)
		world.scenery.add_rock(world, p, 0.65 if k != 1 else 0.85)
	var sign_pos := c - out * 2.6 + side * 1.6
	sign_pos.y = world.scenery.height_at(sign_pos.x, sign_pos.z)
	_sign(self, "Crab Rocks", sign_pos, -out, Color(0.85, 0.45, 0.35))
	_landmark("", c, 2.8)
	var spot_pos := c - out * 1.8
	world._spot(spot_pos, 2.0,
		func(_p): return "E: Catch crabs" if Game.crab_day != Game.day else "The crabs are hiding. Try again tomorrow!",
		func(_p): _start_crabs())


func _start_crabs() -> void:
	if Game.crab_day == Game.day:
		return
	Game.crab_day = Game.day
	world.play_minigame("crabs", func(n):
		if n > 0:
			Game.add_item("crab", n)
			world.hud.show_toast("You caught %d crab%s! Sell them at the market (%d coins each)." % [n, "" if n == 1 else "s", Game.ITEMS["crab"]["sell"]], 4.0)
		else:
			world.hud.show_toast("The crabs got away this time. Come back tomorrow!", 3.0))


# ---------------------------------------------------------------- Pip's race

## Built once everything else in the village is in place: the sign stands at
## the edge of the square, the start/finish line is painted on the cobbles,
## and the rings loop around the village through the gaps between the paths.
## Each ring is placed as far out as there's room, and every leg between two
## rings is checked so nothing solid is in the way.
func build_race() -> void:
	var sign_pos := polar(RACE_SIGN_AT)
	var facing := -sign_pos.normalized()
	_sign(self, "Race Pip!", sign_pos, facing, Color(0.95, 0.8, 0.3))
	# a little chequered flag on the sign
	var flag_root := Node3D.new()
	flag_root.position = sign_pos + Vector3(-facing.z, 0, facing.x) * 0.62
	add_child(flag_root)
	_mesh(flag_root, _cyl(0.025, 0.025, 2.1, 6), Vector3(0, 1.05, 0), Color(0.3, 0.3, 0.32))
	for i in 4:
		for j in 3:
			var sq := _mesh(flag_root, _box(Vector3(0.012, 0.11, 0.11)), Vector3(0, 1.95 - j * 0.11, 0.08 + i * 0.11),
				Color(0.1, 0.1, 0.1) if (i + j) % 2 == 0 else Color(0.97, 0.97, 0.97))
			sq.rotation.y = 0.0
	flag_root.rotation.y = atan2(facing.x, facing.z) + PI / 2
	_landmark("", sign_pos, 0.45)
	var start := polar(Vector2(RACE_SIGN_AT.x, RACE_START_R))
	race_start = start + Vector3(0, 1, 0)
	race_route.clear()
	var prev := start
	for deg in RACE_GAPS:
		var p := _race_point(float(deg), prev)
		race_route.append(p)
		prev = p
	race_route.append(start)   # the finish line
	_paint_start_line(start, (race_route[0] - start).normalized())
	var torus := TorusMesh.new()
	torus.inner_radius = 1.05
	torus.outer_radius = 1.25
	torus.rings = 32
	torus.ring_segments = 8
	for i in race_route.size():
		var p: Vector3 = race_route[i]
		var nxt: Vector3 = race_route[(i + 1) % race_route.size()]
		var prv: Vector3 = race_route[i - 1] if i > 0 else start
		var along := (nxt - prv).normalized()
		var ring := MeshInstance3D.new()
		ring.mesh = torus
		ring.position = p + Vector3(0, 1.3, 0)
		ring.rotation.y = atan2(along.x, along.z)
		ring.rotation.x = PI / 2
		ring.rotation_order = EULER_ORDER_YXZ
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1, 0.85, 0.3) if i < race_route.size() - 1 else Color(0.4, 1, 0.5)
		m.emission_enabled = true
		m.emission = m.albedo_color
		ring.material_override = m
		ring.visible = false
		add_child(ring)
		race_rings.append(ring)
	world._spot(sign_pos, 1.8, _race_prompt, func(_p): _try_race())


## The best spot for a ring near this angle: as far out as it fits, clear of
## anything solid, off the dirt paths, and reachable in a straight line.
func _race_point(deg: float, from: Vector3) -> Vector3:
	for off in [0.0, 4.0, -4.0, 8.0, -8.0, 12.0, -12.0, 16.0, -16.0]:
		var r := RACE_RING_R.y
		while r >= RACE_RING_R.x:
			var p := polar(Vector2(deg + off, r))
			if world.is_clear(p, 1.8, true) and world._dist_to_paths(p) > 1.5 and not world.scenery.is_sand(p) \
					and race_leg_clear(from, p):
				return p
			r -= 0.5
	push_warning("Pip's race: no clear spot near %d degrees" % int(deg))
	return polar(Vector2(deg, 12.0))


## Nothing solid within a runner's reach of the straight line from a to b.
func race_leg_clear(a: Vector3, b: Vector3) -> bool:
	var d := Vector2(b.x - a.x, b.z - a.z)
	var n := int(d.length() / 0.4) + 1
	for i in n + 1:
		var q := a.lerp(b, float(i) / n)
		if not world.is_clear(q, 0.75, true) or in_flower_bed(q, 0.35):
			return false
	return true


## Is p in (or within margin of) one of the flower beds around the square?
func in_flower_bed(p: Vector3, margin := 0.0) -> bool:
	var r := Vector2(p.x, p.z).length()
	if r < BED_INNER - margin or r > BED_OUTER + margin:
		return false
	var a := fposmod(atan2(p.z, p.x), TAU)
	var m := margin / maxf(r, 0.1)
	for bed in garden_beds:
		for turn in [0.0, TAU]:
			if a + turn >= bed[0] - m and a + turn <= bed[1] + m:
				return true
	return false


## Is p on (or right next to) the race course? Used to keep trees, boulders
## and lamps off it.
func on_race_course(p: Vector3, width := 2.6) -> bool:
	var pts := [race_start] + race_route
	var q := Vector2(p.x, p.z)
	for i in pts.size() - 1:
		var a := Vector2(pts[i].x, pts[i].z)
		var b := Vector2(pts[i + 1].x, pts[i + 1].z)
		var t := clampf((q - a).dot(b - a) / max((b - a).length_squared(), 0.001), 0.0, 1.0)
		if q.distance_to(a + (b - a) * t) < width:
			return true
	return false


## A chequered start / finish line on the cobbles, across the first leg.
func _paint_start_line(at: Vector3, dir: Vector3) -> void:
	var root := Node3D.new()
	root.position = at + Vector3(0, 0.05, 0)
	root.rotation.y = atan2(dir.x, dir.z)
	add_child(root)
	var tile := _box(Vector3(0.25, 0.012, 0.25))
	var black: StandardMaterial3D = world._mat(Color(0.12, 0.12, 0.12), false)
	var white: StandardMaterial3D = world._mat(Color(0.95, 0.95, 0.92), false)
	for i in 10:
		for j in 2:
			var t := MeshInstance3D.new()
			t.mesh = tile
			t.position = Vector3(-1.125 + i * 0.25, 0, -0.125 + j * 0.25)
			t.material_override = black if (i + j) % 2 == 0 else white
			root.add_child(t)


func _pip() -> CharacterBody3D:
	for n in world.npcs:
		if n.npc_name == "Pip":
			return n
	return null


func _race_prompt(_p) -> String:
	if racing or counting_down:
		return ""
	var pip := _pip()
	if pip == null or pip.quest_index < 1:
		return "E: Read the sign"
	if Game.race_day == Game.day:
		return "E: Race Pip again (just for fun)"
	return "E: Race Pip! (%d coin prize)" % RACE_PRIZE


func _try_race() -> void:
	if racing or counting_down:
		return
	var pip := _pip()
	if pip == null:
		return
	if pip.quest_index < 1:
		world.hud.show_toast("\"PIP'S RACE COURSE -- no grown-ups who can't even win at tag.\" Maybe play tag with Pip first?", 5.0)
		return
	if pip.state == NPC.State.HOME or pip.state == NPC.State.GO_HOME:
		world.hud.show_toast("Pip has gone home to bed. Race in the daytime!", 3.0)
		return
	if not pip.state in [NPC.State.IDLE, NPC.State.WANDER, NPC.State.CHATTING, NPC.State.APPROACH]:
		world.hud.show_toast("Pip is busy right now.", 2.5)
		return
	_countdown(pip)


func _countdown(pip: CharacterBody3D) -> void:
	counting_down = true
	var player: CharacterBody3D = world.player
	player.busy = true
	Game.time_running = false
	world.hud.show_prompt("")
	var first: Vector3 = race_route[0]
	var dir := first - race_start
	dir.y = 0
	dir = dir.normalized()
	var side := Vector3(-dir.z, 0, dir.x)
	player.global_position = race_start + side * 0.8
	player.velocity = Vector3.ZERO
	player.visual.rotation.y = atan2(-dir.x, -dir.z)
	player.cam_yaw = player.visual.rotation.y
	pip.global_position = race_start - side * 0.8
	pip.velocity = Vector3.ZERO
	pip.start_race([], RACE_PIP_SPEED, _on_pip_finished)
	pip._face(pip.global_position + dir)
	pip.say(["Ready? Through all the rings!", "I'm gonna WIN!", "On your marks!"].pick_random(), 2.5)
	for i in race_rings.size():
		race_rings[i].visible = true
		race_rings[i].transparency = 0.0 if i == 0 else 0.7
	for n in [3, 2, 1]:
		world.hud.show_big(str(n))
		Audio.play("beep", 0.0)
		await get_tree().create_timer(0.8).timeout
		if not counting_down:
			return    # cancelled (e.g. passed out)
	world.hud.show_big("GO!", Color(0.5, 1, 0.5))
	Audio.play("ding", 0.0)
	counting_down = false
	racing = true
	race_time = 0.0
	race_next = 0
	player.busy = false
	pip.race_points = race_route.duplicate()
	pip.race_index = 0


func _process(delta: float) -> void:
	if racing:
		_update_race(delta)
	_update_fireflies(delta)
	if sprinklers.visible:
		var h := Game.hour()
		var on := h >= 6.0 and h < 8.5
		for s in sprays:
			s.emitting = on


func _update_race(delta: float) -> void:
	race_time += delta
	var player: CharacterBody3D = world.player
	var target: Vector3 = race_route[race_next]
	var d := Vector2(player.global_position.x - target.x, player.global_position.z - target.z).length()
	if d < 1.9:
		race_rings[race_next].visible = false
		race_next += 1
		Audio.play("ding", 0.08)
		if race_next >= race_route.size():
			_end_race(true)
			return
		for i in range(race_next, race_rings.size()):
			race_rings[i].transparency = 0.0 if i == race_next else 0.7
	world.hud.show_timer("Race  %.1fs    Rings %d / %d" % [race_time, race_next, race_route.size()])
	# spin the next ring a little so it catches the eye
	race_rings[race_next].scale = Vector3.ONE * (1.0 + 0.08 * sin(race_time * 8.0))
	if race_time > RACE_TIME_LIMIT:
		_end_race(false)


func _on_pip_finished() -> void:
	if racing:
		_end_race(false)


func _end_race(won: bool) -> void:
	racing = false
	world.hud.hide_timer()
	for r in race_rings:
		r.visible = false
	Game.time_running = true
	var pip := _pip()
	if pip:
		pip.stop_race()
	if won:
		var record := Game.race_best <= 0.0 or race_time < Game.race_best
		if record:
			Game.race_best = race_time
		var msg := "You beat Pip in %.1f seconds!" % race_time
		if record:
			msg += "  New record!"
		if Game.race_day != Game.day:
			Game.race_day = Game.day
			Game.add_coins(RACE_PRIZE)
			msg += "  +%d coins" % RACE_PRIZE
		world.hud.show_big("You win!", Color(0.5, 1, 0.5))
		world.hud.show_toast(msg, 4.5)
		Audio.play("win")
		if pip:
			pip.say(["No fair! Rematch tomorrow!", "Whoa, you're FAST!", "I let you win. Obviously."].pick_random(), 3.0)
	else:
		world.hud.show_big("Pip wins!", Color(1, 0.55, 0.4))
		world.hud.show_toast("Pip won the race! Try again -- follow the glowing rings in order.", 4.0)
		Audio.play("fail")
		if pip:
			pip.velocity.y = 5.0
			pip.say(["Ha! Too slow!", "Pip is the champion!", "Better luck next time!"].pick_random(), 3.0)


## Called when the day ends (sleeping or passing out) in the middle of a race.
func cancel_race() -> void:
	if racing or counting_down:
		racing = false
		counting_down = false
		world.hud.hide_timer()
		for r in race_rings:
			r.visible = false
		var pip := _pip()
		if pip:
			pip.stop_race()


# ---------------------------------------------------------------- fireflies

func _update_fireflies(delta: float) -> void:
	fireflies = fireflies.filter(func(f): return is_instance_valid(f) and not f.caught)
	var night: bool = Game.is_night() and world.player != null and not world.in_title
	if not night:
		for f in fireflies:
			f.queue_free()
		fireflies = []
		return
	firefly_timer -= delta
	if firefly_timer > 0.0 or fireflies.size() >= MAX_FIREFLIES:
		return
	firefly_timer = 3.0
	for attempt in 20:
		var a := randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * randf_range(8.0, 27.0)
		if world.is_clear(p, 1.5) and world._dist_to_paths(p) > 1.5 and not world.scenery.is_sand(p):
			var f := Node3D.new()
			f.set_script(FIREFLY_SCRIPT)
			f.home = p
			f.world = world
			add_child(f)
			f.global_position = p + Vector3(0, 1, 0)
			fireflies.append(f)
			return
