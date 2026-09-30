extends "res://scripts/house_games.gd"
## More minigames (same window and look as the others):
##   "music" -- pick an instrument (piano, guitar, flute), then:
##              * a song: notes fall down 4 lanes; hit D F J K (or 1-4) as they
##                cross the line. Each note plays its real pitch, so you're
##                playing the melody. Result: {"song", "score", "accuracy"}.
##              * freestyle: play any notes on a keyboard (A S D F G H J K for
##                the white keys, W E T Y U for the black ones), Z/X change
##                octave, Q changes instrument, R records and P plays it back.
##   "skip"  -- rock skipping at the pond: stop the angle needle, then the power
##              bar; 5 throws. Result: best number of skips.
##   "stars" -- stargazing: find the constellation (shown on the card) hidden
##              among the stars and click its stars. Result: [names found].

# ================================================================ music data

## Songs: notes are "NAME:beats" ("R" = a rest). bass = one root note per bar.
const SONGS := [
	{"id": "waltz", "name": "Village Waltz", "level": "Easy", "bpm": 112, "bar": 3,
		"notes": "E4:1 G4:1 G4:1 A4:1 G4:1 E4:1 D4:1 E4:1 F4:1 E4:3 E4:1 G4:1 C5:1 B4:1 A4:1 G4:1 F4:1 A4:1 G4:1 C4:3",
		"bass": [48, 53, 55, 48, 48, 55, 53, 48]},
	{"id": "jig", "name": "Harvest Jig", "level": "Medium", "bpm": 128, "bar": 4,
		"notes": "G4:0.5 A4:0.5 B4:0.5 G4:0.5 C5:1 G4:1 E4:0.5 F4:0.5 G4:0.5 E4:0.5 D4:2 G4:0.5 A4:0.5 B4:0.5 C5:0.5 D5:1 B4:1 C5:0.5 B4:0.5 A4:0.5 F4:0.5 G4:2 C5:0.5 B4:0.5 A4:0.5 G4:0.5 F4:0.5 E4:0.5 D4:1 E4:0.5 G4:0.5 C5:0.5 G4:0.5 C4:2",
		"bass": [48, 48, 55, 55, 55, 55, 53, 55, 53, 48, 48, 48]},
	{"id": "moon", "name": "Moonlit Sea", "level": "Hard", "bpm": 104, "bar": 4,
		"notes": "A4:0.75 C5:0.25 E5:1 D5:0.5 C5:0.5 B4:1 C5:0.5 A4:0.5 E4:0.75 A4:0.25 C5:1 B4:1 G4:0.75 B4:0.25 D5:1 C5:0.5 B4:0.5 A4:1 G4:0.5 E4:0.5 F4:0.75 A4:0.25 C5:0.5 F5:0.5 E5:0.5 D5:0.25 C5:0.25 B4:1 A4:0.5 B4:0.5 C5:0.5 E5:0.5 D5:0.5 B4:0.5 A4:2",
		"bass": [45, 45, 52, 52, 43, 43, 53, 52, 45]},
]
const NOTE_NAMES := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
const INSTRUMENT_NAMES := {"piano": "Piano", "guitar": "Guitar", "flute": "Flute"}
const LANE_KEYS := ["D", "F", "J", "K"]
const LANE_COLORS := [Color(1, 0.45, 0.45), Color(1, 0.8, 0.3), Color(0.45, 0.85, 0.5), Color(0.45, 0.65, 1)]
const LANE_W := 78.0
const LANE_H := 340.0
const HIT_Y := 300.0
const FALL := 280.0        # pixels per second
const LEAD_IN := 2.0

var music_place := "home"   # "home" or "bandstand" (set by whoever opens the game)
var instrument := "piano"
var music_mode := ""        # menu / song / free / result
var song: Dictionary = {}
var song_notes: Array = []  # {"t", "midi", "lane", "rect", "judged"}
var song_time := 0.0
var song_end := 0.0
var song_score := 0
var song_combo := 0
var song_best_combo := 0
var next_bar := 0
var lane_area: Control
var judge_label: Label
var score_label: Label
var lane_flash: Array = []

# freestyle
const WHITE_KEYS := [KEY_A, KEY_S, KEY_D, KEY_F, KEY_G, KEY_H, KEY_J, KEY_K]
const WHITE_SEMIS := [0, 2, 4, 5, 7, 9, 11, 12]
const BLACK_KEYS := [KEY_W, KEY_E, KEY_T, KEY_Y, KEY_U]
const BLACK_SEMIS := [1, 3, 6, 8, 10]
var octave := 0
var free_keys := {}          # semitone -> key Panel
var recording := false
var rec_start := 0.0
var rec_notes: Array = []    # [time, midi]
var free_time := 0.0
var free_info: Label
var playback_token := 0


func _setup_kind() -> void:
	match kind:
		"music":
			_setup_music()
		"skip":
			_setup_skip()
		"stars":
			_setup_stars()
		"chop":
			_setup_chop()
		"mine":
			_setup_mine()
		_:
			super._setup_kind()


func _run_kind(delta: float) -> void:
	match kind:
		"music":
			_run_music(delta)
		"skip":
			_run_skip(delta)
		"stars":
			_run_stars(delta)
		"chop":
			_run_chop(delta)
		"mine":
			_run_mine(delta)
		_:
			super._run_kind(delta)


func _input_kind(event: InputEvent) -> void:
	match kind:
		"music":
			_music_input(event)
		"skip":
			if event.is_action_pressed("reel"):
				get_viewport().set_input_as_handled()
				_skip_press()
		"stars":
			pass
		"chop", "mine":
			if event.is_action_pressed("reel"):
				get_viewport().set_input_as_handled()
				if kind == "chop":
					_chop_press()
				else:
					_mine_press()
		_:
			super._input_kind(event)


func _rebuild_window(title: String, subtitle: String, accent: Color, icon: String, icon_color := Color.WHITE) -> void:
	for c in root.get_children():
		c.queue_free()
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	root.add_child(content)
	_frame(title, subtitle, accent, icon, icon_color)


func _recenter() -> void:
	await get_tree().process_frame
	if not visible:
		return
	root.reset_size()
	root.position = (root.get_viewport_rect().size - root.size) / 2


static func parse_notes(text: String) -> Array:
	var out := []
	var beat := 0.0
	for tok in text.split(" ", false):
		var parts := tok.split(":")
		var nm: String = parts[0]
		var dur := float(parts[1])
		if nm != "R":
			var midi: int = 12 * (int(nm.substr(1)) + 1) + int(NOTE_NAMES[nm.substr(0, 1)])
			out.append([beat, midi])
		beat += dur
	return out


func owned_instruments() -> Array:
	var out := ["piano"]
	for i in ["guitar", "flute"]:
		if Game.upgrades.get(i, false):
			out.append(i)
	return out


# ================================================================ music: menu

func _setup_music() -> void:
	if not instrument in owned_instruments():
		instrument = "piano"
	_music_menu()


func _music_menu() -> void:
	music_mode = "menu"
	playback_token += 1
	_rebuild_window("Music Time!", "Pick an instrument, then play a song or just jam in freestyle.",
		Color(0.55, 0.35, 0.7), "note", Color(1, 0.85, 0.5))
	body.custom_minimum_size = Vector2(520, 0)
	var inst_row := HBoxContainer.new()
	inst_row.alignment = BoxContainer.ALIGNMENT_CENTER
	inst_row.add_theme_constant_override("separation", 10)
	content.add_child(inst_row)
	content.move_child(inst_row, 1)
	for inst in ["piano", "guitar", "flute"]:
		var owned: bool = inst in owned_instruments()
		var b := Button.new()
		b.custom_minimum_size = Vector2(160, 70)
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = not owned
		var col := Color(0.6, 0.45, 0.8) if inst == instrument else (Color(0.35, 0.28, 0.4) if owned else Color(0.2, 0.17, 0.2))
		for st in ["normal", "hover", "pressed", "disabled"]:
			b.add_theme_stylebox_override(st, UI.pad_style(col))
		var ic := ICON.new(inst, Color.WHITE, 42.0)
		ic.position = Vector2(8, 14)
		b.add_child(ic)
		var l := UI.small_label(INSTRUMENT_NAMES[inst] + ("" if owned else "\n(market)"), UI.CREAM if owned else UI.MUTED, 16)
		l.position = Vector2(58, 14 if owned else 8)
		b.add_child(l)
		b.pressed.connect(func():
			instrument = inst
			Audio.play_note(instrument, 67)
			_music_menu())
		inst_row.add_child(b)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	content.add_child(list)
	content.move_child(list, 2)
	var best: Dictionary = Game.xdict("music_best")
	for i in SONGS.size():
		var sg: Dictionary = SONGS[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(520, 46)
		b.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed"]:
			b.add_theme_stylebox_override(st, UI.pad_style(Color(0.4, 0.28, 0.18)))
		var kb := UI.key_badge(str(i + 1))
		kb.position = Vector2(10, 11)
		b.add_child(kb)
		var bs := int(best.get(sg["name"], 0))
		var l := UI.small_label("%s  (%s)" % [sg["name"], sg["level"]], UI.CREAM, 17)
		l.position = Vector2(46, 4)
		b.add_child(l)
		var l2 := UI.small_label("Best: %d" % bs if bs > 0 else "Not played yet", UI.MUTED, 12)
		l2.position = Vector2(46, 26)
		b.add_child(l2)
		b.pressed.connect(func():
			if grace <= 0.0:
				_start_song(i))
		list.add_child(b)
	var fb := Button.new()
	fb.custom_minimum_size = Vector2(520, 46)
	fb.focus_mode = Control.FOCUS_NONE
	for st in ["normal", "hover", "pressed"]:
		fb.add_theme_stylebox_override(st, UI.pad_style(Color(0.3, 0.4, 0.55)))
	var fk := UI.key_badge("4")
	fk.position = Vector2(10, 11)
	fb.add_child(fk)
	var fl := UI.small_label("Freestyle  -  play whatever you like!", UI.CREAM, 17)
	fl.position = Vector2(46, 12)
	fb.add_child(fl)
	fb.pressed.connect(func():
		if grace <= 0.0:
			_start_free())
	list.add_child(fb)
	var close := Button.new()
	close.text = "Done  (Esc)"
	close.custom_minimum_size = Vector2(180, 36)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(func(): _finish({}))
	content.add_child(close)
	var paid: bool = Game.xi("music_day", -1) == Game.day
	status.text = "Songs pay up to 60 coins once a day." if not paid else "You've already been paid today -- play for fun!"
	_recenter()


func _music_input(event: InputEvent) -> void:
	match music_mode:
		"menu":
			if event.is_action_pressed("pause"):
				get_viewport().set_input_as_handled()
				_finish({})
				return
			for i in SONGS.size():
				if event.is_action_pressed("choice_%d" % (i + 1)):
					get_viewport().set_input_as_handled()
					_start_song(i)
					return
			if event.is_action_pressed("choice_4"):
				get_viewport().set_input_as_handled()
				_start_free()
			elif event.is_action_pressed("cycle_seed"):
				var owned := owned_instruments()
				instrument = owned[(owned.find(instrument) + 1) % owned.size()]
				_music_menu()
		"song":
			if event.is_action_pressed("pause"):
				get_viewport().set_input_as_handled()
				_music_menu()
				return
			for l in 4:
				if event.is_action_pressed("lane_%d" % (l + 1)):
					get_viewport().set_input_as_handled()
					_lane_press(l)
		"free":
			if event.is_action_pressed("pause"):
				get_viewport().set_input_as_handled()
				_music_menu()
				return
			if event is InputEventKey and event.pressed and not event.echo:
				get_viewport().set_input_as_handled()
				_free_key(event.physical_keycode)
		"result":
			if event.is_action_pressed("pause") or event.is_action_pressed("interact"):
				get_viewport().set_input_as_handled()
				_music_menu()


# ================================================================ music: song

func _start_song(i: int) -> void:
	song = SONGS[i]
	music_mode = "song"
	_rebuild_window(song["name"], "Hit D F J K (or 1-4) as the notes cross the line. Esc to stop.",
		Color(0.55, 0.35, 0.7), instrument, Color.WHITE)
	body.custom_minimum_size = Vector2(LANE_W * 4 + 170, LANE_H)
	lane_area = Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.08, 0.06, 0.1)
	ps.set_corner_radius_all(10)
	lane_area.add_theme_stylebox_override("panel", ps)
	lane_area.size = Vector2(LANE_W * 4, LANE_H)
	lane_area.clip_contents = true
	body.add_child(lane_area)
	lane_flash = []
	for l in 4:
		var lane := ColorRect.new()
		lane.color = Color(LANE_COLORS[l], 0.08)
		lane.position = Vector2(l * LANE_W + 2, 0)
		lane.size = Vector2(LANE_W - 4, LANE_H)
		lane_area.add_child(lane)
		lane_flash.append(lane)
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.8)
	line.position = Vector2(0, HIT_Y)
	line.size = Vector2(LANE_W * 4, 3)
	lane_area.add_child(line)
	for l in 4:
		var kb := UI.key_badge(LANE_KEYS[l])
		kb.position = Vector2(l * LANE_W + LANE_W / 2 - 12, HIT_Y + 10)
		lane_area.add_child(kb)
	score_label = UI.small_label("Score 0", UI.GOLD, 22)
	score_label.position = Vector2(LANE_W * 4 + 18, 10)
	body.add_child(score_label)
	judge_label = UI.small_label("", UI.CREAM, 28)
	judge_label.position = Vector2(LANE_W * 4 + 18, 120)
	body.add_child(judge_label)
	# notes -> lanes by pitch (low pitches left, high right)
	var parsed := parse_notes(song["notes"])
	var pitches := []
	for n in parsed:
		if not pitches.has(n[1]):
			pitches.append(n[1])
	pitches.sort()
	var spb: float = 60.0 / float(song["bpm"])
	song_notes = []
	for n in parsed:
		var lane: int = min(3, int(pitches.find(n[1]) * 4.0 / pitches.size()))
		var r := Panel.new()
		var rs := StyleBoxFlat.new()
		rs.bg_color = LANE_COLORS[lane]
		rs.set_corner_radius_all(8)
		rs.border_color = LANE_COLORS[lane].lightened(0.4)
		rs.set_border_width_all(2)
		r.add_theme_stylebox_override("panel", rs)
		r.size = Vector2(LANE_W - 14, 20)
		r.position = Vector2(lane * LANE_W + 7, -40)
		lane_area.add_child(r)
		song_notes.append({"t": LEAD_IN + float(n[0]) * spb, "midi": n[1], "lane": lane, "rect": r, "judged": false})
	var total_beats := 0.0
	for tok in (song["notes"] as String).split(" ", false):
		total_beats += float(tok.split(":")[1])
	song_end = LEAD_IN + total_beats * spb + 1.5
	song_time = 0.0
	song_score = 0
	song_combo = 0
	song_best_combo = 0
	next_bar = 0
	status.text = "Get ready..."
	_set_pips([])
	_recenter()


func _run_music(delta: float) -> void:
	if music_mode == "free":
		free_time += delta
		return
	if music_mode != "song":
		return
	song_time += delta
	var spb: float = 60.0 / float(song["bpm"])
	# accompaniment: a soft bass note and chord at the start of each bar
	var bar_len: float = spb * float(song["bar"])
	var bass: Array = song["bass"]
	while next_bar < bass.size() and song_time >= LEAD_IN + next_bar * bar_len:
		var root_note: int = bass[next_bar]
		Audio.play_note("piano", root_note, -14.0)
		Audio.play_note("piano", root_note + 12 + (3 if song["id"] == "moon" else 4), -18.0)
		next_bar += 1
	for n in song_notes:
		if n["judged"]:
			continue
		var y: float = HIT_Y - (float(n["t"]) - song_time) * FALL - 10.0
		(n["rect"] as Panel).position.y = y
		if song_time - float(n["t"]) > 0.2:
			n["judged"] = true
			(n["rect"] as Panel).modulate = Color(1, 1, 1, 0.25)
			_judge("Miss", Color(0.8, 0.5, 0.5))
			song_combo = 0
	status.text = "Combo %d" % song_combo if song_time > LEAD_IN else "Get ready..."
	if song_time >= song_end:
		_song_result()


func _lane_press(lane: int) -> void:
	var flash: ColorRect = lane_flash[lane]
	flash.color = Color(LANE_COLORS[lane], 0.35)
	var tw := flash.create_tween()
	tw.tween_property(flash, "color", Color(LANE_COLORS[lane], 0.08), 0.2)
	var best = null
	var bd := 1.0
	for n in song_notes:
		if not n["judged"] and n["lane"] == lane:
			var dt: float = abs(float(n["t"]) - song_time)
			if dt < bd:
				bd = dt
				best = n
	if best == null or bd > 0.2:
		Audio.play_note(instrument, 60 + [0, 4, 7, 12][lane], -12.0)
		return
	best["judged"] = true
	Audio.play_note(instrument, best["midi"])
	var r: Panel = best["rect"]
	var rt := r.create_tween().set_parallel(true)
	rt.tween_property(r, "scale", Vector2(1.3, 1.3), 0.15)
	rt.tween_property(r, "modulate:a", 0.0, 0.15)
	if bd < 0.07:
		song_score += 300
		_judge("Perfect!", Color(1, 0.9, 0.4))
	elif bd < 0.13:
		song_score += 200
		_judge("Great!", Color(0.6, 1, 0.6))
	else:
		song_score += 100
		_judge("OK", Color(0.7, 0.85, 1))
	song_combo += 1
	song_best_combo = max(song_best_combo, song_combo)
	if song_combo >= 10:
		song_score += 20    # combo bonus
	score_label.text = "Score %d" % song_score


func _judge(word: String, color: Color) -> void:
	judge_label.text = word
	judge_label.add_theme_color_override("font_color", color)
	judge_label.modulate.a = 1.0
	var tw := judge_label.create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(judge_label, "modulate:a", 0.0, 0.3)
	# villagers nearby enjoy the music
	if music_place == "bandstand" and word != "Miss" and randf() < 0.05:
		_npc_cheer()


func _song_result() -> void:
	music_mode = "result"
	var max_score := song_notes.size() * 300
	var acc := clampf(float(min(song_score, max_score)) / max_score, 0.0, 1.0)
	var grade := "S" if acc >= 0.95 else ("A" if acc >= 0.85 else ("B" if acc >= 0.7 else ("C" if acc >= 0.5 else "D")))
	var best := Game.xdict("music_best")
	var record := song_score > int(best.get(song["name"], 0))
	if record:
		best[song["name"]] = song_score
	var coins := 0
	if Game.xi("music_day", -1) != Game.day and acc >= 0.3:
		coins = int(round(acc * 60.0))
		Game.extra["music_day"] = Game.day
		Game.add_coins(coins)
	Audio.play("win" if acc >= 0.7 else "quest")
	for n in song_notes:
		(n["rect"] as Panel).queue_free()
	song_notes = []
	var msg := "Grade %s!  Score %d  (%d%%)  Best combo %d" % [grade, song_score, int(acc * 100), song_best_combo]
	if record:
		msg += "\nNew best!"
	if coins > 0:
		msg += "\n+%d coins from your audience" % coins
	judge_label.text = ""
	UI.banner(root, "Grade " + grade, Color(1, 0.85, 0.4))
	status.text = msg + "\n(Esc or E to go back)"
	if music_place == "bandstand":
		for i in 3:
			_npc_cheer()


func _npc_cheer() -> void:
	var w = get_parent()
	if w == null or not ("npcs" in w):
		return
	for n in w.npcs:
		if n.visible and n.global_position.distance_to(w.player.global_position) < 14.0 and randf() < 0.5:
			n.say(["Bravo!", "What a tune!", "Encore!", "*claps*", "Lovely!"].pick_random(), 2.0)
			n.velocity.y = 4.0
			return


# ================================================================ music: freestyle

func _start_free() -> void:
	music_mode = "free"
	free_time = 0.0
	recording = false
	rec_notes = []
	octave = 0
	_rebuild_window("Freestyle", "White keys: A S D F G H J K    Black keys: W E T Y U    Z / X: octave    Q: instrument    R: record    P: play back    Esc: back",
		Color(0.3, 0.45, 0.65), instrument, Color.WHITE)
	body.custom_minimum_size = Vector2(560, 210)
	free_keys = {}
	for i in 8:
		var k := Panel.new()
		var ks := StyleBoxFlat.new()
		ks.bg_color = Color(0.97, 0.97, 0.95)
		ks.set_corner_radius_all(6)
		ks.border_color = Color(0.3, 0.3, 0.3)
		ks.set_border_width_all(2)
		k.add_theme_stylebox_override("panel", ks)
		k.position = Vector2(20 + i * 65, 20)
		k.size = Vector2(62, 170)
		body.add_child(k)
		var kl := UI.small_label(OS.get_keycode_string(WHITE_KEYS[i]), Color(0.3, 0.3, 0.3), 16)
		kl.position = Vector2(24, 140)
		k.add_child(kl)
		free_keys[WHITE_SEMIS[i]] = k
	var black_x := [0.7, 1.7, 3.7, 4.7, 5.7]
	for i in 5:
		var k := Panel.new()
		var ks := StyleBoxFlat.new()
		ks.bg_color = Color(0.12, 0.12, 0.14)
		ks.set_corner_radius_all(5)
		k.add_theme_stylebox_override("panel", ks)
		k.position = Vector2(20 + black_x[i] * 65, 20)
		k.size = Vector2(40, 105)
		body.add_child(k)
		var kl := UI.small_label(OS.get_keycode_string(BLACK_KEYS[i]), Color(0.85, 0.85, 0.85), 14)
		kl.position = Vector2(13, 80)
		k.add_child(kl)
		free_keys[BLACK_SEMIS[i]] = k
	free_info = UI.small_label("", UI.CREAM, 16)
	free_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(free_info)
	content.move_child(free_info, 2)
	_free_status()
	status.text = "Jam away!" if music_place != "bandstand" else "The villagers are listening..."
	_set_pips([])
	_recenter()


func _free_status() -> void:
	var rec := "  |  RECORDING (R to stop)" if recording else ("  |  %d notes recorded (P to play)" % rec_notes.size() if not rec_notes.is_empty() else "")
	free_info.text = "%s   |   octave %+d%s" % [INSTRUMENT_NAMES[instrument], octave, rec]


func _free_key(code: int) -> void:
	var semi := -1
	var wi := WHITE_KEYS.find(code)
	if wi >= 0:
		semi = WHITE_SEMIS[wi]
	var bi := BLACK_KEYS.find(code)
	if bi >= 0:
		semi = BLACK_SEMIS[bi]
	if semi >= 0:
		var midi := 60 + semi + octave * 12
		free_note(midi, semi)
		return
	match code:
		KEY_Z:
			octave = max(octave - 1, -1)
		KEY_X:
			octave = min(octave + 1, 1)
		KEY_Q:
			var owned := owned_instruments()
			instrument = owned[(owned.find(instrument) + 1) % owned.size()]
			Audio.play_note(instrument, 67)
		KEY_R:
			recording = not recording
			if recording:
				rec_notes = []
				rec_start = free_time
			Audio.play("click")
		KEY_P:
			_playback()
	_free_status()


func free_note(midi: int, semi: int) -> void:
	Audio.play_note(instrument, midi)
	if recording:
		rec_notes.append([free_time - rec_start, midi])
	var k: Panel = free_keys.get(semi)
	if k:
		k.modulate = Color(1.0, 0.75, 0.45)
		var tw := k.create_tween()
		tw.tween_property(k, "modulate", Color.WHITE, 0.25)
		var n := ICON.new("note", LANE_COLORS[semi % 4], 26.0)
		n.position = k.position + Vector2(k.size.x / 2 - 13, -10)
		body.add_child(n)
		var nt := n.create_tween().set_parallel(true)
		nt.tween_property(n, "position:y", n.position.y - 60, 0.8)
		nt.tween_property(n, "modulate:a", 0.0, 0.8)
		nt.chain().tween_callback(n.queue_free)
	if music_place == "bandstand" and randf() < 0.04:
		_npc_cheer()


func _playback() -> void:
	if rec_notes.is_empty():
		return
	recording = false
	playback_token += 1
	var token := playback_token
	var last := 0.0
	for n in rec_notes:
		await get_tree().create_timer(max(float(n[0]) - last, 0.0)).timeout
		if token != playback_token or music_mode != "free":
			return
		last = float(n[0])
		var midi: int = n[1]
		free_note(midi, (midi - 60) - octave * 12 if free_keys.has((midi - 60) - octave * 12) else ((midi - 60) % 12 + 12) % 12)


# ================================================================ rock skipping

const SKIP_THROWS := 5
var skip_phase := ""         # angle / power / flying / wait
var skip_angle := 0.0
var skip_angle_t := 0.0
var skip_power := 0.0
var skip_power_t := 0.0
var skip_throw := 0
var skip_best := 0
var skip_counts: Array = []
var skip_view: Control
var skip_stone: Control
var skip_needle: ColorRect
var skip_power_fill: ColorRect
var skip_dial: Control


func _setup_skip() -> void:
	_frame("Stone Skipping", "Stop the needle at a low angle, then the power bar near the top. Aim for the green!",
		Color(0.3, 0.55, 0.65), "stone")
	body.custom_minimum_size = Vector2(520, 230)
	skip_view = Panel.new()
	var vs := StyleBoxFlat.new()
	vs.bg_color = Color(0.6, 0.8, 0.95)
	vs.set_corner_radius_all(12)
	skip_view.add_theme_stylebox_override("panel", vs)
	skip_view.size = Vector2(520, 150)
	skip_view.clip_contents = true
	body.add_child(skip_view)
	var water := ColorRect.new()
	water.color = Color(0.25, 0.5, 0.7)
	water.position = Vector2(0, 100)
	water.size = Vector2(520, 50)
	skip_view.add_child(water)
	var bank := ColorRect.new()
	bank.color = Color(0.4, 0.6, 0.3)
	bank.position = Vector2(0, 90)
	bank.size = Vector2(46, 60)
	skip_view.add_child(bank)
	skip_stone = ICON.new("stone", Color.WHITE, 22.0)
	skip_stone.position = Vector2(30, 80)
	skip_view.add_child(skip_stone)
	# angle dial (left) and power bar (right)
	skip_dial = Panel.new()
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(0.1, 0.07, 0.05)
	ds.set_corner_radius_all(8)
	skip_dial.add_theme_stylebox_override("panel", ds)
	skip_dial.position = Vector2(0, 160)
	skip_dial.size = Vector2(250, 64)
	body.add_child(skip_dial)
	var good_a := ColorRect.new()
	good_a.color = Color(0.4, 0.9, 0.45, 0.8)
	good_a.position = Vector2(10 + 12.0 / 45.0 * 230, 8)
	good_a.size = Vector2(12.0 / 45.0 * 230, 30)
	skip_dial.add_child(good_a)
	skip_needle = ColorRect.new()
	skip_needle.color = Color.WHITE
	skip_needle.size = Vector2(5, 40)
	skip_dial.add_child(skip_needle)
	var al := UI.small_label("angle  (flat -> steep)", UI.MUTED, 12)
	al.position = Vector2(10, 44)
	skip_dial.add_child(al)
	var pbg := Panel.new()
	pbg.add_theme_stylebox_override("panel", ds)
	pbg.position = Vector2(270, 160)
	pbg.size = Vector2(250, 64)
	body.add_child(pbg)
	var good_p := ColorRect.new()
	good_p.color = Color(0.4, 0.9, 0.45, 0.5)
	good_p.position = Vector2(10 + 0.8 * 230, 8)
	good_p.size = Vector2(0.2 * 230, 30)
	pbg.add_child(good_p)
	skip_power_fill = ColorRect.new()
	skip_power_fill.color = Color(1, 0.7, 0.3)
	skip_power_fill.position = Vector2(10, 12)
	skip_power_fill.size = Vector2(0, 22)
	pbg.add_child(skip_power_fill)
	var pl := UI.small_label("power", UI.MUTED, 12)
	pl.position = Vector2(10, 44)
	pbg.add_child(pl)
	content.add_child(UI.hint_row(["SPACE", "E"], "or click to stop each meter"))
	skip_throw = 0
	skip_best = 0
	skip_counts = []
	_new_skip()


func _new_skip() -> void:
	skip_phase = "angle"
	skip_angle_t = randf() * 3.0
	skip_power = 0.0
	skip_power_fill.size.x = 0
	skip_stone.position = Vector2(30, 80)
	skip_stone.modulate.a = 1.0
	status.text = "Throw %d of %d  -  stop the angle!" % [skip_throw + 1, SKIP_THROWS]
	_skip_pips()


func _skip_pips() -> void:
	_set_pips([[SKIP_THROWS, skip_throw, Color(0.5, 0.8, 1), "Throws"]])


func _run_skip(delta: float) -> void:
	match skip_phase:
		"angle":
			skip_angle_t += delta * 2.4
			skip_angle = (1.0 - cos(skip_angle_t)) * 0.5 * 45.0
			skip_needle.position = Vector2(10 + skip_angle / 45.0 * 230 - 2, 4)
		"power":
			skip_power_t += delta * 2.2
			skip_power = (1.0 - cos(skip_power_t)) * 0.5
			skip_power_fill.size.x = skip_power * 230


func _skip_press() -> void:
	match skip_phase:
		"angle":
			skip_phase = "power"
			skip_power_t = 0.0
			status.text = "Now the power!"
			Audio.play("click")
		"power":
			skip_phase = "flying"
			var qa := clampf(1.0 - abs(skip_angle - 18.0) / 18.0, 0.0, 1.0)
			var skips := int(round(skip_power * (1.0 + 13.0 * pow(qa, 1.3)))) + (randi() % 2 if qa > 0.5 else 0)
			if skip_angle > 38.0:
				skips = 0    # too steep: plop!
			_fly_stone(skips)


func _fly_stone(skips: int) -> void:
	var x := 30.0
	var hop := 120.0 * skip_power + 30.0
	status.text = "..."
	var tw := skip_stone.create_tween()
	for i in skips:
		var nx: float = min(x + hop, 490.0)
		tw.tween_property(skip_stone, "position", Vector2((x + nx) / 2, 80 - hop * 0.25), 0.12)
		tw.tween_property(skip_stone, "position", Vector2(nx, 88), 0.12)
		tw.tween_callback(func(): Audio.play("skip", 0.1))
		x = nx
		hop *= 0.78
	tw.tween_property(skip_stone, "position", Vector2(x + 20, 104), 0.15)
	tw.tween_callback(func(): Audio.play("splash", 0.1, -6.0))
	tw.tween_property(skip_stone, "modulate:a", 0.0, 0.2)
	await tw.finished
	if kind != "skip":
		return
	skip_counts.append(skips)
	skip_best = max(skip_best, skips)
	skip_throw += 1
	UI.banner(root, "%d skip%s!" % [skips, "" if skips == 1 else "s"] if skips > 0 else "Plop!", Color(0.6, 0.9, 1))
	_skip_pips()
	await get_tree().create_timer(1.0).timeout
	if kind != "skip":
		return
	if skip_throw >= SKIP_THROWS:
		status.text = "Best throw: %d skips" % skip_best
		await get_tree().create_timer(1.0).timeout
		_finish(skip_best)
	else:
		_new_skip()


# ================================================================ stargazing

const CONSTELLATIONS := [
	{"name": "The Fish", "pts": [[0.0, 0.5], [0.3, 0.25], [0.65, 0.3], [0.9, 0.1], [0.9, 0.9], [0.65, 0.7], [0.3, 0.75]],
		"lines": [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 0], [2, 5]]},
	{"name": "The Crown", "pts": [[0.0, 0.8], [0.1, 0.2], [0.3, 0.6], [0.5, 0.0], [0.7, 0.6], [0.9, 0.2], [1.0, 0.8]],
		"lines": [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 0]]},
	{"name": "The Watering Can", "pts": [[0.0, 0.35], [0.35, 0.4], [0.35, 0.95], [0.8, 0.95], [0.8, 0.4], [1.0, 0.05]],
		"lines": [[0, 1], [1, 2], [2, 3], [3, 4], [4, 1], [4, 5]]},
	{"name": "The Lantern", "pts": [[0.5, 0.0], [0.2, 0.3], [0.8, 0.3], [0.2, 0.8], [0.8, 0.8], [0.5, 1.0]],
		"lines": [[0, 1], [0, 2], [1, 2], [1, 3], [2, 4], [3, 5], [4, 5]]},
	{"name": "The Dog", "pts": [[0.0, 0.3], [0.2, 0.15], [0.3, 0.5], [0.8, 0.5], [0.95, 0.2], [0.3, 0.95], [0.8, 0.95]],
		"lines": [[0, 1], [1, 2], [2, 3], [3, 4], [2, 5], [3, 6]]},
	{"name": "The Boot", "pts": [[0.2, 0.0], [0.5, 0.0], [0.5, 0.6], [1.0, 0.8], [1.0, 1.0], [0.2, 1.0]],
		"lines": [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 0]]},
	{"name": "The Ship", "pts": [[0.0, 0.7], [1.0, 0.7], [0.8, 1.0], [0.2, 1.0], [0.5, 0.0], [0.5, 0.7], [0.85, 0.5]],
		"lines": [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [4, 6], [6, 5]]},
	{"name": "The Bread Loaf", "pts": [[0.0, 0.7], [0.15, 0.3], [0.5, 0.1], [0.85, 0.3], [1.0, 0.7], [0.5, 0.85]],
		"lines": [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 0]]},
]
const STAR_TIME := 30.0
const SKY_W := 520.0
const SKY_H := 340.0

class SkyView extends Control:
	var game: Node
	func _draw() -> void:
		game._draw_sky(self)
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			game._sky_click(event.position)

class CardView extends Control:
	var game: Node
	func _draw() -> void:
		game._draw_card(self)

var sky: Control
var card: Control
var star_list: Array = []    # {"pos": Vector2, "c": index in constellation or -1, "found": bool, "size", "tw"}
var star_round := 0
var star_rounds: Array = []  # constellation indices for this session
var star_time := 0.0
var star_found_names: Array = []
var star_flash := 0.0
var star_timer_bar: ColorRect
var star_t := 0.0


func _setup_stars() -> void:
	_frame("Stargazing", "Find the constellation on the card hidden among the stars, and click each of its stars.",
		Color(0.25, 0.25, 0.5), "telescope", Color(0.9, 0.85, 1))
	body.custom_minimum_size = Vector2(SKY_W + 170, SKY_H + 14)
	sky = SkyView.new()
	sky.game = self
	sky.size = Vector2(SKY_W, SKY_H)
	sky.mouse_filter = Control.MOUSE_FILTER_STOP
	body.add_child(sky)
	card = CardView.new()
	card.game = self
	card.position = Vector2(SKY_W + 16, 30)
	card.size = Vector2(150, 150)
	body.add_child(card)
	star_timer_bar = ColorRect.new()
	star_timer_bar.color = Color(0.6, 0.7, 1)
	star_timer_bar.position = Vector2(0, SKY_H + 4)
	star_timer_bar.size = Vector2(SKY_W, 8)
	body.add_child(star_timer_bar)
	content.add_child(UI.hint_row(["click"], "the stars that make the shape (a wrong star costs 2 seconds)"))
	# prefer constellations you haven't charted yet
	var found: Array = Game.xarr("stars_found")
	var order := range(CONSTELLATIONS.size())
	order.shuffle()
	order.sort_custom(func(a, b): return (not found.has(CONSTELLATIONS[a]["name"])) and found.has(CONSTELLATIONS[b]["name"]))
	star_rounds = order.slice(0, 3)
	star_round = 0
	star_found_names = []
	_new_sky()


func _new_sky() -> void:
	var con: Dictionary = CONSTELLATIONS[star_rounds[star_round]]
	star_list = []
	var sc := randf_range(150.0, 200.0)
	var origin := Vector2(randf_range(20, SKY_W - sc - 20), randf_range(20, SKY_H - sc - 20))
	for i in con["pts"].size():
		var p: Array = con["pts"][i]
		star_list.append({"pos": origin + Vector2(p[0], p[1]) * sc, "c": i, "found": false, "size": randf_range(2.2, 3.4), "tw": randf() * TAU})
	var tries := 0
	while star_list.size() < con["pts"].size() + 46 and tries < 2000:
		tries += 1
		var q := Vector2(randf_range(8, SKY_W - 8), randf_range(8, SKY_H - 8))
		var ok := true
		for s in star_list:
			if (s["pos"] as Vector2).distance_to(q) < 20.0:
				ok = false
				break
		if ok:
			star_list.append({"pos": q, "c": -1, "found": false, "size": randf_range(1.2, 3.4), "tw": randf() * TAU})
	star_time = STAR_TIME
	status.text = "Find: %s   (%d of 3)" % [con["name"], star_round + 1]
	_set_pips([[3, star_found_names.size(), Color(0.7, 0.75, 1), "Charted"]])
	sky.queue_redraw()
	card.queue_redraw()


func _run_stars(delta: float) -> void:
	if star_round >= star_rounds.size() or star_time <= -99.0:
		return
	star_t += delta
	star_time -= delta
	star_flash = max(star_flash - delta, 0.0)
	star_timer_bar.size.x = SKY_W * max(star_time, 0.0) / STAR_TIME
	sky.queue_redraw()
	if star_time <= 0.0:
		star_time = -100.0
		UI.banner(root, "Clouds rolled in!", Color(0.7, 0.75, 0.9))
		Audio.play("fail")
		_next_sky()


func _sky_click(pos: Vector2) -> void:
	if kind != "stars" or star_time <= 0.0:
		return
	var best = null
	var bd := 14.0
	for s in star_list:
		var d: float = (s["pos"] as Vector2).distance_to(pos)
		if d < bd:
			bd = d
			best = s
	if best == null:
		return
	if best["c"] >= 0 and not best["found"]:
		best["found"] = true
		Audio.play("twinkle", 0.1)
		var con: Dictionary = CONSTELLATIONS[star_rounds[star_round]]
		var all := true
		for s in star_list:
			if s["c"] >= 0 and not s["found"]:
				all = false
		if all:
			star_time = -100.0
			star_found_names.append(con["name"])
			UI.banner(root, con["name"] + "!", Color(0.85, 0.85, 1))
			Audio.play("chime")
			_next_sky()
	elif best["c"] < 0:
		star_time -= 2.0
		star_flash = 0.3
		Audio.play("fail", 0.1, -8.0)
	sky.queue_redraw()


func _next_sky() -> void:
	await get_tree().create_timer(1.4).timeout
	if kind != "stars":
		return
	star_round += 1
	if star_round >= star_rounds.size():
		status.text = "You charted %d constellation%s tonight." % [star_found_names.size(), "" if star_found_names.size() == 1 else "s"]
		await get_tree().create_timer(1.0).timeout
		_finish(star_found_names)
	else:
		_new_sky()


func _draw_sky(c: Control) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.04, 0.05, 0.14))
	for i in 6:
		c.draw_rect(Rect2(0, c.size.y * i / 6.0, c.size.x, c.size.y / 6.0), Color(0.1, 0.1, 0.3, 0.06 * i))
	if star_flash > 0.0:
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(1, 0.3, 0.3, star_flash * 0.5))
	if star_round < star_rounds.size():
		var con: Dictionary = CONSTELLATIONS[star_rounds[star_round]]
		var by_c := {}
		for s in star_list:
			if s["c"] >= 0:
				by_c[s["c"]] = s
		for ln in con["lines"]:
			var a: Dictionary = by_c[ln[0]]
			var b: Dictionary = by_c[ln[1]]
			if a["found"] and b["found"]:
				c.draw_line(a["pos"], b["pos"], Color(0.7, 0.8, 1, 0.8), 2.0)
	for s in star_list:
		var tw: float = 0.75 + 0.25 * sin(star_t * 3.0 + float(s["tw"]))
		var col := Color(1, 0.95, 0.6) if s["found"] else Color(0.95, 0.95, 1, tw)
		var r: float = float(s["size"]) * (1.8 if s["found"] else 1.0)
		c.draw_circle(s["pos"], r * 2.2, Color(col, 0.15))
		c.draw_circle(s["pos"], r, col)


func _draw_card(c: Control) -> void:
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.93, 0.87, 0.7))
	c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(0.6, 0.45, 0.3), false, 3.0)
	if star_round >= star_rounds.size():
		return
	var con: Dictionary = CONSTELLATIONS[star_rounds[star_round]]
	var pts := []
	for p in con["pts"]:
		pts.append(Vector2(20, 22) + Vector2(p[0], p[1]) * 110.0)
	for ln in con["lines"]:
		c.draw_line(pts[ln[0]], pts[ln[1]], Color(0.4, 0.3, 0.6), 2.0)
	for p in pts:
		c.draw_circle(p, 4.0, Color(0.25, 0.2, 0.45))
	c.draw_string(ThemeDB.fallback_font, Vector2(8, c.size.y - 6), con["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.35, 0.25, 0.15))


# ================================================================ chopping ("Timber!")

const CHOP_SWINGS := 3
const CHOP_W := 380.0
var chop_swing := 0
var chop_points := 0
var chop_x := 0.0
var chop_dir := 1.0
var chop_speed := 300.0
var chop_zone := 0.0          # left edge of the green zone
var chop_wait := 0.0
var chop_marker: ColorRect
var chop_green: ColorRect
var chop_yellow: ColorRect
var chop_notch: ColorRect
var chop_trunk: Panel


func _setup_chop() -> void:
	_frame("Timber!", "Stop the swing in the green for a clean cut. Three good cuts fell the tree for extra wood.",
		Color(0.45, 0.32, 0.18), "wood_log")
	body.custom_minimum_size = Vector2(CHOP_W + 120, 210)
	chop_trunk = Panel.new()
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.55, 0.38, 0.22)
	ts.set_corner_radius_all(8)
	chop_trunk.add_theme_stylebox_override("panel", ts)
	chop_trunk.position = Vector2(CHOP_W + 40, 0)
	chop_trunk.size = Vector2(70, 200)
	body.add_child(chop_trunk)
	for k in 5:
		var bark := ColorRect.new()
		bark.color = Color(0.45, 0.3, 0.17)
		bark.position = Vector2(10 + k * 12, 10 + (k % 2) * 30)
		bark.size = Vector2(3, 170)
		chop_trunk.add_child(bark)
	chop_notch = ColorRect.new()
	chop_notch.color = Color(0.93, 0.8, 0.55)
	chop_notch.position = Vector2(0, 110)
	chop_notch.size = Vector2(0, 26)
	chop_trunk.add_child(chop_notch)
	var bar := Panel.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0.1, 0.07, 0.05)
	bs.set_corner_radius_all(10)
	bar.add_theme_stylebox_override("panel", bs)
	bar.position = Vector2(0, 100)
	bar.size = Vector2(CHOP_W, 46)
	bar.clip_contents = true
	body.add_child(bar)
	var red := ColorRect.new()
	red.color = Color(0.75, 0.3, 0.25)
	red.position = Vector2(4, 4)
	red.size = Vector2(CHOP_W - 8, 38)
	bar.add_child(red)
	chop_yellow = ColorRect.new()
	chop_yellow.color = Color(0.95, 0.8, 0.3)
	bar.add_child(chop_yellow)
	chop_green = ColorRect.new()
	chop_green.color = Color(0.4, 0.9, 0.45)
	bar.add_child(chop_green)
	chop_marker = ColorRect.new()
	chop_marker.color = Color.WHITE
	chop_marker.size = Vector2(6, 62)
	body.add_child(chop_marker)
	content.add_child(UI.hint_row(["SPACE", "E"], "or click to swing"))
	chop_swing = 0
	chop_points = 0
	chop_speed = 300.0
	_new_chop()


func _new_chop() -> void:
	chop_zone = randf_range(90.0, CHOP_W - 130.0)
	chop_green.position = Vector2(chop_zone, 4)
	chop_green.size = Vector2(40, 38)
	chop_yellow.position = Vector2(chop_zone - 45, 4)
	chop_yellow.size = Vector2(130, 38)
	chop_x = 0.0
	chop_dir = 1.0
	chop_wait = 0.0
	status.text = "Swing %d of %d" % [chop_swing + 1, CHOP_SWINGS]
	_set_pips([[CHOP_SWINGS, chop_swing, Color(0.75, 0.55, 0.3), "Swings"]])


func _run_chop(delta: float) -> void:
	if chop_wait > 0.0:
		chop_wait -= delta
		if chop_wait <= 0.0:
			if chop_swing >= CHOP_SWINGS:
				_finish(chop_points)
			else:
				_new_chop()
		return
	chop_x += chop_dir * chop_speed * delta
	if chop_x <= 0.0 or chop_x >= CHOP_W - 6:
		chop_dir = -chop_dir
		chop_x = clampf(chop_x, 0.0, CHOP_W - 6)
	chop_marker.position = Vector2(chop_x, 92)


func _chop_press() -> void:
	if chop_wait > 0.0 or chop_swing >= CHOP_SWINGS:
		return
	var c := chop_x + 3
	var pts := 0
	if c >= chop_zone and c <= chop_zone + 40:
		pts = 2
		UI.banner(root, "Clean cut!", Color(0.6, 1, 0.55))
	elif c >= chop_zone - 45 and c <= chop_zone + 85:
		pts = 1
		UI.banner(root, "Chop!", Color(1, 0.85, 0.4))
	else:
		UI.banner(root, "Whiff!", Color(1, 0.55, 0.45))
	Audio.play("chop" if pts > 0 else "fail", 0.1)
	chop_points += pts
	chop_swing += 1
	chop_notch.size.x = min(70.0, chop_notch.size.x + 8 + pts * 8)
	var tw := chop_trunk.create_tween()
	tw.tween_property(chop_trunk, "rotation", 0.06, 0.05)
	tw.tween_property(chop_trunk, "rotation", 0.0, 0.1)
	chop_speed += 70.0
	_set_pips([[CHOP_SWINGS, chop_swing, Color(0.75, 0.55, 0.3), "Swings"]])
	if chop_swing >= CHOP_SWINGS:
		Audio.play("timber")
		var ft := chop_trunk.create_tween()
		ft.tween_interval(0.3)
		ft.tween_property(chop_trunk, "rotation", 1.3, 0.6).set_ease(Tween.EASE_IN)
		status.text = "Timber!  %d / %d points" % [chop_points, CHOP_SWINGS * 2]
		chop_wait = 1.6
	else:
		chop_wait = 0.7


# ================================================================ mining ("Strike!")

const MINE_STRIKES := 4
const MINE_TARGET := 34.0
class RockView extends Control:
	var game: Node
	func _draw() -> void:
		game._draw_rock(self)

var rock_view: Control
var mine_strike := 0
var mine_points := 0
var mine_perfects := 0
var mine_t := 0.0
var mine_ring := 0.0
var mine_spot := Vector2.ZERO
var mine_wait := 0.0
var mine_cracks: Array = []   # [from, to] line segments
var mine_period := 1.25


func _setup_mine() -> void:
	_frame("Strike!", "Hit when the shrinking ring lines up with the glowing crack. Perfect strikes break off more stone.",
		Color(0.45, 0.47, 0.52), "stone")
	body.custom_minimum_size = Vector2(360, 260)
	rock_view = RockView.new()
	rock_view.game = self
	rock_view.size = Vector2(360, 260)
	body.add_child(rock_view)
	content.add_child(UI.hint_row(["SPACE", "E"], "or click to strike"))
	mine_strike = 0
	mine_points = 0
	mine_perfects = 0
	mine_cracks = []
	mine_period = 1.25
	_new_strike()


func _new_strike() -> void:
	mine_spot = Vector2(randf_range(110, 250), randf_range(90, 170))
	mine_t = 0.0
	mine_wait = 0.0
	status.text = "Strike %d of %d" % [mine_strike + 1, MINE_STRIKES]
	_set_pips([[MINE_STRIKES, mine_strike, Color(0.7, 0.72, 0.8), "Strikes"]])


func _run_mine(delta: float) -> void:
	if mine_wait > 0.0:
		mine_wait -= delta
		if mine_wait <= 0.0:
			if mine_strike >= MINE_STRIKES:
				_finish(mine_points)
			else:
				_new_strike()
		rock_view.queue_redraw()
		return
	mine_t += delta
	# the ring shrinks from big to nothing, then starts again
	var k := fmod(mine_t, mine_period) / mine_period
	mine_ring = lerpf(120.0, 4.0, k)
	rock_view.queue_redraw()


func _mine_press() -> void:
	if mine_wait > 0.0 or mine_strike >= MINE_STRIKES:
		return
	var err: float = abs(mine_ring - MINE_TARGET)
	var pts := 0
	if err < 5.0:
		pts = 2
		mine_perfects += 1
		UI.banner(root, "Perfect!", Color(0.6, 1, 0.55))
	elif err < 13.0:
		pts = 1
		UI.banner(root, "Crack!", Color(1, 0.85, 0.4))
	else:
		UI.banner(root, "Clang!", Color(1, 0.55, 0.45))
	Audio.play("crack" if pts > 0 else "fail", 0.12)
	mine_points += pts
	mine_strike += 1
	for i in 1 + pts * 2:
		var a := randf() * TAU
		mine_cracks.append([mine_spot, mine_spot + Vector2(cos(a), sin(a)) * randf_range(20, 45 + pts * 15)])
	mine_period = max(0.8, mine_period - 0.12)
	_set_pips([[MINE_STRIKES, mine_strike, Color(0.7, 0.72, 0.8), "Strikes"]])
	if mine_strike >= MINE_STRIKES:
		status.text = "The boulder splits!  %d / %d points" % [mine_points, MINE_STRIKES * 2]
		mine_wait = 1.6
	else:
		mine_wait = 0.6


func _draw_rock(c: Control) -> void:
	# a lumpy grey boulder
	var pts := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		var r := 110.0 + sin(i * 2.3) * 12.0
		pts.append(Vector2(180, 135) + Vector2(cos(a) * r * 1.35, sin(a) * r))
	c.draw_colored_polygon(pts, Color(0.55, 0.56, 0.6))
	c.draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.4, 0.4, 0.44), 3.0)
	c.draw_circle(Vector2(140, 100), 26, Color(0.62, 0.63, 0.67))
	for cr in mine_cracks:
		c.draw_line(cr[0], cr[1], Color(0.25, 0.25, 0.28), 3.0)
	if mine_strike < MINE_STRIKES:
		# the weak spot and the shrinking ring
		c.draw_circle(mine_spot, MINE_TARGET, Color(1, 0.8, 0.4, 0.18))
		c.draw_arc(mine_spot, MINE_TARGET, 0, TAU, 40, Color(1, 0.85, 0.4), 3.0)
		if mine_wait <= 0.0:
			var near: bool = abs(mine_ring - MINE_TARGET) < 5.0
			c.draw_arc(mine_spot, mine_ring, 0, TAU, 48, Color(0.6, 1, 0.6) if near else Color.WHITE, 4.0)
