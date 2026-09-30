extends Node3D
## A firefly that comes out at night. It drifts around its meadow, blinks,
## and flits away when you get close -- sneak up and press E to catch it in a
## jar (sells for coins at the market).

var home := Vector3.ZERO      # it stays near here
var world: Node               # main.gd (for toasts / inventory)
var interact_range := 1.7
var drift := Vector3.ZERO
var drift_timer := 0.0
var t := randf() * 10.0
var light: OmniLight3D
var glow: MeshInstance3D
var caught := false


func _ready() -> void:
	add_to_group("interactable")
	glow = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.09
	s.height = 0.18
	glow.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.9, 1.0, 0.45)
	m.emission_enabled = true
	m.emission = Color(0.85, 1.0, 0.35)
	m.emission_energy_multiplier = 4.0
	glow.material_override = m
	add_child(glow)
	# soft glowing halo (a camera-facing quad with a radial gradient)
	var halo := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	halo.mesh = q
	var grad := Gradient.new()
	grad.set_color(0, Color(0.9, 1.0, 0.5, 0.9))
	grad.set_color(1, Color(0.8, 1.0, 0.3, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var hm := StandardMaterial3D.new()
	hm.albedo_texture = tex
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.no_depth_test = false
	halo.material_override = hm
	glow.add_child(halo)
	light = OmniLight3D.new()
	light.light_color = Color(0.8, 1.0, 0.4)
	light.omni_range = 3.0
	light.light_energy = 1.4
	light.shadow_enabled = false
	add_child(light)


func _process(delta: float) -> void:
	if caught:
		return
	t += delta
	# blink
	var b: float = 0.55 + 0.45 * sin(t * 3.1) * sin(t * 1.7)
	light.light_energy = 1.4 * b
	glow.scale = Vector3.ONE * (0.6 + 0.5 * b)

	var player: Node3D = world.player if world else null
	var move := Vector3.ZERO
	if player:
		var away := global_position - player.global_position
		away.y = 0.0
		if away.length() < 3.2 and away.length() > 0.01:
			move = away.normalized() * 1.8    # flit away! (you're faster, so creep up)
	if move == Vector3.ZERO:
		drift_timer -= delta
		if drift_timer <= 0.0:
			drift_timer = randf_range(1.0, 2.5)
			var to_home := home - global_position
			to_home.y = 0.0
			drift = (Vector3(randf() - 0.5, 0, randf() - 0.5).normalized() * 0.5 + to_home * 0.15)
		move = drift
	global_position += move * delta
	# don't wander too far from the meadow
	var off := global_position - home
	off.y = 0.0
	if off.length() > 6.0:
		global_position -= off.normalized() * (off.length() - 6.0)
	global_position.y = 1.0 + 0.35 * sin(t * 1.3) + 0.15 * sin(t * 3.7)


func distance_to_player(player: Node3D) -> float:
	return Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()


func get_prompt(_player: Node3D) -> String:
	return "" if caught else "E: Catch the firefly"


func interact(_player: Node3D) -> void:
	if caught:
		return
	caught = true
	remove_from_group("interactable")
	Game.add_item("firefly")
	Audio.play("ding", 0.1)
	if world:
		world.hud.show_toast("Caught a firefly! (%d in jars)  Sell them at the market." % Game.count("firefly"), 2.5)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.01, 0.25)
	tw.tween_callback(queue_free)
