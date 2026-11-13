extends SceneTree

## Tutundurma probu (headless): iki seviyeyi GERÇEK oyun sahnesinde çözücü yoluyla oynar,
## game.gd kancalarının olay akıttığını; görev ilerlemesini, kilometre taşı alımını, haftalık
## ilerlemeyi ve enjekte edilen tarihlerle gün/hafta devrini doğrular.
##   godot --headless --path . -s res://tools/retention_probe.gd      çıkış 0 = geçti
## Oyuncunun gerçek kaydı ASLA yazılmaz (persist=false).

const START_LEVEL: int = 12
const MONDAY: String = "2026-11-09"
const NEXT_MONDAY: String = "2026-11-16"
const FRAMES_PER_TAP: int = 4
const MAX_DRAIN_FRAMES: int = 2000000
const SEEDED_MISSIONS: Array[Dictionary] = [
	{"id": "levels", "target": 1, "progress": 0, "claimed": false, "reward": {"coins": 20}},
	{"id": "baskets", "target": 3, "progress": 0, "claimed": false, "reward": {"coins": 20}},
	{"id": "stars3", "target": 1, "progress": 0, "claimed": false, "reward": {"coins": 30}},
]

var _game: Node = null
var _progress: Node = null
var _path: Array[int] = []
var _wait: int = 0
var _phase: String = "start"
var _played: int = 0
var _drain: int = 0
var _failed: bool = false
var _baskets_seen: int = 0
var _levels_won_seen: int = 0


func _initialize() -> void:
	_progress = root.get_node("Progress")
	_progress.set("persist", false)


func _process(_delta: float) -> bool:
	if _wait > 0:
		_wait -= 1
		return false
	match _phase:
		"start":
			_prepare()
			_phase = "load"
		"load":
			_load_level(START_LEVEL + _played)
			_path = LevelSolver.solve(_game.get("_level") as Dictionary, 200000)
			if _path.is_empty():
				_fail("çözüm yok")
			_phase = "play"
			_wait = 2
		"play":
			if _path.is_empty():
				_phase = "drain"
				return false
			_game.call("_tap", _path.pop_front())
			_wait = FRAMES_PER_TAP
		"drain":
			_drain += 1
			if _drain < MAX_DRAIN_FRAMES and (bool(_game.get("_playing")) or _game.get("_overlay") == null):
				return false
			_drain = 0
			_played += 1
			print("PROBE retention seviye_bitti %d" % _played)
			if _played < 2:
				_phase = "load"
				return false
			_verify()
			_phase = "done"
		"done":
			print("PROBE SONUC: %s" % ("kaldi" if _failed else "gecti"))
			quit(1 if _failed else 0)
			return true
	return false


func _prepare() -> void:
	_progress.call("reset_state")
	_progress.data.level = START_LEVEL
	RetentionStore.today_override = MONDAY
	AnalyticsLog.echo = false
	AnalyticsLog.clear()
	# Bu seviyede tutorial kartı ya da yenilenen güçlendirici çıkmasın.
	RetentionStore.put(RetentionFlow.KEY_MISSIONS, {"day": MONDAY, "items": SEEDED_MISSIONS, "chest": false})
	var week: Dictionary = WeeklyEvent.new_state(MONDAY, RetentionData.weekly())
	week["theme"] = "baskets"
	RetentionStore.put(RetentionFlow.KEY_WEEKLY, week)
	RetentionEvents.add_listener(_on_event)


func _on_event(event_id: String, amount: int, _data: Dictionary) -> void:
	if event_id == RetentionEvents.BASKET_COMPLETED:
		_baskets_seen += amount
	elif event_id == RetentionEvents.LEVEL_WON:
		_levels_won_seen += amount


func _load_level(level: int) -> void:
	if _game != null:
		_game.queue_free()
	var packed: PackedScene = load("res://scenes/Game.tscn") as PackedScene
	_game = packed.instantiate()
	root.add_child(_game)
	current_scene = _game
	_game.set("_persist", false)
	_game.set("_level_number", level)
	_game.call("_start_level")


func _verify() -> void:
	var coins_before: int = int(_progress.call("coins"))
	print("PROBE retention baskets=%d levels_won=%d seviye=%d" % [_baskets_seen, _levels_won_seen, int(_progress.call("level"))])
	_expect(_levels_won_seen == 2, "level_won olayı iki kez gelmeli")
	_expect(_baskets_seen >= 6, "basket_completed olayları gelmeli")
	# --- Görevler ---
	var state: Dictionary = RetentionFlow.sync_missions(MONDAY)
	var items: Array[Dictionary] = Missions.items(state)
	_expect(int(items[0]["progress"]) == 1 and Missions.is_done(items[0]), "'seviye bitir' görevi tamam olmalı")
	_expect(int(items[1]["progress"]) == 3, "'sepet doldur' görevi hedefte durmalı")
	var reward: Dictionary = RetentionFlow.claim_mission(0, MONDAY)
	_expect(int(reward.get("coins", 0)) == 20, "görev ödülü 20 jeton")
	_expect(RetentionFlow.claim_mission(0, MONDAY).is_empty(), "çift alma reddedilmeli")
	# --- Kilometre taşı ---
	var level_now: int = int(_progress.call("level"))
	var ready: Array[int] = Milestones.claimable(RetentionFlow.milestone_state(), level_now, RetentionData.milestones())
	_expect(ready.has(5) and ready.has(10), "5 ve 10. kilometre taşı alınabilir olmalı (seviye %d)" % level_now)
	var milestone: Dictionary = RetentionFlow.claim_milestone(5)
	_expect(int(milestone.get("coins", 0)) == 30, "5. kilometre taşı 30 jeton")
	_expect(RetentionFlow.claim_milestone(5).is_empty(), "kilometre taşı bir kez")
	# --- Haftalık ---
	var week: Dictionary = RetentionFlow.sync_weekly(MONDAY)
	_expect(WeeklyEvent.progress(week) == _baskets_seen, "haftalık ilerleme sepet sayısına eşit (%d != %d)" % [WeeklyEvent.progress(week), _baskets_seen])
	var weekly_cfg: Dictionary = RetentionData.weekly()
	var theme: Dictionary = WeeklyEvent.theme_by_id(weekly_cfg, "baskets")
	var reached: int = WeeklyEvent.reached_count(week, theme)
	_expect(reached >= 1, "en az bir haftalık kademe ulaşılmış olmalı")
	var coins_mid: int = int(_progress.call("coins"))
	# --- Hafta devri: alınmamış kademeler otomatik verilir ---
	RetentionStore.today_override = NEXT_MONDAY
	var next_week: Dictionary = RetentionFlow.sync_weekly(NEXT_MONDAY)
	_expect(String(next_week["week"]) == NEXT_MONDAY and WeeklyEvent.progress(next_week) == 0, "yeni hafta sıfırlanmalı")
	var expected_auto: int = 0
	for tier: int in range(reached):
		expected_auto += int(WeeklyEvent.tier_reward(weekly_cfg, tier).get("coins", 0))
	_expect(int(_progress.call("coins")) >= coins_mid + expected_auto, "alınmamış haftalık ödüller otomatik verilmeli")
	# --- Gün devri: yeni görevler ---
	var rolled: Dictionary = RetentionFlow.sync_missions(NEXT_MONDAY)
	_expect(String(rolled["day"]) == NEXT_MONDAY and int(Missions.done_count(rolled)) == 0, "yeni gün yeni görevler")
	# --- Geri dönüş ---
	RetentionStore.today_override = DailyDate.add_days(NEXT_MONDAY, 5)
	RetentionFlow.touch_session(RetentionStore.today_override)
	_expect(Comeback.has_pending(RetentionFlow.comeback_state()), "5 gün sonra geri dönüş hediyesi bekler")
	_expect(AnalyticsLog.count("ret_mission_claim") == 1 and AnalyticsLog.count("ret_milestone_claim") == 1, "analitik olayları yazılmalı")
	print("PROBE retention jeton %d -> %d" % [coins_before, int(_progress.call("coins"))])


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failed = true
	printerr("PROBE HATA: %s" % message)
