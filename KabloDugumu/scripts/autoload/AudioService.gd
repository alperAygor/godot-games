extends Node

## Tek ses girişi (v0.2 ASMR): kısa efektler (`play`) + dikişsiz ambient loop'lar
## (`play_ambient`/`stop_ambient`). Sesler `data/sounds.json` tablosundan ada göre
## yüklenir; böylece eksik dosya oyunu kırmaz, tek uyarı basar.
##
## Sözleşme (ARCHITECTURE.md §3): play, has_sound, set_muted, play_ambient,
## stop_ambient, current_ambient. PROCESS_MODE_ALWAYS: pause'da müzik devam eder.
## Mute kalıcıdır: user://settings.cfg -> audio/sound_enabled (ARCHITECTURE §11
## için ui/sound aynası). Headless (CI) tamamen sessizdir, API durumu korunur.

const SOUNDS_PATH: String = "res://data/sounds.json"
const SETTINGS_PATH: String = "user://settings.cfg"
## Eşzamanlı kısa efekt sayısı: kıvılcım + clack + whoosh üst üste binerken
## kesilme olmasın diye 8. Mobilde 8 AudioStreamPlayer ihmal edilebilir maliyet.
const POOL_SIZE: int = 8
const DEFAULT_AMBIENT_FADE: float = 1.5
const MIN_VOLUME_DB: float = -40.0
## UI sesleri ayrı bus'ta: efektlerin altında kalmadan net duyulur.
const UI_SOUNDS: Array[String] = ["ui_tap", "level_start"]
## İlk kullanımda disk/import stall'ı olmasın diye _ready'de cache'e alınan
## yaygın efektler (live-world ölçümü: ilk play ~1-2 ms; yine de önden yüklenir).
const COMMON_SOUNDS: Array[String] = [
	"spark", "clack", "ui_tap", "cable_slide", "cable_pull", "level_start",
	"success", "win", "fail", "fuse_pop", "wrong_socket",
]
## ASMR mix: müzik yatağı kısık, efektler yakın, UI dokunuşları yumuşak.
const BUS_LEVELS: Dictionary = {"Music": -9.0, "SFX": -3.0, "UI": -5.0}
const MASTER_BUS: int = 0

## Kullanıcı sesi kapattı mı? Oyun ayarları bunu `set_muted` ile değiştirir.
var muted: bool = false

var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _table: Dictionary = {}
var _cache: Dictionary = {}
var _loop_cache: Dictionary = {}
var _silent: bool = false
var _missing: Dictionary = {}
var _ambient_player: AudioStreamPlayer = null
var _ambient_name: String = ""
var _ambient_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_silent = DisplayServer.get_name() == "headless"
	_ensure_buses()
	_table = _load_table()
	for i: int in POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = _bus_name("SFX")
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_pool.append(player)
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "Ambient"
	_ambient_player.bus = _bus_name("Music")
	_ambient_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ambient_player)
	_preload_common_sounds()
	muted = not _load_sound_enabled()
	_apply_mute()


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
	player.bus = _bus_for(sound_name)
	player.stream = stream
	player.pitch_scale = 1.0 if pitch_variance <= 0.0 else 1.0 + randf_range(-pitch_variance, pitch_variance)
	player.play()


func has_sound(sound_name: String) -> bool:
	return _table.has(sound_name)


## Yaygın efektleri şimdiden cache'e alır: ilk kullanımda dosya yükleme/import
## kaynaklı kare atlaması olmasın. Headless'ta atlanır (CI gereksiz I/O yapmaz).
func _preload_common_sounds() -> void:
	if _silent:
		return
	for sound_name: String in COMMON_SOUNDS:
		_stream(sound_name)


## Sesi susturur/açar. Master bus'ı susturur (efekt + ambient birlikte) ve
## tercihi user://settings.cfg'ye yazar.
func set_muted(value: bool) -> void:
	var changed: bool = muted != value
	muted = value
	_apply_mute()
	_save_sound_enabled(not muted)
	if changed and not muted and _ambient_name != "":
		_resume_ambient_if_needed()


## Ambient loop başlatır (fade-in). Aynı adla ikinci çağrı idempotenttir.
## Mute/headless durumunda ses çıkmaz ama `current_ambient` durumu korunur.
func play_ambient(ambient_name: String, fade_seconds: float = DEFAULT_AMBIENT_FADE) -> void:
	if ambient_name == "":
		stop_ambient(fade_seconds)
		return
	if not _table.has(ambient_name):
		_warn_missing(ambient_name, "AudioService: ambient '%s' sounds.json içinde yok" % ambient_name)
		return
	if _ambient_name == ambient_name and _ambient_player != null 			and (_ambient_player.playing or _silent or muted):
		return
	_ambient_name = ambient_name
	if _silent or muted or _ambient_player == null:
		return
	var stream: AudioStream = _loop_stream(ambient_name)
	if stream == null:
		return
	_kill_ambient_tween()
	_ambient_player.stream = stream
	_ambient_player.volume_db = MIN_VOLUME_DB
	_ambient_player.play()
	if fade_seconds <= 0.0:
		_ambient_player.volume_db = 0.0
		return
	_ambient_tween = create_tween()
	_ambient_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_ambient_tween.tween_property(_ambient_player, "volume_db", 0.0, fade_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Ambient loop'u fade-out ile durdurur; tekrar çağrı idempotenttir.
func stop_ambient(fade_seconds: float = DEFAULT_AMBIENT_FADE) -> void:
	if _ambient_player == null:
		_ambient_name = ""
		return
	if _ambient_name == "" and not _ambient_player.playing:
		return
	_ambient_name = ""
	_kill_ambient_tween()
	if _silent or fade_seconds <= 0.0 or not _ambient_player.playing:
		_ambient_player.stop()
		return
	_ambient_tween = create_tween()
	_ambient_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_ambient_tween.tween_property(_ambient_player, "volume_db", MIN_VOLUME_DB, fade_seconds) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_ambient_tween.tween_callback(_ambient_player.stop)


func current_ambient() -> String:
	return _ambient_name


## Ambient çalarken kullanıcı sesi açarsa kaldığı yerden devam eder.
func _resume_ambient_if_needed() -> void:
	if _silent or _ambient_player == null:
		return
	var stream: AudioStream = _loop_stream(_ambient_name)
	if stream == null:
		return
	_ambient_player.stream = stream
	if not _ambient_player.playing:
		_ambient_player.volume_db = 0.0
		_ambient_player.play()


func _apply_mute() -> void:
	if AudioServer.get_bus_index(&"Master") < 0:
		return
	AudioServer.set_bus_mute(MASTER_BUS, muted)


func _ensure_buses() -> void:
	for bus_key: Variant in BUS_LEVELS.keys():
		var bus_name: String = String(bus_key)
		var index: int = AudioServer.get_bus_index(StringName(bus_name))
		if index < 0:
			index = AudioServer.bus_count
			AudioServer.add_bus(index)
			AudioServer.set_bus_name(index, StringName(bus_name))
			AudioServer.set_bus_send(index, &"Master")
		AudioServer.set_bus_volume_db(index, float(BUS_LEVELS[bus_key]))


func _bus_name(bus_name: String) -> StringName:
	if AudioServer.get_bus_index(StringName(bus_name)) >= 0:
		return StringName(bus_name)
	return &"Master"


func _bus_for(sound_name: String) -> StringName:
	if UI_SOUNDS.has(sound_name):
		return _bus_name("UI")
	return _bus_name("SFX")


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


## Loop için stream'in kopyasına LOOP_FORWARD uygular; cache'teki tek çalma
## kaynağını kirletmez.
func _loop_stream(sound_name: String) -> AudioStream:
	if _loop_cache.has(sound_name):
		return _loop_cache[sound_name] as AudioStream
	var base: AudioStream = _stream(sound_name)
	if base == null:
		return null
	if base is AudioStreamWAV:
		var looped: AudioStreamWAV = (base as AudioStreamWAV).duplicate(true) as AudioStreamWAV
		looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
		looped.loop_begin = 0
		var frames: int = int(round(looped.get_length() * float(looped.mix_rate)))
		if frames > 0:
			looped.loop_end = frames
		_loop_cache[sound_name] = looped
		return looped
	_warn_missing(sound_name, "AudioService: '%s' loop destekli WAV değil" % sound_name)
	_loop_cache[sound_name] = base
	return base


func _kill_ambient_tween() -> void:
	if _ambient_tween != null and _ambient_tween.is_valid():
		_ambient_tween.kill()
	_ambient_tween = null


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


func _load_sound_enabled() -> bool:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return true
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		push_warning("AudioService: %s okunamadı, ses açık kabul edildi" % SETTINGS_PATH)
		return true
	if config.has_section_key("audio", "sound_enabled"):
		return bool(config.get_value("audio", "sound_enabled", true))
	if config.has_section_key("ui", "sound"):
		return bool(config.get_value("ui", "sound", true))
	return true


func _save_sound_enabled(enabled: bool) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "sound_enabled", enabled)
	# ARCHITECTURE §11 uyumu: aynı tercih ui/sound olarak da yaşar (Loc aynı dosyayı kullanır).
	config.set_value("ui", "sound", enabled)
	var error: Error = config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("AudioService: %s yazılamadı (%d)" % [SETTINGS_PATH, error])
