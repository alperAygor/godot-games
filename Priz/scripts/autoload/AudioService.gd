extends Node

## Tek ses girişi. Sesler `data/sounds.json` tablosundan ada göre yüklenir;
## böylece tabloda olmayan ses sessizce yok sayılır (bir kez uyarı). Üretim: tools/make_sfx.py.
## Katmanlı döngüler (cihaz sesleri, elektrik uğultusu) `start_loop` ile adlı katmanlar olarak çalar;
## ayrıntı ve seviyeler: docs/AUDIO.md.

const SOUNDS_PATH: String = "res://data/sounds.json"
const POOL_SIZE: int = 6
## Tabloda bu adlarla ses varsa oyun açılınca kendiliğinden başlar (yoksa sessiz; uyarı basmaz).
## Ortam çok kısık: efektlerin altında "oda tonu" olsun.
const AMBIENCE_NAME: String = "ambience_main"
const MUSIC_NAME: String = "music_main"
## Müzik efektlerin altında kalır: efektler öne çıksın.
const MUSIC_VOLUME_DB: float = -13.0
const MUSIC_FADE_IN_S: float = 4.0
const AMBIENCE_VOLUME_DB: float = -6.0
const AMBIENCE_FADE_IN_S: float = 3.0
const AMBIENCE_FADE_OUT_S: float = 1.2
## Sessizlik: fade-out bitince oynatıcıyı gerçekten susturmak için kullanılan taban.
const SILENT_DB: float = -80.0

## Veri yolları: bus adları ve varsayılan seviyeleri (dB). Master'da sınırlayıcı (limiter) vardır;
## sekiz cihaz döngüsü + uğultu + ortam + müzik birlikte kırpılmasın diye alt veriler kısıktır.
const BUS_MASTER: StringName = &"Master"
const BUS_SFX: StringName = &"SFX"
const BUS_LOOPS: StringName = &"Loops"
const BUS_AMBIENCE: StringName = &"Ambience"
const BUS_MUSIC: StringName = &"Music"
const MASTER_VOLUME_DB: float = -1.0
const LIMITER_CEILING_DB: float = -1.0
const BUS_LEVELS: Dictionary = {
	&"SFX": 0.0,
	&"Loops": -6.0,
	&"Ambience": -4.0,
	&"Music": -5.0,
}
## Kısma (duck) bu bus'lara uygulanır; efektler (SFX) kısılmaz.
const DUCK_BUSES: Array[StringName] = [&"Loops", &"Ambience", &"Music"]
const DUCK_ATTACK_S: float = 0.05
const DUCK_RELEASE_S: float = 0.6
const DUCK_DEFAULT_DEPTH_DB: float = -14.0

## Döngü katmanları: aynı anda en çok bu kadar oynatıcı üretilir (sızıntıya karşı üst sınır).
const MAX_LOOP_LAYERS: int = 32
const LOOP_DEFAULT_DB: float = -6.0
const LOOP_DEFAULT_FADE_S: float = 0.5
const LOOP_PITCH_MIN: float = 0.25
const LOOP_PITCH_MAX: float = 4.0

## Çıkışta ses iş parçacığının durdurulan akışları bırakması için beklenen süre (ms).
const AUDIO_DRAIN_MSEC: int = 50

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
## p2-slice: `stop_music` kısma tweeni (yeni `play_music` onu iptal eder).
var _music_stop_tween: Tween = null
## Her ses adı için son çalınan varyant: aynı varyantın arka arkaya tekrarı "makine" gibi duyulur.
var _last_variant: Dictionary = {}
## Adlı döngü katmanları: id -> LoopLayer. Boştaki oynatıcılar `_loop_free` içinde yeniden kullanılır.
var _layers: Dictionary = {}
var _loop_free: Array[AudioStreamPlayer] = []
var _loop_all: Array[AudioStreamPlayer] = []
var _loop_streams: Dictionary = {}
var _jingle: AudioStreamPlayer = null
var _duck_tween: Tween = null
var _duck_offset_db: float = 0.0


## Bir döngü katmanının durumu. Hedef değerler (`*_target`) süzülmeler bitmeden de okunabilir.
class LoopLayer extends RefCounted:
	var player: AudioStreamPlayer = null
	var sound_name: String = ""
	var volume_target: float = 0.0
	var pitch_target: float = 1.0
	var stopping: bool = false
	var volume_tween: Tween = null
	var pitch_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_silent = DisplayServer.get_name() == "headless"
	_table = _load_table()
	_ensure_buses()
	var bus_name: StringName = BUS_SFX
	for i: int in POOL_SIZE:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = bus_name
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_pool.append(player)
	# Ambiyans efektlerden bağımsız bir oynatıcıda: havuz döngüsü onu kesmesin.
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = BUS_AMBIENCE
	_ambience.process_mode = Node.PROCESS_MODE_ALWAYS
	_ambience.volume_db = SILENT_DB
	add_child(_ambience)
	# Tablo/akışlar hazır; diğer autoload'lar bitsin diye bir kare sonra başlat.
	_music = AudioStreamPlayer.new()
	_music.bus = BUS_MUSIC
	_music.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music)
	# Kısa müzik parçaları (kazanma) döngüsüz, havuzdan bağımsız oynatıcıda: havuz turu onu kesmesin.
	_jingle = AudioStreamPlayer.new()
	_jingle.bus = BUS_MUSIC
	_jingle.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_jingle)
	if has_sound(AMBIENCE_NAME):
		play_ambience.call_deferred(AMBIENCE_NAME, AMBIENCE_VOLUME_DB)
	if has_sound(MUSIC_NAME):
		play_music.call_deferred(MUSIC_NAME, MUSIC_VOLUME_DB)


## Çıkışta çalan akışlar durdurulup bırakılır. Neden: çalan oynatma (müzik/ambiyans) ses
## sunucusunda referans tutuyordu; her pencereli çıkışta "ObjectDB instances leaked" ve
## "resources still in use" uyarısı basılıyordu.
func _exit_tree() -> void:
	var players: Array[AudioStreamPlayer] = _pool.duplicate()
	players.append_array([_ambience, _music, _jingle])
	players.append_array(_loop_all)
	for player: AudioStreamPlayer in players:
		if player != null:
			player.stop()
	# Durdurulan oynatmayı ses karıştırma iş parçacığı bir sonraki turunda bırakır; çıkışta o tur
	# gelmeden nesne denetimi yapılınca sızıntı sayılıyordu. Kısa bekleme yalnız çıkışta olur.
	OS.delay_msec(AUDIO_DRAIN_MSEC)
	for player: AudioStreamPlayer in players:
		if player != null:
			player.stream = null
			player.free()
	_pool.clear()
	_layers.clear()
	_loop_free.clear()
	_loop_all.clear()
	_loop_streams.clear()
	_ambience = null
	_music = null
	_jingle = null
	_cache.clear()


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


## Belirli bir perdeyle çalar (art arda ödüllerde yükselen nota gibi).
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
	if _music_stop_tween != null and _music_stop_tween.is_valid():
		_music_stop_tween.kill()
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


# --- p2-slice: müziği yumuşakça durdurma (kazanma anı, ana ekrana dönüş) ---
## Döngülü müziği `fade_out` sürede kısıp durdurur; sonraki `play_music` aynı parçayı baştan açar.
func stop_music(fade_out: float = 1.0) -> void:
	if _music == null or not _music.playing:
		return
	_music_name = ""
	var player: AudioStreamPlayer = _music
	var fade: Tween = create_tween()
	_music_stop_tween = fade
	fade.tween_property(player, "volume_db", SILENT_DB, maxf(fade_out, 0.01))
	fade.tween_callback(func() -> void:
		if _music_name == "":
			player.stop())


## Kısa, döngüsüz müzik parçasını (ör. kazanma) Müzik bus'ında çalar. Yeni parça eskisini keser.
func play_jingle(sound_name: String, volume_db: float = 0.0) -> void:
	if _silent or _jingle == null or not _music_on:
		return
	var stream: AudioStream = _stream(sound_name)
	if stream == null:
		return
	_jingle.stream = stream
	_jingle.volume_db = volume_db
	_jingle.play()


## Adlı döngü katmanını başlatır (cihaz sesi, elektrik uğultusu...). Aynı `id` aynı sesle zaten çalıyorsa
## yeniden başlatmaz, yalnız seviyeyi `fade_in` sürede ayarlar. Farklı sesle çağrılırsa katman o sese geçer.
## Ses ayarı kapalıyken katman kaydolur ama duraklatılmış kalır. Tabloda olmayan ses sessizce yok sayılır.
func start_loop(id: String, sound_name: String, volume_db: float = LOOP_DEFAULT_DB, fade_in: float = LOOP_DEFAULT_FADE_S) -> void:
	var existing: LoopLayer = _layers.get(id) as LoopLayer
	if existing != null and not existing.stopping and existing.sound_name == sound_name:
		set_loop_volume(id, volume_db, fade_in)
		return
	var stream: AudioStream = _loop_stream(sound_name)
	if stream == null:
		return
	var layer: LoopLayer = existing
	if layer == null:
		var player: AudioStreamPlayer = _acquire_loop_player()
		if player == null:
			return
		layer = LoopLayer.new()
		layer.player = player
		_layers[id] = layer
	_kill_layer_tweens(layer)
	layer.stopping = false
	layer.sound_name = sound_name
	layer.pitch_target = 1.0
	layer.volume_target = volume_db
	var target: AudioStreamPlayer = layer.player
	target.stream = stream
	target.pitch_scale = 1.0
	# Katmanlar aynı anda başlayınca "faz toplanması" olmasın: başlangıç noktası rastgele.
	target.volume_db = volume_db if fade_in <= 0.0 else SILENT_DB
	target.play(randf() * maxf(stream.get_length() - 0.1, 0.0))
	target.stream_paused = not _sound_on
	if fade_in > 0.0:
		layer.volume_tween = create_tween()
		layer.volume_tween.tween_property(target, "volume_db", volume_db, fade_in)


## Katmanı `fade_out` sürede kısıp durdurur ve oynatıcıyı havuza geri verir. Tanımsız `id` yok sayılır.
func stop_loop(id: String, fade_out: float = LOOP_DEFAULT_FADE_S) -> void:
	var layer: LoopLayer = _layers.get(id) as LoopLayer
	if layer == null or layer.stopping:
		return
	layer.stopping = true
	if fade_out <= 0.0:
		_release_layer(id, layer)
		return
	_kill_layer_tweens(layer)
	layer.volume_tween = create_tween()
	layer.volume_tween.tween_property(layer.player, "volume_db", SILENT_DB, fade_out)
	layer.volume_tween.tween_callback(_release_layer.bind(id, layer))


## Tüm katmanları durdurur.
func stop_all_loops(fade_out: float = LOOP_DEFAULT_FADE_S) -> void:
	for id: String in _layers.keys():
		stop_loop(id, fade_out)


## Katmanın perdesini `glide_seconds` sürede kaydırır (hat dolarken yükselen elektrik uğultusu).
func set_loop_pitch(id: String, pitch: float, glide_seconds: float = 0.0) -> void:
	var layer: LoopLayer = _layers.get(id) as LoopLayer
	if layer == null or layer.stopping:
		return
	var clamped: float = clampf(pitch, LOOP_PITCH_MIN, LOOP_PITCH_MAX)
	layer.pitch_target = clamped
	if layer.pitch_tween != null and layer.pitch_tween.is_valid():
		layer.pitch_tween.kill()
	if glide_seconds <= 0.0:
		layer.player.pitch_scale = clamped
		return
	layer.pitch_tween = create_tween()
	layer.pitch_tween.tween_property(layer.player, "pitch_scale", clamped, glide_seconds)


## Katmanın ses seviyesini (dB) `glide_seconds` sürede kaydırır.
func set_loop_volume(id: String, volume_db: float, glide_seconds: float = 0.0) -> void:
	var layer: LoopLayer = _layers.get(id) as LoopLayer
	if layer == null or layer.stopping:
		return
	layer.volume_target = volume_db
	if layer.volume_tween != null and layer.volume_tween.is_valid():
		layer.volume_tween.kill()
	if glide_seconds <= 0.0:
		layer.player.volume_db = volume_db
		return
	layer.volume_tween = create_tween()
	layer.volume_tween.tween_property(layer.player, "volume_db", volume_db, glide_seconds)


## Katman çalıyor mu (kapanma süzülmesindeki katman çalmıyor sayılır). Ses ayarı kapalıyken de true döner.
func is_loop_playing(id: String) -> bool:
	var layer: LoopLayer = _layers.get(id) as LoopLayer
	return layer != null and not layer.stopping


## Çalan katmanların kimlikleri.
func loop_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in _layers.keys():
		if is_loop_playing(id):
			ids.append(id)
	return ids


## Katmanın hedef ses seviyesi (dB); yoksa SILENT_DB.
func loop_volume_target(id: String) -> float:
	var layer: LoopLayer = _layers.get(id) as LoopLayer
	return SILENT_DB if layer == null else layer.volume_target


## Katmanın hedef perdesi; yoksa 1.0.
func loop_pitch_target(id: String) -> float:
	var layer: LoopLayer = _layers.get(id) as LoopLayer
	return 1.0 if layer == null else layer.pitch_target


## Katmanın oynatıcısı (hata ayıklama ve testler için); yoksa null.
func loop_player(id: String) -> AudioStreamPlayer:
	var layer: LoopLayer = _layers.get(id) as LoopLayer
	return null if layer == null else layer.player


## Oluşturulmuş toplam döngü oynatıcısı (boştakiler dahil): sızıntı denetimi için.
func loop_player_count() -> int:
	return _loop_all.size()


## Döngüleri, ortamı ve müziği kısa süre kısar (sigorta atması sessizliği). `seconds` kısık kalma süresi;
## sonra DUCK_RELEASE_S içinde geri açılır. `depth_db` kısma miktarı (negatif ya da pozitif verilebilir).
## Efektler (SFX bus'ı) kısılmaz. Art arda çağrı, kalan kısmayı yeniler.
func duck(seconds: float, depth_db: float = DUCK_DEFAULT_DEPTH_DB) -> void:
	var depth: float = -absf(depth_db)
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(_apply_duck, _duck_offset_db, depth, DUCK_ATTACK_S)
	_duck_tween.tween_interval(maxf(seconds, 0.0))
	_duck_tween.tween_method(_apply_duck, depth, 0.0, DUCK_RELEASE_S)


## Şu anki kısma miktarı (dB, 0 = kısık değil).
func duck_offset_db() -> float:
	return _duck_offset_db


## Bus'ları kurar (yoksa): SFX / Loops / Ambience / Music, hepsi Master'a gider; Master'da limiter.
## Çalışma anında yapılır: bus düzeni dosyasına bağlı kalmadan testlerde de aynıdır. Tekrar çağrı zararsız.
func _ensure_buses() -> void:
	AudioServer.set_bus_volume_db(0, MASTER_VOLUME_DB)
	for bus_name: StringName in BUS_LEVELS.keys():
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var idx: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, BUS_MASTER)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus_name), float(BUS_LEVELS[bus_name]))
	var master: int = AudioServer.get_bus_index(BUS_MASTER)
	for i: int in AudioServer.get_bus_effect_count(master):
		var existing: AudioEffect = AudioServer.get_bus_effect(master, i)
		if existing is AudioEffectHardLimiter or existing is AudioEffectLimiter:
			return
	var limiter: AudioEffectHardLimiter = AudioEffectHardLimiter.new()
	limiter.ceiling_db = LIMITER_CEILING_DB
	AudioServer.add_bus_effect(master, limiter)


func _apply_duck(offset_db: float) -> void:
	_duck_offset_db = offset_db
	for bus_name: StringName in DUCK_BUSES:
		var idx: int = AudioServer.get_bus_index(bus_name)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, float(BUS_LEVELS[bus_name]) + offset_db)


func _acquire_loop_player() -> AudioStreamPlayer:
	if not _loop_free.is_empty():
		return _loop_free.pop_back()
	if _loop_all.size() >= MAX_LOOP_LAYERS:
		push_warning("AudioService: en çok %d döngü katmanı" % MAX_LOOP_LAYERS)
		return null
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = BUS_LOOPS
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	_loop_all.append(player)
	return player


func _kill_layer_tweens(layer: LoopLayer) -> void:
	if layer.volume_tween != null and layer.volume_tween.is_valid():
		layer.volume_tween.kill()
	if layer.pitch_tween != null and layer.pitch_tween.is_valid():
		layer.pitch_tween.kill()


## Katmanı bırakır; ancak kimlik hâlâ aynı katmana işaret ediyorsa (araya yeni start_loop girmediyse).
func _release_layer(id: String, layer: LoopLayer) -> void:
	if _layers.get(id) != layer:
		return
	_kill_layer_tweens(layer)
	layer.player.stop()
	layer.player.stream = null
	layer.player.volume_db = SILENT_DB
	layer.player.pitch_scale = 1.0
	_layers.erase(id)
	_loop_free.append(layer.player)


## Döngüye alınmış akış, ada göre bir kez üretilir (her başlatmada kopyalanmasın).
func _loop_stream(sound_name: String) -> AudioStream:
	if _loop_streams.has(sound_name):
		return _loop_streams[sound_name] as AudioStream
	var stream: AudioStream = _stream(sound_name)
	if stream == null:
		return null
	var ogg: AudioStreamOggVorbis = stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = true
	var looped: AudioStream = _looped(stream)
	_loop_streams[sound_name] = looped
	return looped


## Ayar: efektler + ortam sesi.
func set_sound_enabled(enabled: bool) -> void:
	_sound_on = enabled
	if _ambience != null:
		_ambience.stream_paused = not enabled
	# Döngü katmanları kaybolmaz, duraklar: ayar açılınca kaldığı yerden sürer.
	for player: AudioStreamPlayer in _loop_all:
		player.stream_paused = not enabled


## Ayar: arka plan müziği.
func set_music_enabled(enabled: bool) -> void:
	_music_on = enabled
	if _music != null:
		_music.stream_paused = not enabled
	if _jingle != null:
		_jingle.stream_paused = not enabled


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
