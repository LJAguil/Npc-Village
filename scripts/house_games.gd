extends "res://scripts/minigames.gd"
## The minigames inside the houses (the outdoor/quest ones live in minigames.gd,
## which this extends -- same window, same look):
##   "bouquet" -- Ivy's flower shop: press the flowers in the order on the ticket
##               before the customer gets bored. Result: orders filled (0-3).
##   "stack"   -- Pip's block tower: drop sliding blocks on the tower; overhangs
##               get cut off. Result: blocks stacked (0-15).
##   "pairs"   -- Otto's curio cabinet: flip cards to find the 6 matching pairs
##               with a limited number of tries. Result: pairs found (0-6).
##   "sort"    -- Sal's catch: send each item to the right bin (pond fish,
##               junk, ocean fish) before it slips away. Result: sorted right.
##   "cooking" -- your stove: pick a recipe, then chop, mix and cook it.
##               Result: {"recipe": id, "stars": 0-3}, or {} if you walked away.
## (Bram's house uses the "baking" game from minigames.gd.)

# ---------------------------------------------------------------- bouquet
const ORDER_LENGTHS := [4, 5, 6]
const ORDER_TIME := 7.5
var order: Array = []
var order_pos := 0
var order_index := 0
var orders_done := 0
var order_time_left := 0.0
var order_busy := false
var ticket: HBoxContainer
var order_bar: ColorRect

# ---------------------------------------------------------------- stack
const STACK_W := 360.0
const STACK_H := 330.0
const BLOCK_H := 22.0
const STACK_MAX := 15
const BLOCK_COLORS := [Color(1, 0.45, 0.4), Color(1, 0.75, 0.3), Color(0.5, 0.85, 0.45), Color(0.4, 0.7, 1), Color(0.75, 0.5, 1)]
var stack_area: Control
var blocks: Array = []        # {"x", "w", "rect"}
var cur_rect: ColorRect
var cur_x := 0.0
var cur_w := 0.0
var cur_dir := 1.0
var cur_speed := 150.0
var stack_over := false

# ---------------------------------------------------------------- pairs
const PAIR_ICONS := [["coin", Color(1, 0.8, 0.3)], ["fish", Color(0.45, 0.7, 1)], ["flower", Color(1, 0.5, 0.7)],
	["crab", Color(1, 0.4, 0.3)], ["star", Color(1, 0.9, 0.4)], ["drop", Color(0.4, 0.8, 1)]]
const PAIR_TRIES := 11
var cards: Array = []
var card_kind: Array = []
var card_state: Array = []    # "down" / "up" / "done"
var first_pick := -1
var pairs_lock := false
var tries_left := 0
var pairs_found := 0

# ---------------------------------------------------------------- sort
const SORT_TOTAL := 15
const SORT_MISTAKES := 3
const POND_FISH := ["minnow", "perch", "bass", "catfish", "trout", "eel"]
const OCEAN_FISH := ["sardine", "mackerel", "pufferfish", "swordfish", "squid", "tuna"]
const JUNK := ["boot", "can"]
const FISH_TINT := {"minnow": Color(0.7, 0.75, 0.8), "perch": Color(0.6, 0.7, 0.3), "bass": Color(0.35, 0.6, 0.3),
	"catfish": Color(0.6, 0.5, 0.4), "trout": Color(0.75, 0.6, 0.55), "eel": Color(0.4, 0.5, 0.3),
	"sardine": Color(0.7, 0.8, 0.9), "mackerel": Color(0.35, 0.6, 0.75), "pufferfish": Color(0.95, 0.8, 0.45),
	"swordfish": Color(0.45, 0.5, 0.8), "squid": Color(0.95, 0.65, 0.7), "tuna": Color(0.35, 0.4, 0.6)}
var sort_index := 0
var sort_correct := 0
var sort_mistakes := 0
var sort_item := ""
var sort_bin := 0             # 0 pond, 1 junk, 2 ocean
var sort_time := 0.0
var sort_time_max := 3.0
var sort_wait := 0.0
var sort_icon: Control
var sort_label: Label
var sort_bar: ColorRect
var bins: Array = []

# ---------------------------------------------------------------- cooking
var cook_phase := ""          # choose / chop / mix / heat / done
var cook_recipe: Dictionary = {}
var cook_stars := 0
var cook_time := 0.0
var chop_fill := 0.0
var mix_seq: Array = []
var mix_pos := 0
var mix_mistakes := 0
var mix_badges: Array = []
var heat := 0.0
var heat_zone := 0.6
var heat_in := 0.0
var cook_bar: ColorRect
var cook_bar_bg: Control
var heat_needle: ColorRect
var heat_zone_rect: ColorRect
var stars_row: HBoxContainer
const MIX_KEYS := ["W", "A", "S", "D"]
const MIX_ACTIONS := ["move_forward", "move_left", "move_back", "move_right"]


func _setup_kind() -> void:
	match kind:
		"bouquet":
			_setup_bouquet()
		"stack":
			_setup_stack()
		"pairs":
			_setup_pairs()
		"sort":
			_setup_sort()
		"cooking":
			_setup_cooking()
		_:
			super._setup_kind()


func _run_kind(delta: float) -> void:
	match kind:
		"bouquet":
			_run_bouquet(delta)
		"stack":
			_run_stack(delta)
		"sort":
			_run_sort(delta)
		"cooking":
			_run_cooking(delta)
		"pairs":
			pass
		_:
			super._run_kind(delta)


func _input_kind(event: InputEvent) -> void:
	match kind:
		"bouquet":
			for i in 4:
				if event.is_action_pressed("choice_%d" % (i + 1)):
					get_viewport().set_input_as_handled()
					_bouquet_press(i)
		"stack":
			if event.is_action_pressed("reel"):
				get_viewport().set_input_as_handled()
				_stack_press()
		"sort":
			for b in 3:
				if event.is_action_pressed(["move_left", "move_back", "move_right"][b]):
					get_viewport().set_input_as_handled()
					_sort_press(b)
		"cooking":
			_cooking_input(event)
		"pairs":
			pass
		_:
			super._input_kind(event)


func _card(bg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(12)
	s.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", s)
	return p


func _bar(parent: Control, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var bg := Panel.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.1, 0.07, 0.05)
	bs.set_corner_radius_all(6)
	bg.add_theme_stylebox_override("panel", bs)
	bg.position = pos
	bg.size = size
	parent.add_child(bg)
	var fill := ColorRect.new()
	fill.color = color
	fill.position = Vector2(3, 3)
	fill.size = Vector2(size.x - 6, size.y - 6)
	bg.add_child(fill)
	return fill


# ================================================================ bouquet (Ivy)

func _setup_bouquet() -> void:
	_frame("Ivy's Flower Shop", "Press the flowers in the order on the ticket before the customer gets bored!",
		Color(0.4, 0.65, 0.35), "flower", Color(1, 0.55, 0.7))
	order_index = 0
	orders_done = 0
	pads = []
	body.custom_minimum_size = Vector2(460, 250)
	var tcard := _card(Color(0.95, 0.9, 0.78))
	tcard.position = Vector2(20, 0)
	tcard.custom_minimum_size = Vector2(420, 70)
	body.add_child(tcard)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 6)
	tcard.add_child(trow)
	var tl := UI.small_label("Order:", Color(0.3, 0.2, 0.1), 16)
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow.add_child(tl)
	ticket = HBoxContainer.new()
	ticket.add_theme_constant_override("separation", 4)
	trow.add_child(ticket)
	order_bar = _bar(body, Vector2(20, 80), Vector2(420, 14), Color(0.5, 0.85, 0.45))
	for i in 4:
		var pad := Button.new()
		pad.size = Vector2(100, 128)
		pad.position = Vector2(8 + i * 113, 108)
		pad.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed"]:
			pad.add_theme_stylebox_override(st, UI.pad_style(FLOWER_COLORS[i].darkened(0.45)))
		pad.pressed.connect(func():
			if grace <= 0.0:
				_bouquet_press(i))
		var icon := ICON.new("flower", FLOWER_COLORS[i], 56.0)
		icon.position = Vector2(22, 14)
		pad.add_child(icon)
		var key := UI.key_badge(str(i + 1))
		key.position = Vector2(38, 90)
		pad.add_child(key)
		body.add_child(pad)
		pads.append(pad)
	content.add_child(UI.hint_row(["1", "2", "3", "4"], "or click the flowers"))
	_new_order()


func _new_order() -> void:
	order = []
	for i in ORDER_LENGTHS[order_index]:
		order.append(randi() % 4)
	order_pos = 0
	order_time_left = ORDER_TIME
	order_busy = false
	for c in ticket.get_children():
		c.queue_free()
	for f in order:
		ticket.add_child(ICON.new("flower", FLOWER_COLORS[f], 46.0))
	status.text = "Customer %d of %d" % [order_index + 1, ORDER_LENGTHS.size()]
	_set_pips([[ORDER_LENGTHS.size(), orders_done, Color(1, 0.6, 0.75), "Bouquets"]])


func _run_bouquet(delta: float) -> void:
	if order_busy:
		return
	order_time_left -= delta
	order_bar.size.x = 414.0 * max(order_time_left, 0.0) / ORDER_TIME
	order_bar.color = Color(0.5, 0.85, 0.45).lerp(Color(1, 0.4, 0.3), 1.0 - order_time_left / ORDER_TIME)
	if order_time_left <= 0.0:
		_order_over(false, "Too slow!")


func _bouquet_press(i: int) -> void:
	if order_busy or kind != "bouquet":
		return
	Audio.play("note%d" % (i + 1), 0.0)
	var tw: Tween = pads[i].create_tween()
	pads[i].pivot_offset = pads[i].size / 2
	tw.tween_property(pads[i], "scale", Vector2(1.08, 1.08), 0.06)
	tw.tween_property(pads[i], "scale", Vector2.ONE, 0.1)
	if order[order_pos] == i:
		ticket.get_child(order_pos).modulate = Color(1, 1, 1, 0.25)
		order_pos += 1
		if order_pos >= order.size():
			orders_done += 1
			_order_over(true, "Lovely!")
	else:
		_order_over(false, "Wrong flower!")


func _order_over(ok: bool, word: String) -> void:
	order_busy = true
	UI.banner(root, word, Color(1, 0.7, 0.85) if ok else Color(1, 0.55, 0.4))
	Audio.play("ding" if ok else "fail")
	_set_pips([[ORDER_LENGTHS.size(), orders_done, Color(1, 0.6, 0.75), "Bouquets"]])
	await get_tree().create_timer(1.0).timeout
	if kind != "bouquet":
		return
	order_index += 1
	if order_index >= ORDER_LENGTHS.size():
		status.text = "%d bouquet%s made!" % [orders_done, "" if orders_done == 1 else "s"]
		await get_tree().create_timer(0.6).timeout
		_finish(orders_done)
	else:
		_new_order()


# ================================================================ stack (Pip)

func _setup_stack() -> void:
	_frame("Pip's Block Tower", "Drop each block onto the tower. Anything hanging over the edge falls off!",
		Color(0.85, 0.65, 0.2), "block", Color(0.4, 0.7, 1))
	body.custom_minimum_size = Vector2(STACK_W, STACK_H)
	stack_area = Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.55, 0.75, 0.95)
	ps.set_corner_radius_all(12)
	stack_area.add_theme_stylebox_override("panel", ps)
	stack_area.size = Vector2(STACK_W, STACK_H)
	stack_area.clip_contents = true
	body.add_child(stack_area)
	blocks = []
	stack_over = false
	cur_speed = 150.0
	# the base (a rug on the floor)
	var base := ColorRect.new()
	base.color = Color(0.6, 0.35, 0.3)
	stack_area.add_child(base)
	blocks.append({"x": STACK_W / 2 - 80, "w": 160.0, "rect": base})
	_layout_stack()
	content.add_child(UI.hint_row(["SPACE", "E"], "or click to drop"))
	_new_block()


func _level_y(level: int) -> float:
	var scroll: float = max(0, blocks.size() - 10) * BLOCK_H
	return STACK_H - (level + 1) * BLOCK_H + scroll


func _layout_stack() -> void:
	for i in blocks.size():
		var b: Dictionary = blocks[i]
		var r: ColorRect = b["rect"]
		r.position = Vector2(b["x"], _level_y(i))
		r.size = Vector2(b["w"], BLOCK_H - 2)
	status.text = "Height: %d / %d" % [blocks.size() - 1, STACK_MAX]


func _new_block() -> void:
	var top: Dictionary = blocks.back()
	cur_w = top["w"]
	cur_dir = 1.0 if blocks.size() % 2 == 0 else -1.0
	cur_x = 0.0 if cur_dir > 0 else STACK_W - cur_w
	cur_rect = ColorRect.new()
	cur_rect.color = BLOCK_COLORS[blocks.size() % BLOCK_COLORS.size()]
	stack_area.add_child(cur_rect)
	cur_rect.size = Vector2(cur_w, BLOCK_H - 2)
	cur_rect.position = Vector2(cur_x, _level_y(blocks.size()))


func _run_stack(delta: float) -> void:
	if stack_over or cur_rect == null:
		return
	cur_x += cur_dir * cur_speed * delta
	if cur_x <= 0.0 or cur_x >= STACK_W - cur_w:
		cur_dir = -cur_dir
		cur_x = clamp(cur_x, 0.0, STACK_W - cur_w)
	cur_rect.position.x = cur_x


func _stack_press() -> void:
	if stack_over or cur_rect == null:
		return
	var top: Dictionary = blocks.back()
	var left: float = max(cur_x, top["x"])
	var right: float = min(cur_x + cur_w, top["x"] + top["w"])
	if right - left <= 2.0:
		# missed the tower completely
		stack_over = true
		var r := cur_rect
		var tw := r.create_tween()
		tw.tween_property(r, "position:y", STACK_H + 40, 0.5).set_ease(Tween.EASE_IN)
		Audio.play("fail")
		UI.banner(root, "Timber!", Color(1, 0.55, 0.4))
		_end_stack()
		return
	if abs(cur_x - float(top["x"])) < 5.0:
		left = top["x"]
		right = left + float(top["w"])
		Audio.play("ding")
		UI.banner(root, "Perfect!", Color(1, 0.9, 0.4))
	else:
		Audio.play("land", 0.1)
		# the overhanging bit tumbles off
		var off_x: float = cur_x if cur_x < left else right
		var off_w: float = (left - cur_x) if cur_x < left else (cur_x + cur_w - right)
		var piece := ColorRect.new()
		piece.color = cur_rect.color.darkened(0.2)
		piece.position = Vector2(off_x, cur_rect.position.y)
		piece.size = Vector2(off_w, BLOCK_H - 2)
		stack_area.add_child(piece)
		var tw := piece.create_tween().set_parallel(true)
		tw.tween_property(piece, "position:y", STACK_H + 40, 0.6).set_ease(Tween.EASE_IN)
		tw.tween_property(piece, "modulate:a", 0.0, 0.6)
		tw.chain().tween_callback(piece.queue_free)
	blocks.append({"x": left, "w": right - left, "rect": cur_rect})
	cur_rect = null
	_layout_stack()
	if blocks.size() - 1 >= STACK_MAX:
		stack_over = true
		UI.banner(root, "Sky high!", Color(0.6, 1, 0.6))
		Audio.play("quest")
		_end_stack()
		return
	cur_speed += 14.0
	_new_block()


func _end_stack() -> void:
	var n := blocks.size() - 1
	status.text = "Your tower: %d blocks!" % n
	await get_tree().create_timer(1.4).timeout
	if kind == "stack":
		_finish(n)


# ================================================================ pairs (Otto)

func _setup_pairs() -> void:
	_frame("Otto's Curio Cabinet", "Find all 6 matching pairs. Otto only has patience for %d tries!" % PAIR_TRIES,
		Color(0.35, 0.45, 0.7), "coin")
	body.custom_minimum_size = Vector2(4 * 96, 3 * 106)
	cards = []
	card_kind = []
	card_state = []
	first_pick = -1
	pairs_lock = false
	tries_left = PAIR_TRIES
	pairs_found = 0
	var deck := []
	for k in PAIR_ICONS.size():
		deck.append(k)
		deck.append(k)
	deck.shuffle()
	for i in deck.size():
		var b := Button.new()
		b.size = Vector2(88, 98)
		b.position = Vector2((i % 4) * 96 + 4, (i / 4) * 106 + 4)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func():
			if grace <= 0.0:
				_pair_press(i))
		body.add_child(b)
		cards.append(b)
		card_kind.append(deck[i])
		card_state.append("down")
		_show_card(i)
	content.add_child(UI.hint_row(["click"], "two cards to flip them"))
	_pairs_status()


func _show_card(i: int) -> void:
	var b: Button = cards[i]
	for c in b.get_children():
		c.queue_free()
	var st: String = card_state[i]
	var col := Color(0.3, 0.35, 0.6) if st == "down" else (Color(0.9, 0.85, 0.72) if st == "up" else Color(0.55, 0.8, 0.5))
	for s in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, UI.pad_style(col))
	if st == "down":
		var q := UI.small_label("?", Color(0.85, 0.8, 1.0), 40)
		q.position = Vector2(34, 22)
		b.add_child(q)
	else:
		var info: Array = PAIR_ICONS[card_kind[i]]
		var icon := ICON.new(info[0], info[1], 60.0)
		icon.position = Vector2(14, 19)
		b.add_child(icon)


func _pairs_status() -> void:
	status.text = "Tries left: %d" % tries_left
	_set_pips([[PAIR_ICONS.size(), pairs_found, Color(0.55, 0.85, 0.5), "Pairs"]])


func _pair_press(i: int) -> void:
	if kind != "pairs" or pairs_lock or card_state[i] != "down":
		return
	card_state[i] = "up"
	_show_card(i)
	Audio.play("click")
	if first_pick < 0:
		first_pick = i
		return
	var a := first_pick
	first_pick = -1
	tries_left -= 1
	if card_kind[a] == card_kind[i]:
		card_state[a] = "done"
		card_state[i] = "done"
		_show_card(a)
		_show_card(i)
		pairs_found += 1
		Audio.play("ding")
		_pairs_status()
		if pairs_found >= PAIR_ICONS.size():
			UI.banner(root, "Splendid!", Color(0.6, 1, 0.6))
			Audio.play("quest")
			pairs_lock = true
			await get_tree().create_timer(1.3).timeout
			_finish(pairs_found)
			return
	else:
		pairs_lock = true
		_pairs_status()
		await get_tree().create_timer(0.8).timeout
		if kind != "pairs":
			return
		card_state[a] = "down"
		card_state[i] = "down"
		_show_card(a)
		_show_card(i)
		pairs_lock = false
	if tries_left <= 0 and pairs_found < PAIR_ICONS.size():
		pairs_lock = true
		UI.banner(root, "Hmph. Out of tries.", Color(1, 0.7, 0.5))
		await get_tree().create_timer(1.3).timeout
		_finish(pairs_found)


# ================================================================ sort (Sal)

func _setup_sort() -> void:
	_frame("Sal's Catch", "Sort the catch! Pond fish left, junk down, ocean fish right. Quick, before it flops away!",
		Color(0.25, 0.5, 0.7), "fish", Color(0.7, 0.85, 1))
	sort_index = 0
	sort_correct = 0
	sort_mistakes = 0
	sort_time_max = 3.2
	sort_wait = 0.0
	body.custom_minimum_size = Vector2(480, 300)
	sort_icon = ICON.new("fish", Color.WHITE, 110.0)
	sort_icon.position = Vector2(185, 10)
	body.add_child(sort_icon)
	sort_label = UI.small_label("", UI.CREAM, 22)
	sort_label.position = Vector2(0, 124)
	sort_label.size = Vector2(480, 30)
	sort_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(sort_label)
	sort_bar = _bar(body, Vector2(140, 158), Vector2(200, 12), Color(0.5, 0.85, 1))
	bins = []
	var names := ["Pond fish", "Junk", "Ocean fish"]
	var keys := ["A", "S", "D"]
	var colors := [Color(0.35, 0.6, 0.3), Color(0.45, 0.4, 0.35), Color(0.25, 0.45, 0.75)]
	var lists := ["minnow, perch, bass,\ncatfish, trout, eel", "boots, cans", "sardine, mackerel, puffer,\nswordfish, squid, tuna"]
	for b in 3:
		var btn := Button.new()
		btn.size = Vector2(150, 110)
		btn.position = Vector2(4 + b * 162, 186)
		btn.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed"]:
			btn.add_theme_stylebox_override(st, UI.pad_style(colors[b]))
		btn.pressed.connect(func():
			if grace <= 0.0:
				_sort_press(b))
		var kb := UI.key_badge(keys[b])
		kb.position = Vector2(8, 6)
		btn.add_child(kb)
		var nl := UI.small_label(names[b], UI.CREAM, 17)
		nl.position = Vector2(40, 6)
		btn.add_child(nl)
		var ll := UI.small_label(lists[b], Color(0.92, 0.9, 0.85), 12)
		ll.position = Vector2(8, 42)
		btn.add_child(ll)
		body.add_child(btn)
		bins.append(btn)
	content.add_child(UI.hint_row(["A", "S", "D"], "(or the arrow keys, or click a bin)"))
	_next_sort_item()


func _next_sort_item() -> void:
	var r := randf()
	if r < 0.2:
		sort_item = JUNK.pick_random()
		sort_bin = 1
	elif r < 0.6:
		sort_item = POND_FISH.pick_random()
		sort_bin = 0
	else:
		sort_item = OCEAN_FISH.pick_random()
		sort_bin = 2
	if is_instance_valid(sort_icon):
		sort_icon.queue_free()
	var icon_kind := sort_item if sort_bin == 1 else "fish"
	sort_icon = ICON.new(icon_kind, FISH_TINT.get(sort_item, Color.WHITE), 110.0)
	sort_icon.position = Vector2(185, 10)
	body.add_child(sort_icon)
	sort_label.text = Game.item_name(sort_item) if Game.ITEMS.has(sort_item) else ("Old Boot" if sort_item == "boot" else "Tin Can")
	sort_time = sort_time_max
	status.text = "%d / %d sorted" % [sort_index, SORT_TOTAL]
	_set_pips([[SORT_MISTAKES, SORT_MISTAKES - sort_mistakes, Color(0.9, 0.35, 0.35), "Mistakes left"]])


func _run_sort(delta: float) -> void:
	if kind != "sort":
		return
	if sort_wait > 0.0:
		sort_wait -= delta
		if sort_wait <= 0.0:
			sort_wait = 0.0
			if sort_index >= SORT_TOTAL or sort_mistakes >= SORT_MISTAKES:
				UI.banner(root, "%d sorted!" % sort_correct, Color(0.6, 0.85, 1))
				kind = "sort_done"
				await get_tree().create_timer(1.2).timeout
				_finish(sort_correct)
			else:
				_next_sort_item()
		return
	sort_time -= delta
	sort_bar.size.x = 194.0 * max(sort_time, 0.0) / sort_time_max
	sort_icon.rotation = sin(sort_time * 18.0) * 0.12     # flop flop
	if sort_time <= 0.0:
		_sort_result(false, "It got away!")


func _sort_press(b: int) -> void:
	if kind != "sort" or sort_wait != 0.0:
		return
	var tw: Tween = bins[b].create_tween()
	bins[b].pivot_offset = bins[b].size / 2
	tw.tween_property(bins[b], "scale", Vector2(1.06, 1.06), 0.06)
	tw.tween_property(bins[b], "scale", Vector2.ONE, 0.1)
	_sort_result(b == sort_bin, "Wrong bin!")


func _sort_result(ok: bool, word: String) -> void:
	sort_index += 1
	if ok:
		sort_correct += 1
		Audio.play("splash", 0.15, -4.0)
		var target: Vector2 = bins[sort_bin].position + Vector2(20, 10)
		var tw := sort_icon.create_tween().set_parallel(true)
		tw.tween_property(sort_icon, "position", target, 0.2)
		tw.tween_property(sort_icon, "scale", Vector2(0.4, 0.4), 0.2)
	else:
		sort_mistakes += 1
		Audio.play("fail")
		UI.banner(root, word, Color(1, 0.55, 0.4))
	sort_time_max = max(1.5, sort_time_max - 0.11)
	sort_wait = 0.35 if ok else 0.9
	_set_pips([[SORT_MISTAKES, max(SORT_MISTAKES - sort_mistakes, 0), Color(0.9, 0.35, 0.35), "Mistakes left"]])
	status.text = "%d / %d sorted" % [sort_index, SORT_TOTAL]


# ================================================================ cooking (your house)

## Recipes you can see at the stove: the basics plus secret ones you've learned.
static func known_recipes() -> Array:
	return Game.RECIPES.filter(func(r): return Game.recipe_known(r))


static func recipe_icon(id: String) -> Array:
	match id:
		"grilled_fish":
			return ["fish", Color(0.85, 0.55, 0.3)]
		"fish_stew":
			return ["pot", Color(0.85, 0.6, 0.35)]
		"tomato_soup":
			return ["pot", Color(0.9, 0.25, 0.15)]
		"pumpkin_pie":
			return ["pie", Color(1, 0.6, 0.2)]
		"corn_chowder":
			return ["pot", Color(1, 0.88, 0.5)]
		"strawberry_cake":
			return ["cake", Color(1, 0.45, 0.55)]
		"mushroom_soup":
			return ["pot", Color(0.7, 0.55, 0.4)]
		"berry_tart":
			return ["pie", Color(0.55, 0.3, 0.8)]
		"herb_fish":
			return ["fish", Color(0.45, 0.75, 0.4)]
		"harvest_loaf":
			return ["bread", Color.WHITE]
		"garden_salad":
			return ["herb", Color.WHITE]
		"berry_pancakes":
			return ["cake", Color(0.55, 0.3, 0.8)]
		"truffle_stew":
			return ["pot", Color(0.45, 0.32, 0.22)]
		"seafood_platter":
			return ["fish", Color(1, 0.6, 0.5)]
	return ["star", Color.WHITE]


static func needs_text(recipe: Dictionary) -> String:
	var parts := []
	for id in recipe["needs"]:
		var n: int = recipe["needs"][id]
		var nm: String = "fish (any)" if id == "any_fish" else Game.item_name(id, n > 1).to_lower()
		var have: int = Game.count_kind("fish") if id == "any_fish" else Game.count(id)
		parts.append("%d %s (have %d)" % [n, nm, have])
	return " + ".join(parts)


func _setup_cooking() -> void:
	_frame("Home Cooking", "Cook your crops and fish into dishes that sell for much more.",
		Color(0.75, 0.35, 0.25), "pot", Color(0.9, 0.6, 0.35))
	cook_phase = "choose"
	cook_recipe = {}
	cook_stars = 0
	body.custom_minimum_size = Vector2(0, 0)
	var list := GridContainer.new()
	list.columns = 2
	list.add_theme_constant_override("h_separation", 8)
	list.add_theme_constant_override("v_separation", 6)
	content.add_child(list)
	content.move_child(list, 1)
	var known := known_recipes()
	for i in known.size():
		var r: Dictionary = known[i]
		var ok := Game.can_cook(r)
		var b := Button.new()
		b.custom_minimum_size = Vector2(380, 50)
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = not ok
		var base := Color(0.45, 0.3, 0.35) if r.has("secret") else Color(0.4, 0.28, 0.18)
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, UI.pad_style(base if ok else Color(0.22, 0.17, 0.13)))
		b.pressed.connect(func():
			if grace <= 0.0:
				_choose_recipe(i))
		var ic: Array = recipe_icon(r["id"])
		var icon := ICON.new(ic[0], ic[1], 34.0)
		icon.position = Vector2(40, 8)
		b.add_child(icon)
		if i < 9:
			var kb := UI.key_badge(str(i + 1))
			kb.position = Vector2(8, 13)
			b.add_child(kb)
		var nm := UI.small_label("%s  -  %d" % [Game.item_name(r["id"]), Game.ITEMS[r["id"]]["sell"]], UI.CREAM if ok else UI.MUTED, 15)
		nm.position = Vector2(82, 4)
		b.add_child(nm)
		var nd := UI.small_label(needs_text(r), Color(0.75, 0.9, 0.65) if ok else Color(0.7, 0.6, 0.5), 11)
		nd.position = Vector2(82, 27)
		b.add_child(nd)
		list.add_child(b)
	var close := Button.new()
	close.text = "Not now  (Esc)"
	close.custom_minimum_size = Vector2(180, 36)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func(): _finish({}))
	content.add_child(close)
	status.text = "Pick a recipe (number keys or click)." if known.any(func(r): return Game.can_cook(r)) else "You don't have the ingredients for anything yet. Grow crops and catch fish!"


func _cooking_input(event: InputEvent) -> void:
	match cook_phase:
		"choose":
			if event.is_action_pressed("pause"):
				get_viewport().set_input_as_handled()
				_finish({})
				return
			for i in min(9, known_recipes().size()):
				if event.is_action_pressed("choice_%d" % (i + 1)):
					get_viewport().set_input_as_handled()
					_choose_recipe(i)
		"chop":
			if event.is_action_pressed("reel"):
				get_viewport().set_input_as_handled()
				chop_fill += 8.0
				Audio.play("till", 0.2, -8.0)
				sort_icon.rotation = randf_range(-0.3, 0.3)
				if chop_fill >= 100.0:
					_cook_step_done(true, "Chopped!")
		"mix":
			for d in 4:
				if event.is_action_pressed(MIX_ACTIONS[d]):
					get_viewport().set_input_as_handled()
					_mix_press(d)


func _choose_recipe(i: int) -> void:
	if cook_phase != "choose":
		return
	var r: Dictionary = known_recipes()[i]
	if not Game.can_cook(r):
		Audio.play("fail")
		return
	Game.use_ingredients(r)
	cook_recipe = r
	Audio.play("click")
	# rebuild the window for the cooking steps
	for c in root.get_children():
		c.queue_free()
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	root.add_child(content)
	var ic: Array = recipe_icon(r["id"])
	_frame("Cooking: " + Game.item_name(r["id"]), "Chop, mix and cook. Each step done well earns a star.",
		Color(0.75, 0.35, 0.25), ic[0], ic[1])
	body.custom_minimum_size = Vector2(460, 170)
	stars_row = HBoxContainer.new()
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(stars_row)
	content.move_child(stars_row, 2)
	_draw_stars()
	_start_chop()
	await get_tree().process_frame
	root.reset_size()
	root.position = (root.get_viewport_rect().size - root.size) / 2


func _draw_stars() -> void:
	for c in stars_row.get_children():
		c.queue_free()
	for i in 3:
		var s := ICON.new("star", Color.WHITE, 30.0)
		s.modulate = Color(1, 1, 1) if i < cook_stars else Color(0.3, 0.25, 0.2)
		stars_row.add_child(s)


func _clear_body() -> void:
	for c in body.get_children():
		c.queue_free()
	for c in content.get_children():
		if c is HBoxContainer and c.has_meta("hint"):
			c.queue_free()


func _hint(keys: Array, text: String) -> void:
	var h := UI.hint_row(keys, text)
	h.set_meta("hint", true)
	content.add_child(h)


func _start_chop() -> void:
	_clear_body()
	cook_phase = "chop"
	cook_time = 4.0
	chop_fill = 0.0
	var first: String = cook_recipe["needs"].keys()[0]
	var ing: String = {"any_fish": "fish", "tomato": "tomato", "corn": "corn", "strawberry": "strawberry", "pumpkin": "pumpkin", "mushroom": "mushroom", "berries": "berries", "herb": "herb", "truffle": "truffle", "wheat": "wheat"}.get(first, "carrot")
	sort_icon = ICON.new(ing, Color(0.8, 0.6, 0.45), 80.0)
	sort_icon.position = Vector2(190, 4)
	body.add_child(sort_icon)
	cook_bar = _bar(body, Vector2(60, 100), Vector2(340, 22), Color(0.95, 0.75, 0.3))
	cook_bar.size.x = 0
	_hint(["SPACE", "E"], "tap fast to chop!")
	status.text = "Step 1: Chop!"


func _start_mix() -> void:
	_clear_body()
	cook_phase = "mix"
	cook_time = 5.0
	mix_seq = []
	mix_pos = 0
	mix_mistakes = 0
	mix_badges = []
	for i in 6:
		mix_seq.append(randi() % 4)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.position = Vector2(40, 30)
	body.add_child(row)
	for d in mix_seq:
		var p := _card(Color(0.95, 0.9, 0.8))
		p.custom_minimum_size = Vector2(58, 58)
		var l := UI.small_label(MIX_KEYS[d], Color(0.25, 0.15, 0.1), 30)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(l)
		row.add_child(p)
		mix_badges.append(p)
	cook_bar = _bar(body, Vector2(60, 120), Vector2(340, 14), Color(0.5, 0.85, 1))
	_hint(["W", "A", "S", "D"], "(or arrows) in order to stir")
	status.text = "Step 2: Stir in order!"


func _mix_press(d: int) -> void:
	if mix_pos >= mix_seq.size():
		return
	var p: PanelContainer = mix_badges[mix_pos]
	if d == mix_seq[mix_pos]:
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.55, 0.85, 0.5)
		st.set_corner_radius_all(12)
		st.set_content_margin_all(8)
		p.add_theme_stylebox_override("panel", st)
		Audio.play("note%d" % (d + 1), 0.0, -4.0)
		mix_pos += 1
		if mix_pos >= mix_seq.size():
			_cook_step_done(mix_mistakes <= 1, "Well stirred!" if mix_mistakes <= 1 else "A bit lumpy...")
	else:
		mix_mistakes += 1
		Audio.play("fail", 0.0, -6.0)
		var tw := p.create_tween()
		tw.tween_property(p, "modulate", Color(1, 0.4, 0.4), 0.08)
		tw.tween_property(p, "modulate", Color.WHITE, 0.2)


func _start_heat() -> void:
	_clear_body()
	cook_phase = "heat"
	cook_time = 7.0
	heat = 0.2
	heat_in = 0.0
	heat_zone = 0.6
	var track := Panel.new()
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.1, 0.07, 0.05)
	ts.set_corner_radius_all(8)
	track.add_theme_stylebox_override("panel", ts)
	track.position = Vector2(30, 30)
	track.size = Vector2(400, 36)
	track.clip_contents = true
	body.add_child(track)
	for i in 20:
		var seg := ColorRect.new()
		seg.size = Vector2(21, 30)
		seg.position = Vector2(3 + i * 19.7, 3)
		seg.color = Color(0.35, 0.55, 0.9).lerp(Color(0.95, 0.25, 0.15), i / 19.0)
		track.add_child(seg)
	heat_zone_rect = ColorRect.new()
	heat_zone_rect.color = Color(0.4, 0.95, 0.45, 0.85)
	heat_zone_rect.size = Vector2(80, 30)
	track.add_child(heat_zone_rect)
	heat_needle = ColorRect.new()
	heat_needle.color = Color.WHITE
	heat_needle.size = Vector2(6, 46)
	body.add_child(heat_needle)
	var lbl := UI.small_label("cold", Color(0.7, 0.8, 1), 13)
	lbl.position = Vector2(30, 72)
	body.add_child(lbl)
	var lbl2 := UI.small_label("too hot", Color(1, 0.6, 0.5), 13)
	lbl2.position = Vector2(380, 72)
	body.add_child(lbl2)
	cook_bar_bg = Control.new()
	body.add_child(cook_bar_bg)
	cook_bar = _bar(body, Vector2(60, 110), Vector2(340, 18), Color(1, 0.65, 0.3))
	cook_bar.size.x = 0
	var cl := UI.small_label("cooked", UI.MUTED, 13)
	cl.position = Vector2(60, 132)
	body.add_child(cl)
	_hint(["hold SPACE"], "for more heat, let go to cool -- keep it in the green")
	status.text = "Step 3: Keep the heat just right!"


func _run_cooking(delta: float) -> void:
	match cook_phase:
		"chop":
			cook_time -= delta
			cook_bar.size.x = 334.0 * clampf(chop_fill / 100.0, 0.0, 1.0)
			if cook_time <= 0.0:
				_cook_step_done(false, "Too slow...")
		"mix":
			cook_time -= delta
			cook_bar.size.x = 334.0 * max(cook_time, 0.0) / 5.0
			if cook_time <= 0.0:
				_cook_step_done(false, "Out of time...")
		"heat":
			cook_time -= delta
			if Input.is_action_pressed("reel"):
				heat = min(heat + 0.55 * delta, 1.0)
			else:
				heat = max(heat - 0.4 * delta, 0.0)
			heat_zone = 0.6 + sin((7.0 - cook_time) * 1.1) * 0.15
			var zx := heat_zone * 400.0 - 40.0
			heat_zone_rect.position = Vector2(zx, 3)
			heat_needle.position = Vector2(30 + heat * 400.0 - 3, 25)
			if abs(heat - heat_zone) <= 0.1:
				heat_in += delta
			cook_bar.size.x = 334.0 * clampf(heat_in / 3.0, 0.0, 1.0)
			if heat_in >= 3.0:
				_cook_step_done(true, "Perfectly cooked!")
			elif cook_time <= 0.0:
				_cook_step_done(false, "Hmm, uneven...")


func _cook_step_done(ok: bool, word: String) -> void:
	var step := cook_phase
	cook_phase = "wait"
	if ok:
		cook_stars += 1
		Audio.play("ding")
	else:
		Audio.play("sizzle")
	_draw_stars()
	UI.banner(root, word, Color(1, 0.85, 0.4) if ok else Color(1, 0.6, 0.45))
	await get_tree().create_timer(1.0).timeout
	if kind != "cooking":
		return
	match step:
		"chop":
			_start_mix()
		"mix":
			_start_heat()
		_:
			cook_phase = "done"
			_clear_body()
			var ic: Array = recipe_icon(cook_recipe["id"])
			var big := ICON.new(ic[0], ic[1] if cook_stars > 0 else Color(0.2, 0.15, 0.1), 110.0)
			big.position = Vector2(175, 20)
			body.add_child(big)
			var n := 2 if cook_stars == 3 else (1 if cook_stars > 0 else 0)
			if n == 0:
				status.text = "Oh no, it's burnt!"
			elif n == 2:
				status.text = "Three stars! You made 2 %s!" % Game.item_name(cook_recipe["id"], true).to_lower()
			else:
				status.text = "You made %s!" % Game.item_name(cook_recipe["id"]).to_lower()
			await get_tree().create_timer(1.6).timeout
			if kind == "cooking":
				_finish({"recipe": cook_recipe["id"], "stars": cook_stars})
