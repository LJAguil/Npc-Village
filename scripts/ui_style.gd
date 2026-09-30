extends RefCounted
## Shared look for minigame screens: warm wooden panels with a gold border and
## drop shadow, a round icon badge + title header, key-hint badges, progress
## pips, a pop-in animation and big result banners ("Perfect!", "Burnt!").
## Use it with:  const UI := preload("res://scripts/ui_style.gd")

const ICON := preload("res://scripts/ui_icon.gd")
const GOLD := Color(1.0, 0.84, 0.42)
const CREAM := Color(0.96, 0.9, 0.78)
const MUTED := Color(0.82, 0.74, 0.62)
const PANEL_BG := Color(0.17, 0.11, 0.07, 0.97)
const BORDER := Color(0.86, 0.62, 0.3)


static func panel_style(accent := BORDER) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PANEL_BG
	s.set_corner_radius_all(18)
	s.set_content_margin_all(22)
	s.border_color = accent
	s.set_border_width_all(5)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 14
	s.shadow_offset = Vector2(0, 6)
	return s


## Title row: a colored circle with a drawn icon, a big title and a subtitle.
static func header(title: String, subtitle: String, accent: Color, icon_kind: String, icon_color := Color.WHITE) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var badge := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = accent
	bs.set_corner_radius_all(32)
	bs.border_color = accent.lightened(0.4)
	bs.set_border_width_all(3)
	bs.set_content_margin_all(6)
	badge.add_theme_stylebox_override("panel", bs)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.add_child(ICON.new(icon_kind, icon_color, 48.0))
	row.add_child(badge)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 2)
	row.add_child(texts)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", GOLD)
	t.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.04))
	t.add_theme_constant_override("outline_size", 8)
	texts.add_child(t)
	var st := Label.new()
	st.text = subtitle
	st.autowrap_mode = TextServer.AUTOWRAP_WORD
	st.custom_minimum_size.x = 380
	st.add_theme_font_size_override("font_size", 15)
	st.add_theme_color_override("font_color", MUTED)
	texts.add_child(st)
	return row


## A little keyboard-key badge, e.g. key_badge("SPACE").
static func key_badge(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.95, 0.9, 0.8)
	s.set_corner_radius_all(6)
	s.border_color = Color(0.55, 0.45, 0.35)
	s.border_width_bottom = 4
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_width_top = 1
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", s)
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(0.2, 0.15, 0.1))
	p.add_child(l)
	return p


## A row like: [SPACE] or [E] or click  -> to stop the needle
static func hint_row(keys: Array, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	for i in keys.size():
		if i > 0:
			row.add_child(small_label("or", MUTED))
		row.add_child(key_badge(keys[i]))
	row.add_child(small_label(text, CREAM))
	return row


static func small_label(text: String, color: Color, size := 15) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## A row of round pips (e.g. loaves baked, misses left).
static func pips(count: int, filled: int, on_color: Color, label := "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	if label != "":
		row.add_child(small_label(label, MUTED, 14))
	for i in count:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(18, 18)
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(9)
		s.bg_color = on_color if i < filled else Color(0.3, 0.25, 0.2)
		s.border_color = on_color.darkened(0.3)
		s.set_border_width_all(2)
		dot.add_theme_stylebox_override("panel", s)
		row.add_child(dot)
	return row


## Scale-and-fade the panel in.
static func pop_in(c: Control) -> void:
	c.pivot_offset = c.size / 2
	c.scale = Vector2(0.85, 0.85)
	c.modulate.a = 0.0
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.15)


## Big word that pops up over the panel and fades ("Perfect!", "Burnt!").
static func banner(parent: Control, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 46)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.15, 0.08, 0.03))
	l.add_theme_constant_override("outline_size", 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	l.pivot_offset = parent.size / 2
	l.scale = Vector2(0.5, 0.5)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2(1.1, 1.1), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.1)
	tw.tween_interval(0.45)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


## Rounded button style for choices (flower pads, crab holes...).
static func pad_style(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(14)
	s.border_color = color.lightened(0.35)
	s.border_width_bottom = 5
	s.border_width_left = 2
	s.border_width_right = 2
	s.border_width_top = 2
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 4
	return s
