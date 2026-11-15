extends GameModule
class_name PlayerControl
## Oyuncu girdisi ve gemi adımı: klavye/fare, dokunmatik (otomatik nişan + ateş) ya da otopilot → player.tick;
## duvar/engel, yenilenme, kalkan yenilenmesi, nova isteği, iz kıvılcımı; kartlardan gelen gemi istatistikleri.

var shield_timer := 0.0
var _target: Variant = null
var _target_timer := 0.0
var _nova_was_ready := false

func reset_run() -> void:
	_nova_was_ready = false
	shield_timer = 0.0

func forget_target(e: Variant = null) -> void:
	## Hedef öldü / sahne temizlendi: otomatik nişan hedefini bırak (null = koşulsuz).
	if e == null or e == _target:
		_target = null

func apply_loadout() -> void:
	## Kartlar/atölye/gemi etkilerini gemi istatistiklerine uygular (maks. can artışı mevcut cana da eklenir).
	var player := ctx.player
	var loadout := ctx.loadout
	var base_hp: float = GameData.number("player.max_health", 100.0)
	var new_max: float = base_hp + loadout.m("max_hp_bonus")
	if new_max > player.max_hp + 0.01:
		player.hp += new_max - player.max_hp
	player.max_hp = new_max
	player.hp = clampf(player.hp, 0.0, player.max_hp)
	player.speed = GameData.number("player.speed", 360.0) * loadout.m("speed_mult")
	player.fire_rate_mult = loadout.m("fire_rate_mult")
	player.dash_cd_mult = loadout.m("dash_cd_mult")
	ctx.weapons.sync_drones()
	ctx.effects.on_loadout_applied()

func idle(delta: float) -> void:
	## Menüde gemi arkada süzülür.
	var player := ctx.player
	var elapsed := ctx.elapsed
	var center := ARENA.get_center()
	var at := center + Vector2(sin(elapsed * 0.5) * 22.0, cos(elapsed * 0.4) * 14.0)
	player.idle_visual(delta, at, elapsed * 0.35 + 0.6, 1.25 + sin(elapsed * 1.3) * 0.14)
	if int(elapsed * 30.0) % 2 == 0:
		var back: Vector3 = player.global_transform.basis.z
		ctx.sparks.trail(player.position + back * 1.3, -back, player.ship_color)

func tick(delta: float) -> void:
	var player := ctx.player
	var touch := ctx.touch
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var aim_target: Vector2 = player.pos2 + player.aim2 * 200.0
	var fire := false
	var dash := Input.is_action_just_pressed("dash")
	var want_nova := Input.is_action_just_pressed("nova")
	var locked: Variant = null
	if player.autopilot:
		var plan := ctx.autopilot.plan()
		input = plan["move"]
		aim_target = plan["aim"]
		fire = plan["fire"]
		dash = plan["dash"]
		want_nova = plan["nova"]
	elif Settings.touch:
		if touch.move.length() > 0.01:
			input = touch.move
		dash = dash or touch.take_dash()
		want_nova = want_nova or touch.take_nova()
		if touch.aiming:
			aim_target = player.pos2 + touch.aim * 320.0
			fire = true
		else:
			locked = _auto_aim(delta)
			if locked != null:
				aim_target = _lead_point(locked)
				fire = Settings.auto_fire
			elif input.length() > 0.2:
				aim_target = player.pos2 + input.normalized() * 200.0
	else:
		aim_target = ctx.camera.mouse_aim()
		fire = Input.is_action_pressed("fire") or Settings.auto_fire
	ctx.camera.update_aim_marker(delta, locked, aim_target)

	var before: Vector2 = player.pos2
	player.tick(delta, input, aim_target, fire, dash)
	if (player.pos2 - before).length() > 0.5:
		var edge := player.radius + 1.0
		if player.pos2.x <= ARENA.position.x + edge or player.pos2.x >= ARENA.end.x - edge or player.pos2.y <= ARENA.position.y + edge or player.pos2.y >= ARENA.end.y - edge:
			ctx.world.hit_wall()
	var fixed := ArenaGeometry.push_out(ctx.obstacles, player.pos2, player.radius)
	if fixed != player.pos2:
		player.pos2 = fixed
		player.position = ArenaSpace.to_world(fixed, player.position.y)
	var regen: float = ctx.loadout.m("regen")
	if regen > 0.0 and player.alive:
		ctx.combat.heal(regen * delta, false)
	if ctx.loadout.i("shield_regen") > 0 and player.shield <= 0:
		shield_timer += delta
		if shield_timer >= ctx.tuning.player_shield_regen_time:
			shield_timer = 0.0
			ctx.combat.give_shield()
	if want_nova:
		ctx.combat.try_nova()
	var nova_ready := ctx.nova >= ctx.tuning.nova_max
	if nova_ready and not _nova_was_ready:
		Sound.play("nova_ready")
		ctx.hud.toast(tr("NOVA HAZIR"), KIT.MAGENTA, 1.4)
	_nova_was_ready = nova_ready
	if player.velocity2.length() > 40.0 and player.alive:
		var back: Vector3 = player.global_transform.basis.z
		ctx.sparks.trail(player.position + back * 1.25, -back, Color(1.0, 0.85, 0.3) if player.overdrive > 0.0 else player.ship_color, 2.0 if player.is_dashing() else 1.5)
		if player.is_dashing():
			ctx.sparks.trail(player.position + back * 0.4, -back, Color(0.7, 1.0, 1.0), 2.4)

# --- Otomatik nişan (dokunmatik) -----------------------------------------------------
func _pick_target() -> Variant:
	var t := ctx.tuning
	var player := ctx.player
	var boss := ctx.boss
	var limit: float = t.player_auto_aim_range
	var best: Variant = null
	var best_score := 1e12
	for e in ctx.enemies:
		if not is_instance_valid(e) or e.dead or e.is_spawning():
			continue
		var d: float = e.pos2.distance_to(player.pos2)
		if d > limit:
			continue
		var score := d
		if e == _target:
			score *= t.auto_aim_keep_bias
		if e.kind == "bomber" or e.kind == "sniper":
			score *= t.auto_aim_priority_bias
		if ArenaGeometry.line_blocked(ctx.obstacles, player.pos2, e.pos2):
			score *= t.auto_aim_blocked_penalty
		if score < best_score:
			best_score = score
			best = e
	if boss != null and is_instance_valid(boss) and boss.alive and boss.intro <= 0.0:
		var db: float = maxf(0.0, boss.pos2.distance_to(player.pos2) - boss.radius)
		if db < limit * t.auto_aim_boss_range_mult and db * t.auto_aim_boss_bias < best_score:
			best = boss
	return best

func target_valid(target: Variant) -> bool:
	return is_valid_target(target, ctx.boss)

static func is_valid_target(target: Variant, boss: Boss3D) -> bool:
	## Hedef hâlâ vurulabilir mi (boss için `alive`, düşman için `not dead`). Sıcak döngüler boss'u yerelde tutar.
	if target == null or not is_instance_valid(target):
		return false
	if target == boss:
		return boss.alive
	return not target.dead

func _auto_aim(delta: float) -> Variant:
	## Hedefi saniyede ~8 kez yeniden seçer; arada mevcut hedefi izler.
	_target_timer -= delta
	if _target_timer <= 0.0 or not target_valid(_target):
		_target_timer = ctx.tuning.auto_aim_retarget
		_target = _pick_target()
	return _target if target_valid(_target) else null

func _lead_point(target: Variant) -> Vector2:
	var speed: float = ctx.tuning.player_bullet_speed
	var tpos: Vector2 = target.pos2
	if target == ctx.boss:
		return tpos
	var tvel: Vector2 = target.velocity2
	return tpos + tvel * (tpos.distance_to(ctx.player.pos2) / speed)
