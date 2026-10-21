extends Node
## Autoload. Sound effects play from a small pool so rapid hits overlap instead of cutting each other
## off; music crossfades between two players. Sounds are synthesized by tools/gen_audio.py.

const POOL := 12
const SFX_NAMES := [
	"hit", "opp_hit", "bounce", "wall", "net", "net_clip", "swoosh", "dash", "serve",
	"point_win", "point_big", "point_lose_1", "point_lose_2", "point_lose_3", "point_lose_4", "clear", "game_over", "buy", "deny", "reroll", "remove",
	"click", "fire",
]
const TRACKS := ["beach", "everest", "moon", "mansion", "arcade", "shop"]
## Music per map, in the order of Scenery.NAMES.
const STAGE_TRACKS := ["beach", "everest", "moon", "mansion", "arcade"]
## Sounds with several takes: play("point_lose") picks one of point_lose_1..N at random.
const VARIANTS := {"point_lose": 4}
const SETTINGS_PATH := "user://settings.cfg"
## Headroom per bus: a slider at 1.0 plays at this level, so the defaults sit well below full scale.
const BASE_DB := {"Music": -12.0, "SFX": -8.0}

## Player-facing volumes, 0..1 per bus.
var vol := {"Music": 0.5, "SFX": 0.7}

var sfx: Dictionary = {}
var tracks: Dictionary = {}
var pool: Array[AudioStreamPlayer] = []
var next := 0
var music: Array[AudioStreamPlayer] = []
var music_on := 0
var music_name := ""


func _ready() -> void:
	_load_settings()
	for bus in vol:
		_apply(bus)
	for n in SFX_NAMES:
		sfx[n] = load("res://audio/sfx/%s.wav" % n)
	for n in TRACKS:
		var s: AudioStreamWAV = load("res://audio/music/%s.wav" % n)
		# 16-bit mono: loop the whole file so the loop is sample-exact
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2
		tracks[n] = s
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		pool.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = &"Music"
		m.volume_db = -80.0
		add_child(m)
		music.append(m)


func set_volume(bus: String, v: float) -> void:
	vol[bus] = clampf(v, 0.0, 1.0)
	_apply(bus)


func _apply(bus: String) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	var v: float = vol[bus]
	AudioServer.set_bus_volume_db(i, BASE_DB[bus] + linear_to_db(v) if v > 0.001 else -80.0)


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for bus in vol:
		cfg.set_value("volume", bus, vol[bus])
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for bus in vol:
		vol[bus] = clampf(float(cfg.get_value("volume", bus, vol[bus])), 0.0, 1.0)


## Plays a sound effect. `pitch` scales it (1.0 = as authored); `vary` adds a random wobble so repeats
## don't sound mechanical; `db` is a volume offset.
func play(name: String, pitch := 1.0, vary := 0.06, db := 0.0) -> void:
	if VARIANTS.has(name):
		name = "%s_%d" % [name, randi_range(1, VARIANTS[name])]
	if not sfx.has(name):
		return
	var p := pool[next]
	next = (next + 1) % POOL
	p.stream = sfx[name]
	p.pitch_scale = pitch * (1.0 + randf_range(-vary, vary))
	p.volume_db = db
	p.play()


## Crossfades to a track; does nothing if it's already playing.
func play_music(name: String, fade := 0.8) -> void:
	if name == music_name or not tracks.has(name):
		return
	music_name = name
	var old := music[music_on]
	music_on = 1 - music_on
	var cur := music[music_on]
	cur.stream = tracks[name]
	cur.volume_db = -80.0
	cur.play()
	var tw := create_tween().set_parallel()
	tw.tween_property(cur, "volume_db", 0.0, fade)
	tw.tween_property(old, "volume_db", -80.0, fade)
	tw.chain().tween_callback(old.stop)
