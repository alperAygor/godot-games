extends Node
## Kalıcı ayarlar + istatistikler. Dokunmatik/masaüstü ayrımı da burada yapılır.

signal changed(key: String)

const PATH := "user://neon_arena_3d.cfg"
const QUALITY_NAMES := ["DÜŞÜK", "ORTA", "YÜKSEK"]

var touch := false
var persist := true
var language := "tr"
var music := 0.7
var sfx := 0.9
var vibration := true
var auto_fire := true
var quality := 2
var shake := true
var show_fps := false

var best := 0
var best_wave := 0
var total_kills := 0
var runs := 0
var tutorial_done := false
var meta: MetaProgress
var _welcome := 0

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	# Demo / test koşuları oyuncunun kayıtlarını kirletmesin.
	persist = not ("--demo" in args or "--no-save" in args)
	touch = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or "--touch" in args
	if "--no-touch" in args:
		touch = false
	auto_fire = touch
	quality = 1 if OS.has_feature("mobile") else 2
	language = "tr" if OS.get_locale_language() == "tr" else "en"
	meta = MetaProgress.new(GameData.upgrades, GameData.ships)
	_load()
	for arg in args:
		if arg.begins_with("--lang="):
			language = arg.get_slice("=", 1)
		if arg.begins_with("--quality="):
			quality = clampi(int(arg.get_slice("=", 1)), 0, 2)
	if touch and not OS.has_feature("mobile"):
		# Masaüstünde --touch ile deneme: fare dokunuş gibi davransın.
		Input.emulate_touch_from_mouse = true

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	language = str(cfg.get_value("game", "language", language))
	music = float(cfg.get_value("audio", "music", music))
	sfx = float(cfg.get_value("audio", "sfx", sfx))
	vibration = bool(cfg.get_value("game", "vibration", vibration))
	auto_fire = bool(cfg.get_value("game", "auto_fire_touch" if touch else "auto_fire", auto_fire))
	shake = bool(cfg.get_value("game", "shake", shake))
	show_fps = bool(cfg.get_value("video", "show_fps", show_fps))
	quality = clampi(int(cfg.get_value("video", "quality", quality)), 0, 2)
	best = int(cfg.get_value("score", "best", 0))
	best_wave = int(cfg.get_value("score", "best_wave", 0))
	total_kills = int(cfg.get_value("score", "kills", 0))
	runs = int(cfg.get_value("score", "runs", 0))
	tutorial_done = bool(cfg.get_value("game", "tutorial_done", false))
	if cfg.has_section("meta"):
		meta.from_dict(cfg.get_value("meta", "state", {}))
	elif runs > 0 or best > 0:
		# Kalıcı ilerleme gelmeden önce oynamış oyuncuya bir kerelik başlangıç çekirdeği.
		_welcome = 150 + total_kills / 4
		meta.earn(_welcome)

func save() -> void:
	if DisplayServer.get_name() == "headless" or not persist:
		return
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("game", "language", language)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sfx", sfx)
	cfg.set_value("game", "vibration", vibration)
	cfg.set_value("game", "auto_fire_touch" if touch else "auto_fire", auto_fire)
	cfg.set_value("game", "shake", shake)
	cfg.set_value("game", "tutorial_done", tutorial_done)
	cfg.set_value("video", "show_fps", show_fps)
	cfg.set_value("video", "quality", quality)
	cfg.set_value("score", "best", best)
	cfg.set_value("score", "best_wave", best_wave)
	cfg.set_value("score", "kills", total_kills)
	cfg.set_value("score", "runs", runs)
	cfg.set_value("meta", "state", meta.to_dict())
	cfg.save(PATH)

func set_value(key: String, value: Variant) -> void:
	set(key, value)
	save()
	changed.emit(key)

func record_run(score: int, wave: int, kills: int, cores_earned := 0) -> bool:
	## Koşu sonucunu işler; yeni rekor ise true döner.
	var is_record := score > best and score > 0
	best = maxi(best, score)
	best_wave = maxi(best_wave, wave)
	total_kills += kills
	runs += 1
	meta.earn(cores_earned)
	save()
	return is_record

func take_welcome() -> int:
	## Hoş geldin bonusu verildiyse miktarını bir kez döndürür (menüde duyurmak için).
	var out := _welcome
	_welcome = 0
	if out > 0:
		save()
	return out

func ui_scale() -> float:
	return 1.3 if touch else 1.0
