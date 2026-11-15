extends TestCase
## AdmobAdsProvider durum makinesi (sahte köprüyle): onay -> başlatma -> önyükleme -> gösterim. Eklenti gerekmez.

class FakeBridge extends AdmobBridge:
	var present := true
	var load_rewarded_calls := 0
	var load_interstitial_calls := 0
	var rewarded_loaded: Callable = Callable()
	var rewarded_load_failed: Callable = Callable()
	var interstitial_loaded: Callable = Callable()
	var interstitial_load_failed: Callable = Callable()
	var rewarded_handlers: Array[Callable] = []
	var interstitial_handlers: Array[Callable] = []
	var consent_calls := 0
	var consent_cb: Callable = Callable()
	var consent_instant := true
	var init_calls := 0
	var privacy := false
	var privacy_calls := 0

	func is_present() -> bool:
		return present
	func request_consent(_config: Dictionary, on_done: Callable) -> void:
		consent_calls += 1
		if consent_instant:
			on_done.call(true)
		else:
			consent_cb = on_done
	func initialize(_config: Dictionary, on_done: Callable) -> void:
		init_calls += 1
		on_done.call()
	func privacy_options_required() -> bool:
		return privacy
	func show_privacy_options(on_done: Callable) -> void:
		privacy_calls += 1
		on_done.call()
	func load_rewarded(_unit_id: String, on_loaded: Callable, on_failed: Callable) -> void:
		load_rewarded_calls += 1
		rewarded_loaded = on_loaded
		rewarded_load_failed = on_failed
	func load_interstitial(_unit_id: String, on_loaded: Callable, on_failed: Callable) -> void:
		load_interstitial_calls += 1
		interstitial_loaded = on_loaded
		interstitial_load_failed = on_failed
	func show_rewarded(on_shown: Callable, on_earned: Callable, on_dismissed: Callable, on_failed: Callable) -> void:
		rewarded_handlers = [on_shown, on_earned, on_dismissed, on_failed]
	func show_interstitial(on_shown: Callable, on_dismissed: Callable, on_failed: Callable) -> void:
		interstitial_handlers = [on_shown, on_dismissed, on_failed]

var _events: Array = []

func _make(bridge: FakeBridge, config: Dictionary = {"request_consent": true}) -> AdmobAdsProvider:
	var p := AdmobAdsProvider.new(bridge, config, true)
	_events.clear()
	p.shown.connect(func() -> void: _events.append("shown"))
	p.rewarded.connect(func() -> void: _events.append("rewarded"))
	p.dismissed.connect(func() -> void: _events.append("dismissed"))
	p.failed.connect(func(reason: String) -> void: _events.append("failed:" + reason))
	return p

## Köprü <-> sağlayıcı geri çağrıları döngüdür; kırılmazsa çıkışta sızıntı uyarısı basılır.
func _drop(p: AdmobAdsProvider, b: FakeBridge) -> void:
	b.rewarded_loaded = Callable()
	b.rewarded_load_failed = Callable()
	b.interstitial_loaded = Callable()
	b.interstitial_load_failed = Callable()
	b.consent_cb = Callable()
	b.rewarded_handlers.clear()
	b.interstitial_handlers.clear()
	p.bridge = null

func _ready_provider(b: FakeBridge) -> AdmobAdsProvider:
	var p := _make(b)
	var granted: Array = []
	p.request_consent(func(can: bool) -> void: granted.append(can))
	p.initialize()
	b.rewarded_loaded.call()
	b.interstitial_loaded.call()
	return p

func test_nothing_happens_without_plugin() -> void:
	var b := FakeBridge.new()
	b.present = false
	var p := _make(b)
	var got: Array = []
	p.request_consent(func(can: bool) -> void: got.append(can))
	eq(got, [false], "eklenti yoksa reklam istenemez")
	p.initialize()
	eq(b.init_calls, 0, "SDK başlamaz")
	check(not p.is_ready(AdPlacement.Id.REVIVE), "hazır değil")
	_drop(p, b)

func test_consent_runs_before_sdk_and_no_load_before_it() -> void:
	var b := FakeBridge.new()
	b.consent_instant = false
	var p := _make(b)
	var got: Array = []
	p.request_consent(func(can: bool) -> void: got.append(can))
	eq(b.consent_calls, 1, "UMP istendi")
	eq(b.init_calls, 0, "onay çözülmeden SDK yok")
	eq(b.load_rewarded_calls + b.load_interstitial_calls, 0, "onay çözülmeden reklam isteği yok")
	check(not p.is_ready(AdPlacement.Id.REVIVE), "hazır değil")
	b.consent_cb.call(true)
	eq(got, [true], "onay çözüldü")
	eq(b.init_calls, 0, "SDK'yı yönetici başlatır (initialize), onay kendiliğinden başlatmaz")
	p.initialize()
	eq(b.init_calls, 1, "initialize sonrası")
	eq(b.load_rewarded_calls, 1, "ödüllü önyüklendi")
	eq(b.load_interstitial_calls, 1, "geçiş önyüklendi")
	_drop(p, b)

func test_consent_can_be_disabled() -> void:
	var b := FakeBridge.new()
	var p := _make(b, {"request_consent": false})
	var got: Array = []
	p.request_consent(func(can: bool) -> void: got.append(can))
	eq(b.consent_calls, 0, "form atlandı")
	eq(got, [true], "izin var")
	_drop(p, b)

func test_consent_denied_passes_through() -> void:
	var b := FakeBridge.new()
	b.consent_instant = false
	var p := _make(b)
	var got: Array = []
	p.request_consent(func(can: bool) -> void: got.append(can))
	b.consent_cb.call(false)
	eq(got, [false], "izin yok iletildi")
	_drop(p, b)

func test_stale_consent_callbacks_ignored() -> void:
	var b := FakeBridge.new()
	b.consent_instant = false
	var p := _make(b)
	var got: Array = []
	p.request_consent(func(can: bool) -> void: got.append(can))
	var first := b.consent_cb
	p.request_consent(func(can: bool) -> void: got.append(can))
	first.call(true)
	eq(got, [], "eski nesil yok sayılır")
	b.consent_cb.call(true)
	eq(got, [true], "güncel nesil çalışır")
	_drop(p, b)

func test_ready_only_after_loads() -> void:
	var b := FakeBridge.new()
	var p := _make(b)
	p.request_consent(func(_c: bool) -> void: pass)
	p.initialize()
	check(not p.is_ready(AdPlacement.Id.REVIVE), "yükleme bitmeden hazır değil")
	b.rewarded_loaded.call()
	b.interstitial_loaded.call()
	check(p.is_ready(AdPlacement.Id.REVIVE), "ödüllü hazır")
	check(p.is_ready(AdPlacement.Id.INTERSTITIAL), "geçiş hazır")
	_drop(p, b)

func test_rewarded_earned_then_dismissed_emits_rewarded_and_preloads_next() -> void:
	var b := FakeBridge.new()
	var p := _ready_provider(b)
	var loads := b.load_rewarded_calls
	p.show(AdPlacement.Id.REVIVE)
	check(not p.is_ready(AdPlacement.Id.REVIVE), "gösterim sırasında hazır değil")
	b.rewarded_handlers[0].call()
	b.rewarded_handlers[1].call()
	check(not _events.has("rewarded"), "ödül, reklam kapanınca verilir")
	b.rewarded_handlers[2].call()
	eq(_events, ["shown", "rewarded"], "olay sırası")
	eq(b.load_rewarded_calls, loads + 1, "sonraki reklam hemen yüklenir")
	_drop(p, b)

func test_rewarded_dismissed_early_fails_without_reward() -> void:
	var b := FakeBridge.new()
	var p := _ready_provider(b)
	p.show(AdPlacement.Id.DOUBLE_CORES)
	b.rewarded_handlers[2].call()
	eq(_events, ["failed:dismissed_early"], "ödül yok")
	_drop(p, b)

func test_interstitial_dismiss_completes() -> void:
	var b := FakeBridge.new()
	var p := _ready_provider(b)
	var loads := b.load_interstitial_calls
	p.show(AdPlacement.Id.INTERSTITIAL)
	b.interstitial_handlers[0].call()
	b.interstitial_handlers[1].call()
	eq(_events, ["shown", "dismissed"], "geçiş tamam")
	eq(b.load_interstitial_calls, loads + 1, "sonraki yüklenir")
	_drop(p, b)

func test_show_failure_reports_and_reloads() -> void:
	var b := FakeBridge.new()
	var p := _ready_provider(b)
	p.show(AdPlacement.Id.INTERSTITIAL)
	b.interstitial_handlers[2].call("boom")
	eq(_events, ["failed:boom"], "hata iletildi")
	check(b.load_interstitial_calls >= 2, "yeniden yüklendi")
	_drop(p, b)

func test_show_when_not_ready_fails_fast() -> void:
	var b := FakeBridge.new()
	var p := _make(b)
	p.request_consent(func(_c: bool) -> void: pass)
	p.initialize()
	p.show(AdPlacement.Id.REVIVE)
	eq(_events, ["failed:not_ready"], "yüklü değilse beklemeden başarısız")
	_drop(p, b)

func test_load_failure_keeps_not_ready() -> void:
	var b := FakeBridge.new()
	var p := _make(b)
	p.request_consent(func(_c: bool) -> void: pass)
	p.initialize()
	b.rewarded_load_failed.call("no_fill")
	check(not p.is_ready(AdPlacement.Id.REVIVE), "hazır değil")
	_drop(p, b)

func test_privacy_options_capability() -> void:
	var b := FakeBridge.new()
	var p := _make(b)
	check(not p.privacy_options_required(), "gerekmiyor")
	b.privacy = true
	check(p.privacy_options_required(), "köprü gerektiriyorsa evet")
	var done: Array = []
	p.show_privacy_options(func() -> void: done.append(1))
	eq(b.privacy_calls, 1, "forma iletildi")
	eq(done, [1], "geri çağrı")
	b.present = false
	check(not p.privacy_options_required(), "eklenti yoksa hayır")
	_drop(p, b)
