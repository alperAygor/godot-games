extends Node
## Ses motoru: Müzik/SFX/UI kanalları, çapraz geçişli müzik, sınırlayıcı ve
## aynı anda çok fazla tekrar eden efektler için hız sınırı.

## id: [dosya, desibel, perde sapması, en kısa aralık (sn), kanal]
const SFX := {
	"shoot": ["shoot", -15.0, 0.06, 0.03, "SFX"],
	"shoot_enemy": ["shoot_enemy", -19.0, 0.08, 0.05, "SFX"],
	"shoot_sniper": ["shoot_sniper", -9.0, 0.05, 0.08, "SFX"],
	"hit": ["hit", -15.5, 0.12, 0.035, "SFX"],
	"crit": ["crit", -7.5, 0.08, 0.06, "SFX"],
	"explode": ["explode", -11.0, 0.1, 0.05, "SFX"],
	"explode_big": ["explode_big", -7.0, 0.06, 0.12, "SFX"],
	"hurt": ["hurt", -4.5, 0.04, 0.1, "SFX"],
	"dash": ["dash", -10.0, 0.06, 0.05, "SFX"],
	"pickup_heal": ["pickup_heal", -8.5, 0.03, 0.05, "SFX"],
	"pickup_power": ["pickup_power", -8.0, 0.03, 0.05, "SFX"],
	"shield_up": ["shield_up", -9.0, 0.02, 0.1, "SFX"],
	"shield_break": ["shield_break", -2.0, 0.03, 0.1, "SFX"],
	"nova": ["nova", -3.5, 0.02, 0.2, "SFX"],
	"nova_ready": ["nova_ready", -9.5, 0.0, 0.5, "SFX"],
	"level_up": ["level_up", -6.5, 0.0, 0.2, "UI"],
	"card_pick": ["card_pick", -6.0, 0.0, 0.05, "UI"],
	"ui_click": ["ui_click", -8.0, 0.03, 0.02, "UI"],
	"ui_hover": ["ui_hover", -17.5, 0.03, 0.03, "UI"],
	"ui_back": ["ui_back", -10.0, 0.02, 0.02, "UI"],
	"ui_toggle": ["ui_toggle", -12.5, 0.02, 0.02, "UI"],
	"wave_start": ["wave_start", -5.5, 0.0, 0.3, "SFX"],
	"wave_clear": ["wave_clear", -8.0, 0.0, 0.3, "SFX"],
	"boss_warn": ["boss_warn", -3.5, 0.0, 0.5, "SFX"],
	"boss_phase": ["boss_phase", -4.5, 0.0, 0.5, "SFX"],
	"boss_die": ["boss_die", -2.5, 0.0, 0.5, "SFX"],
	"game_over": ["game_over", -4.0, 0.0, 0.5, "SFX"],
	"combo": ["combo", -8.0, 0.0, 0.06, "SFX"],
	"low_hp": ["low_hp", -7.5, 0.0, 0.3, "SFX"],
	"elite": ["elite", -9.0, 0.03, 0.3, "SFX"],
	"revive": ["revive", -3.5, 0.0, 0.5, "SFX"],
	"spawn": ["spawn", -19.5, 0.15, 0.07, "SFX"],
	"chain": ["chain", -12.0, 0.12, 0.05, "SFX"],
	"bomb_beep": ["bomb_beep", -13.0, 0.0, 0.05, "SFX"],
	"purchase": ["purchase", -8.5, 0.0, 0.05, "UI"],
	"synergy": ["synergy", -4.0, 0.0, 0.3, "UI"],
	"shoot_scatter": ["shoot_scatter", -8.5, 0.05, 0.05, "SFX"],
	"shoot_rail": ["shoot_rail", -9.0, 0.04, 0.08, "SFX"],
	"shoot_rocket": ["shoot_rocket", -18.0, 0.08, 0.06, "SFX"],
	"slam": ["slam", -6.5, 0.06, 0.06, "SFX"],
	"leap": ["leap", -9.0, 0.0, 0.3, "SFX"],
	"teleport": ["teleport", -10.5, 0.04, 0.2, "SFX"],
	"laser_charge": ["laser_charge", -11.5, 0.0, 0.3, "SFX"],
	"laser": ["laser", -16.5, 0.03, 0.2, "SFX"],
	"deny": ["deny", -12.5, 0.0, 0.1, "UI"],
}
const MUSIC := {
	"menu": ["music_menu", -12.5],
	"battle": ["music_battle", -10.5],
	"boss": ["music_boss", -13.0],
}
const POOL_SIZE := 22
const AUDIO_DIR := "res://assets/audio/"

var muted := false
var _headless := false
var _streams: Dictionary = {}
var _music_streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _started: Array[float] = []
var _last: Dictionary = {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_id := ""
var _music_tween: Tween
var _filter: AudioEffectLowPassFilter
var _filter_tween: Tween
var _next := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_headless = DisplayServer.get_name() == "headless"
	_setup_buses()
	for id in SFX:
		var path: String = AUDIO_DIR + str(SFX[id][0]) + ".wav"
		if ResourceLoader.exists(path):
			_streams[id] = load(path)
	for id in MUSIC:
		var path: String = AUDIO_DIR + str(MUSIC[id][0]) + ".wav"
		if ResourceLoader.exists(path):
			var stream: AudioStreamWAV = load(path)
			if stream:
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				stream.loop_begin = 0
				stream.loop_end = int(round(stream.get_length() * float(stream.mix_rate)))
				_music_streams[id] = stream
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_players.append(player)
		_started.append(0.0)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	get_tree().root.tree_exiting.connect(_shutdown)
	apply_volumes()
	Settings.changed.connect(func(_key): apply_volumes())

func _make_music_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = "Music"
	player.volume_db = -60.0
	add_child(player)
	return player

func _setup_buses() -> void:
	for bus_name in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -0.6
		limiter.pre_gain_db = 2.0
		AudioServer.add_bus_effect(master, limiter)
	var music := AudioServer.get_bus_index("Music")
	if AudioServer.get_bus_effect_count(music) == 0:
		_filter = AudioEffectLowPassFilter.new()
		_filter.cutoff_hz = 20000.0
		_filter.resonance = 0.6
		AudioServer.add_bus_effect(music, _filter)
	else:
		_filter = AudioServer.get_bus_effect(music, 0) as AudioEffectLowPassFilter

func apply_volumes() -> void:
	_set_bus("Music", 0.0 if muted else Settings.music)
	_set_bus("SFX", 0.0 if muted else Settings.sfx)
	_set_bus("UI", 0.0 if muted else Settings.sfx)

func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, linear <= 0.005)
	AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.005, 1.0)))

func play(id: String, volume_offset := 0.0, pitch := 1.0) -> void:
	if muted or _headless or not _streams.has(id):
		return
	var def: Array = SFX[id]
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(id, -10.0)) < float(def[3]):
		return
	_last[id] = now
	var slot := -1
	for i in POOL_SIZE:
		var k := (_next + i) % POOL_SIZE
		if not _players[k].playing:
			slot = k
			break
	if slot < 0:
		# Hepsi dolu: en eski sesi çal.
		var oldest := 1e12
		for i in POOL_SIZE:
			if _started[i] < oldest:
				oldest = _started[i]
				slot = i
	_next = (slot + 1) % POOL_SIZE
	var player := _players[slot]
	var spread: float = float(def[2])
	player.stream = _streams[id]
	player.bus = str(def[4])
	player.volume_db = float(def[1]) + volume_offset
	player.pitch_scale = maxf(0.05, pitch * (1.0 + randf_range(-spread, spread)))
	player.play()
	_started[slot] = now

func ui(id: String) -> void:
	play(id)

func music(id: String, fade := 0.9) -> void:
	## Müziği çapraz geçişle değiştirir; aynı parça zaten çalıyorsa dokunmaz.
	if _headless or id == _music_id:
		return
	_music_id = id
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	var old := _music_a
	_music_a = _music_b
	_music_b = old
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(old, "volume_db", -60.0, fade)
	_music_tween.chain().tween_callback(old.stop)
	if _music_streams.has(id):
		_music_a.stream = _music_streams[id]
		_music_a.volume_db = -40.0
		_music_a.play()
		_music_tween.tween_property(_music_a, "volume_db", float(MUSIC[id][1]), fade).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func start_music() -> void:
	if _music_id == "":
		music("menu")

func set_muffled(on: bool, time := 0.35) -> void:
	## Duraklatma / ölüm anında müziği boğuklaştırır.
	if _filter == null or _headless:
		return
	if _filter_tween != null and _filter_tween.is_valid():
		_filter_tween.kill()
	_filter_tween = create_tween()
	_filter_tween.tween_property(_filter, "cutoff_hz", 700.0 if on else 20000.0, time).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT if on else Tween.EASE_IN)

func toggle_mute() -> bool:
	muted = not muted
	apply_volumes()
	return muted

func _shutdown() -> void:
	# Çıkışta çalan sesleri durdur: aksi hâlde AudioStreamPlayback sızıntı olarak görünür.
	for player in [_music_a, _music_b]:
		if player != null:
			player.stop()
			player.stream = null
	for player in _players:
		if player != null:
			player.stop()
			player.stream = null

func _exit_tree() -> void:
	_shutdown()

func ids() -> Array:
	return SFX.keys()
