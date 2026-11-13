extends Node

## Tek ses girişi. Sesler `data/sounds.json` tablosundan ada göre yüklenir;
## böylece iskelette hiç ses dosyası yokken de hata vermez.

const SOUNDS_PATH: String = "res://data/sounds.json"
const POOL_SIZE: int = 6
## Oyun açılınca otomatik başlayan bahçe ortamı; çok kısık: efektlerin altında "oda tonu" olsun.
const AMBIENCE_NAME: String = "garden_ambience"
const MUSIC_NAME: String = "music_garden"
## Müzik efektlerin altında kalır: ASMR sesleri öne çıksın.
const MUSIC_VOLUME_DB: float = -13.0
const MUSIC_FADE_IN_S: float = 4.0
const AMBIENCE_VOLUME_DB: float = -6.0
const AMBIENCE_FADE_IN_S: float = 3.0
const AMBIENCE_FADE_OUT_S: float = 1.2
## Sessizlik: fade-out bitince oynatıcıyı gerçekten susturmak için kullanılan taban.
const SILENT_DB: float = -80.0

var _pool: Array[AudioStreamPlayer] = []
var _next: int = 0
var _table: Dictionary = {}
var _cache: Dictionary = {}
var _silent: bool = false
## Kullanıcı ayarları: efekt+ortam sesi ve müzik ayrı kapanır. `_silent` (headless) ile
## karışmasın diye ayrı bayraklar; kapalıyken oynatıcılar duraklatılır, akış kaybolmaz.
var _sound_on: bool = true
var _music_on: bool = true
var _missing: Dictionary = {}
var _ambience: AudioStreamPlayer = null
var _ambience_tween: Tween = null
var _ambience_name: String = ""
var _music: AudioStreamPlayer = null
var _music_name: String = ""
## Her ses adı için son çalınan varyant: aynı varyantın arka arkaya tekrarı "makine" gibi duyulur.
var _last_variant: Dictionary = {}


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
	# Ambiyans efektlerden bağımsız bir oynatıcıda: havuz döngüsü onu kesmesin.
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = bus_name
	_ambience.process_mode = Node.PROCESS_MODE_ALWAYS
	_ambience.volume_db = SILENT_DB
	add_child(_ambience)
	# Tablo/akışlar hazır; diğer autoload'lar bitsin diye bir kare sonra başlat.
	_music = AudioStreamPlayer.new()
	_music.bus = bus_name
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music)
	play_ambience.call_deferred(AMBIENCE_NAME, AMBIENCE_VOLUME_DB)
	play_music.call_deferred(MUSIC_NAME, MUSIC_VOLUME_DB)


## `data/sounds.json` içinde tanımlı bir sesi çalar. Tanımsız ad sessizce yok sayılır.
func play(sound_name: String, pitch_variance: float = 0.0) -> void:
	if _silent or not _sound_on or _pool.is_empty():
		return
	var stream: AudioStream = _stream(sound_name)
	if stream == null:
		return
	var player: AudioStreamPlayer = _pool[_next]
	_next = (_next + 1) % _pool.size()
	player.stream = stream
	player.pitch_scale = 1.0 if pitch_variance <= 0.0 else 1.0 + randf_range(-pitch_variance, pitch_variance)
	# Havuz oynatıcıları paylaşılır: önceki play_pitched'in kıstığı ses bu sese sızmasın.
	player.volume_db = 0.0
	player.play()


## Belirli bir perdeyle çalar (art arda sepetlerde yükselen nota için).
func play_pitched(sound_name: String, pitch: float, volume_db: float = 0.0) -> void:
	if _silent or not _sound_on or _pool.is_empty():
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


## `<base_name>_1 .. <base_name>_<count>` varyantlarından rastgele birini çalar; bir öncekini tekrarlamaz.
## Varyant tanımlı değilse (ör. tablo eksik) çıplak `base_name`e düşer, böylece eski adlar hep çalışır.
func play_variant(base_name: String, count: int, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if count <= 1:
		play_pitched(base_name, pitch, volume_db)
		return
	var last: int = int(_last_variant.get(base_name, 0))
	# 1..count arasından, last hariç: (count - 1) seçenek içinden seç, last'ı atlayarak kaydır.
	var pick: int = randi_range(1, count)
	if last > 0:
		pick = randi_range(1, count - 1)
		if pick >= last:
			pick += 1
	_last_variant[base_name] = pick
	var variant_name: String = "%s_%d" % [base_name, pick]
	play_pitched(variant_name if has_sound(variant_name) else base_name, pitch, volume_db)


## Döngülü ortam sesini yumuşakça açar. Aynı ses zaten çalıyorsa yalnızca ses seviyesini ayarlar.
func play_ambience(sound_name: String, volume_db: float = AMBIENCE_VOLUME_DB) -> void:
	if _silent or _ambience == null:
		return
	if _ambience.playing and _ambience_name == sound_name:
		_fade_ambience(volume_db, AMBIENCE_FADE_IN_S)
		return
	var stream: AudioStream = _stream(sound_name)
	if stream == null:
		return
	_ambience.stream = _looped(stream)
	_ambience_name = sound_name
	_ambience.volume_db = SILENT_DB  # Klik olmasın diye sessizlikten başla.
	_ambience.pitch_scale = 1.0
	_ambience.play()
	_ambience.stream_paused = not _sound_on
	_fade_ambience(volume_db, AMBIENCE_FADE_IN_S)


## Ortam sesini yumuşakça kısıp durdurur.
func stop_ambience() -> void:
	if _ambience == null or not _ambience.playing:
		return
	_fade_ambience(SILENT_DB, AMBIENCE_FADE_OUT_S, true)


## Döngülü arka plan müziğini yumuşakça açar (ortam sesinden ayrı oynatıcıda).
func play_music(sound_name: String, volume_db: float = MUSIC_VOLUME_DB) -> void:
	if _silent or _music == null or (_music.playing and _music_name == sound_name):
		return
	var stream: AudioStream = _stream(sound_name)
	if stream == null:
		return
	var ogg: AudioStreamOggVorbis = stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = true
	_music.stream = _looped(stream)
	_music_name = sound_name
	_music.volume_db = SILENT_DB
	_music.play()
	_music.stream_paused = not _music_on
	var fade: Tween = create_tween()
	fade.tween_property(_music, "volume_db", volume_db, MUSIC_FADE_IN_S)


## Ayar: efektler + ortam sesi.
func set_sound_enabled(enabled: bool) -> void:
	_sound_on = enabled
	if _ambience != null:
		_ambience.stream_paused = not enabled


## Ayar: arka plan müziği.
func set_music_enabled(enabled: bool) -> void:
	_music_on = enabled
	if _music != null:
		_music.stream_paused = not enabled


func has_sound(sound_name: String) -> bool:
	return _table.has(sound_name)


func _fade_ambience(target_db: float, seconds: float, stop_when_done: bool = false) -> void:
	if _ambience_tween != null and _ambience_tween.is_valid():
		_ambience_tween.kill()
	_ambience_tween = create_tween()
	_ambience_tween.tween_property(_ambience, "volume_db", target_db, seconds)
	if stop_when_done:
		_ambience_tween.tween_callback(_ambience.stop)


## WAV'ı kodda döngüye alır: import ayarına bağlı kalmadan, kaynak önbelleğini bozmamak için kopya üzerinde.
func _looped(stream: AudioStream) -> AudioStream:
	var wav: AudioStreamWAV = stream as AudioStreamWAV
	if wav == null:
		return stream
	var copy: AudioStreamWAV = wav.duplicate() as AudioStreamWAV
	copy.loop_mode = AudioStreamWAV.LOOP_FORWARD
	copy.loop_begin = 0
	# Sıkıştırılmış (QOA/ADPCM) akışta bayt sayısı örnek sayısı değildir; süre × örnekleme hızı her biçimde doğrudur.
	copy.loop_end = int(round(copy.get_length() * float(copy.mix_rate)))
	return copy


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
