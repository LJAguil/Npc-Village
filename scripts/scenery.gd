extends Node3D
## Landscape and nature: rolling hills around the village, a beach and the
## ocean to the east, a forest on the hills, distant mountains, a lighthouse,
## and the trees, rocks, bushes, flowers and grass inside the village. Everything is generated in code with a fixed random
## seed, so the world looks the same every time you play.
##
## Trees use a low-poly look (faceted shading) and a small shader that makes
## the leaves sway in the wind and fade out when the camera gets close.

const PLAY_RADIUS := 30.0        # the flat, walkable village area
const TERRAIN_SIZE := 220.0
const TERRAIN_STEP := 2.0
const FOLIAGE_SHADER := preload("res://shaders/foliage.gdshader")
const OCEAN_SHADER := preload("res://shaders/ocean.gdshader")
const WATER_Y := -0.2            # sea level
const SHORE_RADIUS := 33.7       # where the beach meets the sea (straight east)

var noise := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()

var trunk_mat: StandardMaterial3D
var leaf_mat: ShaderMaterial
var tree_meshes := {}     # "oak0", "pine1", ... -> ArrayMesh (surface 0 trunk, surface 1 leaves)
var rock_meshes: Array = []
var bush_mesh: ArrayMesh
var lighthouse_lights: Array = []   # turned on at night by main.gd
var lighthouse_beam: Node3D


func _init() -> void:
	noise.seed = 1337
	noise.frequency = 0.035
	detail.seed = 4242
	detail.frequency = 0.12
	rng.seed = 2024

	trunk_mat = StandardMaterial3D.new()
	trunk_mat.vertex_color_use_as_albedo = true
	trunk_mat.vertex_color_is_srgb = true
	trunk_mat.roughness = 1.0
	_add_camera_fade(trunk_mat)
	leaf_mat = ShaderMaterial.new()
	leaf_mat.shader = FOLIAGE_SHADER

	for i in 2:
		tree_meshes["oak%d" % i] = _make_oak()
		tree_meshes["pine%d" % i] = _make_pine()
		tree_meshes["birch%d" % i] = _make_birch()
	for i in 3:
		rock_meshes.append(_make_rock())
	bush_mesh = _make_bush()


# ================================================================ terrain

## Ground height at a point: flat in the village, rising into hills and then
## mountains further out -- except to the east, where it slopes gently down
## into the sea.
func height_at(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
	var hills := smoothstep(PLAY_RADIUS + 1.0, PLAY_RADIUS + 16.0, r) * (2.0 + 6.0 * n)
	var far := smoothstep(55.0, 100.0, r) * (8.0 + 22.0 * n)
	var land := hills + far
	var cf := coast_factor(x, z)
	if cf <= 0.0:
		return land
	var beach: float = -max(0.0, r - 28.0) * 0.035 - max(0.0, r - 34.0) * 0.7
	beach = max(beach, -8.0)
	return lerpf(land, beach, cf)


## 1 straight east (the coast), fading to 0 about 55 degrees to either side.
func coast_factor(x: float, z: float) -> float:
	var a: float = abs(atan2(z, x))
	return 1.0 - smoothstep(0.55, 1.0, a)


## Is this spot sand rather than grass? (used to keep grass and flowers off the beach)
func is_sand(p: Vector3) -> bool:
	var r := Vector2(p.x, p.z).length()
	return coast_factor(p.x, p.z) * smoothstep(25.0, 27.5, r) > 0.3


## Distance from the village center to the waterline in a given direction,
## or -1 if there's no beach that way.
func shore_radius(angle: float) -> float:
	var dir := Vector2(cos(angle), sin(angle))
	if coast_factor(dir.x * 33.0, dir.y * 33.0) < 0.2:
		return -1.0
	var r := 26.0
	while r < 40.0:
		if height_at(dir.x * r, dir.y * r) < WATER_Y + 0.02:
			return r
		r += 0.2
	return -1.0


func build_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)   # faceted, low-poly shading
	var half := TERRAIN_SIZE * 0.5
	var steps := int(TERRAIN_SIZE / TERRAIN_STEP)
	for iz in steps:
		for ix in steps:
			var x0 := -half + ix * TERRAIN_STEP
			var z0 := -half + iz * TERRAIN_STEP
			var corners := [Vector2(x0, z0), Vector2(x0 + TERRAIN_STEP, z0),
				Vector2(x0 + TERRAIN_STEP, z0 + TERRAIN_STEP), Vector2(x0, z0 + TERRAIN_STEP)]
			var v := []
			for c in corners:
				v.append(Vector3(c.x, height_at(c.x, c.y), c.y))
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var center: Vector3 = (v[tri[0]] + v[tri[1]] + v[tri[2]]) / 3.0
				st.set_color(_ground_color(center))
				for k in tri:
					st.add_vertex(v[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 1.0
	mi.material_override = m
	add_child(mi)

	# A huge dark-green disc below everything, so there's never a void at the horizon
	var base := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 900.0
	disc.bottom_radius = 900.0
	disc.height = 0.1
	base.mesh = disc
	base.position.y = -3.0
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.2, 0.33, 0.2)
	base.material_override = bm
	add_child(base)

	# Collision: the real ground shape (so you can walk down the beach)...
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	var size := 121                      # 1 m spacing from -60 to +60
	hm.map_width = size
	hm.map_depth = size
	var data := PackedFloat32Array()
	data.resize(size * size)
	for iz in size:
		for ix in size:
			data[iz * size + ix] = height_at(ix - 60.0, iz - 60.0)
	hm.map_data = data
	col.shape = hm
	floor_body.add_child(col)
	add_child(floor_body)

	# ...and an invisible wall around the village: at the edge of the clearing,
	# or at the waterline on the beach side.
	var segments := 96
	var radii := []
	for i in segments:
		var a := TAU * (i + 0.5) / segments
		var rs := shore_radius(a)
		radii.append(rs + 0.9 if rs > 0.0 else PLAY_RADIUS + 1.5)
	for i in segments:
		var a0 := TAU * i / segments
		var a1 := TAU * (i + 1) / segments
		var r: float = radii[i]
		var mid := (a0 + a1) / 2
		var p := Vector3(cos(mid), 0, sin(mid)) * r
		if dock_gap.is_valid() and dock_gap.call(p):
			continue
		_wall(p, TAU * r / segments + 0.4, -mid + PI / 2)
		# close the gap where neighbouring wall pieces sit at different distances
		var r_next: float = radii[(i + 1) % segments]
		if abs(r_next - r) > 0.3:
			var rm := (r + r_next) / 2
			var pc := Vector3(cos(a1), 0, sin(a1)) * rm
			if not (dock_gap.is_valid() and dock_gap.call(pc)):
				_wall(pc, abs(r_next - r) + 0.8, -a1)


## Set by main.gd before build_terrain(): returns true where the dock
## crosses the edge, so no wall is placed there.
var dock_gap: Callable


func _wall(pos: Vector3, length: float, yaw: float) -> void:
	var wall := StaticBody3D.new()
	var wcol := CollisionShape3D.new()
	var wbox := BoxShape3D.new()
	wbox.size = Vector3(length, 6, 1.0)
	wcol.shape = wbox
	wall.add_child(wcol)
	wall.position = pos + Vector3(0, 3, 0)
	wall.rotation.y = yaw
	add_child(wall)


## The sea: a big animated plane at sea level on the east side.
func build_ocean() -> void:
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(700, 1400)
	plane.subdivide_width = 140
	plane.subdivide_depth = 280
	sea.mesh = plane
	sea.position = Vector3(355, WATER_Y, 0)
	var m := ShaderMaterial.new()
	m.shader = OCEAN_SHADER
	m.set_shader_parameter("shore_radius", SHORE_RADIUS)
	sea.material_override = m
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sea)
	# the sound of the waves, coming from the beach
	var waves := Audio.make_waves_player()
	waves.position = Vector3(SHORE_RADIUS, 0.5, 0)
	add_child(waves)


func _ground_color(p: Vector3) -> Color:
	var d := detail.get_noise_2d(p.x, p.z) * 0.5 + 0.5
	var grass := Color(0.33, 0.56, 0.22).lerp(Color(0.27, 0.48, 0.19), d)
	var h := p.y
	var r := Vector2(p.x, p.z).length()
	var sandy := coast_factor(p.x, p.z) * smoothstep(25.0, 27.5, r)
	if sandy > 0.05 and h < 1.0:
		var sand := Color(0.88, 0.8, 0.58).lerp(Color(0.82, 0.73, 0.5), d)
		if h < WATER_Y + 0.05:
			sand = Color(0.62, 0.56, 0.4)   # wet sand under the water
		return grass.lerp(sand, clamp(sandy * 1.6, 0.0, 1.0))
	if h < 0.05:
		return grass
	var hill := Color(0.27, 0.5, 0.22).lerp(Color(0.22, 0.43, 0.2), d)
	var c := grass.lerp(hill, clamp(h / 3.0, 0.0, 1.0))
	if h > 12.0:
		c = c.lerp(Color(0.45, 0.47, 0.42), clamp((h - 12.0) / 8.0, 0.0, 1.0))
	if h > 24.0:
		c = c.lerp(Color(0.85, 0.87, 0.9), clamp((h - 24.0) / 6.0, 0.0, 1.0))
	return c


## Big faceted mountains far away; the fog turns them blue-grey.
func build_mountains() -> void:
	var mr := RandomNumberGenerator.new()
	mr.seed = 99
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	for i in 22:
		var a := TAU * i / 22.0 + mr.randf_range(-0.1, 0.1)
		var r := mr.randf_range(120.0, 150.0)
		if cos(a) > 0.3:
			continue   # open sea to the east
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = mr.randf_range(28.0, 45.0)
		cone.height = mr.randf_range(35.0, 70.0)
		cone.radial_segments = 7
		cone.rings = 3
		var mesh := _merge([[cone, Transform3D(Basis(), Vector3(0, cone.height / 2, 0)), Color(0.42, 0.47, 0.5)]], 2.5)
		_snow_cap(mesh, cone.height)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = Vector3(cos(a) * r, -2.0, sin(a) * r)
		mi.rotation.y = mr.randf() * TAU
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _snow_cap(mesh: ArrayMesh, height: float) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in range(0, verts.size(), 3):
		var top: float = max(verts[i].y, max(verts[i + 1].y, verts[i + 2].y))
		if top > height * 0.72:
			for k in 3:
				colors[i + k] = Color(0.92, 0.94, 0.97)
	arrays[Mesh.ARRAY_COLOR] = colors
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


# ================================================================ trees

## A single tree with collision (used inside the village).
func add_tree(parent: Node, pos: Vector3, kind := "", s := 1.0) -> Node3D:
	if kind == "":
		kind = ["oak0", "oak1", "pine0", "birch0", "oak0", "pine1", "birch1"][rng.randi() % 7]
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rng.randf() * TAU
	body.scale = Vector3.ONE * s
	var mi := MeshInstance3D.new()
	mi.mesh = tree_meshes[kind]
	mi.set_instance_shader_parameter("tint", _leaf_tint())
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.45
	shape.height = 2.5
	col.shape = shape
	col.position.y = 1.25
	body.add_child(col)
	parent.add_child(body)
	return body


## The forest on the hills around the village (drawn efficiently with MultiMesh).
func build_forest() -> void:
	var spots := {}
	for key in tree_meshes:
		spots[key] = []
	var placed := 0
	var tries := 0
	while placed < 520 and tries < 6000:
		tries += 1
		var a := rng.randf() * TAU
		var r := PLAY_RADIUS + 2.5 + pow(rng.randf(), 0.7) * 65.0
		var x := cos(a) * r
		var z := sin(a) * r
		# clumpy forest: skip spots where the noise says "clearing"
		if detail.get_noise_2d(x * 0.4, z * 0.4) < -0.35 and r > 40.0:
			continue
		var h := height_at(x, z)
		if h > 20.0:
			continue   # no trees on the mountain tops
		if h < 0.5 or (coast_factor(x, z) > 0.35 and r < 60.0):
			continue   # nor on the beach or in the sea
		var kind: String
		if h > 9.0 or rng.randf() < 0.3:
			kind = "pine%d" % (rng.randi() % 2)
		elif rng.randf() < 0.25:
			kind = "birch%d" % (rng.randi() % 2)
		else:
			kind = "oak%d" % (rng.randi() % 2)
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.6)), Vector3(x, h - 0.1, z))
		spots[kind].append(t)
		placed += 1
	for kind in spots:
		var list: Array = spots[kind]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = tree_meshes[kind]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
			mm.set_instance_color(i, _leaf_tint())
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)


func _leaf_tint() -> Color:
	return Color(1, 1, 1).lerp(Color(0.85, 1.05, 0.8), rng.randf())


func _make_oak() -> ArrayMesh:
	var trunk := []
	trunk.append([_cyl(0.2, 0.34, 2.4, 6), Transform3D(Basis(), Vector3(0, 1.2, 0)), Color(0.45, 0.3, 0.18)])
	trunk.append([_cyl(0.07, 0.13, 1.1, 5), Transform3D(Basis(Vector3.FORWARD, 0.8), Vector3(0.35, 1.9, 0)), Color(0.45, 0.3, 0.18)])
	var leaves := []
	var greens := [Color(0.3, 0.58, 0.22), Color(0.36, 0.64, 0.25), Color(0.26, 0.52, 0.2)]
	for i in rng.randi_range(4, 6):
		var a := rng.randf() * TAU
		var d := rng.randf_range(0.3, 0.9)
		var rad := rng.randf_range(0.8, 1.25)
		leaves.append([_ball(rad), Transform3D(Basis(), Vector3(cos(a) * d, rng.randf_range(2.7, 3.6), sin(a) * d)), greens[i % greens.size()]])
	leaves.append([_ball(1.2), Transform3D(Basis(), Vector3(0, 3.9, 0)), greens[1]])
	return _tree_mesh(trunk, leaves)


func _make_pine() -> ArrayMesh:
	var trunk := [[_cyl(0.12, 0.26, 2.0, 6), Transform3D(Basis(), Vector3(0, 1.0, 0)), Color(0.4, 0.27, 0.16)]]
	var leaves := []
	var green := Color(0.18, 0.42, 0.24).lerp(Color(0.22, 0.48, 0.26), rng.randf())
	var tiers := rng.randi_range(3, 4)
	for i in tiers:
		var w := lerpf(1.7, 0.7, float(i) / tiers)
		leaves.append([_cyl(0.0, w, 1.6, 7), Transform3D(Basis(Vector3.UP, rng.randf()), Vector3(0, 1.6 + i * 0.95 + 0.8, 0)), green.darkened(0.05 * i)])
	return _tree_mesh(trunk, leaves)


func _make_birch() -> ArrayMesh:
	var trunk := [[_cyl(0.13, 0.2, 3.4, 6), Transform3D(Basis(), Vector3(0, 1.7, 0)), Color(0.92, 0.9, 0.85)]]
	# a few dark bark marks
	for i in 4:
		trunk.append([_cyl(0.205, 0.205, 0.08, 6), Transform3D(Basis(), Vector3(0, 0.6 + i * 0.7, 0)), Color(0.2, 0.2, 0.2)])
	var leaves := []
	for i in 4:
		var a := rng.randf() * TAU
		leaves.append([_ball(rng.randf_range(0.6, 0.85)), Transform3D(Basis(), Vector3(cos(a) * 0.4, 3.3 + i * 0.35, sin(a) * 0.4)),
			Color(0.55, 0.72, 0.28).lerp(Color(0.62, 0.78, 0.3), rng.randf())])
	return _tree_mesh(trunk, leaves)


func _tree_mesh(trunk_parts: Array, leaf_parts: Array) -> ArrayMesh:
	var mesh := _merge(trunk_parts, 0.0)
	mesh.surface_set_material(0, trunk_mat)
	var leaves := _merge(leaf_parts, 0.18)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, leaves.surface_get_arrays(0))
	mesh.surface_set_material(1, leaf_mat)
	return mesh


# ================================================================ beach

## Palm trees, driftwood, shells and a rowboat along the beach.
## is_free(pos, margin) keeps them away from the dock and Sal's hut.
func build_beach(is_free: Callable) -> void:
	var palm := _make_palm()
	var placed := 0
	for attempt in 300:
		if placed >= 9:
			break
		var a := rng.randf_range(-0.75, 0.75)
		var rs := shore_radius(a)
		if rs < 0.0:
			continue
		var r := rng.randf_range(26.5, rs - 1.8)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = height_at(p.x, p.z)
		if not is_free.call(p, 1.5):
			continue
		var body := StaticBody3D.new()
		body.position = p
		body.rotation.y = rng.randf() * TAU
		body.scale = Vector3.ONE * rng.randf_range(0.9, 1.25)
		var mi := MeshInstance3D.new()
		mi.mesh = palm
		body.add_child(mi)
		var col := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.3
		shape.height = 2.0
		col.shape = shape
		col.position.y = 1.0
		body.add_child(col)
		add_child(body)
		placed += 1

	# Driftwood logs
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.62, 0.52, 0.4)
	for i in 4:
		var a := rng.randf_range(-0.6, 0.6)
		var rs := shore_radius(a)
		if rs < 0.0:
			continue
		var p := Vector3(cos(a), 0, sin(a)) * (rs - rng.randf_range(0.8, 2.5))
		if not is_free.call(p, 1.0):
			continue
		var log := MeshInstance3D.new()
		log.mesh = _cyl(0.14, 0.18, rng.randf_range(1.4, 2.2), 7)
		log.material_override = wood
		log.position = p + Vector3(0, height_at(p.x, p.z) + 0.12, 0)
		log.rotation = Vector3(PI / 2, rng.randf() * TAU, 0)
		add_child(log)

	# Shells and pebbles scattered on the sand
	var shell := SphereMesh.new()
	shell.radius = 0.07
	shell.height = 0.06
	shell.radial_segments = 6
	shell.rings = 3
	var sm := StandardMaterial3D.new()
	sm.vertex_color_use_as_albedo = true
	sm.vertex_color_is_srgb = true
	shell.material = sm
	var ts := []
	var cs := []
	for i in 160:
		var a := rng.randf_range(-0.8, 0.8)
		var rs := shore_radius(a)
		if rs < 0.0:
			continue
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(27.0, rs + 0.3)
		p.y = height_at(p.x, p.z) + 0.02
		ts.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), p))
		cs.append([Color(1, 0.95, 0.9), Color(1, 0.8, 0.75), Color(0.8, 0.75, 0.7), Color(0.95, 0.85, 0.6)][rng.randi() % 4])
	_multimesh(shell, ts, cs)


## A rowboat pulled up on the sand.
func add_rowboat(pos: Vector3, yaw: float) -> void:
	var boat := Node3D.new()
	boat.position = pos
	boat.rotation.y = yaw
	var hull := StandardMaterial3D.new()
	hull.albedo_color = Color(0.3, 0.45, 0.65)
	var inside := StandardMaterial3D.new()
	inside.albedo_color = Color(0.6, 0.45, 0.3)
	for part in [[Vector3(0, 0.25, 0), Vector3(1.2, 0.4, 2.6), hull], [Vector3(0, 0.38, 0), Vector3(1.0, 0.2, 2.3), inside],
			[Vector3(0, 0.45, 0.3), Vector3(1.1, 0.06, 0.25), inside], [Vector3(0, 0.25, 1.45), Vector3(0.7, 0.35, 0.4), hull]]:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = part[1]
		mi.mesh = b
		mi.position = part[0]
		mi.material_override = part[2]
		boat.add_child(mi)
	boat.rotation.z = 0.08
	add_child(boat)


## A striped lighthouse on the headland; its lamp turns at night.
func build_lighthouse(pos: Vector3) -> void:
	var lh := Node3D.new()
	lh.position = pos
	add_child(lh)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.95, 0.95, 0.93)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.8, 0.2, 0.18)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.2, 0.22, 0.25)
	for i in 5:
		var seg := MeshInstance3D.new()
		var top_r := lerpf(1.6, 1.05, (i + 1) / 5.0)
		var bot_r := lerpf(1.6, 1.05, i / 5.0)
		seg.mesh = _cyl(top_r, bot_r, 2.0, 12)
		seg.position.y = 1.0 + i * 2.0
		seg.material_override = white if i % 2 == 0 else red
		lh.add_child(seg)
	var gallery := MeshInstance3D.new()
	gallery.mesh = _cyl(1.5, 1.5, 0.25, 12)
	gallery.position.y = 10.1
	gallery.material_override = dark
	lh.add_child(gallery)
	var lamp_room := MeshInstance3D.new()
	lamp_room.mesh = _cyl(0.85, 0.85, 1.4, 10)
	lamp_room.position.y = 10.9
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(1, 0.95, 0.7)
	glass.emission_enabled = true
	glass.emission = Color(1, 0.85, 0.5)
	glass.emission_energy_multiplier = 1.0
	lamp_room.material_override = glass
	lh.add_child(lamp_room)
	var cap := MeshInstance3D.new()
	cap.mesh = _cyl(0.0, 1.1, 1.0, 10)
	cap.position.y = 12.1
	cap.material_override = red
	lh.add_child(cap)
	var glow := OmniLight3D.new()
	glow.position.y = 10.9
	glow.omni_range = 12.0
	glow.light_color = Color(1, 0.85, 0.55)
	lh.add_child(glow)
	lighthouse_lights.append(glow)
	lighthouse_beam = Node3D.new()
	lighthouse_beam.position.y = 10.9
	lh.add_child(lighthouse_beam)
	var spot := SpotLight3D.new()
	spot.spot_range = 90.0
	spot.spot_angle = 12.0
	spot.light_color = Color(1, 0.9, 0.65)
	spot.rotation.x = -0.12
	lighthouse_beam.add_child(spot)
	lighthouse_lights.append(spot)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.6
	shape.height = 12.0
	col.shape = shape
	col.position.y = 6.0
	body.add_child(col)
	lh.add_child(body)


func _process(delta: float) -> void:
	if lighthouse_beam:
		lighthouse_beam.rotation.y += delta * 0.8


func _make_palm() -> ArrayMesh:
	var trunk := []
	var p := Vector3.ZERO
	var lean := Vector3(0.18, 0, 0)
	for i in 7:
		var seg := _cyl(0.13 - i * 0.008, 0.16 - i * 0.008, 0.62, 6)
		p += Vector3(0, 0.58, 0) + lean * (i * 0.18)
		trunk.append([seg, Transform3D(Basis(Vector3.FORWARD, -0.06 * i), p), Color(0.6, 0.47, 0.32).lerp(Color(0.5, 0.38, 0.25), i % 2)])
	var top := p + Vector3(0, 0.3, 0)
	var leaves := []
	for i in 7:
		var a := TAU * i / 7.0
		var leaf := BoxMesh.new()
		leaf.size = Vector3(0.5, 0.05, 2.0)
		var basis := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.45)
		leaves.append([leaf, Transform3D(basis, top + basis * Vector3(0, 0, 0.95)), Color(0.3, 0.6, 0.22).lerp(Color(0.38, 0.66, 0.25), rng.randf())])
	for i in 3:
		var a := TAU * i / 3.0
		trunk.append([_ball(0.12, 6, 4), Transform3D(Basis(), top + Vector3(cos(a) * 0.18, -0.15, sin(a) * 0.18)), Color(0.4, 0.28, 0.15)])
	return _tree_mesh(trunk, leaves)


# ================================================================ rocks, bushes, flowers, grass

func add_rock(parent: Node, pos: Vector3, s := 1.0) -> Node3D:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = rng.randf() * TAU
	var mi := MeshInstance3D.new()
	mi.mesh = rock_meshes[rng.randi() % rock_meshes.size()]
	mi.scale = Vector3(1.3, 0.8, 1.0) * s
	body.add_child(mi)
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.8 * s
	col.shape = shape
	col.position.y = 0.2
	body.add_child(col)
	parent.add_child(body)
	return body


func _make_rock() -> ArrayMesh:
	var m := _merge([[_ball(0.9, 7, 5), Transform3D(Basis(), Vector3(0, 0.35, 0)), Color(0.45, 0.45, 0.48)]], 0.3)
	# vary the grey per face a little so it reads as stone
	var arrays := m.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	for i in range(0, colors.size(), 3):
		var c := Color(0.46, 0.46, 0.49).lerp(Color(0.36, 0.4, 0.37), rng.randf())
		for k in 3:
			colors[i + k] = c
	arrays[Mesh.ARRAY_COLOR] = colors
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	_add_camera_fade(mat)
	out.surface_set_material(0, mat)
	return out


func _make_bush() -> ArrayMesh:
	var parts := []
	for i in 3:
		var a := TAU * i / 3.0
		parts.append([_ball(rng.randf_range(0.4, 0.55)), Transform3D(Basis(), Vector3(cos(a) * 0.35, 0.35, sin(a) * 0.35)),
			Color(0.25, 0.5, 0.2).lerp(Color(0.32, 0.58, 0.22), rng.randf())])
	parts.append([_ball(0.5), Transform3D(Basis(), Vector3(0, 0.6, 0)), Color(0.3, 0.56, 0.22)])
	var m := _merge(parts, 0.1)
	m.surface_set_material(0, leaf_mat)
	return m


## Bushes, flower patches and grass tufts scattered around the village.
## is_free(pos, margin) says whether a spot is clear of buildings and paths.
func scatter_decor(is_free: Callable) -> void:
	# Bushes
	var bush_t := []
	for i in 400:
		if bush_t.size() >= 45:
			break
		var p := _random_in_village(PLAY_RADIUS - 1.0)
		if is_free.call(p, 1.2):
			bush_t.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.3)), p))
	_multimesh(bush_mesh, bush_t, [])
	# ...and a ring of bushes along the edge of the village
	var ring := []
	for i in 70:
		var a := TAU * i / 70.0 + rng.randf_range(-0.03, 0.03)
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(PLAY_RADIUS + 0.6, PLAY_RADIUS + 2.2)
		if coast_factor(p.x, p.z) > 0.15:
			continue   # no hedge along the beach
		ring.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.0, 1.8)), p))
	_multimesh(bush_mesh, ring, [])

	# Flower patches
	var petal := BoxMesh.new()
	petal.size = Vector3(0.14, 0.14, 0.14)
	var fm := StandardMaterial3D.new()
	fm.vertex_color_use_as_albedo = true
	fm.vertex_color_is_srgb = true
	petal.material = fm
	var stem := BoxMesh.new()
	stem.size = Vector3(0.03, 0.3, 0.03)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.3, 0.6, 0.25)
	stem.material = sm
	var flower_t := []
	var flower_c := []
	var stem_t := []
	var palette := [Color(1, 0.45, 0.6), Color(1, 0.9, 0.3), Color(0.65, 0.55, 1), Color(1, 1, 1), Color(1, 0.55, 0.25)]
	for patch in 22:
		var center := _random_in_village(PLAY_RADIUS - 2.0)
		if not is_free.call(center, 1.5):
			continue
		var col: Color = palette[rng.randi() % palette.size()]
		for k in rng.randi_range(6, 12):
			var p := center + Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))
			if not is_free.call(p, 0.3):
				continue
			stem_t.append(Transform3D(Basis(), p + Vector3(0, 0.15, 0)))
			flower_t.append(Transform3D(Basis(Vector3.UP, rng.randf()), p + Vector3(0, 0.33, 0)))
			flower_c.append(col)
	_multimesh(stem, stem_t, [])
	_multimesh(petal, flower_t, flower_c)

	# Grass tufts
	var blade := PrismMesh.new()
	blade.size = Vector3(0.12, 0.4, 0.05)
	var gm := StandardMaterial3D.new()
	gm.vertex_color_use_as_albedo = true
	gm.vertex_color_is_srgb = true
	blade.material = gm
	var grass_t := []
	var grass_c := []
	for i in 2600:
		var p := _random_in_village(PLAY_RADIUS + 1.0)
		if not is_free.call(p, 0.3):
			continue
		for k in 3:
			var q := p + Vector3(rng.randf_range(-0.12, 0.12), 0.18, rng.randf_range(-0.12, 0.12))
			var b := Basis(Vector3.UP, rng.randf() * TAU).rotated(Vector3.RIGHT, rng.randf_range(-0.25, 0.25))
			grass_t.append(Transform3D(b.scaled(Vector3.ONE * rng.randf_range(0.7, 1.3)), q))
			grass_c.append(Color(0.33, 0.62, 0.24).lerp(Color(0.45, 0.7, 0.28), rng.randf()))
	var gi := _multimesh(blade, grass_t, grass_c)
	gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _random_in_village(radius: float) -> Vector3:
	var a := rng.randf() * TAU
	var r := sqrt(rng.randf()) * radius
	return Vector3(cos(a) * r, 0, sin(a) * r)


func _multimesh(mesh: Mesh, transforms: Array, colors: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		if not colors.is_empty():
			mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	return mmi


# ================================================================ mesh helpers

func _cyl(top: float, bottom: float, height: float, sides: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = sides
	c.rings = 1
	return c


func _ball(radius: float, segments := 7, rings := 5) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = segments
	s.rings = rings
	return s


## Combines [mesh, transform, color] parts into one faceted mesh with vertex
## colors. jitter > 0 wobbles the vertices for a hand-made, lumpy look.
func _merge(parts: Array, jitter: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for part in parts:
		var arrays: Array = part[0].get_mesh_arrays()
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var xf: Transform3D = part[1]
		var seed_offset := rng.randf() * 100.0
		st.set_color(part[2])
		for i in idx:
			var v: Vector3 = verts[i]
			if jitter > 0.0:
				# same position -> same offset, so the surface stays closed
				v += Vector3(detail.get_noise_3d(v.x * 3 + seed_offset, v.y * 3, v.z * 3),
					detail.get_noise_3d(v.x * 3, v.y * 3 + seed_offset, v.z * 3),
					detail.get_noise_3d(v.x * 3, v.y * 3, v.z * 3 + seed_offset)) * jitter * 2.0
			st.add_vertex(xf * v)
	st.generate_normals()
	return st.commit()


func _add_camera_fade(m: BaseMaterial3D) -> void:
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	m.distance_fade_min_distance = 3.5
	m.distance_fade_max_distance = 7.5
