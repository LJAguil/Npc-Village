extends CanvasLayer
## The village projects board (beside the market). After the Harvest Festival you
## can pour your coins into big projects that change the village: flower
## gardens, a fountain, a bandstand (villagers dance there in the evening)
## and a golden statue of yourself. Donate a bit at a time or all at once.

signal closed
signal funded(id: String)

const UI := preload("res://scripts/ui_style.gd")
const ICON := preload("res://scripts/ui_icon.gd")
const ICONS := {"gardens": "flower", "fountain": "drop", "bandstand": "note", "statue": "star"}
const ICON_COLORS := {"gardens": Color(1, 0.5, 0.7), "fountain": Color(0.45, 0.75, 1), "bandstand": Color(1, 0.6, 0.3), "statue": Color(1, 0.84, 0.3)}

var panel: PanelContainer
var coins_label: Label
var list: VBoxContainer
var message: Label


func _ready() -> void:
	layer = 6
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -400
	panel.offset_right = 400
	panel.offset_top = -310
	panel.offset_bottom = 310
	panel.add_theme_stylebox_override("panel", UI.panel_style(Color(0.45, 0.7, 0.4)))
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := UI.header("Village Projects", "Chip in to make the village even better. Every coin counts!", Color(0.3, 0.55, 0.3), "flag")
	coins_label = UI.small_label("", UI.GOLD, 24)
	head.add_child(coins_label)
	v.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)

	message = UI.small_label("", Color(1, 0.9, 0.6), 16)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(message)
	var close := Button.new()
	close.text = "Close  (Esc)"
	close.custom_minimum_size = Vector2(200, 40)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(close_board)
	v.add_child(close)
	visible = false


func open_board() -> void:
	visible = true
	message.text = "Funded projects appear in the village right away."
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh()
	UI.pop_in(panel)


func close_board() -> void:
	if not visible:
		return
	Audio.play("click")
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close_board()


func refresh() -> void:
	coins_label.text = "%d coins" % Game.coins
	for c in list.get_children():
		c.queue_free()
	for p in Game.PROJECTS:
		var id: String = p["id"]
		var price: int = p["price"]
		var have := Game.project_donated(id)
		var done := Game.is_project_funded(id)

		var card := PanelContainer.new()
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(0.4, 0.8, 0.4, 0.12) if done else Color(1, 1, 1, 0.05)
		cs.set_corner_radius_all(10)
		cs.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", cs)
		list.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		row.add_child(ICON.new(ICONS.get(id, "star"), ICON_COLORS.get(id, Color.WHITE), 44.0))

		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(texts)
		texts.add_child(UI.small_label(p["name"] + ("   - Built!" if done else ""), UI.CREAM, 18))
		texts.add_child(UI.small_label(p["desc"], UI.MUTED, 13))
		# progress bar
		var bar_bg := Panel.new()
		bar_bg.custom_minimum_size = Vector2(0, 14)
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(0.1, 0.07, 0.04)
		bs.set_corner_radius_all(7)
		bar_bg.add_theme_stylebox_override("panel", bs)
		texts.add_child(bar_bg)
		var fill := Panel.new()
		var fs := StyleBoxFlat.new()
		fs.bg_color = Color(0.45, 0.85, 0.4) if done else UI.GOLD
		fs.set_corner_radius_all(7)
		fill.add_theme_stylebox_override("panel", fs)
		fill.anchor_bottom = 1.0
		fill.anchor_right = clampf(float(have) / price, 0.0, 1.0)
		bar_bg.add_child(fill)
		texts.add_child(UI.small_label("%d / %d coins" % [have, price], UI.MUTED, 12))

		var btns := VBoxContainer.new()
		btns.add_theme_constant_override("separation", 4)
		btns.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(btns)
		if done:
			btns.add_child(UI.small_label("Complete!", Color(0.6, 1, 0.55), 18))
		else:
			var left := price - have
			for amount in [100, 500]:
				if amount < left:
					btns.add_child(_btn("Give %d" % amount, Game.coins > 0, _give.bind(id, amount)))
			btns.add_child(_btn("Finish it (%d c)" % left, Game.coins >= left, _give.bind(id, left)))


func _btn(text: String, enabled: bool, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 28)
	b.disabled = not enabled
	b.pressed.connect(action)
	return b


func _give(id: String, amount: int) -> void:
	var spent := Game.donate(id, amount)
	if spent <= 0:
		return
	Audio.play("coin")
	if Game.is_project_funded(id):
		Audio.play("win")
		message.text = "The %s is built! Go take a look." % Game.project_info(id)["name"]
		funded.emit(id)
	else:
		message.text = "Thank you for the %d coins!" % spent
	refresh()
