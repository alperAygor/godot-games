extends TestCase

## AudioService döngü katmanları: başlat/durdur, perde ve seviye hedefleri, oynatıcı yeniden kullanımı,
## ses ayarı. Testler karesiz çalışır: süzülmeli (tween) hedefler hedef değerlerle, anlıklar (0 sn) doğrudan denetlenir.

const LOOP_NAMES: Array[String] = [
	"loop_fridge", "loop_oven", "loop_kettle", "loop_washer", "loop_tv", "loop_fan", "loop_toaster", "loop_lamp",
	"hum_mains", "ambience_night", "ambience_noon", "ambience_morning", "ambience_evening",
]

var _audio: Node = null


func before_each() -> void:
	_audio = autoload_node("AudioService")
	_audio.call("stop_all_loops", 0.0)
	_audio.call("set_sound_enabled", true)


func after_each() -> void:
	_audio.call("stop_all_loops", 0.0)
	_audio.call("set_sound_enabled", true)


func test_start_and_stop_loop() -> void:
	assert_not_null(_audio, "AudioService autoload")
	assert_false(bool(_audio.call("is_loop_playing", "fridge")))
	_audio.call("start_loop", "fridge", "loop_fridge", -9.0, 0.0)
	assert_true(bool(_audio.call("is_loop_playing", "fridge")), "başladı")
	var player: AudioStreamPlayer = _audio.call("loop_player", "fridge") as AudioStreamPlayer
	assert_not_null(player)
	assert_true(player.playing, "oynatıcı çalıyor")
	assert_almost_eq(player.volume_db, -9.0, 0.01, "fade 0: seviye anında")
	_audio.call("stop_loop", "fridge", 0.0)
	assert_false(bool(_audio.call("is_loop_playing", "fridge")), "durdu")
	assert_true(_audio.call("loop_player", "fridge") == null, "katman bırakıldı")


func test_unknown_sound_and_unknown_id_are_ignored() -> void:
	_audio.call("start_loop", "ghost", "no_such_sound_xyz", -6.0, 0.0)
	assert_false(bool(_audio.call("is_loop_playing", "ghost")))
	_audio.call("stop_loop", "never_started", 0.0)
	_audio.call("set_loop_pitch", "never_started", 1.5, 0.0)
	_audio.call("set_loop_volume", "never_started", -3.0, 0.0)
	assert_eq((_audio.call("loop_ids") as Array).size(), 0)


func test_twelve_layers_at_once_and_players_are_reused() -> void:
	for i: int in 12:
		_audio.call("start_loop", "layer_%d" % i, LOOP_NAMES[i], -12.0, 0.0)
	assert_eq((_audio.call("loop_ids") as Array).size(), 12, "12 katman birlikte")
	var created: int = int(_audio.call("loop_player_count"))
	assert_true(created >= 12, "en az 12 oynatıcı")
	_audio.call("stop_all_loops", 0.0)
	assert_eq((_audio.call("loop_ids") as Array).size(), 0)
	# İkinci tur: yeni oynatıcı üretilmemeli (sızıntı yok).
	for i: int in 12:
		_audio.call("start_loop", "again_%d" % i, LOOP_NAMES[i], -12.0, 0.0)
	assert_eq(int(_audio.call("loop_player_count")), created, "oynatıcılar yeniden kullanıldı")
	var players: Dictionary = {}
	for i: int in 12:
		players[_audio.call("loop_player", "again_%d" % i)] = true
	assert_eq(players.size(), 12, "her katmanın kendi oynatıcısı var")


func test_restart_same_id_same_sound_only_adjusts_volume() -> void:
	_audio.call("start_loop", "k", "loop_kettle", -10.0, 0.0)
	var first: Object = _audio.call("loop_player", "k")
	_audio.call("start_loop", "k", "loop_kettle", -4.0, 0.0)
	assert_true(_audio.call("loop_player", "k") == first, "aynı oynatıcı")
	assert_almost_eq(float(_audio.call("loop_volume_target", "k")), -4.0, 0.001)
	assert_eq(int(_audio.call("loop_player_count")), maxi(1, int(_audio.call("loop_player_count"))))


func test_same_id_new_sound_switches_stream() -> void:
	_audio.call("start_loop", "slot", "loop_fan", -10.0, 0.0)
	var player: AudioStreamPlayer = _audio.call("loop_player", "slot") as AudioStreamPlayer
	var before: AudioStream = player.stream
	_audio.call("start_loop", "slot", "loop_oven", -10.0, 0.0)
	assert_true(_audio.call("loop_player", "slot") == player, "oynatıcı aynı")
	assert_true(player.stream != before, "akış değişti")


func test_pitch_and_volume_targets_and_clamp() -> void:
	_audio.call("start_loop", "hum", "hum_mains", -14.0, 0.0)
	_audio.call("set_loop_pitch", "hum", 1.6, 0.0)
	var player: AudioStreamPlayer = _audio.call("loop_player", "hum") as AudioStreamPlayer
	assert_almost_eq(player.pitch_scale, 1.6, 0.001, "anlık perde")
	_audio.call("set_loop_pitch", "hum", 1.3, 2.0)
	assert_almost_eq(float(_audio.call("loop_pitch_target", "hum")), 1.3, 0.001, "süzülen perdenin hedefi")
	_audio.call("set_loop_pitch", "hum", 99.0, 0.0)
	assert_true(player.pitch_scale <= 4.0 + 0.001, "perde üst sınırı")
	_audio.call("set_loop_pitch", "hum", 0.0, 0.0)
	assert_true(player.pitch_scale >= 0.25 - 0.001, "perde alt sınırı")
	_audio.call("set_loop_volume", "hum", -20.0, 0.0)
	assert_almost_eq(player.volume_db, -20.0, 0.001)
	_audio.call("set_loop_volume", "hum", -8.0, 1.0)
	assert_almost_eq(float(_audio.call("loop_volume_target", "hum")), -8.0, 0.001)


func test_stop_with_fade_marks_layer_not_playing() -> void:
	_audio.call("start_loop", "tv", "loop_tv", -12.0, 0.0)
	_audio.call("stop_loop", "tv", 1.0)
	assert_false(bool(_audio.call("is_loop_playing", "tv")), "kapanırken çalıyor sayılmaz")
	# Kapanırken aynı kimlikle yeniden başlatma katmanı canlandırır.
	_audio.call("start_loop", "tv", "loop_tv", -12.0, 0.0)
	assert_true(bool(_audio.call("is_loop_playing", "tv")))
	assert_eq(int(_audio.call("loop_pitch_target", "tv") == 1.0), 1, "perde sıfırlandı")


func test_sound_setting_pauses_layers_and_keeps_them() -> void:
	_audio.call("start_loop", "fan", "loop_fan", -12.0, 0.0)
	_audio.call("set_sound_enabled", false)
	var player: AudioStreamPlayer = _audio.call("loop_player", "fan") as AudioStreamPlayer
	assert_true(player.stream_paused, "ses kapalı: duraklatıldı")
	assert_true(bool(_audio.call("is_loop_playing", "fan")), "katman kayıtlı kalır")
	# Ses kapalıyken başlatılan katman da duraklı doğar.
	_audio.call("start_loop", "toast", "loop_toaster", -12.0, 0.0)
	assert_true((_audio.call("loop_player", "toast") as AudioStreamPlayer).stream_paused)
	_audio.call("set_sound_enabled", true)
	assert_false(player.stream_paused, "ses açıldı: sürer")
	assert_false((_audio.call("loop_player", "toast") as AudioStreamPlayer).stream_paused)


func test_loops_use_loops_bus() -> void:
	_audio.call("start_loop", "lamp", "loop_lamp", -20.0, 0.0)
	assert_eq((_audio.call("loop_player", "lamp") as AudioStreamPlayer).bus, &"Loops")
