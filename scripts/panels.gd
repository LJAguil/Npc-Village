extends CanvasLayer
## Small screens that aren't minigames:
##   * the treasure map (M) -- a live top-down map of the village with an X
##     where today's treasure is buried and an arrow for you; you can walk
##     around with it open
##   * adopting and naming the puppy, and the pet menu (pet / feed / fetch)
##   * the gift picker (G next to a villager)
##   * the journal (J): villagers (hearts, birthdays, tastes, bios), your pet,
##     your collections and the calendar

const UI := preload("res://scripts/ui_style.gd")
const ICON := preload("res://scripts/ui_icon.gd")
const VILLAGERS := preload("res://scripts/villager_data.gd")
const HOUSE_GAMES := preload("res://scripts/house_games.gd")

var world: Node3D
var modal: PanelContainer          # the open blocking panel (pet / gift / journal / adopt)
var map_panel: PanelContainer
var map_view: Control
var journal_tab := "villagers"


func _ready() -> void:
	layer = 6
	_build_map()


# ================================================================ helpers

func _open_modal(title: String, subtitle: String, accent: Color, icon: String, icon_color := Color.WHITE, width := 640.0) -> VBoxContainer:
	close_modal(false)
	modal = PanelContainer.new()
	modal.add_theme_stylebox_override("panel", UI.panel_style(accent.lightened(0.2)))
	modal.custom_minimum_size = Vector2(width, 0)
	add_child(modal)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	modal.add_child(v)
	v.add_child(UI.header(title, subtitle, accent, icon, icon_color))
	world.player.busy = true
	Game.time_running = false
	world.menus.can_pause = false
	world.hud.show_prompt("")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_center.call_deferred()
	return v


func _center() -> void:
	if modal and is_instance_valid(modal):
		modal.reset_size()
		modal.position = (modal.get_viewport_rect().size - modal.size) / 2
		UI.pop_in(modal)


func close_modal(restore := true) -> void:
	if modal and is_instance_valid(modal):
		modal.queue_free()
		modal = null
		if restore:
			world.player.busy = false
			Game.time_running = true
			world.menus.can_pause = true
			Audio.play("click")


func is_open() -> bool:
	return modal != null and is_instance_valid(modal)


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and (event.is_action_pressed("pause") or (event.is_action_pressed("journal") and journal_open) or (event.is_action_pressed("bag") and bag_open)):
		get_viewport().set_input_as_handled()
		close_modal()


func _button(text: String, enabled: bool, action: Callable, w := 150.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 38)
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b


func _close_row(v: VBoxContainer) -> void:
	var c := _button("Close  (Esc)", true, func(): close_modal(), 200)
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(c)


func _card() -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, 0.05)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", s)
	return p


func _hearts(n: int, size := 18.0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	for i in 10:
		var h := ICON.new("heart", Color(1, 0.4, 0.5), size)
		h.modulate = Color.WHITE if i < n else Color(0.3, 0.25, 0.25, 0.7)
		row.add_child(h)
	return row


func _bar(value: float, color: Color, width := 260.0) -> Control:
	var bg := Panel.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.1, 0.07, 0.05)
	bs.set_corner_radius_all(7)
	bg.add_theme_stylebox_override("panel", bs)
	bg.custom_minimum_size = Vector2(width, 16)
	var fill := Panel.new()
	var fs := StyleBoxFlat.new()
	fs.bg_color = color
	fs.set_corner_radius_all(7)
	fill.add_theme_stylebox_override("panel", fs)
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(value, 0.0, 1.0)
	bg.add_child(fill)
	return bg


static func item_icon(id: String) -> Array:
	if not Game.ITEMS.has(id):
		return ["star", Color.WHITE]
	var kind: String = Game.ITEMS[id]["kind"]
	match kind:
		"seed":
			return [Game.CROPS[id]["crop"] if Game.CROPS.has(id) else "wheat", Color.WHITE]
		"fish":
			var tint: Dictionary = HOUSE_GAMES.FISH_TINT
			return ["fish", {"golden_carp": Color(1, 0.78, 0.25), "moonfish": Color(0.8, 0.85, 1.0)}.get(id, tint.get(id, Color(0.55, 0.75, 1)))]
		"crop":
			return [id, Color.WHITE]
		"dish":
			return HOUSE_GAMES.recipe_icon(id)
		"critter":
			return [id if id == "crab" else "firefly", Color.WHITE]
		"goods":
			return ["bread" if id == "bread" else "flower", Color(1, 0.55, 0.75)]
		"treasure":
			return {"gem": ["gem", Color(0.4, 0.8, 1)], "old_coin": ["coin", Color.WHITE], "relic": ["relic", Color.WHITE]}.get(id, ["star", Color.WHITE])
		"forage":
			return [id, Color.WHITE]
		"pet":
			return ["bone", Color.WHITE]
		"material":
			return ["wood_log" if id == "wood" else "stone", Color.WHITE]
		"quest":
			return {"flour": ["bread", Color.WHITE], "flower": ["flower", Color(1, 0.55, 0.75)], "coin": ["coin", Color.WHITE]}.get(id, ["star", Color.WHITE])
	return ["star", Color.WHITE]


# ================================================================ treasure map

func _build_map() -> void:
	map_panel = PanelContainer.new()
	map_panel.add_theme_stylebox_override("panel", UI.panel_style(Color(0.7, 0.55, 0.3)))
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	map_panel.offset_left = 14
	map_panel.offset_right = 14 + 330
	map_panel.offset_top = -205
	map_panel.offset_bottom = 205
	map_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	map_panel.add_child(v)
	var t := UI.small_label("Treasure Map", UI.GOLD, 22)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	map_view = Control.new()
	map_view.custom_minimum_size = Vector2(286, 286)
	map_view.set_script(load("res://scripts/map_view.gd"))
	v.add_child(map_view)
	var hint := UI.small_label("X marks the spot! Walk there and press E to dig.\nM to hide the map.", UI.MUTED, 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	map_panel.visible = false


func show_map(treasure: Vector3) -> void:
	map_view.world = world
	map_view.treasure = treasure
	map_panel.visible = true
	UI.pop_in(map_panel)


func hide_map() -> void:
	map_panel.visible = false


func map_visible() -> bool:
	return map_panel.visible


# ================================================================ pet

func open_adopt(pet: Node) -> void:
	var v := _open_modal("A Stray Puppy!", "This little one has been waiting by your door. It wags its whole body when it sees you.",
		Color(0.8, 0.55, 0.3), "paw", Color(1, 0.9, 0.75), 560)
	pet.show_hearts(3)
	Audio.play("bark")
	v.add_child(UI.small_label("Give your new friend a name:", UI.CREAM, 17))
	var name_edit := LineEdit.new()
	name_edit.text = "Biscuit"
	name_edit.max_length = 14
	name_edit.custom_minimum_size = Vector2(300, 40)
	name_edit.add_theme_font_size_override("font_size", 20)
	name_edit.select_all_on_focus = true
	v.add_child(name_edit)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var adopt := func():
		var nm := name_edit.text.strip_edges()
		if nm == "":
			nm = "Biscuit"
		var p := Game.pet()
		p["adopted"] = true
		p["name"] = nm
		p["happiness"] = 60
		p["petted_day"] = Game.day
		pet.refresh()
		close_modal()
		Audio.play("quest")
		world.hud.show_toast("You adopted %s! Feed, pet and play with %s every day. Press E on %s for the pet menu." % [nm, nm, nm], 6.0)
	name_edit.text_submitted.connect(func(_t): adopt.call())
	row.add_child(_button("Adopt!", true, adopt, 180))
	row.add_child(_button("Maybe later", true, func(): close_modal(), 180))
	name_edit.grab_focus.call_deferred()


func open_pet(pet: Node) -> void:
	var p := Game.pet()
	var nm := str(p.get("name", "Biscuit"))
	var v := _open_modal(nm, "Your loyal puppy. A happy pup sometimes brings you presents in the morning!",
		Color(0.8, 0.55, 0.3), "paw", Color(1, 0.9, 0.75), 560)
	var happy := int(p.get("happiness", 50))
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 10)
	hrow.add_child(UI.small_label("Happiness", UI.CREAM, 16))
	hrow.add_child(_bar(happy / 100.0, Color(1, 0.5, 0.6)))
	hrow.add_child(UI.small_label(_mood(happy), UI.MUTED, 15))
	v.add_child(hrow)
	var today := HBoxContainer.new()
	today.add_theme_constant_override("separation", 18)
	for pair in [["Petted", "petted_day"], ["Fed", "fed_day"], ["Played", "played_day"]]:
		var done: bool = int(p.get(pair[1], -1)) == Game.day
		today.add_child(UI.small_label(("[x] " if done else "[  ] ") + pair[0] + " today", Color(0.6, 1, 0.55) if done else UI.MUTED, 15))
	v.add_child(today)
	var food := _food_for_pet()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	row.add_child(_button("Pet", true, func():
		var first: bool = int(p.get("petted_day", -1)) != Game.day
		if first:
			p["petted_day"] = Game.day
			p["happiness"] = clampi(int(p.get("happiness", 50)) + 10, 0, 100)
		pet.show_hearts(3 if first else 1)
		Audio.play("bark", 0.15, -4.0)
		close_modal()
		world.hud.show_toast(("%s loves that! (+happiness)" if first else "%s wags happily.") % nm, 2.5), 140))
	var fed_today: bool = int(p.get("fed_day", -1)) == Game.day
	var feed_text := "Already fed" if fed_today else ("Feed (%s)" % Game.item_name(food) if food != "" else "No food")
	row.add_child(_button(feed_text, not fed_today and food != "", func():
		Game.remove_item(food, 1)
		p["fed_day"] = Game.day
		p["happiness"] = clampi(int(p.get("happiness", 50)) + 15, 0, 100)
		pet.show_hearts(2)
		Audio.play("harvest")
		close_modal()
		world.hud.show_toast("%s gobbles up the %s! (+happiness)" % [nm, Game.item_name(food).to_lower()], 3.0), 190))
	row.add_child(_button("Play fetch", true, func():
		close_modal()
		pet.start_fetch(), 140))
	if food == "" and not fed_today:
		v.add_child(UI.small_label("Buy Pet Treats at the market, or bring a fish.", UI.MUTED, 13))
	# where should the pup spend its day?
	v.add_child(UI.small_label("Where should %s be?" % nm, UI.CREAM, 16))
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 10)
	v.add_child(modes)
	for m in [["follow", "Follow me"], ["home", "Stay home"], ["roam", "Explore the village"]]:
		var b := _button(m[1], true, func():
			pet.set_mode(m[0])
			close_modal()
			world.hud.show_toast({"follow": "%s will follow you around.", "home": "%s trots off home. (It'll be waiting in your house.)",
				"roam": "%s runs off to explore the village! (It sleeps by your door at night.)"}[m[0]] % nm, 4.0), 180)
		if pet.mode() == m[0]:
			b.add_theme_stylebox_override("normal", UI.pad_style(Color(0.55, 0.4, 0.7)))
			b.text = "> " + m[1]
		modes.add_child(b)
	_close_row(v)


func _mood(h: int) -> String:
	if h >= 85:
		return "Overjoyed!"
	if h >= 60:
		return "Happy"
	if h >= 35:
		return "Okay"
	return "Lonely..."


## A pet treat if you have one, otherwise your cheapest fish.
func _food_for_pet() -> String:
	if Game.count("pet_treat") > 0:
		return "pet_treat"
	var best := ""
	for id in Game.inventory:
		if Game.count(id) > 0 and Game.ITEMS.has(id) and Game.ITEMS[id]["kind"] == "fish":
			if best == "" or Game.ITEMS[id]["sell"] < Game.ITEMS[best]["sell"]:
				best = id
	return best


# ================================================================ gifts

func giftables() -> Array:
	var out := []
	for id in Game.ITEMS:
		var info: Dictionary = Game.ITEMS[id]
		if Game.count(id) > 0 and info["sell"] > 0:
			out.append(id)
	return out


func has_giftables() -> bool:
	return not giftables().is_empty()


func open_gift(npc: Node) -> void:
	var nm: String = npc.npc_name
	var v := _open_modal("A gift for %s" % nm, "Pick something from your bag. One gift a day per villager -- find out what they love!",
		Color(0.75, 0.35, 0.45), "heart", Color(1, 0.6, 0.7), 680)
	v.add_child(_hearts(Game.hearts(nm)))
	if npc.is_birthday():
		v.add_child(UI.small_label("It's %s's birthday -- gifts count double today!" % nm, UI.GOLD, 16))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	var known: Array = Game.xdict("known_likes").get(nm, [])
	for id in giftables():
		var b := Button.new()
		b.custom_minimum_size = Vector2(152, 74)
		b.focus_mode = Control.FOCUS_NONE
		var ic: Array = item_icon(id)
		var icon := ICON.new(ic[0], ic[1], 36.0)
		icon.position = Vector2(6, 6)
		b.add_child(icon)
		var l := UI.small_label("%s\nx%d" % [Game.item_name(id), Game.count(id)], UI.CREAM, 13)
		l.position = Vector2(48, 6)
		b.add_child(l)
		if known.has(id):
			var taste := VILLAGERS.taste(nm, id)
			var tl := UI.small_label({"love": "Loves it!", "like": "Likes it", "neutral": "Meh", "dislike": "Dislikes"}[taste],
				{"love": Color(1, 0.5, 0.65), "like": Color(0.6, 1, 0.55), "neutral": UI.MUTED, "dislike": Color(1, 0.5, 0.4)}[taste], 12)
			tl.position = Vector2(48, 50)
			b.add_child(tl)
		b.pressed.connect(func():
			close_modal()
			var line: String = npc.receive_gift(id)
			world.player.start_dialogue_lines(npc, [line])
			world.update_quest_log())
		grid.add_child(b)
	_close_row(v)


# ================================================================ journal

var journal_open := false


func open_journal() -> void:
	var v := _open_modal("Journal", "Your village life at a glance. (J or Esc to close)", Color(0.35, 0.45, 0.65), "map", Color.WHITE, 820)
	journal_open = true
	var jm := modal
	modal.tree_exiting.connect(func():
		if modal == jm or not is_open():   # (not when just switching tabs)
			journal_open = false)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	for t in [["map", "Map"], ["villagers", "Villagers"], ["pet", "Pet"], ["collection", "Collections"], ["calendar", "Calendar"]]:
		var b := _button(t[1], true, func():
			journal_tab = t[0]
			Audio.play("click")
			open_journal(), 140)
		b.modulate = Color.WHITE if journal_tab == t[0] else Color(0.65, 0.6, 0.55)
		tabs.add_child(b)
	if journal_tab == "map":
		_journal_map(v)
		_close_row(v)
		return
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(780, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	match journal_tab:
		"villagers":
			_journal_villagers(list)
		"pet":
			_journal_pet(list)
		"collection":
			_journal_collection(list)
		"calendar":
			_journal_calendar(list)
	_close_row(v)


func _journal_villagers(list: VBoxContainer) -> void:
	for n in world.npcs:
		var nm: String = n.npc_name
		var d := VILLAGERS.of(nm)
		var card := _card()
		list.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)
		var badge := ICON.new("heart", Color.from_hsv(n.hue, 0.5, 0.95), 44.0)
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(badge)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 12)
		top.add_child(UI.small_label(nm, UI.GOLD, 20))
		top.add_child(_hearts(Game.hearts(nm), 16.0))
		top.add_child(UI.small_label("Birthday: day %d" % int(d.get("birthday", 0)), UI.MUTED, 13))
		col.add_child(top)
		var bio := UI.small_label(d.get("bio", ""), UI.CREAM, 13)
		bio.autowrap_mode = TextServer.AUTOWRAP_WORD
		bio.custom_minimum_size.x = 660
		col.add_child(bio)
		var known: Array = Game.xdict("known_likes").get(nm, [])
		var loves := []
		var likes := []
		var dislikes := []
		for id in known:
			var t := VILLAGERS.taste(nm, id)
			var iname := Game.item_name(id)
			if t == "love":
				loves.append(iname)
			elif t == "like":
				likes.append(iname)
			elif t == "dislike":
				dislikes.append(iname)
		col.add_child(UI.small_label("Loves: %s    Likes: %s    Dislikes: %s" % [
			", ".join(loves) if not loves.is_empty() else "???",
			", ".join(likes) if not likes.is_empty() else "???",
			", ".join(dislikes) if not dislikes.is_empty() else "???"], Color(0.95, 0.75, 0.8), 12))
		var seen: Array = Game.xdict("events_seen").get(nm, [])
		var next := 0
		for lvl in VILLAGERS.HEART_EVENTS:
			if not seen.has(lvl):
				next = lvl
				break
		var status := []
		status.append("Gift given today" if int(Game.xdict("gift_day").get(nm, -1)) == Game.day else "No gift yet today")
		status.append("Chatted today" if int(Game.xdict("talked_day").get(nm, -1)) == Game.day else "Haven't chatted today")
		status.append("Next story at %d hearts" % next if next > 0 else "All stories seen")
		var spot: Array = n.current_spot()
		if not spot.is_empty():
			status.append("Now: " + (spot[3] as String).replace("~", "").strip_edges())
		col.add_child(UI.small_label("   |   ".join(status), UI.MUTED, 12))


func _journal_pet(list: VBoxContainer) -> void:
	var p := Game.pet()
	if not p.get("adopted", false):
		list.add_child(UI.small_label("No pet yet. There's a stray puppy waiting by your front door...", UI.CREAM, 17))
		return
	var card := _card()
	list.add_child(card)
	var col := VBoxContainer.new()
	card.add_child(col)
	col.add_child(UI.small_label(str(p.get("name", "Biscuit")) + "   (%s)" % {"follow": "following you", "home": "staying at home", "roam": "exploring the village"}.get(str(p.get("mode", "follow")), ""), UI.GOLD, 24))
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 10)
	hrow.add_child(UI.small_label("Happiness", UI.CREAM, 16))
	hrow.add_child(_bar(int(p.get("happiness", 50)) / 100.0, Color(1, 0.5, 0.6), 320))
	hrow.add_child(UI.small_label(_mood(int(p.get("happiness", 50))), UI.MUTED, 15))
	col.add_child(hrow)
	for pair in [["Petted", "petted_day"], ["Fed", "fed_day"], ["Played fetch", "played_day"]]:
		var done: bool = int(p.get(pair[1], -1)) == Game.day
		col.add_child(UI.small_label(("[x] " if done else "[  ] ") + pair[0] + " today", Color(0.6, 1, 0.55) if done else UI.MUTED, 15))
	col.add_child(UI.small_label("Tips: pet (+10), feed a treat or fish (+15) and play fetch (+15) once a day each.\nMissing a meal or a pat makes your pup sad overnight. Happy pups (60+) find gifts in the morning.", UI.MUTED, 13))


func _journal_collection(list: VBoxContainer) -> void:
	var stars: Array = Game.xarr("stars_found")
	var best: Dictionary = Game.xdict("music_best")
	var rows := [
		["fish", "Fish caught", str(Game.fish_caught)],
		["wheat", "Crops harvested", str(Game.crops_harvested)],
		["pot", "Dishes cooked", str(Game.dishes_cooked)],
		["berries", "Things foraged", str(Game.xi("foraged"))],
		["map", "Treasures dug up", str(Game.xi("treasures"))],
		["wood_log", "Wood and stone gathered", str(Game.xi("gathered"))],
		["map", "Board requests done", str(Game.xi("board_done"))],
		["relic", "Town Hall", "Finished!" if Game.hall_built() else "Stage %d of 4" % (Game.xi("hall_stage") + 1)],
		["telescope", "Constellations charted", "%d / %d  %s" % [stars.size(), EXTRA_CONSTELLATIONS, (", ".join(stars) if not stars.is_empty() else "")]],
		["stone", "Best stone skip", "%d skips" % Game.xi("skip_best")],
		["flag", "Best race vs Pip", ("%.1f s" % Game.race_best) if Game.race_best > 0 else "-"],
		["note", "Songs", ", ".join(best.keys().map(func(k): return "%s: %d" % [k, int(best[k])])) if not best.is_empty() else "-"],
		["pot", "Secret recipes", ", ".join(Game.xarr("recipes").map(func(r): return Game.item_name(r))) if not Game.xarr("recipes").is_empty() else "none yet (5 hearts with a villager)"],
	]
	for r in rows:
		var card := _card()
		list.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		row.add_child(ICON.new(r[0], Color(1, 0.8, 0.5), 32.0))
		var l := UI.small_label(r[1], UI.CREAM, 16)
		l.custom_minimum_size.x = 230
		row.add_child(l)
		var val := UI.small_label(r[2], UI.GOLD, 15)
		val.autowrap_mode = TextServer.AUTOWRAP_WORD
		val.custom_minimum_size.x = 440
		row.add_child(val)


const EXTRA_CONSTELLATIONS := 8


func _journal_calendar(list: VBoxContainer) -> void:
	list.add_child(UI.small_label("Today is day %d of the season (%d days in a season). Day %d overall." % [Game.day_of_season(), Game.SEASON_DAYS, Game.day], UI.CREAM, 17))
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	list.add_child(grid)
	var bdays := {}
	for n in world.npcs:
		bdays[int(VILLAGERS.of(n.npc_name).get("birthday", 0))] = n.npc_name
	for d in range(1, Game.SEASON_DAYS + 1):
		var p := PanelContainer.new()
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.9, 0.7, 0.3, 0.55) if d == Game.day_of_season() else (Color(1, 0.45, 0.6, 0.3) if bdays.has(d) else Color(1, 1, 1, 0.05))
		s.set_corner_radius_all(8)
		s.set_content_margin_all(6)
		p.add_theme_stylebox_override("panel", s)
		p.custom_minimum_size = Vector2(104, 54)
		var l := UI.small_label(str(d) + ("\n" + bdays[d] + "'s birthday" if bdays.has(d) else ""), UI.CREAM, 12)
		p.add_child(l)
		grid.add_child(p)


# ================================================================ request board

func open_board() -> void:
	var board = world.board
	var v := _open_modal("Request Board", "Villagers pin jobs here each morning. Take a note, gather the items, then talk to them to hand it in.",
		Color(0.7, 0.45, 0.25), "map", Color.WHITE, 760)
	v.add_child(UI.small_label("Notes on the board  (%d slots%s)" % [board.slots(), ", town hall bonus!" if Game.hall_built() else ""], UI.GOLD, 17))
	var notes := HBoxContainer.new()
	notes.add_theme_constant_override("separation", 10)
	v.add_child(notes)
	if board.posted().is_empty():
		notes.add_child(UI.small_label("Nothing new today. Check back tomorrow morning!", UI.MUTED, 15))
	for r in board.posted():
		notes.add_child(_note_card(r, true))
	v.add_child(UI.small_label("Your requests  (%d / %d)" % [board.accepted().size(), board.MAX_ACCEPTED], UI.GOLD, 17))
	if board.accepted().is_empty():
		v.add_child(UI.small_label("None yet -- take a note from the board above.", UI.MUTED, 14))
	for r in board.accepted():
		var card := _card()
		v.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var ic: Array = item_icon(r["item"])
		row.add_child(ICON.new(ic[0], ic[1], 34.0))
		var left: int = int(r["deadline"]) - Game.day + 1
		var have: int = board.have_for(r)
		var l := UI.small_label("%s wants %d %s   (you have %d)   -   %d coins   -   %s" % [r["npc"], int(r["count"]),
			Game.item_name(r["item"], int(r["count"]) > 1).to_lower(), have, int(r["reward"]),
			"last day!" if left <= 1 else "%d days left" % left], Color(0.6, 1, 0.55) if have >= int(r["count"]) else UI.CREAM, 14)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var id: int = r["id"]
		row.add_child(_button("Drop", true, func():
			board.drop(id)
			open_board(), 80))
	v.add_child(UI.small_label("Done so far: %d requests" % Game.xi("board_done"), UI.MUTED, 13))
	_close_row(v)


func _note_card(r: Dictionary, can_take: bool) -> PanelContainer:
	var board = world.board
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.95, 0.9, 0.75)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(10)
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 4
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(172, 250)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	p.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	col.add_child(top)
	var npc_color := Color(0.5, 0.4, 0.3)
	for n in world.npcs:
		if n.npc_name == r["npc"]:
			npc_color = Color.from_hsv(n.hue, 0.6, 0.8)
	top.add_child(ICON.new("heart", npc_color, 22.0))
	top.add_child(UI.small_label(r["npc"], Color(0.3, 0.2, 0.1), 17))
	var t := UI.small_label("\"%s\"" % r["text"], Color(0.3, 0.22, 0.15), 12)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD
	t.custom_minimum_size = Vector2(150, 0)
	col.add_child(t)
	var ic: Array = item_icon(r["item"])
	var need := HBoxContainer.new()
	need.add_theme_constant_override("separation", 6)
	need.add_child(ICON.new(ic[0], ic[1], 30.0))
	need.add_child(UI.small_label("x%d  (have %d)" % [int(r["count"]), board.have_for(r)], Color(0.3, 0.22, 0.15), 14))
	col.add_child(need)
	col.add_child(UI.small_label("Reward: %d coins" % int(r["reward"]), Color(0.6, 0.4, 0.05), 14))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	if can_take:
		var full: bool = board.accepted().size() >= board.MAX_ACCEPTED
		var id: int = r["id"]
		col.add_child(_button("Hands full" if full else "Take note", not full, func():
			if board.accept(id):
				Audio.play("click")
				open_board(), 150))
	return p


# ================================================================ town hall

func open_townhall(hall: Node) -> void:
	var stage := Game.xi("hall_stage")
	var v := _open_modal("Town Hall Construction", "Bring wood and stone (chop trees with red ribbons, break boulders) to build the village a town hall.",
		Color(0.45, 0.55, 0.7), "relic", Color.WHITE, 700)
	var steps := HBoxContainer.new()
	steps.add_theme_constant_override("separation", 8)
	v.add_child(steps)
	for i in Game.TOWN_HALL.size():
		var st: Dictionary = Game.TOWN_HALL[i]
		var done := i < stage
		var cur := i == stage
		var c := _card()
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(0.4, 0.8, 0.4, 0.2) if done else (Color(1, 0.85, 0.4, 0.18) if cur else Color(1, 1, 1, 0.04))
		cs.set_corner_radius_all(10)
		cs.set_content_margin_all(8)
		c.add_theme_stylebox_override("panel", cs)
		c.custom_minimum_size = Vector2(152, 0)
		var l := UI.small_label("%d. %s\n%s" % [i + 1, st["name"], "Done!" if done else ("Building now" if cur else "Later")],
			Color(0.6, 1, 0.55) if done else (UI.GOLD if cur else UI.MUTED), 14)
		c.add_child(l)
		steps.add_child(c)
	if stage >= Game.TOWN_HALL.size():
		v.add_child(UI.small_label("The Town Hall is finished. Thank you!", UI.GOLD, 18))
		_close_row(v)
		return
	var cur_st: Dictionary = Game.TOWN_HALL[stage]
	v.add_child(UI.small_label("Stage %d: %s -- %s" % [stage + 1, cur_st["name"], cur_st["desc"]], UI.CREAM, 17))
	for res in cur_st["needs"]:
		var need: int = cur_st["needs"][res]
		var given: int = need - hall.still_needed(res)
		var card := _card()
		v.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var ic := "coin" if res == "coins" else ("stone" if res == "stone" else "wood_log")
		row.add_child(ICON.new(ic, Color.WHITE, 36.0))
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(UI.small_label("%s: %d / %d   (you have %d)" % [res.capitalize(), given, need, hall.have(res)], UI.CREAM, 15))
		col.add_child(_bar(float(given) / need, Color(0.55, 0.8, 0.45) if given >= need else UI.GOLD, 420))
		var give_n: int = min(hall.still_needed(res), hall.have(res))
		var r: String = res
		row.add_child(_button("Give %d" % give_n if give_n > 0 else ("Done" if given >= need else "Need more"), give_n > 0, func():
			var n: int = hall.give(r)
			if n > 0:
				world.hud.show_toast("Gave %d %s." % [n, r], 2.0)
			if is_open():
				open_townhall(hall), 130))
	v.add_child(UI.small_label("Tip: the market sells wood and stone too, if you're in a hurry.", UI.MUTED, 13))
	_close_row(v)


# ================================================================ renaming things

func open_rename(title: String, subtitle: String, current: String, on_done: Callable) -> void:
	var v := _open_modal(title, subtitle, Color(0.45, 0.55, 0.7), "map", Color.WHITE, 560)
	var edit := LineEdit.new()
	edit.text = current
	edit.max_length = 24
	edit.custom_minimum_size = Vector2(420, 42)
	edit.add_theme_font_size_override("font_size", 20)
	edit.select_all_on_focus = true
	v.add_child(edit)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var save := func():
		var t := edit.text.strip_edges()
		close_modal()
		on_done.call(t)
		Audio.play("ding")
		world.hud.show_toast("The sign now reads: %s" % (t if t != "" else "Home Sweet Home"), 3.0)
	edit.text_submitted.connect(func(_t): save.call())
	row.add_child(_button("Save", true, save, 160))
	row.add_child(_button("Cancel", true, func(): close_modal(), 160))
	edit.grab_focus.call_deferred()


# ================================================================ the village guide map

const GUIDE_COLORS := {"shop": Color(0.85, 0.35, 0.3), "game": Color(0.55, 0.35, 0.75), "fish": Color(0.25, 0.55, 0.85),
	"house": Color(0.8, 0.5, 0.2), "build": Color(0.35, 0.5, 0.65), "night": Color(0.2, 0.25, 0.5)}


## Everything worth visiting: [position, name, what you do there, color group]
func guide_entries() -> Array:
	var act = world.activities
	var e := []
	e.append([world.MARKET_POS, "Market", "Buy seeds, tools and hats; sell anything", "shop"])
	e.append([world.board.BOARD_POS, "Request board", "Daily delivery jobs from villagers", "shop"])
	e.append([act.BOARD_POS, "Projects board", "Fund gardens, a fountain, a bandstand, a statue", "build"])
	e.append([act.polar(act.RACE_SIGN_AT), "Race Pip!", "A lap of rings around the square (after her tag game)", "game"])
	e.append([world.POND_CENTER, "Pond", "Fishing", "fish"])
	e.append([world.everyday.SKIP_POS, "Flat stones", "Stone skipping", "game"])
	e.append([world._dock_dir() * (world.DOCK_START + 3.0), "Dock & beach", "Ocean fishing (Moonfish at night off the dock end)", "fish"])
	e.append([act.crab_spot, "Crab Rocks", "Crab catching, once a day", "game"])
	e.append([world.everyday.TELESCOPE_POS, "Telescope", "Stargazing (at night)", "night"])
	e.append([world.FARM_CENTER, "Your farm", "Plant, water and \"Pull!\" harvest", "game"])
	e.append([world.PLAYER_HOUSE, "Your house", "Bed, stove (cooking), piano (music), village map", "house"])
	var games := {"Bram": "Baking", "Ivy": "Flower shop orders", "Pip": "Block tower", "Otto": "Curio card pairs", "Sal": "Catch sorting"}
	for def in world.npc_defs:
		e.append([def["home"], "%s's %s" % [def["name"], "hut" if def.get("hut", false) else "house"], games.get(def["name"], ""), "house"])
	e.append([world.townhall.HALL_POS, "Town Hall", "Go inside (records, request board)" if Game.hall_built() else "Build it with wood, stone and coins", "build"])
	if Game.is_project_funded("bandstand"):
		e.append([act.BANDSTAND_POS, "Bandstand", "Play music; dancing in the evening", "game"])
	return e


func _journal_map(v: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var mv := Control.new()
	mv.custom_minimum_size = Vector2(420, 420)
	mv.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mv.clip_contents = true     # nothing drawn past the edge of the map
	mv.set_script(load("res://scripts/map_view.gd"))
	mv.world = world
	var marks := []
	var entries := guide_entries()
	for i in entries.size():
		marks.append({"pos": entries[i][0], "n": i + 1, "color": GUIDE_COLORS[entries[i][3]]})
	for id in world.gathering.nodes:
		var n: Dictionary = world.gathering.nodes[id]
		marks.append({"pos": n["pos"], "n": 0, "color": Color(0.2, 0.55, 0.2) if n["kind"] == "tree" else Color(0.45, 0.45, 0.5)})
	for f in world.everyday.forage_nodes:
		if is_instance_valid(f):
			marks.append({"pos": f.global_position, "n": 0, "color": Color(0.75, 0.3, 0.8)})
	mv.markers = marks
	if bool(Game.extra.get("treasure_opened", false)) and not bool(Game.extra.get("treasure_found", false)):
		mv.treasure = world.everyday.treasure_pos
	row.add_child(mv)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(350, 420)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	var legend := VBoxContainer.new()
	legend.add_theme_constant_override("separation", 4)
	scroll.add_child(legend)
	for i in entries.size():
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		var badge := PanelContainer.new()
		var bs := StyleBoxFlat.new()
		bs.bg_color = GUIDE_COLORS[entries[i][3]]
		bs.set_corner_radius_all(11)
		bs.content_margin_left = 6
		bs.content_margin_right = 6
		badge.add_theme_stylebox_override("panel", bs)
		badge.custom_minimum_size = Vector2(26, 22)
		var bl := UI.small_label(str(i + 1), Color.WHITE, 13)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_child(bl)
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		line.add_child(badge)
		var t := UI.small_label("%s\n%s" % [entries[i][1], entries[i][2]], UI.CREAM, 13)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD
		t.custom_minimum_size.x = 300
		line.add_child(t)
		legend.add_child(line)
	legend.add_child(UI.small_label("Small dots: green = trees to chop, grey = boulders,\npurple = today's forage finds.  Arrow = you.", UI.MUTED, 12))


# ================================================================ the bag (inventory)

var bag_tab := "all"
var bag_sel := ""
const BAG_TABS := [["all", "All"], ["seed", "Seeds"], ["crop", "Crops"], ["fish", "Fish"],
	["finds", "Finds"], ["cooking", "Food"], ["other", "Materials & more"]]
const BAG_ORDER := ["seed", "crop", "fish", "forage", "treasure", "critter", "dish", "goods", "material", "pet", "quest"]


static func bag_group(kind: String) -> String:
	match kind:
		"seed", "crop", "fish":
			return kind
		"forage", "treasure", "critter":
			return "finds"
		"dish", "goods":
			return "cooking"
	return "other"


## Everything in your bag, in a sensible order.
func bag_items(tab := "all") -> Array:
	var out := []
	for kind in BAG_ORDER:
		for id in Game.ITEMS:
			if Game.ITEMS[id]["kind"] == kind and Game.count(id) > 0 and (tab == "all" or bag_group(kind) == tab):
				out.append(id)
	return out


func open_bag() -> void:
	var v := _open_modal("Your Bag", "Everything you're carrying. Click something for details.  (I or Esc to close)",
		Color(0.55, 0.4, 0.25), "pot", Color(1, 0.85, 0.5), 900)
	bag_open = true
	var bm := modal
	modal.tree_exiting.connect(func():
		if modal == bm or not is_open():   # (not when just switching tabs)
			bag_open = false)
	# totals
	var worth := 0
	var things := 0
	for id in bag_items():
		things += Game.count(id)
		worth += int(Game.ITEMS[id]["sell"]) * Game.count(id)
	var sums := HBoxContainer.new()
	sums.add_theme_constant_override("separation", 24)
	sums.add_child(UI.small_label("Coins: %d" % Game.coins, UI.GOLD, 17))
	sums.add_child(UI.small_label("%d things (%d kinds)" % [things, bag_items().size()], UI.CREAM, 17))
	sums.add_child(UI.small_label("Worth about %d coins at the market" % worth, UI.MUTED, 15))
	v.add_child(sums)
	# tabs
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	for t in BAG_TABS:
		var n := bag_items(t[0]).size()
		var b := _button("%s (%d)" % [t[1], n] if t[0] != "all" else t[1], true, func():
			bag_tab = t[0]
			bag_sel = ""
			Audio.play("click")
			open_bag(), 118 if t[0] != "other" else 170)
		if bag_tab == t[0]:
			b.add_theme_color_override("font_color", UI.GOLD)
			b.add_theme_color_override("font_hover_color", UI.GOLD)
		tabs.add_child(b)
	var items := bag_items(bag_tab)
	if not items.has(bag_sel):
		bag_sel = items[0] if not items.is_empty() else ""
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	v.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)
	if items.is_empty():
		grid.add_child(UI.small_label("Nothing here yet.", UI.MUTED, 16))
	for id in items:
		grid.add_child(_bag_slot(id))
	body.add_child(_bag_detail(bag_sel))
	_close_row(v)


func _bag_slot(id: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(84, 84)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = Game.item_name(id)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(1, 1, 1, 0.14) if id == bag_sel else Color(1, 1, 1, 0.05)
	st.set_corner_radius_all(10)
	st.border_color = UI.GOLD if id == bag_sel else Color(1, 1, 1, 0.12)
	st.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", st)
	var hov := st.duplicate() as StyleBoxFlat
	hov.bg_color = Color(1, 1, 1, 0.18)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", hov)
	var ic: Array = item_icon(id)
	var icon := ICON.new(ic[0], ic[1], 46.0)
	icon.position = Vector2(19, 8)
	b.add_child(icon)
	var cnt := UI.small_label("x%d" % Game.count(id), Color.WHITE, 14)
	cnt.position = Vector2(4, 58)
	cnt.size = Vector2(76, 20)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cnt.add_theme_color_override("font_outline_color", Color.BLACK)
	cnt.add_theme_constant_override("outline_size", 4)
	b.add_child(cnt)
	if Game.ITEMS[id]["kind"] == "seed" and id == Game.selected_seed:
		var tag := UI.small_label("planting", UI.GOLD, 11)
		tag.position = Vector2(5, 3)
		b.add_child(tag)
	if Game.museum_items().has(id) and not Game.museum_has(id) and Game.hall_built():
		var star := ICON.new("star", UI.GOLD, 16.0)
		star.position = Vector2(64, 4)
		star.tooltip_text = "Not in the museum yet"
		b.add_child(star)
	b.pressed.connect(func():
		bag_sel = id
		Audio.play("click")
		open_bag())
	return b


func _bag_detail(id: String) -> PanelContainer:
	var card := _card()
	card.custom_minimum_size = Vector2(300, 380)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)
	if id == "":
		col.add_child(UI.small_label("Your bag is empty.\nGo fishing, farming or foraging!", UI.MUTED, 15))
		return card
	var info: Dictionary = Game.ITEMS[id]
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	col.add_child(top)
	var ic: Array = item_icon(id)
	top.add_child(ICON.new(ic[0], ic[1], 64.0))
	var tc := VBoxContainer.new()
	top.add_child(tc)
	tc.add_child(UI.small_label(Game.item_name(id), UI.GOLD, 20))
	tc.add_child(UI.small_label(KIND_NAMES.get(info["kind"], "Item"), UI.MUTED, 14))
	tc.add_child(UI.small_label("You have %d" % Game.count(id), UI.CREAM, 15))
	var sell: int = info["sell"]
	col.add_child(UI.small_label("Sells for %d each  (%d for all)" % [sell, sell * Game.count(id)] if sell > 0 else "Can't be sold", UI.CREAM, 15))
	var about := UI.small_label(item_about(id), UI.CREAM, 14)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD
	about.custom_minimum_size.x = 276
	col.add_child(about)
	var extras := []
	var used := _used_in(id)
	if not used.is_empty():
		extras.append("Cook it into: " + ", ".join(used))
	var fans := []
	for n in world.npcs:
		var known: Array = Game.xdict("known_likes").get(n.npc_name, [])
		if known.has(id) and VILLAGERS.taste(n.npc_name, id) == "love":
			fans.append(n.npc_name)
	if not fans.is_empty():
		extras.append("Loved by: " + ", ".join(fans))
	if Game.museum_items().has(id):
		extras.append("Museum: " + ("on display" if Game.museum_has(id) else ("not donated yet" if Game.hall_built() else "the town hall will have a museum")))
	if not extras.is_empty():
		var ex := UI.small_label("\n".join(extras), Color(0.75, 0.9, 0.7), 14)
		ex.autowrap_mode = TextServer.AUTOWRAP_WORD
		ex.custom_minimum_size.x = 276
		col.add_child(ex)
	if info["kind"] == "seed":
		var plant := _button("Planting these" if Game.selected_seed == id else "Plant these next", Game.selected_seed != id, func():
			Game.selected_seed = id
			Game.inventory_changed.emit()
			Audio.play("click")
			open_bag(), 200)
		col.add_child(plant)
	return card


const KIND_NAMES := {"seed": "Seeds", "crop": "Crop", "fish": "Fish", "forage": "Forage find", "treasure": "Treasure",
	"critter": "Critter", "dish": "Home cooking", "goods": "Handmade", "material": "Building material", "pet": "For your puppy",
	"quest": "For a villager"}


## Where it comes from and what it's for.
func item_about(id: String) -> String:
	var kind: String = Game.ITEMS[id]["kind"]
	match kind:
		"seed":
			var c: Dictionary = Game.CROPS.get(id, {})
			return "Plant on your farm and water it every day. Grows into %s in %d days." % [Game.item_name(c.get("crop", "wheat"), true).to_lower(), int(c.get("days", 2))]
		"crop":
			return "Grown on your farm. Sell it, cook with it, or give it to a villager."
		"fish":
			for f in Game.FISH:
				if f["id"] == id:
					var h: Array = f["hours"]
					var when := "any time" if int(h[0]) <= 6 and int(h[1]) >= 26 else "%s to %s" % [_hour_text(int(h[0])), _hour_text(int(h[1]))]
					var where := "the pond" if f["water"] == "pond" else ("the end of the dock" if f.get("dock", false) else "the ocean (beach or dock)")
					return "Caught in %s, %s." % [where, when] + (" A legendary fish!" if id in ["golden_carp", "moonfish"] else "")
			return "A fish."
		"forage":
			return {"berries": "Wild berries grow around the village. New ones every morning.",
				"herb": "Wild herbs grow around the village. New ones every morning.",
				"mushroom": "Mushrooms pop up near the edge of the village each morning.",
				"truffle": "A rare find near the edge of the village. Otto loves them.",
				"shell": "Washed up on the beach. New ones every morning.",
				"pearl": "Sometimes hidden inside a seashell on the beach."}.get(id, "Found around the village.")
		"treasure":
			return {"gem": "Found when breaking boulders (and sometimes buried).", "old_coin": "Dug up with the treasure map.",
				"relic": "A rare treasure dug up with the treasure map."}.get(id, "A treasure.")
		"critter":
			return "Caught at the Crab Rocks on the beach, once a day." if id == "crab" else "Caught on summer nights around the village."
		"dish":
			for r in Game.RECIPES:
				if r["id"] == id:
					var parts := []
					for k in r["needs"]:
						parts.append("%d %s" % [int(r["needs"][k]), "any fish" if k == "any_fish" else Game.item_name(k, int(r["needs"][k]) > 1).to_lower()])
					return "Cooked at your stove from " + ", ".join(parts) + "."
			return "Home cooking."
		"goods":
			return "Baked with Bram in his bakery." if id == "bread" else "Made with Ivy in her flower shop."
		"material":
			return "Chop trees and break rocks around the village (or buy it at the market). Used to build the town hall." if id != "gem" else ""
		"pet":
			return "A treat for your puppy. Buy them at the market."
		"quest":
			return "Someone in the village asked you for this."
	return ""


func _hour_text(h: int) -> String:
	var hh := h % 24
	return "%d %s" % [12 if hh % 12 == 0 else hh % 12, "AM" if hh < 12 else "PM"]


## Dishes this ingredient goes into (only recipes you know).
func _used_in(id: String) -> Array:
	var out := []
	var kind: String = Game.ITEMS[id]["kind"]
	for r in Game.RECIPES:
		var needs: Dictionary = r["needs"]
		if (needs.has(id) or (kind == "fish" and needs.has("any_fish"))) and Game.recipe_known(r):
			out.append(Game.item_name(r["id"]))
	return out.slice(0, 5)


var bag_open := false


# ================================================================ town hall: records and museum

func open_records() -> void:
	var v := _open_modal("Village Records", "Everything the village has done, written down in the big red book.", Color(0.55, 0.2, 0.2), "flag", Color.WHITE, 560)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	for r in world.interiors.records():
		grid.add_child(UI.small_label(r[0], UI.CREAM, 17))
		var val := UI.small_label(r[1], UI.GOLD, 17)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(val)
	_close_row(v)


func open_museum() -> void:
	var ids: Array = Game.museum_items()
	var done: int = Game.xarr("museum").size()
	var v := _open_modal("Village Museum", "Donate one of each fish, crop, find and treasure. Click something you're carrying to donate it.",
		Color(0.3, 0.45, 0.6), "fish", Color(0.6, 0.85, 1.0), 880)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	v.add_child(top)
	top.add_child(UI.small_label("%d / %d on display" % [done, ids.size()], UI.GOLD, 18))
	top.add_child(_bar(float(done) / ids.size(), Color(0.45, 0.75, 1.0), 300))
	var ri: int = Game.xi("museum_rewards")
	if ri < Game.MUSEUM_REWARDS.size():
		var nxt: Array = Game.MUSEUM_REWARDS[ri]
		top.add_child(UI.small_label("Next reward at %d: %d coins%s" % [int(nxt[0]), int(nxt[1]), (" + " + Game.item_name(nxt[2]).to_lower()) if str(nxt[2]) != "" else ""], UI.MUTED, 14))
	else:
		top.add_child(UI.small_label("Complete! Thank you, curator.", Color(0.6, 1, 0.6), 15))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(840, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	for section in [["Aquarium", ["fish"]], ["Harvest", ["crop"]], ["Finds and treasures", ["forage", "treasure"]]]:
		var sids := ids.filter(func(id): return Game.ITEMS[id]["kind"] in section[1])
		var have := sids.filter(func(id): return Game.museum_has(id)).size()
		list.add_child(UI.small_label("%s  (%d / %d)" % [section[0], have, sids.size()], UI.GOLD, 17))
		var grid := GridContainer.new()
		grid.columns = 7
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		list.add_child(grid)
		for id in sids:
			grid.add_child(_museum_slot(id))
	_close_row(v)


func _museum_slot(id: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(112, 78)
	b.focus_mode = Control.FOCUS_NONE
	var shown := Game.museum_has(id)
	var can := not shown and Game.count(id) > 0
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.3, 0.5, 0.35, 0.35) if shown else (Color(0.9, 0.7, 0.3, 0.25) if can else Color(1, 1, 1, 0.04))
	st.set_corner_radius_all(10)
	st.border_color = Color(0.5, 0.85, 0.5) if shown else (UI.GOLD if can else Color(1, 1, 1, 0.1))
	st.set_border_width_all(2)
	b.add_theme_stylebox_override("normal", st)
	b.add_theme_stylebox_override("hover", st)
	b.add_theme_stylebox_override("pressed", st)
	b.add_theme_stylebox_override("disabled", st)
	var ic: Array = item_icon(id)
	var icon := ICON.new(ic[0], ic[1] if (shown or can) else Color(0.2, 0.18, 0.16), 40.0)
	if not (shown or can):
		icon.modulate = Color(0.25, 0.22, 0.2)
	icon.position = Vector2(36, 4)
	b.add_child(icon)
	var name_l := UI.small_label(Game.item_name(id) if (shown or can or Game.count(id) > 0) else "???", UI.CREAM if shown else (UI.GOLD if can else UI.MUTED), 12)
	name_l.position = Vector2(2, 46)
	name_l.size = Vector2(108, 16)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(name_l)
	var status := UI.small_label("On display" if shown else ("Donate!" if can else ""), Color(0.6, 1, 0.6) if shown else UI.GOLD, 11)
	status.position = Vector2(2, 60)
	status.size = Vector2(108, 14)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(status)
	b.disabled = not can
	b.pressed.connect(func():
		var msg: String = world.interiors.donate(id)
		Audio.play("chime")
		world.hud.show_toast(msg if msg != "" else "Donated %s to the museum!" % Game.item_name(id).to_lower(), 3.5)
		if msg != "":
			Audio.play("win")
		open_museum())
	return b
