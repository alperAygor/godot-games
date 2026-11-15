extends GameModule
class_name RunFlow
## Durum makinesi: menü → oyun → (duraklat) → ölü → oyun sonu; koşu başlatma/sıfırlama, tohumlama, harita
## kurulumu ve sektör geçişi, dalga/harita olaylarının oyuncu tarafı, ölüm + İkinci Şans + ödül.
## Menü/duraklat/kart ekranları menus.gd'de (F3); burası yalnız onların sinyallerine bağlanır.
##
## C1 koşu yapısı: mod seçimi (ana menü girişi, `--mode=`), sektör hedefi (SectorHud), sektör kapısı (GateScreen) ve
## zafer (VictoryScreen) burada bağlanır. Mantık RunState'te (saf); ekranlar menus.gd'ye dokunmadan `menus.modules`'a
## kaydedilir ve dil değişiminde (`screens_rebuilt`) yeniden kurulur. Zaferle biten koşu da oyun sonu durumuna ("dead" =
## koşu bitti) geçer: ×2 çekirdek teklifi ve geçiş reklamı kuralları ölümle aynı yoldan çalışır (`outcome` farkı).

const MapBuilderScript = preload("res://scripts/world/map_builder.gd")
const GateScreen = preload("res://scripts/ui/screens/gate.gd")
const VictoryScreen = preload("res://scripts/ui/screens/victory.gd")
const SectorHudScript = preload("res://scripts/ui/sector_hud.gd")

var dead_timer := 0.0
var cores_earned := 0
var revives_used := 0
var _over_shown := false
var _record := false
var _hint_time := 0.0
## C1: koşu nasıl bitti: "" (sürüyor) | "death" | "victory" (zaferde SONUÇLAR). Reklam akışı `died` bayrağını buradan alır.
var outcome := ""
var gate: GateScreen
var victory: VictoryScreen
var sector_hud: SectorHud
var _wired := false
var _gate_cards: Dictionary = {}
var _mode_button: Button
var _mode_note: Label
var _result_label: Label

# --- Harita -----------------------------------------------------------------------
func build_map(index: int) -> void:
	var host := ctx.host
	if ctx.world != null and is_instance_valid(ctx.world):
		host.remove_child(ctx.world)
		ctx.world.queue_free()
	clear_entities()
	ctx.world = MapBuilderScript.new()
	host.add_child(ctx.world)
	ctx.world.build(index, GameData.map_theme(index))
	ctx.world.apply_quality(Settings.quality)
	ctx.obstacles = ctx.world.obstacles
	ctx.map_index = index

func clear_entities() -> void:
	for e in ctx.enemies:
		if is_instance_valid(e):
			e.queue_free()
	for p in ctx.pickups:
		if is_instance_valid(p):
			p.queue_free()
	if ctx.boss != null and is_instance_valid(ctx.boss):
		ctx.boss.queue_free()
	ctx.boss = null
	ctx.bosses.reset()
	ctx.control.forget_target()
	ctx.enemies.clear()
	ctx.pickups.clear()
	ctx.hazards.clear()
	ctx.aftershocks.clear()
	ctx.field.clear_all()
	ctx.sparks.clear_all()

func apply_quality() -> void:
	var q := Settings.quality
	var vp := ctx.host.get_viewport()
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][q]
	var mobile := OS.has_feature("mobile")
	vp.scaling_3d_scale = [0.67, 0.82, 1.0][q] if mobile else [0.75, 1.0, 1.0][q]
	ctx.sparks.budget = [0.5, 0.8, 1.0][q]
	if ctx.world != null and is_instance_valid(ctx.world):
		ctx.world.apply_quality(q)

# --- Akış: menü / oyun / duraklat ------------------------------------------------
func enter_menu() -> void:
	var player := ctx.player
	_wire()
	ctx.host.get_tree().paused = false
	Fx.reset()
	ctx.state = "menu"
	ctx.cards.reset()
	clear_entities()
	if ctx.world == null or ctx.world.theme_index != 0:
		build_map(0)
	ctx.loadout.reset()
	ctx.weapons.sync_drones()
	player.set_ship(Settings.meta.current_ship())
	player.max_hp = GameData.number("player.max_health", 100.0)
	player.reset(ARENA.get_center())
	ctx.hud.active = false
	ctx.hud.dimmed = false
	ctx.touch.set_enabled(false)
	ctx.camera.aim_marker.visible = false
	ctx.world.set_danger(false)
	ctx.menus.in_game = false
	ctx.menus.show_main()
	_refresh_mode_button()
	Sound.music("menu")
	Sound.set_muffled(false)
	if ctx.hooks != null:
		ctx.hooks.on_menu_shown()

func reseed() -> void:
	## Tohumlu koşuda (`--seed=N`) her başlangıç aynı rastgele akışla başlar: global randf (dövüş, efekt),
	## kart çekilişi ve RunState dalga planı. Tohum yoksa (oyuncu) hiçbir şey değişmez.
	var s := ctx.options.run_seed
	if s == 0:
		return
	seed(s)
	ctx.cards.rng.seed = s
	ctx.run.rng.seed = s

func start_game() -> void:
	var options := ctx.options
	var player := ctx.player
	var loadout := ctx.loadout
	var run := ctx.run
	_wire()
	reseed()
	ctx.host.get_tree().paused = false
	Fx.reset()
	ctx.host.get_viewport().gui_release_focus()
	ctx.menus.hide_all()
	ctx.menus.in_game = true
	if ctx.world == null or ctx.world.theme_index != options.debug_map:
		build_map(options.debug_map)
	else:
		clear_entities()
	ctx.map_index = options.debug_map
	ctx.world.set_danger(false)
	loadout.reset()
	loadout.apply_effects(Settings.meta.effects())
	var ship_def: Dictionary = Settings.meta.current_ship()
	if options.debug_ship != "" and not Settings.meta.ship_def(options.debug_ship).is_empty():
		ship_def = Settings.meta.ship_def(options.debug_ship)
	ctx.weapon = ship_def.get("weapon", {})
	loadout.apply_effects(ship_def.get("effect", {}))
	player.set_ship(ship_def)
	for id in options.debug_give:
		var card := GameData.card_by_id(str(id))
		if not card.is_empty():
			loadout.apply(card)
	ctx.weapons.sync_drones()
	player.autopilot = options.demo
	player.max_hp = GameData.number("player.max_health", 100.0)
	player.reset(ARENA.get_center())
	ctx.control.apply_loadout()
	if loadout.i("start_shield") > 0:
		player.shield = 1
	var nova_max := ctx.tuning.nova_max
	ctx.nova = nova_max if options.debug_nova else clampf(loadout.m("nova_start"), 0.0, nova_max)
	ctx.rerolls = ctx.tuning.run_base_rerolls + loadout.i("rerolls")
	cores_earned = 0
	ctx.combat.reset_run()
	revives_used = 0
	ctx.control.reset_run()
	ctx.feedback.reset_run()
	ctx.camera.reset_run()
	ctx.state = "playing"
	ctx.hud.active = true
	ctx.hud.dimmed = false
	ctx.hud.reset()
	ctx.touch.set_enabled(Settings.touch and not options.demo)
	ctx.elapsed = 0.0
	dead_timer = 0.0
	_over_shown = false
	outcome = ""
	_gate_cards.clear()
	ctx.cards.reset()
	Sound.set_muffled(false)
	Sound.music("battle")
	run.set_mode(current_mode())
	run.begin()
	run.xp_mult = loadout.m("xp_mult")
	if options.start_wave > 1:
		run.jump_to(options.start_wave)
	if options.debug_hp > 0.0:
		player.hp = minf(options.debug_hp, player.max_hp)
	if options.show_cards_demo:
		run.add_xp(run.xp_next)
	if not Settings.tutorial_done and not options.demo:
		_hint_time = 9.0
		ctx.hud.hint = tr("SOL: HAREKET   ·   SAĞ: NİŞAN   ·   ATIL ile mermilerden kaç") if Settings.touch else tr("WASD hareket   ·   FARE nişan + ateş   ·   BOŞLUK atıl   ·   Q nova")
	if run.has_goal() and _hint_time <= 0.0:
		ctx.hud.show_banner(tr("HEDEF: %d SEKTÖR") % run.total_sectors(), tr("her sektör %d dalga · sonunda boss") % run.waves_per_sector(), 2.6, KIT.GOLD)
	if options.debug_screen == "gate" or options.debug_screen == "victory":
		_debug_screen.call_deferred(options.debug_screen)
	ctx.events.run_started.emit(str(ship_def.get("id", "")), options.run_seed)

func pause() -> void:
	if ctx.state != "playing" or ctx.host.get_tree().paused:
		return
	ctx.host.get_tree().paused = true
	Fx.settle_time()
	ctx.touch.release_all()
	ctx.hud.dimmed = true
	Sound.set_muffled(true)
	Sound.play("ui_click")
	ctx.menus.show_pause(ctx.run.wave, ctx.run.level, ctx.run.score, ctx.loadout.summary())

func resume() -> void:
	if ctx.cards.is_open:
		return
	ctx.menus.hide_all()
	ctx.hud.dimmed = false
	ctx.host.get_tree().paused = false
	Fx.settle_time()
	Sound.set_muffled(false)

# --- Kare adımları ----------------------------------------------------------------
func tick_debug_die() -> void:
	## `--die=T`: T saniye sonra oyuncuyu öldür (ölüm/ödül akışı testleri).
	var player := ctx.player
	var options := ctx.options
	if options.debug_die > 0.0 and ctx.elapsed > options.debug_die and player.alive:
		options.debug_die = 0.0
		player.invuln = 0.0
		player.shield = 0
		player.take_damage(99999.0, player.pos2 + Vector2.UP)

func tick_hint(delta: float) -> void:
	if _hint_time > 0.0:
		_hint_time -= delta
		if _hint_time <= 0.0:
			ctx.hud.hint = ""
			Settings.tutorial_done = true
			Settings.save()

func tick_dead(delta: float) -> void:
	dead_timer += delta
	ctx.spawner.tick_effects_only(delta)
	if dead_timer > 1.5 and not _over_shown:
		_over_shown = true
		ctx.hud.active = false
		_show_results()

func _show_results() -> void:
	ctx.menus.show_gameover(_summary(), ctx.loadout.summary())
	var run := ctx.run
	ctx.menus.gameover.set_title(tr("ZAFER") if run.won else tr("OYUN BİTTİ"), KIT.GOLD if run.won else KIT.RED)
	_fill_result_label()

func _summary() -> Dictionary:
	var run := ctx.run
	return {
		"score": run.score, "best": Settings.best, "record": _record, "wave": run.wave,
		"level": run.level, "kills": run.kills, "combo": run.max_combo, "time": run.time,
		"cores": cores_earned, "total_cores": Settings.meta.cores,
		"mode": run.mode, "won": run.won, "outcome": outcome, "sectors": run.sectors_cleared,
		"sectors_total": run.total_sectors(), "gates": Array(run.gates_taken), "reward": run.reward(ctx.loadout.m("core_mult")),
	}

# --- Ölüm -------------------------------------------------------------------------
func on_player_died() -> void:
	var revive_card: bool = ctx.loadout.i("revive") > revives_used
	ctx.events.player_died.emit(revive_card)
	if revive_card:
		revives_used += 1
		revive("card")
		return
	# SEAM(ads: revive): kart diriltmesi yoksa reklamla diriltme teklifi (MonetizationHooks): oyun duraklar, ölüm
	# sekansı BEKLER. Ödül gelirse hooks `revive("ad")` çağırır; vazgeçilir/başarısız olursa `finish_death()` çalışır.
	if ctx.hooks != null and ctx.hooks.offer_revive():
		return
	finish_death()

func finish_death() -> void:
	## Ölümün asıl akışı: durum "dead", ödül hesabı + kayıt, ölüm efektleri, koşu sonu olayı.
	var player := ctx.player
	var run := ctx.run
	ctx.state = "dead"
	player.visible = false
	ctx.camera.aim_marker.visible = false
	ctx.touch.set_enabled(false)
	ctx.hud.hint = ""
	run.end_run()
	outcome = "death"
	_settle_reward()
	Sound.play("game_over")
	Sound.play("explode_big", 0.0, 0.9)
	Sound.set_muffled(true, 0.8)
	ctx.world.set_danger(false)
	Fx.shake(22.0)
	Fx.vibrate(250)
	ctx.feedback.hurt_fx = 1.0
	Fx.slow_motion(0.3, 0.9)   # tek hız sahibi: araya giren vuruş donması bayat 0.3 bırakamaz
	var sparks := ctx.sparks
	sparks.burst(player.position, Color(0.6, 0.95, 1.0), 70, 15.0, 1.3, 1.7)
	sparks.burst(player.position, Color(1.0, 0.85, 0.5), 30, 10.0, 0.9, 1.3)
	sparks.ring(player.position, Color(0.6, 0.95, 1.0), 0.5, 11.0, 0.8, 0.14, 1.0)
	sparks.flash(player.position, Color(0.6, 0.9, 1.0), 12.0, 16.0, 0.5)
	# SEAM(ads: interstitial): koşu sonu; geçiş reklamı oyun sonu ekranındaki TEKRAR OYNA / ANA MENÜ basışında
	# (MonetizationHooks.on_restart / on_menu) gösterilir, burada değil. run_ended dinleyicileri düğmeleri hazırlar.
	ctx.events.run_ended.emit(_summary())

func _settle_reward() -> void:
	## Koşu sonu (ölüm ya da zafer): ödül eğrisi (RunState.reward, veri: waves.json run.modes.<mod>.reward), mod rekoru, kayıt.
	var run := ctx.run
	cores_earned = run.reward_total(ctx.loadout.m("core_mult"))
	RunRecords.record(Settings.flags, run.mode, {"score": run.score, "wave": run.wave, "won": run.won, "time": run.victory_time if run.won else run.time})
	_record = Settings.record_run(run.score, run.wave, run.kills, cores_earned)
	# SEAM(ads: double cores): ödül hesaplandı ve kayda işlendi; ek çekirdek Settings.meta üzerinden verilir.
	ctx.events.reward_computed.emit(cores_earned)

func revive(source: String) -> void:
	## Yarı canla geri dön + çevreyi temizleyen patlama. Kart (İkinci Şans) bunu kullanır; reklam akışı da
	## (C8) aynı yolu çağırmalı ki iki diriltme aynı hissettirsin.
	var t := ctx.tuning
	var player := ctx.player
	player.alive = true
	player.hp = player.max_hp * t.revive_hp_ratio
	player.invuln = t.revive_invuln
	ctx.combat.blast(t.revive_blast_radius, t.revive_blast_damage * ctx.loadout.m("damage_mult") * (1.0 + t.nova_wave_scale * float(ctx.run.wave - 1)), KIT.GOLD)
	Sound.play("revive")
	ctx.hud.show_banner(tr("İKİNCİ ŞANS"), tr("yarı canla geri döndün"), 1.8, KIT.GOLD)
	ctx.events.player_revived.emit(source)

# --- Dalga / harita olayları --------------------------------------------------------
func on_wave_cleared(wave: int) -> void:
	ctx.combat.heal(ctx.tuning.run_wave_clear_heal)
	ctx.hud.toast(tr("DALGA %02d TEMİZ   +%d") % [wave, int(GameData.number("waves.clear_bonus", 60)) * wave], KIT.GREEN, 1.8)
	Sound.play("wave_clear")

func on_map_cleared(_index: int) -> void:
	ctx.combat.heal(ctx.player.max_hp * ctx.tuning.run_map_clear_heal)
	var run := ctx.run
	if run.has_goal():
		var last := run.sectors_cleared >= run.total_sectors()
		ctx.hud.show_banner(tr("SEKTÖR %d/%d TEMİZ") % [run.sectors_cleared, run.total_sectors()],
			tr("son boss yenildi") if last else (tr("sektör kapısı açılıyor") if run.gates_enabled() else tr("yeni bölgeye geçiliyor")), 2.6, KIT.GOLD)
	else:
		ctx.hud.show_banner(tr("SEKTÖR TEMİZLENDİ"), tr("yeni bölgeye geçiliyor"), 2.6, KIT.GOLD)
	ctx.events.sector_cleared.emit(run.sectors_cleared - 1, run.sectors_cleared)
	Sound.play("wave_clear", 3.0, 0.8)

func on_map_changed(index: int) -> void:
	build_map(index)
	var player := ctx.player
	var world := ctx.world
	player.reset(ARENA.get_center(), true)
	ctx.control.apply_loadout()
	ctx.camera.snap_to(player.pos2)
	var theme: Dictionary = GameData.map_theme(index)
	ctx.menus.flash(world.color_a.lerp(Color(1, 1, 1), 0.5), 0.9, 0.9)
	ctx.hud.show_banner(tr(str(theme.get("name", "YENİ SEKTÖR"))), tr("sektör %d  ·  seviye %d") % [index + 1, ctx.run.level], 2.4, world.color_a.lerp(Color(1, 1, 1), 0.2))
	ctx.sparks.ring(player.position, world.color_a, 0.5, 14.0, 0.9, 0.12, 1.0)
	Fx.shake(8.0)

# --- C1: kurulum (ekranlar, hedef göstergesi, mod seçici) ----------------------------------
func _wire() -> void:
	## İlk menü/koşuda bir kez: RunState sinyalleri, hedef göstergesi katmanı, ekran kaydı. game3d.gd'ye dokunmadan.
	if _wired:
		return
	_wired = true
	var run := ctx.run
	run.gate_opened.connect(on_gate_opened)
	run.gate_closed.connect(_on_gate_closed)
	run.victory_reached.connect(on_victory_reached)
	ctx.menus.screens_rebuilt.connect(_install_screens)
	var layer := CanvasLayer.new()
	layer.layer = 9   # HUD/menü katmanının (10) altında: kart/kapı/duraklat ekranları üstünü örter
	ctx.host.add_child(layer)
	sector_hud = SectorHudScript.new()
	sector_hud.ctx = ctx
	layer.add_child(sector_hud)
	_install_screens()

func _install_screens() -> void:
	## Kapı + zafer ekranlarını menü kayıt defterine ekler, ana menüye mod seçicisini, oyun sonuna sonuç satırını koyar.
	## Dil değişiminde (screens_rebuilt) tüm ekranlar yeni örnek olduğu için yeniden çağrılır.
	var menus := ctx.menus
	gate = GateScreen.new(menus)
	menus.modules["gate"] = gate
	gate.build()
	gate.chosen.connect(on_gate_chosen)
	victory = VictoryScreen.new(menus)
	menus.modules["victory"] = victory
	victory.build()
	victory.finish_pressed.connect(finish_victory)
	victory.continue_pressed.connect(continue_endless)
	menus.move_child(menus.fade, menus.get_child_count() - 1)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_mode_button = KIT.button(tr("MOD"), KIT.GOLD, Vector2(360, 54), 20)
	_mode_button.pressed.connect(cycle_mode)
	box.add_child(_mode_button)
	_mode_note = KIT.label("", 13, KIT.DIM)
	_mode_note.custom_minimum_size = Vector2(360, 0)
	_mode_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_mode_note)
	menus.main.add_entry(box, menus.main.column.get_children().find(menus.focus.get("main")) + 1)
	_result_label = KIT.label("", 17, KIT.GOLD, KIT.bold(), HORIZONTAL_ALIGNMENT_CENTER)
	_result_label.visible = false
	menus.gameover.add_reward_action(_result_label)
	_refresh_mode_button()

# --- C1: mod -----------------------------------------------------------------------------
func current_mode() -> String:
	## `--mode=` > oyuncunun seçimi (Settings.flags.run_mode) > veri varsayılanı (run.default_mode).
	var run := ctx.run
	if ctx.options.run_mode != "" and run.has_mode(ctx.options.run_mode):
		return ctx.options.run_mode
	var fallback := str(run.run_defs().get("default_mode", RunState.MODE_STANDARD))
	return RunRecords.selected_mode(Settings.flags, run.modes(), fallback)

func cycle_mode() -> void:
	RunRecords.select_mode(Settings.flags, RunRecords.next_mode(current_mode(), ctx.run.modes()))
	ctx.options.run_mode = ""
	Settings.save()
	Sound.play("ui_click")
	_refresh_mode_button()

func _refresh_mode_button() -> void:
	if _mode_button == null or not is_instance_valid(_mode_button):
		return
	var id := current_mode()
	var def: Dictionary = ctx.run.run_defs().get("modes", {}).get(id, {})
	_mode_button.text = tr("MOD: %s  ▸") % tr(str(def.get("name", id)))
	var rec := RunRecords.get_record(Settings.flags, id)
	var note := tr(str(def.get("desc", "")))
	if int(rec["runs"]) > 0:
		note += "\n" + (tr("zafer %d  ·  en iyi dalga %d  ·  rekor %s") % [int(rec["wins"]), int(rec["wave"]), KIT.fmt(int(rec["best"]))])
	_mode_note.text = note

func _fill_result_label() -> void:
	if _result_label == null or not is_instance_valid(_result_label):
		return
	var run := ctx.run
	var def: Dictionary = run.mode_def
	var name := tr(str(def.get("name", run.mode)))
	if run.total_sectors() <= 0:
		_result_label.text = tr("%s  ·  %d boss") % [name, run.bosses]
	elif run.won and run.continued:
		_result_label.text = tr("%s  ·  ZAFER + sonsuzda %d dalga") % [name, run.wave - run.victory_wave]
	else:
		_result_label.text = tr("%s  ·  SEKTÖR %d/%d") % [name, run.sectors_cleared, run.total_sectors()]
	_result_label.visible = true

# --- C1: sektör kapısı -------------------------------------------------------------------
func _resolve_gate(ids: Array) -> Array:
	## Kimlik → ekran seçeneği. C3 kancası: kapı tanımında `card_tier` varsa ve kart verisinde o katmandan kart varsa
	## (ör. "cursed"), o kart sunulur ve seçilince `loadout.apply(card)`; yoksa kapının kendi `effect`i kullanılır.
	var run := ctx.run
	var out: Array = []
	for id in ids:
		var def := run.gate_def(str(id))
		var card := {}
		if def.has("card_tier"):
			var pool: Array = []
			for c in GameData.cards:
				if str(c.get("tier", "")) == str(def["card_tier"]):
					pool.append(c)
			if not pool.is_empty():
				card = pool[run.gate_rng.randi() % pool.size()]
				_gate_cards[str(id)] = card
		out.append({
			"id": str(id), "name": tr(str(card.get("name", def.get("name", id)))), "risk": int(def.get("risk", 0)),
			"lines": GateScreen.describe(def, card),
		})
	return out

func on_gate_opened(ids: Array) -> void:
	var run := ctx.run
	var player := ctx.player
	_gate_cards.clear()
	var opts := _resolve_gate(ids)
	if ctx.options.demo and ctx.options.debug_screen != "gate":
		# Bot: canı düşükse güvenli, değilse en ödüllü seçenek (simülasyonla aynı kural: RunState.bot_gate_choice).
		on_gate_chosen.call_deferred(RunState.bot_gate_choice(ids, run.gate_defs(), player.hp / maxf(1.0, player.max_hp), "auto"))
		return
	_hold_for_screen()
	var next: Dictionary = GameData.map_theme(ctx.map_index + 1)
	gate.present(opts, {"cleared": run.sectors_cleared, "total": run.total_sectors(), "next_name": str(next.get("name", "")),
		"reward_mult": run.reward_mult, "banked": run.banked_cores})

func on_gate_chosen(id: String) -> void:
	var run := ctx.run
	if run.phase != RunState.PHASE_GATE:
		return
	if id != "" and not run.gate_options.has(id):
		id = ""
	_release_screen()
	run.choose_gate(id)
	ctx.events.gate_chosen.emit(id)

func _on_gate_closed(id: String) -> void:
	## Oyuncuya dönük kapı etkileri (harita değişmeden hemen önce).
	if id == "":
		ctx.hud.toast(tr("KAPI ATLANDI"), KIT.DIM, 1.4)
		return
	var def := ctx.run.gate_def(id)
	var player := ctx.player
	if float(def.get("heal_ratio", 0.0)) > 0.0:
		ctx.combat.heal(player.max_hp * float(def["heal_ratio"]))
	if int(def.get("rerolls", 0)) > 0:
		ctx.cards.grant_reroll(int(def["rerolls"]))
	if _gate_cards.has(id):
		ctx.loadout.apply(_gate_cards[id])
	elif def.has("effect"):
		ctx.loadout.apply_effects(def["effect"])
	ctx.control.apply_loadout()
	player.hp = clampf(maxf(player.hp, 1.0), 1.0, player.max_hp)
	var name := tr(str((_gate_cards.get(id, {}) as Dictionary).get("name", def.get("name", id))))
	ctx.hud.toast(name, KIT.GOLD, 1.8)

func _hold_for_screen() -> void:
	ctx.host.get_tree().paused = true
	Fx.settle_time()
	ctx.touch.release_all()
	ctx.hud.dimmed = true
	Sound.set_muffled(true)

func _release_screen() -> void:
	ctx.menus.hide_all()
	ctx.hud.dimmed = false
	ctx.host.get_tree().paused = false
	Fx.settle_time()
	Sound.set_muffled(false)

# --- C1: zafer ---------------------------------------------------------------------------
func on_victory_reached() -> void:
	var run := ctx.run
	Sound.play("synergy")
	ctx.events.run_won.emit(_summary())
	if ctx.options.demo and ctx.options.debug_screen != "victory":
		if ctx.options.after_victory == "continue":
			continue_endless.call_deferred()
		else:
			finish_victory.call_deferred()
		return
	_hold_for_screen()
	var r: Dictionary = run.mode_def.get("reward", {})
	victory.present({"sectors": run.total_sectors(), "score": run.score, "time": run.time, "wave": run.wave,
		"cores": run.reward_total(ctx.loadout.m("core_mult")), "can_continue": run.can_continue(), "extra_cap": int(r.get("extra_cap", 0))})

func continue_endless() -> void:
	var run := ctx.run
	if not run.can_continue():
		return
	_release_screen()
	run.continue_endless()
	ctx.hud.toast(tr("SONSUZ MOD — bosslar güçleniyor"), KIT.VIOLET, 2.4)

func finish_victory() -> void:
	## Zaferde SONUÇLAR: koşu biter (durum "dead" = koşu bitti; oyun sonu ekranı ZAFER başlığıyla, hemen).
	var run := ctx.run
	if run.phase != RunState.PHASE_VICTORY:
		return
	_release_screen()
	outcome = "victory"
	ctx.state = "dead"
	ctx.camera.aim_marker.visible = false
	ctx.touch.set_enabled(false)
	ctx.hud.hint = ""
	run.finish_victory()
	_settle_reward()
	ctx.world.set_danger(false)
	Sound.play("wave_clear", 3.0, 0.8)
	ctx.events.run_ended.emit(_summary())
	_over_shown = true
	ctx.hud.active = false
	_show_results()

func _debug_screen(which: String) -> void:
	## `--screen=gate|victory` (ekran görüntüsü / elle deneme): ilgili ekranı hemen açar.
	var run := ctx.run
	if not run.has_goal():
		return
	run.debug_end_sector(1 if which == "gate" else run.total_sectors())
