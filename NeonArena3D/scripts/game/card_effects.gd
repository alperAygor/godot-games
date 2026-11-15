extends GameModule
class_name CardEffects
## C3 kart etkileri: yeni kartların (yörünge bıçakları, taret, sekme, infaz, kara delik, plazma izi…), evrimlerin ve
## lanet bedellerinin oyundaki karşılığı + kart ekranı eklentileri (yasaklama satırı, evrim yolu ipucu).
##
## Diğer modüller buraya yalnız KANCA çağırır (her biri tek satır):
##   WeaponSystem.on_player_shot  → shot_damage_mult(), on_shot()        drone mermisi → drone_bullet(b)
##   CombatSystem.hit_enemy       → enemy_damage_mult(e), on_hit(e, b)   mermi durdu → on_bullet_stopped(e, b)
##   CombatSystem.reap            → on_kill(e)    heal → heal_mult()     nova → nova_radius_mult(), on_nova()
##   CombatSystem.on_player_hurt  → on_hurt(amount)   apply_pickup → on_pickup(kind)   reset_run → reset_run()
##   PlayerControl.apply_loadout  → on_loadout_applied()   game3d: tick(delta), player.dashed_at/shield_broken
## Sayılar: data/card_rules.json → params (kurulumda bir kez okunur; kare başına sözlük yolu yok).
## Kare başına bellek ayırma yok: taret/iz/hedef dizileri önceden ayrılır, görseller Sparks üzerinden (düğüm yok → sızıntı yok).
## LANETLİ KART (C1 kapısı): `apply_curse(id)` → Loadout.apply_curse + gemi istatistiklerini yeniler. Liste/bilgi için
## Loadout.cursed_cards() / Loadout.curse_info(card) (bkz. scripts/core/loadout.gd başı).

const BulletFieldScript = preload("res://scripts/world/bullet_field.gd")
const MAX_TARGETS := 8
## Mermi `chain` alanı işaretleri: 0 = normal mermi (zincir/sekme/bölünme tetikler), 1 = türev mermi (tetiklemez),
## RICOCHET_BASE + n = sekmiş mermi, n sekme hakkı kaldı.
const RICOCHET_BASE := 100

# Sayılar (card_rules.json → params)
var p := {}
var _blade_radius := 58.0
var _blade_spin := 3.4
var _blade_hit := 24.0
var _blade_pulse := 0.15
var _blade_damage := 1.0

# Koşu durumu
var _blade_angle := 0.0
var _blade_timer := 0.0
var _turret_pos := PackedVector2Array()
var _turret_life := PackedFloat32Array()
var _turret_cd := PackedFloat32Array()
var _turret_count := 0
var _trail_pos := PackedVector2Array()
var _trail_life := PackedFloat32Array()
var _trail_head := 0
var _trail_timer := 0.0
var _static_timer := 0.0
var _missile_timer := 0.0
var _kill_count := 0
var _base_rate := 1.0
var _base_speed := 360.0
var _targets: Array = []
var _hint: Label
var _banish_row: HBoxContainer
var _banish_buttons: Array = []
var _shown: Array = []

func setup(context: GameContext) -> void:
	super.setup(context)
	p = (Loadout.load_rules().get("params", {}) as Dictionary)
	_blade_radius = _n("orbit_radius")
	_blade_spin = _n("orbit_spin")
	_blade_hit = _n("orbit_hit_radius")
	_blade_pulse = maxf(0.03, _n("orbit_pulse"))
	_blade_damage = _n("orbit_damage")
	var trail_points := maxi(4, int(_n("trail_points", 32.0)))
	_trail_pos.resize(trail_points)
	_trail_life.resize(trail_points)
	_turret_pos.resize(4)
	_turret_life.resize(4)
	_turret_cd.resize(4)
	_targets.resize(MAX_TARGETS)

func _n(key: String, fallback := 0.0) -> float:
	return float(p.get(key, fallback))

func reset_run() -> void:
	_blade_angle = 0.0
	_blade_timer = 0.0
	_turret_count = 0
	_trail_life.fill(0.0)
	_trail_head = 0
	_trail_timer = 0.0
	_static_timer = 0.0
	_missile_timer = 0.0
	_kill_count = 0

func _dmg() -> float:
	return ctx.tuning.player_damage * ctx.loadout.m("damage_mult")

# --- Ateş -----------------------------------------------------------------------------
func shot_damage_mult() -> float:
	## Ana silah mermisi hasar çarpanı: çok mermi cezası, ivme, sabit nişan, kombo motoru.
	var l := ctx.loadout
	var player := ctx.player
	var mult := 1.0
	if l.i("projectiles") > 1:
		mult *= l.m("projectile_damage_mult")
	var speed_ratio := clampf(player.velocity2.length() / maxf(1.0, player.speed), 0.0, 1.0)
	if l.m("momentum") > 0.0:
		mult *= 1.0 + l.m("momentum") * speed_ratio
	if l.m("steady") > 0.0 and speed_ratio < _n("steady_speed_ratio", 0.25):
		mult *= 1.0 + l.m("steady")
	if l.m("combo_power") > 0.0:
		mult *= 1.0 + minf(_n("combo_cap", 0.45), l.m("combo_power") * float(ctx.run.combo))
	return mult

func on_shot(origin: Vector2, direction: Vector2, damage: float, size: float) -> void:
	var rear := ctx.loadout.i("rear_guns")
	if rear <= 0:
		return
	var back := -direction
	var dmg := damage * _n("rear_damage", 0.7)
	for k in rear:
		var off := 0.0 if rear == 1 else (float(k) - 0.5) * _n("rear_spread", 0.45)
		var b = ctx.field.spawn(origin - direction * 30.0, back.rotated(off), 900.0, true, dmg, 0.6, size * 0.85)
		b.chain = 1

func drone_bullet(b) -> void:
	if ctx.loadout.i("evo_swarm") > 0:
		b.pierce = int(_n("swarm_drone_pierce", 2))
		b.damage *= _n("swarm_drone_damage", 1.5)

# --- İsabet ---------------------------------------------------------------------------
func enemy_damage_mult(e) -> float:
	var hunter := ctx.loadout.m("hunter")
	return 1.0 + hunter if hunter > 0.0 and e.elite else 1.0

func boss_damage_mult() -> float:
	return 1.0 + ctx.loadout.m("hunter")

func on_hit(e, b) -> void:
	## Mermi düşmana değdi (hasar uygulandı). İnfaz, kristal kırılma (kritik), bölünme (öldürünce).
	var l := ctx.loadout
	var execute := l.m("execute")
	if execute > 0.0 and not e.dead:
		var threshold := _n("execute_base", 0.12) + _n("execute_per_level", 0.08) * (execute - 1.0)
		if e.hp < e.max_hp * threshold:
			e.take_damage(e.hp + 1.0)
			ctx.sparks.burst(e.position, Color(1.0, 0.3, 0.3), 10, 9.0, 0.3, 1.0)
	if b.chain != 0:
		return
	var shards := l.i("crit_shards")
	if shards > 0 and b.crit:
		var n := int(_n("shard_count", 3.0)) + int(_n("shard_per_level", 2.0)) * (shards - 1)
		_burst_bullets(e.pos2, b.velocity2.angle(), n, TAU, b.damage * _n("shard_damage", 0.55), _n("shard_speed", 700.0), _n("shard_life", 0.3), Color(1.0, 0.85, 0.4))
	var split := l.i("split_shot")
	if split > 0 and e.dead:
		var a := _n("split_angle", 0.6)
		_burst_bullets(e.pos2, b.velocity2.angle(), int(_n("split_count", 2.0)) * split, a * 2.0, b.damage * _n("split_damage", 0.5), _n("split_speed", 760.0), _n("split_life", 0.35), Color(0.6, 1.0, 0.9))

func _burst_bullets(at: Vector2, heading: float, n: int, arc: float, dmg: float, speed: float, life: float, tint: Color) -> void:
	for k in n:
		var u := (float(k) + 0.5) / float(n) - 0.5 if arc < TAU else float(k) / float(n)
		var dir := Vector2.from_angle(heading + u * arc)
		var nb = ctx.field.spawn(at + dir * 16.0, dir, speed, true, dmg, life, 0.7, false, tint)
		nb.chain = 1

func on_bullet_stopped(e, b) -> void:
	## Mermi düşmanda durdu (delme hakkı bitti): Sekme.
	var bounces := 0
	if b.chain == 0:
		bounces = ctx.loadout.i("ricochet")
	elif b.chain > RICOCHET_BASE:
		bounces = b.chain - RICOCHET_BASE
	if bounces <= 0:
		return
	var next = _nearest_enemy(e.pos2, _n("ricochet_range", 300.0), e)
	if next == null:
		return
	var dir: Vector2 = (next.pos2 - e.pos2).normalized()
	var nb = ctx.field.spawn(e.pos2 + dir * (e.radius + 4.0), dir, maxf(700.0, b.velocity2.length()), true, b.damage * _n("ricochet_damage", 0.7), 0.5, b.size, b.crit)
	nb.chain = RICOCHET_BASE + bounces - 1
	nb.hits.append(e.get_instance_id())

func _nearest_enemy(from: Vector2, radius: float, skip = null):
	var best = null
	var best_d := radius
	for o in ctx.enemies:
		if o == skip or o.dead or o.is_spawning():
			continue
		var d: float = o.pos2.distance_to(from)
		if d < best_d:
			best_d = d
			best = o
	return best

# --- Öldürme / iyileşme / toplanabilir --------------------------------------------------
func on_kill(e) -> void:
	var l := ctx.loadout
	if l.i("kill_shield") > 0:
		_kill_count += 1
		var list: Array = p.get("kill_shield_kills", [30, 20])
		var need := int(list[mini(l.i("kill_shield"), list.size()) - 1])
		if _kill_count >= need and ctx.player.shield <= 0:
			_kill_count = 0
			ctx.combat.give_shield()
	if l.m("hunter") > 0.0 and e.elite:
		for k in int(_n("hunter_extra_drops", 1.0)):
			ctx.spawner.spawn_pickup(e.pos2 + Vector2(18.0 * float(k + 1), 0.0), ctx.spawner.roll_pickup())

func vampire_mult() -> float:
	return _n("bloodmoon_vampire", 2.0) if ctx.loadout.i("evo_bloodmoon") > 0 else 1.0

func nova_kill_mult() -> float:
	return _n("overdrive_nova_mult", 2.0) if ctx.loadout.i("overdrive_plus") > 0 and ctx.player.overdrive > 0.0 else 1.0

func chain_range_mult() -> float:
	return _n("thunder_chain_range", 1.5) if ctx.loadout.i("evo_thunder") > 0 else 1.0

func heal_mult() -> float:
	return ctx.loadout.m("heal_mult")

func harvest_threshold() -> float:
	return _n("bloodmoon_shield_at", 25.0) if ctx.loadout.i("evo_bloodmoon") > 0 else ctx.tuning.run_harvest_shield_at

func on_pickup(kind: String) -> void:
	var l := ctx.loadout
	var player := ctx.player
	if kind == "overdrive" and l.i("overdrive_plus") > 0:
		player.overdrive *= _n("overdrive_time_mult", 2.0)
	var pb := l.i("pickup_blast")
	if pb > 0:
		var r := _n("pickup_blast_radius", 220.0)
		ctx.combat.area_damage(player.pos2, r, _dmg() * _n("pickup_blast_damage", 4.0) * (1.0 + _n("pickup_blast_per_level", 0.5) * float(pb - 1)))
		ctx.combat.add_nova(_n("pickup_blast_nova", 10.0))
		ctx.sparks.ring(player.position, Color(0.5, 1.0, 0.8), 0.4, r / ArenaSpace.SCALE, 0.35, 0.2, 1.0)
		Sound.play("explode", -4.0, 1.2)

# --- Nova -----------------------------------------------------------------------------
func nova_radius_mult() -> float:
	return _n("singularity_radius", 1.4) if ctx.loadout.i("evo_singularity") > 0 else 1.0

func on_nova(radius: float, damage: float) -> void:
	var l := ctx.loadout
	var player := ctx.player
	if l.i("nova_vortex") > 0:
		var reach := radius * _n("vortex_reach_mult", 1.7)
		var pull := _n("vortex_pull", 520.0)
		for e in ctx.enemies:
			if e.dead or e.is_spawning():
				continue
			var to: Vector2 = player.pos2 - e.pos2
			var d := to.length()
			if d < reach and d > 1.0:
				e.knock2 += to / d * pull * minf(1.0, d / 200.0)
		var mult := _n("singularity_vortex", 1.5) if l.i("evo_singularity") > 0 else 1.0
		ctx.aftershocks.append({"pos2": player.pos2, "t": _n("vortex_delay", 0.55), "dmg": damage * _n("vortex_damage", 0.8) * mult, "r": _n("vortex_radius", 230.0)})
		ctx.sparks.ring(player.position, Color(0.55, 0.3, 1.0), reach / ArenaSpace.SCALE, 0.5, 0.55, 0.25, 0.6)
	if l.i("nova_shell") > 0:
		ctx.combat.give_shield()
		ctx.combat.heal(_n("nova_shell_heal", 15.0))
	if l.i("evo_singularity") > 0:
		ctx.combat.add_nova(_n("singularity_refund", 30.0))

# --- Hasar alma / kalkan / atılma ------------------------------------------------------
func on_hurt(amount: float) -> float:
	## Oyuncu `amount` hasar aldı (can zaten düştü). Çelik Gövde iade eder, lanet (hurt_mult) ekler. Gerçek hasarı döner.
	var l := ctx.loadout
	var player := ctx.player
	var real := amount
	var plating := l.m("plating")
	if plating > 0.0:
		real = maxf(_n("plating_min", 1.0), amount - plating)
		player.hp = minf(player.max_hp, player.hp + (amount - real))
		if player.hp > 0.0 and not player.alive:
			player.alive = true
	var hurt := l.m("hurt_mult")
	if hurt > 1.0:
		var extra := real * (hurt - 1.0)
		player.hp -= extra
		real += extra
		if player.hp <= 0.0:
			player.hp = 0.0
			player.alive = false
	return real

func on_shield_broken() -> void:
	if ctx.loadout.i("shield_bash") <= 0:
		return
	var player := ctx.player
	var r := _n("shield_bash_radius", 210.0)
	ctx.combat.area_damage(player.pos2, r, _dmg() * _n("shield_bash_damage", 5.0))
	player.invuln = maxf(player.invuln, _n("shield_bash_invuln", 1.0))
	ctx.sparks.ring(player.position, Color(0.5, 0.8, 1.0), 0.5, r / ArenaSpace.SCALE, 0.4, 0.22, 1.0)
	ctx.sparks.burst(player.position, Color(0.6, 0.9, 1.0), 30, 12.0, 0.5, 1.3)
	Sound.play("explode", -2.0, 1.1)
	Fx.shake(7.0)

func on_dash(at: Vector2, dir: Vector2) -> void:
	var l := ctx.loadout
	if l.m("dash_nova") > 0.0:
		ctx.combat.add_nova(l.m("dash_nova"))
	var turrets := l.i("turret")
	if turrets > 0:
		if _turret_count >= mini(turrets, _turret_pos.size()):
			for k in _turret_count - 1:
				_turret_pos[k] = _turret_pos[k + 1]
				_turret_life[k] = _turret_life[k + 1]
				_turret_cd[k] = _turret_cd[k + 1]
			_turret_count -= 1
		_turret_pos[_turret_count] = at
		_turret_life[_turret_count] = _n("turret_life", 6.0)
		_turret_cd[_turret_count] = 0.2
		_turret_count += 1
		ctx.sparks.ring(ArenaSpace.to_world(at, 0.5), Color(0.5, 1.0, 0.7), 0.2, 1.4, 0.3, 0.2)
	var slam := l.i("dash_blast")
	if slam > 0:
		var t := ctx.tuning
		var dash_time := GameData.number("player.dash_time", 0.15)
		var end := at + dir * GameData.number("player.dash_speed", 1250.0) * dash_time
		end = Vector2(clampf(end.x, ARENA.position.x, ARENA.end.x), clampf(end.y, ARENA.position.y, ARENA.end.y))
		var mult := _n("comet_blast_mult", 2.0) if l.i("evo_comet") > 0 else 1.0
		ctx.aftershocks.append({"pos2": end, "t": dash_time, "r": _n("dash_blast_radius", 120.0) + _n("dash_blast_per_level", 40.0) * float(slam - 1),
			"dmg": t.player_damage * l.m("damage_mult") * _n("dash_blast_damage", 3.0) * mult})

func _trail_level() -> int:
	var l := ctx.loadout
	return maxi(l.i("dash_trail"), int(_n("comet_trail", 1.0)) if l.i("evo_comet") > 0 else 0)

# --- Kare ------------------------------------------------------------------------------
func on_loadout_applied() -> void:
	_base_rate = ctx.player.fire_rate_mult
	_base_speed = ctx.player.speed

func tick(delta: float) -> void:
	var l := ctx.loadout
	var player := ctx.player
	if not player.alive:
		return
	if l.i("adrenaline") > 0:
		var low := player.hp < player.max_hp * _n("adrenaline_hp", 0.4)
		player.fire_rate_mult = _base_rate * (1.0 + _n("adrenaline_rate", 0.5) if low else 1.0)
		player.speed = _base_speed * (1.0 + _n("adrenaline_speed", 0.15) if low else 1.0)
	if l.i("orbit_blades") > 0:
		_tick_blades(delta, l.i("orbit_blades"))
	if _turret_count > 0:
		_tick_turrets(delta)
	var trail := _trail_level()
	if trail > 0:
		_tick_trail(delta, trail)
	if l.i("static_field") > 0:
		_tick_static(delta, l.i("static_field"))
	if l.i("missile_pod") > 0:
		_tick_missiles(delta, l.i("missile_pod"))
	if l.i("reflect") > 0 and player.is_dashing():
		_reflect()

func _tick_blades(delta: float, count: int) -> void:
	var player := ctx.player
	_blade_angle = fmod(_blade_angle + delta * _blade_spin, TAU)
	for k in count:
		var at := player.pos2 + Vector2.from_angle(_blade_angle + TAU * float(k) / float(count)) * _blade_radius
		ctx.sparks.glow_add(ArenaSpace.to_world(at, 0.0).x, ArenaSpace.to_world(at, 0.0).z, 0.7, Color(1.0, 0.8, 0.4, 0.5))
	_blade_timer -= delta
	if _blade_timer > 0.0:
		return
	_blade_timer = _blade_pulse
	var dmg := _dmg() * _blade_damage
	var boss := ctx.boss
	for k in count:
		var at := player.pos2 + Vector2.from_angle(_blade_angle + TAU * float(k) / float(count)) * _blade_radius
		var w := ArenaSpace.to_world(at, 1.0)
		ctx.sparks.trail(w, ArenaSpace.dir_to_world(Vector2.from_angle(_blade_angle + TAU * float(k) / float(count) + PI * 0.5)), Color(1.0, 0.85, 0.45), 1.6)
		for e in ctx.enemies:
			if e.dead or e.is_spawning():
				continue
			var rr: float = _blade_hit + e.radius
			if e.pos2.distance_squared_to(at) < rr * rr:
				e.take_damage(dmg, (e.pos2 - player.pos2).normalized() * 60.0)
				ctx.sparks.burst(e.position, Color(1.0, 0.85, 0.45), 3, 6.0, 0.2, 0.7)
		if boss != null and is_instance_valid(boss) and boss.alive and boss.intro <= 0.0 and boss.pos2.distance_to(at) < _blade_hit + boss.radius:
			boss.take_damage(dmg)

func _tick_turrets(delta: float) -> void:
	var k := 0
	var dmg := _dmg() * _n("turret_damage", 0.85)
	var reach := _n("turret_range", 560.0)
	while k < _turret_count:
		_turret_life[k] -= delta
		if _turret_life[k] <= 0.0:
			for j in range(k, _turret_count - 1):
				_turret_pos[j] = _turret_pos[j + 1]
				_turret_life[j] = _turret_life[j + 1]
				_turret_cd[j] = _turret_cd[j + 1]
			_turret_count -= 1
			continue
		var at: Vector2 = _turret_pos[k]
		var w := ArenaSpace.to_world(at, 0.0)
		ctx.sparks.glow_add(w.x, w.z, 1.1, Color(0.4, 1.0, 0.7, 0.45))
		_turret_cd[k] -= delta
		if _turret_cd[k] <= 0.0:
			var target = _nearest_enemy(at, reach)
			var tpos := Vector2.ZERO
			var has := target != null
			if has:
				tpos = target.pos2
			elif ctx.boss != null and is_instance_valid(ctx.boss) and ctx.boss.alive and ctx.boss.intro <= 0.0 and ctx.boss.pos2.distance_to(at) < reach:
				tpos = ctx.boss.pos2
				has = true
			if has:
				_turret_cd[k] = _n("turret_interval", 0.42)
				var dir := (tpos - at).normalized()
				var b = ctx.field.spawn(at + dir * 14.0, dir, _n("turret_bullet_speed", 900.0), true, dmg, 0.8, 0.9, false, Color(0.45, 1.0, 0.7))
				b.chain = 1
				ctx.sparks.spray(ArenaSpace.to_world(at, 1.0), ArenaSpace.dir_to_world(dir), Color(0.5, 1.0, 0.7), 2, 6.0, 0.12, 0.7)
		k += 1

func _tick_trail(delta: float, level: int) -> void:
	var player := ctx.player
	var n := _trail_pos.size()
	if player.is_dashing():
		var last: Vector2 = _trail_pos[(_trail_head - 1 + n) % n]
		if _trail_life[(_trail_head - 1 + n) % n] <= 0.0 or last.distance_to(player.pos2) > 14.0:
			_trail_pos[_trail_head] = player.pos2
			_trail_life[_trail_head] = _n("trail_life", 2.4)
			_trail_head = (_trail_head + 1) % n
	var any := false
	for k in n:
		if _trail_life[k] > 0.0:
			_trail_life[k] -= delta
			any = true
			var w := ArenaSpace.to_world(_trail_pos[k], 0.0)
			ctx.sparks.glow_add(w.x, w.z, 0.8, Color(1.0, 0.45, 0.15, 0.35 * clampf(_trail_life[k], 0.0, 1.0)))
	if not any:
		return
	_trail_timer -= delta
	if _trail_timer > 0.0:
		return
	var tick := _n("trail_tick", 0.2)
	_trail_timer = tick
	var dmg := _dmg() * _n("trail_dps", 2.6) * tick * (1.0 + _n("trail_per_level", 0.5) * float(level - 1))
	var width := _n("trail_width", 34.0)
	for e in ctx.enemies:
		if e.dead or e.is_spawning():
			continue
		var rr: float = width + e.radius
		for k in n:
			if _trail_life[k] > 0.0 and e.pos2.distance_squared_to(_trail_pos[k]) < rr * rr:
				e.take_damage(dmg)
				break

func _tick_static(delta: float, level: int) -> void:
	var l := ctx.loadout
	var thunder := l.i("evo_thunder") > 0
	_static_timer -= delta * (_n("thunder_static_rate", 2.0) if thunder else 1.0)
	if _static_timer > 0.0:
		return
	_static_timer = _n("static_interval", 1.0)
	var player := ctx.player
	var want := mini(MAX_TARGETS, int(_n("static_targets", 2.0)) + (level - 1) + (int(_n("thunder_static_targets", 2.0)) if thunder else 0))
	var reach := _n("static_range", 230.0)
	var found := 0
	for k in want:
		var best = null
		var best_d := reach
		for e in ctx.enemies:
			if e.dead or e.is_spawning():
				continue
			var taken := false
			for j in found:
				if _targets[j] == e:
					taken = true
					break
			if taken:
				continue
			var d: float = e.pos2.distance_to(player.pos2)
			if d < best_d:
				best_d = d
				best = e
		if best == null:
			break
		_targets[found] = best
		found += 1
	var dmg := _dmg() * _n("static_damage", 1.5)
	var t := ctx.tuning
	for j in found:
		var e = _targets[j]
		ctx.sparks.lightning(player.position, e.position, Color(0.6, 0.8, 1.0), 0.07, 0.16)
		e.take_damage(dmg)
		ctx.feedback.damage_number(e.position, dmg, false)
		if l.i("chain") > 0:
			ctx.combat._chain_from(e, dmg * (t.hits_chain_damage + l.m("chain_power")), l.i("chain"))
		_targets[j] = null
	if found > 0:
		Sound.play("chain", -6.0)

func _tick_missiles(delta: float, level: int) -> void:
	_missile_timer -= delta * float(level)
	if _missile_timer > 0.0:
		return
	var player := ctx.player
	var target = _nearest_enemy(player.pos2, _n("missile_range", 700.0))
	if target == null:
		_missile_timer = 0.2
		return
	_missile_timer = _n("missile_interval", 2.2)
	var dir: Vector2 = (target.pos2 - player.pos2).normalized().rotated(0.6)
	var b = ctx.field.spawn(player.pos2 + dir * 20.0, dir, _n("missile_speed", 520.0) * 0.5, true, _dmg() * _n("missile_damage", 2.5), _n("missile_life", 1.6), 1.1, false, Color(1.0, 0.6, 0.3))
	b.style = BulletFieldScript.STYLE_ROCKET
	b.homing = _n("missile_homing", 7.0)
	b.blast = _n("missile_blast", 64.0)
	b.accel = 1600.0
	b.max_speed = _n("missile_speed", 520.0) * 1.8
	b.target = target
	b.chain = 1
	Sound.play("shoot_rocket", -5.0, 1.2)

func _reflect() -> void:
	var player := ctx.player
	var r := _n("reflect_radius", 110.0)
	var rr := r * r
	var dmg := _dmg() * _n("reflect_damage", 2.0)
	for b in ctx.field.bullets:
		if b.dead or b.friendly:
			continue
		if b.pos2.distance_squared_to(player.pos2) < rr:
			b.friendly = true
			b.velocity2 = -b.velocity2 * 1.4
			b.damage = dmg
			b.color = Color(0.6, 1.0, 1.0)
			b.chain = 1
			b.life = maxf(b.life, 0.6)
			ctx.sparks.burst(ArenaSpace.to_world(b.pos2, 1.0), Color(0.6, 1.0, 1.0), 3, 5.0, 0.2, 0.7)

# --- Lanetli kart (C1 kapısı için oyun içi sarmalayıcı) ------------------------------------
func apply_curse(id: String) -> bool:
	## Loadout.apply_curse + gemi istatistiklerini yenile + koşu XP çarpanını eşitle. C1'in sektör kapısı bunu çağırır.
	if not ctx.loadout.apply_curse(id):
		return false
	ctx.control.apply_loadout()
	ctx.run.xp_mult = ctx.loadout.m("xp_mult")
	ctx.events.card_picked.emit(GameData.card_by_id(id))
	return true

# --- Kart ekranı: yasaklama + evrim ipucu (cards.add_below_reroll seam'i) ------------------
func build(_host: Node) -> void:
	ctx.events.cards_shown.connect(_on_cards_shown)
	ctx.events.card_picked.connect(_on_card_picked)
	ctx.menus.screens_rebuilt.connect(_install_seams)
	_install_seams()

func _install_seams() -> void:
	_hint = KIT.label("", 16, KIT.GOLD, null, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.visible = false
	_banish_row = HBoxContainer.new()
	_banish_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_banish_row.add_theme_constant_override("separation", 30)
	_banish_buttons.clear()
	for k in 3:
		var b := KIT.button(tr("YASAKLA"), KIT.RED, Vector2(292, 40), 15)
		var index := k
		b.pressed.connect(func(): _on_banish(index))
		_banish_row.add_child(b)
		_banish_buttons.append(b)
	_banish_row.visible = false
	# add_below_reroll YENİLE'nin hemen altına koyar: önce ipucu, sonra yasaklama satırı → sıra: YENİLE, yasakla, ipucu.
	ctx.menus.cards.add_below_reroll(_hint)
	ctx.menus.cards.add_below_reroll(_banish_row)

func _on_cards_shown(cards: Array, _rerolls: int) -> void:
	_shown = cards
	var l := ctx.loadout
	if _banish_row != null:
		var left := l.banishes_total()
		_banish_row.visible = left > 0 and not (ctx.options.demo and not ctx.options.show_cards_demo)
		for k in _banish_buttons.size():
			var b: Button = _banish_buttons[k]
			b.visible = k < cards.size() and str((cards[k] as Dictionary).get("tier", "")) != "evolution"
			b.text = tr("YASAKLA  (%d)") % left
	if _hint != null:
		_hint.text = evolution_hint()
		_hint.visible = _hint.text != ""

func evolution_hint() -> String:
	## "EVRİM YOLU: YILDIZ YAĞMURU — ÇOKLU ATIŞ 1/2 · DELİCİ 0/2" (en yakın evrim) ya da "EVRİM HAZIR: …".
	var progress := ctx.loadout.evolution_progress()
	if progress.is_empty():
		return ""
	var best: Dictionary = progress[0]
	var card: Dictionary = best["card"]
	if bool(best["ready"]):
		return tr("EVRİM HAZIR: %s — bu seçimde!") % tr(str(card.get("name", "")))
	var parts := PackedStringArray()
	var need: Dictionary = best["need"]
	for id in need:
		parts.append("%s %d/%d" % [tr(str(GameData.card_by_id(str(id)).get("name", id))), int(best["have"][id]), int(need[id])])
	return tr("EVRİM YOLU: %s") % tr(str(card.get("name", ""))) + " — " + " · ".join(parts)

func _on_banish(index: int) -> void:
	if index < 0 or index >= _shown.size() or not ctx.cards.is_open:
		return
	var card: Dictionary = _shown[index]
	if not ctx.loadout.banish(str(card.get("id", ""))):
		Sound.play("deny")
		return
	ctx.hud.toast(tr("YASAKLANDI: %s") % tr(str(card.get("name", ""))), KIT.RED, 1.4)
	ctx.cards.open(false)

func _on_card_picked(card: Dictionary) -> void:
	var tier := str(card.get("tier", ""))
	if tier != "evolution" and tier != "cursed":
		return
	var player := ctx.player
	var accent: Color = KIT.GOLD if tier == "evolution" else KIT.RED
	ctx.hud.show_banner(tr("EVRİM") if tier == "evolution" else tr("LANET"), tr(str(card.get("name", ""))), 2.6, accent)
	ctx.sparks.ring(player.position, accent, 0.4, 12.0, 0.9, 0.12, 1.0)
	ctx.sparks.ring(player.position, Color(1, 1, 1), 0.3, 7.0, 0.6, 0.08)
	ctx.sparks.burst(player.position, accent, 60, 16.0, 0.8, 1.5, 0.5)
	ctx.feedback.tint(accent, 0.8)
	Sound.play("synergy")
	Fx.shake(10.0)
	Fx.vibrate(60)
