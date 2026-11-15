extends SceneTree
## Reklam akışı probesi (C8): GERÇEK sahnede bot koşuları + sahte (mock) sağlayıcı her sonuçla (başarı, kapatıldı, doluluk
## yok, zaman aşımı). Doğrular: diriltme koşuda bir kez ve yalnız ödülle; çekirdek tam bir kez ×2; yenileme sınırı; günlük
## bonus aynı gün iki kez alınamaz; geçiş reklamı pacing'i AdPacing kararıyla birebir (ilk 3 koşu yok, 180 sn, her 2. ölüm,
## ödüllüden sonra yok, reklamsız yok); ilk koşuda reklam arayüzü yok; hiçbir sonuçta oyun duraklı/sessiz kalmaz;
## TEKRAR OYNA / ANA MENÜ her zaman tamamlanır. Ayrıca iki hata düzeltmesi (hız sahibi, av modu uyarısı).
##   godot --headless --path . -s res://tools/dev/ads_probe.gd -- --no-save
## Kayıt dosyasına yazmaz (--no-save zorunlu). Başarı satırı: "ADS PROBE: geçti" + "SONUÇ: geçti".

const T0 := 1_800_000_000
const DAY := 86400

var S: Node          # autoload'lar -s betiğinde ada göre derlenmez: ağaçtan alınır
var SND: Node
var I18N: Node
var GD: Node
var scene
var mock: MockAdsProvider
var mgr: Node
var _fail := 0
var _checks := 0
var _started := 0
var _clock := T0


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fail += 1
	print(("  ✓ " if cond else "  ✗ ") + msg)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _wait(sec: float) -> void:
	await create_timer(sec, true, false, true).timeout


func _until(cond: Callable, timeout := 3.0) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await _wait(0.02)
		t += 0.02
	return cond.call()


# --- Kurulum yardımcıları ----------------------------------------------------------------------
func _provider(outcome: MockAdsProvider.Outcome, ready := true, interstitial_always := false) -> void:
	mock.outcome = outcome
	mock.ready = ready
	mock.delay_seconds = 0.05
	var cfg := AdConfig.load_file()
	cfg["settings"]["show_start_timeout_seconds"] = 0.5
	cfg["settings"]["max_ad_seconds"] = 5.0
	if interstitial_always:
		cfg["interstitial"]["free_runs"] = 0
		cfg["interstitial"]["every_n_deaths"] = 1
		cfg["interstitial"]["min_seconds"] = 0
	mgr.call("setup", cfg, load("res://scripts/services/settings_ad_environment.gd").new(), mock)
	mgr.call("reset_session")


func _tick_clock(seconds: int) -> void:
	_clock += seconds
	S.clock_override = _clock


func _new_run(runs_done: int) -> void:
	scene.ctx.flow.enter_menu()
	await _frames(2)
	S.flags["run_counter"] = runs_done
	scene.menus.play_pressed.emit()
	await _frames(3)


func _kill() -> void:
	if scene.ctx.cards.is_open:
		scene.ctx.cards.pick(0)
	scene.run.score = maxi(scene.run.score, 4500)   # çekirdek ödülü > 0 olsun (×2 anlamlı)
	scene.run.wave = maxi(scene.run.wave, 4)
	scene.player.invuln = 0.0
	scene.player.shield = 0
	scene.player.take_damage(99999.0, scene.player.pos2 + Vector2.UP)
	await _frames(3)


func _gameover() -> void:
	## Ölüm sekansı bitsin, oyun sonu ekranı açılsın.
	await _until(func() -> bool: return scene.state == "dead")
	scene.ctx.flow.dead_timer = 2.0
	await _until(func() -> bool: return scene.menus.current == "gameover")
	await _frames(2)


func _bot(seconds: float) -> void:
	scene.player.autopilot = true
	await _wait(seconds)
	if scene.ctx.cards.is_open:
		scene.ctx.cards.pick(0)


func _clean(tag: String) -> void:
	## Hiçbir sonuç oyunu duraklı, sessiz ya da yavaş bırakmamalı (ölüm yavaş çekimi bitene dek beklenir).
	await _frames(2)
	await _until(func() -> bool: return is_equal_approx(Engine.time_scale, 1.0), 1.5)   # ölüm yavaş çekimi 0.9 sn sürer
	_check(not paused, "%s: oyun duraklı DEĞİL" % tag)
	_check(not SND.ad_muted, "%s: ses kısık DEĞİL" % tag)
	_check(is_equal_approx(Engine.time_scale, 1.0), "%s: oyun hızı 1.0 (gelen %.3f)" % [tag, Engine.time_scale])
	_check(not scene.ctx.hooks.ad_active, "%s: reklam kilidi yok" % tag)


func _find_text(node: Node, text: String) -> Control:
	if node is Button and (node as Button).text == text:
		return node
	if node is Label and (node as Label).text == text:
		return node
	for child in node.get_children():
		var f := _find_text(child, text)
		if f != null:
			return f
	return null


func _hooks():   # tür belirtilmez: -s betiği autoload'lardan önce derlenir
	return scene.ctx.hooks


# --- Ana akış ----------------------------------------------------------------------------------
func _run() -> void:
	if not "--no-save" in OS.get_cmdline_user_args():
		printerr("PROBE HATA: --no-save gerekli (kayıt dosyası korunur)")
		quit(2)
		return
	await process_frame
	S = root.get_node("Settings")
	SND = root.get_node("Sound")
	I18N = root.get_node("I18n")
	GD = root.get_node("GameData")
	I18N.set_language("tr")
	scene = load("res://scenes/main.tscn").instantiate()
	scene.run_seed = 20260101   # tohumlu koşu: bot davranışı tekrarlanabilir
	root.add_child(scene)
	await _frames(3)
	mgr = root.get_node("AdManager")
	mock = MockAdsProvider.new()
	S.clock_override = _clock
	S.flags["ads_removed"] = true   # genel senaryolarda geçiş reklamı karışmasın (pacing bölümü kaldırır)
	scene.events.run_started.connect(func(_s: String, _seed: int) -> void: _started += 1)
	_provider(MockAdsProvider.Outcome.SUCCESS)

	await _t_first_run_clean()
	await _t_revive()
	await _t_revive_edge()
	await _t_double_cores()
	await _t_reroll()
	await _t_daily()
	await _t_interstitial_outcomes()
	await _t_pacing()
	await _t_lifecycle_and_language()
	await _t_time_scale()
	await _t_hunt_toast()

	print("ADS PROBE: %s (%d kontrol)" % ["geçti" if _fail == 0 else "%d HATA" % _fail, _checks])
	print("SONUÇ: %s" % ("geçti" if _fail == 0 else "%d hata" % _fail))
	S.clock_override = -1
	quit(0 if _fail == 0 else 1)


# --- 1. İlk koşu temiz ---------------------------------------------------------------------------
func _t_first_run_clean() -> void:
	print("▸ ilk koşu: hiçbir reklam arayüzü yok")
	_provider(MockAdsProvider.Outcome.SUCCESS)
	S.flags["run_counter"] = 0
	scene.ctx.flow.enter_menu()
	await _frames(2)
	var h = _hooks()
	_check(not h._daily_button.visible, "ana menü (hiç koşu bitmedi): günlük bonus girişi yok")
	await _new_run(0)
	await _bot(1.0)
	var shows_before := mock.show_count
	scene.ctx.rerolls = 0
	scene.ctx.cards.open()
	await _frames(2)
	_check(not h._reroll_button.visible, "ilk koşu kart ekranı: +1 yenileme düğmesi yok")
	scene.ctx.cards.pick(0)
	await _frames(2)
	await _kill()
	_check(not h.overlay.offer_visible and not h._revive_pending, "ilk koşu ölümü: diriltme teklifi YOK")
	await _gameover()
	_check(scene.state == "dead", "ilk koşu: doğrudan oyun sonu (durum %s, alive %s, ekran %s)" % [scene.state, scene.player.alive, scene.menus.current])
	_check(not h._double_button.visible, "ilk koşu oyun sonu: ×2 düğmesi yok")
	scene.menus.restart_pressed.emit()
	await _frames(3)
	_check(scene.state == "playing" and mock.show_count == shows_before, "ilk koşu: hiç reklam gösterilmedi, yeniden başlatma tamam")
	await _clean("ilk koşu")


# --- 2. Diriltme ------------------------------------------------------------------------------------
func _t_revive() -> void:
	print("▸ diriltme: ödül → canlan, koşuda bir kez")
	var h = _hooks()
	_provider(MockAdsProvider.Outcome.SUCCESS)
	await _new_run(1)
	await _bot(1.0)
	await _kill()
	_check(h.overlay.offer_visible, "ölüm: 'İZLE VE CANLAN' teklifi açık")
	_check(paused, "teklif sırasında oyun duraklı (arkada hasar/zamanlayıcı yok)")
	_check(scene.state == "playing" and not scene.player.alive, "ölüm sekansı bekletildi (henüz oyun sonu değil)")
	_check(h.overlay.decline_button.visible and h.overlay.countdown.seconds_left() >= 1, "geri sayım + VAZGEÇ görünür")
	var hp_before: float = scene.player.hp
	var t_before: float = scene.run.time
	await _wait(0.3)
	_check(is_equal_approx(scene.run.time, t_before) and is_equal_approx(scene.player.hp, hp_before), "duraklı oyun: süre/can ilerlemedi")
	var shows := mock.show_count
	h.overlay.accept_button.pressed.emit()
	await _frames(1)
	_check(h.ad_active and paused and SND.ad_muted, "reklam sırasında: duraklı + ses kısık")
	await _until(func() -> bool: return scene.player.alive)
	_check(mock.show_count == shows + 1, "tam bir reklam gösterildi")
	_check(scene.player.alive and scene.state == "playing", "ödül sonrası canlandı ve oyun sürüyor")
	_check(is_equal_approx(scene.player.hp, scene.player.max_hp * scene.ctx.tuning.revive_hp_ratio), "yarı canla (kart diriltmesiyle aynı yol)")
	_check(not paused and not SND.ad_muted, "reklam bitti: duraklatma/sessizlik geri alındı")
	_check(h.revive_used, "bu koşuda reklam diriltmesi kullanıldı")
	await _wait(0.2)
	await _kill()
	_check(not h.overlay.offer_visible, "aynı koşuda ikinci teklif YOK")
	_check(scene.state == "dead" or scene.player.alive == false, "ikinci ölüm normal oyun sonu")
	await _gameover()
	_check(scene.menus.current == "gameover", "oyun sonu ekranı açıldı")
	await _clean("diriltme başarı")

	print("▸ diriltme: kapatıldı / doluluk yok / zaman aşımı → normal oyun sonu, ödül yok")
	for item in [["kapatıldı", MockAdsProvider.Outcome.DISMISSED], ["doluluk yok", MockAdsProvider.Outcome.NO_FILL], ["zaman aşımı", MockAdsProvider.Outcome.TIMEOUT]]:
		_provider(item[1])
		await _new_run(1)
		await _kill()
		_check(h.overlay.offer_visible, "%s: teklif açıldı" % item[0])
		var revived := [false]
		var cb := func(_s: String) -> void: revived[0] = true
		scene.events.player_revived.connect(cb)
		h.overlay.accept_button.pressed.emit()
		await _until(func() -> bool: return scene.state == "dead", 3.0)
		scene.events.player_revived.disconnect(cb)
		_check(scene.state == "dead" and not revived[0], "%s: diriltme YOK, oyun sonu" % item[0])
		await _gameover()
		_check(scene.menus.current == "gameover", "%s: oyun sonu ekranı açılır" % item[0])
		await _clean("diriltme " + item[0])
	_provider(MockAdsProvider.Outcome.SUCCESS)


func _t_revive_edge() -> void:
	print("▸ diriltme: vazgeç, geri sayım bitişi, reklam yok, kart önceliği")
	var h = _hooks()
	# VAZGEÇ düğmesi
	await _new_run(1)
	await _kill()
	var shows := mock.show_count
	h.overlay.decline_button.pressed.emit()
	await _frames(2)
	_check(scene.state == "dead" and mock.show_count == shows and not paused, "VAZGEÇ: reklam gösterilmedi, normal oyun sonu, duraklı değil")
	await _gameover()
	await _clean("vazgeç")
	# Geri sayım bitişi = vazgeç
	await _new_run(1)
	await _kill()
	h.overlay.advance(h.cfg.revive_offer_seconds + 0.5)
	await _frames(2)
	_check(scene.state == "dead" and not h.overlay.offer_visible and mock.show_count == shows, "süre bitti: vazgeçilmiş sayılır")
	await _gameover()
	await _clean("süre bitti")
	# Reklam hazır değil: teklif hiç çıkmaz (ölü düğme yok)
	_provider(MockAdsProvider.Outcome.SUCCESS, false)
	await _new_run(1)
	await _kill()
	_check(not h.overlay.offer_visible and scene.state == "dead", "reklam hazır değil: teklif YOK, doğrudan oyun sonu")
	await _gameover()
	_check(not h._double_button.visible, "reklam hazır değil: ×2 düğmesi görünmez")
	await _clean("reklam yok")
	_provider(MockAdsProvider.Outcome.SUCCESS)
	# Kart İkinci Şans öncelikli
	await _new_run(1)
	var card: Dictionary = GD.card_by_id("ikincisans")
	scene.loadout.apply(card)
	var offered := [false]
	var cb2 := func(_c: bool) -> void: offered[0] = h.overlay.offer_visible
	scene.events.player_died.connect(cb2)
	var shows2 := mock.show_count
	await _kill()
	scene.events.player_died.disconnect(cb2)
	_check(scene.player.alive and not h.overlay.offer_visible and mock.show_count == shows2, "kart diriltmesi önce: reklam teklifi çıkmadı")
	await _kill()
	_check(h.overlay.offer_visible, "kart bitince reklam diriltmesi teklif edilir")
	h.overlay.decline_button.pressed.emit()
	await _gameover()
	await _clean("kart önceliği")


# --- 3. Çift çekirdek -----------------------------------------------------------------------------------
func _t_double_cores() -> void:
	print("▸ çift çekirdek: tam bir kez")
	var h = _hooks()
	_provider(MockAdsProvider.Outcome.SUCCESS)
	await _new_run(1)
	await _bot(1.0)
	await _kill()
	h.overlay.decline_button.pressed.emit()
	await _gameover()
	var earned: int = scene._cores_earned
	var total_before: int = S.meta.cores
	_check(earned > 0 and h._double_button.visible, "oyun sonu: ×2 düğmesi görünür (ikinci koşu, kazanç %d)" % earned)
	# çift dokunuş + ekrandan çıkma + uygulama duraklaması reklam sürerken
	var shows := mock.show_count
	h._double_button.pressed.emit()
	h._double_button.pressed.emit()
	await _frames(1)
	scene.menus.menu_pressed.emit()       # reklam sürerken çıkmaya çalış
	scene.menus.restart_pressed.emit()
	scene.menus._notification(Node.NOTIFICATION_APPLICATION_PAUSED)   # uygulama arka plana
	await _frames(1)
	_check(scene.state == "dead" and h.ad_active, "reklam sürerken menü/yeniden başlat yok sayıldı, durum aynı")
	await _until(func() -> bool: return h.double_used)
	_check(mock.show_count == shows + 1, "çift dokunuş: yalnız BİR reklam")
	_check(S.meta.cores == total_before + earned, "çekirdek tam bir kez ikiye katlandı (+%d)" % earned)
	_check(h.double_extra == earned, "ek miktar = bu koşunun kazancı")
	_check(not h._double_button.visible, "düğme gizlendi")
	h._on_double_pressed()
	await _frames(2)
	_check(S.meta.cores == total_before + earned and mock.show_count == shows + 1, "ikinci talep etkisiz")
	_check(scene.state == "dead" and not paused and not SND.ad_muted, "uygulama duraklaması sonrası durum geri geldi")
	await _clean("çift çekirdek")
	# başarısız → ödül yok, hak tüketilmez, sonra başarıyla alınabilir
	for oc in [MockAdsProvider.Outcome.DISMISSED, MockAdsProvider.Outcome.NO_FILL, MockAdsProvider.Outcome.TIMEOUT]:
		_provider(oc)
		await _new_run(1)
		await _kill()
		h.overlay.decline_button.pressed.emit()
		await _gameover()
		var before: int = S.meta.cores
		h._double_button.pressed.emit()
		await _until(func() -> bool: return not h.ad_active and not h._double_busy, 3.0)
		_check(S.meta.cores == before and not h.double_used, "çekirdek ×2 %s: ödül YOK" % MockAdsProvider.Outcome.keys()[oc])
		_check(h._double_button.visible and not h._double_button.disabled, "başarısız istek hak tüketmedi: düğme yeniden kullanılabilir")
		await _clean("çift çekirdek başarısız")
	_provider(MockAdsProvider.Outcome.SUCCESS)
	var before2: int = S.meta.cores
	h._double_button.pressed.emit()
	await _until(func() -> bool: return h.double_used)
	_check(S.meta.cores == before2 + scene._cores_earned, "yeniden denemede ×2 alındı")


# --- 4. Yenileme ----------------------------------------------------------------------------------------
func _t_reroll() -> void:
	print("▸ +1 yenileme: koşu başına sınır veriden")
	var h = _hooks()
	_provider(MockAdsProvider.Outcome.SUCCESS)
	await _new_run(1)
	scene.ctx.rerolls = 1
	scene.ctx.cards.open()
	await _frames(2)
	_check(not h._reroll_button.visible, "yenileme hakkı varken teklif yok")
	scene.ctx.rerolls = 0
	scene.ctx.cards.pick(0)
	await _frames(2)
	scene.ctx.cards.open()
	await _frames(2)
	_check(h._reroll_button.visible, "yenileme bitince 'İZLE: +1 YENİLE' görünür")
	var limit: int = int(AdConfig.limits(AdConfig.load_file(), "REROLL")["per_run"])
	var got := 0
	for i in limit + 2:
		if not h._reroll_button.visible:
			break
		var before: int = scene.ctx.rerolls
		h._reroll_button.pressed.emit()
		await _until(func() -> bool: return scene.ctx.rerolls > before, 2.0)
		if scene.ctx.rerolls > before:
			got += 1
			_check(scene.ctx.rerolls == before + 1, "ödül: tam +1 yenileme (%d)" % scene.ctx.rerolls)
			scene.ctx.rerolls = 0   # harcanmış say (sınır koşu başına sayılır)
			scene.menus.cards.set_rerolls(0)
			h._refresh_reroll()
	_check(got == limit, "koşu başına en fazla %d reklam yenilemesi (alınan %d)" % [limit, got])
	_check(not h._reroll_button.visible, "sınır dolunca düğme gizli")
	_check(not paused or scene.ctx.cards.is_open, "kart ekranı dışında duraklatma kalmadı")
	scene.ctx.cards.pick(0)
	await _frames(2)
	_check(not paused, "kart seçildi: oyun duraklı değil")
	# başarısız → yenileme yok
	for oc in [MockAdsProvider.Outcome.DISMISSED, MockAdsProvider.Outcome.NO_FILL, MockAdsProvider.Outcome.TIMEOUT]:
		_provider(oc)
		await _new_run(1)
		scene.ctx.rerolls = 0
		scene.ctx.cards.open()
		await _frames(2)
		h._reroll_button.pressed.emit()
		await _until(func() -> bool: return not h.ad_active and not h._reroll_busy, 3.0)
		_check(scene.ctx.rerolls == 0, "yenileme %s: ödül YOK" % MockAdsProvider.Outcome.keys()[oc])
		_check(scene.ctx.cards.is_open and paused, "kart ekranı bozulmadı (hâlâ duraklı, açık)")
		scene.ctx.cards.pick(0)
		await _frames(2)
		await _clean("yenileme " + MockAdsProvider.Outcome.keys()[oc])
	_provider(MockAdsProvider.Outcome.SUCCESS)
	# yeni koşuda sınır sıfırlanır
	await _new_run(1)
	scene.ctx.rerolls = 0
	scene.ctx.cards.open()
	await _frames(2)
	_check(h._reroll_button.visible, "yeni koşu: yenileme teklifi yeniden var")
	scene.ctx.cards.pick(0)
	await _frames(2)


# --- 5. Günlük bonus --------------------------------------------------------------------------------------
func _t_daily() -> void:
	print("▸ günlük bonus: günde bir kez")
	var h = _hooks()
	_provider(MockAdsProvider.Outcome.SUCCESS)
	_tick_clock(DAY)
	S.flags["run_counter"] = 1
	S.flags["daily_bonus_date"] = ""
	scene.ctx.flow.enter_menu()
	await _frames(2)
	_check(h._daily_button.visible, "ana menü: GÜNLÜK BONUS girişi görünür")
	var amount: int = h.cfg.daily_bonus_cores
	_check(amount == 50, "bonus miktarı veriden (%d)" % amount)
	var before: int = S.meta.cores
	var shows := mock.show_count
	h._daily_button.pressed.emit()
	h._daily_button.pressed.emit()
	await _until(func() -> bool: return S.meta.cores > before)
	await _frames(2)
	_check(S.meta.cores == before + amount and mock.show_count == shows + 1, "bonus tam bir kez verildi (+%d)" % amount)
	_check(not h._daily_button.visible and not Ads.daily_bonus_available(), "aynı gün ikinci talep: giriş gizli")
	h._on_daily_pressed()
	await _frames(2)
	_check(S.meta.cores == before + amount, "aynı gün zorla çağrı da çekirdek vermez")
	scene.ctx.flow.enter_menu()
	await _frames(2)
	_check(not h._daily_button.visible, "menüye dönünce de gizli")
	_tick_clock(DAY)
	scene.ctx.flow.enter_menu()
	await _frames(2)
	_check(h._daily_button.visible, "ertesi gün yeniden alınabilir")
	# başarısızlık hak tüketmez
	for oc in [MockAdsProvider.Outcome.DISMISSED, MockAdsProvider.Outcome.NO_FILL, MockAdsProvider.Outcome.TIMEOUT]:
		_provider(oc)
		var b: int = S.meta.cores
		h._daily_button.pressed.emit()
		await _until(func() -> bool: return not h.ad_active and not h._daily_busy, 3.0)
		_check(S.meta.cores == b and h._daily_button.visible, "günlük %s: ödül yok, hak duruyor" % MockAdsProvider.Outcome.keys()[oc])
		await _clean("günlük " + MockAdsProvider.Outcome.keys()[oc])
	_provider(MockAdsProvider.Outcome.SUCCESS)


# --- 6. Geçiş reklamı: sonuçlar -------------------------------------------------------------------------------
func _t_interstitial_outcomes() -> void:
	print("▸ geçiş reklamı: her sonuçta TEKRAR OYNA / ANA MENÜ tam bir kez tamamlanır")
	var h = _hooks()
	S.flags["ads_removed"] = false
	for oc in [MockAdsProvider.Outcome.SUCCESS, MockAdsProvider.Outcome.DISMISSED, MockAdsProvider.Outcome.NO_FILL, MockAdsProvider.Outcome.TIMEOUT]:
		for action in ["restart", "menu"]:
			_provider(oc, true, true)
			await _new_run(5)
			await _kill()
			h.overlay.decline_button.pressed.emit()
			await _gameover()
			var started_before := _started
			var shows := mock.show_count
			if action == "restart":
				scene.menus.restart_pressed.emit()
				scene.menus.restart_pressed.emit()   # çift dokunuş
			else:
				scene.menus.menu_pressed.emit()
				scene.menus.menu_pressed.emit()
			await _until(func() -> bool: return scene.state != "dead", 3.0)
			await _frames(3)
			var tag := "%s/%s" % [MockAdsProvider.Outcome.keys()[oc], action]
			_check(mock.show_count == shows + 1, "%s: geçiş reklamı istendi (bir kez)" % tag)
			if action == "restart":
				_check(scene.state == "playing" and _started == started_before + 1, "%s: yeni koşu tam bir kez başladı" % tag)
			else:
				_check(scene.state == "menu" and not paused, "%s: ana menüye geçildi" % tag)
			await _clean("geçiş " + tag)
	# reklam hazır değil: yine tamamlanır
	_provider(MockAdsProvider.Outcome.SUCCESS, false, true)
	await _new_run(5)
	await _kill()
	await _gameover()
	var sb := _started
	scene.menus.restart_pressed.emit()
	await _frames(3)
	_check(scene.state == "playing" and _started == sb + 1, "reklam hazır değil: yeniden başlatma yine tamam")
	# oyun SIRASINDA geçiş yok: duraklatma menüsünden yeniden başlat
	var shows := mock.show_count
	_provider(MockAdsProvider.Outcome.SUCCESS, true, true)
	await _new_run(5)
	shows = mock.show_count
	scene.flow.pause() if false else scene.ctx.flow.pause()
	await _frames(2)
	scene.menus.restart_pressed.emit()
	await _frames(3)
	_check(mock.show_count == shows and scene.state == "playing", "oyun sırasında (duraklatmadan yeniden başlat) geçiş reklamı YOK")
	S.flags["ads_removed"] = true


# --- 7. Geçiş reklamı: pacing dizisi ------------------------------------------------------------------------------
func _expected_reason(runs_completed: int, deaths_since: int, now: int, last: int, rewarded: bool, removed: bool) -> String:
	var c := AdPacing.Context.new()
	c.runs_completed = runs_completed
	c.deaths_since_last = deaths_since
	c.now_unix = now
	c.last_interstitial_unix = last
	c.rewarded_just_watched = rewarded
	c.ads_removed = removed
	return AdPacing.evaluate(c, AdConfig.pacing(AdConfig.load_file()))


func _pacing_series(name: String, spacing: int, runs: int, rewarded_run := -1, removed := false) -> Array:
	## `runs` koşu oynar (her biri ölür, oyun sonu, sırayla TEKRAR OYNA/ANA MENÜ); AdPacing'i bağımsız modelle karşılaştırır.
	var h = _hooks()
	var shown: Array = []
	S.flags["ads_removed"] = removed
	S.flags["run_counter"] = 0
	S.flags["last_transition_time"] = 0
	_provider(MockAdsProvider.Outcome.SUCCESS)
	mgr.call("reset_session")
	var deaths := 0
	var last := 0
	for i in range(1, runs + 1):
		await _new_run(i - 1)
		await _kill()
		h.overlay.decline_button.pressed.emit()
		await _gameover()
		var rewarded := false
		if i == rewarded_run:
			h._double_button.pressed.emit()
			await _until(func() -> bool: return h.double_used)
			rewarded = h.double_used
		_tick_clock(spacing)
		deaths += 1
		var now := _clock
		var want := _expected_reason(i, deaths, now, last, rewarded, removed)
		var shows := mock.show_count
		if i % 2 == 0:
			scene.menus.menu_pressed.emit()
		else:
			scene.menus.restart_pressed.emit()
		await _until(func() -> bool: return scene.state != "dead", 3.0)
		await _frames(2)
		var did: bool = mock.show_count == shows + 1
		var got: String = mgr.get("last_pacing_reason")
		_check(got == want and did == (want == ""), "%s koşu %d: karar '%s' (model '%s'), reklam %s" % [name, i, got, want, "VAR" if did else "yok"])
		if did:
			deaths = 0
			last = now
		shown.append(did)
		await _wait(0.1)
	return shown


func _t_pacing() -> void:
	print("▸ geçiş reklamı pacing dizisi (AdPacing ile birebir)")
	_tick_clock(DAY)
	var s1 := await _pacing_series("120sn aralık", 120, 8)
	_check(not s1[0] and not s1[1] and not s1[2], "ilk 3 koşuda geçiş reklamı YOK")
	_check(s1[3], "4. koşuda (≥2 ölüm, ≥180 sn) geçiş reklamı var")
	_check(not s1[4], "hemen ardından gelen ölümde yok (her 2. ölüm kuralı)")
	var s2 := await _pacing_series("50sn aralık", 50, 7)
	_check(not s2.has(true) or s2.count(true) < 3, "kısa aralıklarda 180 sn kuralı ağır basar (en fazla seyrek)")
	var s3 := await _pacing_series("ödüllü izlendi", 120, 6, 4)
	_check(not s3[3], "4. koşuda ödüllü reklam izlendi: o koşuda geçiş YOK")
	var s4 := await _pacing_series("reklamsız", 120, 6, -1, true)
	_check(not s4.has(true), "reklamsız (remove-ads): hiçbir koşuda geçiş reklamı YOK")
	S.flags["ads_removed"] = true
	_check(not mgr.call("can_show", AdPlacement.Id.INTERSTITIAL), "remove-ads: geçiş yerleşimi kapalı")
	_check(mgr.call("can_show", AdPlacement.Id.REVIVE), "remove-ads yalnız geçişi kaldırır: ödüllüler açık")


# --- 8. Yaşam döngüsü, dil değişimi, gizlilik ------------------------------------------------------------------------------
func _t_lifecycle_and_language() -> void:
	print("▸ yaşam döngüsü: begin_run, dil değişimi, gizlilik satırı")
	var h = _hooks()
	_provider(MockAdsProvider.Outcome.SUCCESS)
	S.flags["ads_removed"] = true
	# begin_run: yeni koşuda diriltme/çift/yenileme limitleri sıfırlanır
	await _new_run(1)
	_check(mgr.call("used_in_run", AdPlacement.Id.REVIVE) == 0, "yeni koşu: koşu limitleri sıfır (Ads.begin_run)")
	# gizlilik satırı yalnız gerekliyse
	var title_tr := "GİZLİLİK SEÇENEKLERİ"
	scene.ctx.flow.enter_menu()
	await _frames(2)
	_check(_find_text(scene.menus.settings.root, title_tr) == null, "gizlilik gerekmiyor: satır YOK")
	mock.privacy_required = true
	mgr.emit_signal("availability_changed")
	await _frames(2)
	var row := _find_text(scene.menus.settings.root, title_tr)
	_check(row != null, "gizlilik gerekli: satır var")
	var open_button := _find_text(scene.menus.settings.root, "AÇ") as Button
	if open_button != null:
		open_button.pressed.emit()
	_check(mock.privacy_shown_count == 1, "satır Ads.show_privacy_options'ı çağırır")
	# dil değişimi ekranları yeniden kurar: eklenenler yeniden eklenir, EN metinler
	S.flags["run_counter"] = 1
	S.flags["daily_bonus_date"] = ""
	_tick_clock(DAY)
	I18N.set_language("en")
	await _frames(3)
	scene.ctx.flow.enter_menu()
	await _frames(2)
	_check(h._daily_button.visible and h._daily_button.text == "DAILY BONUS  +%d" % h.cfg.daily_bonus_cores, "EN: günlük bonus girişi yeniden eklendi (%s)" % h._daily_button.text)
	_check(h._double_button.text == "WATCH: CORES ×2" and h._reroll_button.text == "WATCH: +1 REROLL", "EN: ×2 ve yenileme düğmeleri yeniden eklendi")
	_check(_find_text(scene.menus.settings.root, "PRIVACY OPTIONS") != null, "EN: gizlilik satırı yeniden eklendi")
	h.overlay.show_offer(1.0)
	_check(h.overlay.accept_button.text == "WATCH TO REVIVE" and h.overlay.decline_button.text == "NO THANKS", "EN: teklif metinleri")
	h.overlay.hide_overlay()
	I18N.set_language("tr")
	await _frames(3)
	mock.privacy_required = false
	_check(h._double_button.text == "İZLE: ÇEKİRDEK ×2", "TR: metinler Türkçe")
	# uygulama arka plana gitti / geri döndü: duraklatma menüsü reklam sırasında açılmaz, sonra normal
	await _new_run(1)
	scene.menus._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await _frames(2)
	_check(scene.menus.current == "pause" and paused, "oyun sırasında arka plana gitmek duraklatma menüsünü açar (reklam yokken)")
	scene.menus.resume_pressed.emit()
	await _frames(2)
	_check(not paused and scene.state == "playing", "devam: duraklatma kalktı")
	await _clean("yaşam döngüsü")


# --- 9. Hata düzeltmeleri ---------------------------------------------------------------------------------------------------------
func _t_time_scale() -> void:
	print("▸ hata (a): vuruş donması ölüm yavaş çekimini bayat bırakmaz")
	var fx: Node = root.get_node("Fx")
	fx.settle_time()
	fx.slow_motion(0.3, 0.15)     # ölüm yavaş çekimi
	fx.hitstop(0.4, 0.1)          # yavaş çekim bittikten SONRA biten donma (eski hata: 0.3 geri yazılırdı)
	await _wait(0.8)
	_check(is_equal_approx(Engine.time_scale, 1.0), "yavaş çekim + araya giren donma sonrası hız 1.0 (gelen %.3f)" % Engine.time_scale)
	fx.slow_motion(0.3, 5.0)
	fx.hitstop(0.1, 0.2)
	await _wait(0.3)
	_check(is_equal_approx(Engine.time_scale, 0.3), "donma bitti, yavaş çekim sürüyor (0.3)")
	fx.settle_time()
	_check(is_equal_approx(Engine.time_scale, 1.0), "duraklat/reklam/yeni koşu: settle geçici katmanları kapatır")
	await _wait(0.2)
	fx.settle_time()
	# gerçek ölüm + donma akışı
	await _new_run(0)
	await _kill()
	fx.hitstop(0.5, 0.1)
	await _gameover()
	await _wait(1.2)
	_check(is_equal_approx(Engine.time_scale, 1.0), "gerçek ölüm sekansı + donma: oyun sonu ekranı tam hızda (gelen %.3f)" % Engine.time_scale)
	# duraklatma sırasında başlayan donma
	await _new_run(0)
	fx.hitstop(0.3, 0.1)
	scene.ctx.flow.pause()
	await _wait(0.5)
	_check(is_equal_approx(Engine.time_scale, 1.0), "duraklat: yavaşlık takılı kalmaz (gelen %.3f)" % Engine.time_scale)
	scene.menus.resume_pressed.emit()
	await _frames(2)


func _t_hunt_toast() -> void:
	print("▸ hata (b): av modu uyarısı yalnız ölü düşman varken çıkmaz")
	await _new_run(0)
	var hud = scene.hud
	var kind: String = str(GD.balance["enemies"].keys()[0])
	scene.ctx.spawner.spawn_enemy(kind, Vector2(900, 900), 0.0, false)
	await _frames(1)
	for e in scene.enemies:
		e.dead = true
	hud._toast_time = 0.0
	hud._toast = ""
	scene.ctx.spawner._hunt_stragglers()
	_check(hud._toast_time <= 0.0 and hud._toast == "", "yalnız ölü düşman: 'yaklaşıyor' uyarısı YOK")
	scene.ctx.spawner.spawn_enemy(kind, Vector2(1200, 900), 0.0, false)
	await _frames(1)
	var alive := 0
	for e in scene.enemies:
		if is_instance_valid(e) and not e.dead:
			alive += 1
	scene.ctx.spawner._hunt_stragglers()
	_check(alive > 0 and hud._toast_time > 0.0, "canlı düşman varken uyarı çıkar")
