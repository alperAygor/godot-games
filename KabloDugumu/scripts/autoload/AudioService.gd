extends Node

## Tek ses girişi. Sesler `data/sounds.json` tablosundan ada göre yüklenir;
## böylece iskelette hiç ses dosyası yokken de hata vermez.
##
## Sözleşme (ARCHITECTURE.md §3): play, has_sound, set_muted. `muted` durumu
## dışarıdan okunabilir; headless (CI) çalışırken ses tamamen sessizdir.

const SOUNDS_PATH: String = "res://data/sounds.json"
## Eşzamanlı kısa efekt sayısı: kıvılcım + clack + whoosh üst üste binerken
## kesilme olmasın diye 8. Mobilde 8 AudioStreamPlayer ihmal edilebilir maliyet.
const POOL_SIZE: int = 8

## Kullanıcı sesi kapattı mı? Oyun ayarları bunu `set_muted` ile değiştirir.
var muted: bool = false

var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _table: Dictionary = {}
var _cache: Dictionary = {}
var _silent: bool = false
var _missing: Dictionary = {}
var _bus: StringName = &"Master"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_silent = DisplayServer.get_name() == "headless"
	_table = _load_table()
	var bus_index: int = AudioServer.get_bus_index(&"SFX")
	if bus_index >= 0:
		_bus = &"SFX"
	for i: int in POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = _bus
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_pool.append(player)


## `data/sounds.json` içinde tanımlı bir sesi çalar. Tanımsız ad sessizce yok sayılır.
## `pitch_variance` > 0 ise her çalma ±varyans kadar perde değiştirir (tekrar hissini kırar).
func play(sound_name: String, pitch_variance: float = 0.0) -> void:
	if _silent or muted or _pool.is_empty():
		return
	var stream: AudioStream = _stream(sound_name)
	if stream == null:
		return
	var player: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.pitch_scale = 1.0 if pitch_variance <= 0.0 else 1.0 + randf_range(-pitch_variance, pitch_variance)
	player.play()


func has_sound(sound_name: String) -> bool:
	return _table.has(sound_name)


## Sesi susturur/açar. Bus seviyesinde de uygulanır ki çalmakta olan sesler de sussun.
func set_muted(value: bool) -> void:
	muted = value
	var bus_index: int = AudioServer.get_bus_index(_bus)
	if bus_index >= 0:
		AudioServer.set_bus_mute(bus_index, value)


func _stream(sound_name: String) -> AudioStream:
	if _cache.has(sound_name):
		return _cache[sound_name] as AudioStream
	if not _table.has(sound_name):
		_warn_missing(sound_name, "AudioService: '%s' sounds.json içinde yok" % sound_name)
		return null
	var path: String = String(_table[sound_name])
	if not ResourceLoader.exists(path):
		_warn_missing(sound_name, "AudioService: ses dosyası yok: %s" % path)
		return null
	var stream: AudioStream = load(path) as AudioStream
	_cache[sound_name] = stream
	return stream


## Eksik ses için yalnızca bir kez uyar: aynı ad her karede çağrılsa log dolmaz.
func _warn_missing(key: String, message: String) -> void:
	if _missing.has(key):
		return
	_missing[key] = true
	push_warning(message)


func _load_table() -> Dictionary:
	if not FileAccess.file_exists(SOUNDS_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOUNDS_PATH))
	if parsed is Dictionary:
		return parsed as Dictionary
	push_warning("AudioService: %s geçerli JSON değil" % SOUNDS_PATH)
	return {}
