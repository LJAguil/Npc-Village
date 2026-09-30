extends CanvasLayer
## The market stall, with three tabs:
##   Buy  -- seeds and upgrades (rods, lure, sprinklers)
##   Hats -- hats for you to buy and wear
##   Sell -- fish, crops and critters
## Uses the mouse; Esc or the Close button leaves.

signal closed
signal hat_changed

const UI := preload("res://scripts/ui_style.gd")
const ICON := preload("res://scripts/ui_icon.gd")
const HOUSE_GAMES := preload("res://scripts/house_games.gd")
const PANELS := preload("res://scripts/panels.gd")

const HAT_COLORS := {"chef_hat": Color(0.97, 0.97, 0.97), "flower": Color(1, 0.45, 0.7), "propeller_cap": Color(1, 0.35, 0.3), "top_hat": Color(0.15, 0.15, 0.18), "sailor_hat": Color(0.9, 0.92, 1.0), "party_hat": Color(0.3, 0.6, 1.0), "straw_hat": Color(0.93, 0.8, 0.45), "flower_crown": Color(1, 0.5, 0.7), "pirate_hat": Color(0.2, 0.2, 0.24), "crown": Color(1, 0.8, 0.2)}
const HAT_DESC := {"chef_hat": "A gift from Bram.", "flower": "A gift from Ivy.", "propeller_cap": "A gift from Pip. It spins!", "top_hat": "A gift from Otto.", "sailor_hat": "A gift from Sal.", "party_hat": "Every day is a party.", "straw_hat": "Keeps the sun off while you farm.", "flower_crown": "Ivy says it suits you.", "pirate_hat": "Arr! Sal will be impressed.", "crown": "Solid gold. For true village royalty."}

var panel: PanelContainer
var coins_label: Label
var list: VBoxContainer
var message: Label
var tab := "buy"
var tab_buttons := {}


func _ready() -> void:
	layer = 6
	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -400
	panel.offset_right = 400
	panel.offset_top = -290
	panel.offset_bottom = 290
	panel.add_theme_stylebox_override("panel", UI.panel_style())
	add_child(panel)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var head := UI.header("Village Market", "Seeds, upgrades and hats. We buy fish, crops and critters!", Color(0.8, 0.3, 0.25), "coin")
	coins_label = UI.small_label("", UI.GOLD, 24)
	head.add_child(coins_label)
	v.add_child(head)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	for t in [["buy", "Buy"], ["hats", "Hats"], ["sell", "Sell"]]:
		var b := Button.new()
		b.text = t[1]
		b.custom_minimum_size = Vector2(120, 38)
		b.add_theme_font_size_override("font_size", 18)
		b.pressed.connect(func():
			Audio.play("click")
			tab = t[0]
			refresh())
		tabs.add_child(b)
		tab_buttons[t[0]] = b

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	message = UI.small_label("", Color(1, 0.9, 0.6), 16)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(message)
	var close := Button.new()
	close.text = "Close  (Esc)"
	close.custom_minimum_size = Vector2(200, 40)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(close_shop)
	v.add_child(close)
	visible = false


func open_shop() -> void:
	visible = true
	tab = "buy"
	message.text = "Welcome! Seeds grow in the farm plot by your house."
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh()
	UI.pop_in(panel)


func close_shop() -> void:
	if not visible:
		return
	Audio.play("click")
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close_shop()


func refresh() -> void:
	coins_label.text = "%d coins" % Game.coins
	for key in tab_buttons:
		tab_buttons[key].modulate = Color(1, 1, 1) if key == tab else Color(0.65, 0.6, 0.55)
	for c in list.get_children():
		c.queue_free()
	match tab:
		"buy":
			for entry in Game.SHOP:
				var id: String = entry["id"]
				var is_upgrade: bool = entry.get("upgrade", false)
				if is_upgrade:
					var owned: bool = Game.upgrades.get(id, false)
					var needs: String = entry.get("needs", "")
					var locked: bool = needs != "" and not Game.upgrades.get(needs, false)
					var btn := "Owned" if owned else ("Needs Better Rod" if locked else "%d c" % entry["price"])
					var up_icon: String = {"rod": "fish", "lure": "fish", "master_rod": "fish", "sprinklers": "drop", "guitar": "guitar", "flute": "flute"}.get(id, "star")
					_row(up_icon, entry["name"], entry["desc"], btn, not owned and not locked and Game.coins >= entry["price"], _buy.bind(entry))
				else:
					var label := Game.item_name(id)
					if Game.count(id) > 0:
						label += "  (have %d)" % Game.count(id)
					var icon: String = (Game.CROPS[id]["crop"] as String) if Game.CROPS.has(id) else ("bone" if id == "pet_treat" else "star")
					_row(icon, label, entry["desc"], "%d c" % entry["price"], Game.coins >= entry["price"], _buy.bind(entry), Color.WHITE)
		"hats":
			for h in Game.HATS:
				var id: String = h["id"]
				if h.get("gift", false) and not Game.hats_owned.has(id):
					continue   # villagers' gifts only show up once you have them
				if Game.hats_owned.has(id):
					var wearing := Game.player_hat == id
					var hc: Color = HAT_COLORS.get(id, Color.WHITE)
					_row("hat", h["name"], "Wearing it!" if wearing else "In your wardrobe.", "Take off" if wearing else "Wear", true, _wear.bind(id), hc)
				else:
					_row("hat", h["name"], HAT_DESC.get(id, "A fine hat for a fine villager."), "%d c" % h["price"], Game.coins >= h["price"], _buy_hat.bind(h), HAT_COLORS.get(id, Color.WHITE))
		"sell":
			var any := false
			for id in Game.ITEMS:
				var info: Dictionary = Game.ITEMS[id]
				if info["sell"] > 0 and Game.count(id) > 0:
					any = true
					var n := Game.count(id)
					var ic: Array = PANELS.item_icon(id)
					var icon: String = ic[0]
					var tint: Color = ic[1]
					_row(icon, "%s x%d" % [info["name"], n], "%d c each" % info["sell"], "Sell all (%d c)" % (info["sell"] * n), true, _sell.bind(id), tint)
			if not any:
				list.add_child(UI.small_label("Nothing to sell yet. Catch fish, harvest crops,\\ncatch crabs, bake, cook, or catch fireflies at night!", UI.MUTED, 16))


func _buy(entry: Dictionary) -> void:
	if Game.coins < entry["price"]:
		return
	Game.add_coins(-entry["price"])
	if entry.get("upgrade", false):
		Game.upgrades[entry["id"]] = true
		message.text = "Bought the %s!" % entry["name"]
	else:
		Game.add_item(entry["id"])
		if Game.count(Game.selected_seed) == 0:
			Game.selected_seed = entry["id"]
		message.text = "Bought %s." % Game.item_name(entry["id"])
	Audio.play("coin")
	refresh()


func _buy_hat(h: Dictionary) -> void:
	if Game.coins < h["price"]:
		return
	Game.add_coins(-h["price"])
	Game.hats_owned.append(h["id"])
	Game.player_hat = h["id"]
	message.text = "Looking sharp in your new %s!" % h["name"]
	Audio.play("coin")
	hat_changed.emit()
	refresh()


func _wear(id: String) -> void:
	Game.player_hat = "" if Game.player_hat == id else id
	Audio.play("click")
	hat_changed.emit()
	refresh()


func _sell(id: String) -> void:
	var n := Game.count(id)
	var total: int = Game.ITEMS[id]["sell"] * n
	Game.remove_item(id, n)
	Game.add_coins(total)
	message.text = "Sold %d %s for %d coins." % [n, Game.item_name(id, n != 1), total]
	Audio.play("coin")
	refresh()


func _row(icon: String, title: String, desc: String, btn_text: String, enabled: bool, action: Callable, icon_color := Color(1, 0.65, 0.3)) -> void:
	var card := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(1, 1, 1, 0.05)
	cs.set_corner_radius_all(10)
	cs.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", cs)
	list.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(ICON.new(icon, icon_color, 40.0))
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(texts)
	texts.add_child(UI.small_label(title, UI.CREAM, 18))
	texts.add_child(UI.small_label(desc, UI.MUTED, 13))
	var b := Button.new()
	b.text = btn_text
	b.custom_minimum_size = Vector2(150, 38)
	b.disabled = not enabled
	b.pressed.connect(action)
	row.add_child(b)
