extends Node

## Tek ses girişi. Sesler `data/sounds.json` tablosundan ada göre yüklenir;
## böylece iskelette hiç ses dosyası yokken de hata vermez.
##
## Headless'ta gerçek çalma yapılmaz ama sayaç artar; kabul probu olay→ses
## bağlantısını bu sayaçla doğrular (ARCHITECTURE.md §5.6). Aynı sesin 80 ms
## içinde tekrarlanması `SfxGate` ile engellenir (çarpma sinyali sağanağı).

const SOUNDS_PATH: String = "res://data/sounds.json"
const POOL_SIZE: int = 6
## `balance.audio.min_gap_ms` okunamazsa/bozuksa kullanılan sözleşme değeri.
const DEFAULT_MIN_GAP_MS: int = 80

var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _table: Dictionary = {}
var _cache: Dictionary = {}
var _silent: bool = false
var _muted: bool = false
var _missing: Dictionary = {}
var _counts: Dictionary[String, int] = {}
var _gate: SfxGate = SfxGate.new()
var _min_gap_ms: int = DEFAULT_MIN_GAP_MS
var _gap_loaded: bool = false


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
## Sessizken hiçbir şey yapmaz ve sayaç ARTMAZ; sıklık sınırına takılan deneme de sayılmaz.
func play(sound_name: String, pitch_variance: float = 0.0) -> void:
	if _muted:
		return
	var stream: AudioStream = _stream(sound_name)
	if stream == null:
		return
	if not _allow_now(sound_name):
		return
	_counts[sound_name] = int(_counts.get(sound_name, 0)) + 1
	if _silent or _pool.is_empty():
		return
	var player: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.pitch_scale = 1.0 if pitch_variance <= 0.0 else 1.0 + randf_range(-pitch_variance, pitch_variance)
	player.play()


## Başarıyla "çalınan" (sessizde de sayılan) çağrı sayısı; probun olay→ses ölçütü.
func play_count(sound_name: String) -> int:
	return int(_counts.get(sound_name, 0))


func set_muted(muted: bool) -> void:
	_muted = muted


func is_muted() -> bool:
	return _muted


func has_sound(sound_name: String) -> bool:
	return _table.has(sound_name)


func _allow_now(sound_name: String) -> bool:
	if not _gap_loaded:
		_load_gap()
	return _gate.allow(sound_name, Time.get_ticks_msec(), _min_gap_ms)


## `balance.audio.min_gap_ms` ilk çalmada okunur: GameData autoload'u bu
## servisten sonra yüklendiği için `_ready` anında tablo henüz hazır olmayabilir.
func _load_gap() -> void:
	_gap_loaded = true
	var data: Node = get_node_or_null("/root/GameData")
	if data == null:
		return
	var balance_raw: Variant = data.call("table", "balance")
	if not balance_raw is Dictionary:
		return
	var audio_raw: Variant = (balance_raw as Dictionary).get("audio")
	if not audio_raw is Dictionary:
		return
	var raw: Variant = (audio_raw as Dictionary).get("min_gap_ms")
	if typeof(raw) == TYPE_INT:
		_min_gap_ms = maxi(int(raw), 0)
	elif typeof(raw) == TYPE_FLOAT:
		var number: float = float(raw)
		if is_finite(number) and is_equal_approx(number, roundf(number)):
			_min_gap_ms = maxi(int(roundf(number)), 0)


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
