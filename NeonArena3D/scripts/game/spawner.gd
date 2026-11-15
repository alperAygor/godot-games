extends GameModule
class_name Spawner
## Düşman/toplanabilir doğurma, dalga temposu (av modu), düşman hareketinin arena kuralları (engel kaçınma,
## itme, sınır, birbirinden ayrılma). Ne zaman/hangi tür doğacağına RunState karar verir (spawn_due sinyali).

const EnemyScript = preload("res://scripts/entities3d/enemy3d.gd")
const PickupScript = preload("res://scripts/entities3d/pickup3d.gd")

var wave_time := 0.0
var _hunt_timer := 0.0

func on_wave_started(wave: int) -> void:
	var t := ctx.tuning
	wave_time = 0.0
	_hunt_timer = t.run_hunt_after
	if ctx.world != null and is_instance_valid(ctx.world):
		ctx.world.flash_pulse(ctx.player.position, 1.0)
	if not ctx.run.is_boss_wave(wave):
		Sound.play("wave_start")
		ctx.hud.show_banner(tr("DALGA %02d") % wave, tr("%d düşman") % ctx.run.pending.size(), 1.7)

func tick_pacing(delta: float) -> void:
	## Uzun süren dalgada kalan düşmanlar oyuncuya ışınlanır: soft-lock olmaz.
	var t := ctx.tuning
	wave_time += delta
	_hunt_timer -= delta
	if _hunt_timer <= 0.0 and wave_time > t.run_hunt_after and ctx.run.phase in [RunState.PHASE_BATTLE, RunState.PHASE_BOSS]:
		_hunt_timer = t.run_hunt_every
		_hunt_stragglers()

func _hunt_stragglers() -> void:
	var enemies := ctx.enemies
	var sparks := ctx.sparks
	var moved := 0
	for e in enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		moved += 1
		sparks.burst(e.position, e.color(), 10, 5.0, 0.4, 0.9)
		e.pos2 = spawn_point()
		e.position = ArenaSpace.to_world(e.pos2, 0.9)
		sparks.burst(e.position, e.color(), 12, 6.0, 0.45, 1.0)
	if moved > 0:   # liste yalnız ölü düşman tutuyorsa (henüz biçilmemiş) "yaklaşıyor" uyarısı yanlış olurdu
		ctx.hud.toast(tr("AV MODU — kalan düşmanlar yaklaşıyor"), KIT.RED, 1.8)
		Sound.play("elite", -4.0, 1.2)

func tick_enemies(delta: float) -> void:
	## Düşman adımı: ölüleri biçer, hareket + engel + sınır, bombacı fitili, ateş isteği.
	var enemies := ctx.enemies
	var obstacles := ctx.obstacles
	var player_pos: Vector2 = ctx.player.pos2
	for i in range(enemies.size() - 1, -1, -1):
		var e = enemies[i]
		if not is_instance_valid(e):
			enemies.remove_at(i)
			continue
		if e.dead:
			enemies.remove_at(i)
			ctx.combat.reap(e)
			continue
		var wants_fire: bool = e.tick(delta, player_pos)
		if not e.is_spawning():
			e.pos2 += ArenaGeometry.avoid(obstacles, e.pos2, e.radius) * 90.0 * delta
			e.pos2 = ArenaGeometry.push_out(obstacles, e.pos2, e.radius)
		e.pos2.x = clampf(e.pos2.x, ARENA.position.x + e.radius, ARENA.end.x - e.radius)
		e.pos2.y = clampf(e.pos2.y, ARENA.position.y + e.radius, ARENA.end.y - e.radius)
		if e.fuse >= 0.0 and not e.fuse_started:
			e.fuse_started = true
			var blast_r: float = float(e.stats.get("explode_radius", 120.0)) / ArenaSpace.SCALE
			ctx.sparks.ring(e.position, Color(1.0, 0.3, 0.12, 0.9), blast_r, blast_r, float(e.stats.get("fuse_time", 0.55)), 0.1, 1.0)
			Sound.play("bomb_beep")
		if wants_fire:
			ctx.weapons.fire_enemy_bullet(e)
		if e.explode_now:
			e.dead = true

func tick_effects_only(delta: float) -> void:
	## Ölüm ekranı arkasında dünya akmaya devam eder (oyuncu yok).
	var enemies := ctx.enemies
	var player_pos: Vector2 = ctx.player.pos2
	for i in range(enemies.size() - 1, -1, -1):
		var e = enemies[i]
		if not is_instance_valid(e):
			enemies.remove_at(i)
			continue
		e.tick(delta, player_pos)
	ctx.field.tick(delta)
	if ctx.boss != null and is_instance_valid(ctx.boss):
		ctx.boss.tick(delta, player_pos)

func separate_enemies() -> void:
	var enemies := ctx.enemies
	for i in enemies.size():
		var a = enemies[i]
		if not is_instance_valid(a) or a.dead or a.is_spawning():
			continue
		for j in range(i + 1, enemies.size()):
			var b = enemies[j]
			if not is_instance_valid(b) or b.dead or b.is_spawning():
				continue
			var diff: Vector2 = b.pos2 - a.pos2
			var min_dist: float = a.radius + b.radius + 2.0
			var dist_sq := diff.length_squared()
			if dist_sq > 0.0001 and dist_sq < min_dist * min_dist:
				var dist := sqrt(dist_sq)
				var push: Vector2 = diff / dist * (min_dist - dist) * 0.5
				a.pos2 -= push
				b.pos2 += push

func tick_pickups(delta: float) -> void:
	var pickups := ctx.pickups
	var player_pos: Vector2 = ctx.player.pos2
	var pull: float = ctx.tuning.run_magnet_pull * ctx.loadout.m("magnet")
	for i in range(pickups.size() - 1, -1, -1):
		var p = pickups[i]
		if not is_instance_valid(p) or not p.tick(delta, player_pos, pull):
			if is_instance_valid(p):
				p.queue_free()
			pickups.remove_at(i)

func on_spawn_due(kind: String) -> void:
	spawn_enemy(kind, spawn_point(), 0.6)

func spawn_point(override_min := 0.0, override_max := 0.0) -> Vector2:
	var min_r: float = GameData.number("waves.spawn_radius_min", 620.0) if override_min <= 0.0 else override_min
	var max_r: float = GameData.number("waves.spawn_radius_max", 980.0) if override_max <= 0.0 else override_max
	var player_pos: Vector2 = ctx.player.pos2
	for i in 30:
		var angle := randf() * TAU
		var dist := randf_range(min_r, max_r)
		var p: Vector2 = player_pos + Vector2.from_angle(angle) * dist
		p.x = clampf(p.x, ARENA.position.x + 70.0, ARENA.end.x - 70.0)
		p.y = clampf(p.y, ARENA.position.y + 70.0, ARENA.end.y - 70.0)
		if p.distance_to(player_pos) > 300.0 and not ArenaGeometry.point_blocked(ctx.obstacles, p, 50.0):
			return p
	return ARENA.get_center() + Vector2(0, 400)

func spawn_enemy(kind: String, at: Vector2, delay := 0.5, allow_elite := true) -> void:
	var run := ctx.run
	var elite_def: Dictionary = {}
	if allow_elite and kind != "swarmer":
		var def: Dictionary = GameData.elite_def()
		if not def.is_empty() and run.wave >= int(def.get("from_wave", 4)) and not run.is_boss_wave(run.wave):
			var chance := minf(float(def.get("chance_max", 0.16)), float(def.get("chance", 0.05)) + float(def.get("chance_per_wave", 0.006)) * float(run.wave))
			if randf() < chance:
				elite_def = def
	var e = EnemyScript.new()
	var stats: Dictionary = GameData.enemy_stats(kind)
	stats["spawn_delay"] = delay
	e.setup(kind, stats, run.hp_scale(), run.damage_scale(), run.speed_scale(), elite_def)
	e.pos2 = at
	e.position = ArenaSpace.to_world(at, 0.3)
	ctx.entities.add_child(e)
	ctx.enemies.append(e)
	var c: Color = KIT.GOLD if e.elite else e.color()
	var r: float = e.radius / ArenaSpace.SCALE
	ctx.sparks.ring(e.position, c, r * 4.0, r * 1.1, delay, 0.14, 1.0)
	ctx.sparks.burst(e.position, c, 6, 4.0, 0.4, 0.8)
	if e.elite:
		Sound.play("elite")
		ctx.hud.toast(tr("ELİT DÜŞMAN"), KIT.GOLD, 1.2)
	else:
		Sound.play("spawn")

func spawn_pickup(at: Vector2, kind: String) -> void:
	var p = PickupScript.new()
	at.x = clampf(at.x, ARENA.position.x + 30.0, ARENA.end.x - 30.0)
	at.y = clampf(at.y, ARENA.position.y + 30.0, ARENA.end.y - 30.0)
	p.setup(kind, ArenaGeometry.push_out(ctx.obstacles, at, 20.0))
	ctx.entities.add_child(p)
	ctx.pickups.append(p)

func roll_pickup() -> String:
	var r := randf()
	var shield_w: float = GameData.number("pickups.shield_weight", 0.16)
	var od_w: float = GameData.number("pickups.overdrive_weight", 0.26)
	if r < shield_w and ctx.player.shield <= 0:
		return "shield"
	if r < shield_w + od_w:
		return "overdrive"
	return "heal"
