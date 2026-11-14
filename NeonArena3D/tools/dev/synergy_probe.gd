extends SceneTree
## Altı sinerjinin oyun içi etkisini tek tek tetikleyip doğrular.

var _fail := 0
var scene

func _check(cond: bool, msg: String) -> void:
	print(("  ✓ " if cond else "  ✗ ") + msg)
	if not cond:
		_fail += 1

func _initialize() -> void:
	_run.call_deferred()

func _give(ids: Array) -> void:
	var gd = root.get_node("GameData")
	for id in ids:
		scene.loadout.apply(gd.card_by_id(id))
	scene._apply_loadout()

func _enemy_at(at: Vector2, hp := 500.0):
	scene._spawn_enemy("chaser", at, 0.0, false)
	var e = scene.enemies[scene.enemies.size() - 1]
	e.spawn_delay = 0.0
	e.max_hp = hp
	e.hp = hp
	return e

func _run() -> void:
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for i in 3:
		await process_frame
	scene._start_game()
	scene.run.pending.clear()
	await process_frame
	var p: Vector2 = scene.player.pos2

	# 1) Fırtına Ağı: kritik isabet zincire +2 düşman ekler
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

	# 2) Kan Hasadı: taşan iyileşme kalkan olur
	_give(["vampir", "yenilenme", "s_hasat"])
	scene.player.hp = scene.player.max_hp
	scene.player.shield = 0
	scene._heal(60.0)
	_check(scene.player.shield == 1, "Kan Hasadı: 60 taşan can → kalkan")

	# 3) Kıyamet Novası: 3 artçı patlama
	_give(["novacekirdek", "patlayici", "s_kiyamet"])
	scene.nova = scene.NOVA_MAX
	scene._try_nova()
	_check(scene._aftershocks.size() == 3, "Kıyamet Novası: 3 artçı patlama sıraya girdi (gelen %d)" % scene._aftershocks.size())

	# 4) Yıldırım Koşusu: atılırken öldürmek beklemeyi sıfırlar
	_give(["sok", "atilma", "s_yildirim"])
	for e in scene.enemies:
		e.dead = true
	scene.enemies.clear()
	scene.field.clear_all()
	var weak = _enemy_at(scene.player.pos2 + Vector2(10, 0), 5.0)
	scene.player.dash_left = 0.1
	scene.player.dash_cd = 0.9
	print("    dash_damage=%.1f blitz=%d dashing=%s alive=%s dist=%.1f lim=%.1f spawning=%s" % [scene.loadout.m("dash_damage"), scene.loadout.i("blitz"), str(scene.player.is_dashing()), str(scene.player.alive), weak.pos2.distance_to(scene.player.pos2), weak.radius + scene.player.radius + 22.0, str(weak.is_spawning())])
	scene._resolve_collisions()
	print("    sonra: dead=%s hp=%.1f dash_cd=%.2f" % [str(weak.dead), weak.hp, scene.player.dash_cd])
	_check(weak.dead and scene.player.dash_cd == 0.0, "Yıldırım Koşusu: atılma ile öldürme → bekleme sıfır")

	# 5) Kovan Zihni: 3 drone ve hızlı ateş
	_give(["drone", "drone", "coklu", "s_kovan"])
	_check(scene.drones.size() == 3, "Kovan Zihni: 3 drone (gelen %d)" % scene.drones.size())

	# 6) Diken Kalesi: hasar alınca 12 mermi
	_give(["diken", "zirh", "s_kale"])
	var before: int = scene.field.bullets.size()
	scene.player.invuln = 0.0
	scene.player.shield = 0
	scene.player.take_damage(5.0, scene.player.pos2 + Vector2.UP)
	var after: int = scene.field.bullets.size()
	_check(after - before == 12, "Diken Kalesi: hasarda 12 mermi (gelen %d)" % (after - before))
	print("SONUÇ: %s" % ("geçti" if _fail == 0 else "%d hata" % _fail))
	quit(0 if _fail == 0 else 1)
