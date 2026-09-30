extends CanvasLayer
## Title screen (New Game / Continue / Quit) and the Esc pause menu
## (Resume / Save / volume sliders / Quit to title).

signal start_new
signal start_continue
signal save_requested

var title_root: Control
var pause_root: Control
var continue_btn: Button
var save_label: Label
var paused := false
var in_title := true
var can_pause := true   # the world turns this off during sleep transitions


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_title()
	_build_pause()
	show_title()


func show_title() -> void:
	in_title = true
	title_root.visible = true
	pause_root.visible = false
	continue_btn.disabled = not Game.has_save()
	continue_btn.text = "Continue" if Game.has_save() else "Continue (no save yet)"
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if in_title or not can_pause:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		if paused:
			_resume()
		else:
			_pause()


func _pause() -> void:
	paused = true
	get_tree().paused = true
	pause_root.visible = true
	save_label.text = ""
	Audio.play("click")


func _resume() -> void:
	paused = false
	get_tree().paused = false
	pause_root.visible = false
	Audio.play("click")


# ------------------------------------------------------------------ title

func _build_title() -> void:
	title_root = Control.new()
	title_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(title_root)

	# Soft dark gradient on the left so the text is readable over the village
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.25)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_root.add_child(shade)

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	v.offset_left = 90
	v.offset_right = 600
	v.offset_top = -220
	v.offset_bottom = 220
	v.add_theme_constant_override("separation", 14)
	title_root.add_child(v)

	var title := Label.new()
	title.text = "NPC Village"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(1, 0.88, 0.5))
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.05))
	title.add_theme_constant_override("outline_size", 16)
	v.add_child(title)
	var sub := Label.new()
	sub.text = "Farm, fish, and help your neighbors\nget ready for the Harvest Festival."
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_outline_color", Color.BLACK)
	sub.add_theme_constant_override("outline_size", 8)
	v.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	v.add_child(spacer)

	var new_btn := _button("New Game", func():
		Audio.play("click")
		title_root.visible = false
		in_title = false
		start_new.emit())
	v.add_child(new_btn)
	continue_btn = _button("Continue", func():
		Audio.play("click")
		title_root.visible = false
		in_title = false
		start_continue.emit())
	v.add_child(continue_btn)
	v.add_child(_button("Quit", func(): get_tree().quit()))

	var credits := Label.new()
	credits.text = "Character models by Kenney (kenney.nl, CC0)"
	credits.add_theme_font_size_override("font_size", 14)
	credits.add_theme_color_override("font_outline_color", Color.BLACK)
	credits.add_theme_constant_override("outline_size", 6)
	credits.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	credits.offset_left = -420
	credits.offset_top = -36
	credits.offset_right = -16
	credits.offset_bottom = -12
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_root.add_child(credits)


# ------------------------------------------------------------------ pause

func _build_pause() -> void:
	pause_root = Control.new()
	pause_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(pause_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.5)
	pause_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -318
	panel.offset_bottom = 318
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.14, 0.09, 0.97)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(22)
	style.border_color = Color(0.75, 0.55, 0.3)
	style.set_border_width_all(4)
	panel.add_theme_stylebox_override("panel", style)
	pause_root.add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.45))
	v.add_child(title)

	v.add_child(_button("Resume", _resume))
	v.add_child(_button("Save Game", func():
		Audio.play("click")
		save_requested.emit()))
	save_label = Label.new()
	save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_label.add_theme_color_override("font_color", Color(0.7, 1, 0.6))
	v.add_child(save_label)

	v.add_child(_slider("Music volume", Audio.music_volume, Audio.set_music_volume))
	v.add_child(_slider("Sound effects volume", Audio.sfx_volume, Audio.set_sfx_volume))
	var opts := GridContainer.new()
	opts.columns = 2
	opts.add_theme_constant_override("h_separation", 16)
	opts.add_theme_constant_override("v_separation", 10)
	v.add_child(opts)
	opts.add_child(_fishing_option())
	opts.add_child(_farming_option())
	opts.add_child(_gathering_option())
	opts.add_child(_instrument_music_option())

	var help := Label.new()
	help.text = "WASD move   Space jump   E interact\nQ change seed   Right-drag camera"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 14)
	help.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
	v.add_child(help)

	v.add_child(_button("Quit to Title", func():
		Audio.play("click")
		get_tree().paused = false
		Game.start_mode = "title"
		get_tree().reload_current_scene()))
	pause_root.visible = false


func show_saved(ok: bool) -> void:
	save_label.text = "Game saved!" if ok else "Could not save the game."


## Fishing style: the timing-bar minigame, or a simpler "react to the bite" version.
func _fishing_option() -> Control:
	return _choice("Fishing style", ["Minigame (timing bar)", "Simple (just react to the bite)"],
		1 if Game.fishing_mode == "simple" else 0,
		func(i): Game.set_fishing_mode("simple" if i == 1 else "minigame"))


## Farming style: the "Pull!" harvest minigame, or harvest instantly.
func _farming_option() -> Control:
	return _choice("Farming style", ["Minigame (Pull! when harvesting)", "Simple (harvest instantly)"],
		1 if Game.farming_mode == "simple" else 0,
		func(i): Game.set_farming_mode("simple" if i == 1 else "minigame"))


## Gathering style: Timber!/Strike! minigames when chopping and mining, or just swing.
func _gathering_option() -> Control:
	return _choice("Chopping & mining style", ["Minigame (Timber! / Strike!)", "Simple (just swing)"],
		1 if Game.gathering_mode == "simple" else 0,
		func(i): Game.set_gathering_mode("simple" if i == 1 else "minigame"))


## What the background music does while you play an instrument.
func _instrument_music_option() -> Control:
	return _choice("Music while playing instruments", ["Off (fade out)", "Quiet"],
		1 if Audio.instrument_music == "quiet" else 0,
		func(i): Audio.set_instrument_music("quiet" if i == 1 else "off"))


func _choice(label_text: String, items: Array, selected: int, on_pick: Callable) -> Control:
	var box := VBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	box.add_child(l)
	var opt := OptionButton.new()
	opt.custom_minimum_size.x = 290
	for it in items:
		opt.add_item(it)
	opt.selected = selected
	opt.item_selected.connect(func(i):
		Audio.play("click")
		on_pick.call(i))
	box.add_child(opt)
	return box


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 48)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(action)
	return b


func _slider(label_text: String, value: float, on_change: Callable) -> Control:
	var box := VBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	box.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size.x = 300
	s.value_changed.connect(on_change)
	box.add_child(s)
	return box
