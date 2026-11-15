extends TestCase
## MockAdsProvider: ayarlanabilir sonuçlar (başarı / erken kapatma / doluluk yok / zaman aşımı), belirleyici davranış.

func _run(outcome: MockAdsProvider.Outcome, placement: int) -> Array:
	var p := MockAdsProvider.new()
	p.delay_seconds = 0.0
	p.outcome = outcome
	var ev: Array = []
	p.shown.connect(func() -> void: ev.append("shown"))
	p.rewarded.connect(func() -> void: ev.append("rewarded"))
	p.dismissed.connect(func() -> void: ev.append("dismissed"))
	p.failed.connect(func(r: String) -> void: ev.append("failed:" + r))
	p.show(placement)
	return ev

func test_rewarded_outcomes() -> void:
	eq(_run(MockAdsProvider.Outcome.SUCCESS, AdPlacement.Id.REVIVE), ["shown", "rewarded"], "başarı")
	eq(_run(MockAdsProvider.Outcome.DISMISSED, AdPlacement.Id.REVIVE), ["shown", "failed:dismissed_early"], "erken kapatma: ödül yok")
	eq(_run(MockAdsProvider.Outcome.NO_FILL, AdPlacement.Id.REVIVE), ["failed:no_fill"], "doluluk yok")
	eq(_run(MockAdsProvider.Outcome.TIMEOUT, AdPlacement.Id.REVIVE), [], "zaman aşımı: sessiz")

func test_interstitial_outcomes() -> void:
	eq(_run(MockAdsProvider.Outcome.SUCCESS, AdPlacement.Id.INTERSTITIAL), ["shown", "dismissed"], "geçiş tamam")
	eq(_run(MockAdsProvider.Outcome.DISMISSED, AdPlacement.Id.INTERSTITIAL), ["shown", "dismissed"], "geçişte kapatma normal")
	eq(_run(MockAdsProvider.Outcome.NO_FILL, AdPlacement.Id.INTERSTITIAL), ["failed:no_fill"], "doluluk yok")

func test_deterministic_no_random_failure() -> void:
	for i in 50:
		eq(_run(MockAdsProvider.Outcome.SUCCESS, AdPlacement.Id.REROLL), ["shown", "rewarded"], "her seferinde aynı")

func test_consent_hold_and_resolve() -> void:
	var p := MockAdsProvider.new()
	p.consent_instant = false
	var got: Array = []
	p.request_consent(func(can: bool) -> void: got.append(can))
	eq(got, [], "bekliyor")
	p.resolve_consent(true)
	eq(got, [true], "çözüldü")
	p.resolve_consent(true)
	eq(got, [true], "ikinci kez çağrılmaz")

func test_optional_capabilities_default_off() -> void:
	var p := MockAdsProvider.new()
	check(not p.privacy_options_required(), "mock: gizlilik formu gerekmez")
	check(not NoAdsProvider.new().privacy_options_required(), "reklamsız: gerekmez")
	var no := NoAdsProvider.new()
	var ev: Array = []
	no.failed.connect(func(r: String) -> void: ev.append(r))
	check(not no.is_ready(AdPlacement.Id.REVIVE), "reklamsız hazır değil")
	no.show(AdPlacement.Id.REVIVE)
	eq(ev, ["ads_disabled"], "reklamsız asla ödül vermez")

func test_end_to_end_with_manager_and_mock() -> void:
	var env := AdEnvironment.new()
	var m: Node = (load("res://scripts/autoload/AdManager.gd") as GDScript).new()
	var p := MockAdsProvider.new()
	p.delay_seconds = 0.0
	m.call("setup", AdConfig.load_file(), env, p)
	check(p.initialized, "onay sonrası başlatıldı")
	var got: Array = []
	m.call("show_rewarded", AdPlacement.Id.REVIVE, func() -> void: got.append("revive"))
	eq(got, ["revive"], "mock başarı -> ödül")
	p.outcome = MockAdsProvider.Outcome.DISMISSED
	m.call("begin_run")
	m.call("show_rewarded", AdPlacement.Id.REVIVE, func() -> void: got.append("BAD"))
	eq(got, ["revive"], "erken kapatma -> ödül yok")
	m.call("set_provider", null)
	m.free()
