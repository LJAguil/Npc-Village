extends Node3D
## The village. Builds the world in code (houses, farm, pond, market, trees,
## lamps...), spawns the player and villagers, runs the clock and the
## day/night lighting, and handles quests, sleeping and the festival.

const NPC_SCRIPT := preload("res://scripts/npc.gd")
const PLAYER_SCRIPT := preload("res://scripts/player.gd")
const HUD_SCRIPT := preload("res://scripts/dialogue_ui.gd")
const SHOP_SCRIPT := preload("res://scripts/shop_ui.gd")
const MENUS_SCRIPT := preload("res://scripts/menus.gd")
const FISHING_SCRIPT := preload("res://scripts/fishing.gd")
const PICKUP_SCRIPT := preload("res://scripts/pickup.gd")
const TILE_SCRIPT := preload("res://scripts/farm_tile.gd")
const SPOT_SCRIPT := preload("res://scripts/interact_spot.gd")
const SCENERY_SCRIPT := preload("res://scripts/scenery.gd")
const MINIGAMES_SCRIPT := preload("res://scripts/minigames.gd")
const ACTIVITIES_SCRIPT := preload("res://scripts/activities.gd")
const INTERIORS_SCRIPT := preload("res://scripts/interiors.gd")
const EXTRA_GAMES_SCRIPT := preload("res://scripts/extra_games.gd")
const EVERYDAY_SCRIPT := preload("res://scripts/everyday.gd")
const PANELS_SCRIPT := preload("res://scripts/panels.gd")
const TOWNHALL_SCRIPT := preload("res://scripts/townhall.gd")
const GATHERING_SCRIPT := preload("res://scripts/gathering.gd")
const BOARD_SCRIPT := preload("res://scripts/request_board.gd")

const PLAY_RADIUS := 30.0   # the village is a round clearing surrounded by hills
const POND_CENTER := Vector3(-22, 0, -2)
const POND_RADIUS := 5.5
const FARM_CENTER := Vector3(-8, 0, 21)
const FARM_COLS := 4
const FARM_ROWS := 3
const FARM_SPACING := 1.7
const MARKET_POS := Vector3(0, 0, -17)
const PLAYER_HOUSE := Vector3(0, 0, 26)
const DOCK_ANGLE := 0.12          # the dock points (almost) due east
const DOCK_START := 29.5          # distance from the well where the dock begins...
const DOCK_END := 43.0            # ...and ends
const DOCK_WIDTH := 2.4
const SAL_HUT := Vector3(27, 0, -7.5)
const PLAZA_RADIUS := 6.2          # the cobbled square around the well

## Villagers and their quest chains. Edit freely!
## Quest types: "collect" (find items in the world), "dig" (find buried items
## with the metal detector), "tag", "deliver" (bring items you farmed or fished;
## "any_fish" = any kind), "festival" (the finale).
## A quest with "minigame" ("baking" or "memory") plays it after the items are
## found; the quest completes when you win.
var npc_defs := [
	{
		"name": "Bram", "hue": 0.0, "accessory": "chef_hat", "home": Vector3(-13, 0, -13),
		"greetings": ["Oh, hello there!", "Back again? Good to see you."],
		"lines": ["Fresh bread tomorrow, thanks to you!", "Have you tried standing still? Very relaxing."],
		"chat": ["Lovely weather, isn't it?", "I should get back to the oven soon.", "Smell that? Bread!", "Pop into the bakery sometime -- my oven is always warm."],
		"quests": [
			{"type": "collect", "item": "flour", "count": 3, "item_plural": "flour sacks", "reward": 20,
				"title": "Find Bram's 3 flour sacks",
				"ask": ["I'm Bram, the baker. Well... I would be.", "A gust of wind blew my 3 flour sacks all over the village!",
					"They're still tumbling around in the wind! Catch them for me -- just run into them."],
				"ask_npc": "Have you seen my flour sacks anywhere? They keep blowing away!",
				"minigame": "baking",
				"ask_minigame": ["You caught all three sacks! They were really rolling, weren't they?",
					"Now help me bake. Stop the needle in the golden zone -- three perfect loaves!"],
				"minigame_fail": "Oh dear, burnt to a crisp. Talk to me when you want to try again!",
				"thanks": ["Smell that? Perfect bread!", "Thank you, friend. You're a natural baker."]},
			{"type": "deliver", "item": "wheat", "count": 5, "item_plural": "wheat", "reward": 50,
				"title": "Grow 5 wheat for Bram",
				"ask": ["Now I have flour, but I'll need more soon.", "Could you grow 5 wheat for me? You have a farm plot next to your house.",
					"Wheat seeds are sold at the market. Water them every day and they're ready in 2 days."],
				"ask_npc": "Anyone growing wheat around here?",
				"hint_npc": ["The traveler has a farm by their house! Wheat grows in 2 days if you water it.", "The market sells wheat seeds, I think."],
				"hint_player": "Plant wheat on your farm and water it every day. It's ready after 2 days.",
				"thanks": ["Five bundles of golden wheat! Perfect.", "I'll bake you the biggest loaf in the village."]},
		],
	},
	{
		"name": "Ivy", "hue": 0.36, "accessory": "flower", "home": Vector3(13, 0, -13),
		"greetings": ["Hi! I'm Ivy.", "Hey, it's you again!"],
		"lines": ["My garden looks so pretty now.", "Some day I'll leave this village and see the world."],
		"chat": ["Have you seen my garden lately?", "I think it might rain.", "Want to race to the well?", "I could use a hand in my flower shop. Come inside!"],
		"quests": [
			{"type": "collect", "item": "flower", "count": 5, "item_plural": "flowers", "reward": 20,
				"title": "Pick 5 flowers for Ivy",
				"ask": ["I'm planting a garden, but I need more flowers.", "Could you pick 5 flowers for me? They grow all over the field."],
				"ask_npc": "I'm looking for flowers. Have you seen any?",
				"minigame": "memory",
				"ask_minigame": ["Five flowers! Now let's plant them in my special pattern.",
					"I'll show you the order -- watch closely, then repeat it with keys 1 to 4."],
				"minigame_fail": "Oops, the pattern got all mixed up. Talk to me to try again!",
				"thanks": ["It's perfect! Look at the colors!", "My garden is going to be the best in the village."]},
			{"type": "deliver", "item": "pumpkin", "count": 2, "item_plural": "pumpkins", "reward": 80,
				"title": "Grow 2 pumpkins for Ivy",
				"ask": ["I want to decorate my garden for the Harvest Festival.", "Could you grow 2 big pumpkins for me?",
					"Pumpkin seeds are at the market. They take 4 days, so plant them early!"],
				"ask_npc": "Do you know anyone who grows pumpkins?",
				"hint_npc": ["Pumpkins take 4 days of watering. The traveler's farm could grow them!", "Pumpkin seeds cost 25 at the market."],
				"hint_player": "Pumpkin seeds cost 25 at the market. Water them for 4 days.",
				"thanks": ["They're HUGE! Thank you!", "My garden will be the talk of the festival."]},
		],
	},
	{
		"name": "Pip", "hue": 0.13, "accessory": "", "scale": 1.2, "home": Vector3(13, 0, 13),
		"greetings": ["Hiya!!", "OH HI!"],
		"lines": ["That was the BEST game of tag ever!", "You're fast! Not as fast as me though. Well, maybe."],
		"chat": ["Tag! You're it!", "What's your favorite color? Mine's yellow!", "Let's go explore!", "Come play blocks in my room! Bet you can't beat my tower!"],
		"quests": [
			{"type": "tag", "time": 40.0, "title": "Catch Pip in a game of tag", "reward": 20,
				"ask": ["I'm Pip! Wanna play tag?", "You have 40 seconds to catch me! I trip sometimes, so watch for your chance.",
					"Ready? When you close this, GO!"],
				"thanks": []},
			{"type": "deliver", "item": "any_fish", "count": 3, "item_plural": "fish", "reward": 40,
				"title": "Show Pip 3 fish",
				"ask": ["I've never seen a fish up close!", "Can you catch 3 fish for me? Any kind!",
					"The pond is east of the well. Stand at the edge and press E to cast."],
				"ask_npc": "Have you ever caught a fish? I want to see one!",
				"hint_npc": ["The pond east of the well is full of minnows!", "I heard catfish only come out at night."],
				"hint_player": "Go to the pond east of the well, stand at the edge and press E to fish.",
				"thanks": ["WOW! They're so slippery!", "This one looks like it's smiling at me!"]},
			{"type": "deliver", "item": "carrot", "count": 3, "item_plural": "carrots", "reward": 60,
				"title": "Bring Pip 3 carrots",
				"ask": ["My mom says carrots make you run faster.", "Can you grow me 3 carrots? Then I'll be UNCATCHABLE!"],
				"ask_npc": "Do carrots really make you faster?",
				"hint_npc": ["Carrot seeds are at the market. They take 3 days to grow.", "I don't think carrots make you faster, Pip."],
				"hint_player": "Carrot seeds are at the market. They take 3 days of watering.",
				"thanks": ["Crunch crunch! I feel faster already!", "Wanna race? ...Maybe later."]},
		],
	},
	{
		"name": "Otto", "hue": 0.6, "accessory": "top_hat", "home": Vector3(-13, 0, 13),
		"greetings": ["Greetings, traveler.", "Hmm. You again. Welcome."],
		"lines": ["I am the village elder. Also the only one with a proper hat.", "Talk to everyone. That is ancient wisdom."],
		"chat": ["In my day, the grass was greener.", "Mind your manners, youngster.", "Hmm. Yes. Indeed.", "Care to test your memory on my curio cabinet? Do come in."],
		"quests": [
			{"type": "dig", "item": "coin", "count": 5, "item_plural": "gold coins", "reward": 35,
				"title": "Dig up Otto's 5 buried coins",
				"ask": ["I am Otto, the village elder.", "Years ago I buried 5 gold coins around the village for safekeeping... and forgot where.",
					"Take my old metal detector. The bar fills and it beeps faster as you get close. When it's going wild, press E to dig!"],
				"ask_npc": "Have you seen me burying anything? I've forgotten where my coins are.",
				"thanks": ["My coins! Every last one.", "You are honest as well as helpful."]},
			{"type": "deliver", "item": "golden_carp", "count": 1, "item_plural": "golden carp", "reward": 150,
				"title": "Catch the legendary Golden Carp for Otto",
				"ask": ["Legend says a Golden Carp lives in our pond.", "I have wanted to see it since I was a boy. Catch it, and I will reward you handsomely."],
				"ask_npc": "Have you ever seen the Golden Carp?",
				"hint_npc": ["My grandma said the Golden Carp only bites early in the morning, before 9!", "They say a Golden Lure from the market attracts rare fish."],
				"hint_player": "They say it only bites early in the morning, before 9 AM. A Golden Lure might help.",
				"thanks": ["By my hat... the Golden Carp! It's real!", "You have made an old man very happy."]},
			{"type": "festival", "count": 1000, "item_plural": "coins", "reward": 0,
				"title": "Raise 1000 coins for the Harvest Festival",
				"wait": ["The Harvest Festival is coming, but the village isn't ready.", "Help everyone else first. Then come see me."],
				"ask": ["Everyone in the village is happy -- thanks to you.", "Now, the Harvest Festival! We need 1000 coins for lanterns, music, food and fireworks.",
					"Can you raise it? The market pays well for fish and crops."],
				"thanks": ["1000 coins! The festival is on!", "Everyone, to the well! Let the Harvest Festival begin!"]},
		],
	},
	{
		"name": "Sal", "hue": 0.5, "accessory": "sailor_hat", "home": SAL_HUT, "hut": true,
		"greetings": ["Ahoy there!", "Ahoy, landlubber!"],
		"lines": ["Forty years I've fished these waters.", "Smell that salt air? Nothing like it."],
		"chat": ["The tide's coming in.", "Saw a whale out past the lighthouse once. Honest!", "Fish are biting today.", "Swing by the hut and help me sort the catch, eh?"],
		"quests": [
			{"type": "deliver", "item": "pufferfish", "count": 1, "item_plural": "pufferfish", "reward": 60,
				"title": "Catch a pufferfish for Sal",
				"ask": ["Ahoy! Name's Sal. I run the dock down here.", "Bet you can't land a pufferfish. They puff up and dart about like mad!",
					"Fish anywhere along the beach, or off the end of my dock."],
				"ask_npc": "Anyone ever caught a pufferfish? Sal says they're a menace.",
				"hint_npc": ["Sal says pufferfish dart around suddenly. Keep your bar steady!", "You can fish in the ocean from the beach or Sal's dock."],
				"hint_player": "Pufferfish live in the ocean. Fish from the beach or the dock -- and watch for sudden darts!",
				"thanks": ["Ha! Look at him puff! You've got the knack.", "Here's something for your trouble."]},
			{"type": "deliver", "item": "moonfish", "count": 1, "item_plural": "moonfish", "reward": 200,
				"title": "Catch the legendary Moonfish for Sal",
				"ask": ["Now, have you heard of the Moonfish?", "Glows silver, it does. Only rises at night, and only in the deep water off the end of my dock.",
					"Forty years I've tried. Catch it and I'll make it worth your while."],
				"ask_npc": "You ever seen the Moonfish? Sal won't stop talking about it.",
				"hint_npc": ["They say the Moonfish only bites at night, off the very end of the dock.", "Sal's been trying to catch the Moonfish for forty years!"],
				"hint_player": "Only at night, only off the end of the dock. A Better Rod would help.",
				"thanks": ["The Moonfish... it's real. It's beautiful.", "Forty years! I could cry. Thank you, friend."]},
		],
	},
]

var npcs: Array = []
var player: CharacterBody3D
var hud: CanvasLayer
var shop: CanvasLayer
var menus: CanvasLayer
var fishing: Node3D
var tiles: Array = []
var landmarks: Array = []     # [{"name": String, "pos": Vector3, "radius": float}]
var pickups := {}             # item -> Array of pickup nodes still in the world

var sun: DirectionalLight3D
var moon: DirectionalLight3D
var sky_mat: ProceduralSkyMaterial
var env: Environment
var lamps: Array = []
var title_cam: Camera3D
var title_angle := 0.0
var in_title := true
var time_accum := 0.0
var was_night := false
var sleeping := false
var festival_decor: Node3D
var scenery: Node3D
var minigames: CanvasLayer
var activities: Node3D         # crab rocks, Pip's race, fireflies, projects, sprinklers
var interiors: Node3D          # walk-in houses and their minigames
var everyday: Node3D           # foraging, treasure, telescope, stone skipping, music, the puppy
var panels: CanvasLayer        # treasure map, pet menu, gifts, journal
var townhall: Node3D           # the town hall construction site / building
var gathering: Node3D          # choppable trees and breakable boulders
var board: Node3D              # the request board at the market
var beep_timer := 0.0
var path_dests: Array = []   # every dirt path runs from the well to one of these


func _ready() -> void:
	randomize()
	_build_environment()
	_build_village()

	hud = CanvasLayer.new()
	hud.set_script(HUD_SCRIPT)
	add_child(hud)
	hud.win_continue.connect(_on_win_continue)

	shop = CanvasLayer.new()
	shop.set_script(SHOP_SCRIPT)
	add_child(shop)
	shop.closed.connect(_on_shop_closed)
	shop.hat_changed.connect(_apply_player_hat)
	panels = CanvasLayer.new()
	panels.set_script(PANELS_SCRIPT)
	panels.world = self
	add_child(panels)
	activities.setup_ui()

	minigames = CanvasLayer.new()
	minigames.set_script(EXTRA_GAMES_SCRIPT)   # extra_games.gd extends house_games.gd extends minigames.gd
	add_child(minigames)

	fishing = Node3D.new()
	fishing.set_script(FISHING_SCRIPT)
	fishing.game_world = self
	add_child(fishing)

	player = CharacterBody3D.new()
	player.set_script(PLAYER_SCRIPT)
	player.position = PLAYER_SCRIPT.SPAWN
	player.hud = hud
	player.game = self
	add_child(player)

	# Title screen: fresh state, a golden-hour village and an orbiting camera
	Game.reset()
	Game.minutes = 17 * 60
	Game.time_running = false
	_init_farm_data()
	_spawn_npcs()
	_build_farm()

	title_cam = Camera3D.new()
	add_child(title_cam)
	title_cam.current = true

	menus = CanvasLayer.new()
	menus.set_script(MENUS_SCRIPT)
	add_child(menus)
	menus.start_new.connect(_start_game.bind(false))
	menus.start_continue.connect(_start_game.bind(true))
	menus.save_requested.connect(func(): menus.show_saved(Game.save_game()))

	hud.set_visible_hud(false)
	_update_lighting()
	Audio.start_music(false)

	if Game.start_mode == "auto_new":   # used by automated tests
		menus.title_root.visible = false
		menus.in_title = false
		_start_game(false)


func _process(delta: float) -> void:
	if in_title:
		title_angle += delta * 0.08
		title_cam.position = Vector3(sin(title_angle) * 27.0, 15.0, cos(title_angle) * 27.0)
		title_cam.look_at(Vector3(0, 1, 0))
	elif Game.time_running and not sleeping:
		time_accum += delta
		while time_accum >= Game.SECONDS_PER_GAME_MINUTE:
			time_accum -= Game.SECONDS_PER_GAME_MINUTE
			Game.minutes += 1
		if Game.minutes >= Game.PASS_OUT:
			sleep(true)
		_update_detector(delta)
	_update_lighting()
	var night := Game.is_night()
	if night != was_night:
		was_night = night
		Audio.set_night(night)


# ================================================================ Starting / loading

func _start_game(continue_save: bool) -> void:
	if continue_save and Game.load_game():
		hud.show_toast("Welcome back! Day %d." % Game.day, 4.0)
	else:
		Game.reset()
		hud.show_toast("Welcome to the village! Talk to the villagers (E) to see who needs help.", 6.0)
	if Game.farm.size() != FARM_COLS * FARM_ROWS:
		_init_farm_data()
	in_title = false
	title_cam.current = false
	interiors.leave_instantly()
	player.camera.current = true
	player.global_position = PLAYER_SCRIPT.SPAWN
	player.controls_enabled = true
	hud.set_visible_hud(true)
	for t in tiles:
		t.refresh()
	# Villagers pick up their saved quest progress and memories
	for i in npcs.size():
		var npc: CharacterBody3D = npcs[i]
		npc._load_from_save()
		var angle := TAU * i / npcs.size() + PI / 4.0
		npc.global_position = Vector3(cos(angle) * 6.0, 1, sin(angle) * 6.0)
		npc._show(true)
		npc._roll_schedule()
		npc._enter_idle()
	# Respawn any quest items still lying around
	for c in pickups.values():
		for p in c:
			if is_instance_valid(p):
				p.queue_free()
	pickups = {}
	for npc in npcs:
		if npc.quest_state == NPC_SCRIPT.Quest.ACTIVE and npc.quest.get("type", "") in ["collect", "dig"]:
			_spawn_collect_items(npc.quest)
	festival_decor.visible = Game.won
	activities.cancel_race()
	activities.refresh()
	_apply_player_hat()
	panels.close_modal(false)
	panels.hide_map()
	townhall.refresh()
	interiors.refresh_home_sign()
	everyday.on_start()
	was_night = Game.is_night()
	Audio.start_music(was_night)
	Game.time_running = true
	update_quest_log()
	hud.update_inventory()


func _init_farm_data() -> void:
	Game.farm = []
	for i in FARM_COLS * FARM_ROWS:
		Game.farm.append({"tilled": false, "crop": "", "stage": 0, "watered": false})


# ================================================================ Quests

func on_quest_accepted(npc: CharacterBody3D) -> void:
	var q: Dictionary = npc.quest
	match q["type"]:
		"collect", "dig":
			_spawn_collect_items(q)
			hud.show_toast("New quest: " + q["title"])
		"tag":
			hud.show_toast("Catch %s!" % npc.npc_name, 2.0)
		_:
			hud.show_toast("New quest: " + q["title"])
	Audio.play("click")
	update_quest_log()


func on_quest_completed(npc: CharacterBody3D, q: Dictionary) -> void:
	update_quest_log()
	hud.update_inventory()
	if q["type"] == "festival":
		_win()
		return
	Audio.play("quest")
	var msg := "You helped %s!" % npc.npc_name
	if q.get("reward", 0) > 0:
		msg += "  +%d coins" % q["reward"]
	hud.show_toast(msg)


func villagers_needing_help() -> Array:
	return npcs.filter(func(n): return not n.all_quests_done()).map(func(n): return n.npc_name)


func everyone_else_done(asker: CharacterBody3D) -> bool:
	for n in npcs:
		if n != asker and not n.all_quests_done():
			return false
	return true


func collect(pickup: Area3D) -> void:
	var item: String = pickup.item_type
	Game.add_item(item)
	pickups[item].erase(pickup)
	pickup.queue_free()
	Audio.play("coin", 0.15)
	var owner_npc := _npc_for_item(item)
	if owner_npc:
		var need: int = owner_npc.quest["count"]
		if Game.count(item) >= need:
			hud.show_toast("Got all the %s! Take them back to %s." % [owner_npc.quest["item_plural"], owner_npc.npc_name])
		else:
			hud.show_toast("Found one! (%d/%d %s)" % [Game.count(item), need, owner_npc.quest["item_plural"]], 2.0)
	update_quest_log()


## A hint about where a remaining item is, based on the nearest landmark.
func hint_for(item: String, from_npc: bool) -> String:
	var remaining: Array = pickups.get(item, []).filter(func(p): return is_instance_valid(p))
	if remaining.is_empty():
		return "I haven't seen any around." if from_npc else "I think you've found them all -- come back when you have them!"
	var p: Node3D = remaining.pick_random()
	var nearest := ""
	var best := INF
	for lm in landmarks:
		if lm["name"] == "":
			continue
		var d: float = lm["pos"].distance_to(p.global_position) - lm["radius"]
		if d < best:
			best = d
			nearest = lm["name"]
	if p.buried:
		if from_npc:
			return ["I remember you digging near %s, years ago!", "Try around %s -- you were always poking about there."].pick_random() % nearest
		return "Someone thinks you once buried something near %s." % nearest
	if from_npc:
		return ["I think I saw one near %s.", "Hmm, maybe try by %s?", "There was one near %s this morning!"].pick_random() % nearest
	return "Someone mentioned seeing one near %s." % nearest


func _npc_for_item(item: String) -> CharacterBody3D:
	for n in npcs:
		if n.quest.get("item", "") == item:
			return n
	return null


func update_quest_log() -> void:
	var done := 0
	var total := 0
	var text := ""
	for n in npcs:
		total += n.quests.size()
		done += n.quest_index
		var q: Dictionary = n.quest
		if n.all_quests_done():
			text += "\n[x] %s is happy!" % n.npc_name
		elif n.quest_state == NPC_SCRIPT.Quest.NOT_STARTED:
			if q["type"] == "festival" and not everyone_else_done(n):
				text += "\n[ ] Festival: help everyone, then see Otto"
			else:
				text += "\n[ ] Talk to %s" % n.npc_name
		else:
			match q["type"]:
				"collect", "dig", "deliver":
					if q.has("minigame") and n._have_for_quest() >= q["count"]:
						text += "\n[ ] Talk to %s -- time to %s!" % [n.npc_name, "bake" if q["minigame"] == "baking" else "plant"]
					else:
						text += "\n[ ] %s  (%d/%d)" % [q["title"], min(n._have_for_quest(), q["count"]), q["count"]]
				"festival":
					text += "\n[ ] %s  (%d/%d)" % [q["title"], min(Game.coins, q["count"]), q["count"]]
				_:
					text += "\n[ ] " + q["title"]
	var header := "Harvest Festival!" if Game.won else "Village requests  (%d/%d)" % [done, total]
	if board and not board.accepted().is_empty():
		text += "\n\nBoard requests" + board.quest_log_lines()
	hud.set_quest_log(header + "\n" + text)


func _spawn_collect_items(q: Dictionary) -> void:
	var item: String = q["item"]
	var need: int = q["count"] - Game.count(item)
	if not pickups.has(item):
		pickups[item] = []
	for i in need:
		_spawn_pickup(item, q["type"] == "dig")


func _spawn_pickup(item: String, buried := false) -> void:
	var pos := Vector3.ZERO
	for attempt in 80:
		var a := randf() * TAU
		pos = Vector3(cos(a), 0, sin(a)) * sqrt(randf()) * (PLAY_RADIUS - 4.0)
		if is_clear(pos, 1.5) and pos.distance_to(PLAYER_SCRIPT.SPAWN * Vector3(1, 0, 1)) > 5.0:
			break
	var p := Area3D.new()
	p.set_script(PICKUP_SCRIPT)
	p.item_type = item
	p.buried = buried
	p.game = self
	p.position = pos
	add_child(p)
	pickups[item].append(p)


## soft landmarks (flower beds) only count when hard_only is false.
func is_clear(pos: Vector3, margin: float, hard_only := false) -> bool:
	for lm in landmarks:
		if hard_only and lm.get("soft", false):
			continue
		if Vector2(pos.x - lm["pos"].x, pos.z - lm["pos"].z).length() < lm["radius"] + margin:
			return false
	return true


# ================================================================ Shop, sleep, win

func open_shop(_p) -> void:
	player.busy = true
	Game.time_running = false
	hud.show_prompt("")
	menus.can_pause = false   # Esc closes the market instead of opening the pause menu
	Audio.play("click")
	shop.open_shop()


func _on_shop_closed() -> void:
	activities.refresh()   # sprinklers may have been bought
	menus.can_pause = true
	player.busy = false
	Game.time_running = true
	update_quest_log()


## End the day. passed_out = true when the clock hit 2 AM.
func sleep(passed_out := false) -> void:
	if sleeping:
		return
	if fishing.is_active():
		fishing._finish(false, "")
	activities.cancel_race()
	if player.talking_to:
		player._end_dialogue()
	sleeping = true
	Game.time_running = false
	player.busy = true
	menus.can_pause = false
	hud.show_prompt("")
	hud.fade_through_black(func():
		Game.advance_day()
		for t in tiles:
			t.refresh()
		for n in npcs:
			n.reset_for_morning()
		if interiors.current == "home" and not passed_out:
			player.global_position = interiors.bed_side()   # wake up next to your bed
		else:
			interiors.leave_instantly()
			player.global_position = PLAYER_SCRIPT.SPAWN
			player.cam_yaw = 0.0
		player.velocity = Vector3.ZERO
		var saved := Game.save_game()
		var msg := "You passed out from exhaustion... " if passed_out else ""
		msg += "Good morning! Day %d." % Game.day
		if saved:
			msg += "  (Game saved)"
		hud.show_toast(msg, 5.0)
		Audio.play("morning")
		everyday.on_morning()
		update_quest_log()
		hud.update_inventory())
	await get_tree().create_timer(2.4).timeout
	sleeping = false
	player.busy = false
	menus.can_pause = true
	Game.time_running = true


func _win() -> void:
	Game.won = true
	festival_decor.visible = true
	Audio.play("win")
	# Everyone gathers around the well
	for i in npcs.size():
		var n: CharacterBody3D = npcs[i]
		var a := TAU * i / npcs.size()
		n.global_position = Vector3(cos(a) * 3.2, 1, sin(a) * 3.2)
		n.celebrate()
	_confetti()
	Game.save_game()
	Game.time_running = false
	player.busy = true
	hud.show_win("The Harvest Festival is on!\n\nYou helped every villager and brought the village together.\n\nDay %d   |   Fish caught: %d   |   Crops harvested: %d" % [Game.day, Game.fish_caught, Game.crops_harvested])
	update_quest_log()


func _on_win_continue() -> void:
	player.busy = false
	Game.time_running = true
	for n in npcs:
		n.stop_celebrating()


func _confetti() -> void:
	_confetti_at(Vector3(0, 6, 0))


func _confetti_at(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = 300
	p.lifetime = 4.0
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 6.0
	p.initial_velocity_max = 11.0
	p.gravity = Vector3(0, -4, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.12)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	p.mesh = q
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 0.3, 0.3), Color(1, 0.9, 0.2), Color(0.3, 0.8, 1), Color(0.6, 1, 0.4)])
	g.offsets = PackedFloat32Array([0.0, 0.33, 0.66, 1.0])
	p.color_initial_ramp = g
	add_child(p)
	p.emitting = true


# ================================================================ Day / night lighting

func _update_lighting() -> void:
	var h := fmod(Game.minutes / 60.0, 24.0)
	# 0 at night, 1 at midday; dawn ~6-7, dusk ~19-20
	var day_amt: float = clamp(min((h - 5.5) / 1.5, (20.5 - h) / 1.5), 0.0, 1.0)
	var dusk: float = clamp(1.0 - abs(h - 19.3) / 1.4, 0.0, 1.0) + clamp(1.0 - abs(h - 6.3) / 1.0, 0.0, 1.0) * 0.6
	var sun_angle := (h - 6.0) / 14.0 * PI        # 0 at sunrise, PI at sunset
	sun.rotation = Vector3(-clamp(sin(sun_angle), 0.15, 1.0) * 1.1, -sun_angle + PI * 0.5, 0)
	sun.light_energy = day_amt * 0.95
	sun.light_color = Color(1, 0.97, 0.9).lerp(Color(1, 0.6, 0.35), clamp(dusk, 0.0, 1.0))
	sun.visible = day_amt > 0.01
	moon.light_energy = (1.0 - day_amt) * 0.35
	moon.visible = day_amt < 0.99

	var top := Color(0.05, 0.07, 0.18).lerp(Color(0.35, 0.55, 0.9), day_amt)
	var horizon := Color(0.1, 0.12, 0.25).lerp(Color(0.7, 0.8, 0.9), day_amt)
	horizon = horizon.lerp(Color(1.0, 0.55, 0.35), clamp(dusk, 0.0, 1.0) * 0.8)
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = horizon
	sky_mat.ground_horizon_color = horizon.darkened(0.2)
	sky_mat.ground_bottom_color = Color(0.05, 0.08, 0.05).lerp(Color(0.2, 0.35, 0.18), day_amt)
	env.ambient_light_energy = lerp(0.35, 0.6, day_amt)
	env.fog_light_color = horizon.lerp(top, 0.3)
	for l in lamps:
		l.light_energy = (1.0 - day_amt) * 2.2
		l.visible = day_amt < 0.95
	for l in scenery.lighthouse_lights:
		l.visible = day_amt < 0.9
		l.light_energy = (1.0 - day_amt) * (6.0 if l is SpotLight3D else 2.0)


# ================================================================ World building

func _spawn_npcs() -> void:
	for i in npc_defs.size():
		var def: Dictionary = npc_defs[i]
		var npc := CharacterBody3D.new()
		npc.set_script(NPC_SCRIPT)
		npc.npc_name = def["name"]
		npc.hue = def["hue"]
		npc.accessory = def["accessory"]
		npc.model_scale = def.get("scale", 1.5)
		npc.greetings = def["greetings"]
		npc.lines = def["lines"]
		npc.chat_lines = def["chat"]
		npc.quests = def["quests"]
		var home: Vector3 = def["home"]
		npc.door_pos = home + (-home).normalized() * 2.9
		npc.world_half_size = PLAY_RADIUS - 4.0
		npc.game = self
		var angle := TAU * i / npc_defs.size() + PI / 4.0
		npc.position = Vector3(cos(angle) * 6.0, 1, sin(angle) * 6.0)
		add_child(npc)
		npcs.append(npc)
	for npc in npcs:
		npc.others = npcs.filter(func(n): return n != npc)


func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.ssao_enabled = true
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-60, 40, 0)
	moon.light_color = Color(0.55, 0.65, 1.0)
	add_child(moon)

	# Fog softens the distance so the hills and mountains fade into haze
	env.fog_enabled = true
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.15
	env.fog_aerial_perspective = 0.2

	scenery = Node3D.new()
	scenery.set_script(SCENERY_SCRIPT)
	add_child(scenery)
	scenery.dock_gap = func(p: Vector3) -> bool:
		var along := p.dot(_dock_dir())
		var side: float = abs(p.dot(Vector3(-_dock_dir().z, 0, _dock_dir().x)))
		return side < DOCK_WIDTH / 2 + 0.6 and along > DOCK_START - 2.0 and along < DOCK_END + 2.0
	scenery.build_terrain()
	scenery.build_mountains()
	scenery.build_ocean()


func _build_village() -> void:
	# Dirt paths from the well to each place (drawn first so things sit on top)
	path_dests = [Vector3(-13, 0, -13), Vector3(13, 0, -13), Vector3(13, 0, 13), Vector3(-13, 0, 13),
		MARKET_POS, PLAYER_HOUSE, POND_CENTER, FARM_CENTER + Vector3(3.5, 0, -2.5), _dock_dir() * 27.5]
	for dest in path_dests:
		_add_path(Vector3.ZERO, dest)

	for def in npc_defs:
		if def.get("hut", false):
			_add_hut(def["home"])
		else:
			_add_house(def["home"], "%s's House" % def["name"], "%s's house" % def["name"], Color.from_hsv(def["hue"], 0.35, 0.9))
	_add_house(PLAYER_HOUSE, "Your House", "your house", Color(0.85, 0.75, 0.6))

	_add_plaza()
	_add_well(Vector3.ZERO)
	_add_market()
	_add_pond()
	_build_farm_area()
	_build_dock()
	_add_ocean_fishing_spots()
	townhall = Node3D.new()
	townhall.set_script(TOWNHALL_SCRIPT)
	townhall.world = self
	add_child(townhall)
	townhall.build()
	board = Node3D.new()
	board.set_script(BOARD_SCRIPT)
	board.world = self
	add_child(board)
	board.build()

	# Every tree and rock in the village can be chopped or broken for wood and
	# stone. The named ones first (villagers use these names when giving hints).
	gathering = Node3D.new()
	gathering.set_script(GATHERING_SCRIPT)
	gathering.world = self
	add_child(gathering)
	gathering.add_fixed("lm_big_oak", "tree", Vector3(-13, 0, -7.5), 1.3, "the big oak", "oak0")
	gathering.add_fixed("lm_tall_pine", "tree", Vector3(20.5, 0, 12), 1.1, "the tall pine", "pine0")
	gathering.add_fixed("lm_birch", "tree", Vector3(-4, 0, -25), 1.2, "the lonely birch", "birch0")
	gathering.add_fixed("lm_old_oak", "tree", Vector3(21, 0, -15), 1.5, "the old oak", "oak1")
	gathering.add_fixed("lm_grey_rock", "rock", Vector3(19, 0, -10.5), 1.0, "the grey rock")
	gathering.add_fixed("lm_mossy_rock", "rock", Vector3(-22.5, 0, 11), 1.2, "the mossy rock")
	gathering.add_fixed("lm_flat_rock", "rock", Vector3(-19, 0, -18), 1.0, "the flat rock")
	gathering.add_fixed("lm_pointy_rock", "rock", Vector3(-21.5, 0, 8.3), 0.9, "the pointy rock")
	gathering.add_fixed("lm_boulder", "rock", Vector3(17, 0, 21), 1.6, "the big boulder")

	# Projects (gardens, fountain, bandstand, statue), crab rocks, sprinklers...
	activities = Node3D.new()
	activities.set_script(ACTIVITIES_SCRIPT)
	activities.world = self
	add_child(activities)
	activities.build()
	# ...then Pip's race course threads its way around all of that...
	activities.build_race()
	# ...and the rest of the trees and boulders fill in around the edges, off the course.
	gathering.build()

	interiors = Node3D.new()
	interiors.set_script(INTERIORS_SCRIPT)
	interiors.world = self
	add_child(interiors)
	interiors.build()
	everyday = Node3D.new()
	everyday.set_script(EVERYDAY_SCRIPT)
	everyday.world = self
	add_child(everyday)
	everyday.build()

	# The coast: lighthouse on the northern headland, a rowboat, palms and shells
	var lh_angle := -0.98
	var lh := Vector3(cos(lh_angle), 0, sin(lh_angle)) * 39.0
	lh.y = scenery.height_at(lh.x, lh.z) - 0.3
	scenery.build_lighthouse(lh)
	var boat_a := 0.42
	var boat_r: float = scenery.shore_radius(boat_a) - 1.2
	var boat_pos := Vector3(cos(boat_a), 0, sin(boat_a)) * boat_r
	boat_pos.y = scenery.height_at(boat_pos.x, boat_pos.z)
	scenery.add_rowboat(boat_pos, -boat_a + 0.3)
	landmarks.append({"name": "the rowboat", "pos": boat_pos, "radius": 1.6})
	scenery.build_beach(func(p, margin): return is_clear(p, margin) and not scenery.dock_gap.call(p))

	_place_lamps()
	scenery.build_forest()
	scenery.scatter_decor(func(p, margin): return is_clear(p, margin) and _dist_to_paths(p) > 1.0 + margin and not scenery.is_sand(p) \
		and Vector2(p.x, p.z).length() > (PLAZA_RADIUS + 0.4 if margin < 1.0 else 12.0))
	_build_festival_decor()


func _dock_dir() -> Vector3:
	return Vector3(cos(DOCK_ANGLE), 0, sin(DOCK_ANGLE))


## Sal's wooden dock: planks on posts, railings, crates, and a lantern at the end.
func _build_dock() -> void:
	var d := _dock_dir()
	var side := Vector3(-d.z, 0, d.x)
	var length := DOCK_END - DOCK_START
	var mid := d * (DOCK_START + length / 2)
	var yaw := atan2(d.x, d.z)
	var plank := _mat(Color(0.6, 0.45, 0.3), false)
	var dark := _mat(Color(0.4, 0.29, 0.18), false)
	var deck_y := 0.03

	var dock := StaticBody3D.new()
	dock.position = mid
	dock.rotation.y = yaw
	add_child(dock)
	# planks (alternating shades) and the walkable deck
	var n := int(length / 0.5)
	for i in n:
		_box_part(Vector3(0, deck_y - 0.06, -length / 2 + (i + 0.5) * 0.5), Vector3(DOCK_WIDTH, 0.12, 0.46),
			plank if i % 2 == 0 else _mat(Color(0.56, 0.42, 0.28), false), false, dock)
	var deck := CollisionShape3D.new()
	var deck_box := BoxShape3D.new()
	deck_box.size = Vector3(DOCK_WIDTH, 0.4, length + 0.5)
	deck.shape = deck_box
	deck.position.y = deck_y - 0.2
	dock.add_child(deck)
	# posts down into the water
	for i in range(0, int(length / 2.5) + 1):
		for sx in [-1, 1]:
			var post := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.12
			cyl.bottom_radius = 0.12
			cyl.height = 2.2
			post.mesh = cyl
			post.position = Vector3(sx * (DOCK_WIDTH / 2 + 0.05), -0.6, -length / 2 + i * 2.5)
			post.material_override = dark
			dock.add_child(post)
	# rope railings along the sides (the part over the water) with collision
	var rail_start := 33.2 - (DOCK_START + length / 2)   # railings start where the dock leaves the beach
	for sx in [-1, 1]:
		var rail_len := length / 2 - rail_start
		_box_part(Vector3(sx * (DOCK_WIDTH / 2 + 0.05), 0.75, rail_start + rail_len / 2), Vector3(0.06, 0.06, rail_len), dark, false, dock)
		var rcol := CollisionShape3D.new()
		var rbox := BoxShape3D.new()
		rbox.size = Vector3(0.3, 2.0, rail_len)
		rcol.shape = rbox
		rcol.position = Vector3(sx * (DOCK_WIDTH / 2 + 0.2), 1.0, rail_start + rail_len / 2)
		dock.add_child(rcol)
		for k in range(0, int(rail_len / 2.0) + 1):
			_box_part(Vector3(sx * (DOCK_WIDTH / 2 + 0.05), 0.4, rail_start + k * 2.0), Vector3(0.1, 0.8, 0.1), dark, false, dock)
	# end rail
	_box_part(Vector3(0, 0.75, length / 2), Vector3(DOCK_WIDTH, 0.06, 0.06), dark, false, dock)
	var ecol := CollisionShape3D.new()
	var ebox := BoxShape3D.new()
	ebox.size = Vector3(DOCK_WIDTH + 0.6, 2.0, 0.3)
	ecol.shape = ebox
	ecol.position = Vector3(0, 1.0, length / 2 + 0.15)
	dock.add_child(ecol)
	# crates and a barrel near the start, a lamp at the end
	_box_part(d * (DOCK_START + 1.2) + side * 1.9 + Vector3(0, 0.3, 0), Vector3(0.6, 0.6, 0.6), dark, false)
	_box_part(d * (DOCK_START + 1.9) + side * 2.0 + Vector3(0, 0.25, 0), Vector3(0.5, 0.5, 0.5), plank, false)
	_add_lamp(d * (DOCK_END - 0.8) + side * (DOCK_WIDTH / 2 - 0.25) + Vector3(0, deck_y, 0))
	landmarks.append({"name": "the dock", "pos": d * (DOCK_START + 1.0), "radius": 2.0})

	# fishing off the end of the dock: deep water, where the Moonfish lives
	var end := d * (DOCK_END - 0.6)
	_spot(end, 2.2,
		func(_p): return "" if fishing.is_active() else "E: Fish off the dock (deep water)",
		func(p): fishing.start(p, d * (DOCK_END + 4.0) + Vector3(0, scenery.WATER_Y + 0.05, 0), "ocean", true))


## "Press E to fish" spots every few meters along the waterline.
func _add_ocean_fishing_spots() -> void:
	var a := -0.8
	while a <= 0.8:
		var rs: float = scenery.shore_radius(a)
		var p := Vector3(cos(a), 0, sin(a)) * rs
		if rs > 0.0 and not scenery.dock_gap.call(p):
			var outward := Vector3(cos(a), 0, sin(a))
			var target := p + outward * 3.5 + Vector3(0, scenery.WATER_Y + 0.05, 0)
			_spot(p, 1.7,
				func(_p): return "" if fishing.is_active() else "E: Fish in the ocean",
				func(pl): fishing.start(pl, target, "ocean", false))
		a += 0.09


## Sal's little bait shack by the beach.
## Sal's Bait & Tackle: a weathered beach shack on a low deck, with plank
## walls, porthole windows, a tin roof, a porch awning strung with buoys, a big
## painted sign with a wooden fish, crates of fish, a barrel of rods, a net, a
## life ring and a lantern by the door.
func _add_hut(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	body.rotation.y = atan2(-pos.x, -pos.z)
	var planks := Color(0.52, 0.66, 0.72)
	var trim := Color(0.93, 0.93, 0.9)
	var deck := Color(0.62, 0.52, 0.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 27
	# deck on short stilts
	_box_part(Vector3(0, 0.14, 0.35), Vector3(3.8, 0.12, 4.1), _mat(deck, false), false, body)
	for x in [-1.8, 1.8]:
		for z in [-1.6, 2.3]:
			_box_part(Vector3(x, 0.05, z), Vector3(0.16, 0.2, 0.16), _mat(deck.darkened(0.3), false), false, body)
	for k in 12:
		_box_part(Vector3(-1.85 + k * 0.335, 0.205, 0.35), Vector3(0.02, 0.01, 4.1), _mat(deck.darkened(0.2), false), false, body)
	# plank walls with white corner boards
	_box_part(Vector3(0, 1.4, 0), Vector3(3.2, 2.4, 3.0), _mat(planks), false, body)
	for k in 10:
		var shade := planks.darkened(rng.randf() * 0.12)
		_box_part(Vector3(-1.44 + k * 0.32, 1.4, 1.505), Vector3(0.3, 2.4, 0.02), _mat(shade), false, body)
		_box_part(Vector3(-1.44 + k * 0.32, 1.4, -1.505), Vector3(0.3, 2.4, 0.02), _mat(planks.darkened(rng.randf() * 0.12)), false, body)
	for k in 9:
		for x in [-1.605, 1.605]:
			_box_part(Vector3(x, 1.4, -1.28 + k * 0.32), Vector3(0.02, 2.4, 0.3), _mat(planks.darkened(rng.randf() * 0.12)), false, body)
	for x in [-1.6, 1.6]:
		for z in [-1.5, 1.5]:
			_box_part(Vector3(x, 1.4, z), Vector3(0.14, 2.45, 0.14), _mat(trim), false, body)
	# tin roof (ridge runs front to back) with a white fascia
	var roof := MeshInstance3D.new()
	var pr := PrismMesh.new()
	pr.size = Vector3(4.0, 1.0, 3.7)
	roof.mesh = pr
	roof.position.y = 3.1
	roof.material_override = _mat(Color(0.72, 0.36, 0.3))
	body.add_child(roof)
	_box_part(Vector3(0, 3.62, 0), Vector3(0.14, 0.1, 3.8), _mat(Color(0.55, 0.26, 0.22)), false, body)
	# front: a blue door with a porthole, a porthole window each side
	_box_part(Vector3(0, 1.1, 1.53), Vector3(1.05, 1.9, 0.05), _mat(trim), false, body)
	_box_part(Vector3(0, 1.08, 1.56), Vector3(0.88, 1.8, 0.05), _mat(Color(0.2, 0.4, 0.6)), false, body)
	_box_part(Vector3(0.3, 1.05, 1.6), Vector3(0.08, 0.08, 0.04), _mat(Color(0.9, 0.75, 0.3)), false, body)
	for px in [-1.05, 1.05, 0.0]:
		var py := 1.75 if px != 0.0 else 1.55
		var ring := MeshInstance3D.new()
		var tr := TorusMesh.new()
		tr.inner_radius = 0.17 if px != 0.0 else 0.12
		tr.outer_radius = 0.24 if px != 0.0 else 0.17
		ring.mesh = tr
		ring.rotation.x = PI / 2
		ring.position = Vector3(px, py, 1.58)
		ring.material_override = _mat(Color(0.85, 0.7, 0.35))
		body.add_child(ring)
		var glass := _box_part(Vector3(px, py, 1.57), Vector3(0.3 if px != 0.0 else 0.2, 0.3 if px != 0.0 else 0.2, 0.02), _glow_mat(0.5), false, body)
		glass.rotation.z = PI / 4
	# the big sign over the door, with a wooden fish on top
	_box_part(Vector3(0, 2.44, 1.62), Vector3(2.8, 0.44, 0.08), _mat(Color(0.16, 0.36, 0.55)), false, body)
	_box_part(Vector3(0, 2.44, 1.6), Vector3(2.92, 0.54, 0.05), _mat(trim), false, body)
	var hut_sign := Label3D.new()
	hut_sign.text = "Sal's Bait & Tackle"
	hut_sign.position = Vector3(0, 2.44, 1.67)
	hut_sign.font_size = 40
	hut_sign.pixel_size = 0.0045
	hut_sign.outline_size = 8
	hut_sign.outline_modulate = Color(0.08, 0.18, 0.3)
	hut_sign.modulate = Color(1, 0.95, 0.8)
	body.add_child(hut_sign)
	var fish := MeshInstance3D.new()
	var fsph := SphereMesh.new()
	fsph.radius = 0.2
	fsph.height = 0.4
	fish.mesh = fsph
	fish.scale = Vector3(2.2, 0.8, 0.3)
	fish.position = Vector3(-0.1, 2.95, 1.92)
	fish.material_override = _mat(Color(1, 0.6, 0.25))
	body.add_child(fish)
	var tail := MeshInstance3D.new()
	var tp := PrismMesh.new()
	tp.size = Vector3(0.35, 0.3, 0.06)
	tail.mesh = tp
	tail.rotation.z = PI / 2
	tail.position = Vector3(0.52, 2.95, 1.92)
	tail.material_override = _mat(Color(0.95, 0.5, 0.2))
	body.add_child(tail)
	var eye := MeshInstance3D.new()
	var es := SphereMesh.new()
	es.radius = 0.04
	es.height = 0.08
	eye.mesh = es
	eye.position = Vector3(-0.42, 3.0, 1.98)
	eye.material_override = _mat(Color(0.1, 0.1, 0.1))
	body.add_child(eye)
	# porch awning on two posts, strung with buoys
	for x in [-1.75, 1.75]:
		_box_part(Vector3(x, 1.1, 2.3), Vector3(0.12, 2.0, 0.12), _mat(trim), false, body)
	var awning := _box_part(Vector3(0, 2.12, 1.95), Vector3(3.9, 0.07, 1.0), _mat(Color(0.95, 0.95, 0.92)), false, body)
	awning.rotation.x = 0.18
	for k in 5:
		_box_part(Vector3(-1.56 + k * 0.78, 2.08, 1.95), Vector3(0.39, 0.075, 1.0), _mat(Color(0.2, 0.45, 0.65)), false, body).rotation.x = 0.18
	for k in 9:
		var buoy := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = 0.09
		bs.height = 0.18
		buoy.mesh = bs
		var t := k / 8.0
		buoy.position = Vector3(lerpf(-1.7, 1.7, t), 1.95 - 0.12 * 4.0 * t * (1.0 - t), 2.42)
		buoy.material_override = _mat(Color(0.95, 0.3, 0.25) if k % 2 == 0 else Color(0.97, 0.97, 0.95))
		body.add_child(buoy)
	# fishing net and a life ring on the front wall
	var net := _box_part(Vector3(1.05, 1.1, 1.54), Vector3(0.6, 0.8, 0.02), _mat(Color(0.8, 0.75, 0.6)), false, body)
	net.rotation.z = 0.08
	for k in 4:
		_box_part(Vector3(0.8 + k * 0.17, 1.1, 1.56), Vector3(0.015, 0.8, 0.015), _mat(Color(0.55, 0.5, 0.4)), false, body)
		_box_part(Vector3(1.05, 0.78 + k * 0.2, 1.56), Vector3(0.6, 0.015, 0.015), _mat(Color(0.55, 0.5, 0.4)), false, body)
	var life := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.18
	torus.outer_radius = 0.3
	life.mesh = torus
	life.rotation.x = PI / 2
	life.position = Vector3(-1.05, 1.05, 1.58)
	life.material_override = _mat(Color(0.95, 0.35, 0.25))
	body.add_child(life)
	for k in 4:
		var stripe := _box_part(Vector3(-1.05, 1.05, 1.6) + Vector3(cos(k * PI / 2), sin(k * PI / 2), 0) * 0.24, Vector3(0.1, 0.1, 0.08), _mat(Color(0.97, 0.97, 0.95)), false, body)
		stripe.rotation.z = k * PI / 2
	# crates of fish and a barrel of fishing rods on the porch
	for cx in [-1.35, -0.9]:
		_box_part(Vector3(cx, 0.43, 2.05 + (0.0 if cx < -1.0 else 0.15)), Vector3(0.44, 0.44, 0.44), _mat(Color(0.6, 0.45, 0.28), false), false, body)
		for k in 3:
			var f2 := MeshInstance3D.new()
			var s2 := SphereMesh.new()
			s2.radius = 0.06
			s2.height = 0.12
			f2.mesh = s2
			f2.scale = Vector3(2.0, 0.8, 0.8)
			f2.position = Vector3(cx - 0.1 + k * 0.1, 0.68, 2.05 + (0.0 if cx < -1.0 else 0.15) - 0.08 + k * 0.08)
			f2.material_override = _mat([Color(0.7, 0.8, 0.9), Color(0.4, 0.6, 0.75), Color(0.95, 0.75, 0.4)][k], false)
			body.add_child(f2)
	var barrel := MeshInstance3D.new()
	var bcyl := CylinderMesh.new()
	bcyl.top_radius = 0.24
	bcyl.bottom_radius = 0.24
	bcyl.height = 0.6
	barrel.mesh = bcyl
	barrel.position = Vector3(1.35, 0.5, 2.1)
	barrel.material_override = _mat(Color(0.5, 0.34, 0.2), false)
	body.add_child(barrel)
	for k in 3:
		var rod := _box_part(Vector3(1.3 + k * 0.06, 1.3, 2.1), Vector3(0.025, 1.4, 0.025), _mat(Color(0.3, 0.22, 0.15)), false, body)
		rod.rotation.z = -0.15 + k * 0.12
	# a lantern beside the door (lights up at night)
	_box_part(Vector3(-0.75, 1.95, 1.62), Vector3(0.18, 0.24, 0.18), _glow_mat(1.6), false, body)
	var lantern := OmniLight3D.new()
	lantern.position = Vector3(-0.75, 1.9, 1.9)
	lantern.light_color = Color(1, 0.8, 0.5)
	lantern.omni_range = 5.0
	body.add_child(lantern)
	lamps.append(lantern)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.2, 2.4, 3.0)
	col.shape = shape
	col.position.y = 1.2
	body.add_child(col)
	add_child(body)
	landmarks.append({"name": "Sal's hut", "pos": pos, "radius": 2.4})


## The hat you bought at the market (or none).
func _apply_player_hat() -> void:
	player.visual.set_accessory(Game.player_hat)


## Where villagers gather in the evening (Vector3.INF until it's built).
func bandstand_spot() -> Vector3:
	return activities.bandstand_spot() if activities else Vector3.INF


## Quest minigames (baking, memory): pause the world while they run.
func start_minigame(npc: CharacterBody3D, kind: String) -> void:
	play_minigame(kind, func(success): npc.minigame_finished(success))


## Runs any screen minigame (baking, memory, harvest, crabs) with the world
## paused, then calls done(result). extra = crop name for the harvest game.
func play_minigame(kind: String, done: Callable, extra := "") -> void:
	player.busy = true
	Game.time_running = false
	menus.can_pause = false
	hud.show_prompt("")
	minigames.harvest_crop = extra
	if kind == "music":
		Audio.duck_music(true)
	minigames.start(kind, func(result):
		if kind == "music":
			Audio.duck_music(false)
		player.busy = false
		Game.time_running = true
		menus.can_pause = true
		done.call(result)
		update_quest_log()
		hud.update_inventory())


## Otto's metal detector: while you're hunting his buried coins, a bar shows
## how close the nearest one is, and it beeps faster as you get closer.
func _update_detector(delta: float) -> void:
	var buried: Array = pickups.get("coin", []).filter(func(p): return is_instance_valid(p) and p.buried and not p.digging)
	if buried.is_empty() or player.busy or interiors.current != "":
		hud.hide_detector()
		return
	var best := INF
	for p in buried:
		best = min(best, p.distance_to_player(player))
	var strength: float = clamp(1.0 - best / 16.0, 0.0, 1.0)
	hud.show_detector(strength)
	if strength > 0.05:
		beep_timer -= delta
		if beep_timer <= 0.0:
			beep_timer = lerpf(1.3, 0.1, strength)
			Audio.play("beep", 0.0, lerpf(-14.0, -2.0, strength))


## Street lamps go beside the paths (never on them): a pair along each path,
## on alternating sides, plus a few around the well.
func _place_lamps() -> void:
	var spots := []
	for dest in path_dests:
		var d: Vector3 = dest
		var dir := d.normalized()
		var side := Vector3(-dir.z, 0, dir.x)
		for k in 2:
			var t := 0.35 if k == 0 else 0.72
			var p := d * t + side * (1.7 if k == 0 else -1.7)
			spots.append(p)
	for deg in [26.0, 160.0, 247.5, 337.0]:
		var a := deg_to_rad(deg)
		spots.append(Vector3(cos(a), 0, sin(a)) * (PLAZA_RADIUS + 0.35))   # lamps around the edge of the square
	var placed := []
	for p in spots:
		var ok: bool = _dist_to_paths(p) > 1.25 and is_clear(p, 0.6, true) and not activities.on_race_course(p, 1.3)
		for q in placed:
			if p.distance_to(q) < 5.0:
				ok = false
		if ok:
			_add_lamp(p)
			placed.append(p)
			landmarks.append({"name": "", "pos": p, "radius": 0.3})


## The farm: dirt bed, post-and-rail fence with a gate, tool shed,
## scarecrow, hay bales and a water barrel. (The tiles themselves are made in
## _build_farm once the game state exists.)
func _build_farm_area() -> void:
	var fx := FARM_COLS * FARM_SPACING + 2.4     # fence width
	var fz := FARM_ROWS * FARM_SPACING + 2.4     # fence depth
	var c := FARM_CENTER
	var wood := _mat(Color(0.55, 0.38, 0.22))
	var dark_wood := _mat(Color(0.42, 0.28, 0.16))

	var bed := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(FARM_COLS * FARM_SPACING + 0.6, 0.03, FARM_ROWS * FARM_SPACING + 0.6)
	bed.mesh = bb
	bed.position = c + Vector3(0, 0.012, 0)
	bed.material_override = _mat(Color(0.4, 0.29, 0.18), false)
	add_child(bed)

	# Fence: four sides, with a 2.2 m gate near the village end of the north side
	var gate_x := fx / 2 - 1.6          # gate center, measured from the farm center
	var sides := [
		[Vector3(-fx / 2, 0, -fz / 2), Vector3(fx / 2, 0, -fz / 2)],   # north (has the gate)
		[Vector3(fx / 2, 0, -fz / 2), Vector3(fx / 2, 0, fz / 2)],     # east
		[Vector3(fx / 2, 0, fz / 2), Vector3(-fx / 2, 0, fz / 2)],     # south
		[Vector3(-fx / 2, 0, fz / 2), Vector3(-fx / 2, 0, -fz / 2)],   # west
	]
	for i in sides.size():
		var a: Vector3 = sides[i][0]
		var b: Vector3 = sides[i][1]
		if i == 0:
			_fence_run(c + a, c + Vector3(gate_x - 1.1, 0, -fz / 2), wood, dark_wood)
			_fence_run(c + Vector3(gate_x + 1.1, 0, -fz / 2), c + b, wood, dark_wood)
		else:
			_fence_run(c + a, c + b, wood, dark_wood)

	# keep the way to the gate open (no trees or rocks in front of it)
	landmarks.append({"name": "", "pos": c + Vector3(gate_x, 0, -fz / 2 - 1.8), "radius": 2.0})
	# A wooden arch over the gate with a little hanging sign
	var gc := c + Vector3(gate_x, 0, -fz / 2)
	for x in [-1.25, 1.25]:
		_box_part(gc + Vector3(x, 1.35, 0), Vector3(0.18, 2.7, 0.18), dark_wood, false)
		_box_part(gc + Vector3(x, 2.72, 0), Vector3(0.26, 0.08, 0.26), dark_wood, false)
		# a climbing vine with flowers on each post
		for k in 5:
			var leaf := MeshInstance3D.new()
			var ls := SphereMesh.new()
			ls.radius = 0.12
			ls.height = 0.2
			leaf.mesh = ls
			leaf.position = gc + Vector3(x + (0.1 if k % 2 == 0 else -0.1), 0.4 + k * 0.45, -0.1)
			leaf.material_override = _mat(Color(0.3, 0.55, 0.25), false)
			add_child(leaf)
			if k % 2 == 1:
				var fl := MeshInstance3D.new()
				var fs := SphereMesh.new()
				fs.radius = 0.06
				fs.height = 0.12
				fl.mesh = fs
				fl.position = leaf.position + Vector3(0, 0.06, -0.1)
				fl.material_override = _mat(Color(1, 0.55, 0.7), false)
				add_child(fl)
	_box_part(gc + Vector3(0, 2.62, 0), Vector3(2.9, 0.16, 0.2), wood, false)
	_box_part(gc + Vector3(0, 2.45, 0), Vector3(2.5, 0.08, 0.12), dark_wood, false)
	for x in [-0.45, 0.45]:
		_box_part(gc + Vector3(x, 2.3, 0), Vector3(0.025, 0.24, 0.025), _mat(Color(0.3, 0.3, 0.3)), false)
	_box_part(gc + Vector3(0, 2.04, 0), Vector3(1.2, 0.34, 0.06), _mat(Color(0.72, 0.55, 0.34)), false)
	for side in [-1.0, 1.0]:
		var farm_label := Label3D.new()
		farm_label.text = "FARM"
		farm_label.font_size = 44
		farm_label.pixel_size = 0.005
		farm_label.modulate = Color(0.3, 0.18, 0.06)
		farm_label.outline_size = 0
		farm_label.position = gc + Vector3(0, 2.04, side * 0.035)
		farm_label.rotation.y = 0.0 if side > 0 else PI
		add_child(farm_label)
		# painted wheat either side of the word
		for wx in [-0.45, 0.45]:
			for k in 3:
				var st := _box_part(gc + Vector3(wx + (k - 1) * 0.04, 2.04, side * 0.036), Vector3(0.02, 0.2, 0.005), _mat(Color(0.85, 0.65, 0.2), false), false)
				st.rotation.z = (k - 1) * 0.3

	# Scarecrow in the corner
	var sc := c + Vector3(fx / 2 - 0.6, 0, fz / 2 - 0.6)
	_box_part(sc + Vector3(0, 0.9, 0), Vector3(0.08, 1.8, 0.08), dark_wood, false)
	_box_part(sc + Vector3(0, 1.35, 0), Vector3(1.2, 0.07, 0.07), dark_wood, false)
	_box_part(sc + Vector3(0, 1.2, 0), Vector3(0.45, 0.5, 0.25), _mat(Color(0.35, 0.5, 0.75)), false)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.2
	hs.height = 0.4
	head.mesh = hs
	head.position = sc + Vector3(0, 1.7, 0)
	head.material_override = _mat(Color(0.9, 0.8, 0.5))
	add_child(head)
	var brim := MeshInstance3D.new()
	var bcyl := CylinderMesh.new()
	bcyl.top_radius = 0.18
	bcyl.bottom_radius = 0.4
	bcyl.height = 0.18
	brim.mesh = bcyl
	brim.position = sc + Vector3(0, 1.92, 0)
	brim.material_override = _mat(Color(0.85, 0.7, 0.35))
	add_child(brim)

	# Tool shed on the west side
	var shed_pos := c + Vector3(-fx / 2 - 2.2, 0, 0.5)
	var shed := StaticBody3D.new()
	shed.position = shed_pos
	shed.rotation.y = PI / 2
	var walls := _box_part(Vector3(0, 1.1, 0), Vector3(2.6, 2.2, 2.2), _mat(Color(0.62, 0.42, 0.28)), false, shed)
	var roof := MeshInstance3D.new()
	var pr := PrismMesh.new()
	pr.size = Vector3(3.0, 0.9, 2.6)
	roof.mesh = pr
	roof.position = Vector3(0, 2.65, 0)
	roof.material_override = _mat(Color(0.35, 0.4, 0.45))
	shed.add_child(roof)
	_box_part(Vector3(0, 0.8, 1.11), Vector3(0.9, 1.6, 0.05), dark_wood, false, shed)
	var sc_col := CollisionShape3D.new()
	var sbox := BoxShape3D.new()
	sbox.size = Vector3(2.6, 2.2, 2.2)
	sc_col.shape = sbox
	sc_col.position.y = 1.1
	shed.add_child(sc_col)
	add_child(shed)
	walls.name = "ShedWalls"

	# Hay bales and a water barrel
	var hay := _mat(Color(0.9, 0.78, 0.4))
	for hp in [shed_pos + Vector3(0.3, 0.35, 2.0), shed_pos + Vector3(-0.6, 0.35, 2.3), shed_pos + Vector3(-0.15, 1.0, 2.15)]:
		var bale := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.4
		cyl.bottom_radius = 0.4
		cyl.height = 0.8
		bale.mesh = cyl
		bale.rotation.z = PI / 2
		bale.position = hp
		bale.material_override = hay
		add_child(bale)
	var barrel_pos := c + Vector3(gate_x - 1.7, 0, -fz / 2 + 0.6)
	var barrel := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.35
	bc.bottom_radius = 0.3
	bc.height = 0.8
	bc.radial_segments = 10
	barrel.mesh = bc
	barrel.position = barrel_pos + Vector3(0, 0.4, 0)
	barrel.material_override = dark_wood
	add_child(barrel)
	_box_part(barrel_pos + Vector3(0, 0.79, 0), Vector3(0.5, 0.02, 0.5), _mat(Color(0.3, 0.5, 0.8)), false)

	landmarks.append({"name": "your farm", "pos": c, "radius": max(fx, fz) / 2 + 0.3})
	landmarks.append({"name": "your farm", "pos": shed_pos, "radius": 1.8})


## One straight run of post-and-rail fence (with collision).
func _fence_run(a: Vector3, b: Vector3, wood: Material, post_wood: Material) -> void:
	var d := b - a
	var length := d.length()
	var posts := int(ceil(length / 1.3))
	for i in posts + 1:
		_box_part(a + d * (float(i) / posts) + Vector3(0, 0.45, 0), Vector3(0.12, 0.9, 0.12), post_wood, false)
	var mid := (a + b) / 2
	var body := StaticBody3D.new()
	body.position = mid
	body.rotation.y = atan2(d.x, d.z)
	for h in [0.35, 0.72]:
		_box_part(Vector3(0, h, 0), Vector3(0.06, 0.1, length), wood, false, body)
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 1.0, length)
	col.shape = box
	col.position.y = 0.5
	body.add_child(col)
	add_child(body)


func _box_part(pos: Vector3, size: Vector3, mat: Material, _unused := false, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	(parent if parent else self).add_child(mi)
	return mi


func _build_farm() -> void:
	for r in FARM_ROWS:
		for c in FARM_COLS:
			var t := Node3D.new()
			t.set_script(TILE_SCRIPT)
			t.index = r * FARM_COLS + c
			t.game_world = self
			t.position = FARM_CENTER + Vector3((c - (FARM_COLS - 1) * 0.5) * FARM_SPACING, 0, (r - (FARM_ROWS - 1) * 0.5) * FARM_SPACING)
			add_child(t)
			tiles.append(t)



## Where the bobber lands when fishing in the pond: a couple of meters in from the edge.
func _pond_cast_target(p: Node3D) -> Vector3:
	var to_center := POND_CENTER - p.global_position
	to_center.y = 0
	var dist_to_edge := to_center.length() - POND_RADIUS
	var target := p.global_position + to_center.normalized() * (dist_to_edge + 2.2)
	target.y = 0.05
	return target


func _add_pond() -> void:
	var water := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = POND_RADIUS
	cyl.bottom_radius = POND_RADIUS
	cyl.height = 0.1
	cyl.radial_segments = 48
	water.mesh = cyl
	water.position = POND_CENTER + Vector3(0, 0.02, 0)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.2, 0.45, 0.75)
	wm.metallic = 0.3
	wm.roughness = 0.1
	water.material_override = wm
	add_child(water)
	var shore := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = POND_RADIUS + 0.8
	sc.bottom_radius = POND_RADIUS + 0.8
	sc.height = 0.06
	sc.radial_segments = 48
	shore.mesh = sc
	shore.position = POND_CENTER + Vector3(0, 0.01, 0)
	shore.material_override = _mat(Color(0.75, 0.68, 0.5), false)
	add_child(shore)
	# Lily pads and reeds
	for i in 7:
		var a := randf() * TAU
		var pad := MeshInstance3D.new()
		var pc := CylinderMesh.new()
		pc.top_radius = randf_range(0.3, 0.5)
		pc.bottom_radius = pc.top_radius
		pc.height = 0.02
		pad.mesh = pc
		pad.position = POND_CENTER + Vector3(cos(a), 0, sin(a)) * randf_range(1.5, POND_RADIUS - 1.0) + Vector3(0, 0.08, 0)
		pad.material_override = _mat(Color(0.3, 0.6, 0.25))
		add_child(pad)
	for i in 12:
		var a := randf() * TAU
		var reed := MeshInstance3D.new()
		var rb := BoxMesh.new()
		rb.size = Vector3(0.06, randf_range(0.7, 1.2), 0.06)
		reed.mesh = rb
		reed.position = POND_CENTER + Vector3(cos(a), 0, sin(a)) * (POND_RADIUS + 0.5) + Vector3(0, rb.size.y / 2, 0)
		reed.rotation.z = randf_range(-0.2, 0.2)
		reed.material_override = _mat(Color(0.35, 0.55, 0.2))
		add_child(reed)
	# You can't walk into the water
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = POND_RADIUS - 0.3
	shape.height = 2.0
	col.shape = shape
	body.add_child(col)
	body.position = POND_CENTER + Vector3(0, 1, 0)
	add_child(body)
	var pond_spot := _spot(POND_CENTER, 1.4,
		func(_p): return "" if fishing.is_active() else "E: Fish",
		func(p): fishing.start(p, _pond_cast_target(p), "pond", false))
	pond_spot.ring_radius = POND_RADIUS
	landmarks.append({"name": "the pond", "pos": POND_CENTER, "radius": POND_RADIUS + 0.5})


func _add_market() -> void:
	var body := StaticBody3D.new()
	body.position = MARKET_POS
	var wood := _mat(Color(0.55, 0.38, 0.22))
	var counter := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(4.0, 1.1, 1.2)
	counter.mesh = cb
	counter.position = Vector3(0, 0.55, 0.6)
	counter.material_override = wood
	body.add_child(counter)
	for x in [-1.9, 1.9]:
		var post := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.15, 2.8, 0.15)
		post.mesh = pb
		post.position = Vector3(x, 1.4, 1.1)
		post.material_override = wood
		body.add_child(post)
	# Striped awning
	for i in 6:
		var stripe := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(4.4 / 6.0, 0.08, 2.0)
		stripe.mesh = sb
		stripe.position = Vector3(-2.2 + (i + 0.5) * 4.4 / 6.0, 2.85, 0.6)
		stripe.rotation.x = 0.25
		stripe.material_override = _mat(Color(0.9, 0.25, 0.2) if i % 2 == 0 else Color(0.95, 0.92, 0.85))
		body.add_child(stripe)
	# Goods on the counter
	var goods := [Color(1, 0.55, 0.05), Color(0.95, 0.8, 0.3), Color(0.55, 0.7, 0.8), Color(1, 0.5, 0.1)]
	for i in goods.size():
		var g := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.2
		s.height = 0.35
		g.mesh = s
		g.position = Vector3(-1.3 + i * 0.85, 1.25, 0.6)
		g.material_override = _mat(goods[i])
		body.add_child(g)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4.0, 1.1, 1.2)
	col.shape = shape
	col.position = Vector3(0, 0.55, 0.6)
	body.add_child(col)
	var market_sign := Label3D.new()
	market_sign.text = "MARKET"
	market_sign.font_size = 96
	market_sign.pixel_size = 0.006
	market_sign.outline_size = 16
	market_sign.modulate = Color(1, 0.9, 0.5)
	market_sign.position = Vector3(0, 3.5, 1.2)
	market_sign.visibility_range_begin = 7.0
	body.add_child(market_sign)
	add_child(body)
	_spot(MARKET_POS + Vector3(0, 0, 2.0), 2.2,
		func(_p): return "E: Open the market (buy seeds, sell fish & crops)",
		open_shop)
	landmarks.append({"name": "the market", "pos": MARKET_POS, "radius": 2.5})


func _spot(pos: Vector3, r: float, prompt_f: Callable, action_f: Callable) -> Node3D:
	var s := Node3D.new()
	s.set_script(SPOT_SCRIPT)
	s.position = pos
	s.interact_range = r
	s.prompt_func = prompt_f
	s.action_func = action_f
	add_child(s)
	return s


func _add_path(from: Vector3, to: Vector3) -> void:
	var d := to - from
	d.y = 0
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(1.6, 0.02, d.length())
	m.mesh = b
	m.position = from + d * 0.5 + Vector3(0, 0.005, 0)
	m.rotation.y = atan2(d.x, d.z)
	m.material_override = _mat(Color(0.6, 0.5, 0.35), false)
	add_child(m)


func _add_house(pos: Vector3, sign_text: String, lm_name: String, wall_color: Color) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	# Face the house toward the middle of the village
	body.rotation.y = atan2(-pos.x, -pos.z)
	var timber := Color(0.36, 0.24, 0.15)
	var stone := Color(0.55, 0.53, 0.5)
	var roof_color := Color.from_hsv(wall_color.h, 0.45, 0.55).lerp(Color(0.55, 0.25, 0.2), 0.45)
	var accent := Color.from_hsv(fmod(wall_color.h + 0.5, 1.0), 0.45, 0.6)
	# stone base, plaster walls, timber corners and a belt beam
	_box_part(Vector3(0, 0.2, 0), Vector3(4.3, 0.4, 4.3), _mat(stone), false, body)
	_box_part(Vector3(0, 1.65, 0), Vector3(4, 2.5, 4), _mat(wall_color), false, body)
	for x in [-2.0, 2.0]:
		for z in [-2.0, 2.0]:
			_box_part(Vector3(x, 1.65, z), Vector3(0.22, 2.5, 0.22), _mat(timber), false, body)
	for z in [-2.02, 2.02]:
		_box_part(Vector3(0, 2.85, z), Vector3(4.1, 0.16, 0.08), _mat(timber), false, body)
	for x in [-2.02, 2.02]:
		_box_part(Vector3(x, 2.85, 0), Vector3(0.08, 0.16, 4.1), _mat(timber), false, body)
	# roof with an overhang, a ridge beam and gable trim
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(4.9, 1.9, 4.9)
	roof.mesh = prism
	roof.position.y = 3.85
	roof.material_override = _mat(roof_color)
	body.add_child(roof)
	_box_part(Vector3(0, 4.82, 0), Vector3(0.18, 0.14, 5.0), _mat(roof_color.darkened(0.3)), false, body)
	var gable := MeshInstance3D.new()
	var gp := PrismMesh.new()
	gp.size = Vector3(4.0, 1.7, 0.05)
	gable.mesh = gp
	gable.position = Vector3(0, 3.75, 2.03)
	gable.material_override = _mat(wall_color.lightened(0.08))
	body.add_child(gable)
	# round attic window in the gable
	var attic := MeshInstance3D.new()
	var ac := CylinderMesh.new()
	ac.top_radius = 0.28
	ac.bottom_radius = 0.28
	ac.height = 0.05
	attic.mesh = ac
	attic.rotation.x = PI / 2
	attic.position = Vector3(0, 3.65, 2.06)
	attic.material_override = _glow_mat(0.5)
	body.add_child(attic)
	# chimney with a little smoke
	_box_part(Vector3(1.2, 4.6, -0.9), Vector3(0.5, 1.4, 0.5), _mat(stone.darkened(0.1)), false, body)
	_box_part(Vector3(1.2, 5.33, -0.9), Vector3(0.62, 0.1, 0.62), _mat(stone.darkened(0.25)), false, body)
	var smoke := CPUParticles3D.new()
	smoke.position = Vector3(1.2, 5.5, -0.9)
	smoke.amount = 10
	smoke.lifetime = 3.0
	smoke.direction = Vector3.UP
	smoke.spread = 12.0
	smoke.initial_velocity_min = 0.4
	smoke.initial_velocity_max = 0.7
	smoke.gravity = Vector3(0.15, 0.05, 0)
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.2
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.36
	var smm := StandardMaterial3D.new()
	smm.albedo_color = Color(0.85, 0.85, 0.85, 0.35)
	smm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = smm
	smoke.mesh = sm
	body.add_child(smoke)
	# front door with a frame, a little roof over it, a step and a lantern
	_box_part(Vector3(0, 1.3, 2.02), Vector3(1.25, 2.05, 0.06), _mat(timber), false, body)
	_box_part(Vector3(0, 1.25, 2.06), Vector3(1.0, 1.85, 0.06), _mat(Color(0.45, 0.28, 0.17)), false, body)
	_box_part(Vector3(0.32, 1.2, 2.1), Vector3(0.07, 0.07, 0.05), _mat(Color(1, 0.84, 0.3)), false, body)
	var awning := MeshInstance3D.new()
	var awp := PrismMesh.new()
	awp.size = Vector3(1.6, 0.4, 0.8)
	awning.mesh = awp
	awning.position = Vector3(0, 2.52, 2.35)
	awning.material_override = _mat(roof_color)
	body.add_child(awning)
	_box_part(Vector3(0, 0.12, 2.5), Vector3(1.5, 0.24, 0.7), _mat(stone.lightened(0.1)), false, body)
	var lantern := _box_part(Vector3(0.85, 2.05, 2.12), Vector3(0.16, 0.24, 0.16), _glow_mat(1.2), false, body)
	lantern.name = "DoorLantern"
	# windows: front pair plus one on each side, with frames, shutters and flower boxes
	var flowers := [Color(1, 0.45, 0.6), Color(1, 0.85, 0.3), Color(0.65, 0.55, 1), Color(1, 1, 1)]
	var wins := [[Vector3(-1.3, 1.8, 2.03), 0.0], [Vector3(1.3, 1.8, 2.03), 0.0], [Vector3(2.03, 1.8, 0.2), PI / 2], [Vector3(-2.03, 1.8, 0.2), -PI / 2]]
	for w in wins:
		var holder := Node3D.new()
		holder.position = w[0]
		holder.rotation.y = w[1]
		body.add_child(holder)
		_box_part(Vector3(0, 0, 0), Vector3(0.8, 0.8, 0.05), _mat(timber), false, holder)
		_box_part(Vector3(0, 0, 0.03), Vector3(0.66, 0.66, 0.03), _glow_mat(0.8), false, holder)
		_box_part(Vector3(0, 0, 0.05), Vector3(0.05, 0.66, 0.02), _mat(timber), false, holder)
		_box_part(Vector3(0, 0, 0.05), Vector3(0.66, 0.05, 0.02), _mat(timber), false, holder)
		for sx in [-0.55, 0.55]:
			_box_part(Vector3(sx, 0, 0.03), Vector3(0.28, 0.82, 0.04), _mat(accent), false, holder)
		_box_part(Vector3(0, -0.5, 0.12), Vector3(0.85, 0.18, 0.22), _mat(timber.lightened(0.15)), false, holder)
		for k in 5:
			var f := _box_part(Vector3(-0.32 + k * 0.16, -0.36, 0.12), Vector3(0.11, 0.11, 0.11), _mat(flowers[k % 4]), false, holder)
			f.rotation.y = k
	var house_sign := Label3D.new()
	house_sign.text = sign_text
	house_sign.position = Vector3(0, 3.05, 2.1)
	house_sign.font_size = 52
	house_sign.pixel_size = 0.006
	house_sign.outline_size = 12
	house_sign.visibility_range_begin = 7.0   # hide when the camera is right up against the house
	body.add_child(house_sign)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 3, 4)
	col.shape = shape
	col.position.y = 1.5
	body.add_child(col)
	add_child(body)
	landmarks.append({"name": lm_name, "pos": pos, "radius": 3.0})


## Warm window glass that glows a little (more at night, via the lamps).
func _glow_mat(energy: float) -> StandardMaterial3D:
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(1, 0.85, 0.5)
	wm.emission_enabled = true
	wm.emission = Color(1, 0.75, 0.4)
	wm.emission_energy_multiplier = energy
	wm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	wm.distance_fade_min_distance = 3.5
	wm.distance_fade_max_distance = 7.5
	return wm


## A round cobbled square around the well, with a stone curb.
func _add_plaza() -> void:
	var cobble := BoxMesh.new()
	cobble.size = Vector3(0.42, 0.04, 0.42)
	var cm := StandardMaterial3D.new()
	cm.vertex_color_use_as_albedo = true
	cm.vertex_color_is_srgb = true
	cobble.material = cm
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cobble
	var xforms := []
	var cols := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var r := 1.35
	while r < PLAZA_RADIUS:
		var n := int(TAU * r / 0.47)
		var off := rng.randf() * TAU
		for i in n:
			var a := off + TAU * i / n
			var b := Basis(Vector3.UP, -a + rng.randf_range(-0.08, 0.08))
			xforms.append(Transform3D(b, Vector3(cos(a) * r, 0.02, sin(a) * r)))
			cols.append(Color(0.68, 0.64, 0.58).lerp(Color(0.8, 0.76, 0.68), rng.randf()).darkened(rng.randf() * 0.12))
		r += 0.46
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, cols[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# mortar underneath and a raised curb around the edge (gaps where the paths come in)
	var base := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = PLAZA_RADIUS + 0.2
	bc.bottom_radius = PLAZA_RADIUS + 0.2
	bc.height = 0.02
	bc.radial_segments = 48
	base.mesh = bc
	base.position.y = 0.006
	base.material_override = _mat(Color(0.52, 0.49, 0.44), false)
	add_child(base)
	var curb := BoxMesh.new()
	curb.size = Vector3(0.62, 0.12, 0.25)
	var steps := 64
	for i in steps:
		var a := TAU * i / steps
		var p := Vector3(cos(a), 0, sin(a)) * (PLAZA_RADIUS + 0.12)
		if _dist_to_paths(p) < 1.0:
			continue
		var c := MeshInstance3D.new()
		c.mesh = curb
		c.position = p + Vector3(0, 0.06, 0)
		c.rotation.y = -a + PI / 2
		c.material_override = _mat(Color(0.58, 0.56, 0.52), false)
		add_child(c)


## The old stone well in the middle of the square: a ring of stone blocks with
## a capstone rim, a wooden frame with a shingled roof, a crank, a rope and a
## bucket (plus a spare bucket and a couple of flower pots beside it).
## Small things only need to fade when the camera is right on top of them.
func _near_fade(m: StandardMaterial3D) -> StandardMaterial3D:
	m.distance_fade_min_distance = 1.2
	m.distance_fade_max_distance = 2.6
	return m


func _add_well(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var n := 16
	for course in 3:
		for i in n:
			var a := TAU * (i + 0.5 * (course % 2)) / n
			var blk := _box_part(Vector3(cos(a), 0, sin(a)) * 0.92 + Vector3(0, 0.14 + course * 0.26, 0), Vector3(0.36, 0.25, 0.3),
				_mat(Color(0.6, 0.58, 0.55).darkened(rng.randf() * 0.18).lerp(Color(0.62, 0.55, 0.45), rng.randf() * 0.3), false), false, body)
			blk.rotation.y = -a + PI / 2
	for i in n:
		var a := TAU * i / n
		var cap := _box_part(Vector3(cos(a), 0, sin(a)) * 0.94 + Vector3(0, 0.84, 0), Vector3(0.4, 0.1, 0.42), _mat(Color(0.74, 0.72, 0.68), false), false, body)
		cap.rotation.y = -a + PI / 2
		if rng.randf() < 0.3:   # a little moss
			var moss := MeshInstance3D.new()
			var ms := SphereMesh.new()
			ms.radius = 0.1
			ms.height = 0.08
			moss.mesh = ms
			moss.position = Vector3(cos(a), 0, sin(a)) * 1.08 + Vector3(0, 0.1 + rng.randf() * 0.5, 0)
			moss.material_override = _mat(Color(0.3, 0.5, 0.25), false)
			body.add_child(moss)
	# the dark water down inside
	var shaft := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.78
	sc.bottom_radius = 0.78
	sc.height = 0.66
	shaft.mesh = sc
	shaft.position.y = 0.33
	shaft.material_override = _mat(Color(0.12, 0.2, 0.3), false)
	body.add_child(shaft)
	var water := MeshInstance3D.new()
	var wc := CylinderMesh.new()
	wc.top_radius = 0.76
	wc.bottom_radius = 0.76
	wc.height = 0.01
	water.mesh = wc
	water.position.y = 0.67
	var wm := _mat(Color(0.2, 0.42, 0.62), false)
	wm.roughness = 0.1
	wm.metallic = 0.3
	water.material_override = wm
	body.add_child(water)
	# timber frame, crank and roof (these fade when the camera is close)
	var timber := _near_fade(_mat(Color(0.42, 0.28, 0.16)))
	for x in [-0.95, 0.95]:
		_box_part(Vector3(x, 1.85, 0), Vector3(0.16, 2.1, 0.16), timber, false, body)
		_box_part(Vector3(x, 0.95, 0), Vector3(0.26, 0.14, 0.3), timber, false, body)
	var axle := MeshInstance3D.new()
	var ac := CylinderMesh.new()
	ac.top_radius = 0.07
	ac.bottom_radius = 0.07
	ac.height = 2.05
	axle.mesh = ac
	axle.rotation.z = PI / 2
	axle.position.y = 2.15
	axle.material_override = _near_fade(_mat(Color(0.5, 0.35, 0.2)))
	body.add_child(axle)
	var rope := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.top_radius = 0.1
	rc.bottom_radius = 0.1
	rc.height = 0.16
	rope.mesh = rc
	rope.rotation.z = PI / 2
	rope.position = Vector3(0, 2.15, 0)
	rope.material_override = _near_fade(_mat(Color(0.75, 0.65, 0.45)))
	body.add_child(rope)
	_box_part(Vector3(0, 1.72, 0.08), Vector3(0.025, 0.8, 0.025), _near_fade(_mat(Color(0.75, 0.65, 0.45))), false, body)
	# the crank handle on the side
	_box_part(Vector3(1.12, 2.15, 0), Vector3(0.1, 0.1, 0.1), timber, false, body)
	_box_part(Vector3(1.16, 2.0, 0.0), Vector3(0.06, 0.34, 0.06), timber, false, body)
	_box_part(Vector3(1.24, 1.85, 0.0), Vector3(0.2, 0.06, 0.06), timber, false, body)
	# the bucket hanging on the rope, and a spare one on the ground
	for bp in [Vector3(0, 1.2, 0.08), Vector3(1.35, 0.16, 0.7)]:
		var bucket := MeshInstance3D.new()
		var bc := CylinderMesh.new()
		bc.top_radius = 0.2
		bc.bottom_radius = 0.15
		bc.height = 0.3
		bucket.mesh = bc
		bucket.position = bp
		bucket.material_override = _mat(Color(0.55, 0.38, 0.22), false)
		body.add_child(bucket)
		for yy in [-0.08, 0.08]:
			var band := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.17 + yy * 0.1
			tm.outer_radius = 0.2 + yy * 0.1
			band.mesh = tm
			band.position = bp + Vector3(0, yy, 0)
			band.material_override = _mat(Color(0.3, 0.3, 0.32), false)
			body.add_child(band)
	# shingled roof along the axle, with a ridge
	var roof_mat := _near_fade(_mat(Color(0.55, 0.28, 0.2)))
	for side in [-1, 1]:
		for k in 3:
			var shingle := _box_part(Vector3(0, 2.95 - k * 0.17, side * (0.2 + k * 0.3)), Vector3(2.5, 0.06, 0.38), roof_mat, false, body)
			shingle.rotation.x = -side * 0.5
	_box_part(Vector3(0, 3.1, 0), Vector3(2.6, 0.1, 0.12), _near_fade(_mat(Color(0.4, 0.2, 0.15))), false, body)
	_box_part(Vector3(0, 2.72, 0), Vector3(2.1, 0.1, 0.1), timber, false, body)
	# flower pots by the well
	for fp in [Vector3(-1.3, 0, -0.6), Vector3(-1.1, 0, 0.9)]:
		var pot := MeshInstance3D.new()
		var pc := CylinderMesh.new()
		pc.top_radius = 0.2
		pc.bottom_radius = 0.15
		pc.height = 0.28
		pot.mesh = pc
		pot.position = fp + Vector3(0, 0.14, 0)
		pot.material_override = _mat(Color(0.72, 0.4, 0.26), false)
		body.add_child(pot)
		for k in 5:
			var fl := MeshInstance3D.new()
			var fs := SphereMesh.new()
			fs.radius = 0.07
			fs.height = 0.14
			fl.mesh = fs
			fl.position = fp + Vector3(cos(k * 1.26) * 0.1, 0.34 + (k % 2) * 0.05, sin(k * 1.26) * 0.1)
			fl.material_override = _mat([Color(1, 0.45, 0.6), Color(1, 0.85, 0.3), Color(0.7, 0.55, 1)][k % 3], false)
			body.add_child(fl)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.08
	shape.height = 1.0
	col.shape = shape
	col.position.y = 0.5
	body.add_child(col)
	add_child(body)
	landmarks.append({"name": "the well", "pos": pos, "radius": 1.5})


func _add_lamp(pos: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var post := MeshInstance3D.new()
	var pb := CylinderMesh.new()
	pb.top_radius = 0.07
	pb.bottom_radius = 0.1
	pb.height = 2.6
	post.mesh = pb
	post.position.y = 1.3
	post.material_override = _mat(Color(0.2, 0.2, 0.22))
	body.add_child(post)
	var bulb := MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(0.35, 0.4, 0.35)
	bulb.mesh = bb
	bulb.position.y = 2.75
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(1, 0.9, 0.6)
	bm.emission_enabled = true
	bm.emission = Color(1, 0.8, 0.45)
	bm.emission_energy_multiplier = 1.5
	bm.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	bm.distance_fade_min_distance = 3.5
	bm.distance_fade_max_distance = 7.5
	bulb.material_override = bm
	body.add_child(bulb)
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.8, 0.5)
	light.omni_range = 8.0
	light.position.y = 2.6
	body.add_child(light)
	lamps.append(light)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.15
	shape.height = 2.6
	col.shape = shape
	col.position.y = 1.3
	body.add_child(col)
	add_child(body)




## Lanterns and bunting around the well, shown once the festival starts.
## Distance from a point to the nearest dirt path's center line.
func _dist_to_paths(p: Vector3) -> float:
	var best := INF
	for dest in path_dests:
		var d: Vector3 = dest
		var t: float = clamp(p.dot(d) / d.length_squared(), 0.0, 1.0)
		best = min(best, Vector2(p.x - d.x * t, p.z - d.z * t).length())
	return best


func _build_festival_decor() -> void:
	festival_decor = Node3D.new()
	add_child(festival_decor)
	var colors := [Color(1, 0.3, 0.3), Color(1, 0.85, 0.2), Color(0.3, 0.7, 1), Color(0.5, 1, 0.4)]
	for i in 12:
		var a := TAU * i / 12.0
		var p := Vector3(cos(a) * 5.5, 0, sin(a) * 5.5)
		var pole := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.1, 3.0, 0.1)
		pole.mesh = pb
		pole.position = p + Vector3(0, 1.5, 0)
		pole.material_override = _mat(Color(0.5, 0.35, 0.2))
		festival_decor.add_child(pole)
		var lantern := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.25
		s.height = 0.45
		lantern.mesh = s
		lantern.position = p + Vector3(0, 3.1, 0)
		var lm := StandardMaterial3D.new()
		lm.albedo_color = colors[i % colors.size()]
		lm.emission_enabled = true
		lm.emission = colors[i % colors.size()]
		lm.emission_energy_multiplier = 1.2
		lantern.material_override = lm
		festival_decor.add_child(lantern)
		# bunting flag between this pole and the next
		var a2 := TAU * (i + 0.5) / 12.0
		var flag := MeshInstance3D.new()
		var fp := PrismMesh.new()
		fp.size = Vector3(0.5, 0.5, 0.03)
		flag.mesh = fp
		flag.position = Vector3(cos(a2) * 5.4, 2.55, sin(a2) * 5.4)
		flag.rotation = Vector3(PI, -a2 + PI / 2, 0)
		flag.material_override = _mat(colors[(i + 1) % colors.size()])
		festival_decor.add_child(flag)
	festival_decor.visible = false


## Material for world objects. Things that can block the camera (trees,
## houses, rocks, lamps) fade out when the camera gets close to them, so they
## never hide the player.
func _mat(c: Color, camera_fade := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if camera_fade:
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		m.distance_fade_min_distance = 3.5
		m.distance_fade_max_distance = 7.5
	return m
