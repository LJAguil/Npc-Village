extends CanvasLayer
## Screen minigames:
##   "baking"  -- stop the swinging oven needle in the golden zone (Bram's quest)
##   "memory"  -- watch Ivy's flower pattern, then repeat it with keys 1-4 (Ivy's quest)
##   "harvest" -- "Pull!": stop the rising marker in the green band (farming)
##   "crabs"   -- whack-a-crab on the beach rocks; don't grab the jellyfish!
## start(kind, on_done): on_done is called with the result when the game ends:
##   baking / memory -> bool (won?), harvest -> 0 miss / 1 good / 2 perfect,
##   crabs -> number of crabs caught.

const UI := preload("res://scripts/ui_style.gd")
const ICON := preload("res://scripts/ui_icon.gd")
const BAR_W := 440.0

var kind := ""
var on_done: Callable
var grace := 0.0
var root: PanelContainer
var content: VBoxContainer
var status: Label
var pips_box: HBoxContainer
var body: Control

# baking
var bar: Control
var zone: ColorRect
var needle: ColorRect
var loaf: Control
var needle_x := 0.0
var needle_dir := 1.0
var needle_speed := 300.0
var zone_w := 90.0
var zone_x := 0.0
var bakes := 0
var misses := 0
var pause := 0.0

# memory
const FLOWER_COLORS := [Color(1, 0.45, 0.6), Color(1, 0.85, 0.25), Color(0.55, 0.55, 1), Color(0.97, 0.97, 0.97)]
const FLOWER_NAMES := ["Pink", "Yellow", "Blue", "White"]
var pads: Array = []
var sequence: Array = []
var round_lengths := [3, 4, 5]
var round_index := 0
var input_pos := 0
var showing := false
var mistakes := 0

# harvest
const PULL_H := 240.0
var pull_marker: ColorRect
var pull_band_y := 0.0      # bottom of the green band, measured up from the bottom
var pull_band_h := 34.0
var pull_t := 0.0
var pull_speed := 1.6
var pull_time_left := 0.0
var pull_done := false
var crop_icon: Control

# crabs
const CRAB_TIME := 25.0
var holes: Array = []        # Buttons
var hole_state: Array = []   # "" / "crab" / "jelly"
var hole_timer: Array = []
var crab_time_left := 0.0
var spawn_timer := 0.0
var crabs_caught := 0
var time_bar: ColorRect


func _ready() -> void:
	layer = 7
	process_mode = Node.PROCESS_MODE_PAUSABLE
	root = PanelContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(root)
	visible = false


func start(which: String, done: Callable) -> void:
	kind = which
	on_done = done
	grace = 0.4
	for c in root.get_children():
		c.queue_free()
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	root.add_child(content)
	visible = true
	_setup_kind()
	await get_tree().process_frame
	root.reset_size()
	root.position = (root.get_viewport_rect().size - root.size) / 2
	UI.pop_in(root)


## Subclasses (house_games.gd) override these three to add more games.
func _setup_kind() -> void:
	match kind:
		"baking":
			_setup_baking()
		"memory":
			_setup_memory()
		"harvest":
			_setup_harvest()
		"crabs":
			_setup_crabs()


func _run_kind(delta: float) -> void:
	match kind:
		"baking":
			_run_baking(delta)
		"harvest":
			_run_harvest(delta)
		"crabs":
			_run_crabs(delta)


func _input_kind(event: InputEvent) -> void:
	if kind == "baking" and event.is_action_pressed("reel"):
		get_viewport().set_input_as_handled()
		_bake_press()
	elif kind == "harvest" and event.is_action_pressed("reel"):
		get_viewport().set_input_as_handled()
		_pull_press()
	elif kind == "memory" and not showing:
		for i in 4:
			if event.is_action_pressed("choice_%d" % (i + 1)):
				get_viewport().set_input_as_handled()
				_memory_press(i)
	elif kind == "crabs":
		for i in 9:
			if event.is_action_pressed("choice_%d" % (i + 1)):
				get_viewport().set_input_as_handled()
				_crab_press(i)


func _finish(result) -> void:
	visible = false
	kind = ""
	if on_done.is_valid():
		on_done.call(result)


func _frame(title: String, subtitle: String, accent: Color, icon: String, icon_color := Color.WHITE) -> void:
	root.add_theme_stylebox_override("panel", UI.panel_style(accent.lightened(0.15)))
	content.add_child(UI.header(title, subtitle, accent, icon, icon_color))
	body = Control.new()
	body.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(body)
	pips_box = HBoxContainer.new()
	pips_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pips_box.add_theme_constant_override("separation", 24)
	content.add_child(pips_box)
	status = UI.small_label("", UI.CREAM, 19)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(status)


func _set_pips(rows: Array) -> void:
	for c in pips_box.get_children():
		c.queue_free()
	for r in rows:
		pips_box.add_child(UI.pips(r[0], r[1], r[2], r[3]))


func _process(delta: float) -> void:
	if not visible:
		return
	grace -= delta
	_run_kind(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or grace > 0.0:
		return
	_input_kind(event)


# ================================================================ baking

func _setup_baking() -> void:
	_frame("Bake the Bread!", "Stop the needle in the golden zone. Bake 3 loaves -- you can miss twice.",
		Color(0.85, 0.5, 0.2), "bread")
	bakes = 0
	misses = 0
	needle_speed = 280.0
	zone_w = 95.0
	pause = 0.0
	body.custom_minimum_size = Vector2(BAR_W, 150)
	bar = Panel.new()
	var bs := StyleBoxFlat.new()
	bs.set_corner_radius_all(10)
	bs.bg_color = Color(0.1, 0.07, 0.05)
	bar.add_theme_stylebox_override("panel", bs)
	bar.size = Vector2(BAR_W, 40)
	bar.position = Vector2(0, 18)
	bar.clip_contents = true
	body.add_child(bar)
	# temperature gradient: cold (blue) -> hot (red)
	for i in 22:
		var seg := ColorRect.new()
		seg.size = Vector2(BAR_W / 22.0 + 1, 32)
		seg.position = Vector2(i * BAR_W / 22.0, 4)
		seg.color = Color(0.35, 0.55, 0.9).lerp(Color(0.9, 0.25, 0.15), i / 21.0)
		bar.add_child(seg)
	zone = ColorRect.new()
	zone.color = Color(1, 0.85, 0.3)
	bar.add_child(zone)
	needle = ColorRect.new()
	needle.size = Vector2(6, 58)
	needle.color = Color.WHITE
	body.add_child(needle)
	var cold := UI.small_label("raw", Color(0.7, 0.8, 1), 13)
	cold.position = Vector2(0, 62)
	body.add_child(cold)
	var hot := UI.small_label("burnt", Color(1, 0.6, 0.5), 13)
	hot.position = Vector2(BAR_W - 40, 62)
	body.add_child(hot)
	loaf = ICON.new("bread", Color.WHITE, 64.0)
	loaf.position = Vector2(BAR_W / 2 - 32, 82)
	body.add_child(loaf)
	content.add_child(UI.hint_row(["SPACE", "E"], "or click to stop the needle"))
	_new_bake_round()


func _new_bake_round() -> void:
	zone.size = Vector2(zone_w, 32)
	zone_x = randf_range(BAR_W * 0.35, BAR_W - zone_w - 20)
	zone.position = Vector2(zone_x, 4)
	needle_x = 0.0
	needle_dir = 1.0
	loaf.modulate = Color(1.15, 1.1, 1.0)
	_bake_status()


func _bake_status() -> void:
	status.text = "Watch the needle..."
	_set_pips([[3, bakes, Color(0.95, 0.65, 0.25), "Loaves"], [2, 2 - misses, Color(0.9, 0.35, 0.35), "Misses left"]])


func _run_baking(delta: float) -> void:
	if pause > 0.0:
		pause -= delta
		if pause <= 0.0:
			if bakes >= 3:
				_finish(true)
			elif misses > 2:
				_finish(false)
			else:
				_new_bake_round()
		return
	needle_x += needle_dir * needle_speed * delta
	if needle_x >= BAR_W - 6 or needle_x <= 0.0:
		needle_dir = -needle_dir
		needle_x = clamp(needle_x, 0.0, BAR_W - 6)
	needle.position = Vector2(needle_x, 9)


func _bake_press() -> void:
	if pause > 0.0:
		return
	var center := needle_x + 3
	if center >= zone_x and center <= zone_x + zone_w:
		bakes += 1
		loaf.modulate = Color(1, 1, 1)
		Audio.play("ding")
		UI.banner(root, "Perfect!", Color(1, 0.85, 0.3))
		status.text = "A golden loaf!"
		needle_speed += 90.0        # each loaf is a little harder
		zone_w = max(zone_w - 15.0, 50.0)
	else:
		misses += 1
		var burnt := center > zone_x + zone_w
		loaf.modulate = Color(0.25, 0.18, 0.15) if burnt else Color(1.4, 1.35, 1.2)
		Audio.play("sizzle" if burnt else "fail")
		UI.banner(root, "Burnt!" if burnt else "Still raw!", Color(1, 0.45, 0.35) if burnt else Color(0.7, 0.8, 1))
		status.text = "Try again!" if misses <= 2 else "Oh no..."
	_set_pips([[3, bakes, Color(0.95, 0.65, 0.25), "Loaves"], [2, max(2 - misses, 0), Color(0.9, 0.35, 0.35), "Misses left"]])
	pause = 1.0


# ================================================================ memory

func _setup_memory() -> void:
	_frame("Plant the Pattern", "Watch the flowers light up, then repeat the pattern.",
		Color(0.4, 0.65, 0.35), "flower", Color(1, 0.55, 0.7))
	pads = []
	round_index = 0
	mistakes = 0
	sequence = []
	body.custom_minimum_size = Vector2(460, 140)
	for i in 4:
		var pad := Button.new()
		pad.size = Vector2(100, 128)
		pad.position = Vector2(8 + i * 113, 6)
		pad.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed"]:
			pad.add_theme_stylebox_override(st, UI.pad_style(FLOWER_COLORS[i].darkened(0.55)))
		pad.pressed.connect(func():
			if not showing and grace <= 0.0:
				_memory_press(i))
		var icon := ICON.new("flower", FLOWER_COLORS[i], 56.0)
		icon.position = Vector2(22, 14)
		pad.add_child(icon)
		var key := UI.key_badge(str(i + 1))
		key.position = Vector2(38, 90)
		pad.add_child(key)
		body.add_child(pad)
		pads.append(pad)
	content.add_child(UI.hint_row(["1", "2", "3", "4"], "or click the flowers"))
	_next_memory_round()


func _memory_pips() -> void:
	_set_pips([[round_lengths.size(), round_index, Color(0.5, 0.85, 0.45), "Rounds"], [2, 2 - mistakes, Color(0.9, 0.35, 0.35), "Mistakes left"]])


func _next_memory_round() -> void:
	while sequence.size() < round_lengths[round_index]:
		sequence.append(randi() % 4)
	input_pos = 0
	_memory_pips()
	_play_sequence()


func _play_sequence() -> void:
	showing = true
	status.text = "Watch carefully..."
	await get_tree().create_timer(0.8).timeout
	for i in sequence:
		if not visible:
			return
		_light(i, true)
		await get_tree().create_timer(0.5).timeout
		_light(i, false)
		await get_tree().create_timer(0.2).timeout
	showing = false
	status.text = "Your turn!  %d / %d" % [0, sequence.size()]


func _light(i: int, on: bool) -> void:
	if i >= pads.size() or not is_instance_valid(pads[i]):
		return
	var style := UI.pad_style(FLOWER_COLORS[i] if on else FLOWER_COLORS[i].darkened(0.55))
	for st in ["normal", "hover", "pressed"]:
		pads[i].add_theme_stylebox_override(st, style)
	if on:
		Audio.play("note%d" % (i + 1), 0.0)
		var tw: Tween = pads[i].create_tween()
		pads[i].pivot_offset = pads[i].size / 2
		tw.tween_property(pads[i], "scale", Vector2(1.08, 1.08), 0.08)
		tw.tween_property(pads[i], "scale", Vector2.ONE, 0.12)


func _memory_press(i: int) -> void:
	_light(i, true)
	get_tree().create_timer(0.2).timeout.connect(func(): _light(i, false))
	if sequence[input_pos] == i:
		input_pos += 1
		status.text = "Your turn!  %d / %d" % [input_pos, sequence.size()]
		if input_pos >= sequence.size():
			round_index += 1
			_memory_pips()
			showing = true
			if round_index >= round_lengths.size():
				UI.banner(root, "Beautiful!", Color(1, 0.7, 0.85))
				status.text = "The garden is planted."
				Audio.play("quest")
				await get_tree().create_timer(1.3).timeout
				_finish(true)
			else:
				UI.banner(root, "Well done!", Color(0.6, 1, 0.6))
				await get_tree().create_timer(1.0).timeout
				_next_memory_round()
	else:
		mistakes += 1
		Audio.play("fail")
		_memory_pips()
		showing = true
		if mistakes > 2:
			UI.banner(root, "Oops!", Color(1, 0.45, 0.35))
			status.text = "The flowers are all mixed up!"
			await get_tree().create_timer(1.3).timeout
			_finish(false)
		else:
			input_pos = 0
			UI.banner(root, "Oops!", Color(1, 0.6, 0.4))
			status.text = "Watch again..."
			await get_tree().create_timer(1.0).timeout
			_play_sequence()


# ================================================================ harvest

## crop: "wheat", "carrot" or "pumpkin" -- bigger crops move faster
var harvest_crop := "wheat"


func _setup_harvest() -> void:
	var names := {"wheat": "Wheat", "carrot": "Carrot", "pumpkin": "Pumpkin", "tomato": "Tomato", "strawberry": "Strawberry", "corn": "Corn"}
	_frame("Pull!", "Stop the marker in the green band for a perfect harvest (bonus crop!).",
		Color(0.45, 0.6, 0.25), "carrot")
	pull_speed = {"wheat": 1.5, "carrot": 1.9, "tomato": 2.0, "pumpkin": 2.3, "strawberry": 2.4, "corn": 2.5}.get(harvest_crop, 1.6)
	pull_band_h = {"wheat": 40.0, "carrot": 34.0, "tomato": 32.0, "pumpkin": 28.0, "strawberry": 27.0, "corn": 26.0}.get(harvest_crop, 34.0)
	pull_band_y = randf_range(PULL_H * 0.55, PULL_H - pull_band_h - 8)
	pull_t = 0.0
	pull_time_left = 4.0
	pull_done = false
	body.custom_minimum_size = Vector2(300, PULL_H + 10)
	var track := Panel.new()
	var ts := StyleBoxFlat.new()
	ts.set_corner_radius_all(12)
	ts.bg_color = Color(0.1, 0.07, 0.05)
	track.add_theme_stylebox_override("panel", ts)
	track.size = Vector2(56, PULL_H)
	track.position = Vector2(60, 4)
	track.clip_contents = true
	body.add_child(track)
	# weak (bottom) -> good -> green perfect band
	for i in 12:
		var seg := ColorRect.new()
		seg.size = Vector2(48, PULL_H / 12.0 + 1)
		seg.position = Vector2(4, PULL_H - (i + 1) * PULL_H / 12.0)
		seg.color = Color(0.75, 0.3, 0.2).lerp(Color(0.95, 0.8, 0.3), i / 11.0)
		track.add_child(seg)
	var band := ColorRect.new()
	band.color = Color(0.35, 0.9, 0.4)
	band.size = Vector2(48, pull_band_h)
	band.position = Vector2(4, PULL_H - pull_band_y - pull_band_h)
	track.add_child(band)
	pull_marker = ColorRect.new()
	pull_marker.size = Vector2(72, 6)
	pull_marker.color = Color.WHITE
	body.add_child(pull_marker)
	crop_icon = ICON.new(harvest_crop, Color.WHITE, 90.0)
	crop_icon.position = Vector2(160, PULL_H / 2 - 45)
	body.add_child(crop_icon)
	var nm := UI.small_label(names.get(harvest_crop, "Crop"), UI.CREAM, 18)
	nm.position = Vector2(170, PULL_H / 2 + 50)
	body.add_child(nm)
	content.add_child(UI.hint_row(["SPACE", "E"], "or click to pull"))
	status.text = "Get ready..."


func _run_harvest(delta: float) -> void:
	if pull_done:
		return
	pull_t += delta * pull_speed
	var h := (1.0 - cos(pull_t * PI)) * 0.5 * (PULL_H - 6)   # smooth up and down
	pull_marker.position = Vector2(52, 4 + PULL_H - h - 6)
	pull_time_left -= delta
	status.text = "Pull!"
	if pull_time_left <= 0.0:
		_pull_result(0)


func _pull_press() -> void:
	if pull_done:
		return
	var h := (1.0 - cos(pull_t * PI)) * 0.5 * (PULL_H - 6) + 3
	if h >= pull_band_y and h <= pull_band_y + pull_band_h:
		_pull_result(2)
	elif h > PULL_H * 0.35:
		_pull_result(1)
	else:
		_pull_result(0)


func _pull_result(quality: int) -> void:
	pull_done = true
	match quality:
		2:
			UI.banner(root, "Perfect!", Color(0.5, 1, 0.5))
			Audio.play("ding")
			status.text = "A bonus crop!"
		1:
			UI.banner(root, "Good!", Color(1, 0.85, 0.4))
			Audio.play("harvest")
			status.text = "Nice pull."
		_:
			UI.banner(root, "Weak pull", Color(0.9, 0.7, 0.6))
			Audio.play("harvest")
			status.text = "Still got it out."
	var tw := crop_icon.create_tween()
	tw.tween_property(crop_icon, "position:y", crop_icon.position.y - 40, 0.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(crop_icon, "position:y", crop_icon.position.y, 0.25).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(0.8).timeout
	_finish(quality)


# ================================================================ crabs

func _setup_crabs() -> void:
	_frame("Crab Catch!", "Grab the crabs before they hide. Don't touch the jellyfish!",
		Color(0.25, 0.55, 0.75), "crab")
	holes = []
	hole_state = []
	hole_timer = []
	crabs_caught = 0
	crab_time_left = CRAB_TIME
	spawn_timer = 0.6
	body.custom_minimum_size = Vector2(360, 340)
	for i in 9:
		var b := Button.new()
		b.size = Vector2(108, 100)
		b.position = Vector2(6 + (i % 3) * 118, 6 + (i / 3) * 110)
		b.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, UI.pad_style(Color(0.78, 0.68, 0.48)))
		b.pressed.connect(func():
			if grace <= 0.0:
				_crab_press(i))
		var hole := Panel.new()
		var hs := StyleBoxFlat.new()
		hs.bg_color = Color(0.3, 0.22, 0.14)
		hs.set_corner_radius_all(30)
		hole.add_theme_stylebox_override("panel", hs)
		hole.size = Vector2(70, 26)
		hole.position = Vector2(19, 62)
		hole.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hole)
		var key := UI.key_badge(str(i + 1))
		key.position = Vector2(6, 4)
		b.add_child(key)
		body.add_child(b)
		holes.append(b)
		hole_state.append("")
		hole_timer.append(0.0)
	time_bar = ColorRect.new()
	time_bar.color = Color(0.4, 0.8, 1)
	time_bar.size = Vector2(360, 8)
	time_bar.position = Vector2(0, 334)
	body.add_child(time_bar)
	content.add_child(UI.hint_row(["1-9"], "or click the crabs"))
	status.text = "Crabs caught: 0"


func _show_in_hole(i: int, what: String) -> void:
	hole_state[i] = what
	var old: Node = holes[i].get_node_or_null("Critter")
	if old:
		old.queue_free()
	if what == "":
		return
	var icon: Control = ICON.new("crab" if what == "crab" else "jelly", Color(0.75, 0.45, 0.9), 64.0)
	icon.name = "Critter"
	icon.position = Vector2(22, 60)
	holes[i].add_child(icon)
	var tw := icon.create_tween()
	tw.tween_property(icon, "position:y", 16.0, 0.12).set_ease(Tween.EASE_OUT)


func _run_crabs(delta: float) -> void:
	crab_time_left -= delta
	time_bar.size.x = 360.0 * max(crab_time_left, 0.0) / CRAB_TIME
	time_bar.color = Color(0.4, 0.8, 1).lerp(Color(1, 0.4, 0.3), 1.0 - crab_time_left / CRAB_TIME)
	if crab_time_left <= 0.0:
		kind = "crabs_done"
		for i in 9:
			_show_in_hole(i, "")
		UI.banner(root, "%d crabs!" % crabs_caught, Color(1, 0.6, 0.45))
		status.text = "Time's up!"
		await get_tree().create_timer(1.3).timeout
		_finish(crabs_caught)
		return
	var progress := 1.0 - crab_time_left / CRAB_TIME     # gets faster over time
	for i in 9:
		if hole_state[i] != "":
			hole_timer[i] -= delta
			if hole_timer[i] <= 0.0:
				_show_in_hole(i, "")
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		spawn_timer = lerpf(0.75, 0.38, progress)
		var empty := []
		for i in 9:
			if hole_state[i] == "":
				empty.append(i)
		if not empty.is_empty():
			var i: int = empty.pick_random()
			_show_in_hole(i, "jelly" if randf() < 0.18 else "crab")
			hole_timer[i] = lerpf(1.1, 0.6, progress)


func _crab_press(i: int) -> void:
	if kind != "crabs":
		return
	match hole_state[i]:
		"crab":
			crabs_caught += 1
			Audio.play("coin", 0.2)
			_show_in_hole(i, "")
		"jelly":
			crabs_caught = max(crabs_caught - 1, 0)
			Audio.play("fail")
			UI.banner(root, "Ouch!", Color(0.85, 0.55, 1))
			_show_in_hole(i, "")
	status.text = "Crabs caught: %d" % crabs_caught
