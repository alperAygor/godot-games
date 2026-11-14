extends SceneTree
## Atölye etkilerinin koşuya uygulanmasını ve ölümde çekirdek ödülünü doğrular.

var _fail := 0

func _check(cond: bool, msg: String) -> void:
	print(("  ✓ " if cond else "  ✗ ") + msg)
	if not cond:
		_fail += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings = root.get_node("Settings")
	var meta = settings.meta
	meta.earn(5000)
	for id in ["zirh", "zirh", "silah", "nova", "nova", "sans", "kalkan", "veri", "toplayici"]:
		meta.buy(id)
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for i in 3:
		await process_frame
	scene._start_game()
	await process_frame
	_check(is_equal_approx(scene.player.max_hp, 124.0), "2 seviye zırh: maks can 124 (gelen %.0f)" % scene.player.max_hp)
	_check(is_equal_approx(scene.loadout.m("damage_mult"), 1.06), "1 seviye silah: hasar ×1.06 (gelen %.3f)" % scene.loadout.m("damage_mult"))
	_check(is_equal_approx(scene.nova, 50.0), "2 seviye nova ön yükü: nova 50 (gelen %.0f)" % scene.nova)
	_check(scene.rerolls == 3, "1 seviye şans: 3 yenileme (gelen %d)" % scene.rerolls)
	_check(scene.player.shield == 1, "ön kalkan: başlangıçta kalkan var")
	_check(is_equal_approx(scene.run.xp_mult, 1.08), "veri bankası: XP ×1.08 (gelen %.3f)" % scene.run.xp_mult)
	var before: int = meta.cores
	scene.run.score = 15000
	scene.run.wave = 9
	scene.run.bosses = 1
	scene.player.invuln = 0.0
	scene.player.shield = 0
	scene.player.take_damage(99999.0, scene.player.pos2 + Vector2.UP)
	for i in 4:
		await process_frame
	var expected: int = MetaProgress.run_reward(15000, 9, 1, 1.1)
	_check(scene.state == "dead", "ölüm durumuna geçildi")
	_check(scene._cores_earned == expected, "ödül formülü + toplayıcı ×1.1: %d (gelen %d)" % [expected, scene._cores_earned])
	_check(meta.cores == before + expected, "çekirdek bakiyeye eklendi (%d → %d)" % [before, meta.cores])
	print("SONUÇ: %s" % ("geçti" if _fail == 0 else "%d hata" % _fail))
	quit(0 if _fail == 0 else 1)
