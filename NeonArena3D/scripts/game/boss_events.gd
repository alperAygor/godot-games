extends GameModule
class_name BossEvents
## Boss yaşam döngüsü ve saldırı olayları: doğma (RunState.boss_due), Boss3D sinyallerinin mermi/tehlike/ışın
## karşılıkları, yer tehlikeleri, lazerler, ölüm sekansı ve sektör geçişi tetiklemesi (run.boss_died).
## Boss davranışı (ne zaman ne yapacağı) boss3d.gd'de; değerler data/balance/bosses.json + combat.json boss_attacks.

var dying := false                  ## ölüm sekansı sürüyor (tank bölünmesi kapalı)
var _boss_ofs := 0.0
var _boss_landed := false
var _boss_pop := 0.0

func reset() -> void:
	dying = false

func tick(delta: float) -> void:
	var boss := ctx.boss
	if boss == null or not is_instance_valid(boss):
		return
	var sparks := ctx.sparks
	boss.tick(delta, ctx.player.pos2)
	boss.pos2.x = clampf(boss.pos2.x, ARENA.position.x + boss.radius, ARENA.end.x - boss.radius)
	boss.pos2.y = clampf(boss.pos2.y, ARENA.position.y + boss.radius, ARENA.end.y - boss.radius)
	if not _boss_landed and boss.intro <= 0.0:
		_boss_landed = true
		sparks.ring(boss.position, boss.color(), 1.0, 13.0, 0.7, 0.2)
		sparks.burst(boss.position, boss.color(), 50, 13.0, 0.8, 1.6)
		Sound.play("explode_big", -2.0, 0.8)
		Fx.shake(20.0)
		Fx.vibrate(80)
		ctx.world.flash_pulse(boss.position, 1.0)
	if not boss.alive:
		if not dying:
			_on_boss_dying()
		_boss_pop -= delta
		if _boss_pop <= 0.0:
			_boss_pop = 0.11
			var off := Vector3(randf_range(-1.6, 1.6), randf_range(-0.4, 1.2), randf_range(-1.6, 1.6))
			sparks.burst(boss.position + off, boss.color() if randf() < 0.5 else Color(1, 0.9, 0.6), 14, 9.0, 0.5, 1.3)
			sparks.flash(boss.position + off, boss.color(), 5.0, 8.0, 0.2)
			Sound.play("explode", -4.0, randf_range(0.8, 1.3))
			Fx.shake(6.0)
		if boss.dying <= 0.0:
			_on_boss_killed()

func _spawn_boss_bullet(at: Vector2, dir: Vector2, speed: float, damage: float) -> void:
	var t := ctx.tuning
	var boss := ctx.boss
	var c: Color = boss.color().lerp(Color(1, 0.3, 0.6), 0.3) if boss != null else Color(1, 0.3, 0.6)
	ctx.field.spawn(at, dir, speed, false, damage, t.boss_attacks_bullet_life, t.boss_attacks_bullet_size, false, Color(c.r, c.g, c.b, 1.0))

func on_boss_due() -> void:
	var t := ctx.tuning
	var run := ctx.run
	if ctx.boss != null and is_instance_valid(ctx.boss):
		ctx.boss.queue_free()
	var map_index := ctx.map_index
	var theme: Dictionary = GameData.map_theme(map_index)
	var lap := map_index / maxi(1, GameData.maps.size())
	var kind := str(theme.get("boss", "sentinel"))
	if ctx.options.debug_boss != "":
		kind = ctx.options.debug_boss
	var b: Boss3D = Boss3D.new()
	var display := tr(str(theme.get("boss_name", "BOSS")))
	if lap > 0:
		display += " MK-%d" % (lap + 1)
	b.setup(GameData.boss_stats(kind), run.hp_scale() * (1.0 + t.boss_attacks_lap_hp * float(lap)), run.damage_scale(), display, str(theme.get("boss_color", "")), kind)
	b.pos2 = _boss_spawn_point()
	b.position = ArenaSpace.to_world(b.pos2, 6.0)
	ctx.host.add_child(b)
	ctx.boss = b
	_boss_landed = false
	dying = false
	b.radial_wave.connect(_on_boss_radial)
	b.aimed_shot.connect(_on_boss_aimed)
	b.summon.connect(_on_boss_summon)
	b.phase_changed.connect(_on_boss_phase)
	b.charge_warn.connect(_on_boss_charge_warn)
	b.charge_started.connect(_on_boss_charge)
	b.spiral_shot.connect(_on_boss_spiral)
	b.zone_marked.connect(_on_boss_zone)
	b.ring_burst.connect(_on_boss_ring)
	b.fan_shot.connect(_on_boss_fan)
	b.leap_started.connect(_on_boss_leap)
	b.blink_warn.connect(_on_boss_blink_warn)
	b.blinked.connect(_on_boss_blinked)
	b.beam_warned.connect(func(): Sound.play("laser_charge"))
	ctx.hud.show_banner(b.display_name, tr("BOSS YAKLAŞIYOR"), 2.6, b.color())
	ctx.sparks.ring(ArenaSpace.to_world(b.pos2, 0.0), b.color(), 9.0, 1.5, 1.2, 0.1, 1.0)
	Sound.play("boss_warn")
	Sound.music("boss", 1.2)
	ctx.world.set_danger(true)
	Fx.vibrate(120)
	ctx.events.boss_spawned.emit(kind)

func _boss_spawn_point() -> Vector2:
	## Boss her zaman ekranın üst tarafında, oyuncunun kuzeyinde doğar.
	var player_pos: Vector2 = ctx.player.pos2
	for i in 12:
		var offset := Vector2(randf_range(-200.0, 200.0), -randf_range(300.0, 380.0))
		var p: Vector2 = player_pos + offset
		p.x = clampf(p.x, ARENA.position.x + 140.0, ARENA.end.x - 140.0)
		p.y = clampf(p.y, ARENA.position.y + 140.0, ARENA.end.y - 140.0)
		if p.distance_to(player_pos) > 260.0 and not ArenaGeometry.point_blocked(ctx.obstacles, p, 90.0):
			return p
	return (player_pos + Vector2(0, 420)).clamp(ARENA.position + Vector2(140, 140), ARENA.end - Vector2(140, 140))

# --- Boss sinyalleri: mermi kalıpları --------------------------------------------------
func _on_boss_radial(count: int) -> void:
	var boss := ctx.boss
	if boss == null:
		return
	var t := ctx.tuning
	_boss_ofs += 0.19
	for i in count:
		var dir := Vector2.from_angle(TAU * float(i) / float(count) + _boss_ofs)
		_spawn_boss_bullet(boss.pos2 + dir * (boss.radius + 10.0), dir, t.boss_attacks_radial_speed, boss.damage_value * t.boss_attacks_radial_damage)
	ctx.sparks.ring(boss.position, boss.color(), 1.5, 4.5, 0.3, 0.15)
	Sound.play("shoot_enemy", 3.0, 0.6)

func _on_boss_aimed(dir: Vector2) -> void:
	var boss := ctx.boss
	if boss == null:
		return
	var t := ctx.tuning
	var shots := t.boss_attacks_aimed_shots
	for i in shots:
		var offset := (float(i) - float(shots - 1) * 0.5) * t.boss_attacks_aimed_spread
		_spawn_boss_bullet(boss.pos2 + dir.rotated(offset) * (boss.radius + 8.0), dir.rotated(offset), t.boss_attacks_aimed_speed, boss.damage_value * t.boss_attacks_aimed_damage)
	Sound.play("shoot_enemy", 1.0, 0.8)

func _on_boss_spiral(angle: float, arms: int) -> void:
	var boss := ctx.boss
	if boss == null:
		return
	var t := ctx.tuning
	for k in arms:
		var dir := Vector2.from_angle(angle + TAU * float(k) / float(arms))
		_spawn_boss_bullet(boss.pos2 + dir * (boss.radius + 8.0), dir, t.boss_attacks_spiral_speed, boss.damage_value * t.boss_attacks_spiral_damage)
	Sound.play("shoot_enemy", -3.0, 1.3)

func _on_boss_summon(kind: String, count: int) -> void:
	var boss := ctx.boss
	if boss == null:
		return
	for i in count:
		var offset := Vector2.from_angle(randf() * TAU) * randf_range(boss.radius + 20.0, boss.radius + 90.0)
		ctx.spawner.spawn_enemy(kind, boss.pos2 + offset, 0.35)
		ctx.run.add_alive(1)

func _on_boss_charge_warn(dir: Vector2, duration: float) -> void:
	var boss := ctx.boss
	if boss == null:
		return
	var reach: float = float(boss.stats.get("charge_speed", 760.0)) * float(boss.stats.get("charge_time", 0.5))
	var from := ArenaSpace.to_world(boss.pos2, 0.15)
	var to := ArenaSpace.to_world(boss.pos2 + dir * (reach + boss.radius), 0.15)
	ctx.sparks.beam(from, to, Color(1.0, 0.2, 0.25, 0.55), boss.radius / ArenaSpace.SCALE * 1.7, duration)
	ctx.sparks.ring(boss.position, Color(1.0, 0.3, 0.3), 5.0, 1.6, duration, 0.14)
	Sound.play("bomb_beep", 3.0, 0.7)
	Sound.play("elite", -5.0, 1.5)

func _on_boss_charge(_dir: Vector2) -> void:
	Sound.play("dash", 4.0, 0.55)
	Fx.shake(9.0)

func _on_boss_phase(_phase: int) -> void:
	var boss := ctx.boss
	if boss == null:
		return
	var sparks := ctx.sparks
	ctx.hud.show_banner(tr("ÖFKE FAZI"), tr("saldırılar hızlanıyor"), 1.8, KIT.RED)
	Sound.play("boss_phase")
	sparks.ring(boss.position, boss.color(), 1.0, 16.0, 0.8, 0.14, 1.0)
	sparks.burst(boss.position, boss.color(), 60, 15.0, 0.9, 1.6)
	sparks.flash(boss.position, boss.color(), 12.0, 18.0, 0.5)
	for at in ctx.field.clear_hostile(boss.pos2, 99999.0):
		sparks.burst(ArenaSpace.to_world(at, 1.0), boss.color(), 2, 3.0, 0.3, 0.8)
	Fx.shake(18.0)
	Fx.hitstop(0.1, 0.1)
	Fx.vibrate(90)

# --- Boss saldırıları: tehlike bölgeleri, dalgalar, ışınlar ---------------------------
func _on_boss_zone(at: Vector2, radius: float, delay: float, burst: int) -> void:
	var boss := ctx.boss
	at = at.clamp(ARENA.position + Vector2(40, 40), ARENA.end - Vector2(40, 40))
	var dmg: float = boss.damage_value * ctx.tuning.boss_attacks_zone_damage if boss != null else 25.0
	ctx.hazards.append({"pos2": at, "radius": radius, "t": delay, "max": delay, "dmg": dmg, "burst": burst, "kind": "slam"})
	var w := ArenaSpace.to_world(at, 0.0)
	var c := Color(1.0, 0.32, 0.12)
	ctx.sparks.ring(w, Color(c, 0.9), radius / ArenaSpace.SCALE, radius / ArenaSpace.SCALE, delay, 0.07, 0.6)
	ctx.sparks.ring(w, Color(c, 0.7), 0.1, radius / ArenaSpace.SCALE, delay, 0.9, 0.0)
	Sound.play("bomb_beep", -2.0, 0.8)

func tick_hazards(delta: float) -> void:
	var t := ctx.tuning
	var hazards := ctx.hazards
	var sparks := ctx.sparks
	var player := ctx.player
	for i in range(hazards.size() - 1, -1, -1):
		var h: Dictionary = hazards[i]
		h["t"] = float(h["t"]) - delta
		if float(h["t"]) > 0.0:
			continue
		hazards.remove_at(i)
		var at: Vector2 = h["pos2"]
		var r: float = h["radius"]
		var w := ArenaSpace.to_world(at, 0.2)
		var boss := ctx.boss
		var c := Color(1.0, 0.4, 0.12) if str(h["kind"]) != "leap" else (boss.color() if boss != null else Color(1, 0.4, 0.1))
		sparks.burst(w, c, 26, 11.0, 0.55, 1.3, 0.6)
		sparks.ring(w, c, r / ArenaSpace.SCALE * 0.4, r / ArenaSpace.SCALE * 1.15, 0.35, 0.25, 1.0)
		sparks.flash(w, c, 6.0, 9.0, 0.2)
		Sound.play("slam", -2.0 if str(h["kind"]) == "slam" else 2.0)
		Fx.shake(9.0 if str(h["kind"]) == "slam" else 18.0)
		if player.alive and player.pos2.distance_to(at) < r + player.radius * 0.5:
			player.take_damage(float(h["dmg"]), at)
		var burst := int(h["burst"])
		for k in burst:
			var dir := Vector2.from_angle(TAU * float(k) / float(burst) + randf() * 0.3)
			_spawn_boss_bullet(at + dir * 10.0, dir, t.boss_attacks_zone_burst_speed, float(h["dmg"]) * t.boss_attacks_zone_burst_damage)

func _on_boss_ring(count: int, gap: int, speed: float) -> void:
	var boss := ctx.boss
	if boss == null:
		return
	var start := randi() % count
	for i in count:
		if posmod(i - start, count) < gap:
			continue
		var dir := Vector2.from_angle(TAU * float(i) / float(count))
		_spawn_boss_bullet(boss.pos2 + dir * (boss.radius + 10.0), dir, speed, boss.damage_value * ctx.tuning.boss_attacks_ring_damage)
	ctx.sparks.ring(boss.position, boss.color(), 1.5, 6.0, 0.35, 0.18, 0.4)
	Sound.play("slam", -6.0, 1.3)
	Fx.shake(6.0)

func _on_boss_fan(dir: Vector2, count: int, arc: float, speed: float) -> void:
	var boss := ctx.boss
	if boss == null:
		return
	for i in count:
		var u := float(i) / float(maxi(1, count - 1)) - 0.5
		var d := dir.rotated(u * arc)
		_spawn_boss_bullet(boss.pos2 + d * (boss.radius + 6.0), d, speed * randf_range(0.95, 1.05), boss.damage_value * ctx.tuning.boss_attacks_fan_damage)
	Sound.play("shoot_enemy", 2.0, 0.65 if boss.kind == "titan" else 1.25)

func _on_boss_leap(to: Vector2, duration: float) -> void:
	var boss := ctx.boss
	if boss == null:
		return
	var t := ctx.tuning
	to = to.clamp(ARENA.position + Vector2(boss.radius, boss.radius), ARENA.end - Vector2(boss.radius, boss.radius))
	boss._leap_to = to
	var r := float(boss.stats.get("leap_radius", 150.0))
	ctx.hazards.append({"pos2": to, "radius": r, "t": duration, "max": duration, "dmg": boss.damage_value * t.boss_attacks_leap_damage, "burst": t.boss_attacks_leap_burst, "kind": "leap"})
	var w := ArenaSpace.to_world(to, 0.0)
	ctx.sparks.ring(w, Color(1.0, 0.2, 0.15, 0.95), r / ArenaSpace.SCALE, r / ArenaSpace.SCALE, duration, 0.06, 0.8)
	ctx.sparks.ring(w, Color(1.0, 0.3, 0.15, 0.8), 0.2, r / ArenaSpace.SCALE, duration, 0.9, 0.0)
	Sound.play("leap")
	ctx.hud.toast(tr("SIÇRAMA — dairenin dışına çık!"), KIT.RED, 1.0)

func _on_boss_blink_warn(to: Vector2, delay: float) -> void:
	var boss := ctx.boss
	if boss == null:
		return
	var fixed: Vector2 = to.clamp(ARENA.position + Vector2(140, 140), ARENA.end - Vector2(140, 140))
	for i in 8:
		if not ArenaGeometry.point_blocked(ctx.obstacles, fixed, boss.radius + 20.0):
			break
		fixed = (fixed + (ARENA.get_center() - fixed).normalized() * 80.0)
	boss.set_blink_target(fixed)
	var w := ArenaSpace.to_world(fixed, 0.0)
	ctx.sparks.ring(w, Color(0.6, 0.9, 1.0), 5.0, 1.6, delay, 0.12, 0.5)
	ctx.sparks.burst(boss.position, boss.color(), 18, 7.0, 0.5, 1.0)
	Sound.play("teleport", -4.0, 0.8)

func _on_boss_blinked(from: Vector2, to: Vector2) -> void:
	var boss := ctx.boss
	if boss == null:
		return
	var t := ctx.tuning
	var sparks := ctx.sparks
	sparks.burst(ArenaSpace.to_world(from, 1.5), Color(0.75, 0.95, 1.0), 26, 10.0, 0.5, 1.2)
	sparks.burst(ArenaSpace.to_world(to, 1.5), Color(0.75, 0.95, 1.0), 30, 10.0, 0.6, 1.3)
	sparks.ring(ArenaSpace.to_world(to, 0.0), boss.color(), 1.0, 7.0, 0.4, 0.15)
	sparks.lightning(ArenaSpace.to_world(from, 1.5), ArenaSpace.to_world(to, 1.5), Color(0.7, 0.95, 1.0), 0.09, 0.25)
	var n := t.boss_attacks_blink_bullets
	for k in n:
		var dir := Vector2.from_angle(TAU * float(k) / float(n))
		_spawn_boss_bullet(from + dir * 20.0, dir, t.boss_attacks_blink_speed, boss.damage_value * t.boss_attacks_blink_damage)
	Sound.play("teleport")
	Fx.shake(6.0)

func tick_beams() -> void:
	## Buz Hükümdarı lazerleri: uyarıda ince çizgi, ateşte kalın ışın + çarpışma.
	var boss := ctx.boss
	if boss == null or not is_instance_valid(boss) or not boss.alive or boss.beam_state == Boss3D.BEAM_IDLE:
		return
	var player := ctx.player
	var sparks := ctx.sparks
	var elapsed := ctx.elapsed
	var origin: Vector2 = boss.pos2
	var from3 := ArenaSpace.to_world(origin, 1.0)
	var firing: bool = boss.beam_state == Boss3D.BEAM_FIRE
	for angle in boss.beam_angles:
		var dir := Vector2.from_angle(angle)
		var end: Vector2 = origin + dir * boss.beam_length
		var to3 := ArenaSpace.to_world(end, 1.0)
		if firing:
			var flicker := 0.85 + 0.15 * sin(elapsed * 60.0)
			sparks.beam(from3, to3, Color(0.4, 0.85, 1.0, 0.7), boss.beam_width / ArenaSpace.SCALE * 1.4 * flicker, 0.035)
			sparks.beam(from3, to3, Color(0.95, 1.0, 1.0, 0.95), boss.beam_width / ArenaSpace.SCALE * 0.45, 0.035)
			if randf() < 0.5:
				sparks.spray(to3, -ArenaSpace.dir_to_world(dir), Color(0.7, 0.95, 1.0), 2, 6.0, 0.25, 0.8)
			if player.alive:
				var ab := end - origin
				var u := clampf((player.pos2 - origin).dot(ab) / ab.length_squared(), 0.0, 1.0)
				if (origin + ab * u).distance_to(player.pos2) < boss.beam_width + player.radius:
					player.take_damage(boss.damage_value * float(boss.stats.get("beam_damage", 0.5)), origin + ab * u)
		else:
			sparks.beam(from3, to3, Color(1.0, 0.3, 0.4, 0.35 + 0.25 * sin(elapsed * 30.0)), 0.05, 0.035)
	if firing and fmod(elapsed, 0.25) < ctx.host.get_process_delta_time():
		Sound.play("laser", -6.0)

func _on_boss_dying() -> void:
	var boss := ctx.boss
	dying = true
	_boss_pop = 0.0
	for at in ctx.field.clear_hostile(boss.pos2, 99999.0):
		ctx.sparks.burst(ArenaSpace.to_world(at, 1.0), boss.color(), 2, 3.0, 0.3, 0.8)
	ctx.run.pending.clear()
	for e in ctx.enemies:
		if is_instance_valid(e) and not e.dead:
			e.dead = true
	Sound.play("boss_die")
	Fx.hitstop(0.25, 0.25)

func _on_boss_killed() -> void:
	var boss := ctx.boss
	if boss == null:
		return
	var sparks := ctx.sparks
	var at: Vector3 = boss.position
	sparks.burst(at, boss.color(), 90, 20.0, 1.4, 2.0)
	sparks.burst(at, Color(1, 1, 1), 40, 14.0, 0.9, 1.4)
	sparks.ring(at, boss.color(), 1.0, 22.0, 0.9, 0.16, 1.0)
	sparks.ring(at, Color(1, 1, 1), 0.5, 15.0, 0.6, 0.08)
	sparks.flash(at, boss.color(), 16.0, 26.0, 0.6)
	Sound.play("explode_big", 3.0, 0.7)
	Fx.shake(28.0)
	Fx.vibrate(200)
	ctx.world.flash_pulse(at, 1.0)
	ctx.menus.flash(Color(1, 1, 1), 0.35, 0.6)
	ctx.hud.float_text(at, "+%d" % boss.points(), KIT.GOLD, 34, 1.4)
	var drop_at: Vector2 = boss.pos2
	for kind in ["heal", "shield", "overdrive"]:
		ctx.spawner.spawn_pickup(drop_at + Vector2.from_angle(randf() * TAU) * randf_range(30.0, 90.0), kind)
	ctx.combat.add_nova(ctx.tuning.nova_boss_kill_gain)
	var kind_name := str(boss.kind)
	ctx.boss = null
	dying = false
	boss.queue_free()
	ctx.world.set_danger(false)
	Sound.music("battle", 1.5)
	ctx.events.boss_killed.emit(kind_name)
	ctx.run.boss_died()
