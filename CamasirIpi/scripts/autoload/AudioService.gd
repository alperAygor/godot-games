extends Node

## Tek ses girişi. Sesler `data/sounds.json` tablosundan ada göre yüklenir;
## böylece iskelette hiç ses dosyası yokken de hata vermez.

const SOUNDS_PATH: String = "res://data/sounds.json"
const POOL_SIZE: int = 6

var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _table: Dictionary = {}
var _cache: Dictionary = {}
var _silent: bool = false
var _missing: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_silent = DisplayServer.get_name() == "headless"
	_table = _load_table()
	var bus_name: StringName = &"Master"
	if AudioServer.get_bus_index(&"SFX") >= 0:
		bus_name = &"SFX"
	for i: int in POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = bus_name
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_pool.append(player)


## `data/sounds.json` içinde tanımlı bir sesi çalar. Tanımsız ad sessizce yok sayılır.
func play(sound_name: String, pitch_variance: float = 0.0) -> void:
	if _silent or _pool.is_empty():
		return
	var stream: AudioStream = _stream(sound_name)
	if stream == null:
		return
	var player: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.pitch_scale = 1.0 if pitch_variance <= 0.0 else 1.0 + randf_range(-pitch_variance, pitch_variance)
	player.play()


## Belirli bir perdeyle çalar (art arda sepetlerde yükselen nota için).
func play_pitched(sound_name: String, pitch: float, volume_db: float = 0.0) -> void:
	if _silent or _pool.is_empty():
		return
	var stream: AudioStream = _stream(sound_name)
	if stream == null:
		return
	var player: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.pitch_scale = maxf(pitch, 0.1)
	player.volume_db = volume_db
	player.play()


func has_sound(sound_name: String) -> bool:
	return _table.has(sound_name)


func _stream(sound_name: String) -> AudioStream:
	if _cache.has(sound_name):
		return _cache[sound_name] as AudioStream
	if not _table.has(sound_name):
		if not _missing.has(sound_name):
			_missing[sound_name] = true
			push_warning("AudioService: '%s' sounds.json içinde yok" % sound_name)
		return null
	var path: String = String(_table[sound_name])
	if not ResourceLoader.exists(path):
		if not _missing.has(sound_name):
			_missing[sound_name] = true
			push_warning("AudioService: ses dosyası yok: %s" % path)
		return null
	var stream: AudioStream = load(path) as AudioStream
	_cache[sound_name] = stream
	return stream


func _load_table() -> Dictionary:
	if not FileAccess.file_exists(SOUNDS_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOUNDS_PATH))
	if parsed is Dictionary:
		return parsed as Dictionary
	push_warning("AudioService: %s geçerli JSON değil" % SOUNDS_PATH)
	return {}
