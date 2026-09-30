extends Node
## Global game state (autoloaded as "Game"): money, inventory, the clock,
## quest progress, the farm and upgrades -- plus saving and loading.
## The world scene reads from and writes to this; menus call new_game()/load_game().

signal coins_changed
signal inventory_changed
signal day_started(day: int)

const SAVE_PATH := "user://save.json"
const SECONDS_PER_GAME_MINUTE := 0.45    # a full day (6 AM - 2 AM) is about 9 real minutes
const DAY_START := 6 * 60                # 6:00 AM
const PASS_OUT := 26 * 60                # 2:00 AM -- you fall asleep wherever you are
const START_COINS := 25

# ------------------------------------------------------------------ item data
## Everything that can be in the inventory. "sell" = 0 means it can't be sold.
const ITEMS := {
	"wheat_seed":   {"name": "Wheat Seeds",   "plural": "wheat seeds",   "sell": 0,   "kind": "seed"},
	"carrot_seed":  {"name": "Carrot Seeds",  "plural": "carrot seeds",  "sell": 0,   "kind": "seed"},
	"pumpkin_seed": {"name": "Pumpkin Seeds", "plural": "pumpkin seeds", "sell": 0,   "kind": "seed"},
	"tomato_seed":  {"name": "Tomato Seeds",  "plural": "tomato seeds",  "sell": 0,   "kind": "seed"},
	"corn_seed":    {"name": "Corn Seeds",    "plural": "corn seeds",    "sell": 0,   "kind": "seed"},
	"strawberry_seed": {"name": "Strawberry Seeds", "plural": "strawberry seeds", "sell": 0, "kind": "seed"},
	"wheat":        {"name": "Wheat",         "plural": "wheat",         "sell": 12,  "kind": "crop"},
	"carrot":       {"name": "Carrot",        "plural": "carrots",       "sell": 28,  "kind": "crop"},
	"pumpkin":      {"name": "Pumpkin",       "plural": "pumpkins",      "sell": 75,  "kind": "crop"},
	"tomato":       {"name": "Tomato",        "plural": "tomatoes",      "sell": 40,  "kind": "crop"},
	"corn":         {"name": "Corn",          "plural": "corn",          "sell": 120, "kind": "crop"},
	"strawberry":   {"name": "Strawberry",    "plural": "strawberries",  "sell": 95,  "kind": "crop"},
	"minnow":       {"name": "Minnow",        "plural": "minnows",       "sell": 8,   "kind": "fish"},
	"perch":        {"name": "Perch",         "plural": "perch",         "sell": 16,  "kind": "fish"},
	"bass":         {"name": "Bass",          "plural": "bass",          "sell": 30,  "kind": "fish"},
	"catfish":      {"name": "Catfish",       "plural": "catfish",       "sell": 45,  "kind": "fish"},
	"golden_carp":  {"name": "Golden Carp",   "plural": "golden carp",   "sell": 150, "kind": "fish"},
	"trout":        {"name": "Trout",         "plural": "trout",         "sell": 32,  "kind": "fish"},
	"eel":          {"name": "Eel",           "plural": "eels",          "sell": 58,  "kind": "fish"},
	# ocean fish
	"sardine":      {"name": "Sardine",       "plural": "sardines",      "sell": 12,  "kind": "fish"},
	"mackerel":     {"name": "Mackerel",      "plural": "mackerel",      "sell": 26,  "kind": "fish"},
	"pufferfish":   {"name": "Pufferfish",    "plural": "pufferfish",    "sell": 45,  "kind": "fish"},
	"swordfish":    {"name": "Swordfish",     "plural": "swordfish",     "sell": 95,  "kind": "fish"},
	"moonfish":     {"name": "Moonfish",      "plural": "moonfish",      "sell": 260, "kind": "fish"},
	"squid":        {"name": "Squid",         "plural": "squid",         "sell": 50,  "kind": "fish"},
	"tuna":         {"name": "Tuna",          "plural": "tuna",          "sell": 130, "kind": "fish"},
	# quest items
	"flour":        {"name": "Flour Sack",    "plural": "flour sacks",   "sell": 0,   "kind": "quest"},
	"flower":       {"name": "Flower",        "plural": "flowers",       "sell": 0,   "kind": "quest"},
	"coin":         {"name": "Gold Coin",     "plural": "gold coins",    "sell": 0,   "kind": "quest"},
	# critters from minigames
	"crab":         {"name": "Crab",          "plural": "crabs",         "sell": 15,  "kind": "critter"},
	"firefly":      {"name": "Firefly Jar",   "plural": "firefly jars",  "sell": 20,  "kind": "critter"},
	# foraged around the village (new spots every morning)
	"berries":      {"name": "Wild Berries",  "plural": "wild berries",  "sell": 14,  "kind": "forage"},
	"mushroom":     {"name": "Mushroom",      "plural": "mushrooms",     "sell": 22,  "kind": "forage"},
	"herb":         {"name": "Wild Herbs",    "plural": "wild herbs",    "sell": 16,  "kind": "forage"},
	"shell":        {"name": "Seashell",      "plural": "seashells",     "sell": 12,  "kind": "forage"},
	"truffle":      {"name": "Truffle",       "plural": "truffles",      "sell": 95,  "kind": "forage"},
	"pearl":        {"name": "Pearl",         "plural": "pearls",        "sell": 160, "kind": "forage"},
	# dug up with the daily treasure map
	"gem":          {"name": "Gemstone",      "plural": "gemstones",     "sell": 120, "kind": "treasure"},
	"old_coin":     {"name": "Ancient Coin",  "plural": "ancient coins", "sell": 80,  "kind": "treasure"},
	"relic":        {"name": "Old Relic",     "plural": "old relics",    "sell": 200, "kind": "treasure"},
	# gathered from trees and boulders (used to build the town hall)
	"wood":         {"name": "Wood",          "plural": "wood",          "sell": 5,   "kind": "material"},
	"stone":        {"name": "Stone",         "plural": "stone",         "sell": 4,   "kind": "material"},
	# for your puppy
	"pet_treat":    {"name": "Pet Treat",     "plural": "pet treats",    "sell": 0,   "kind": "pet"},
	# made in the villagers' houses
	"bread":        {"name": "Bread Loaf",    "plural": "bread loaves",  "sell": 20,  "kind": "goods"},
	"bouquet":      {"name": "Bouquet",       "plural": "bouquets",      "sell": 35,  "kind": "goods"},
	# cooked at home (see RECIPES)
	"grilled_fish":    {"name": "Grilled Fish",    "plural": "grilled fish",     "sell": 70,  "kind": "dish"},
	"fish_stew":       {"name": "Fish Stew",       "plural": "fish stews",       "sell": 90,  "kind": "dish"},
	"tomato_soup":     {"name": "Tomato Soup",     "plural": "tomato soups",     "sell": 120, "kind": "dish"},
	"pumpkin_pie":     {"name": "Pumpkin Pie",     "plural": "pumpkin pies",     "sell": 170, "kind": "dish"},
	"corn_chowder":    {"name": "Corn Chowder",    "plural": "corn chowders",    "sell": 210, "kind": "dish"},
	"strawberry_cake": {"name": "Strawberry Cake", "plural": "strawberry cakes", "sell": 280, "kind": "dish"},
	"mushroom_soup":   {"name": "Mushroom Soup",   "plural": "mushroom soups",   "sell": 110, "kind": "dish"},
	"berry_tart":      {"name": "Berry Tart",      "plural": "berry tarts",      "sell": 120, "kind": "dish"},
	"herb_fish":       {"name": "Herb-Baked Fish", "plural": "herb-baked fish",  "sell": 115, "kind": "dish"},
	# secret recipes the villagers teach you at 5 hearts
	"harvest_loaf":    {"name": "Bram's Harvest Loaf", "plural": "harvest loaves",  "sell": 260, "kind": "dish"},
	"garden_salad":    {"name": "Ivy's Garden Salad",  "plural": "garden salads",   "sell": 240, "kind": "dish"},
	"berry_pancakes":  {"name": "Pip's Berry Pancakes", "plural": "berry pancakes", "sell": 210, "kind": "dish"},
	"truffle_stew":    {"name": "Otto's Truffle Stew", "plural": "truffle stews",   "sell": 360, "kind": "dish"},
	"seafood_platter": {"name": "Sal's Seafood Platter", "plural": "seafood platters", "sell": 250, "kind": "dish"},
}

## Cooking at your stove. "any_fish" = any fish (the cheapest ones are used first).
## A 3-star cook makes 2 dishes, 1-2 stars makes 1, 0 stars burns it.
const RECIPES := [
	{"id": "grilled_fish",    "needs": {"any_fish": 2}},
	{"id": "fish_stew",       "needs": {"any_fish": 1, "carrot": 1}},
	{"id": "tomato_soup",     "needs": {"tomato": 2}},
	{"id": "pumpkin_pie",     "needs": {"pumpkin": 1, "wheat": 2}},
	{"id": "corn_chowder",    "needs": {"corn": 1, "any_fish": 1}},
	{"id": "strawberry_cake", "needs": {"strawberry": 2, "wheat": 1}},
	{"id": "mushroom_soup",   "needs": {"mushroom": 2}},
	{"id": "berry_tart",      "needs": {"berries": 2, "wheat": 1}},
	{"id": "herb_fish",       "needs": {"any_fish": 1, "herb": 1}},
	# secret recipes: only show up once the villager has taught you (5 hearts)
	{"id": "harvest_loaf",    "needs": {"wheat": 2, "pumpkin": 1}, "secret": "Bram"},
	{"id": "garden_salad",    "needs": {"tomato": 1, "strawberry": 1, "herb": 1}, "secret": "Ivy"},
	{"id": "berry_pancakes",  "needs": {"berries": 2, "wheat": 1, "strawberry": 1}, "secret": "Pip"},
	{"id": "truffle_stew",    "needs": {"truffle": 1, "any_fish": 1}, "secret": "Otto"},
	{"id": "seafood_platter", "needs": {"any_fish": 3}, "secret": "Sal"},
]

## seed -> crop it grows into, days of watering needed, and colors for the model
const CROPS := {
	"wheat_seed":   {"crop": "wheat",   "days": 2, "color": Color(0.95, 0.8, 0.3)},
	"carrot_seed":  {"crop": "carrot",  "days": 3, "color": Color(1.0, 0.5, 0.1)},
	"pumpkin_seed": {"crop": "pumpkin", "days": 4, "color": Color(1.0, 0.55, 0.05)},
	"tomato_seed":  {"crop": "tomato",  "days": 3, "color": Color(0.9, 0.15, 0.1)},
	"strawberry_seed": {"crop": "strawberry", "days": 4, "color": Color(0.95, 0.2, 0.3)},
	"corn_seed":    {"crop": "corn",    "days": 5, "color": Color(1.0, 0.85, 0.25)},
}

## Fish you can catch. hours = [from, to) in 24h game time (to may go past 24).
## difficulty 0..1 controls how wildly the fish moves in the minigame.
## water: "pond" or "ocean". dock: only bites from the end of the dock.
## style "dart": sudden jumps (pufferfish); "strong": pulls the meter down faster.
const FISH := [
	{"id": "minnow",      "difficulty": 0.25, "weight": 40, "hours": [6, 26], "water": "pond"},
	{"id": "perch",       "difficulty": 0.40, "weight": 30, "hours": [6, 19], "water": "pond"},
	{"id": "bass",        "difficulty": 0.60, "weight": 18, "hours": [6, 26], "water": "pond"},
	{"id": "catfish",     "difficulty": 0.70, "weight": 25, "hours": [19, 26], "water": "pond"},
	{"id": "golden_carp", "difficulty": 0.95, "weight": 4,  "hours": [6, 9], "water": "pond"},
	{"id": "trout",       "difficulty": 0.45, "weight": 22, "hours": [6, 18], "water": "pond"},
	{"id": "eel",         "difficulty": 0.72, "weight": 15, "hours": [20, 26], "water": "pond", "style": "dart"},
	{"id": "sardine",     "difficulty": 0.30, "weight": 40, "hours": [6, 26], "water": "ocean"},
	{"id": "mackerel",    "difficulty": 0.50, "weight": 30, "hours": [6, 20], "water": "ocean"},
	{"id": "pufferfish",  "difficulty": 0.60, "weight": 20, "hours": [6, 26], "water": "ocean", "style": "dart"},
	{"id": "swordfish",   "difficulty": 0.85, "weight": 9,  "hours": [10, 18], "water": "ocean", "style": "strong"},
	{"id": "moonfish",    "difficulty": 0.95, "weight": 4, "hours": [21, 26], "water": "ocean", "dock": true},
	{"id": "squid",       "difficulty": 0.55, "weight": 20, "hours": [19, 26], "water": "ocean"},
	{"id": "tuna",        "difficulty": 0.85, "weight": 10, "hours": [7, 17], "water": "ocean", "dock": true, "style": "strong"},
]

## What the market sells.
const SHOP := [
	{"id": "wheat_seed",   "price": 5,   "desc": "Grows in 2 days. Sells for 12."},
	{"id": "carrot_seed",  "price": 10,  "desc": "Grows in 3 days. Sells for 28."},
	{"id": "pumpkin_seed", "price": 25,  "desc": "Grows in 4 days. Sells for 75."},
	{"id": "tomato_seed",  "price": 15,  "desc": "Grows in 3 days. Sells for 40."},
	{"id": "strawberry_seed", "price": 35, "desc": "Grows in 4 days. Sells for 95."},
	{"id": "corn_seed",    "price": 40,  "desc": "Grows in 5 days. Sells for 120."},
	{"id": "rod",          "price": 120, "name": "Better Rod", "desc": "Bigger catch bar when fishing.", "upgrade": true},
	{"id": "lure",         "price": 150, "name": "Golden Lure", "desc": "Faster bites; rare fish bite more often.", "upgrade": true},
	{"id": "sprinklers",   "price": 800, "name": "Sprinklers", "desc": "Your farm waters itself every morning.", "upgrade": true},
	{"id": "wood",         "price": 15,  "desc": "In a hurry? Chopping trees is free!"},
	{"id": "stone",        "price": 15,  "desc": "Or break boulders around the village for free."},
	{"id": "pet_treat",    "price": 8,   "desc": "Your puppy's favorite snack."},
	{"id": "guitar",       "price": 300, "name": "Guitar", "desc": "Play it at your piano or the bandstand (music menu).", "upgrade": true},
	{"id": "flute",        "price": 250, "name": "Flute", "desc": "A sweet wooden flute for the music menu.", "upgrade": true},
	{"id": "master_rod",   "price": 2000, "name": "Master Rod", "desc": "Biggest catch bar; legendary fish bite twice as often.", "upgrade": true, "needs": "rod"},
]

## Hats for you to wear (buy at the market, then Wear / Take off).
const HATS := [
	{"id": "party_hat",    "name": "Party Hat",    "price": 175},
	{"id": "straw_hat",    "name": "Straw Hat",    "price": 300},
	{"id": "flower_crown", "name": "Flower Crown", "price": 500},
	{"id": "pirate_hat",   "name": "Pirate Hat",   "price": 1000},
	{"id": "crown",        "name": "Golden Crown", "price": 4000},
	# gifts from villagers at 8 hearts (not sold -- they show up once you own them)
	{"id": "chef_hat",     "name": "Bram's Chef Hat",   "price": 0, "gift": true},
	{"id": "flower",       "name": "Ivy's Flower",      "price": 0, "gift": true},
	{"id": "propeller_cap", "name": "Pip's Propeller Cap", "price": 0, "gift": true},
	{"id": "top_hat",      "name": "Otto's Top Hat",    "price": 0, "gift": true},
	{"id": "sailor_hat",   "name": "Sal's Sailor Cap",  "price": 0, "gift": true},
]

## The town hall is built in stages at the construction site (north-east of
## your house). Contributions can be made a bit at a time.
const TOWN_HALL := [
	{"name": "Foundation", "desc": "A solid stone floor.",          "needs": {"stone": 30, "coins": 200}},
	{"name": "Frame",      "desc": "Timber posts and beams.",       "needs": {"wood": 40}},
	{"name": "Walls",      "desc": "Walls, windows and a big door.", "needs": {"wood": 30, "stone": 30}},
	{"name": "Roof",       "desc": "The roof, a bell tower and the village flag.", "needs": {"wood": 25, "stone": 15, "coins": 500}},
]

## The town hall museum: donate one of each fish (to the aquarium), crop,
## forage find and treasure. Rewards at these totals: [count, coins, item].
const MUSEUM_KINDS := ["fish", "crop", "forage", "treasure"]
const MUSEUM_REWARDS := [[5, 150, ""], [10, 300, "gem"], [15, 500, ""], [20, 800, "relic"], [25, 1200, ""], [29, 3000, "pearl"]]


func museum_items() -> Array:
	var out := []
	for id in ITEMS:
		if ITEMS[id]["kind"] in MUSEUM_KINDS:
			out.append(id)
	return out


func museum_has(id: String) -> bool:
	return xarr("museum").has(id)


## Village projects: fund them at the board beside the market. Each one changes the village.
const PROJECTS := [
	{"id": "gardens",   "name": "Flower Gardens", "price": 600,   "desc": "Curved flower beds around the village square."},
	{"id": "fountain",  "name": "Fountain",       "price": 1500,  "desc": "A three-tier fountain in its own little court. Toss in a coin!"},
	{"id": "bandstand", "name": "Bandstand",      "price": 2500,  "desc": "A stage with a red roof. Play music; villagers dance in the evening."},
	{"id": "statue",    "name": "Golden Statue",  "price": 7000,  "desc": "A golden statue of the village hero. (That's you!)"},
]

# ------------------------------------------------------------------ state
var coins := START_COINS
var inventory := {}            # item id -> count
var day := 1
var minutes := DAY_START       # game minutes since midnight of the current day
var quest_progress := {}       # npc name -> {"index": int, "state": int}
var npc_memory := {}           # npc name -> {"friendship": {}, "heard_helped": []}
var farm := []                 # one dict per farm tile
var upgrades := {"rod": false, "lure": false}
var hats_owned: Array = []
var player_hat := ""
var projects := {}             # project id -> coins donated so far
var crab_day := -1             # the day you last went crab catching (once per day)
var race_day := -1             # the day you last raced Pip (once per day)
var race_best := 0.0           # best race time in seconds (0 = never won)
var house_day := {}            # house id -> the day you last played its minigame (once per day)
var dishes_cooked := 0
## Everything added in update 12 (friendship, pet, foraging, treasure, music,
## rock skipping, stargazing) lives in one dictionary, saved as a whole.
var extra := {}
const SEASON_DAYS := 28
var selected_seed := "wheat_seed"
var won := false
var fish_caught := 0
var crops_harvested := 0

## Settings (saved in settings.cfg, not in the save game)
const SETTINGS_PATH := "user://settings.cfg"
var fishing_mode := "minigame"   # "minigame" (timing bar) or "simple" (just react to the bite)
var farming_mode := "minigame"   # "minigame" (Pull! on harvest) or "simple" (harvest instantly)
var gathering_mode := "minigame" # "minigame" (Timber!/Strike! when chopping and mining) or "simple" (just swing)

## Runtime-only (not saved)
var time_running := false      # false on the title screen, in dialogue, shops and menus
var start_mode := "title"      # "title", "new" or "continue" -- read by the world on load


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		fishing_mode = cfg.get_value("gameplay", "fishing_mode", fishing_mode)
		farming_mode = cfg.get_value("gameplay", "farming_mode", farming_mode)
		gathering_mode = cfg.get_value("gameplay", "gathering_mode", gathering_mode)


func set_fishing_mode(mode: String) -> void:
	fishing_mode = mode
	_save_setting("fishing_mode", mode)


func set_farming_mode(mode: String) -> void:
	farming_mode = mode
	_save_setting("farming_mode", mode)


func set_gathering_mode(mode: String) -> void:
	gathering_mode = mode
	_save_setting("gathering_mode", mode)


func _save_setting(key: String, value) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("gameplay", key, value)
	cfg.save(SETTINGS_PATH)


## Registering key bindings in code keeps project.godot short and readable.
func _setup_input() -> void:
	var actions := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E],
		"jump": [KEY_SPACE],
		"reel": [KEY_SPACE, KEY_E, MOUSE_BUTTON_LEFT],
		"cycle_seed": [KEY_Q],
		"pause": [KEY_ESCAPE],
		"choice_1": [KEY_1, KEY_KP_1],
		"choice_2": [KEY_2, KEY_KP_2],
		"choice_3": [KEY_3, KEY_KP_3],
		"choice_4": [KEY_4, KEY_KP_4],
		"choice_5": [KEY_5, KEY_KP_5],
		"choice_6": [KEY_6, KEY_KP_6],
		"choice_7": [KEY_7, KEY_KP_7],
		"choice_8": [KEY_8, KEY_KP_8],
		"choice_9": [KEY_9, KEY_KP_9],
		"gift": [KEY_G],
		"journal": [KEY_J],
		"bag": [KEY_I, KEY_TAB],
		"map": [KEY_M],
		"lane_1": [KEY_D, KEY_1],
		"lane_2": [KEY_F, KEY_2],
		"lane_3": [KEY_J, KEY_3],
		"lane_4": [KEY_K, KEY_4],
	}
	for action in actions:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for code in actions[action]:
			var ev: InputEvent
			if code == MOUSE_BUTTON_LEFT:
				ev = InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
			else:
				ev = InputEventKey.new()
				ev.physical_keycode = code
			InputMap.action_add_event(action, ev)


# ------------------------------------------------------------------ helpers

func count(item: String) -> int:
	return inventory.get(item, 0)


func add_item(item: String, n := 1) -> void:
	inventory[item] = count(item) + n
	if inventory[item] <= 0:
		inventory.erase(item)
	inventory_changed.emit()


func remove_item(item: String, n := 1) -> bool:
	if count(item) < n:
		return false
	add_item(item, -n)
	return true


func count_kind(kind: String) -> int:
	var total := 0
	for id in inventory:
		if ITEMS.has(id) and ITEMS[id]["kind"] == kind:
			total += inventory[id]
	return total


## Removes n items of a kind (e.g. any 3 fish), cheapest first.
func remove_kind(kind: String, n: int) -> bool:
	if count_kind(kind) < n:
		return false
	var ids := inventory.keys().filter(func(id): return ITEMS.has(id) and ITEMS[id]["kind"] == kind)
	ids.sort_custom(func(a, b): return ITEMS[a]["sell"] < ITEMS[b]["sell"])
	for id in ids:
		while n > 0 and count(id) > 0:
			add_item(id, -1)
			n -= 1
	return true


func project_info(id: String) -> Dictionary:
	for p in PROJECTS:
		if p["id"] == id:
			return p
	return {}


func project_donated(id: String) -> int:
	return int(projects.get(id, 0))


func is_project_funded(id: String) -> bool:
	var info := project_info(id)
	return not info.is_empty() and project_donated(id) >= int(info["price"])


## Put up to n coins toward a project. Returns how many were actually spent.
func donate(id: String, n: int) -> int:
	var info := project_info(id)
	if info.is_empty():
		return 0
	var spend: int = min(n, coins, int(info["price"]) - project_donated(id))
	if spend <= 0:
		return 0
	add_coins(-spend)
	projects[id] = project_donated(id) + spend
	return spend


func _default_extra() -> Dictionary:
	return {
		"friendship": {},      # villager -> friendship points (100 per heart, max 1000)
		"talked_day": {},      # villager -> last day you chatted (daily friendship)
		"gift_day": {},        # villager -> last day you gave a gift
		"events_seen": {},     # villager -> [heart levels whose story you've seen]
		"known_likes": {},     # villager -> [item ids whose reaction you've learned]
		"recipes": [],         # secret recipes learned
		"pet": {"adopted": false, "name": "Biscuit", "happiness": 50, "fed_day": -1, "petted_day": -1, "played_day": -1},
		"forage_day": -1, "forage_taken": [], "foraged": 0,
		"treasure_day": -1, "treasure_opened": false, "treasure_found": false, "treasures": 0,
		"music_best": {}, "music_day": -1,
		"skip_best": 0, "skip_day": -1,
		"stars_found": [], "stars_day": -1,
		# update 13: gathering, town hall, request board
		"cut": {},             # tree / boulder id -> day it was cut (they grow back)
		"gathered": 0,
		"hall_stage": 0,       # town hall stages finished (0-4)
		"hall_given": {},      # resource -> amount put toward the current stage
		"board_day": -1, "board_posted": [], "board_accepted": [], "board_done": 0, "board_next_id": 1,
		# update 16: the town hall museum, and a log of recently found items for the HUD
		"museum": [],          # item ids donated (one of each)
		"museum_rewards": 0,   # how many MUSEUM_REWARDS have been paid out
		"wishes": 0,
	}


## Small helpers for the extra state (JSON loads numbers as floats).
func xi(key: String, default := 0) -> int:
	return int(extra.get(key, default))


func xdict(key: String) -> Dictionary:
	if not extra.has(key) or typeof(extra[key]) != TYPE_DICTIONARY:
		extra[key] = {}
	return extra[key]


func xarr(key: String) -> Array:
	if not extra.has(key) or typeof(extra[key]) != TYPE_ARRAY:
		extra[key] = []
	return extra[key]


func pet() -> Dictionary:
	return xdict("pet")


func day_of_season() -> int:
	return (day - 1) % SEASON_DAYS + 1


func friendship(npc_name: String) -> int:
	return int(xdict("friendship").get(npc_name, 0))


func hearts(npc_name: String) -> int:
	return friendship(npc_name) / 100


func add_friendship(npc_name: String, n: int) -> void:
	var f := xdict("friendship")
	f[npc_name] = clampi(friendship(npc_name) + n, 0, 1000)


func hall_built() -> bool:
	return xi("hall_stage") >= TOWN_HALL.size()


func recipe_known(recipe: Dictionary) -> bool:
	return not recipe.has("secret") or xarr("recipes").has(recipe["id"])


## Can you cook this recipe with what's in your bag?
func can_cook(recipe: Dictionary) -> bool:
	for id in recipe["needs"]:
		var n: int = recipe["needs"][id]
		if (count_kind("fish") if id == "any_fish" else count(id)) < n:
			return false
	return true


func use_ingredients(recipe: Dictionary) -> void:
	for id in recipe["needs"]:
		var n: int = recipe["needs"][id]
		if id == "any_fish":
			remove_kind("fish", n)
		else:
			remove_item(id, n)


func house_done_today(id: String) -> bool:
	return int(house_day.get(id, -1)) == day


func add_coins(n: int) -> void:
	coins += n
	coins_changed.emit()


func item_name(id: String, plural := false) -> String:
	if not ITEMS.has(id):
		return id
	return ITEMS[id]["plural"] if plural else ITEMS[id]["name"]


func hour() -> float:
	return minutes / 60.0


func is_night() -> bool:
	return minutes >= 20 * 60 or minutes < 6 * 60


func clock_text() -> String:
	var m := minutes % (24 * 60)
	var h := m / 60
	var suffix := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, (m % 60) / 10 * 10, suffix]


func owned_seeds() -> Array:
	return CROPS.keys().filter(func(s): return count(s) > 0)


func cycle_seed() -> void:
	var seeds := CROPS.keys()
	var i := seeds.find(selected_seed)
	for step in seeds.size():
		i = (i + 1) % seeds.size()
		if count(seeds[i]) > 0:
			selected_seed = seeds[i]
			break
	inventory_changed.emit()


# ------------------------------------------------------------------ days

## Called when you sleep (or pass out). Grows watered crops and saves.
func advance_day() -> void:
	# your puppy gets sad if it wasn't fed or petted yesterday
	var p := pet()
	if p.get("adopted", false):
		var h := int(p.get("happiness", 50))
		if int(p.get("fed_day", -1)) != day:
			h -= 15
		if int(p.get("petted_day", -1)) != day:
			h -= 5
		p["happiness"] = clampi(h, 0, 100)
	day += 1
	minutes = DAY_START
	for tile in farm:
		if tile["crop"] != "" and tile["watered"]:
			tile["stage"] += 1
		tile["watered"] = false
		if upgrades.get("sprinklers", false) and tile["crop"] != "":
			tile["watered"] = true
	day_started.emit(day)


# ------------------------------------------------------------------ new / save / load

func reset() -> void:
	coins = START_COINS
	inventory = {"wheat_seed": 5}
	day = 1
	minutes = DAY_START
	quest_progress = {}
	npc_memory = {}
	farm = []
	upgrades = {"rod": false, "lure": false}
	hats_owned = []
	player_hat = ""
	projects = {}
	crab_day = -1
	race_day = -1
	race_best = 0.0
	house_day = {}
	dishes_cooked = 0
	extra = _default_extra()
	selected_seed = "wheat_seed"
	won = false
	fish_caught = 0
	crops_harvested = 0


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var data := {
		"version": 1,
		"coins": coins, "inventory": inventory, "day": day, "minutes": minutes,
		"quest_progress": quest_progress, "npc_memory": npc_memory, "farm": farm,
		"upgrades": upgrades, "selected_seed": selected_seed, "won": won,
		"hats_owned": hats_owned, "player_hat": player_hat, "projects": projects,
		"crab_day": crab_day, "race_day": race_day, "race_best": race_best,
		"house_day": house_day, "dishes_cooked": dishes_cooked, "extra": extra,
		"fish_caught": fish_caught, "crops_harvested": crops_harvested,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not save: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(data, "  "))
	return true


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Save file is corrupted; starting a new game.")
		return false
	reset()
	coins = int(data.get("coins", START_COINS))
	day = int(data.get("day", 1))
	minutes = int(data.get("minutes", DAY_START))
	won = bool(data.get("won", false))
	selected_seed = str(data.get("selected_seed", "wheat_seed"))
	fish_caught = int(data.get("fish_caught", 0))
	crops_harvested = int(data.get("crops_harvested", 0))
	upgrades = data.get("upgrades", upgrades)
	hats_owned = data.get("hats_owned", [])
	player_hat = str(data.get("player_hat", ""))
	projects = data.get("projects", {})
	crab_day = int(data.get("crab_day", -1))
	race_day = int(data.get("race_day", -1))
	race_best = float(data.get("race_best", 0.0))
	house_day = {}
	var hd: Dictionary = data.get("house_day", {})
	for k in hd:
		house_day[k] = int(hd[k])
	dishes_cooked = int(data.get("dishes_cooked", 0))
	extra = _default_extra()
	var ex: Dictionary = data.get("extra", {})
	for k in ex:
		extra[k] = ex[k]
	npc_memory = data.get("npc_memory", {})
	# JSON turns every number into a float -- convert counts back to ints
	inventory = {}
	for k in data.get("inventory", {}):
		inventory[k] = int(data["inventory"][k])
	quest_progress = {}
	for k in data.get("quest_progress", {}):
		var q: Dictionary = data["quest_progress"][k]
		quest_progress[k] = {"index": int(q.get("index", 0)), "state": int(q.get("state", 0))}
	farm = []
	for t in data.get("farm", []):
		farm.append({"tilled": bool(t.get("tilled", false)), "crop": str(t.get("crop", "")),
			"stage": int(t.get("stage", 0)), "watered": bool(t.get("watered", false))})
	return true
