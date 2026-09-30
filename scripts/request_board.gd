extends Node3D
## The request board by the market (and a second one inside the town hall).
## Villagers pin optional jobs on it every morning: bring Sal 2 mackerel, bring
## Bram 4 tomatoes, bring Otto 8 wood... Take a note, gather the things, then
## talk to that villager to hand them in for coins and friendship.
##   * up to 3 notes on the board (4 once the town hall is built)
##   * you can hold up to 3 requests at a time; each has 3 days
##   * notes nobody takes come down after 2 days
##   * rewards are about 1.6x what the items would sell for (+25% with the town hall)

const BOARD_POS := Vector3(3.6, 0, -15.6)
const MAX_ACCEPTED := 3
const DAYS_TO_DO := 3
const POSTED_DAYS := 2
const FRIEND_POINTS := 40

## What each villager tends to ask for: [item, min count, max count]
const WANTS := {
	"Bram": [["wheat", 3, 6], ["carrot", 2, 4], ["tomato", 2, 4], ["pumpkin", 1, 2], ["strawberry", 1, 3], ["corn", 1, 2], ["wood", 5, 8], ["pumpkin_pie", 1, 1], ["berries", 3, 5]],
	"Ivy": [["herb", 2, 4], ["berries", 2, 4], ["mushroom", 2, 3], ["strawberry", 1, 3], ["tomato", 2, 3], ["carrot", 2, 3], ["shell", 2, 3]],
	"Pip": [["shell", 2, 4], ["berries", 2, 4], ["crab", 2, 3], ["firefly", 1, 2], ["minnow", 2, 3], ["perch", 1, 2], ["berry_tart", 1, 1], ["stone", 4, 6]],
	"Otto": [["wood", 6, 10], ["stone", 6, 10], ["mushroom", 2, 3], ["trout", 1, 2], ["catfish", 1, 2], ["mushroom_soup", 1, 1], ["bass", 1, 2], ["herb", 2, 3]],
	"Sal": [["sardine", 2, 4], ["mackerel", 1, 3], ["pufferfish", 1, 2], ["squid", 1, 2], ["bass", 1, 2], ["trout", 1, 2], ["tuna", 1, 1], ["fish_stew", 1, 1], ["wood", 4, 6]],
}
const ASKS := {
	"Bram": ["I'm testing a new recipe. Could you bring me %s?", "The bakery is running low on supplies! I need %s."],
	"Ivy": ["I'm making a centerpiece and need %s. Could you help?", "Oh, would you find me %s? For a little project!"],
	"Pip": ["I NEED %s for my collection. Please please please!", "Top secret mission: bring me %s. Don't ask why!"],
	"Otto": ["A task for a capable youngster: fetch me %s.", "I require %s. For historical reasons."],
	"Sal": ["Bait's running low, matey. Could you bring me %s?", "Got a craving something fierce. Bring me %s!"],
}
const THANKS := {
	"Bram": ["Just what I needed! You've saved the day's baking.", "Perfect. You have a baker's eye for quality."],
	"Ivy": ["Oh, they're lovely! Thank you so much!", "You're a treasure. This is exactly right!"],
	"Pip": ["YES! Mission accomplished! You're the best!", "Whoa, you actually got them! High five!"],
	"Otto": ["Splendid. Most satisfactory work.", "Ah, excellent. You are a credit to the village."],
	"Sal": ["Aye, that's the stuff! Much obliged.", "Now that's a fine haul. Thanks, matey!"],
}

var world: Node3D


func build() -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = BOARD_POS
	var f := -Vector3(BOARD_POS.x, 0, BOARD_POS.z).normalized()
	root.rotation.y = atan2(f.x, f.z)
	var wood := Color(0.5, 0.35, 0.22)
	for x in [-0.75, 0.75]:
		_box(root, Vector3(x, 0.95, 0), Vector3(0.12, 1.9, 0.12), wood)
	_box(root, Vector3(0, 1.3, 0), Vector3(1.7, 1.0, 0.08), Color(0.72, 0.55, 0.35))
	_box(root, Vector3(0, 1.88, 0), Vector3(1.9, 0.12, 0.3), Color(0.8, 0.35, 0.3))
	var colors := [Color(1, 0.95, 0.8), Color(0.9, 0.95, 1), Color(1, 0.9, 0.9), Color(0.92, 1, 0.9)]
	for i in 4:
		var note := _box(root, Vector3(-0.55 + i * 0.37, 1.25 + (0.08 if i % 2 == 0 else -0.06), 0.05), Vector3(0.3, 0.36, 0.01), colors[i])
		note.name = "Note%d" % i
		_box(root, note.position + Vector3(0, 0.15, 0.01), Vector3(0.04, 0.04, 0.01), Color(0.85, 0.2, 0.2))
	var l := Label3D.new()
	l.text = "REQUESTS"
	l.font_size = 44
	l.pixel_size = 0.005
	l.outline_size = 10
	l.position = Vector3(0, 1.88, 0.16)
	l.visibility_range_end = 16.0
	root.add_child(l)
	world.landmarks.append({"name": "the request board", "pos": BOARD_POS, "radius": 0.9})
	world._spot(BOARD_POS + f * 1.0, 1.7, func(_p): return "E: Read the request board  (%d new)" % posted().size() if not posted().is_empty() else "E: Read the request board",
		func(_p): world.panels.open_board())


func _box(parent: Node3D, pos: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = world._mat(c, false)
	parent.add_child(mi)
	return mi


# ================================================================ state

func posted() -> Array:
	return Game.xarr("board_posted")


func accepted() -> Array:
	return Game.xarr("board_accepted")


func slots() -> int:
	return 4 if Game.hall_built() else 3


func reward_mult() -> float:
	return 2.0 if Game.hall_built() else 1.6


## Every morning: take down old notes, drop expired jobs, pin up new ones.
func refresh_day() -> void:
	if Game.xi("board_day", -1) == Game.day:
		_update_notes_visual()
		return
	Game.extra["board_day"] = Game.day
	Game.extra["board_posted"] = posted().filter(func(r): return int(r["posted"]) + POSTED_DAYS > Game.day)
	var still := []
	for r in accepted():
		if int(r["deadline"]) < Game.day:
			world.hud.show_toast("%s's request ran out of time." % r["npc"], 3.0)
		else:
			still.append(r)
	Game.extra["board_accepted"] = still
	var tries := 0
	while posted().size() < slots() and tries < 30:
		tries += 1
		var r := _new_request()
		if not r.is_empty():
			posted().append(r)
	_update_notes_visual()


func _new_request() -> Dictionary:
	var npc_name: String = WANTS.keys().pick_random()
	var want: Array = WANTS[npc_name].pick_random()
	var item: String = want[0]
	# don't post two notes for the same person and item
	for r in posted() + accepted():
		if r["npc"] == npc_name and r["item"] == item:
			return {}
	var n := randi_range(want[1], want[2])
	var sell: int = Game.ITEMS[item]["sell"]
	var reward := int(ceil(sell * n * reward_mult() + 10))
	var id := Game.xi("board_next_id", 1)
	Game.extra["board_next_id"] = id + 1
	var what := "%d %s" % [n, Game.item_name(item, n > 1).to_lower()]
	return {"id": id, "npc": npc_name, "item": item, "count": n, "reward": reward, "posted": Game.day, "deadline": -1,
		"text": (ASKS[npc_name] as Array).pick_random() % what}


func accept(id: int) -> bool:
	if accepted().size() >= MAX_ACCEPTED:
		return false
	for r in posted():
		if int(r["id"]) == id:
			posted().erase(r)
			r["deadline"] = Game.day + DAYS_TO_DO - 1
			accepted().append(r)
			_update_notes_visual()
			world.update_quest_log()
			return true
	return false


func drop(id: int) -> void:
	for r in accepted():
		if int(r["id"]) == id:
			accepted().erase(r)
			break
	world.update_quest_log()


func have_for(r: Dictionary) -> int:
	return Game.count(r["item"])


## A request this villager can take from you right now ({} if none).
func deliverable(npc_name: String) -> Dictionary:
	for r in accepted():
		if r["npc"] == npc_name and have_for(r) >= int(r["count"]):
			return r
	return {}


func open_for(npc_name: String) -> Dictionary:
	for r in accepted():
		if r["npc"] == npc_name:
			return r
	return {}


func thanks_lines(r: Dictionary) -> Array:
	return [(THANKS[r["npc"]] as Array).pick_random(), "Here's %d coins, as promised." % int(r["reward"])]


func complete(id: int) -> void:
	for r in accepted():
		if int(r["id"]) == id:
			if have_for(r) < int(r["count"]):
				return
			Game.remove_item(r["item"], int(r["count"]))
			Game.add_coins(int(r["reward"]))
			Game.add_friendship(r["npc"], FRIEND_POINTS)
			accepted().erase(r)
			Game.extra["board_done"] = Game.xi("board_done") + 1
			Audio.play("quest")
			world.hud.show_toast("Request done for %s! +%d coins, and %s likes you more." % [r["npc"], int(r["reward"]), r["npc"]], 4.0)
			world.update_quest_log()
			return


func quest_log_lines() -> String:
	var t := ""
	for r in accepted():
		var left: int = int(r["deadline"]) - Game.day + 1
		t += "\n[ ] %s: %d %s (%d/%d)  %s" % [r["npc"], int(r["count"]), Game.item_name(r["item"], int(r["count"]) > 1),
			min(have_for(r), int(r["count"])), int(r["count"]), "last day!" if left <= 1 else "%d days" % left]
	return t


func _update_notes_visual() -> void:
	var n := posted().size()
	for i in 4:
		var note := find_child("Note%d" % i, true, false)
		if note:
			note.visible = i < n
