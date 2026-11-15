extends TestCase
## `Ads` cephesi: yönetici yokken güvenli no-op; varken yönlendirme. Gerçek autoload'a dokunmaz (manager_override).

const ManagerScript = preload("res://scripts/autoload/AdManager.gd")

func _with_manager(provider: AdsProvider, env: AdEnvironment = null) -> Node:
	var m: Node = ManagerScript.new()
	m.call("setup", AdConfig.load_file(), env if env != null else AdEnvironment.new(), provider)
	Ads.manager_override = m
	return m

func _release(m: Node) -> void:
	Ads.manager_override = null
	m.call("set_provider", null)
	m.free()

func test_facade_without_manager_is_safe() -> void:
	Ads.suppress_manager = true
	var order: Array = []
	check(not Ads.available(), "yönetici yok")
	check(not Ads.can_show(AdPlacement.Id.REVIVE), "yönetici yok: gizli")
	check(not Ads.show_rewarded(AdPlacement.Id.REVIVE, func() -> void: order.append("ODUL"), func(r: String) -> void: order.append(r)), "no-op")
	eq(order, ["no_manager"], "ödül yok, neden iletildi")
	check(not Ads.maybe_interstitial({}, func() -> void: order.append("then")), "reklam yok")
	eq(order, ["no_manager", "then"], "then yine çağrılır")
	Ads.begin_run()
	check(not Ads.privacy_options_required(), "gizlilik yok")
	Ads.show_privacy_options(func() -> void: order.append("privacy"))
	eq(order, ["no_manager", "then", "privacy"], "geri çağrı yine gelir")
	Ads.suppress_manager = false

func test_facade_routes_to_manager() -> void:
	var mock := MockAdsProvider.new()
	mock.delay_seconds = 0.0
	var m := _with_manager(mock)
	check(Ads.available(), "yönetici var")
	check(Ads.can_show(AdPlacement.Id.REVIVE), "sunulabilir")
	var got: Array = []
	check(Ads.show_rewarded(AdPlacement.Id.REVIVE, func() -> void: got.append("revive")), "başladı")
	eq(got, ["revive"], "ödül yalnız onaydan sonra")
	check(not Ads.can_show(AdPlacement.Id.REVIVE), "koşu başına bir kez")
	Ads.begin_run()
	check(Ads.can_show(AdPlacement.Id.REVIVE), "begin_run sıfırlar")
	_release(m)

func test_facade_interstitial_and_daily() -> void:
	var env := AdEnvironment.new()
	env.runs_completed = 10
	var mock := MockAdsProvider.new()
	mock.delay_seconds = 0.0
	var m := _with_manager(mock, env)
	check(Ads.daily_bonus_available(), "günlük hazır")
	var then: Array = []
	check(not Ads.maybe_interstitial({}, func() -> void: then.append(1)), "1. ölüm: reklam yok")
	check(Ads.maybe_interstitial({}, func() -> void: then.append(2)), "2. ölüm: reklam")
	eq(then, [1, 2], "then iki kez (her çağrıda bir)")
	eq(mock.show_count, 1, "tek gösterim")
	_release(m)

func test_facade_privacy_passthrough() -> void:
	var mock := MockAdsProvider.new()
	var m := _with_manager(mock)
	check(not Ads.privacy_options_required(), "mock: gerekmez")
	mock.privacy_required = true
	check(Ads.privacy_options_required(), "iletildi")
	var done: Array = []
	Ads.show_privacy_options(func() -> void: done.append(1))
	eq(done, [1], "geri çağrı")
	_release(m)

func test_facade_respects_remove_ads() -> void:
	var env := AdEnvironment.new()
	env.runs_completed = 10
	env.ads_removed = true
	var mock := MockAdsProvider.new()
	mock.delay_seconds = 0.0
	var m := _with_manager(mock, env)
	for i in 4:
		Ads.maybe_interstitial({}, func() -> void: pass)
	eq(mock.show_count, 0, "reklamsız: geçiş yok")
	check(Ads.can_show(AdPlacement.Id.REROLL), "ödüllü açık")
	_release(m)
