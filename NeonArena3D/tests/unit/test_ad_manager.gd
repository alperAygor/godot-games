extends TestCase
## AdManager: ödül yalnız `rewarded` ile, limitler, günlük bonus, onay kapısı, zaman aşımı akışı serbest bırakır,
## geçiş reklamı bağlamı (koşu/ölüm/süre/ödüllü/remove-ads). Sağlayıcı ve ortam sahtedir; gerçek kayda dokunulmaz.

const ManagerScript = preload("res://scripts/autoload/AdManager.gd")
const REVIVE := AdPlacement.Id.REVIVE
const DOUBLE := AdPlacement.Id.DOUBLE_CORES
const REROLL := AdPlacement.Id.REROLL
const DAILY := AdPlacement.Id.DAILY_BONUS
const INTER := AdPlacement.Id.INTERSTITIAL

var _log: Array = []

## Betikle yönlendirilen sağlayıcı: "silent" = hiçbir şey yayma.
class Scripted extends AdsProvider:
	var mode := "silent"
	var calls := 0
	var consent_held := false
	var init_calls := 0
	var ready := true
	var _held: Callable = Callable()
	func request_consent(on_done: Callable) -> void:
		if consent_held:
			_held = on_done
		else:
			on_done.call(true)
	func release(can_request := true) -> void:
		_held.call(can_request)
	func initialize() -> void:
		init_calls += 1
	func is_ready(_p: int) -> bool:
		return ready
	func show(p: int) -> void:
		calls += 1
		match mode:
			"reward":
				shown.emit()
				if p == INTERSTITIAL_PLACEMENT:
					dismissed.emit()
				else:
					rewarded.emit()
			"dismissed_early":
				shown.emit()
				failed.emit("dismissed_early")
			"fail":
				failed.emit("no_fill")
			"shown_only":
				shown.emit()
			_:
				pass

func _make(provider: AdsProvider = null, env: AdEnvironment = null) -> Node:
	var m: Node = ManagerScript.new()
	m.call("setup", AdConfig.load_file(), env if env != null else AdEnvironment.new(), provider if provider != null else Scripted.new())
	_log.clear()
	m.connect("rewarded_finished", func(p: int, ok: bool) -> void: _log.append("rew:%d:%s" % [p, ok]))
	m.connect("interstitial_finished", func(ok: bool) -> void: _log.append("inter:%s" % ok))
	return m

func _done(m: Node) -> void:
	m.call("set_provider", null)
	m.free()

func _scripted(mode: String) -> Scripted:
	var s := Scripted.new()
	s.mode = mode
	return s

func _ticket(m: Node) -> int:
	return int(m.get("_pending_ticket"))

# --- ödül yalnız rewarded ile --------------------------------------------------------------

func test_reward_only_on_provider_reward_callback() -> void:
	var s := _scripted("silent")
	var m := _make(s)
	var got: Array = []
	check(m.call("show_rewarded", REVIVE, func() -> void: got.append("reward")), "istek başladı")
	eq(got, [], "sağlayıcı sustu: ödül yok")
	s.rewarded.emit()
	eq(got, ["reward"], "rewarded gelince ödül")
	s.rewarded.emit()
	eq(got, ["reward"], "yinelenen sinyal ikinci ödül vermez")
	_done(m)

func test_shown_dismissed_or_fail_never_reward() -> void:
	for mode in ["dismissed_early", "fail", "shown_only"]:
		var s := _scripted(mode)
		var m := _make(s)
		var rewards: Array = []
		var fails: Array = []
		m.call("show_rewarded", REVIVE, func() -> void: rewards.append(1), func(r: String) -> void: fails.append(r))
		if mode == "shown_only":
			s.dismissed.emit()   # ödüllüde kapanış tek başına ödül değildir
		eq(rewards, [], "%s: ödül yok" % mode)
		_done(m)

func test_failure_calls_on_fail_and_emits() -> void:
	var s := _scripted("fail")
	var m := _make(s)
	var fails: Array = []
	m.call("show_rewarded", REROLL, func() -> void: _log.append("ODUL"), func(r: String) -> void: fails.append(r))
	eq(fails, ["no_fill"], "neden iletildi")
	eq(_log, ["rew:%d:false" % REROLL], "başarısızlık sinyali; ödül yok")
	check(m.call("can_show", REROLL), "başarısız istek hak tüketmez")
	_done(m)

func test_late_reward_after_timeout_is_ignored() -> void:
	var s := _scripted("silent")
	var m := _make(s)
	var rewards: Array = []
	m.call("show_rewarded", REVIVE, func() -> void: rewards.append(1))
	m.call("_on_show_timeout", _ticket(m))
	eq(_log, ["rew:%d:false" % REVIVE], "zaman aşımı akışı bırakır")
	s.rewarded.emit()
	eq(rewards, [], "geç gelen ödül verilmez")
	_done(m)

# --- zaman aşımı ---------------------------------------------------------------------------

func test_silent_rewarded_times_out_and_unblocks() -> void:
	var s := _scripted("silent")
	var m := _make(s)
	var fails: Array = []
	m.call("show_rewarded", REVIVE, func() -> void: pass, func(r: String) -> void: fails.append(r))
	check(not m.call("can_show", REVIVE), "bekleyen istek varken ikinci yok")
	m.call("_on_show_timeout", _ticket(m))
	eq(fails, ["timeout"], "zaman aşımı nedeni")
	check(m.call("can_show", REVIVE), "akış serbest: yeniden sunulabilir")
	_done(m)

func test_silent_interstitial_times_out_and_still_calls_then() -> void:
	var s := _scripted("silent")
	var m := _make(s)
	var then: Array = []
	m.call("maybe_interstitial", {"runs_completed": 9, "died": true}, func() -> void: then.append(1))
	# ilk ölüm: every_n_deaths=2 -> reklam yok, then hemen
	eq(then, [1], "ilk ölüm: reklamsız devam")
	check(m.call("maybe_interstitial", {"runs_completed": 9}, func() -> void: then.append(2)), "2. ölüm: reklam başladı")
	eq(then, [1], "reklam bekliyor")
	m.call("_on_show_timeout", _ticket(m))
	eq(then, [1, 2], "zaman aşımı then'i çağırır")
	eq(_log, ["inter:false"], "başarısız geçiş sinyali")
	_done(m)

func test_hard_timeout_releases_stuck_shown_ad() -> void:
	var s := _scripted("shown_only")
	var m := _make(s)
	var fails: Array = []
	m.call("show_rewarded", REVIVE, func() -> void: pass, func(r: String) -> void: fails.append(r))
	m.call("_on_show_timeout", _ticket(m))
	eq(fails, [], "ekrandaki reklam kısa zaman aşımıyla kesilmez")
	m.call("_on_hard_timeout", _ticket(m))
	eq(fails, ["timeout"], "ama takılırsa sert sınır serbest bırakır")
	_done(m)

func test_stale_timeout_ignored() -> void:
	var s := _scripted("reward")
	var m := _make(s)
	m.call("show_rewarded", REVIVE, func() -> void: pass)
	var old := _ticket(m)
	s.mode = "silent"
	m.call("show_rewarded", REROLL, func() -> void: pass)
	m.call("_on_show_timeout", old)
	m.call("_on_hard_timeout", old)
	eq(_log, ["rew:%d:true" % REVIVE], "eski ters sayım yeni isteği bozmaz")
	_done(m)

# --- limitler ------------------------------------------------------------------------------

func test_revive_once_per_run() -> void:
	var m := _make(_scripted("reward"))
	check(m.call("can_show", REVIVE), "ilk: var")
	m.call("show_rewarded", REVIVE, func() -> void: pass)
	check(not m.call("can_show", REVIVE), "aynı koşuda ikinci revive yok")
	var fails: Array = []
	check(not m.call("show_rewarded", REVIVE, func() -> void: _log.append("ODUL"), func(r: String) -> void: fails.append(r)), "reddedildi")
	eq(fails, ["not_available"], "neden")
	m.call("begin_run")
	check(m.call("can_show", REVIVE), "yeni koşuda yine var")
	_done(m)

func test_reroll_twice_per_run() -> void:
	var m := _make(_scripted("reward"))
	m.call("show_rewarded", REROLL, func() -> void: pass)
	check(m.call("can_show", REROLL), "1. sonrası 2. var")
	m.call("show_rewarded", REROLL, func() -> void: pass)
	check(not m.call("can_show", REROLL), "2. sonrası yok")
	eq(m.call("used_in_run", REROLL), 2, "sayaç")
	_done(m)

func test_limits_come_from_data() -> void:
	var m := _make(_scripted("reward"))
	var cfg: Dictionary = AdConfig.load_file()
	(cfg["placements"] as Dictionary)["REVIVE"] = {"per_run": 3, "per_session": 999}
	m.set("config", cfg)
	for i in 3:
		check(m.call("can_show", REVIVE), "veri 3 diyor: %d. var" % i)
		m.call("show_rewarded", REVIVE, func() -> void: pass)
	check(not m.call("can_show", REVIVE), "4. yok")
	_done(m)

func test_daily_bonus_once_per_today_key() -> void:
	var env := AdEnvironment.new()
	env.today = "2027-01-15"
	var m := _make(_scripted("reward"), env)
	check(m.call("can_show", DAILY), "bugün var")
	var got: Array = []
	m.call("show_rewarded", DAILY, func() -> void: got.append(1))
	eq(got, [1], "ödül")
	eq(env.daily_claimed_date, "2027-01-15", "tarih kaydedildi")
	check(not m.call("can_show", DAILY), "aynı gün ikinci yok")
	m.call("begin_run")
	check(not m.call("can_show", DAILY), "yeni koşu günlüğü sıfırlamaz")
	env.today = "2027-01-16"
	check(m.call("can_show", DAILY), "ertesi gün var")
	_done(m)

func test_daily_bonus_survives_new_manager_via_environment() -> void:
	var env := AdEnvironment.new()
	var m1 := _make(_scripted("reward"), env)
	m1.call("show_rewarded", DAILY, func() -> void: pass)
	_done(m1)
	var m2 := _make(_scripted("reward"), env)
	check(not m2.call("can_show", DAILY), "yeniden açılışta (kayıt) hâlâ alınmış")
	_done(m2)

func test_failed_daily_does_not_consume_the_day() -> void:
	var env := AdEnvironment.new()
	var m := _make(_scripted("fail"), env)
	m.call("show_rewarded", DAILY, func() -> void: pass)
	eq(env.daily_claimed_date, "", "başarısız: gün tüketilmedi")
	check(m.call("can_show", DAILY), "tekrar denenebilir")
	_done(m)

func test_interstitial_id_cannot_be_requested_as_rewarded() -> void:
	var m := _make(_scripted("reward"))
	var fails: Array = []
	check(not m.call("show_rewarded", INTER, func() -> void: _log.append("ODUL"), func(r: String) -> void: fails.append(r)), "reddedildi")
	eq(fails, ["not_rewarded"], "ödüllü değil")
	eq(_log, [], "ödül yok")
	_done(m)

# --- onay (consent) kapısı -----------------------------------------------------------------

func test_no_ads_and_no_init_before_consent_resolves() -> void:
	var s := _scripted("reward")
	s.consent_held = true
	var m := _make(s)
	check(not m.call("consent_resolved"), "çözülmedi")
	check(not m.call("can_show", REVIVE), "onaydan önce sunulamaz")
	eq(s.init_calls, 0, "onaydan önce SDK başlatılmaz")
	var fails: Array = []
	check(not m.call("show_rewarded", REVIVE, func() -> void: _log.append("ODUL"), func(r: String) -> void: fails.append(r)), "reddedildi")
	eq(s.calls, 0, "sağlayıcıya hiç istek gitmedi")
	var then: Array = []
	m.call("maybe_interstitial", {"runs_completed": 99, "died": true}, func() -> void: then.append(1))
	m.call("maybe_interstitial", {"runs_completed": 99, "died": true}, func() -> void: then.append(2))
	eq(s.calls, 0, "geçiş isteği de yok")
	eq(then, [1, 2], "ama akış devam eder")
	s.release(true)
	eq(s.init_calls, 1, "onaydan sonra başlatıldı")
	check(m.call("can_show", REVIVE), "artık sunulabilir")
	_done(m)

func test_consent_denied_means_no_ads_ever() -> void:
	var s := _scripted("reward")
	s.consent_held = true
	var m := _make(s)
	s.release(false)
	check(m.call("consent_resolved"), "çözüldü")
	eq(s.init_calls, 0, "izin yok: SDK hiç başlamaz")
	check(not m.call("can_show", REVIVE), "reklam yok")
	_done(m)

func test_stale_consent_callback_from_replaced_provider_ignored() -> void:
	var old := _scripted("reward")
	old.consent_held = true
	var m := _make(old)
	var fresh := _scripted("reward")
	m.call("set_provider", fresh)
	old.release(true)
	eq(old.init_calls, 0, "eski sağlayıcı başlatılmaz")
	eq(fresh.init_calls, 1, "yenisi başlatıldı")
	_done(m)

func test_no_provider_is_safe_noop() -> void:
	var m := _make()
	m.call("set_provider", null)
	check(not m.call("can_show", REVIVE), "sağlayıcı yok")
	var fails: Array = []
	check(not m.call("show_rewarded", REVIVE, func() -> void: _log.append("ODUL"), func(r: String) -> void: fails.append(r)), "no-op")
	eq(fails, ["not_available"], "neden")
	var then: Array = []
	m.call("maybe_interstitial", {"runs_completed": 99}, func() -> void: then.append(1))
	eq(then, [1], "geçişte then yine çağrılır")
	m.free()

func test_not_ready_provider_hides_button() -> void:
	var s := _scripted("reward")
	s.ready = false
	var m := _make(s)
	check(not m.call("can_show", REVIVE), "hazır değil -> gizli")
	check(not m.call("can_show", INTER), "geçiş de")
	_done(m)

func test_privacy_options_follow_provider() -> void:
	var mock := MockAdsProvider.new()
	var m := _make(mock)
	check(not m.call("privacy_options_required"), "mock: gerekmez")
	mock.privacy_required = true
	check(m.call("privacy_options_required"), "sağlayıcı gerektiriyorsa evet")
	var done: Array = []
	m.call("show_privacy_options", func() -> void: done.append(1))
	eq(done, [1], "form kapandı")
	eq(mock.privacy_shown_count, 1, "sağlayıcıya iletildi")
	mock.privacy_required = false
	m.call("show_privacy_options", func() -> void: done.append(2))
	eq(mock.privacy_shown_count, 1, "gerekmiyorsa form açılmaz")
	eq(done, [1, 2], "ama geri çağrı yine gelir")
	_done(m)

# --- geçiş reklamı bağlamı -----------------------------------------------------------------

func _setup_inter() -> Array:
	var env := AdEnvironment.new()
	env.runs_completed = 4
	var s := _scripted("reward")
	return [_make(s, env), env, s]

func test_interstitial_first_three_runs_never() -> void:
	var parts := _setup_inter()
	var m: Node = parts[0]
	var s: Scripted = parts[2]
	var then: Array = []
	for runs in [1, 2, 3]:
		(parts[1] as AdEnvironment).runs_completed = runs
		m.call("maybe_interstitial", {}, func() -> void: then.append(1))
		m.call("maybe_interstitial", {}, func() -> void: then.append(1))
	eq(s.calls, 0, "ilk 3 koşuda reklam yok")
	eq(then.size(), 6, "then hep çağrıldı")
	_done(m)

func test_interstitial_fourth_run_second_death_shows_and_records() -> void:
	var parts := _setup_inter()
	var m: Node = parts[0]
	var env: AdEnvironment = parts[1]
	var s: Scripted = parts[2]
	var then: Array = []
	m.call("maybe_interstitial", {}, func() -> void: then.append("a"))
	eq(s.calls, 0, "1. ölüm: yok")
	eq(m.get("last_pacing_reason"), AdPacing.REASON_DEATHS, "neden: ölüm aralığı")
	m.call("maybe_interstitial", {}, func() -> void: then.append("b"))
	eq(s.calls, 1, "2. ölüm: gösterildi")
	eq(then, ["a", "b"], "then sırası")
	eq(env.last_interstitial_unix, env.now_unix, "zaman kaydedildi (Settings.mark_transition karşılığı)")
	eq(_log, ["inter:true"], "tamamlandı")
	# hemen ardından iki ölüm daha: 180 sn dolmadı
	m.call("maybe_interstitial", {}, func() -> void: pass)
	m.call("maybe_interstitial", {}, func() -> void: pass)
	eq(s.calls, 1, "180 sn dolmadan yok")
	eq(m.get("last_pacing_reason"), AdPacing.REASON_TOO_SOON, "neden: erken")
	env.now_unix += 179
	m.call("maybe_interstitial", {}, func() -> void: pass)
	eq(s.calls, 1, "179 sn: yok")
	env.now_unix += 1
	m.call("maybe_interstitial", {}, func() -> void: pass)
	eq(s.calls, 2, "180 sn: var")
	_done(m)

func test_deaths_counter_resets_only_after_a_shown_interstitial() -> void:
	var parts := _setup_inter()
	var m: Node = parts[0]
	var s: Scripted = parts[2]
	m.call("maybe_interstitial", {}, func() -> void: pass)
	m.call("maybe_interstitial", {}, func() -> void: pass)
	eq(s.calls, 1, "2. ölümde gösterildi")
	m.call("maybe_interstitial", {}, func() -> void: pass)
	eq(s.calls, 1, "hemen sonraki ölüm: yok (sayaç sıfırlandı)")
	_done(m)

func test_rewarded_in_run_blocks_interstitial_until_next_run() -> void:
	var parts := _setup_inter()
	var m: Node = parts[0]
	var s: Scripted = parts[2]
	m.call("show_rewarded", REVIVE, func() -> void: pass)
	m.call("maybe_interstitial", {}, func() -> void: pass)
	m.call("maybe_interstitial", {}, func() -> void: pass)
	eq(s.calls, 1, "yalnız revive reklamı gitti; geçiş yok")
	eq(m.get("last_pacing_reason"), AdPacing.REASON_REWARDED, "neden: ödüllü izlendi")
	m.call("begin_run")
	m.call("maybe_interstitial", {}, func() -> void: pass)
	eq(s.calls, 2, "yeni koşuda yeniden uygun")
	_done(m)

func test_double_cores_ad_also_blocks_interstitial() -> void:
	var parts := _setup_inter()
	var m: Node = parts[0]
	var s: Scripted = parts[2]
	m.call("maybe_interstitial", {}, func() -> void: pass)   # 1. ölüm
	m.call("show_rewarded", DOUBLE, func() -> void: pass)
	m.call("maybe_interstitial", {}, func() -> void: pass)   # 2. ölüm ama çift çekirdek izlendi
	eq(s.calls, 1, "çift çekirdekten hemen sonra geçiş yok")
	_done(m)

func test_remove_ads_never_interstitial_but_rewarded_stays() -> void:
	var parts := _setup_inter()
	var m: Node = parts[0]
	var env: AdEnvironment = parts[1]
	var s: Scripted = parts[2]
	env.ads_removed = true
	for i in 6:
		m.call("maybe_interstitial", {}, func() -> void: pass)
	eq(s.calls, 0, "reklamsız: geçiş asla")
	eq(m.get("last_pacing_reason"), AdPacing.REASON_ADS_REMOVED, "neden")
	check(m.call("can_show", REVIVE), "ödüllü açık kalır")
	check(not m.call("can_show", INTER), "geçiş sunulamaz")
	_done(m)

func test_interstitial_clock_rollback_blocks() -> void:
	var parts := _setup_inter()
	var m: Node = parts[0]
	var env: AdEnvironment = parts[1]
	var s: Scripted = parts[2]
	env.last_interstitial_unix = env.now_unix + 5000
	m.call("maybe_interstitial", {}, func() -> void: pass)
	m.call("maybe_interstitial", {}, func() -> void: pass)
	eq(s.calls, 0, "saat geri alındı: yok")
	eq(m.get("last_pacing_reason"), AdPacing.REASON_CLOCK, "neden")
	_done(m)

func test_wrong_moment_blocks_interstitial() -> void:
	var parts := _setup_inter()
	var m: Node = parts[0]
	var s: Scripted = parts[2]
	for i in 3:
		m.call("maybe_interstitial", {"moment": "in_run"}, func() -> void: pass)
	eq(s.calls, 0, "oyun içi an: asla")
	_done(m)

func test_interstitial_failure_still_continues_and_does_not_reset_gap() -> void:
	var parts := _setup_inter()
	var m: Node = parts[0]
	var env: AdEnvironment = parts[1]
	var s: Scripted = parts[2]
	s.mode = "fail"
	var then: Array = []
	m.call("maybe_interstitial", {}, func() -> void: then.append(1))
	m.call("maybe_interstitial", {}, func() -> void: then.append(2))
	eq(then, [1, 2], "reklam gelmedi: akış sürdü")
	eq(env.last_interstitial_unix, 0, "gösterilmeyen reklam süre sayacını başlatmaz")
	s.mode = "reward"
	m.call("maybe_interstitial", {}, func() -> void: then.append(3))
	eq(s.calls, 2, "sonraki ölümde yeniden denenir (başarısız gösterim sayacı sıfırlamadı)")
	_done(m)

func test_then_called_exactly_once_even_with_duplicate_signals() -> void:
	var parts := _setup_inter()
	var m: Node = parts[0]
	var s: Scripted = parts[2]
	s.mode = "silent"
	var then: Array = []
	m.call("maybe_interstitial", {}, func() -> void: then.append(1))
	m.call("maybe_interstitial", {}, func() -> void: then.append(2))
	s.shown.emit()
	s.dismissed.emit()
	s.dismissed.emit()
	s.rewarded.emit()
	m.call("_on_hard_timeout", _ticket(m))
	eq(then, [1, 2], "ikinci then tam bir kez")
	_done(m)

func test_default_provider_selection_on_desktop_debug() -> void:
	var p: AdsProvider = ManagerScript.make_default_provider()
	if OS.is_debug_build():
		check(p is MockAdsProvider or p is NoAdsProvider, "masaüstü hata ayıklama: mock (ya da --ads=none)")
	else:
		check(p is NoAdsProvider, "yayın: reklamsız")
