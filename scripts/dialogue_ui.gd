extends CanvasLayer
## The in-game HUD: day/clock/coins, quest log, inventory bar, pop-up messages,
## tag timer, interaction prompt, dialogue box, screen fade and the win screen.

signal win_continue

var status_label: Label
var quest_label: Label
var inv_label: RichTextLabel
var recent_row: HBoxContainer     # the last few things you picked up
var recent: Array = []            # item ids, newest first
var last_counts := {}
var prompt: Label
var panel: PanelContainer
var name_label: Label
var text_label: Label
var hint_label: Label
var toast: Label
var toast_timer := 0.0
var timer_label: Label
var fade: ColorRect
var detector: PanelContainer
var detector_fill: ColorRect
var detector_label: Label
var win_panel: PanelContainer
var win_label: Label
var root: Control
var hearts_row: HBoxContainer
const ICON := preload("res://scripts/ui_icon.gd")


func _ready() -> void:
	layer = 2
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Day / time / coins (top left)
	var spanel := _panel(Color(0.12, 0.09, 0.06, 0.8))
	spanel.position = Vector2(12, 12)
	root.add_child(spanel)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 20)
	spanel.add_child(status_label)

	# Quest log (top right)
	var qpanel := _panel(Color(0.12, 0.09, 0.06, 0.7))
	qpanel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	qpanel.offset_left = -370
	qpanel.offset_right = -12
	qpanel.offset_top = 12
	root.add_child(qpanel)
	quest_label = Label.new()
	quest_label.add_theme_font_size_override("font_size", 16)
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	quest_label.custom_minimum_size.x = 330
	qpanel.add_child(quest_label)

	# Inventory (bottom left)
	var ipanel := _panel(Color(0.12, 0.09, 0.06, 0.7))
	ipanel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ipanel.offset_left = 12
	ipanel.offset_bottom = -12
	ipanel.offset_top = -120
	ipanel.offset_right = 300
	ipanel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(ipanel)
	var iv := VBoxContainer.new()
	iv.add_theme_constant_override("separation", 6)
	iv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ipanel.add_child(iv)
	inv_label = RichTextLabel.new()
	inv_label.bbcode_enabled = true
	inv_label.fit_content = true
	inv_label.scroll_active = false
	inv_label.custom_minimum_size = Vector2(270, 0)
	inv_label.add_theme_font_size_override("normal_font_size", 15)
	inv_label.add_theme_font_size_override("bold_font_size", 15)
	inv_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	iv.add_child(inv_label)
	recent_row = HBoxContainer.new()
	recent_row.add_theme_constant_override("separation", 4)
	recent_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	iv.add_child(recent_row)

	# Pop-up message (top center)
	toast = _outlined_label(24)
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast.offset_left = -260
	toast.offset_right = 260
	toast.offset_top = 105
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD
	toast.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	root.add_child(toast)

	timer_label = _outlined_label(34)
	timer_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	timer_label.offset_left = -300
	timer_label.offset_right = 300
	timer_label.offset_top = 190
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.visible = false
	root.add_child(timer_label)

	prompt = _outlined_label(22)
	prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt.offset_top = -205
	prompt.offset_bottom = -170
	prompt.offset_left = -350
	prompt.offset_right = 350
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt)

	# Dialogue box
	panel = _panel(Color(0.12, 0.09, 0.06, 0.88))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -400
	panel.offset_right = 400
	panel.offset_top = -160
	panel.offset_bottom = -20
	root.add_child(panel)
	var vbox := VBoxContainer.new()
	panel.add_child(vbox)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	vbox.add_child(name_row)
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(1, 0.8, 0.35))
	name_row.add_child(name_label)
	hearts_row = HBoxContainer.new()
	hearts_row.add_theme_constant_override("separation", 2)
	hearts_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_row.add_child(hearts_row)
	for i in 10:
		hearts_row.add_child(ICON.new("heart", Color(1, 0.4, 0.5), 18.0))
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_label.add_theme_font_size_override("font_size", 20)
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(text_label)
	hint_label = Label.new()
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.add_theme_color_override("font_color", Color(0.75, 0.7, 0.6))
	vbox.add_child(hint_label)
	panel.visible = false

	# Otto's metal detector (bottom right)
	detector = _panel(Color(0.12, 0.09, 0.06, 0.8))
	detector.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	detector.offset_left = -300
	detector.offset_right = -12
	detector.offset_top = -86
	detector.offset_bottom = -12
	root.add_child(detector)
	var dv := VBoxContainer.new()
	detector.add_child(dv)
	detector_label = Label.new()
	detector_label.add_theme_font_size_override("font_size", 16)
	dv.add_child(detector_label)
	var dbg := ColorRect.new()
	dbg.custom_minimum_size = Vector2(260, 16)
	dbg.color = Color(0.2, 0.2, 0.2)
	dv.add_child(dbg)
	detector_fill = ColorRect.new()
	detector_fill.size = Vector2(0, 16)
	dbg.add_child(detector_fill)
	detector.visible = false

	# Full-screen fade (for sleeping)
	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.color = Color(0, 0, 0, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)

	# Win screen
	win_panel = _panel(Color(0.12, 0.09, 0.06, 0.92))
	win_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	win_panel.offset_left = -320
	win_panel.offset_right = 320
	win_panel.offset_top = -170
	win_panel.offset_bottom = 170
	root.add_child(win_panel)
	var wv := VBoxContainer.new()
	wv.alignment = BoxContainer.ALIGNMENT_CENTER
	wv.add_theme_constant_override("separation", 18)
	win_panel.add_child(wv)
	win_label = Label.new()
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_label.add_theme_font_size_override("font_size", 24)
	win_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	wv.add_child(win_label)
	var keep := Button.new()
	keep.text = "Keep playing"
	keep.custom_minimum_size = Vector2(220, 44)
	keep.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	keep.pressed.connect(func():
		Audio.play("click")
		win_panel.visible = false
		win_continue.emit())
	wv.add_child(keep)
	win_panel.visible = false

	Game.coins_changed.connect(update_status)
	Game.inventory_changed.connect(update_inventory)
	update_status()
	update_inventory()


func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer -= delta
		toast.modulate.a = clamp(toast_timer, 0.0, 1.0)
	update_status()


func set_visible_hud(v: bool) -> void:
	root.visible = v


func update_status() -> void:
	status_label.text = "Day %d   %s   %s\nCoins: %d" % [Game.day, Game.clock_text(), "Night" if Game.is_night() else "Day", Game.coins]


## Bottom-left: your seeds (Q to pick which one you plant), how full your bag
## is, and icons of the last few things you picked up. Press I for the bag.
func update_inventory() -> void:
	var seeds := []
	for sd in Game.CROPS:
		if Game.count(sd) > 0:
			var nm := "%s x%d" % [Game.item_name(sd).replace(" Seeds", ""), Game.count(sd)]
			seeds.append("[b][color=#ffd966]> %s[/color][/b]" % nm if sd == Game.selected_seed else nm)
	var kinds := 0
	var total := 0
	for id in Game.inventory:
		var n := Game.count(id)
		if n <= 0:
			continue
		if not last_counts.has(id) or n > int(last_counts[id]):
			if not last_counts.is_empty() or recent.is_empty():
				recent.erase(id)
				recent.push_front(id)
		kinds += 1
		total += n
	last_counts = {}
	for id in Game.inventory:
		last_counts[id] = Game.count(id)
	recent = recent.filter(func(id): return Game.count(id) > 0).slice(0, 6)
	var lines := []
	lines.append("[color=#c8e6a0]Seeds (Q):[/color] " + (", ".join(seeds) if not seeds.is_empty() else "none"))
	lines.append("[color=#c8e6a0]Bag (I):[/color] %d thing%s, %d kind%s" % [total, "" if total == 1 else "s", kinds, "" if kinds == 1 else "s"])
	inv_label.text = "\n".join(lines)
	for c in recent_row.get_children():
		c.queue_free()
	var panels_script = load("res://scripts/panels.gd")
	for id in recent:
		var slot := PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = Color(1, 1, 1, 0.07)
		st.set_corner_radius_all(6)
		st.set_content_margin_all(2)
		slot.add_theme_stylebox_override("panel", st)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ic: Array = panels_script.item_icon(id)
		var icon: Control = ICON.new(ic[0], ic[1], 32.0)
		slot.add_child(icon)
		var cnt := Label.new()
		cnt.text = str(Game.count(id))
		cnt.add_theme_font_size_override("font_size", 12)
		cnt.add_theme_color_override("font_outline_color", Color.BLACK)
		cnt.add_theme_constant_override("outline_size", 4)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cnt.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		slot.add_child(cnt)
		recent_row.add_child(slot)
	recent_row.visible = not recent.is_empty()


func show_detector(strength: float) -> void:
	detector.visible = true
	detector_fill.size.x = 260.0 * strength
	detector_fill.color = Color(0.3, 0.6, 1.0).lerp(Color(1.0, 0.3, 0.2), strength)
	var word := "Cold" if strength < 0.3 else ("Warm" if strength < 0.6 else ("Hot!" if strength < 0.9 else "RIGHT HERE!"))
	detector_label.text = "Metal detector:  " + word


func hide_detector() -> void:
	detector.visible = false


func show_prompt(text: String) -> void:
	prompt.text = text


func show_dialogue(speaker: String, text: String, is_last: bool, hearts := -1) -> void:
	panel.visible = true
	name_label.text = speaker
	hearts_row.visible = hearts >= 0
	for i in hearts_row.get_child_count():
		hearts_row.get_child(i).modulate = Color(1, 1, 1) if i < hearts else Color(0.3, 0.25, 0.25, 0.7)
	text_label.text = text
	hint_label.text = "[E] close" if is_last else "[E] next"


func hide_dialogue() -> void:
	panel.visible = false


func set_quest_log(text: String) -> void:
	quest_label.text = text


func show_toast(text: String, seconds := 3.5) -> void:
	toast.text = text
	toast_timer = seconds
	toast.modulate.a = 1.0


func show_timer(text: String) -> void:
	timer_label.visible = true
	timer_label.text = text


## Big word in the middle of the screen (race countdown: 3, 2, 1, GO!).
var big_label: Label

func show_big(text: String, color := Color(1, 0.85, 0.3)) -> void:
	if big_label == null:
		big_label = _outlined_label(96)
		big_label.add_theme_constant_override("outline_size", 16)
		big_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		big_label.offset_left = -300
		big_label.offset_right = 300
		big_label.offset_top = -170
		big_label.offset_bottom = -50
		big_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		root.add_child(big_label)
	big_label.text = text
	big_label.add_theme_color_override("font_color", color)
	big_label.modulate.a = 1.0
	big_label.pivot_offset = Vector2(300, 60)
	big_label.scale = Vector2(1.5, 1.5)
	var tw := big_label.create_tween()
	tw.tween_property(big_label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_property(big_label, "modulate:a", 0.0, 0.2)


func hide_timer() -> void:
	timer_label.visible = false


func show_win(text: String) -> void:
	hide_dialogue()
	prompt.text = ""
	win_label.text = text
	win_panel.visible = true


## Fades to black, calls middle(), then fades back in.
func fade_through_black(middle: Callable) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.8)
	tw.tween_callback(middle)
	tw.tween_interval(0.8)
	tw.tween_property(fade, "color:a", 0.0, 0.8)


func _outlined_label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel(color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	style.border_color = Color(0.55, 0.4, 0.22, 0.9)
	style.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p
