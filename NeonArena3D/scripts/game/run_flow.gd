extends GameModule
class_name RunFlow
## Durum makinesi: menü → oyun → (duraklat) → ölü → oyun sonu; koşu başlatma/sıfırlama, tohumlama, harita
## kurulumu ve sektör geçişi, dalga/harita olaylarının oyuncu tarafı, ölüm + İkinci Şans + ödül.
## Menü/duraklat/kart ekranları menus.gd'de (F3); burası yalnız onların sinyallerine bağlanır.

const MapBuilderScript = preload("res://scripts/world/map_builder.gd")

var dead_timer := 0.0
var cores_earned := 0
var revives_used := 0
var _over_shown := false
var _record := false
var _hint_time := 0.0

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
	ctx.cards.reset()
	Sound.set_muffled(false)
	Sound.music("battle")
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
		ctx.menus.show_gameover(_summary(), ctx.loadout.summary())

func _summary() -> Dictionary:
	var run := ctx.run
	return {
		"score": run.score, "best": Settings.best, "record": _record, "wave": run.wave,
		"level": run.level, "kills": run.kills, "combo": run.max_combo, "time": run.time,
		"cores": cores_earned, "total_cores": Settings.meta.cores,
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
	cores_earned = MetaProgress.run_reward(run.score, run.wave, run.bosses, ctx.loadout.m("core_mult"))
	_record = Settings.record_run(run.score, run.wave, run.kills, cores_earned)
	# SEAM(ads: double cores): ödül hesaplandı ve kayda işlendi; ek çekirdek Settings.meta üzerinden verilir.
	ctx.events.reward_computed.emit(cores_earned)
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
	ctx.hud.show_banner(tr("SEKTÖR TEMİZLENDİ"), tr("yeni bölgeye geçiliyor"), 2.6, KIT.GOLD)
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
