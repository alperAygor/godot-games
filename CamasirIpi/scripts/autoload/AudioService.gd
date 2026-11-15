extends Node

## Tek ses girişi. Sesler `data/sounds.json` tablosundan ada göre yüklenir;
## böylece iskelette hiç ses dosyası yokken de hata vermez.

const SOUNDS_PATH: String = "res://data/sounds.json"
const POOL_SIZE: int = 8
## Oyun açılınca otomatik başlayan bahçe ortamı; efektlerin altında "oda tonu" olsun.
const AMBIENCE_NAME: String = "garden_ambience"
const MUSIC_NAME: String = "music_garden"

## Bus'lar (çalışma anında kurulur; yoksa eklenir). Master'a sert sınırlayıcı konur: çok ses üst üste
## binince (müzik + ortam + birkaç efekt) kırpılma olmasın, dosyalar da yüksek seviyede tutulabilsin.
const BUS_MASTER: StringName = &"Master"
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
const BUS_AMBIENCE: StringName = &"Ambience"
const LIMITER_CEILING_DB: float = -1.0
const LIMITER_PRE_GAIN_DB: float = 2.0
const LIMITER_RELEASE_S: float = 0.15

## Seviyeler (dB, bus öncesi): dosyalar kategori başına hedef LUFS'a normalleştirildi (docs/AUDIO.md).
## Ortam yatağı -25 LUFS'ta, müzik -17 LUFS'ta; oyun müziği ayrıca MusicRouter.GAME_VOLUME_DB kadar kısık.
const AMBIENCE_VOLUME_DB: float = 0.0
## Ana ekranda müzik öne çıkar, ortam yatağı geri çekilir.
const AMBIENCE_MENU_DB: float = -6.0
const AMBIENCE_FADE_IN_S: float = 3.0
const AMBIENCE_FADE_OUT_S: float = 1.2
const MUSIC_FADE_IN_S: float = 3.0
## Sessizlik: fade-out bitince oynatıcıyı gerçekten susturmak için kullanılan taban.
const SILENT_DB: float = -80.0
## Önemli jingle'larda müzik kısılır (Music bus), jingle bitince yavaşça geri gelir.
const DUCK_SOUNDS: Array[String] = ["win", "lose", "success", "chest_open"]
const DUCK_DB: float = -4.0
const DUCK_ATTACK_S: float = 0.12
const DUCK_RELEASE_S: float = 0.9
const DUCK_MAX_HOLD_S: float = 2.2

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
## Ortam geçişinde çıkan döngü bu oynatıcıda sönerken yenisi `_ambience`te açılır (sert kesme yok).
var _ambience_alt: AudioStreamPlayer = null
var _ambience_tween: Tween = null
var _ambience_name: String = ""
var _ambience_wanted_db: float = AMBIENCE_VOLUME_DB
## Müzik: iki oynatıcı sırayla çalar (çapraz geçiş); `_router` hangi parçanın çalacağını bilir.
var _music_players: Array[AudioStreamPlayer] = []
var _music_active: int = 0
var _music_tweens: Dictionary = {}
var _music_target_db: float = 0.0
var _router: MusicRouter = MusicRouter.new()
var _duck_tween: Tween = null
## Her ses adı için son çalınan varyant: aynı varyantın arka arkaya tekrarı "makine" gibi duyulur.
var _last_variant: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_silent = DisplayServer.get_name() == "headless"
	_table = _load_table()
	_setup_buses()
	for i: int in POOL_SIZE:
		var player: AudioStreamPlayer = _new_player(BUS_SFX)
		_pool.append(player)
	# Ambiyans efektlerden bağımsız bir oynatıcıda: havuz döngüsü onu kesmesin.
	_ambience = _new_player(BUS_AMBIENCE)
	_ambience.volume_db = SILENT_DB
	_ambience_alt = _new_player(BUS_AMBIENCE)
	_ambience_alt.volume_db = SILENT_DB
	for i: int in 2:
		var music_player: AudioStreamPlayer = _new_player(BUS_MUSIC)
		music_player.volume_db = SILENT_DB
		_music_players.append(music_player)
	# Sahne değişimini dinle: ana ekrana dönünce menü teması, oyuna girince mekân parçası (home.gd/game.gd değişmeden).
	get_tree().root.child_entered_tree.connect(_on_root_child_entered)
	# Tablo/akışlar hazır; diğer autoload'lar bitsin diye bir kare sonra başlat.
	_start_ambience.call_deferred(AMBIENCE_NAME, AMBIENCE_MENU_DB)
	play_music.call_deferred(MUSIC_NAME)


func _new_player(bus_name: StringName) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = bus_name
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


## Music / SFX / Ambience bus'larını ve Master sınırlayıcısını kurar (idempotent).
func _setup_buses() -> void:
	for bus_name: StringName in [BUS_MUSIC, BUS_SFX, BUS_AMBIENCE]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, BUS_MASTER)
	var master: int = AudioServer.get_bus_index(BUS_MASTER)
	for effect_index: int in AudioServer.get_bus_effect_count(master):
		if AudioServer.get_bus_effect(master, effect_index) is AudioEffectHardLimiter:
			return
	var limiter: AudioEffectHardLimiter = AudioEffectHardLimiter.new()
	limiter.pre_gain_db = LIMITER_PRE_GAIN_DB
	limiter.ceiling_db = LIMITER_CEILING_DB
	limiter.release = LIMITER_RELEASE_S
	AudioServer.add_bus_effect(master, limiter)


## Çıkışta çalan akışlar durdurulup bırakılır. Neden: çalan oynatma (müzik/ambiyans) ses
## sunucusunda referans tutuyordu; her pencereli çıkışta "6 ObjectDB instances leaked" ve
## "2 resources still in use" (music_garden.ogg) uyarısı basılıyordu.
func _exit_tree() -> void:
	var players: Array[AudioStreamPlayer] = _pool.duplicate()
	players.append(_ambience)
	players.append(_ambience_alt)
	players.append_array(_music_players)
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
	_ambience = null
	_ambience_alt = null
	_music_players.clear()
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
	_maybe_duck(sound_name, stream)


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
	_maybe_duck(sound_name, stream)


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
## Oyun bunu seviye başında çağırır; ortam adı mekânı ve geceyi taşıdığı için müzik parçası da buradan seçilir.
func play_ambience(sound_name: String, volume_db: float = AMBIENCE_VOLUME_DB) -> void:
	if _silent or _ambience == null:
		return
	_request_music(_router.on_ambience(sound_name), NAN)
	_start_ambience(sound_name, volume_db)


func _start_ambience(sound_name: String, volume_db: float) -> void:
	if _ambience.playing and _ambience_name == sound_name:
		_ambience_wanted_db = volume_db
		_fade_ambience(volume_db, AMBIENCE_FADE_IN_S)
		return
	var stream: AudioStream = _stream(sound_name)
	if stream == null:
		return
	if _ambience.playing:
		# Eski döngüyü yumuşakça söndür; yenisi diğer oynatıcıda açılır.
		var old: AudioStreamPlayer = _ambience
		_ambience = _ambience_alt
		_ambience_alt = old
		var fade_out: Tween = create_tween()
		fade_out.tween_property(old, "volume_db", SILENT_DB, AMBIENCE_FADE_OUT_S)
		fade_out.tween_callback(old.stop)
	_ambience.stream = _looped(stream)
	_ambience_name = sound_name
	_ambience.volume_db = SILENT_DB  # Klik olmasın diye sessizlikten başla.
	_ambience.pitch_scale = 1.0
	_ambience.play()
	_ambience.stream_paused = not _sound_on
	_ambience_wanted_db = volume_db
	_fade_ambience(volume_db, AMBIENCE_FADE_IN_S)


## Ortam sesini yumuşakça kısıp durdurur.
func stop_ambience() -> void:
	if _ambience == null or not _ambience.playing:
		return
	_ambience_name = ""
	_fade_ambience(SILENT_DB, AMBIENCE_FADE_OUT_S, true)


## Döngülü arka plan müziğini ister. Ad bağlama göre çözülür (ana ekranda mekân parçası istenirse menü
## teması çalar); çalan parça zaten buysa HİÇBİR ŞEY yapılmaz (yeniden başlatma yok), farklıysa eski parça
## yumuşakça kısılırken yenisi açılır. `volume_db` verilmezse parçanın varsayılanı kullanılır.
func play_music(sound_name: String, volume_db: float = NAN) -> void:
	if _silent or _music_players.is_empty():
		return
	_request_music(_router.on_play_music(sound_name), volume_db)


## Ayar: efektler + ortam sesi.
func set_sound_enabled(enabled: bool) -> void:
	_sound_on = enabled
	for player: AudioStreamPlayer in [_ambience, _ambience_alt]:
		if player != null:
			player.stream_paused = not enabled


## Ayar: arka plan müziği.
func set_music_enabled(enabled: bool) -> void:
	_music_on = enabled
	for player: AudioStreamPlayer in _music_players:
		player.stream_paused = not enabled


## Çalan müziğin adı (boş = yok); test ve hata ayıklama için.
func current_music() -> String:
	return _router.current


## Reklam/arka plan dönüşü: platform akışı durdurduysa müzik ve ortam kaldığı yerden yeniden kurulur.
func resume_audio() -> void:
	if _silent:
		return
	if _ambience != null and not _ambience_name.is_empty() and not _ambience.playing:
		_ambience.play()
		_ambience.volume_db = _ambience_wanted_db
	if _ambience != null:
		_ambience.stream_paused = not _sound_on
	var active: AudioStreamPlayer = _active_music_player()
	if active != null and not _router.current.is_empty():
		if not active.playing:
			active.play()
			active.volume_db = _music_target_db
		active.stream_paused = not _music_on


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN \
			or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		resume_audio.call_deferred()


func _active_music_player() -> AudioStreamPlayer:
	if _music_players.is_empty():
		return null
	return _music_players[_music_active]


## Yeni bir kök sahne eklendi: bağlam (menü/oyun) değişmiş olabilir. Yol boşsa (açılır pencere vb.) yok sayılır.
func _on_root_child_entered(node: Node) -> void:
	if node.scene_file_path.is_empty():
		return
	var was_game: bool = _router.context == MusicRouter.Context.GAME
	var track: String = _router.on_scene(node.scene_file_path)
	_request_music(track, NAN)
	var is_game: bool = _router.context == MusicRouter.Context.GAME
	if was_game and not is_game and _ambience != null and _ambience.playing:
		_ambience_wanted_db = AMBIENCE_MENU_DB
		_fade_ambience(AMBIENCE_MENU_DB, AMBIENCE_FADE_IN_S)


func _request_music(track: String, volume_db: float) -> void:
	if _silent or _music_players.is_empty():
		return
	_music_target_db = volume_db if not is_nan(volume_db) else MusicRouter.volume_db_for(track)
	if not _router.needs_switch(track):
		# Aynı parça: yeniden başlatma yok; yalnız seviyeyi (bağlam değiştiyse) ve çalmayı güvenceye al.
		var current_player: AudioStreamPlayer = _active_music_player()
		if current_player != null and current_player.playing:
			_fade_music_player(current_player, current_player.volume_db, _music_target_db, MusicRouter.CROSSFADE_MENU_S, true)
		return
	var stream: AudioStream = _stream(track)
	if stream == null:
		return
	var ogg: AudioStreamOggVorbis = stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = true
	var fade_seconds: float = MusicRouter.crossfade_seconds(_router.current, track)
	var outgoing: AudioStreamPlayer = _active_music_player()
	_music_active = 1 - _music_active
	var incoming: AudioStreamPlayer = _active_music_player()
	incoming.stream = _looped(stream)
	incoming.volume_db = SILENT_DB
	incoming.play()
	incoming.stream_paused = not _music_on
	_router.commit(track)
	# Giren: sessizlikten hedefe; çıkan: şimdiki seviyesinden sessizliğe (eşit güçlü), sonra durur.
	_fade_music_player(incoming, SILENT_DB, _music_target_db, fade_seconds, true)
	if outgoing != null and outgoing.playing:
		_fade_music_player(outgoing, outgoing.volume_db, SILENT_DB, fade_seconds, false)


## Bir müzik oynatıcısının seviyesini eşit güçlü eğriyle geçirir. `rising` false ise sonunda durdurur.
func _fade_music_player(player: AudioStreamPlayer, from_db: float, to_db: float, seconds: float, rising: bool) -> void:
	var old: Variant = _music_tweens.get(player)
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	var fade: Tween = create_tween()
	_music_tweens[player] = fade
	fade.tween_method(_apply_music_fade.bind(player, from_db, to_db, rising), 0.0, 1.0, seconds)
	if not rising:
		fade.tween_callback(player.stop)


func _apply_music_fade(t: float, player: AudioStreamPlayer, from_db: float, to_db: float, rising: bool) -> void:
	if not is_instance_valid(player):
		return
	var curve: Vector2 = MusicRouter.equal_power_db(t)
	if rising:
		# Sessizlikten açılış eşit güçlü eğriyle; yeniden hedefleme (seviye değişimi) doğrusal.
		player.volume_db = maxf(to_db + curve.y, SILENT_DB) if from_db <= SILENT_DB else lerpf(from_db, to_db, t)
	else:
		player.volume_db = maxf(from_db + curve.x, SILENT_DB)


## Önemli jingle çalarken müzik bus'ını kısar, jingle bitince yumuşakça geri getirir.
func _maybe_duck(sound_name: String, stream: AudioStream) -> void:
	if not MusicRouter.is_duck_sound(sound_name, DUCK_SOUNDS):
		return
	var index: int = AudioServer.get_bus_index(BUS_MUSIC)
	if index < 0:
		return
	if _duck_tween != null and _duck_tween.is_valid():
		_duck_tween.kill()
	var hold: float = MusicRouter.duck_hold_seconds(stream.get_length(), DUCK_MAX_HOLD_S)
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_music_bus_db, AudioServer.get_bus_volume_db(index), DUCK_DB, DUCK_ATTACK_S)
	_duck_tween.tween_interval(hold)
	_duck_tween.tween_method(_set_music_bus_db, DUCK_DB, 0.0, DUCK_RELEASE_S)


func _set_music_bus_db(value: float) -> void:
	var index: int = AudioServer.get_bus_index(BUS_MUSIC)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, value)


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
