extends SceneTree
## C1 koşu yapısı probesi: GERÇEK sahnede (scenes/main.tscn) tohumlu koşular.
##   1) bot (demo) standart koşu: boss → SEKTÖR KAPISI (bot seçer) → 2. sektör → … → ZAFER → sonuç ekranı "ZAFER"
##   2) oyuncu yolu: kapı ekranı (duraklatır, 3 kart, çift dokunuş, ATLA), zafer ekranı → SONSUZA DEVAM → ölüm → sonuç
##   3) hızlı mod: zafer → SONUÇLAR → İZLE ×2 çekirdek (mock reklam) → TEKRAR OYNA (geçiş kararı, eylem bir kez)
##   4) mod seçici + mod rekorları, dil değişiminde ekranların yeniden kaydı, duraklatma kapıda yok sayılır
## Boss'lar araçla bitirilir (take_damage), oyuncu dokunulmaz tutulur: amaç akışın doğruluğu, denge değil (denge: tools/sim).
##   godot --headless --path . -s res://tools/dev/run_probe.gd -- --no-save [--seed=7]
## Kayıt dosyasına yazmaz (--no-save zorunlu). Başarı: "SONUÇ: geçti".

var S: Node
var I18N: Node
var FX: Node
var scene
var _fail := 0
var _checks := 0
var _events: Dictionary = {}


func _check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_fail += 1
	print(("  ✓ " if cond else "  ✗ ") + msg)


func _initialize() -> void:
	_run.call_deferred()


func _arg(name: String, fallback: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + name + "="):
			return a.get_slice("=", 1)
	return fallback


func _wait(sec: float) -> void:
	if scene != null and is_instance_valid(scene) and scene.player != null:
		scene.player.invuln = 3.0   # akış probu: oyuncu ölmesin (ölüm ayrıca, bilerek)
		if scene.ctx.cards.is_open and not scene.ctx.options.demo:
			scene.ctx.cards.pick(0)   # oyuncu yolunda seviye kartı açılırsa ilkini seç
	await create_timer(sec, true, false, true).timeout


func _until(cond: Callable, timeout := 20.0) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await _wait(0.05)
		t += 0.05
	return cond.call()


func _count(name: String) -> void:
	_events[name] = int(_events.get(name, 0)) + 1


func _kill_boss() -> bool:
	var up := await _until(func(): return scene.boss != null and is_instance_valid(scene.boss) and scene.boss.alive and scene.boss.intro <= 0.0)
	if up:
		scene.boss.take_damage(scene.boss.hp + 1.0)
	return up


func _start(mode: String, demo: bool, wave: int) -> void:
	var ctx = scene.ctx
	ctx.flow.enter_menu()
	await _wait(0.05)
	ctx.options.demo = demo
	ctx.options.run_mode = mode
	ctx.options.start_wave = wave
	ctx.flow.start_game()
	await _wait(0.05)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if not ("--no-save" in args):
		printerr("PROBE HATA: --no-save gerekli (kayıt dosyası korunur)")
		quit(2)
		return
	S = root.get_node("Settings")
	I18N = root.get_node("I18n")
	FX = root.get_node("Fx")
	await process_frame
	scene = load("res://scenes/main.tscn").instantiate()
	scene.run_seed = int(_arg("seed", "7"))
	root.add_child(scene)
	FX.set_base_scale(3.0)
	await _wait(0.1)
	var ctx = scene.ctx
	ctx.events.gate_chosen.connect(func(_id): _count("gate"))
	ctx.events.run_won.connect(func(_s): _count("won"))
	ctx.events.run_ended.connect(func(_s): _count("ended"))
	ctx.events.sector_cleared.connect(func(_a, _b): _count("sector"))

	print("== 1) bot: standart koşu, kapı → sektör → zafer ==")
	S.flags["run_counter"] = 0
	await _start("standard", true, 5)
	_check(scene.run.mode == "standard" and scene.run.has_goal(), "standart mod seçildi, hedef var")
	_check(ctx.flow.sector_hud != null and ctx.flow.sector_hud.visible, "hedef göstergesi görünür")
	for k in 3:
		var wave_at: int = [5, 10, 15][k]
		if k > 0:
			scene.run.jump_to(wave_at)
		_check(await _kill_boss(), "sektör %d boss'u çıktı ve bitirildi" % (k + 1))
		if k < 2:
			var moved := await _until(func(): return scene.run.map_index == k + 1 and scene.run.wave == wave_at + 1)
			_check(moved, "kapıdan sonra sektör %d (harita %d, dalga %d)" % [k + 2, scene.run.map_index, scene.run.wave])
			_check(scene.world.theme_index == k + 1, "yeni harita kuruldu")
			_check(int(_events.get("gate", 0)) == k + 1, "bot kapıda seçim yaptı (%s)" % str(Array(scene.run.gates_taken)))
			_check(scene.state == "playing" and not paused, "oyun sürüyor, duraklı değil")
	var over := await _until(func(): return scene.state == "dead" and ctx.menus.current == "gameover")
	_check(over, "zafer → sonuç ekranı")
	_check(scene.run.won and ctx.flow.outcome == "victory", "koşu zaferle bitti")
	_check(ctx.menus.gameover._title.text == scene.tr("ZAFER"), "sonuç başlığı ZAFER")
	_check(scene._cores_earned == scene.run.reward_total(scene.loadout.m("core_mult")) and scene._cores_earned > 0, "ödül eğrisi: %d çekirdek" % scene._cores_earned)
	_check(int(_events.get("won", 0)) == 1 and int(_events.get("ended", 0)) == 1, "run_won ve run_ended birer kez")
	_check(int(_events.get("sector", 0)) == 3, "3 sektör olayı")
	_check(int(RunRecords.get_record(S.flags, "standard")["wins"]) == 1, "mod rekoru: 1 zafer")

	print("== 2) oyuncu: kapı ekranı, ATLA, zafer ekranı → sonsuza devam → ölüm ==")
	_events.clear()
	S.flags["run_counter"] = 0
	await _start("standard", false, 5)
	_check(await _kill_boss(), "1. boss bitirildi")
	var gate_up := await _until(func(): return ctx.menus.current == "gate")
	_check(gate_up and paused, "kapı ekranı açıldı, oyun duraklı")
	_check(ctx.flow.gate.card_count() == 3, "3 seçenek kartı")
	_check(scene.run.gate_options[0] == "repair", "ilk seçenek güvenli")
	ctx.hooks.on_pause_requested()
	_check(ctx.menus.current == "gate", "kapıdayken duraklatma isteği yok sayılır")
	await _wait(0.4)   # kartlar belirince tıklanabilir
	var pick: String = scene.run.gate_options[1]
	var mult_before: float = scene.run.reward_mult
	var bonus: float = scene.run.gate_reward_bonus(pick)   # lanetli kart atanmışsa 0 (ödül core_mult'ta)
	ctx.flow.gate.press(1)
	ctx.flow.gate.press(0)   # çift dokunuş: yok sayılmalı
	await _wait(0.1)
	_check(not paused and ctx.menus.current == "", "seçimden sonra oyun sürer")
	_check(Array(scene.run.gates_taken) == [pick], "seçilen kapı kaydedildi (%s), çift dokunuş yok sayıldı" % pick)
	_check(scene.run.map_index == 1 and scene.run.wave == 6, "2. sektör başladı")
	_check(absf(scene.run.reward_mult - (mult_before + bonus)) < 0.001, "kapı ödül çarpanı uygulandı (+%.2f)" % bonus)
	scene.run.jump_to(10)
	_check(await _kill_boss(), "2. boss bitirildi")
	_check(await _until(func(): return ctx.menus.current == "gate"), "ikinci kapı")
	await _wait(0.4)
	ctx.flow.gate.press(-1)
	await _wait(0.1)
	_check(scene.run.map_index == 2 and scene.run.gates_taken.size() == 1, "ATLA: sektör ilerledi, kapı kaydedilmedi")
	scene.run.jump_to(15)
	_check(await _kill_boss(), "3. boss bitirildi")
	_check(await _until(func(): return ctx.menus.current == "victory"), "zafer ekranı açıldı")
	_check(paused and ctx.flow.victory._continue.visible, "zaferde oyun duraklı, SONSUZA DEVAM görünür")
	ctx.flow.victory.press(false)
	await _wait(0.1)
	_check(not paused and scene.run.continued and scene.run.wave == 16 and scene.run.map_index == 3, "sonsuza devam: dalga 16, harita 3")
	_check(not ctx.flow.sector_hud.visible, "devamda sektör hedefi gizlenir")
	_check(scene.state == "playing", "koşu sürüyor")
	await _wait(0.3)
	scene.player.invuln = 0.0
	scene.player.shield = 0
	# Bot kart seçimi rastgele: İkinci Şans (revive) seçildiyse bu ölüm diriltmeye dönerdi (C3 sonrası 45 kartlık havuzda
	# bu tohumla seçiliyor). Diriltme hakları harcanmış say: burada ölüm → sonuç akışı sınanıyor.
	ctx.flow.revives_used = scene.loadout.i("revive")
	scene.player.take_damage(99999.0, scene.player.pos2 + Vector2.UP)
	_check(await _until(func(): return ctx.menus.current == "gameover"), "ölüm → sonuç ekranı")
	_check(ctx.flow.outcome == "death" and scene.run.won, "ölümle bitti, zafer korunur")
	_check(ctx.menus.gameover._title.text == scene.tr("ZAFER"), "başlık yine ZAFER")
	_check(ctx.flow._result_label.visible and ctx.flow._result_label.text.find(scene.tr("ZAFER")) >= 0, "sonuç satırı: " + ctx.flow._result_label.text)
	var rw: Dictionary = scene.run.reward(scene.loadout.m("core_mult"))
	_check(int(rw["victory"]) > 0 and int(rw["extra"]) >= 0, "ödülde zafer payı var (+devam payı %d)" % int(rw["extra"]))

	print("== 3) hızlı mod: zafer → SONUÇLAR → ×2 çekirdek → TEKRAR OYNA ==")
	var mgr: Node = root.get_node("AdManager")
	var mock := MockAdsProvider.new()
	mock.outcome = MockAdsProvider.Outcome.SUCCESS
	mock.ready = true
	mock.delay_seconds = 0.05
	var cfg := AdConfig.load_file()
	cfg["settings"]["show_start_timeout_seconds"] = 0.5
	mgr.call("setup", cfg, load("res://scripts/services/settings_ad_environment.gd").new(), mock)
	mgr.call("reset_session")
	S.flags["run_counter"] = 5   # reklam arayüzü açık (ilk koşu değil)
	await _start("quick", false, 9)
	_check(scene.run.waves_per_sector() == 3 and scene.run.is_boss_wave(9), "hızlı: 9. dalga boss")
	_check(await _kill_boss(), "hızlı mod boss'u bitirildi")
	_check(await _until(func(): return ctx.menus.current == "victory"), "hızlı modda zafer ekranı")
	_check(not ctx.flow.victory._continue.visible, "hızlı modda sonsuza devam yok")
	ctx.flow.victory.press(true)
	await _wait(0.1)
	_check(scene.state == "dead" and ctx.menus.current == "gameover" and not paused, "SONUÇLAR → oyun sonu ekranı, duraklı değil")
	var earned: int = scene._cores_earned
	_check(earned > 0, "zafer ödülü %d" % earned)
	_check(ctx.hooks._double_button.visible, "zafer sonucunda İZLE ×2 teklifi görünür")
	var cores_before: int = S.meta.cores
	ctx.hooks._double_button.pressed.emit()
	_check(await _until(func(): return ctx.hooks.double_used, 3.0), "×2 ödülü verildi")
	_check(S.meta.cores == cores_before + ctx.hooks.double_extra and ctx.hooks.double_extra == earned, "çekirdek tam bir kez ikiye katlandı")
	_check(await _until(func(): return not ctx.hooks.ad_active and not paused, 3.0), "reklam sonrası oyun serbest")
	ctx.hooks.on_restart()
	_check(await _until(func(): return scene.state == "playing", 5.0), "TEKRAR OYNA tamamlandı (geçiş kararı → eylem)")
	_check(int(RunRecords.get_record(S.flags, "quick")["wins"]) == 1 and int(RunRecords.get_record(S.flags, "standard")["wins"]) == 2, "rekorlar mod başına ayrı")

	print("== 4) mod seçici, dil değişimi, debug ekranı ==")
	ctx.options.run_mode = ""
	RunRecords.select_mode(S.flags, "standard")
	ctx.flow.enter_menu()
	await _wait(0.1)
	_check(ctx.flow.current_mode() == "standard", "seçili mod standart")
	_check(ctx.flow._mode_button.is_inside_tree() and ctx.flow._mode_button.text.find(scene.tr("STANDART")) >= 0, "ana menüde mod düğmesi")
	ctx.flow.cycle_mode()
	_check(ctx.flow.current_mode() == "quick", "mod düğmesi: hızlı")
	ctx.flow.cycle_mode()
	ctx.flow.cycle_mode()
	_check(ctx.flow.current_mode() == "standard", "üç basışta başa döner")
	I18N.set_language("en")
	await _wait(0.1)
	_check(ctx.menus.modules.has("gate") and ctx.menus.modules.has("victory"), "dil değişince kapı/zafer ekranları yeniden kaydedildi")
	_check(ctx.flow._mode_button.is_inside_tree() and ctx.flow._mode_button.text.begins_with("MODE"), "mod düğmesi İngilizce")
	I18N.set_language("tr")
	await _wait(0.1)
	ctx.options.debug_screen = "gate"
	await _start("standard", false, 1)
	_check(await _until(func(): return ctx.menus.current == "gate", 3.0), "--screen=gate kapı ekranını açar")
	ctx.options.debug_screen = ""
	ctx.flow.gate.press(-1)
	await _wait(0.1)
	_check(not paused and scene.run.map_index == 1, "debug kapısı da kapanır")
	ctx.flow.enter_menu()

	print("== 5) LANETLİ GÜÇ kapısı → C3 lanetli kartı (bedel/ödül önceden, tek uygulama, çift ödül yok) ==")
	await _start("standard", false, 5)
	_check(await _kill_boss(), "boss bitirildi")
	_check(await _until(func(): return ctx.menus.current == "gate"), "kapı açıldı")
	# Seçenekler rastgele: lanetli seçeneği garanti etmek için açık kapıyı yeniden sun (oyuncu yolu aynı).
	scene.run.gate_options.assign(["repair", "cursed", "overload"])
	scene.run.gate_cards.clear()
	ctx.flow.on_gate_opened(Array(scene.run.gate_options))
	await _wait(0.4)
	var curse_id := str(scene.run.gate_cards.get("cursed", ""))
	var GD: Node = root.get_node("GameData")
	var curse_card: Dictionary = GD.card_by_id(curse_id)
	_check(str(curse_card.get("tier", "")) == "cursed", "lanetli seçeneğe gerçek lanetli kart atandı: " + curse_id)
	var gcard = ctx.flow.gate._cards[1]
	var bad_lines := 0
	for line in gcard.lines:
		if not bool(line[1]):
			bad_lines += 1
	var info := Loadout.curse_info(curse_card)
	_check(gcard.title == scene.tr(str(curse_card.get("name", ""))) and bad_lines >= 1, "kartta lanetin adı ve bedeli görünür (%s)" % gcard.title)
	var reward_line := false
	for line in gcard.lines:
		reward_line = reward_line or str(line[0]).find(str(int(round((float(info["reward_mult"]) - 1.0) * 100.0)))) >= 0
	_check(reward_line, "kartta lanetin kendi ödülü görünür (×%.2f)" % float(info["reward_mult"]))
	var core_before: float = scene.loadout.m("core_mult")
	var rm_before: float = scene.run.reward_mult
	var picked := [0]
	var pick_cb := func(c: Dictionary): picked[0] += 1 if str(c.get("id", "")) == curse_id else 0
	ctx.events.card_picked.connect(pick_cb)
	ctx.flow.gate.press(1)
	ctx.flow.gate.press(1)   # çift dokunuş
	await _wait(0.2)
	ctx.events.card_picked.disconnect(pick_cb)
	_check(Array(scene.loadout.curses) == [curse_id] and scene.loadout.count(curse_id) == 1, "lanet tam bir kez uygulandı")
	_check(picked[0] == 1, "lanet sinyali (LANET afişi) bir kez")
	_check(absf(scene.run.reward_mult - rm_before) < 0.001, "kapının kendi +%15'i eklenmedi")
	_check(absf(scene.loadout.m("core_mult") - core_before * float(info["reward_mult"])) < 0.001, "ödül yalnız kartın reward_mult'u (core_mult ×%.2f)" % float(info["reward_mult"]))
	_check(absf(scene.player.max_hp - (float(GD.number("player.max_health", 100.0)) + scene.loadout.m("max_hp_bonus"))) < 0.01, "gemi istatistikleri yenilendi (azami can %.0f)" % scene.player.max_hp)
	_check(scene.state == "playing" and not paused, "kapıdan sonra oyun sürer")
	ctx.flow.enter_menu()

	FX.set_base_scale(1.0)
	print("RUN PROBE: %d kontrol" % _checks)
	print("SONUÇ: %s" % ("geçti" if _fail == 0 else "%d hata" % _fail))
	quit(0 if _fail == 0 else 1)
