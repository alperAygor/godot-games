extends SceneTree

## Harita / zen / çevrimiçi kapı probu (headless): GERÇEK oyun sahnesinde
##  (a) bitmiş bir seviyeyi tekrar oynar: yıldız yalnız FARK kadar artar, seviye ve seri değişmez;
##      tekrarda kayıp seriyi bozmaz;
##  (b) iki zen tahtası oynar, ikincisinde zorlanmış "kaybedecekti" durumu yaratır: kayıp sayfası YOK,
##      jeton/yıldız/seviye/seri değişmez, sayaç artar, kurtarma sonrası tahta kayıp değildir;
##  (c) sahte çevrimdışı aktarımla seviye başlamasının ENGELLENDİĞİNİ, sahte çevrimiçi ile geçtiğini doğrular.
##   godot --headless --path . -s res://tools/map_probe.gd      çıkış 0 = geçti
##
## NOT: autoload kimlikleri `-s` kipinde derleme anında yoktur; onlara değen sınıflara `load` + `call/get` ile erişilir.

const PLAYER_LEVEL: int = 12
const REPLAY_LEVEL: int = 5
const START_COINS: int = 40
const START_STREAK: int = 2
const START_STARS: int = 7
const PRESET_BEST: int = 1
const FRAMES_PER_TAP: int = 4
const SETTLE_FRAMES: int = 2
const MAX_WAIT_FRAMES: int = 6000
const SOLVE_BUDGET: int = 200000
const ZEN_SEED: int = 4242
const LOSS_SEARCH_TRIES: int = 600
const GAME_SCENE: String = "res://scenes/Game.tscn"


## Sahte aktarım: `online` bayrağı çalışma anında çevrilebilir (bağlantı gitti/geldi).
class FakeTransport extends OnlineTransport:
	var online: bool = false
	var calls: int = 0

	func probe(_url: String, _status: int, _timeout: float) -> bool:
		calls += 1
		return online


var _progress: Node = null
var _game: Node = null
var _path: Array[int] = []
var _wait: int = 0
var _phase: String = "start"
var _failed: bool = false
var _waited: int = 0
var _before: Dictionary = {}
var _zen_script: GDScript = null
var _gate_script: GDScript = null
var _flow_script: GDScript = null
var _fake: FakeTransport = null


func _initialize() -> void:
	# Prob oyuncunun gerçek kaydını ASLA ezmemeli.
	_progress = root.get_node("Progress")
	_progress.set("persist", false)
	_zen_script = load("res://scripts/zen/zen_mode.gd") as GDScript
	_gate_script = load("res://scripts/net/online_gate.gd") as GDScript
	_flow_script = load("res://scripts/map/map_flow.gd") as GDScript
	AnalyticsLog.echo = false
	AnalyticsLog.clear()


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	match _phase:
		"start":
			_check(not bool(_gate_script.call("is_active")), "kapı headless'ta kendiliğinden kapalı olmalı")
			_reset_progress()
			_start_replay()
			_phase = "a_play"
			_wait = 2
		"a_play":
			if _path.is_empty():
				_phase = "a_check"
				_wait = SETTLE_FRAMES
				return false
			_game.call("_tap", _path.pop_front())
			_wait = FRAMES_PER_TAP
		"a_check":
			if not _wait_for(_game.get("_overlay") != null):
				return false
			_replay_checks()
			_phase = "a_lose"
		"a_lose":
			_replay_lose_check()
			_phase = "b_start"
		"b_start":
			_reset_progress()
			_start_zen()
			_phase = "b_play"
			_wait = 2
		"b_play":
			if _path.is_empty():
				_phase = "b_wait_next"
				return false
			_game.call("_tap", _path.pop_front())
			_wait = FRAMES_PER_TAP
		"b_wait_next":
			var session: RefCounted = _game.get("_zen") as RefCounted
			if not _wait_for(int(session.get("step")) >= 2 and bool(_game.get("_playing")) == false):
				return false
			_zen_win_checks()
			_phase = "b_force_loss"
		"b_force_loss":
			if not _force_zen_loss():
				_phase = "c_start"
				return false
			_phase = "b_loss_play"
			_wait = 2
		"b_loss_play":
			if _path.is_empty():
				_phase = "b_loss_check"
				_waited = 0
				return false
			_game.call("_tap", _path.pop_front())
			_wait = FRAMES_PER_TAP
		"b_loss_check":
			var session: RefCounted = _game.get("_zen") as RefCounted
			if not _wait_for(int(session.get("rescues")) >= 1):
				return false
			_wait = 30
			_phase = "b_loss_verify"
		"b_loss_verify":
			_zen_loss_checks()
			_phase = "c_start"
		"c_start":
			_gate_checks()
			_phase = "done"
		"done":
			print("PROBE SONUC: %s" % ("kaldi" if _failed else "gecti"))
			quit(1 if _failed else 0)
			return true
	return false


func _reset_progress() -> void:
	_progress.call("reset_state")
	_progress.data.level = PLAYER_LEVEL
	_progress.data.coins = START_COINS
	_progress.data.streak = START_STREAK
	_progress.data.stars = START_STARS
	_progress.data.record_best_stars(REPLAY_LEVEL, PRESET_BEST)
	_progress.data.stars = START_STARS
	# Öğretici kartları görüldü sayılır: sonuç sayfasının önüne geçmesinler.
	var tutorials: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/tutorials.json"))
	for card: Variant in ((tutorials as Dictionary).get("cards", {}) as Dictionary).keys():
		_progress.call("mark_seen", "tut_card_%s" % String(card))
	_before = _snapshot()


func _snapshot() -> Dictionary:
	return {"level": int(_progress.call("level")), "coins": int(_progress.call("coins")),
		"stars": int(_progress.call("stars")), "streak": int(_progress.call("streak")),
		"best": int(_progress.call("best_stars", REPLAY_LEVEL))}


func _launch() -> void:
	if _game != null:
		_game.queue_free()
	_game = (load(GAME_SCENE) as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game
	_game.set("_persist", false)


func _solve_current() -> void:
	_path = LevelSolver.solve(_game.get("_level") as Dictionary, SOLVE_BUDGET)
	_check(not _path.is_empty(), "seviye çözülebilir olmalı")


# --- (a) Tekrar oynama ---------------------------------------------------------------------------

func _start_replay() -> void:
	_flow_script.set("pending_replay", REPLAY_LEVEL)
	_launch()
	_check(int(_game.get("_replay_level")) == REPLAY_LEVEL, "oyun tekrar seviyesini almalı")
	_check(int(_game.get("_level_number")) == REPLAY_LEVEL, "tekrar seviye numarası")
	_check(int(_flow_script.get("pending_replay")) == 0, "devir oyun açılınca temizlenmeli")
	_solve_current()


func _replay_checks() -> void:
	var after: Dictionary = _snapshot()
	var gained: int = int(after["best"]) - int(_before["best"])
	_check(int(after["best"]) >= int(_before["best"]), "en iyi yıldız asla düşmemeli")
	_check(gained >= 1, "çözücü yoluyla tekrar yıldızı artırmalı (en iyi %d -> %d)" % [_before["best"], after["best"]])
	_check(int(after["stars"]) == int(_before["stars"]) + gained, "yıldız toplamı yalnız FARK kadar artmalı")
	_check(int(after["level"]) == PLAYER_LEVEL, "Progress.level() değişmemeli")
	_check(int(after["streak"]) == START_STREAK, "seri değişmemeli")
	_check(int(_game.get("_level_number")) == REPLAY_LEVEL, "oyun seviye numarası ilerlememeli")
	var sheet: Object = _game.get("_overlay") as Object
	_check(sheet != null and sheet.get_script().resource_path.ends_with("result_sheet.gd"), "kazanma sayfası açılmalı")
	_check(sheet.get_signal_connection_list("continue_pressed").size() >= 1, "Devam haritaya dönmeli")
	# Taban ödül verilmez: yalnız (varsa) kusursuz/zincir ek jetonu.
	var coin_gain: int = int(after["coins"]) - int(_before["coins"])
	var balance: Dictionary = _progress.call("balance_table") as Dictionary
	_check(coin_gain < int(balance.get("win_coins", 0)) + int(StarRating.perfect_bonus(3, balance)),
		"tekrar taban ödülü vermemeli (kazanç %d)" % coin_gain)
	_check(AnalyticsLog.count("replay_win") == 1, "replay_win analitiği")
	for entry: Dictionary in AnalyticsLog.events():
		if String(entry["name"]) == "replay_win":
			_check(int(entry["delta"]) == gained, "replay_win yıldız farkını taşımalı")
	print("PROBE tekrar yıldız %d->%d fark=%d jeton+%d seviye=%d seri=%d" % [_before["best"], after["best"],
		gained, coin_gain, after["level"], after["streak"]])
	# Aynı seviyeyi en iyi yıldızla tekrar kazanmak hiçbir şey vermemeli (jeton/yıldız çiftlenmez).
	var mid: Dictionary = _snapshot()
	_progress.data.record_best_stars(REPLAY_LEVEL, StarRating.MAX_STARS)
	_progress.data.stars = int(mid["stars"])
	var again: Dictionary = _flow_script.call("replay_win", REPLAY_LEVEL, _game.get("_board"), false,
		_game.get("_run_stats")) as Dictionary
	_check(int(again["stars"]) == 0, "en iyi yıldız zaten 3 iken fark 0 olmalı")
	_check(int(_progress.call("stars")) == int(mid["stars"]), "fark 0: yıldız değişmemeli")
	_check(int(_progress.call("coins")) == int(mid["coins"]), "fark 0: jeton değişmemeli")
	_check(int(_progress.call("level")) == PLAYER_LEVEL and int(_progress.call("streak")) == START_STREAK,
		"tekrar tekrarında da seviye/seri sabit")


func _replay_lose_check() -> void:
	var streak_before: int = int(_progress.call("streak"))
	_game.call("_show_lose", 3)
	_check(int(_progress.call("streak")) == streak_before, "tekrarda kayıp seriyi sıfırlamamalı")
	var sheet: Object = _game.get("_overlay") as Object
	_check(sheet != null and sheet.get_script().resource_path.ends_with("result_sheet.gd"), "kayıp sayfası (tekrar/devam)")
	_check(int(_progress.call("level")) == PLAYER_LEVEL, "kayıpta seviye değişmemeli")


# --- (b) Zen -------------------------------------------------------------------------------------

func _start_zen() -> void:
	_zen_script.set("pending", true)
	_zen_script.set("pending_seed", ZEN_SEED)
	_launch()
	var session: RefCounted = _game.get("_zen") as RefCounted
	_check(session != null, "zen oturumu açılmalı")
	_check(bool((_game.get("_level") as Dictionary).get("zen", false)), "zen tahtası kullanılmalı")
	_check(int(_game.get("_replay_level")) == 0, "zen tekrar değildir")
	_solve_current()


func _zen_win_checks() -> void:
	var session: RefCounted = _game.get("_zen") as RefCounted
	_check(int(session.get("cleared")) == 1, "ilk zen tahtası temizlenmiş sayılmalı")
	_check(_game.get("_overlay") == null, "zen'de sonuç sayfası olmamalı")
	_check(bool((_game.get("_level") as Dictionary).get("zen", false)), "ikinci tahta da zen")
	_check(int(_zen_script.call("total_cleared")) == 1, "kalıcı zen sayacı 1")
	var now: Dictionary = _snapshot()
	for key: String in ["level", "coins", "stars", "streak", "best"]:
		_check(int(now[key]) == int(_before[key]), "zen ilk tahta sonrası %s değişmemeli" % key)
	_check(AnalyticsLog.count("zen_level_clear") == 1, "zen_level_clear analitiği")
	print("PROBE zen tahta1 temiz; sıradaki tahta kuruldu")


## Zen tahtasını 1 askılı bir tahtayla değiştirir ve rastgele oynayarak KAYBEDECEK bir dokunuş dizisi bulur.
func _force_zen_loss() -> bool:
	var level: Dictionary = (_game.get("_level") as Dictionary).duplicate(true)
	level["rack_slots"] = 1
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = ZEN_SEED
	for _try: int in range(LOSS_SEARCH_TRIES):
		var clone: LaundryBoard = LaundryBoard.new(level)
		var taps: Array[int] = []
		while not clone.is_over():
			var open: Array[int] = []
			for id: int in clone.item_ids():
				if clone.is_on_line(id) and clone.blockers_of(id).is_empty():
					open.append(id)
			if open.is_empty():
				break
			var pick: int = open[rng.randi_range(0, open.size() - 1)]
			clone.tap(pick)
			taps.append(pick)
		if clone.is_lost():
			_game.set("_level", level)
			var board: LaundryBoard = LaundryBoard.new(level)
			board.enable_history()
			_game.set("_board", board)
			(_game.get("_zen") as RefCounted).get("taps").clear()
			_game.call("_rebuild_from_board")
			_path = taps
			_before = _snapshot()
			_check(true, "kayıp dizisi bulundu (%d dokunuş)" % taps.size())
			return true
	_check(false, "zorlanmış kayıp durumu bulunamadı")
	return false


func _zen_loss_checks() -> void:
	var board: LaundryBoard = _game.get("_board") as LaundryBoard
	var session: RefCounted = _game.get("_zen") as RefCounted
	_check(int(session.get("rescues")) >= 1, "kurtarma çalışmalı")
	_check(not board.is_lost(), "kurtarma sonrası tahta kayıp olmamalı")
	_check(_game.get("_overlay") == null, "zen'de kayıp sayfası olmamalı")
	for child: Node in (_game.get("_ui") as Node).get_children():
		var script: Script = child.get_script() as Script
		_check(script == null or not script.resource_path.ends_with("result_sheet.gd"), "ResultSheet bulunmamalı")
	var now: Dictionary = _snapshot()
	for key: String in ["level", "coins", "stars", "streak", "best"]:
		_check(int(now[key]) == int(_before[key]), "kurtarma sonrası %s değişmemeli" % key)
	_check(int(_progress.call("streak")) == START_STREAK, "kayıp zen'de seriyi sıfırlamamalı")
	print("PROBE zen kurtarma: geri-al/askı tamam rescues=%d slots=%d" % [session.get("rescues"), board.rack_slots()])


# --- (c) Çevrimiçi kapısı ------------------------------------------------------------------------

func _gate_checks() -> void:
	_reset_progress()
	if _game != null:
		_game.queue_free()
		_game = null
	_gate_script.call("reset")
	_gate_script.set("forced", true)
	_fake = FakeTransport.new()
	_fake.online = false
	_gate_script.call("set_transport", _fake)
	# (1) Oyun sahnesi çevrimdışıyken seviye BAŞLATMAMALI ve "Bağlantı gerekli" sayfasını açmalı.
	_game = (load(GAME_SCENE) as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game
	_game.set("_persist", false)
	_check(_game.get("_board") == null and _game.get("_world") == null, "çevrimdışı: seviye başlamamalı")
	_check(bool(_gate_script.call("sheet_open")), "çevrimdışı: bağlantı sayfası açılmalı")
	_check(AnalyticsLog.count("online_gate_shown") == 1, "online_gate_shown analitiği")
	# Bağlantı gelir: sayfanın yeniden denemesi seviyeyi başlatır.
	_fake.online = true
	(_gate_script.get("_sheet") as Object).call("_attempt", true)
	_check(_game.get("_board") != null, "çevrimiçi: seviye başlamalı")
	_check(not bool(_gate_script.call("sheet_open")) or _gate_script.get("_sheet") == null, "sayfa kapanmalı")
	_check(AnalyticsLog.count("online_gate_passed") == 1 and AnalyticsLog.count("online_gate_retry") >= 1,
		"passed/retry analitiği")
	# (2) Aynı oturumda ikinci başlangıç önbellekten geçer: ağa gidilmez.
	var calls: int = _fake.calls
	_game.call("_start_level")
	_check(_fake.calls == calls, "taze önbellek: ikinci başlangıçta ağ denetimi yok")
	# (3) Ana ekrandan "Oyna": çevrimdışıyken sahne DEĞİŞMEMELİ.
	_gate_script.call("reset")
	_gate_script.set("forced", true)
	_fake = FakeTransport.new()
	_gate_script.call("set_transport", _fake)
	var manager: Node = root.get_node("GameManager")
	var phase_before: int = int(manager.get("phase"))
	manager.call("start_game")
	_check(int(manager.get("phase")) == phase_before, "çevrimdışı: GameManager.start_game sahne/faz değiştirmemeli")
	_check(bool(_gate_script.call("sheet_open")), "çevrimdışı: başlangıçta sayfa açık")
	_gate_script.call("reset")
	print("PROBE çevrimiçi kapı: engelledi, geçirdi, önbellek tamam")


func _wait_for(condition: bool) -> bool:
	if condition:
		_waited = 0
		return true
	_waited += 1
	if _waited > MAX_WAIT_FRAMES:
		_check(false, "zaman aşımı (%s)" % _phase)
		_waited = 0
		_phase = "done"
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		printerr("PROBE HATA: %s" % message)
