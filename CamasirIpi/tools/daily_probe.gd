extends SceneTree

## Günlük bulmaca probu (headless): bugünün bulmacasını GERÇEK oyun sahnesinde çözücünün
## yoluyla oynar ve doğrular: ödül tek sefer, normal seviye/seri değişmez, tekrar ödül vermez,
## ertesi gün seri artar, kaçırılan gün seriyi sıfırlar, devir oyundan sonra temizlenir.
##   godot --headless --path . -s res://tools/daily_probe.gd      çıkış 0 = geçti
##
## NOT: autoload kimlikleri `-s` kipinde derleme anında yoktur; hepsine `root.get_node` / `call` ile erişilir.

const PLAYER_LEVEL: int = 12
const START_COINS: int = 40
const FRAMES_PER_TAP: int = 4
const SETTLE_FRAMES: int = 2
const MAX_DRAIN_FRAMES: int = 2000000
const SOLVE_BUDGET: int = 200000
const SECTION: String = "daily"

var _progress: Node = null
var _store: GDScript = null
var _game: Node = null
var _path: Array[int] = []
var _wait: int = 0
var _phase: String = "start"
var _failed: bool = false
var _drain_frames: int = 0
var _today: String = ""
var _coins_before: int = 0
var _round: int = 0


func _initialize() -> void:
	# Prob oyuncunun gerçek kaydını ASLA ezmemeli.
	_progress = root.get_node("Progress")
	_progress.set("persist", false)
	_store = load("res://scripts/daily/daily_store.gd") as GDScript
	_today = (load("res://scripts/daily/daily_date.gd") as GDScript).call("today_key") as String


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	match _phase:
		"start":
			# Autoload'un kendi _ready'si (diskten yükleme) _initialize'dan SONRA koşar; durum burada kurulur.
			_progress.call("reset_state")
			_progress.data.level = PLAYER_LEVEL
			_progress.data.coins = START_COINS
			_check(bool(_store.call("puzzle_available", _today)), "bugün oynanabilir olmalı")
			_check(bool(_store.call("calendar_available", _today)), "takvim alınabilir olmalı")
			_coins_before = int(_progress.call("coins"))
			_launch(_store.call("todays_level", _today) as Dictionary)
			_phase = "play"
			_wait = 2
		"play":
			if _path.is_empty():
				_phase = "check"
				_wait = SETTLE_FRAMES
				return false
			_game.call("_tap", _path.pop_front())
			_wait = FRAMES_PER_TAP
		"check":
			_drain_frames += 1
			if _drain_frames < MAX_DRAIN_FRAMES and (bool(_game.get("_playing")) or _game.get("_overlay") == null):
				return false
			_drain_frames = 0
			_after_play()
		"done":
			print("PROBE SONUC: %s" % ("kaldi" if _failed else "gecti"))
			quit(1 if _failed else 0)
			return true
	return false


## Günlük seviyeyi `pending_level` ile devredip gerçek oyun sahnesini açar.
func _launch(level: Dictionary) -> void:
	if _game != null:
		_game.queue_free()
	(load("res://scripts/daily/daily_puzzle.gd") as GDScript).set("pending_level", level)
	_game = (load("res://scenes/Game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game
	_game.set("_persist", false)
	_path = LevelSolver.solve(_game.get("_level") as Dictionary, SOLVE_BUDGET)
	_check(not _path.is_empty(), "günlük seviye çözülebilir olmalı")
	_check(bool((_game.get("_level") as Dictionary).get("daily", false)), "oyun günlük seviyeyi kullanmalı")


func _after_play() -> void:
	var board: LaundryBoard = _game.get("_board") as LaundryBoard
	_check(board.is_won(), "günlük bulmaca kazanılmalı")
	_check(_game.get("_overlay") != null and _game.get("_overlay").get_script() == load("res://scripts/daily/daily_flow.gd"),
		"günlük sonuç sayfası açılmalı")
	if _round == 0:
		var reward: Dictionary = (load("res://scripts/daily/daily_puzzle.gd") as GDScript).call(
			"reward_for", 1, PLAYER_LEVEL) as Dictionary
		_check(int(_progress.call("coins")) == _coins_before + int(reward["coins"]),
			"ödül tam bir kez verilmeli")
		_check(int(_progress.call("level")) == PLAYER_LEVEL, "normal seviye değişmemeli")
		_check(int(_progress.call("streak")) == 0, "normal galibiyet serisi değişmemeli")
		_check(String(_progress.call("module_value", SECTION, "last_won", "")) == _today, "kazanım tarihi yazılmalı")
		_check(int(_progress.call("module_value", SECTION, "streak", 0)) == 1, "günlük seri 1 olmalı")
		_check(int(_game.get("_level_number")) == PLAYER_LEVEL, "oyun seviye numarası ilerlememeli")
		print("PROBE günlük_kazanım jeton=%d seri=1" % int(_progress.call("coins")))
		# Tekrar: aynı gün yeniden kazanmak ödül/seri vermez.
		var coins_after: int = int(_progress.call("coins"))
		var replay: Dictionary = _store.call("record_win", _today) as Dictionary
		_check(not bool(replay["first"]), "tekrar kazanım 'ilk' sayılmamalı")
		_check(int(_progress.call("coins")) == coins_after, "tekrar ödül vermemeli")
		_check(int(_progress.call("module_value", SECTION, "streak", 0)) == 1, "tekrar seriyi artırmamalı")
		# Devir temizlendi mi: normal bir oyun sahnesi günlük seviyeyi AÇMAMALI.
		_check((load("res://scripts/daily/daily_puzzle.gd") as GDScript).get("pending_level").is_empty(),
			"devir oyun açılınca temizlenmeli")
		_check(bool(_store.call("puzzle_available", _today)) == false, "kazanılınca bugün için rozet kalkmalı")
		# Aynı bulmacayı sahnede bir daha oyna: sonuç sayfası ödülsüz.
		_round = 1
		_launch((_game.get("_level") as Dictionary).duplicate(true))
		_phase = "play"
		_wait = 2
		return
	_check(int(_progress.call("coins")) == _coins_before + int((load("res://scripts/daily/daily_puzzle.gd") as GDScript).call(
		"reward_for", 1, PLAYER_LEVEL)["coins"]), "sahnede tekrar oynamak ödül vermemeli")
	_check(int(_progress.call("level")) == PLAYER_LEVEL, "tekrarda da seviye değişmemeli")
	# Ertesi gün: seri 2; bir gün kaçarsa 1.
	var date_script: GDScript = load("res://scripts/daily/daily_date.gd") as GDScript
	var tomorrow: String = date_script.call("add_days", _today, 1) as String
	var next: Dictionary = _store.call("record_win", tomorrow) as Dictionary
	_check(bool(next["first"]) and int(next["streak"]) == 2, "ertesi gün seri 2 olmalı")
	var skipped: Dictionary = _store.call("record_win", date_script.call("add_days", _today, 4)) as Dictionary
	_check(int(skipped["streak"]) == 1, "kaçırılan gün seriyi 1'e döndürmeli")
	_check(int(_progress.call("module_value", SECTION, "best", 0)) == 2, "en iyi seri korunmalı")
	# Takvim: bir kez alınır, ikinci kez reddedilir; jeton yalnız bir kez artar.
	var before_cal: int = int(_progress.call("coins"))
	var first: Dictionary = _store.call("claim_calendar", _today) as Dictionary
	var second: Dictionary = _store.call("claim_calendar", _today) as Dictionary
	_check(bool(first["ok"]) and not bool(second["ok"]), "takvim günde bir kez alınmalı")
	_check(int(_progress.call("coins")) == before_cal + int((first["reward"] as Dictionary)["coins"]),
		"takvim ödülü tek sefer")
	print("PROBE günlük_akış tamam")
	_phase = "done"


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		printerr("PROBE HATA: %s" % message)
