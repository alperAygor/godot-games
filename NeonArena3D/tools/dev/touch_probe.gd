extends SceneTree
## Dokunmatik kontrolleri gerçek InputEventScreenTouch/Drag olaylarıyla sınar (çoklu dokunuş dahil).

var _fail := 0
var scene

func _check(cond: bool, msg: String) -> void:
	print(("  ✓ " if cond else "  ✗ ") + msg)
	if not cond:
		_fail += 1

func _initialize() -> void:
	_run.call_deferred()

func _touch(index: int, at: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = at
	e.pressed = pressed
	scene.touch._input(e)

func _drag(index: int, at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = at
	scene.touch._input(e)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	var settings = root.get_node("Settings")
	settings.touch = true
	settings.auto_fire = true
	scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await _frames(3)
	scene._start_game()
	scene.run.pending.clear()
	scene.hud.hint = ""
	await _frames(2)
	var tc = scene.touch
	var vp: Vector2 = root.get_visible_rect().size
	print("  görünüm: %s  kenar boşlukları: %s" % [str(vp), str(tc._margin)])
	_check(tc.enabled and tc.visible, "dokunmatik katman açık")

	# 1) Sol çubuk: sağa sürükle → hareket
	var start: Vector2 = scene.player.pos2
	_touch(0, Vector2(220, vp.y - 170), true)
	_drag(0, Vector2(320, vp.y - 170))
	await _frames(2)
	_check(tc.move.x > 0.9 and absf(tc.move.y) < 0.1, "sol çubuk sağ: move=%s" % str(tc.move))
	await create_timer(0.5).timeout
	_check(scene.player.pos2.x - start.x > 60.0, "gemi sağa gitti (%.0f px)" % (scene.player.pos2.x - start.x))

	# 2) Aynı anda sağ çubuk (2. parmak): yukarı nişan + ateş
	_touch(1, Vector2(vp.x - 220, vp.y - 170), true)
	_drag(1, Vector2(vp.x - 220, vp.y - 280))
	await _frames(3)
	_check(tc.aiming and tc.aim.y < -0.9, "sağ çubuk yukarı: aim=%s" % str(tc.aim))
	_check(tc.move.x > 0.9, "1. parmak hâlâ hareket ettiriyor (çoklu dokunuş)")
	await create_timer(0.3).timeout
	_check(scene.player.aim2.y < -0.9, "gemi yukarı nişan aldı: %s" % str(scene.player.aim2))
	var shots := 0
	for b in scene.field.bullets:
		if b.friendly:
			shots += 1
	_check(shots > 0, "nişan çubuğu ateş ettirdi (%d mermi)" % shots)

	# 3) Parmaklar kalkınca: hareket durur, otomatik nişan devreye girer
	_touch(0, Vector2(320, vp.y - 170), false)
	_touch(1, Vector2(vp.x - 220, vp.y - 280), false)
	await _frames(2)
	_check(tc.move == Vector2.ZERO and not tc.aiming, "bırakınca çubuklar sıfırlandı")
	scene._spawn_enemy("chaser", scene.player.pos2 + Vector2(-260, 0), 0.0, false)
	var e = scene.enemies[scene.enemies.size() - 1]
	e.spawn_delay = 0.0
	await create_timer(0.4).timeout
	_check(scene.player.aim2.x < -0.8, "otomatik nişan soldaki düşmana döndü: %s" % str(scene.player.aim2))

	# 4) ATIL düğmesi
	scene.player.dash_cd = 0.0
	var dc: Vector2 = tc._dash_center()
	_touch(2, dc, true)
	await _frames(2)
	_touch(2, dc, false)
	_check(scene.player.dash_cd > 0.0, "ATIL düğmesi atılma yaptı")

	# 5) NOVA düğmesi (dolu)
	scene.nova = scene.NOVA_MAX
	var nc: Vector2 = tc._nova_center()
	_touch(3, nc, true)
	await _frames(2)
	_touch(3, nc, false)
	_check(scene.nova < 20.0, "NOVA düğmesi novayı kullandı (kalan %.1f, öldürmelerden geri dolan)" % scene.nova)

	# 6) Düğmeye basan parmak çubuk başlatmamalı
	_check(tc._move_id == -1 and tc._aim_id == -1, "düğme dokunuşları çubuğu tetiklemedi")

	# 7) Duraklat düğmesi
	var pc: Vector2 = tc._pause_center()
	_touch(4, pc, true)
	await _frames(2)
	_touch(4, pc, false)
	_check(paused and scene.menus.current == "pause", "duraklat düğmesi menüyü açtı")
	print("SONUÇ: %s" % ("geçti" if _fail == 0 else "%d hata" % _fail))
	quit(0 if _fail == 0 else 1)
