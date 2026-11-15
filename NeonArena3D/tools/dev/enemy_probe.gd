extends SceneTree
## C2 düşman probu: GERÇEK sahnede (scenes/main.tscn) her yeni türü ve her elit ön ekini doğurup davranışını doğrular:
## uyarı (telegraf) süresi, hasarın yalnız bildirilen alanda/zamanda verilmesi, ölüm etkisi, düğümün ölümden sonra serbest kalması.
##
##   godot --headless --path . -s res://tools/dev/enemy_probe.gd -- --no-save
##
## Kare kare elle sürülür (sahnenin _process'i kapatılır): oyun adımının düşman/tehlike/çarpışma bölümü aynen çağrılır
## (Spawner.tick_enemies → BossEvents.tick_hazards → BulletField.tick → ayrılma → CombatSystem.resolve_collisions).
## NOT: düşmanlar havuzlanmaz (doğrudan oluştur/serbest bırak); "havuza dönüş" = listeden çıkma + düğümün serbest kalması +
## kalıcı nesne bırakmamasıdır. Kayıt dosyasına dokunmaz (--no-save).

var EnemyScript   # çalışma anında yüklenir: otoyükler (GameData) derleme anında yok
const DT := 0.05

var _fail := 0
var scene
var ctx
var sp
var player
var gdata

func _check(cond: bool, msg: String) -> void:
	print(("  ✓ " if cond else "  ✗ ") + msg)
	if not cond:
		_fail += 1

func _initialize() -> void:
	_run.call_deferred()

func _arena_center() -> Vector2:
	return Vector2(1320.0, 840.0)

func _clear() -> void:
	for e in ctx.enemies:
		if is_instance_valid(e):
			e.free()
	ctx.enemies.clear()
	for p in ctx.pickups:
		if is_instance_valid(p):
			p.free()
	ctx.pickups.clear()
	ctx.hazards.clear()
	ctx.field.clear_all()
	ctx.run.pending.clear()
	ctx.run.alive = 0
	player.pos2 = _arena_center()
	player.invuln = 0.0
	player.shield = 0
	player.max_hp = 100000.0
	player.hp = 100000.0
	player.velocity2 = Vector2.ZERO

func _step(dt := DT) -> void:
	sp.tick_enemies(dt)
	ctx.bosses.tick_hazards(dt)
	ctx.field.tick(dt)
	sp.separate_enemies()
	ctx.combat.resolve_collisions()

func _spawn(kind: String, at: Vector2, prefix := ""):
	var stats: Dictionary = gdata.enemy_stats(kind)
	stats["spawn_delay"] = 0.0
	var elite_def: Dictionary = {} if prefix == "" else EnemyData.merged_elite(gdata.elite_def(), prefix)
	var e = EnemyScript.new()
	e.setup(kind, stats, 1.0, 1.0, 1.0, elite_def)
	e.pos2 = at
	e.position = ArenaSpace.to_world(at, 0.3)
	ctx.entities.add_child(e)
	ctx.enemies.append(e)
	ctx.run.alive += 1
	return e

func _hp_loss_by_contact(e) -> float:
	## Oyuncuyu düşmanın üstüne koy, çarpışmayı çöz; kaybedilen can.
	var before: float = player.hp
	var keep: Vector2 = player.pos2
	player.pos2 = e.pos2
	player.invuln = 0.0
	player.shield = 0
	ctx.combat.resolve_collisions()
	var lost: float = before - player.hp
	player.hp = before
	player.invuln = 0.0
	player.pos2 = keep
	return lost

func _until(e, cond: Callable, max_s := 30.0) -> float:
	## cond doğru olana dek adım at; geçen süre (bulunamazsa -1).
	var t := 0.0
	while t < max_s:
		if cond.call():
			return t
		_step()
		t += DT
	return -1.0

func _kill_and_collect(e) -> bool:
	## Öldür → tick_enemies biçsin → düğüm serbest kalsın. true = temiz çıkış.
	e.take_damage(1.0e7, Vector2.ZERO)
	var before: int = ctx.enemies.size()
	_step()
	await process_frame
	return not ctx.enemies.has(e) and not is_instance_valid(e) and ctx.enemies.size() <= before - 1

func _run() -> void:
	EnemyScript = load("res://scripts/entities3d/enemy3d.gd")
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for i in 3:
		await process_frame
	scene._start_game()
	await process_frame
	scene.set_process(false)
	seed(7)   # belirlenimli: _start_game küresel rastgele akışı yeniden tohumladı; aynı çıktı her koşuda
	ctx = scene.ctx
	sp = ctx.spawner
	player = ctx.player
	player.shield = 0
	var gd = root.get_node("GameData")
	gdata = gd
	print("== C2 düşman probu ==")
	_check(gd.errors.is_empty(), "veri doğrulaması temiz (%d hata)" % gd.errors.size())

	await _test_charger(gd)
	await _test_shielder(gd)
	await _test_medic(gd)
	await _test_minelayer(gd)
	await _test_blinker(gd)
	await _test_brooder(gd)
	await _test_prefixes(gd)
	await _test_scheduling(gd)

	print("SONUÇ: %s" % ("geçti" if _fail == 0 else "%d hata" % _fail))
	scene.queue_free()
	quit(0 if _fail == 0 else 1)

# --- Hücumcu -----------------------------------------------------------------------------------
func _test_charger(gd) -> void:
	print("-- hücumcu (charger)")
	_clear()
	var st: Dictionary = gd.enemy_stats("charger")
	var e = _spawn("charger", Vector2(1000, 840))
	e.cool = 0.0
	var seen := {}
	var windup_t := 0.0
	var dash_t := 0.0
	var dash_from := Vector2.ZERO
	var dash_len := 0.0
	var contact := {}
	var tele_ok := true
	seen[EnemyScript.CH_APPROACH] = true
	contact[EnemyScript.CH_APPROACH] = _hp_loss_by_contact(e)   # yaklaşırken (ilk karede) temas
	for i in 400:
		var s_before: int = e.state
		_step()
		var s: int = e.state
		if s == EnemyScript.CH_WINDUP:
			windup_t += DT
			tele_ok = tele_ok and e.tele.visible
		elif e.tele.visible:
			tele_ok = false
		if s == EnemyScript.CH_DASH:
			if s_before != EnemyScript.CH_DASH:
				dash_from = e.pos2
			dash_t += DT
			dash_len = e.pos2.distance_to(dash_from)
		if not seen.has(s):
			seen[s] = true
			contact[s] = _hp_loss_by_contact(e)
		if s == EnemyScript.CH_APPROACH and seen.size() == 4 and windup_t > 0.0 and dash_t > 0.0 and i > 20 and s_before == EnemyScript.CH_RECOVER:
			break
		# oyuncu hareketsiz kalır: hücum çizgisi oyuncuya kilitlidir
	_check(seen.size() == 4, "4 durumun hepsi görüldü (yaklaş/uyarı/atılma/yorgunluk)")
	_check(windup_t >= 0.6, "uyarı süresi >= 0,6 sn (ölçülen %.2f, veri %.2f)" % [windup_t, float(st["windup"])])
	_check(absf(windup_t - float(st["windup"])) <= DT * 2.0, "uyarı süresi veriyle aynı")
	_check(tele_ok, "uyarı çizgisi yalnız uyarı sırasında görünür")
	var want_len := float(st["dash_speed"]) * float(st["dash_time"])
	_check(absf(dash_len - want_len) <= want_len * 0.15, "atılma mesafesi ~%.0f px (ölçülen %.0f)" % [want_len, dash_len])
	_check(float(contact.get(EnemyScript.CH_WINDUP, -1.0)) == 0.0, "uyarı sırasında temas hasarı YOK")
	_check(float(contact.get(EnemyScript.CH_RECOVER, -1.0)) == 0.0, "yorgunlukta temas hasarı YOK")
	var dash_dmg: float = contact.get(EnemyScript.CH_DASH, 0.0)
	_check(absf(dash_dmg - float(st["damage"]) * float(st["dash_damage_mult"])) < 0.5, "atılma hasarı = hasar × çarpan (%.1f)" % dash_dmg)
	_check(float(contact.get(EnemyScript.CH_APPROACH, 0.0)) > 0.0 and float(contact.get(EnemyScript.CH_APPROACH, 0.0)) < dash_dmg, "yaklaşırken zayıf temas hasarı, atılma daha güçlü")
	# Yorgunlukta açık hedef: ×1,5 hasar
	e.state = EnemyScript.CH_RECOVER
	var hp0: float = e.hp
	e.take_damage(10.0, Vector2.ZERO)
	_check(absf((hp0 - e.hp) - 10.0 * float(st["recover_taken_mult"])) < 0.01, "yorgun hücumcu ×%.1f hasar alır" % float(st["recover_taken_mult"]))
	_check(await _kill_and_collect(e), "ölüm: listeden çıktı, düğüm serbest kaldı")
	_check(ctx.hazards.is_empty(), "hücumcu kalıcı tehlike bırakmaz")

# --- Kalkancı ----------------------------------------------------------------------------------
func _test_shielder(gd) -> void:
	print("-- kalkancı (shielder)")
	_clear()
	var st: Dictionary = gd.enemy_stats("shielder")
	var e = _spawn("shielder", Vector2(1000, 840))
	e.max_hp = 5000.0
	e.hp = 5000.0
	_step()
	_check(e.shield_angle > -0.2 and e.shield_angle < 0.2, "kalkan oyuncuya dönük")
	var base := 12.0
	var hp0: float = e.hp
	e.take_damage(base, Vector2(-1, 0) * 100.0)   # önden gelen mermi (itme = merminin gidiş yönü)
	var front_loss: float = hp0 - e.hp
	hp0 = e.hp
	e.take_damage(base, Vector2(1, 0) * 100.0)    # arkadan
	var back_loss: float = hp0 - e.hp
	hp0 = e.hp
	e.take_damage(base, Vector2(0, -1) * 100.0)   # yandan
	var side_loss: float = hp0 - e.hp
	hp0 = e.hp
	e.take_damage(base, Vector2.ZERO)              # zincir şimşeği (itme yok)
	var chain_loss: float = hp0 - e.hp
	hp0 = e.hp
	e.take_damage(float(st["shield_pierce_damage"]) + 5.0, Vector2(-1, 0) * 100.0)
	var heavy_loss: float = hp0 - e.hp
	_check(absf(front_loss - base * float(st["shield_block"])) < 0.01, "önden vuruş %%%d'e düşer (%.2f)" % [int(float(st["shield_block"]) * 100.0), front_loss])
	_check(absf(back_loss - base) < 0.01 and absf(side_loss - base) < 0.01, "arka ve yan vuruş tam hasar")
	_check(absf(chain_loss - base) < 0.01, "zincir şimşeği (itmesiz) kalkanı atlar")
	_check(heavy_loss >= float(st["shield_pierce_damage"]), "ağır vuruş (nova/ray) kalkanı deler")
	# Kalkan yavaş döner: oyuncu arkaya geçince hemen çevrilemez, sonra döner.
	player.pos2 = Vector2(700, 840)   # düşmanın solu (kalkanın tersi)
	var a0: float = e.shield_angle
	for i in 5:
		_step()   # 0,25 sn
	var turned := absf(wrapf(e.shield_angle - a0, -PI, PI))
	_check(turned <= float(st["shield_turn"]) * 0.25 + 0.05, "kalkan dönüş hızı sınırlı (%.2f rad / 0,25 sn)" % turned)
	for i in 4:
		_step()   # toplam 0,45 sn: kalkan yarım turdan azını döndü
	var flank := absf(wrapf(e.shield_angle - a0, -PI, PI)) < PI * 0.5
	_check(flank, "yana/arkaya geçen oyuncu, kalkan dönene dek vurabilir (0,45 sn sonra sapma %.2f rad)" % absf(wrapf(e.shield_angle - a0, -PI, PI)))
	# Gerçek mermiyle uçtan uca: önden vuran mermi az hasar verir
	_clear()
	e = _spawn("shielder", Vector2(1000, 840))
	_step()
	ctx.hud._floaters.clear()
	var b = ctx.field.spawn(Vector2(1200, 840), Vector2(-1, 0), 900.0, true, base, 1.0, 1.0, false)
	for i in 30:
		_step()
		if b.dead:
			break
	_check(e.blocked_hits >= 1 and (e.max_hp - e.hp) < base * 0.5, "gerçek mermi önden: engellendi (kaybedilen %.2f)" % (e.max_hp - e.hp))
	# Entegrasyon: hasar sayısı GERÇEK hasarı gösterir (12 değil ~1) + küçük "ENGEL" işareti.
	var texts: Array = []
	for f in ctx.hud._floaters:
		texts.append(str(f["t"]))
	var real := str(maxi(1, int(round(e.max_hp - e.hp))))
	_check(texts.has(real) and not texts.has(str(int(base))), "engellenen vuruşta sayı gerçek hasar (%s), tam hasar (%d) değil · %s" % [real, int(base), str(texts)])
	_check(texts.has(ctx.hud.tr("ENGEL")), "engellenen vuruşta ENGEL işareti")
	_check(await _kill_and_collect(e), "ölüm: düğüm serbest")

# --- Onarıcı -----------------------------------------------------------------------------------
func _test_medic(gd) -> void:
	print("-- onarıcı (medic)")
	_clear()
	var st: Dictionary = gd.enemy_stats("medic")
	# Yaralı müttefik yokken darbe başlamaz (şarj iptal edilir)
	var m = _spawn("medic", Vector2(1000, 600))
	m.cool = 0.0
	var started := false
	for i in 40:
		_step()
		if m.state == EnemyScript.MD_CHARGE:
			started = true
	_check(not started, "yaralı müttefik yokken şarj kalıcı başlamaz")
	# Yaralı müttefik + menzil dışı müttefik
	m.speed_value = 0.0   # ölçüm sabit konumda: menzil dışına çıkma etkisi yok
	m.pos2 = Vector2(1000, 600)
	m.velocity2 = Vector2.ZERO
	var ally = _spawn("tank", Vector2(1000, 720))
	ally.speed_value = 0.0
	ally.hp = ally.max_hp * 0.5
	var far = _spawn("tank", Vector2(2300, 1500))
	far.hp = far.max_hp * 0.5
	m.cool = 0.0
	var t_charge := 0.0
	var healed_at := -1.0
	var ally0: float = ally.hp
	var t := 0.0
	var charging := false
	for i in 120:
		_step()
		t += DT
		if m.state == EnemyScript.MD_CHARGE:
			charging = true
			t_charge += DT
		if ally.hp > ally0 and healed_at < 0.0:
			healed_at = t
			break
	_check(charging, "yaralı müttefik varken şarj (uyarı halkası) başladı")
	_check(t_charge >= 0.6, "iyileştirme uyarısı >= 0,6 sn (ölçülen %.2f)" % t_charge)
	var gain: float = ally.hp - ally0
	_check(absf(gain - ally.max_hp * float(st["heal_frac"])) < 0.5, "müttefik canı maks canın %%%d'i kadar arttı (%.1f)" % [int(float(st["heal_frac"]) * 100.0), gain])
	_check(is_equal_approx(far.hp, far.max_hp * 0.5), "menzil dışı müttefik iyileşmedi")
	_check(m.hp == m.max_hp, "onarıcı kendini iyileştirmez / hasar almadı")
	_check(m.damage_value <= 8.0, "onarıcı zayıf vurur (temas %.0f)" % m.damage_value)
	_check(await _kill_and_collect(m), "ölüm: düğüm serbest (müttefikler yaşıyor)")
	_check(ctx.enemies.size() == 2, "onarıcının ölümü diğerlerini etkilemez")

# --- Mayıncı -----------------------------------------------------------------------------------
func _test_minelayer(gd) -> void:
	print("-- mayıncı (minelayer)")
	_clear()
	var st: Dictionary = gd.enemy_stats("minelayer")
	var e = _spawn("minelayer", Vector2(1000, 840))
	e.cool = 0.0
	var t := _until(e, func(): return ctx.hazards.size() >= int(st["mine_count"]), 5.0)
	_check(t >= 0.0, "mayın bırakıldı (%d bölge)" % ctx.hazards.size())
	var delay_ok := true
	for h in ctx.hazards:
		delay_ok = delay_ok and float(h["max"]) >= 0.6 and absf(float(h["max"]) - float(st["mine_delay"])) < 0.01 and absf(float(h["radius"]) - float(st["mine_radius"])) < 0.01
	_check(delay_ok, "her mayın uyarısı >= 0,6 sn (%.2f) ve yarıçap veriyle aynı" % float(st["mine_delay"]))
	# Hasar yalnız süre dolunca ve yarıçap içinde.
	var z: Dictionary = ctx.hazards[0]
	var at: Vector2 = z["pos2"]
	ctx.hazards.clear()
	ctx.hazards.append(z)   # yalnız bu bölgeyi sına (öteki mayın yakınsa sonucu bozmasın)
	e.cool = 999.0
	e.speed_value = 0.0
	player.pos2 = at
	player.invuln = 0.0
	var hp0: float = player.hp
	var elapsed := 0.0
	while elapsed < float(z["max"]) - 0.12:
		ctx.bosses.tick_hazards(DT)
		elapsed += DT
	_check(player.hp == hp0, "süre dolmadan (%.2f/%.2f) içinde durmak hasar vermez" % [elapsed, float(z["max"])])
	# oyuncu çıkar → hasar yok
	player.pos2 = at + Vector2(float(z["radius"]) + 60.0, 0.0)
	for i in 6:
		ctx.bosses.tick_hazards(DT)
	_check(player.hp == hp0, "bölge dışındaki oyuncu hasar almaz")
	ctx.hazards.clear()
	# içinde kalan oyuncu: patlamada hasar
	add_zone_for_probe(at, float(st["mine_radius"]), float(st["mine_delay"]), e.damage_value)
	player.pos2 = at
	player.invuln = 0.0
	for i in 30:
		ctx.bosses.tick_hazards(DT)
	_check(absf((hp0 - player.hp) - e.damage_value) < 0.01, "patlama içindeki oyuncuya tam %.0f hasar" % e.damage_value)
	_check(ctx.hazards.is_empty(), "patlayan bölge listeden çıktı")
	_check(await _kill_and_collect(e), "ölüm: düğüm serbest")

func add_zone_for_probe(at: Vector2, radius: float, delay: float, dmg: float) -> void:
	sp.add_zone(at, radius, delay, dmg, Color(1, 0.3, 0.8))

# --- Sıçrayıcı ---------------------------------------------------------------------------------
func _test_blinker(gd) -> void:
	print("-- sıçrayıcı (blinker)")
	_clear()
	var st: Dictionary = gd.enemy_stats("blinker")
	var e = _spawn("blinker", Vector2(500, 500))
	e.cool = 0.0
	var fade_t := 0.0
	var moved_in_fade := false
	var pos_fade: Vector2 = e.pos2
	var landed := false
	for i in 120:
		_step()
		if e.state == EnemyScript.BL_FADE:
			if fade_t == 0.0:
				pos_fade = e.pos2
			fade_t += DT
			moved_in_fade = moved_in_fade or e.pos2.distance_to(pos_fade) > 1.0
		if e.state == EnemyScript.BL_STRIKE:
			landed = true
			break
	_check(fade_t >= 0.6, "kaybolma uyarısı >= 0,6 sn (ölçülen %.2f)" % fade_t)
	_check(not moved_in_fade, "kaybolurken yerinde durur")
	_check(landed, "oyuncunun yanına indi")
	var d: float = e.pos2.distance_to(player.pos2)
	_check(absf(d - float(st["land_dist"])) < 5.0, "iniş oyuncudan %.0f px (veri %.0f)" % [d, float(st["land_dist"])])
	_check(ctx.hazards.size() == 1, "iniş yerinde tek vuruş bölgesi")
	var z: Dictionary = ctx.hazards[0]
	_check(float(z["max"]) >= 0.6 and absf(float(z["max"]) - float(st["strike_delay"])) < 0.01, "vuruş uyarısı >= 0,6 sn (%.2f)" % float(z["max"]))
	_check((z["pos2"] as Vector2).distance_to(e.pos2) < 1.0 and absf(float(z["radius"]) - float(st["strike_radius"])) < 0.01, "bölge iniş noktasında, yarıçap veriyle aynı")
	_check(_hp_loss_by_contact(e) == 0.0, "iniş/vuruş beklerken temas hasarı yok")
	# Uyarı dolmadan hasar yok; dışarı çıkan kurtulur
	var hp0: float = player.hp
	player.pos2 = e.pos2 + Vector2(float(st["strike_radius"]) + 50.0, 0.0)
	for i in 25:
		ctx.bosses.tick_hazards(DT)
	_check(player.hp == hp0, "halkadan çıkan oyuncu hasar almaz")
	_check(await _kill_and_collect(e), "ölüm: düğüm serbest")

# --- Kuluçka -----------------------------------------------------------------------------------
func _test_brooder(gd) -> void:
	print("-- kuluçka (brooder)")
	_clear()
	var st: Dictionary = gd.enemy_stats("brooder")
	var e = _spawn("brooder", Vector2(1000, 600))
	e.cool = 0.0
	var alive0: int = ctx.run.alive
	var swell_t := 0.0
	var first_hatch_at := -1.0
	var t := 0.0
	var count_before := 0
	for i in 1200:
		_step()
		t += DT
		if e.state == EnemyScript.BR_SWELL and first_hatch_at < 0.0:
			swell_t += DT
		if first_hatch_at < 0.0 and e.hatched >= 1:
			first_hatch_at = t
			count_before = ctx.enemies.size()
		# oyuncuya ulaşan yavruları temizle ki sınama sürüp gitsin
		for c in ctx.enemies:
			if c != e and c.kind == "swarmer":
				c.hp = c.max_hp
	_check(swell_t >= 0.6, "yavrulama uyarısı (şişme) >= 0,6 sn (ölçülen %.2f)" % swell_t)
	_check(count_before == 1 + int(st["hatch_count"]), "ilk yavrulamada %d yavru (liste %d)" % [int(st["hatch_count"]), count_before])
	_check(e.hatched == int(st["max_hatches"]), "en çok %d yavrulama (yapılan %d)" % [int(st["max_hatches"]), e.hatched])
	var kids := 0
	for c in ctx.enemies:
		if c.kind == "swarmer":
			kids += 1
	_check(kids == int(st["max_hatches"]) * int(st["hatch_count"]), "toplam yavru = %d" % kids)
	_check(ctx.run.alive == alive0 + kids, "RunState.alive yavrularla tutarlı (%d)" % ctx.run.alive)
	_check(await _kill_and_collect(e), "ölüm: düğüm serbest")

# --- Elit ön ekleri ----------------------------------------------------------------------------
func _test_prefixes(gd) -> void:
	print("-- elit ön ekleri")
	var def: Dictionary = gd.elite_def()
	var prefixes: Dictionary = def["prefixes"]
	_check(prefixes.size() == 4, "4 elit ön eki tanımlı")
	var base_pts := float(gd.enemy_stats("chaser")["points"])
	var elite_mult: float = def["points_mult"]
	# Zırhlı
	_clear()
	var p: Dictionary = prefixes["armored"]
	var e = _spawn("chaser", Vector2(900, 840), "armored")
	_check(e.elite and e.prefix == "armored" and e.halo != null, "zırhlı: işaret (halka) var")
	_check(absf(e.max_hp - 22.0 * float(p["hp_mult"])) < 0.01, "zırhlı: can ×%.1f" % float(p["hp_mult"]))
	var hp0: float = e.hp
	e.take_damage(10.0, Vector2.ZERO)
	_check(absf((hp0 - e.hp) - 10.0 * float(p["damage_taken_mult"])) < 0.01, "zırhlı: gelen hasar ×%.2f" % float(p["damage_taken_mult"]))
	_check(absf(float(e.points()) * elite_mult - base_pts * float(p["points_mult"])) <= elite_mult, "zırhlı: ödül puanı ×%.0f (Combat çarpanıyla)" % float(p["points_mult"]))
	_check(await _kill_and_collect(e), "zırhlı: ölüm temiz")
	# Çevik
	_clear()
	p = prefixes["swift"]
	e = _spawn("chaser", Vector2(900, 840), "swift")
	_check(absf(e.speed_value - 132.0 * float(p["speed_mult"])) < 0.01, "çevik: hız ×%.2f (%.0f)" % [float(p["speed_mult"]), e.speed_value])
	_check(e.halo != null and e.prefix_color.is_equal_approx(Color.from_string(str(p["color"]), Color.BLACK)), "çevik: ön ek renginde işaret")
	_check(await _kill_and_collect(e), "çevik: ölüm temiz")
	# Bölünen
	_clear()
	p = prefixes["splitting"]
	e = _spawn("chaser", Vector2(900, 700), "splitting")
	var alive0: int = ctx.run.alive
	e.take_damage(1.0e7, Vector2.ZERO)
	_step()
	await process_frame
	var kids: Array = ctx.enemies.duplicate()
	_check(kids.size() == int(p["split_count"]), "bölünen: ölünce %d parça" % int(p["split_count"]))
	var frac_ok := true
	var small_ok := true
	for k in kids:
		frac_ok = frac_ok and absf(k.max_hp - 22.0 * float(p["split_hp_frac"])) < 0.01
		small_ok = small_ok and not k.elite and k.from_split and k.radius < 15.0
	_check(frac_ok, "bölünen: parçalar maks canın %%%d'i" % int(float(p["split_hp_frac"]) * 100.0))
	_check(small_ok, "bölünen: parçalar elit değil, küçük, tekrar bölünmez")
	_check(ctx.run.alive == alive0 - 1 + kids.size(), "bölünen: RunState.alive tutarlı (%d)" % ctx.run.alive)
	for k in kids:
		k.spawn_delay = 0.0
		k.take_damage(1.0e7, Vector2.ZERO)
	_step()
	await process_frame
	_check(ctx.enemies.is_empty(), "bölünen: parçalar ölünce yeni parça çıkmaz")
	# Emici
	_clear()
	p = prefixes["vampiric"]
	e = _spawn("chaser", Vector2(900, 840), "vampiric")
	e.hp = e.max_hp * 0.4
	var hp_before: float = e.hp
	e.pos2 = player.pos2
	var lost := _hp_loss_by_contact(e)
	_step()   # düşman ticki: temas vuruşunu görür ve iyileşir
	_check(lost > 0.0, "emici: temasta oyuncuya hasar (%.1f)" % lost)
	_check(absf((e.hp - hp_before) - e.max_hp * float(p["lifesteal_frac"])) < 0.5, "emici: vuruşta maks canın %%%d'i kadar iyileşti (+%.1f)" % [int(float(p["lifesteal_frac"]) * 100.0), e.hp - hp_before])
	var pick0: int = ctx.pickups.size()
	e.pos2 = Vector2(400, 400)   # oyuncunun toplama alanından uzakta öldür
	e.take_damage(1.0e7, Vector2.ZERO)
	_step()
	await process_frame
	_check(ctx.pickups.size() - pick0 == 1 + int(p["bonus_pickups"]), "emici: ölünce garantili + %d ek ganimet (%d)" % [int(p["bonus_pickups"]), ctx.pickups.size() - pick0])
	_clear()
	# Uygunluk kuralları (saf)
	_check(EnemyData.pick_prefix(def, "swarmer", 20, 0.5) == "", "swarmer için ön ek yok")
	_check(EnemyData.pick_prefix(def, "chaser", 5, 0.99) in ["armored", "swift"], "erken dalgada yalnız zırhlı/çevik")

# --- Zamanlama kuralları ----------------------------------------------------------------------
func _test_scheduling(gd) -> void:
	print("-- zamanlama (sektör + üst sınır)")
	_clear()
	var en: Dictionary = gd.balance["enemies"]
	_check(EnemyData.resolve_kind(en, "minelayer", 0, {}) == str(en["minelayer"]["fallback"]), "mayıncı 0. sektörde yedeğe döner")
	_check(EnemyData.resolve_kind(en, "minelayer", 1, {}) == "minelayer", "mayıncı kızıl sektörde doğar")
	_check(EnemyData.resolve_kind(en, "medic", 0, {"medic": int(en["medic"]["max_alive"])}) == str(en["medic"]["fallback"]), "üst sınırda onarıcı yedeğe döner")
	# Spawner'ın gerçek yolu: iki onarıcı varken üçüncü istek yedek türü doğurur
	for k in 2:
		_spawn("medic", Vector2(1000 + k * 100, 500))
	var before: int = ctx.enemies.size()
	sp.on_spawn_due("medic")
	var last = ctx.enemies[ctx.enemies.size() - 1]
	_check(ctx.enemies.size() == before + 1 and last.kind == str(en["medic"]["fallback"]), "Spawner.on_spawn_due üst sınırı uygular (doğan: %s)" % last.kind)
	_clear()
