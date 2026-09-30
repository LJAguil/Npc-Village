extends Node3D
## The visible body of a character (player or NPC): the Kenney robot model,
## recolored, with an optional hat, and simple animation helpers.
## The parent CharacterBody3D rotates this node to face where it's going.

const MODEL := preload("res://models/character.glb")
const RECOLOR := preload("res://shaders/recolor.gdshader")

var model: Node3D
var anim: AnimationPlayer


## hue: 0..1 to recolor the purple parts, or -1 to keep the original purple.
## accessory: "", "chef_hat", "top_hat" or "flower".
func setup(hue: float, accessory: String, model_scale := 1.5) -> void:
	model = MODEL.instantiate()
	model.scale = Vector3.ONE * model_scale
	model.rotation.y = PI        # the model faces +Z; our characters face -Z
	model.position.y = -0.9      # body origin is the capsule's center; this puts feet on the ground
	add_child(model)

	anim = model.find_child("AnimationPlayer", true, false)
	if anim:
		for a in ["idle", "walk"]:
			if anim.has_animation(a):
				anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR

	if hue >= 0.0:
		_recolor(model, hue)
	if accessory != "":
		_add_accessory(accessory, model_scale)
	play("idle")


func play(anim_name: String, speed := 1.0) -> void:
	if anim == null:
		return
	if anim.current_animation != anim_name:
		anim.play(anim_name, 0.15)
	anim.speed_scale = speed


## Picks idle / walk / jump from how the body is moving.
func animate_from_velocity(velocity: Vector3, on_floor: bool, walk_speed: float) -> void:
	var horizontal := Vector2(velocity.x, velocity.z).length()
	if hat and accessory_kind == "propeller_cap":
		var prop := hat.get_node_or_null("Propeller")
		if prop:
			prop.rotation.y += 0.05 + horizontal * 0.06   # spins faster when you run
	if not on_floor:
		play("jump")
	elif horizontal > 0.2:
		play("walk", clamp(horizontal / walk_speed, 0.6, 2.0))
	else:
		play("idle")


func _recolor(node: Node, hue: float) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child
			for i in mi.mesh.get_surface_count():
				var src := mi.get_active_material(i)
				if src is BaseMaterial3D and src.albedo_texture:
					var m := ShaderMaterial.new()
					m.shader = RECOLOR
					m.set_shader_parameter("tex", src.albedo_texture)
					m.set_shader_parameter("target_hue", hue)
					mi.set_surface_override_material(i, m)
		_recolor(child, hue)


## Hats are attached to the robot's torso (which carries the head), so they
## bob and tilt with the walk animation instead of floating in place. They're
## designed for a 1.5x-scale robot and shrink/grow with the model.
var hat: Node3D
var accessory_kind := ""


func _add_accessory(kind: String, _s: float) -> void:
	set_accessory(kind)


func set_accessory(kind: String) -> void:
	if hat:
		hat.queue_free()
		hat = null
	accessory_kind = kind
	var antenna := model.find_child("antenna", true, false)
	if antenna:
		antenna.visible = kind == "" or kind == "flower" or kind == "flower_crown"
	if kind == "":
		return
	var torso: Node3D = model.find_child("torso", true, false)
	hat = Node3D.new()
	hat.scale = Vector3.ONE / 1.5
	hat.position = Vector3(0, 0.6, 0.02)    # top of the head, in the torso's space
	if torso:
		torso.add_child(hat)
	else:
		hat.position.y = 0.8
		model.add_child(hat)

	match kind:
		"chef_hat":
			hat.add_child(_part(CylinderMesh.new(), Color.WHITE, Vector3(0, 0.15, 0), Vector3(0.55, 0.3, 0.55)))
			hat.add_child(_part(SphereMesh.new(), Color.WHITE, Vector3(0, 0.38, 0), Vector3(0.75, 0.4, 0.75)))
		"top_hat":
			hat.add_child(_part(CylinderMesh.new(), Color(0.12, 0.12, 0.15), Vector3(0, 0.02, 0), Vector3(0.9, 0.04, 0.9)))
			hat.add_child(_part(CylinderMesh.new(), Color(0.12, 0.12, 0.15), Vector3(0, 0.27, 0), Vector3(0.5, 0.5, 0.5)))
			hat.add_child(_part(CylinderMesh.new(), Color(0.7, 0.15, 0.2), Vector3(0, 0.1, 0), Vector3(0.52, 0.08, 0.52)))
		"sailor_hat":
			hat.add_child(_part(CylinderMesh.new(), Color(0.95, 0.95, 0.97), Vector3(0, 0.12, 0), Vector3(0.62, 0.24, 0.62)))
			hat.add_child(_part(CylinderMesh.new(), Color(0.15, 0.2, 0.4), Vector3(0, 0.02, 0), Vector3(0.7, 0.05, 0.7)))
			hat.add_child(_part(CylinderMesh.new(), Color(0.15, 0.2, 0.4), Vector3(0, 0.22, 0), Vector3(0.64, 0.05, 0.64)))
		"flower":
			var f := Node3D.new()
			f.position = Vector3(0.25, 0.05, 0)
			f.rotation.z = -0.4
			f.add_child(_part(SphereMesh.new(), Color(1, 0.45, 0.7), Vector3.ZERO, Vector3(0.3, 0.12, 0.3)))
			f.add_child(_part(SphereMesh.new(), Color(1, 0.9, 0.3), Vector3(0, 0.05, 0), Vector3(0.12, 0.08, 0.12)))
			hat.add_child(f)
		# ---- hats you can buy at the market
		"straw_hat":
			hat.add_child(_part(CylinderMesh.new(), Color(0.93, 0.8, 0.45), Vector3(0, 0.02, 0), Vector3(1.25, 0.04, 1.25)))
			hat.add_child(_part(SphereMesh.new(), Color(0.93, 0.8, 0.45), Vector3(0, 0.08, 0), Vector3(0.62, 0.32, 0.62)))
			hat.add_child(_part(CylinderMesh.new(), Color(0.8, 0.25, 0.2), Vector3(0, 0.07, 0), Vector3(0.64, 0.07, 0.64)))
		"party_hat":
			var cone := CylinderMesh.new()
			hat.add_child(_part(cone, Color(0.3, 0.6, 1.0), Vector3(0, 0.25, 0), Vector3(0.45, 0.5, 0.45), 0.0))
			hat.add_child(_part(SphereMesh.new(), Color(1, 0.85, 0.2), Vector3(0, 0.52, 0), Vector3(0.12, 0.12, 0.12)))
			hat.add_child(_part(CylinderMesh.new(), Color(1, 0.4, 0.6), Vector3(0, 0.12, 0), Vector3(0.36, 0.05, 0.36)))
		"flower_crown":
			var colors := [Color(1, 0.45, 0.6), Color(1, 0.9, 0.3), Color(0.6, 0.55, 1), Color(1, 1, 1)]
			for i in 8:
				var a := TAU * i / 8.0
				hat.add_child(_part(SphereMesh.new(), colors[i % 4], Vector3(cos(a) * 0.3, 0.02, sin(a) * 0.3), Vector3(0.14, 0.1, 0.14)))
			hat.add_child(_part(CylinderMesh.new(), Color(0.3, 0.6, 0.25), Vector3(0, 0.0, 0), Vector3(0.62, 0.03, 0.62)))
		"pirate_hat":
			hat.add_child(_part(BoxMesh.new(), Color(0.1, 0.1, 0.12), Vector3(0, 0.14, 0), Vector3(1.0, 0.3, 0.42)))
			hat.add_child(_part(SphereMesh.new(), Color(0.1, 0.1, 0.12), Vector3(0, 0.22, 0), Vector3(0.6, 0.34, 0.5)))
			hat.add_child(_part(BoxMesh.new(), Color(0.95, 0.85, 0.3), Vector3(0, 0.13, 0.215), Vector3(0.9, 0.04, 0.01)))
			hat.add_child(_part(SphereMesh.new(), Color(0.95, 0.95, 0.95), Vector3(0, 0.22, 0.24), Vector3(0.12, 0.12, 0.04)))
		"propeller_cap":
			var cols := [Color(1, 0.3, 0.3), Color(1, 0.85, 0.2), Color(0.3, 0.6, 1), Color(0.4, 0.85, 0.4)]
			for i in 4:
				var wedge := _part(SphereMesh.new(), cols[i], Vector3(cos(TAU * i / 4.0) * 0.08, 0.1, sin(TAU * i / 4.0) * 0.08), Vector3(0.45, 0.3, 0.45))
				hat.add_child(wedge)
			hat.add_child(_part(BoxMesh.new(), Color(1, 0.3, 0.3), Vector3(0, 0.02, 0.33), Vector3(0.4, 0.03, 0.25)))
			hat.add_child(_part(CylinderMesh.new(), Color(0.2, 0.2, 0.2), Vector3(0, 0.3, 0), Vector3(0.04, 0.12, 0.04)))
			var prop := Node3D.new()
			prop.name = "Propeller"
			prop.position = Vector3(0, 0.37, 0)
			prop.add_child(_part(BoxMesh.new(), Color(1, 0.85, 0.2), Vector3.ZERO, Vector3(0.5, 0.02, 0.08)))
			prop.add_child(_part(BoxMesh.new(), Color(0.3, 0.6, 1), Vector3.ZERO, Vector3(0.08, 0.02, 0.5)))
			hat.add_child(prop)
		"crown":
			var gold := Color(1, 0.8, 0.2)
			hat.add_child(_part(CylinderMesh.new(), gold, Vector3(0, 0.08, 0), Vector3(0.6, 0.16, 0.6), -1.0, true))
			for i in 5:
				var a := TAU * i / 5.0
				hat.add_child(_part(CylinderMesh.new(), gold, Vector3(cos(a) * 0.26, 0.22, sin(a) * 0.26), Vector3(0.09, 0.16, 0.09), 0.0, true))
				hat.add_child(_part(SphereMesh.new(), [Color(0.9, 0.1, 0.2), Color(0.2, 0.5, 1)][i % 2], Vector3(cos(a) * 0.3, 0.09, sin(a) * 0.3), Vector3(0.07, 0.07, 0.07)))


## top: for cylinders, the top radius (0 makes a cone; -1 = same as bottom).
## shiny: metallic gold look.
func _part(mesh: PrimitiveMesh, color: Color, pos: Vector3, size: Vector3, top := -1.0, shiny := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	# Primitive meshes default to 1 unit tall/wide (sphere radius 0.5), so scale = size
	if mesh is CylinderMesh:
		mesh.top_radius = 0.5 if top < 0.0 else top
		mesh.bottom_radius = 0.5
		mesh.height = 1.0
	elif mesh is BoxMesh:
		mesh.size = Vector3.ONE
	elif mesh is SphereMesh:
		mesh.radius = 0.5
		mesh.height = 1.0
	mi.mesh = mesh
	mi.scale = size
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if shiny:
		m.metallic = 0.8
		m.roughness = 0.25
		m.emission_enabled = true
		m.emission = color * 0.25
	mi.material_override = m
	return mi
