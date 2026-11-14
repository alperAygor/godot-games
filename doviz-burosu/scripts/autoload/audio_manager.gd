extends Node
## Müzik ve efekt çalma, bus ses seviyeleri. Ses seviyeleri SettingsManager'dan gelir.

const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const SFX_POOL_SIZE := 8
const TRACK_DB := -5.0
const AMBIENT_DB := -13.0
## Sahne -> müzik parçası. Boş/eksik sahne mevcut müziği sürdürür (market ve ayarlar menü müziğiyle devam eder).
## Masa parçasını `set_tension`, son ekranı kendisi seçer.
const SCENE_TRACKS := {
	"res://scenes/main.tscn": "theme_main",
	"res://scenes/morning.tscn": "morning",
	"res://scenes/desk.tscn": "desk_calm",
	"res://scenes/evening.tscn": "evening",
}

var _music_player: AudioStreamPlayer
## Müzik parçaları: iki oynatıcı çapraz geçişle (crossfade) birbirine devreder. Oda uğultusu (ambient) ayrı, sessiz bir katmandır.
var _tracks: Array[AudioStreamPlayer] = []
var _track_slot := 0
var _current_track := ""
var _ambient_player: AudioStreamPlayer
var _track_cache := {}
var _fade_tween: Tween
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cache := {}
var _blip_cache := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # oyun duraklasa da müzik çalsın
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)
	for i in 2:
		var track_player := AudioStreamPlayer.new()
		track_player.bus = MUSIC_BUS
		track_player.volume_db = -60.0
		add_child(track_player)
		_tracks.append(track_player)
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = MUSIC_BUS
	_ambient_player.volume_db = AMBIENT_DB
	add_child(_ambient_player)
	SceneManager.scene_changed.connect(_on_scene_changed)

	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_sfx_players.append(player)

	_apply_volumes()
	SettingsManager.setting_changed.connect(_on_setting_changed)


## Tüm sesleri durdurur ve akışları bırakır. Kapanmadan önce çağrılmalı; ses sunucusu
## durdurmayı sonraki karelerde işlediği için ardından bir iki kare beklenmeli.
func stop_all() -> void:
	for player: AudioStreamPlayer in _sfx_players + _tracks + [_music_player, _ambient_player]:
		if player != null:
			player.stop()
			player.stream = null
	_sfx_cache.clear()
	_blip_cache.clear()
	_track_cache.clear()
	_current_track = ""


## Kısa ses efekti akışı (assets/audio/sfx/<ad>.mp3). İlk kullanımda yüklenir, sonra önbellekten gelir: her seste diskten
## okuyup ayrıştırma yok. Önbellek `stop_all`/çıkışta boşaltılır (çıkışta "kaynak kullanımda" uyarısı olmasın). Dosya yoksa null.
func sfx_stream(sound: String) -> AudioStream:
	if _sfx_cache.has(sound):
		return _sfx_cache[sound]
	var path := "res://assets/audio/sfx/%s.mp3" % sound
	if not ResourceLoader.exists(path):
		path = "res://assets/audio/music/%s.mp3" % sound  # kısa müzik vuruşları (stinger_*)
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	_sfx_cache[sound] = stream
	return stream


## Konuşma bipi: 10 tizlik kademesi, ilk kullanımda üretilir ve saklanır (her harfte yeni ses nesnesi ayrılmaz).
func blip_stream(voice: float) -> AudioStream:
	var step := clampi(int(voice * 10.0), 0, 9)
	if _blip_cache.has(step):
		return _blip_cache[step]
	var rate := 22050
	var frequency := 150.0 + (step + 0.5) / 10.0 * 160.0
	var count := int(rate * 0.045)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		var envelope := minf(1.0, float(i) / 120.0) * (1.0 - float(i) / count)
		var square := 1.0 if fmod(t * frequency, 1.0) < 0.5 else -1.0
		data.encode_s16(i * 2, int(clampf(square * envelope * 0.22, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = false
	stream.data = data
	_blip_cache[step] = stream
	return stream


func _exit_tree() -> void:
	stop_all()


## Oda uğultusu: sürekli, çok kısık döngü (müziğin altında). Ekransız çalıştırmada çalmaz.
func play_ambient(stream: AudioStream) -> void:
	if DisplayServer.get_name() == "headless" or (_ambient_player.stream == stream and _ambient_player.playing):
		return
	_ambient_player.stream = stream
	_ambient_player.play()


## Müzik parçası akışı (assets/audio/music/<ad>.mp3), döngülü; ilk kullanımda yüklenir. Dosya yoksa null.
func track_stream(track: String) -> AudioStream:
	if _track_cache.has(track):
		return _track_cache[track]
	var path := "res://assets/audio/music/%s.mp3" % track
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStreamMP3
	if stream != null:
		stream.loop = true
	_track_cache[track] = stream
	return stream


## Parçayı çapraz geçişle başlatır (aynı parça zaten çalıyorsa dokunmaz). Ekransız çalıştırmada yalnızca adı hatırlar.
func play_track(track: String, fade := 1.4) -> void:
	if track == _current_track:
		return
	_current_track = track
	if DisplayServer.get_name() == "headless":
		return
	var stream := track_stream(track)
	if stream == null:
		return
	var incoming := _tracks[_track_slot]
	var outgoing := _tracks[1 - _track_slot]
	_track_slot = 1 - _track_slot
	incoming.stream = stream
	incoming.volume_db = -60.0
	incoming.play()
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween().set_parallel(true)
	_fade_tween.tween_property(incoming, "volume_db", TRACK_DB, fade)
	if outgoing.playing:
		_fade_tween.tween_property(outgoing, "volume_db", -60.0, fade)
		_fade_tween.chain().tween_callback(outgoing.stop)


func current_track() -> String:
	return _current_track


## Masada vardiyanın son bölümünde gergin parçaya geçer; sakinleşince (yeni gün) sakin parçaya döner.
func set_tension(tense: bool) -> void:
	if _current_track in ["desk_calm", "desk_tense"]:
		play_track("desk_tense" if tense else "desk_calm", 2.5)


func _on_scene_changed(path: String) -> void:
	if SCENE_TRACKS.has(path):
		play_track(str(SCENE_TRACKS[path]))


func play_music(stream: AudioStream) -> void:
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.play()


func stop_music() -> void:
	_music_player.stop()
	_music_player.stream = null  # akış bırakılır (çıkışta "kaynak kullanımda" uyarısı olmasın)


func play_sfx(stream: AudioStream, pitch_scale := 1.0) -> void:
	# Ekransız (test/CI) çalıştırmada ses sürücüsü sahte; oynatıcılar serbest kalmıyor ve
	# çıkışta "kaynak hâlâ kullanımda" hatası veriyor. Orada ses çalmaya gerek yok.
	if DisplayServer.get_name() == "headless":
		return
	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.pitch_scale = pitch_scale
			player.play()
			return
	# Havuz doluysa en eski sesi kes.
	_sfx_players[0].stream = stream
	_sfx_players[0].play()


## linear: 0.0 - 1.0
func set_bus_volume(bus_name: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	linear = clampf(linear, 0.0, 1.0)
	AudioServer.set_bus_mute(index, linear <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))


func _apply_volumes() -> void:
	set_bus_volume(&"Master", SettingsManager.get_value("audio", "master"))
	set_bus_volume(MUSIC_BUS, SettingsManager.get_value("audio", "music"))
	set_bus_volume(SFX_BUS, SettingsManager.get_value("audio", "sfx"))


func _on_setting_changed(section: String, _key: String, _value: Variant) -> void:
	if section == "audio":
		_apply_volumes()


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, &"Master")
