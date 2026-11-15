extends SceneTree
## Kart probu (gerçek sahne, başsız): 6 sinerjinin yanında HER kartın, evrimin ve lanetin oyundaki etkisini
## tetikleyip ölçer (etki gerçekten oluyor mu), her kartla kısa bir gerçek oyun adımı koşar (betik hatası yok mu),
## sonda düğüm/yetim düğüm sayısının büyümediğini doğrular (sızıntı yok). Kayıt dosyasına dokunmaz (--no-save).
##   godot --headless --path . -s res://tools/dev/synergy_probe.gd -- --no-save

var _fail := 0
var _checked := {}
var scene
var ctx

func _check(cond: bool, msg: String) -> void:
	print(("  ✓ " if cond else "  ✗ ") + msg)
	if not cond:
		_fail += 1

func _initialize() -> void:
	_run.call_deferred()

func _gd():
	return root.get_node("GameData")

func _give(ids: Array) -> void:
	for id in ids:
		var card: Dictionary = _gd().card_by_id(id)
		if str(card.get("tier", "")) == "cursed":
			scene.loadout.apply_curse(id)
		else:
			scene.loadout.apply(card)
	scene._apply_loadout()

func _recipe(id: String) -> Array:
	## Kartı tarifiyle (sinerji/evrim parçaları, iç içe) verilecek listeye açar.
	var card: Dictionary = _gd().card_by_id(id)
	var tier := str(card.get("tier", ""))
	if tier != "synergy" and tier != "evolution":
		return [id]
	var out: Array = []
	var need: Dictionary = Loadout.recipe_of(card)
	for piece in need:
		for k in int(need[piece]):
			out.append_array(_recipe(str(piece)) if k == 0 else [str(piece)])
	out.append(id)
	return out

func _enemy_at(at: Vector2, hp := 500.0, kind := "chaser"):
	scene._spawn_enemy(kind, at, 0.0, false)
	var e = scene.enemies[scene.enemies.size() - 1]
	e.spawn_delay = 0.0
	e.max_hp = hp
	e.hp = hp
	return e

func _fresh() -> void:
	scene._start_game()
	scene.run.pending.clear()
	for e in scene.enemies:
		e.dead = true
		e.queue_free()
	scene.enemies.clear()
	scene.field.clear_all()
	scene._aftershocks.clear()
	scene.player.invuln = 0.0
	scene.player.shield = 0

func _friendly() -> int:
	var n := 0
	for b in scene.field.bullets:
		if b.friendly and not b.dead:
			n += 1
	return n

func _frames(n: int) -> void:
	for k in n:
		await process_frame

func _run() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await _frames(3)
	ctx = scene.ctx
	_fresh()
	await process_frame
	await _synergies()
	print("— yeni kartlar, evrimler, lanetler —")
	await _new_cards()
	print("— her kartla gerçek oyun adımı + sızıntı —")
	await _soak()
	var missing: Array = []
	for card in _gd().cards:
		if not _checked.has(str(card["id"])):
			missing.append(str(card["id"]))
	_check(missing.is_empty(), "her kart ölçüldü (%d kart, eksik: %s)" % [_gd().cards.size(), ", ".join(PackedStringArray(missing))])
	print("SONUÇ: %s" % ("geçti" if _fail == 0 else "%d hata" % _fail))
	quit(0 if _fail == 0 else 1)

# --- Altı özgün sinerji (eski prob; davranış aynı) ---------------------------------------
func _synergies() -> void:
	var p: Vector2 = scene.player.pos2
	_give(["zincir", "kritik", "s_firtina"])
	var line: Array = []
	for k in 5:
		line.append(_enemy_at(p + Vector2(300 + k * 60, 0)))
	var b = scene.field.spawn(p, Vector2.RIGHT, 900.0, true, 20.0, 1.0, 1.0, true)
	b.crit = true
	scene._hit_enemy(line[0], b)
	var hit := 0
	for e in line:
		if e.hp < e.max_hp:
			hit += 1
	_check(hit == 4, "Fırtına Ağı: kritik 1 + 3 zincir = 4 düşmana ulaştı (gelen %d)" % hit)
	_mark(["zincir", "kritik", "s_firtina"])

	_fresh()
	_give(["vampir", "yenilenme", "s_hasat"])
	scene.player.hp = scene.player.max_hp
	scene._heal(60.0)
	_check(scene.player.shield == 1, "Kan Hasadı: 60 taşan can → kalkan")
	_mark(["vampir", "yenilenme", "s_hasat"])

	_fresh()
	_give(["novacekirdek", "patlayici", "s_kiyamet"])
	scene.nova = scene.NOVA_MAX
	scene._try_nova()
	_check(scene._aftershocks.size() == 3, "Kıyamet Novası: 3 artçı patlama sıraya girdi (gelen %d)" % scene._aftershocks.size())
	_mark(["novacekirdek", "patlayici", "s_kiyamet"])

	_fresh()
	_give(["sok", "atilma", "s_yildirim"])
	var weak = _enemy_at(scene.player.pos2 + Vector2(10, 0), 5.0)
	scene.player.dash_left = 0.1
	scene.player.dash_cd = 0.9
	scene._resolve_collisions()
	_check(weak.dead and scene.player.dash_cd == 0.0, "Yıldırım Koşusu: atılma ile öldürme → bekleme sıfır")
	_mark(["sok", "atilma", "s_yildirim"])

	_fresh()
	_give(["drone", "drone", "coklu", "s_kovan"])
	_check(scene.drones.size() == 3, "Kovan Zihni: 3 drone (gelen %d)" % scene.drones.size())
	_mark(["drone", "coklu", "s_kovan"])

	_fresh()
	_give(["diken", "zirh", "s_kale"])
	var before: int = scene.field.bullets.size()
	scene.player.take_damage(5.0, scene.player.pos2 + Vector2.UP)
	_check(scene.field.bullets.size() - before == 12, "Diken Kalesi: hasarda 12 mermi (gelen %d)" % (scene.field.bullets.size() - before))
	_mark(["diken", "zirh", "s_kale"])

func _mark(ids: Array) -> void:
	for id in ids:
		_checked[str(id)] = true

# --- Yeni kartlar -----------------------------------------------------------------------
func _new_cards() -> void:
	var fx = ctx.effects   # tipsiz: -s betiği otoyüklerden önce derlenir
	var player = scene.player

	_fresh(); _give(["yorunge", "yorunge"])
	var ring: Array = []
	for k in 8:
		ring.append(_enemy_at(player.pos2 + Vector2.from_angle(TAU * k / 8.0) * 58.0))
	for k in 40:
		fx.tick(1.0 / 60.0)
	_check(ring.any(func(e): return e.hp < e.max_hp), "Yörünge Bıçakları: halkadaki düşmanlar kesildi")
	_mark(["yorunge"])

	_fresh(); _give(["taret"])
	var far = _enemy_at(player.pos2 + Vector2(300, 0))
	fx.on_dash(player.pos2, Vector2.RIGHT)
	var shots := _friendly()
	for k in 30:
		fx.tick(1.0 / 60.0)
	_check(fx._turret_count == 1 and _friendly() > shots, "Otomatik Taret: atılmada taret kuruldu ve ateş etti")
	_mark(["taret"])

	_fresh(); _give(["arka"])
	scene.field.clear_all()
	ctx.weapons.on_player_shot(player.pos2, Vector2.RIGHT)
	var back := 0
	for b in scene.field.bullets:
		if b.friendly and b.velocity2.x < 0.0:
			back += 1
	_check(back >= 1, "Arka Toplar: geriye mermi (gelen %d)" % back)
	_mark(["arka"])

	_fresh(); _give(["sekme"])
	var a = _enemy_at(player.pos2 + Vector2(100, 0))
	var b2 = _enemy_at(player.pos2 + Vector2(260, 0))
	var bl = scene.field.spawn(player.pos2, Vector2.RIGHT, 900.0, true, 10.0, 1.0)
	var n0 := _friendly()
	fx.on_bullet_stopped(a, bl)
	_check(_friendly() == n0 + 1 and scene.field.bullets[scene.field.bullets.size() - 1].velocity2.x > 0.0, "Sekme: duran mermi yakındaki düşmana seker")
	_mark(["sekme"])

	_fresh(); _give(["infaz"])
	var low = _enemy_at(player.pos2 + Vector2(150, 0))
	low.hp = low.max_hp * 0.08 + 1.0
	scene._hit_enemy(low, scene.field.spawn(player.pos2, Vector2.RIGHT, 900.0, true, 1.0, 1.0))
	_check(low.dead, "İnfaz: %12 altındaki düşman bitti")
	_mark(["infaz"])

	_fresh(); _give(["kirilma"])
	var tgt = _enemy_at(player.pos2 + Vector2(150, 0))
	var cb = scene.field.spawn(player.pos2, Vector2.RIGHT, 900.0, true, 10.0, 1.0, 1.0, true)
	n0 = _friendly()
	scene._hit_enemy(tgt, cb)
	var want_shards := int(Loadout.param("shard_count", 3.0))
	_check(_friendly() - n0 == want_shards, "Kristal Kırılma: kritik → %d parça (gelen %d)" % [want_shards, _friendly() - n0])
	_mark(["kirilma"])

	_fresh(); _give(["ivme"])
	player.velocity2 = Vector2.RIGHT * player.speed
	var moving: float = fx.shot_damage_mult()
	player.velocity2 = Vector2.ZERO
	_check(moving > 1.25 and is_equal_approx(fx.shot_damage_mult(), 1.0), "İvme: hareketle hasar ×%.2f, dururken ×1" % moving)
	_mark(["ivme"])

	_fresh(); _give(["sabit"])
	player.velocity2 = Vector2.ZERO
	_check(fx.shot_damage_mult() > 1.35, "Sabit Nişan: dururken hasar ×%.2f" % fx.shot_damage_mult())
	_mark(["sabit"])

	_fresh(); _give(["karadelik"])
	var pulled = _enemy_at(player.pos2 + Vector2(450, 0))
	scene.nova = scene.NOVA_MAX
	scene._try_nova()
	_check(pulled.knock2.x < 0.0 and scene._aftershocks.any(func(x): return x.has("r")), "Kara Delik: düşman çekildi, çöküş sıraya girdi")
	_mark(["karadelik"])

	_fresh(); _give(["akim"])
	scene.nova = 0.0
	fx.on_dash(player.pos2, Vector2.RIGHT)
	_check(scene.nova >= 4.0, "İyon Akımı: atılma novayı doldurdu (%.0f)" % scene.nova)
	_mark(["akim"])

	_fresh(); _give(["iz"])
	var burn = _enemy_at(player.pos2, 500.0)
	player.dash_left = 0.1
	for k in 20:
		fx.tick(1.0 / 60.0)
	_check(burn.hp < burn.max_hp, "Plazma İzi: izdeki düşman yandı")
	_mark(["iz"])

	_fresh(); _give(["adrenalin"])
	var base_rate: float = player.fire_rate_mult
	player.hp = player.max_hp * 0.2
	fx.tick(1.0 / 60.0)
	_check(player.fire_rate_mult > base_rate * (1.0 + Loadout.param("adrenaline_rate") * 0.99), "Adrenalin: düşük canda ateş hızı ×%.2f" % (player.fire_rate_mult / base_rate))
	_mark(["adrenalin"])

	_fresh(); _give(["ayna"])
	var hb = scene.field.spawn(player.pos2 + Vector2(60, 0), Vector2.LEFT, 300.0, false, 10.0, 2.0)
	player.dash_left = 0.1
	fx.tick(1.0 / 60.0)
	_check(hb.friendly and hb.velocity2.x > 0.0, "Ayna Atılması: düşman mermisi yansıdı")
	_mark(["ayna"])

	_fresh(); _give(["bariyer"])
	var dummy = _enemy_at(player.pos2 + Vector2(500, 0))
	for k in 30:
		fx.on_kill(dummy)
	_check(player.shield == 1, "Ölüm Bariyeri: 30 öldürme → kalkan")
	_mark(["bariyer"])

	_fresh(); _give(["toplayici"])
	var near = _enemy_at(player.pos2 + Vector2(120, 0))
	fx.on_pickup("heal")
	_check(near.hp < near.max_hp, "Şok Toplayıcı: toplamada şok dalgası")
	_mark(["toplayici"])

	_fresh(); _give(["avci"])
	var el = _enemy_at(player.pos2 + Vector2(500, 0))
	el.elite = true
	var pk: int = scene.pickups.size()
	fx.on_kill(el)
	_check(fx.enemy_damage_mult(el) > 1.1 and scene.pickups.size() > pk, "Avcı: elite hasar ×%.2f ve ek ganimet" % fx.enemy_damage_mult(el))
	_mark(["avci"])

	_fresh(); _give(["kombo"])
	scene.run.combo = 20
	_check(fx.shot_damage_mult() > 1.18, "Kombo Motoru: 20 kombo → hasar ×%.2f" % fx.shot_damage_mult())
	_mark(["kombo"])

	_fresh(); _give(["novakalkan"])
	scene.nova = scene.NOVA_MAX
	scene._try_nova()
	_check(player.shield == 1, "Nova Kabuğu: nova → kalkan")
	_mark(["novakalkan"])

	_fresh(); _give(["bolunme"])
	var w1 = _enemy_at(player.pos2 + Vector2(150, 0), 5.0)
	var kb = scene.field.spawn(player.pos2, Vector2.RIGHT, 900.0, true, 50.0, 1.0)
	n0 = _friendly()
	scene._hit_enemy(w1, kb)
	_check(_friendly() - n0 == int(Loadout.param("split_count", 2.0)), "Bölünme: öldüren mermi %d parça" % (_friendly() - n0))
	_mark(["bolunme"])

	_fresh(); _give(["statik"])
	var z1 = _enemy_at(player.pos2 + Vector2(120, 0))
	var z2 = _enemy_at(player.pos2 + Vector2(-140, 0))
	fx.tick(1.1)
	_check(z1.hp < z1.max_hp and z2.hp < z2.max_hp, "Statik Alan: 2 yakın düşman çarpıldı")
	_mark(["statik"])

	_fresh(); _give(["asiri"])
	player.overdrive = 6.0
	fx.on_pickup("overdrive")
	_check(player.overdrive >= 11.9 and fx.nova_kill_mult() > 1.9, "Aşırı Yükleme: süre ×2, nova ×2")
	_mark(["asiri"])

	_fresh(); _give(["sismik"])
	fx.on_dash(player.pos2, Vector2.RIGHT)
	_check(scene._aftershocks.size() == 1 and scene._aftershocks[0].has("r"), "Sismik İniş: atılma sonu patlaması sıraya girdi")
	_mark(["sismik"])

	_fresh(); _give(["celik"])
	player.hp = 100.0
	player.max_hp = 100.0
	player.take_damage(10.0, player.pos2 + Vector2.UP)
	_check(is_equal_approx(player.hp, 93.0), "Çelik Gövde: 10 hasar → 7 (can %.1f)" % player.hp)
	_mark(["celik"])

	_fresh(); _give(["firlatici"])
	_enemy_at(player.pos2 + Vector2(300, 0))
	fx.tick(0.1)
	_check(scene.field.bullets.any(func(x): return x.friendly and x.homing > 0.0), "Füze Kapsülü: güdümlü füze")
	_mark(["firlatici"])

	_fresh(); _give(["kalkancarp"])
	var bash = _enemy_at(player.pos2 + Vector2(120, 0))
	player.shield = 1
	player.take_damage(10.0, player.pos2 + Vector2.UP)
	_check(bash.hp < bash.max_hp and player.invuln >= 0.99, "Kalkan Çarpması: kalkan kırılınca patlama")
	_mark(["kalkancarp"])

	# Denge anahtarları (mevcut kartlar)
	_fresh(); _give(["coklu"])
	player.velocity2 = Vector2.ZERO
	_check(scene.loadout.i("projectiles") == 2 and fx.shot_damage_mult() < 0.9, "Çoklu Atış: 2 mermi, mermi hasarı ×%.2f" % fx.shot_damage_mult())
	_fresh(); _give(["atilma"])
	scene.nova = 0.0
	fx.on_dash(player.pos2, Vector2.RIGHT)
	_check(scene.nova >= 2.9 and scene.loadout.m("dash_cd_mult") < 0.75, "Kısa Devre: atılma +%.0f nova, bekleme ×%.2f" % [scene.nova, scene.loadout.m("dash_cd_mult")])
	_fresh(); _give(["delici"])
	_check(scene.loadout.i("pierce") == 1 and scene.loadout.m("damage_mult") > 1.05, "Delici: +1 delme, hasar +%6")

	# --- Evrimler
	for evo in ["e_yildiz", "e_suru", "e_tanri", "e_kanay", "e_kuyruk", "e_tekil"]:
		_fresh()
		var recipe := _recipe(evo)
		_give(recipe.slice(0, recipe.size() - 1))
		var offer: Array = scene.loadout.roll(3, RandomNumberGenerator.new())
		_check(not offer.is_empty() and str(offer[0]["id"]) == evo, "%s: tarif tamam → ilk yuvada garanti sunuldu" % evo)
		_give([evo])
		_mark([evo])
		match evo:
			"e_yildiz":
				scene.field.clear_all()
				ctx.weapons.on_player_shot(player.pos2, Vector2.RIGHT)
				_check(_friendly() == 4 and scene.loadout.i("pierce") >= 4, "Yıldız Yağmuru: 4 mermi, delme %d" % scene.loadout.i("pierce"))
			"e_suru":
				var db = scene.field.spawn(player.pos2, Vector2.RIGHT, 900.0, true, 10.0, 1.0)
				fx.drone_bullet(db)
				_check(scene.drones.size() == 4 and db.pierce == 2, "Sürü Kraliçesi: 4 drone, delen drone mermisi (gelen %d)" % scene.drones.size())
			"e_tanri":
				var zs: Array = []
				for k in 5:
					zs.append(_enemy_at(player.pos2 + Vector2.from_angle(TAU * k / 5.0) * 130.0, 5000.0))
				fx.tick(0.6)
				var zapped := zs.filter(func(e): return e.hp < e.max_hp).size()
				_check(zapped >= 4 and scene.loadout.i("chain") == 3, "Yıldırım Tanrısı: hızlı statik %d hedef" % zapped)
			"e_kanay":
				player.hp = player.max_hp
				scene._heal(40.0)
				_check(player.shield == 1 and fx.vampire_mult() > 1.0 and fx.harvest_threshold() < 50.0, "Kan Ayı: 40 taşan can → kalkan (eşik %.0f), vampir ×%.1f" % [fx.harvest_threshold(), fx.vampire_mult()])
			"e_kuyruk":
				fx.on_dash(player.pos2, Vector2.RIGHT)
				_check(scene.loadout.m("dash_cd_mult") < 0.5 and fx._trail_level() >= 1 and scene._aftershocks.size() == 1, "Kuyruklu Yıldız: kısa bekleme, iz + iniş")
			"e_tekil":
				scene.nova = scene.NOVA_MAX
				scene._try_nova()
				_check(scene.nova >= 29.0 and fx.nova_radius_mult() > 1.3, "Tekillik: geniş nova, %.0f iade" % scene.nova)

	# --- Lanetler (C1 API)
	for c in scene.loadout.cursed_cards():
		var id := str(c["id"])
		_fresh()
		var info: Dictionary = Loadout.curse_info(c)
		var core_before: float = scene.loadout.m("core_mult")
		var applied: bool = fx.apply_curse(id)
		_check(applied and scene.loadout.curses.has(id) and scene.loadout.m("core_mult") > core_before and info["drawback"] != "", "Lanet %s: uygulandı, ödül ×%.2f, bedel: %s" % [id, float(info["reward_mult"]), info["drawback"]])
		match id:
			"l_kan":
				player.hp = 50.0
				scene._heal(20.0)
				_check(is_equal_approx(player.hp, 60.0), "Kan Andı: iyileşme yarıya indi (can %.1f)" % player.hp)
			"l_asiri":
				player.hp = 100.0
				player.max_hp = 100.0
				player.take_damage(10.0, player.pos2 + Vector2.UP)
				_check(is_equal_approx(player.hp, 86.0), "Aşırı Hız: 10 hasar → 14 (can %.1f)" % player.hp)
			"l_acgoz":
				_check(scene.loadout.roll(3, RandomNumberGenerator.new()).size() == 2, "Açgözlülük: seviyede 2 kart")
			"l_cam":
				_check(player.max_hp < 70.0, "Cam Top: maksimum can düştü (%.0f)" % player.max_hp)
		_mark([id])

	# Kalan (yalnız istatistik) kartlar: çarpan değişmeli ve gemiye yansımalı
	for card in _gd().cards:
		var id := str(card["id"])
		if _checked.has(id):
			continue
		_fresh()
		var before: Dictionary = scene.loadout.mods.duplicate()
		_give([id])
		var changed := false
		for key in card["effect"]:
			if not is_equal_approx(float(scene.loadout.mods.get(key, 0.0)), float(before.get(key, 0.0))):
				changed = true
		_check(changed, "%s: etki uygulandı (%s)" % [id, str(card["effect"])])
		_mark([id])
	_fresh(); _give(["cevik"])
	_check(player.speed > 360.0 * 1.09, "Çeviklik: gemi hızına yansıdı (%.0f)" % player.speed)
	_fresh(); _give(["zirh"])
	_check(player.max_hp >= 124.0, "Zırh: maksimum can %.0f" % player.max_hp)

# --- Gerçek oyun adımı + sızıntı ---------------------------------------------------------
func _soak() -> void:
	## Her kart (tarifiyle) verilip düşmanlarla dolu sahnede ~0,4 sn gerçek kare koşar: SCRIPT ERROR kapıda yakalanır.
	_fresh()
	await _frames(10)
	var nodes0 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphans0 := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var errors := 0
	for card in _gd().cards:
		_fresh()
		_give(_recipe(str(card["id"])))
		var p: Vector2 = scene.player.pos2
		for k in 6:
			_enemy_at(p + Vector2.from_angle(TAU * k / 6.0) * (90.0 + 40.0 * k), 60.0, ["chaser", "shooter", "swarmer"][k % 3])
		scene.player.hp = scene.player.max_hp
		scene.nova = scene.NOVA_MAX
		scene.player.dash_left = 0.1
		await _frames(24)
		scene._try_nova()
		await _frames(4)
		if scene.state != "playing":
			errors += 1
	_check(errors == 0, "her kartla gerçek oyun adımı tamamlandı (%d kart)" % _gd().cards.size())
	_fresh()
	await _frames(10)
	var nodes1 := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphans1 := int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check(nodes1 - nodes0 <= 4 and orphans1 - orphans0 <= 4, "sızıntı yok: düğüm %d → %d, yetim %d → %d" % [nodes0, nodes1, orphans0, orphans1])
