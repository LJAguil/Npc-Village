extends Node
## Sound manager (autoloaded as "Audio"): background music that crossfades
## between day and night tracks, one-shot sound effects, and volume settings
## that are remembered between sessions.

const SETTINGS_PATH := "user://settings.cfg"

const SFX_NAMES := ["coin", "jump", "land", "splash", "cast", "bite", "reel", "catch", "fail",
	"click", "harvest", "till", "water", "plant", "quest", "morning", "win",
	"beep", "note1", "note2", "note3", "note4", "ding", "sizzle", "dig",
	"bark", "chime", "rustle", "skip", "twinkle", "chop", "crack", "hammer", "timber"]

## Instruments: one sample each (recorded at middle C, MIDI 60), pitch-shifted per note.
const INSTRUMENTS := ["piano", "guitar", "flute"]
var INST := {}
var _note_players: Array = []

var SFX := {}   # name -> AudioStream, loaded in _ready
var MUSIC_DAY: AudioStream
var MUSIC_NIGHT: AudioStream
var FOOTSTEPS: AudioStream
var WAVES: AudioStream

var music_volume := 0.7
## While you play an instrument the background music fades out ("off") or
## down ("quiet"). Saved in settings.cfg.
var instrument_music := "off"
var _duck := 1.0
var _duck_target := 1.0
var sfx_volume := 0.8

var _day_player: AudioStreamPlayer
var _night_player: AudioStreamPlayer
var _sfx_players: Array = []
var _night_mix := 0.0      # 0 = day music, 1 = night music
var _night_target := 0.0
var _music_on := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_bus("Music")
	_make_bus("SFX")

	for n in SFX_NAMES:
		SFX[n] = _load_ogg("res://audio/%s.ogg" % n)
	MUSIC_DAY = _load_ogg("res://audio/music_day.ogg")
	MUSIC_NIGHT = _load_ogg("res://audio/music_night.ogg")
	FOOTSTEPS = _load_ogg("res://audio/walking.ogg")
	WAVES = _load_ogg("res://audio/waves.ogg")

	for s in [MUSIC_DAY, MUSIC_NIGHT, FOOTSTEPS, WAVES]:
		if s:
			s.loop = true
	_day_player = _new_player("Music", MUSIC_DAY)
	_night_player = _new_player("Music", MUSIC_NIGHT)
	for i in 8:
		_sfx_players.append(_new_player("SFX", null))
	for inst in INSTRUMENTS:
		INST[inst] = _load_ogg("res://audio/inst_%s.ogg" % inst)
	for i in 10:
		_note_players.append(_new_player("SFX", null))

	_load_settings()
	_apply_volumes()


func _process(delta: float) -> void:
	if _duck != _duck_target:
		_duck = move_toward(_duck, _duck_target, delta * 1.5)
		_apply_volumes()
	if not _music_on:
		return
	_night_mix = move_toward(_night_mix, _night_target, delta * 0.25)
	_day_player.volume_db = linear_to_db(max(1.0 - _night_mix, 0.0001))
	_night_player.volume_db = linear_to_db(max(_night_mix, 0.0001))


## Loads a sound. Normally Godot has imported it; if it hasn't yet (e.g. new
## files were copied in while the editor was open), read the .ogg file directly
## so the game still has sound.
func _load_ogg(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is AudioStream:
			return res
	var direct := AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path(path))
	if direct == null:
		push_warning("Could not load sound: " + path)
	return direct


func start_music(night := false) -> void:
	_night_target = 1.0 if night else 0.0
	_night_mix = _night_target
	if not _day_player.playing:
		_day_player.play()
	if not _night_player.playing:
		_night_player.play()
	_music_on = true


func set_night(night: bool) -> void:
	_night_target = 1.0 if night else 0.0


func play(sound: String, pitch_variation := 0.05, volume_db := 0.0) -> void:
	if SFX.get(sound) == null:
		return
	for p in _sfx_players:
		if not p.playing:
			p.stream = SFX[sound]
			p.pitch_scale = 1.0 + randf_range(-pitch_variation, pitch_variation)
			p.volume_db = volume_db
			p.play()
			return


## Plays one note on an instrument. midi 60 = middle C.
func play_note(instrument: String, midi: int, volume_db := 0.0) -> void:
	var stream: AudioStream = INST.get(instrument)
	if stream == null:
		return
	var best: AudioStreamPlayer = _note_players[0]
	for p in _note_players:
		if not p.playing:
			best = p
			break
		if p.get_playback_position() > best.get_playback_position():
			best = p   # all busy: steal the oldest note
	best.stream = stream
	best.pitch_scale = pow(2.0, (midi - 60) / 12.0)
	best.volume_db = volume_db
	best.play()


func make_footsteps_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = FOOTSTEPS
	p.bus = "SFX"
	p.volume_db = -8.0
	return p


## Ocean waves that get louder as you walk toward the beach.
func make_waves_player() -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = WAVES
	p.bus = "SFX"
	p.unit_size = 14.0
	p.max_distance = 70.0
	p.volume_db = -2.0
	p.autoplay = true
	return p


func set_music_volume(v: float) -> void:
	music_volume = v
	_apply_volumes()
	_save_settings()


func set_sfx_volume(v: float) -> void:
	sfx_volume = v
	_apply_volumes()
	_save_settings()


## Fade the background music down while an instrument is being played.
func duck_music(on: bool) -> void:
	_duck_target = (0.0 if instrument_music == "off" else 0.2) if on else 1.0


func set_instrument_music(mode: String) -> void:
	instrument_music = mode
	_save_settings()


func _apply_volumes() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(max(music_volume * _duck, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(max(sfx_volume, 0.0001)))


func _make_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")


func _new_player(bus_name: String, stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus_name
	p.stream = stream
	add_child(p)
	return p


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		music_volume = cfg.get_value("audio", "music", music_volume)
		sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
		instrument_music = cfg.get_value("audio", "instrument_music", instrument_music)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)   # keep other settings (like the fishing style) in the file
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "instrument_music", instrument_music)
	cfg.save(SETTINGS_PATH)
