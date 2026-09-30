extends CharacterBody3D
## A villager with a small state machine:
##   IDLE / WANDER -> standing around or walking to a random spot
##   APPROACH / CHATTING -> walking to another villager and chatting
##   TALKING -> in a conversation with the player
##   FLEE -> running from the player during tag
##   GO_HOME / HOME -> heading home in the evening, asleep inside at night
##   CELEBRATE -> hopping around at the festival
##
## Each villager has a chain of quests. Villagers talk to each other: they ask
## about their problems (others answer with real hints), gossip about what they
## heard, and spread news when the player helps someone.

enum State { IDLE, WANDER, APPROACH, CHATTING, TALKING, FLEE, CELEBRATE, GO_HOME, HOME, RACE }
enum Quest { NOT_STARTED, ACTIVE, DONE }

const SPEED := 2.0
const FLEE_SPEED := 6.0   # a bit faster than the player -- wait for her to trip!
const CHAT_DISTANCE := 1.8
const LINE_TIME := 2.6
const GRAVITY := 20.0
const TAG_DISTANCE := 1.5
const VISUAL_SCRIPT := preload("res://scripts/character_visual.gd")
const VILLAGERS := preload("res://scripts/villager_data.gd")

# Set by main.gd before the node enters the tree
var npc_name := "NPC"
var hue := 0.0
var accessory := ""
var model_scale := 1.5
var greetings: Array = []
var lines: Array = []
var chat_lines: Array = []
var quests: Array = []
var door_pos := Vector3.ZERO
var world_half_size := 28.0
var others: Array = []
var game: Node   # main.gd

var state := State.IDLE
var quest_index := 0
var quest_state := Quest.NOT_STARTED
var state_timer := 0.0
var target := Vector3.ZERO
var chat_cooldown := 0.0
var partner: CharacterBody3D = null
var is_initiator := false
var convo: Array = []   # [[speaker, text], ...]
var convo_step := 0
var line_timer := 0.0
var pending_action := ""   # what to do when the player closes the dialogue

var friendship := {}        # other npc name -> number of chats
var last_heard := {}        # {"from": name, "text": line}
var heard_helped: Array = []   # names of villagers this one knows the player helped
var times_met_player := 0
var bedtime := 20 * 60
var wake_time := 7 * 60

var flee_timer := 0.0
var flee_grace := 0.0
var stumble_timer := 0.0
var dodge_timer := 0.0
var dodge_dir := Vector3.ZERO
var flee_dir := Vector3.ZERO
var last_flee_pos := Vector3.ZERO
var stuck_time := 0.0

var visual: Node3D
var bubble: Label3D
var name_label: Label3D
var collider: CollisionShape3D
var bubble_timer := 0.0
var interact_range := 2.5


func _ready() -> void:
	add_to_group("interactable")
	_build_body()
	_load_from_save()
	_roll_schedule()
	chat_cooldown = randf_range(2.0, 5.0)
	_enter_idle()


func _build_body() -> void:
	collider = CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 1.8
	collider.shape = shape
	add_child(collider)

	visual = Node3D.new()
	visual.set_script(VISUAL_SCRIPT)
	add_child(visual)
	visual.setup(hue, accessory, model_scale)

	name_label = Label3D.new()
	name_label.text = npc_name
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.position.y = 1.35
	name_label.font_size = 48
	name_label.pixel_size = 0.005
	name_label.outline_size = 12
	add_child(name_label)

	bubble = Label3D.new()
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.position.y = 1.8
	bubble.font_size = 40
	bubble.pixel_size = 0.005
	bubble.outline_size = 14
	bubble.modulate = Color(1, 1, 0.85)
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD
	bubble.width = 550
	bubble.visible = false
	add_child(bubble)


# ---------------------------------------------------------------- save data

func _load_from_save() -> void:
	var p: Dictionary = Game.quest_progress.get(npc_name, {})
	quest_index = p.get("index", 0)
	quest_state = p.get("state", Quest.NOT_STARTED)
	if quest_state == Quest.ACTIVE and quest.get("type", "") == "tag":
		quest_state = Quest.NOT_STARTED   # a tag game in progress doesn't survive a reload
	var m: Dictionary = Game.npc_memory.get(npc_name, {})
	friendship = m.get("friendship", {})
	heard_helped = m.get("heard_helped", [])
	times_met_player = int(m.get("met", 0))


func _save_progress() -> void:
	Game.quest_progress[npc_name] = {"index": quest_index, "state": quest_state}
	Game.npc_memory[npc_name] = {"friendship": friendship, "heard_helped": heard_helped, "met": times_met_player}


## The current quest, or {} if this villager has nothing left to ask.
var quest: Dictionary:
	get:
		return quests[quest_index] if quest_index < quests.size() else {}


func all_quests_done() -> bool:
	return quest_index >= quests.size()


# ---------------------------------------------------------------- main loop

func _physics_process(delta: float) -> void:
	if state == State.HOME:
		if Game.minutes >= wake_time and Game.minutes < bedtime:
			_wake_up()
		return

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0

	if bubble_timer > 0.0:
		bubble_timer -= delta
		if bubble_timer <= 0.0:
			bubble.visible = false

	if chat_cooldown > 0.0:
		chat_cooldown -= delta

	# Evening: head home (unless busy with the player)
	if Game.minutes >= bedtime and state in [State.IDLE, State.WANDER, State.APPROACH, State.CHATTING]:
		go_home()

	match state:
		State.IDLE:
			_stop()
			state_timer -= delta
			if _try_start_chat():
				pass
			elif state_timer <= 0.0:
				_enter_wander()
			elif _near_site() and randf() < 0.006:
				say(["~ hammering ~", "~ measuring ~", "~ carrying planks ~"].pick_random(), 2.0)
				if game.player.global_position.distance_to(global_position) < 12.0:
					Audio.play("hammer", 0.1, -10.0)
			elif _at_spot() and randf() < 0.006:
				say(current_spot()[3], 2.5)
				state_timer = max(state_timer, 4.0)   # linger at a favorite spot
			elif randf() < 0.004 and _near_bandstand():
				velocity.y = 4.5   # a little dance hop
				say(["♪ La la la ♪", "What a tune!", "♪ ♫ ♪", "I love this song!"].pick_random(), 1.5)
		State.WANDER:
			state_timer -= delta
			if _try_start_chat():
				pass
			elif _move_toward(target) < 0.5 or state_timer <= 0.0:
				_enter_idle()
		State.APPROACH:
			state_timer -= delta
			if not is_instance_valid(partner) or partner.partner != self or state_timer <= 0.0:
				_end_chat()   # partner got busy or we took too long
			elif _move_toward(partner.global_position) < CHAT_DISTANCE:
				_stop()
				_face(partner.global_position)
				if is_initiator and partner.state == State.CHATTING:
					_begin_convo()
				else:
					state = State.CHATTING
		State.CHATTING:
			_stop()
			if is_instance_valid(partner):
				_face(partner.global_position)
			if is_initiator:
				_run_convo(delta)
			elif not is_instance_valid(partner) or partner.partner != self:
				_end_chat()
		State.TALKING:
			_stop()
		State.FLEE:
			_run_flee(delta)
		State.CELEBRATE:
			_stop()
			if is_on_floor() and randf() < 0.03:
				velocity.y = 6.0
				say(["Hooray!", "Happy festival!", "Woohoo!", "Thank you!"].pick_random(), 1.2)
		State.RACE:
			_run_race()
		State.GO_HOME:
			state_timer -= delta
			if _move_toward(door_pos) < 0.7 or state_timer <= 0.0:
				_enter_home()

	move_and_slide()
	_slide_off_characters()
	visual.animate_from_velocity(velocity, is_on_floor(), SPEED)


# ---------------------------------------------------------------- movement

func _move_toward(pos: Vector3, speed := SPEED) -> float:
	var to := pos - global_position
	to.y = 0.0
	var dist := to.length()
	if dist > 0.05:
		var dir := _steer_around_obstacles(to / dist, dist)
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_face(global_position + dir)
	return dist


var walk_stuck := 0.0
var detour_timer := 0.0
var detour_dir := Vector3.ZERO

## Bends the walking direction around trees, rocks and buildings that are in
## the way, and sidesteps if we still end up wedged against something.
func _steer_around_obstacles(dir: Vector3, dist: float) -> Vector3:
	var here := Vector3(global_position.x, 0, global_position.z)
	var side := Vector3(-dir.z, 0, dir.x)
	var steer := Vector3.ZERO
	for lm in game.landmarks:
		var off: Vector3 = lm["pos"] * Vector3(1, 0, 1) - here
		var ahead := off.dot(dir)
		if ahead < 0.0 or ahead > min(3.0, dist):
			continue
		var lateral := off.dot(side)
		var clearance: float = lm["radius"] + 0.7
		if abs(lateral) < clearance:
			# push away from the obstacle's side, harder the closer it is
			var push: float = (clearance - abs(lateral)) / clearance * (1.0 - ahead / 3.0)
			steer -= side * sign(lateral if lateral != 0.0 else 1.0) * push * 2.0
	var out := (dir + steer).normalized()

	# fallback: still not moving? sidestep for a moment
	var actual := get_real_velocity()
	if Vector2(actual.x, actual.z).length() < SPEED * 0.3 and is_on_floor():
		walk_stuck += get_physics_process_delta_time()
	else:
		walk_stuck = 0.0
	if walk_stuck > 0.35 and detour_timer <= 0.0:
		detour_dir = (side * (1.0 if randf() < 0.5 else -1.0) + dir * 0.2).normalized()
		detour_timer = 0.8
		walk_stuck = 0.0
	if detour_timer > 0.0:
		detour_timer -= get_physics_process_delta_time()
		return detour_dir
	return out


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0


func _face(pos: Vector3) -> void:
	var d := pos - global_position
	if Vector2(d.x, d.z).length() > 0.01:
		var want := atan2(-d.x, -d.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, want, 0.2)


## If we're standing on top of another character, slide off sideways.
func _slide_off_characters() -> void:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var other := c.get_collider()
		if other is CharacterBody3D and c.get_normal().y > 0.3:
			var away: Vector3 = global_position - other.global_position
			away.y = 0.0
			if away.length() < 0.01:
				away = Vector3(randf() - 0.5, 0.0, randf() - 0.5)
			global_position += away.normalized() * 0.1


# ---------------------------------------------------------------- states

func _enter_idle() -> void:
	state = State.IDLE
	state_timer = randf_range(1.0, 3.0)


func _enter_wander() -> void:
	state = State.WANDER
	state_timer = 8.0
	# Evenings with a bandstand: everyone drifts over to listen and dance
	var stand: Vector3 = game.bandstand_spot() if game.has_method("bandstand_spot") else Vector3.INF
	if stand != Vector3.INF and Game.hour() >= 17.0 and randf() < 0.75:
		var ba := randf() * TAU
		target = stand + Vector3(cos(ba), 0, sin(ba)) * randf_range(3.6, 4.8)
		target.y = global_position.y
		state_timer = 14.0
		return
	# While the town hall is going up, villagers pop over to help
	var site: Vector3 = game.townhall.site_for_helpers() if game.get("townhall") else Vector3.INF
	if site != Vector3.INF and Game.hour() >= 8.0 and Game.hour() < 18.0 and randf() < 0.15:
		var ha := randf() * TAU
		target = site + Vector3(cos(ha), 0, sin(ha)) * randf_range(4.8, 5.6)
		target.y = global_position.y
		state_timer = 16.0
		return
	# Daily routine: at certain hours each villager has a favorite spot
	var spot := current_spot()
	if not spot.is_empty() and randf() < 0.65:
		var sa := randf() * TAU
		target = (spot[2] as Vector3) + Vector3(cos(sa), 0, sin(sa)) * 0.6
		target.y = global_position.y
		state_timer = 20.0
		return
	# Pick a spot that isn't inside a building or the pond
	for attempt in 10:
		var a := randf() * TAU
		target = Vector3(cos(a), 0, sin(a)) * sqrt(randf()) * world_half_size
		target.y = global_position.y
		if game.is_clear(target, 0.8):
			break


func is_available() -> bool:
	return state == State.IDLE or state == State.WANDER


func say(text: String, duration := LINE_TIME) -> void:
	bubble.text = text
	bubble.visible = true
	bubble_timer = duration


func celebrate() -> void:
	if partner != null:
		_end_chat()
	if state == State.HOME:
		_show(true)
		global_position = door_pos + Vector3(0, 1, 0)
	state = State.CELEBRATE


func stop_celebrating() -> void:
	if state == State.CELEBRATE:
		_enter_idle()


# ---------------------------------------------------------------- day & night

func _roll_schedule() -> void:
	bedtime = 20 * 60 + randi_range(0, 60)
	wake_time = 6 * 60 + 30 + randi_range(0, 60)


func go_home() -> void:
	if partner != null:
		var p := partner
		_end_chat()
		if is_instance_valid(p):
			p._end_chat()
	say(["Getting late. Good night!", "Time for bed.", "*yawn*"].pick_random(), 2.0)
	state = State.GO_HOME
	state_timer = 40.0


func _enter_home() -> void:
	state = State.HOME
	_stop()
	global_position = door_pos + Vector3(0, 1, 0)
	_show(false)


func _wake_up() -> void:
	global_position = door_pos + Vector3(0, 1, 0)
	velocity = Vector3.ZERO
	_show(true)
	_enter_idle()


## Called by the world when a new day starts (after you sleep).
func reset_for_morning() -> void:
	partner = null
	convo = []
	_roll_schedule()
	if state != State.CELEBRATE:
		_enter_home()


func _show(v: bool) -> void:
	visible = v
	collider.disabled = not v
	bubble.visible = false


# ---------------------------------------------------------------- NPC <-> NPC

func _try_start_chat() -> bool:
	if chat_cooldown > 0.0:
		return false
	chat_cooldown = randf_range(2.0, 4.0)   # retry soon if nobody is free
	var free := others.filter(func(n): return n.is_available())
	if free.is_empty():
		return false
	# Prefer someone nearby
	free.sort_custom(func(a, b):
		return a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position))
	var pick: CharacterBody3D = free[0] if randf() < 0.7 else free.pick_random()
	partner = pick
	is_initiator = true
	state = State.APPROACH
	state_timer = 12.0
	pick.accept_chat(self)
	return true


func accept_chat(from: CharacterBody3D) -> void:
	partner = from
	is_initiator = false
	state = State.APPROACH
	state_timer = 12.0


func _begin_convo() -> void:
	state = State.CHATTING
	var other_name: String = partner.npc_name
	var f: int = friendship.get(other_name, 0)
	var hello: String
	if f == 0:
		hello = "Hi, I'm %s. You're %s, right?" % [npc_name, other_name]
	elif f < 3:
		hello = "Hey %s!" % other_name
	else:
		hello = "%s, my friend! Good to see you again." % other_name
	convo = [[self, hello], [partner, partner.reply_greeting(self)]]

	var news := heard_helped.filter(func(n): return not partner.heard_helped.has(n))
	var q := quest
	if quest_state == Quest.ACTIVE and q.get("type", "") in ["collect", "dig", "deliver"]:
		# Ask around about our problem -- the other villager gives a real hint.
		convo.append([self, q["ask_npc"]])
		if q["type"] in ["collect", "dig"]:
			convo.append([partner, game.hint_for(q["item"], true)])
		else:
			convo.append([partner, (q["hint_npc"] as Array).pick_random()])
	elif not news.is_empty():
		# Spread the news that the player helped someone.
		var who: String = news[0]
		var told := "Did you hear? The traveler helped me!" if who == npc_name \
			else "Did you hear? The traveler helped %s!" % who
		convo.append([self, told])
		var reply: String
		if partner.heard_helped.has(partner.npc_name):
			reply = ["They helped me too! Such a kind traveler.", "Yes! They helped me as well."].pick_random()
		else:
			reply = ["Really? How kind!", "I hope they can help me too!"].pick_random()
		convo.append([partner, reply])
		partner.heard_helped.append(who)
		partner._save_progress()
	elif not Game.projects.is_empty() and randf() < 0.45:
		convo.append([self, project_gossip()])
		convo.append([partner, ["It really is lovely.", "The traveler paid for it, you know!", "Best village in the valley!"].pick_random()])
	else:
		convo.append([self, chat_lines.pick_random()])
		convo.append([partner, partner.chat_lines.pick_random()])
	convo.append([self, ["See you around!", "Anyway, I'd better go.", "Nice talking to you!"].pick_random()])
	convo_step = 0
	line_timer = 0.0


func reply_greeting(from: CharacterBody3D) -> String:
	var f: int = friendship.get(from.npc_name, 0)
	if f == 0:
		return "Nice to meet you, %s! I'm %s." % [from.npc_name, npc_name]
	elif f < 3:
		return "Oh, hi %s." % from.npc_name
	return "Always a pleasure, %s!" % from.npc_name


func _run_convo(delta: float) -> void:
	if partner == null or partner.state != State.CHATTING:
		_end_chat()
		return
	line_timer -= delta
	if line_timer > 0.0:
		return
	if convo_step >= convo.size():
		var p := partner
		_finish_chat_memory(p)
		p._finish_chat_memory(self)
		p._end_chat()
		_end_chat()
		return
	var speaker: CharacterBody3D = convo[convo_step][0]
	var text: String = convo[convo_step][1]
	speaker.say(text)
	# The listener remembers what they heard, to gossip about later
	var listener: CharacterBody3D = partner if speaker == self else self
	listener.last_heard = {"from": speaker.npc_name, "text": text}
	convo_step += 1
	line_timer = LINE_TIME


func _finish_chat_memory(other: CharacterBody3D) -> void:
	friendship[other.npc_name] = friendship.get(other.npc_name, 0) + 1
	_save_progress()


func _end_chat() -> void:
	partner = null
	is_initiator = false
	convo = []
	chat_cooldown = randf_range(4.0, 8.0)
	if state in [State.APPROACH, State.CHATTING, State.IDLE, State.WANDER]:
		_enter_wander()


# ---------------------------------------------------------------- Player <-> NPC

func can_talk() -> bool:
	return visible and state not in [State.FLEE, State.CELEBRATE, State.HOME, State.RACE]


func distance_to_player(player: Node3D) -> float:
	return global_position.distance_to(player.global_position)


func get_prompt(_player: Node3D) -> String:
	if not can_talk():
		return ""
	var t := "E: Talk to %s" % npc_name
	if can_receive_gift() and game.panels.has_giftables():
		t += "      G: Give a gift"
	return t


func interact(player: Node3D) -> void:
	player.start_dialogue(self)


## Called by the player. Returns the lines this villager will say.
func start_player_talk(player: Node3D) -> Array:
	# If we were chatting with another villager, politely excuse ourselves.
	if partner != null and is_instance_valid(partner):
		var p := partner
		p.say("Oh, I'll let you two talk.")
		p._end_chat()
	partner = null
	is_initiator = false
	convo = []
	var was_going_home := state == State.GO_HOME
	state = State.TALKING
	pending_action = ""
	visual.rotation.y = atan2(-(player.global_position.x - global_position.x),
		-(player.global_position.z - global_position.z))

	var out: Array = []
	var greeting: String = greetings[min(times_met_player, greetings.size() - 1)]
	if was_going_home:
		greeting = "Oh! I was just heading home. What is it?"
	var q := quest
	# chatting once a day makes you better friends
	var talked := Game.xdict("talked_day")
	if int(talked.get(npc_name, -1)) != Game.day:
		talked[npc_name] = Game.day
		Game.add_friendship(npc_name, VILLAGERS.TALK_POINTS)
	# handing in a request from the board comes first
	var board_req: Dictionary = game.board.deliverable(npc_name) if game.get("board") else {}
	if not board_req.is_empty():
		out.append("Is that my %s? You found %s!" % [Game.item_name(board_req["item"], int(board_req["count"]) > 1).to_lower(), "them" if int(board_req["count"]) > 1 else "it"])
		out.append_array(game.board.thanks_lines(board_req))
		pending_action = "board"
		board_pending_id = int(board_req["id"])
		times_met_player += 1
		_save_progress()
		return out
	# a heart event (a little story + a gift) when you reach 2, 5 or 8 hearts
	var ev := _pending_heart_event()
	var ready_to_turn_in: bool = quest_state == Quest.ACTIVE and _have_for_quest() >= int(q.get("count", 0)) and q.get("type", "") != "tag"
	if ev > 0 and not ready_to_turn_in and q.get("type", "") != "festival":
		out.append_array(data["events"][ev]["lines"])
		pending_action = "event_%d" % ev
		times_met_player += 1
		_save_progress()
		return out
	if is_birthday():
		out.append_array(data.get("birthday_lines", []))
		if int(Game.xdict("gift_day").get(npc_name, -1)) != Game.day:
			out.append("(A birthday gift would make my day!)")

	if all_quests_done():
		out.append(greeting)
		var others_helped := heard_helped.filter(func(n): return n != npc_name)
		if not others_helped.is_empty() and not Game.won:
			out.append("I heard you helped %s too. You're a real hero!" % others_helped.pick_random())
		out.append(lines.pick_random())
		out.append_array(personal_lines())
		if Game.won and not Game.projects.is_empty() and randf() < 0.6:
			out.append(project_gossip())
		if not last_heard.is_empty():
			out.append("I was just talking to %s. They said: \"%s\"" % [last_heard["from"], last_heard["text"]])
		var remaining: Array = game.villagers_needing_help()
		if not remaining.is_empty() and not Game.won:
			out.append("I think %s still needs help." % remaining.pick_random())

	elif quest_state == Quest.NOT_STARTED:
		if q["type"] == "festival" and not game.everyone_else_done(self):
			out.append(greeting)
			out.append_array(q["wait"])
		else:
			out.append(greeting)
			out.append_array(q["ask"])
			pending_action = "start_tag" if q["type"] == "tag" else "accept"

	else:   # ACTIVE
		var have := _have_for_quest()
		var need: int = q.get("count", 0)
		if have >= need and q.has("minigame"):
			# Items found -- now the fun part (baking, planting...)
			out.append_array(q["ask_minigame"])
			pending_action = "minigame"
		elif have >= need:
			out.append_array(q["thanks"])
			if q.get("reward", 0) > 0:
				out.append("Here, take %d coins as thanks." % q["reward"])
			if quest_index + 1 < quests.size() and quests[quest_index + 1]["type"] != "festival":
				out.append("Come talk to me again later -- I might need your help with something else.")
			pending_action = "complete"
		else:
			match q["type"]:
				"collect", "dig", "deliver":
					out.append("You've got %d of %d %s so far. Keep at it!" % [have, need, q["item_plural"]])
					if q["type"] == "dig":
						out.append("Watch the detector bar -- it beeps faster the closer you get.")
					if q["type"] in ["collect", "dig"]:
						out.append(game.hint_for(q["item"], false))
					else:
						out.append(q["hint_player"])
				"festival":
					out.append("We still need %d more coins for the festival." % (need - have))
					out.append("Sell fish and crops at the market -- the pumpkins fetch a fine price.")
			if randf() < 0.4:
				out.append_array(personal_lines())

	var open_req: Dictionary = game.board.open_for(npc_name) if game.get("board") else {}
	if not open_req.is_empty():
		out.append("Oh, and don't forget -- I'm waiting on %d %s from the board!" % [int(open_req["count"]), Game.item_name(open_req["item"], int(open_req["count"]) > 1).to_lower()])
	times_met_player += 1
	_save_progress()
	return out


func _have_for_quest() -> int:
	var q := quest
	match q.get("type", ""):
		"collect", "dig":
			return Game.count(q["item"])
		"deliver":
			return Game.count_kind("fish") if q["item"] == "any_fish" else Game.count(q["item"])
		"festival":
			return Game.coins
	return 0


func end_player_talk() -> void:
	bubble.visible = false
	chat_cooldown = randf_range(3.0, 6.0)
	_enter_idle()
	if Game.minutes >= bedtime:
		go_home()
	var q := quest
	match pending_action:
		"accept":
			quest_state = Quest.ACTIVE
			game.on_quest_accepted(self)
		"complete":
			_complete_quest()
		"board":
			game.board.complete(board_pending_id)
		"event_2", "event_5", "event_8":
			_finish_heart_event(int(pending_action.substr(6)))
		"minigame":
			game.start_minigame(self, q["minigame"])
		"start_tag":
			quest_state = Quest.ACTIVE
			state = State.FLEE
			flee_timer = q["time"]
			flee_grace = 2.0
			flee_dir = Vector3.ZERO
			last_flee_pos = global_position
			stumble_timer = randf_range(4.0, 6.0)
			say("You'll never catch me!", 2.0)
			game.on_quest_accepted(self)
	pending_action = ""
	_save_progress()


func _complete_quest() -> void:
	var q := quest
	match q["type"]:
		"collect", "dig":
			Game.remove_item(q["item"], q["count"])
		"deliver":
			if q["item"] == "any_fish":
				Game.remove_kind("fish", q["count"])
			else:
				Game.remove_item(q["item"], q["count"])
		"festival":
			Game.add_coins(-q["count"])
	if q.get("reward", 0) > 0:
		Game.add_coins(q["reward"])
	Game.add_friendship(npc_name, VILLAGERS.QUEST_POINTS)
	if not heard_helped.has(npc_name):
		heard_helped.append(npc_name)
	var finished := q
	quest_index += 1
	quest_state = Quest.NOT_STARTED
	_save_progress()
	game.on_quest_completed(self, finished)


## Called by the world when a quest minigame ends.
func minigame_finished(success: bool) -> void:
	var q := quest
	if success:
		say((q["thanks"] as Array).pick_random(), 3.5)
		_complete_quest()
	else:
		say(q["minigame_fail"], 4.0)
		game.hud.show_toast(q["minigame_fail"], 4.0)


# ---------------------------------------------------------------- Tag

func _run_flee(delta: float) -> void:
	flee_timer -= delta
	flee_grace -= delta
	game.hud.show_timer("Catch %s! %.1f" % [npc_name, max(flee_timer, 0.0)])
	var player: Node3D = game.player
	var to_player := player.global_position - global_position
	to_player.y = 0.0

	if to_player.length() < TAG_DISTANCE and flee_grace <= 0.0:
		_end_tag(true)
		return
	if flee_timer <= 0.0:
		_end_tag(false)
		return

	# Every few seconds, trip up for a moment -- that's your chance!
	stumble_timer -= delta
	if stumble_timer < 0.0:
		_stop()
		if stumble_timer > -delta:
			say(["Whoops!", "Oof!", "Eep!"].pick_random(), 0.8)
		if stumble_timer < -0.7:
			stumble_timer = randf_range(3.0, 4.5)
		return

	var away := _pick_flee_dir(-to_player.normalized())

	# Fallback: if he's barely moving (wedged somewhere), bolt in a random direction briefly
	dodge_timer -= delta
	if global_position.distance_to(last_flee_pos) < FLEE_SPEED * delta * 0.3:
		stuck_time += delta
	else:
		stuck_time = 0.0
	last_flee_pos = global_position
	if stuck_time > 0.25 and dodge_timer <= 0.0:
		dodge_dir = Vector3(randf() - 0.5, 0, randf() - 0.5).normalized()
		dodge_timer = 0.5
	if dodge_timer > 0.0:
		away = dodge_dir
	flee_dir = away
	velocity.x = away.x * FLEE_SPEED
	velocity.z = away.z * FLEE_SPEED
	_face(global_position + away)


func _end_tag(caught: bool) -> void:
	game.hud.hide_timer()
	_stop()
	if caught:
		say("Aww, you got me! Nice one!", 3.0)
		_enter_idle()
		_complete_quest()
	else:
		say("Ha! Too slow! Talk to me to try again.", 3.0)
		quest_state = Quest.NOT_STARTED
		_save_progress()
		_enter_idle()
		game.hud.show_toast("%s got away! Talk to %s to try again." % [npc_name, npc_name])
		game.update_quest_log()


## Tries 16 directions and picks the one that best gets away from the player
## without running into the edge of the world, buildings, trees or villagers.
func _pick_flee_dir(away: Vector3) -> Vector3:
	var here := Vector3(global_position.x, 0, global_position.z)
	var obstacles: Array = []
	for n in others:
		if n.visible:
			obstacles.append([Vector3(n.global_position.x, 0, n.global_position.z), 0.6])
	for lm in game.landmarks:
		obstacles.append([lm["pos"] * Vector3(1, 0, 1), lm["radius"]])
	var best := away
	var best_score := -INF
	for i in 16:
		var a := TAU * i / 16.0
		var d := Vector3(sin(a), 0, cos(a))
		var score := d.dot(away) + d.dot(flee_dir) * 0.3
		for look in [1.5, 3.5]:
			var p: Vector3 = here + d * look
			if Vector2(p.x, p.z).length() > world_half_size:
				score -= 1.5
			for ob in obstacles:
				if p.distance_to(ob[0]) < ob[1] + 0.8:
					score -= 1.5
		if score > best_score:
			best_score = score
			best = d
	return best


# ---------------------------------------------------------------- after the festival

## Something nice to say about a village project the player has funded.
func project_gossip() -> String:
	var lines_for := {
		"gardens": ["Have you smelled the new flower beds? Heavenly.", "The gardens make the whole square feel brighter."],
		"fountain": ["I tossed a coin in the fountain and made a wish!", "The sound of the fountain helps me nap."],
		"bandstand": ["See you at the bandstand tonight? There's dancing!", "My feet still hurt from dancing at the bandstand."],
		"statue": ["Every morning I salute the golden statue.", "That statue is SO shiny. Just like the real hero!"],
	}
	var funded: Array = []
	for id in Game.projects:
		if Game.is_project_funded(id):
			funded.append(id)
	if funded.is_empty():
		return "I hear there are plans to fix up the village. Exciting!"
	return (lines_for.get(funded.pick_random(), ["The village looks wonderful these days."]) as Array).pick_random()


func _near_bandstand() -> bool:
	var stand: Vector3 = game.bandstand_spot() if game.has_method("bandstand_spot") else Vector3.INF
	return stand != Vector3.INF and Vector2(global_position.x - stand.x, global_position.z - stand.z).length() < 6.0


# ---------------------------------------------------------------- racing (Pip)

var board_pending_id := -1
var race_points: Array = []
var race_index := 0
var race_speed := 4.5
var race_done_cb: Callable


## Run through the checkpoints; calls done() when crossing the last one.
func start_race(points: Array, speed: float, done: Callable) -> void:
	if partner != null and is_instance_valid(partner):
		var p := partner
		_end_chat()
		p._end_chat()
	partner = null
	race_points = points
	race_index = 0
	race_speed = speed
	race_done_cb = done
	_show(true)
	state = State.RACE


func stop_race() -> void:
	if state == State.RACE:
		race_points = []
		_enter_idle()


func _run_race() -> void:
	if race_points.is_empty():
		_stop()   # on the start line, waiting for GO
		return
	var p: Vector3 = race_points[race_index]
	if _move_toward(p, race_speed) < 1.2:
		race_index += 1
		if race_index >= race_points.size():
			race_points = []
			_stop()
			if race_done_cb.is_valid():
				race_done_cb.call()


# ---------------------------------------------------------------- friendship & personality

var data: Dictionary:
	get:
		return VILLAGERS.of(npc_name)


func is_birthday() -> bool:
	return int(data.get("birthday", -1)) == Game.day_of_season()


## [from, to, position, activity] for right now, or [].
func current_spot() -> Array:
	var h := Game.hour()
	for sp in data.get("spots", []):
		if h >= sp[0] and h < sp[1]:
			return sp
	return []


func _near_site() -> bool:
	var site: Vector3 = game.townhall.site_for_helpers() if game.get("townhall") else Vector3.INF
	return site != Vector3.INF and Vector2(global_position.x - site.x, global_position.z - site.z).length() < 6.5


func _at_spot() -> bool:
	var sp := current_spot()
	if sp.is_empty():
		return false
	var p: Vector3 = sp[2]
	return Vector2(global_position.x - p.x, global_position.z - p.z).length() < 1.6


## A line that depends on how well they know you, and sometimes what they
## think of another villager.
func personal_lines() -> Array:
	var out := []
	var hl: Dictionary = data.get("hearts_lines", {})
	var hearts := Game.hearts(npc_name)
	var pool := []
	for tier in hl:
		if hearts >= int(tier):
			pool.append_array(hl[tier])
	if not pool.is_empty():
		out.append(pool.pick_random())
	var ops: Dictionary = data.get("opinions", {})
	if not ops.is_empty() and randf() < 0.35:
		out.append(ops[ops.keys().pick_random()])
	return out


func _pending_heart_event() -> int:
	var seen: Array = Game.xdict("events_seen").get(npc_name, [])
	var hearts := Game.hearts(npc_name)
	for lvl in VILLAGERS.HEART_EVENTS:
		if hearts >= lvl and not seen.has(lvl) and data.get("events", {}).has(lvl):
			return lvl
	return 0


func _finish_heart_event(lvl: int) -> void:
	var seen_all := Game.xdict("events_seen")
	var seen: Array = seen_all.get(npc_name, [])
	if seen.has(lvl):
		return
	seen.append(lvl)
	seen_all[npc_name] = seen
	var ev: Dictionary = data["events"][lvl]
	var msg := ""
	if ev.has("items"):
		var parts := []
		for id in ev["items"]:
			Game.add_item(id, ev["items"][id])
			parts.append("%d %s" % [ev["items"][id], Game.item_name(id, ev["items"][id] > 1).to_lower()])
		msg = "%s gave you %s!" % [npc_name, ", ".join(parts)]
	elif ev.has("recipe"):
		Game.xarr("recipes").append(ev["recipe"])
		msg = "%s taught you a secret recipe: %s! Cook it at your stove." % [npc_name, Game.item_name(ev["recipe"])]
	elif ev.has("hat"):
		if not Game.hats_owned.has(ev["hat"]):
			Game.hats_owned.append(ev["hat"])
		var hat_name := ev["hat"] as String
		for hh in Game.HATS:
			if hh["id"] == ev["hat"]:
				hat_name = hh["name"]
		msg = "%s gave you %s! Wear it from the Hats tab at the market." % [npc_name, hat_name]
	Audio.play("quest")
	game.hud.show_toast(msg, 5.0)


func can_receive_gift() -> bool:
	return can_talk() and int(Game.xdict("gift_day").get(npc_name, -1)) != Game.day


## Give an item. Returns what they say about it.
func receive_gift(item: String) -> String:
	var taste := VILLAGERS.taste(npc_name, item)
	var pts: int = VILLAGERS.GIFT_POINTS[taste]
	var bday := is_birthday()
	if bday and pts > 0:
		pts *= 2
	Game.remove_item(item, 1)
	Game.add_friendship(npc_name, pts)
	Game.xdict("gift_day")[npc_name] = Game.day
	var known := Game.xdict("known_likes")
	var k: Array = known.get(npc_name, [])
	if not k.has(item):
		k.append(item)
	known[npc_name] = k
	var line: String = (data.get("reactions", {}).get(taste, ["Thank you!"]) as Array).pick_random()
	if bday and pts > 0:
		line += " And on my birthday, too!"
	Audio.play("ding" if pts > 0 else "fail")
	return line
