extends GameModule
class_name CombatSystem
## Çarpışma ve hasar: mermi/temas/atılma çarpışmaları, isabet + zincir + alan hasarı, patlamalar, iyileşme ve
## kalkan, toplanabilir etkileri, nova, düşman ölümü (puan/XP/düşme/bölünme/kombo eşikleri).
## Formüller game3d.gd'den birebir taşındı; sayılar data/balance/combat.json (ctx.tuning).

const BulletFieldScript = preload("res://scripts/world/bullet_field.gd")

var _overheal := 0.0
var _milestone_index := 0

func reset_run() -> void:
	_overheal = 0.0
	_milestone_index = 0
	ctx.effects.reset_run()

# --- Çarpışmalar ------------------------------------------------------------------
func resolve_collisions() -> void:
	var t := ctx.tuning
	var player := ctx.player
	var boss := ctx.boss
	var sparks := ctx.sparks
	var enemies := ctx.enemies
	var loadout := ctx.loadout
	var feedback := ctx.feedback
	var obstacles := ctx.obstacles
	var boss_hittable: bool = boss != null and is_instance_valid(boss) and boss.alive and boss.intro <= 0.0
	for b in ctx.field.bullets:
		if b.dead:
			continue
		if b.friendly:
			for e in enemies:
				if e.dead or e.is_spawning():
					continue
				var rr: float = e.radius + b.radius
				if b.pos2.distance_squared_to(e.pos2) < rr * rr:
					if not b.hits.is_empty() and b.hits.has(e.get_instance_id()):
						continue
					hit_enemy(e, b)
					if b.blast > 0.0:
						rocket_blast(b)
						b.dead = true
						break
					if b.pierce > 0:
						b.pierce -= 1
						b.hits.append(e.get_instance_id())
					else:
						b.dead = true
						ctx.effects.on_bullet_stopped(e, b)
					break
			if b.dead:
				continue
			if boss_hittable:
				var br: float = boss.radius + b.radius
				if b.pos2.distance_squared_to(boss.pos2) < br * br:
					boss.take_damage(b.damage * ctx.effects.boss_damage_mult())
					if b.blast > 0.0:
						rocket_blast(b)
					var at := ArenaSpace.to_world(b.pos2, BulletFieldScript.HEIGHT)
					sparks.spray(at, -ArenaSpace.dir_to_world(b.velocity2), Color(1.0, 0.7, 0.8), 6, 8.0, 0.3, 1.0)
					feedback.damage_number(at, b.damage, b.crit)
					Sound.play("crit" if b.crit else "hit", -1.0, 0.85)
					b.dead = true
					continue
		else:
			if player.alive and player.invuln <= 0.0:
				var pr: float = player.radius + b.radius + 1.0
				if b.pos2.distance_squared_to(player.pos2) < pr * pr:
					player.take_damage(b.damage, b.pos2 - b.velocity2 * 0.01)
					b.dead = true
					continue
		if ArenaGeometry.point_blocked(obstacles, b.pos2, b.radius):
			if b.blast > 0.0:
				rocket_blast(b)
			sparks.spray(ArenaSpace.to_world(b.pos2, BulletFieldScript.HEIGHT), -ArenaSpace.dir_to_world(b.velocity2), b.color, 4, 5.0, 0.22, 0.8)
			b.dead = true

	var dash_damage: float = loadout.m("dash_damage")
	if player.alive and player.is_dashing() and dash_damage > 0.0:
		for e in enemies:
			if e.dead or e.is_spawning() or e.dash_hit > 0.0:
				continue
			if e.pos2.distance_to(player.pos2) < e.radius + player.radius + t.hits_dash_reach:
				e.dash_hit = t.hits_dash_hit_cd
				var dash_hit: float = dash_damage * loadout.m("damage_mult") * (t.hits_blitz_mult if loadout.i("blitz") > 0 else 1.0)
				var dash_dealt: float = e.take_damage(dash_hit, player.dash_dir * t.hits_dash_knockback)
				sparks.lightning(player.position, e.position, Color(0.6, 1.0, 1.0), 0.08, 0.18)
				sparks.burst(e.position, Color(0.6, 1.0, 1.0), 8, 7.0, 0.3, 1.0)
				feedback.enemy_damage_number(e, dash_dealt, false)
				Sound.play("chain")
				if e.dead and loadout.i("blitz") > 0:
					player.dash_cd = 0.0
					sparks.ring(player.position, Color(0.6, 1.0, 1.0), 0.3, 2.2, 0.25, 0.25)
	if player.invuln <= 0.0 and player.alive:
		for e in enemies:
			if e.dead or e.is_spawning() or e.touch_cd > 0.0:
				continue
			if e.pos2.distance_to(player.pos2) < e.radius + player.radius:
				e.touch_cd = t.hits_touch_cd
				player.take_damage(e.damage_value, e.pos2)
				var thorns: float = loadout.m("thorns") * (t.hits_fortress_thorns_mult if loadout.i("fortress") > 0 else 1.0)
				if thorns > 0.0:
					var thorns_dealt: float = e.take_damage(thorns, (e.pos2 - player.pos2).normalized() * t.hits_thorns_knockback)
					feedback.enemy_damage_number(e, thorns_dealt, false)
				break
	if boss != null and is_instance_valid(boss) and boss.alive and boss.intro <= 0.0 and not boss.is_airborne() and player.invuln <= 0.0 and player.alive:
		if boss.pos2.distance_to(player.pos2) < boss.radius + player.radius:
			player.take_damage(boss.damage_value * (t.hits_boss_charge_contact if boss.is_charging() else 1.0), boss.pos2)
	var pickups := ctx.pickups
	var pickup_radius := t.run_pickup_radius
	for pi in range(pickups.size() - 1, -1, -1):
		var p = pickups[pi]
		if is_instance_valid(p) and p.pos2.distance_to(player.pos2) < pickup_radius and player.alive:
			apply_pickup(p)
			p.queue_free()
			pickups.remove_at(pi)

# --- Hasar ------------------------------------------------------------------------
func hit_enemy(e, b) -> void:
	var t := ctx.tuning
	var loadout := ctx.loadout
	var dir: Vector2 = b.velocity2.normalized()
	var push := dir * (t.hits_heavy_knockback if e.kind == "tank" or e.elite else t.hits_knockback)
	var dealt: float = e.take_damage(b.damage * ctx.effects.enemy_damage_mult(e), push)
	var at := ArenaSpace.to_world(b.pos2, BulletFieldScript.HEIGHT)
	ctx.sparks.spray(at, -ArenaSpace.dir_to_world(dir), Color(1.0, 0.85, 0.45) if b.crit else e.color().lerp(Color(1, 1, 1), 0.45), 7 if b.crit else 4, 8.0, 0.28, 1.0 if b.crit else 0.8)
	ctx.feedback.enemy_damage_number(e, dealt, b.crit)   # gerçek hasar (kalkan engeli %12, zırhlı ×0,5 …), tam mermi hasarı değil
	Sound.play("crit" if b.crit else "hit")
	var chain: int = loadout.i("chain")
	var storm: bool = b.crit and loadout.i("storm") > 0
	if storm:
		chain += t.hits_storm_jumps
	if chain > 0 and b.chain == 0:
		_chain_from(e, b.damage * (t.hits_storm_chain_damage if storm else t.hits_chain_damage + loadout.m("chain_power")), chain)
	ctx.effects.on_hit(e, b)

func _chain_from(source, damage: float, jumps: int) -> void:
	var visited: Array = [source]
	var current = source
	var reach := ctx.tuning.hits_chain_range * ctx.effects.chain_range_mult()
	for n in jumps:
		var next = null
		var best := reach
		for e in ctx.enemies:
			if e.dead or e.is_spawning() or visited.has(e):
				continue
			var d: float = e.pos2.distance_to(current.pos2)
			if d < best:
				best = d
				next = e
		if next == null:
			break
		ctx.sparks.lightning(current.position, next.position, Color(0.75, 0.6, 1.0), 0.07, 0.17)
		ctx.sparks.burst(next.position, Color(0.8, 0.7, 1.0), 5, 5.0, 0.25, 0.8)
		var chain_dealt: float = next.take_damage(damage)
		ctx.feedback.enemy_damage_number(next, chain_dealt, false)
		visited.append(next)
		current = next
	if visited.size() > 1:
		Sound.play("chain")

func area_damage(center: Vector2, radius: float, damage: float, skip = null) -> void:
	var knock := ctx.tuning.hits_area_knockback
	for other in ctx.enemies:
		if other == skip or other.dead or other.is_spawning():
			continue
		var d: float = other.pos2.distance_to(center)
		if d < radius + other.radius:
			other.take_damage(damage, (other.pos2 - center).normalized() * knock)
	var boss := ctx.boss
	if boss != null and is_instance_valid(boss) and boss.alive and boss.pos2.distance_to(center) < radius + boss.radius:
		boss.take_damage(damage)

func rocket_blast(b) -> void:
	var sparks := ctx.sparks
	var at := ArenaSpace.to_world(b.pos2, BulletFieldScript.HEIGHT)
	sparks.burst(at, Color(1.0, 0.6, 0.25), 14, 9.0, 0.4, 1.1)
	sparks.ring(at, Color(1.0, 0.55, 0.2), 0.3, b.blast / ArenaSpace.SCALE * 1.1, 0.3, 0.25, 1.0)
	sparks.flash(at, Color(1.0, 0.55, 0.2), 4.0, 7.0, 0.16)
	Sound.play("explode", -6.0, 1.35)
	Fx.shake(2.5)
	area_damage(b.pos2, b.blast, b.damage * 0.6)

func _bomber_blast(e) -> void:
	var player := ctx.player
	var sparks := ctx.sparks
	var radius := float(e.stats.get("explode_radius", 120.0))
	var world_r := radius / ArenaSpace.SCALE
	sparks.burst(e.position, Color(1.0, 0.4, 0.15), 44, 13.0, 0.7, 1.5)
	sparks.ring(e.position, Color(1.0, 0.45, 0.15), 0.5, world_r * 1.15, 0.45, 0.22, 1.0)
	sparks.flash(e.position, Color(1.0, 0.5, 0.2), 9.0, 12.0, 0.3)
	Sound.play("explode_big", -3.0, 1.15)
	Fx.shake(13.0)
	if player.alive and player.pos2.distance_to(e.pos2) < radius:
		player.take_damage(e.damage_value, e.pos2)
	area_damage(e.pos2, radius, e.damage_value * ctx.tuning.hits_bomber_area_damage, e)

func tick_aftershocks(delta: float) -> void:
	var aftershocks := ctx.aftershocks
	for i in range(aftershocks.size() - 1, -1, -1):
		var a: Dictionary = aftershocks[i]
		a["t"] = float(a["t"]) - delta
		if float(a["t"]) > 0.0:
			continue
		aftershocks.remove_at(i)
		var at: Vector2 = a["pos2"]
		var w := ArenaSpace.to_world(at, 0.6)
		ctx.sparks.burst(w, Color(1.0, 0.45, 0.85), 22, 11.0, 0.5, 1.3)
		ctx.sparks.ring(w, Color(1.0, 0.45, 0.85), 0.4, 4.0, 0.35, 0.25, 1.0)
		ctx.sparks.flash(w, Color(1.0, 0.4, 0.8), 6.0, 9.0, 0.2)
		Sound.play("explode", -2.0, 0.8)
		Fx.shake(6.0)
		area_damage(at, float(a.get("r", ctx.tuning.nova_aftershock_radius)), float(a["dmg"]))

# --- İyileşme, kalkan, toplanabilirler ---------------------------------------------
func heal(amount: float, show := true) -> void:
	## Tüm iyileşmeler buradan geçer; Kan Hasadı taşan canı kalkana çevirir.
	var player := ctx.player
	amount *= ctx.effects.heal_mult()
	var room := player.max_hp - player.hp
	player.heal(amount)
	if ctx.loadout.i("harvest") <= 0:
		return
	_overheal += maxf(0.0, amount - room)
	if _overheal >= ctx.effects.harvest_threshold() and player.shield <= 0:
		_overheal = 0.0
		give_shield()
		if show:
			ctx.hud.toast(tr("KAN HASADI — kalkan"), KIT.RED, 1.0)

func give_shield() -> void:
	ctx.player.shield = 1
	Sound.play("shield_up")
	ctx.sparks.ring(ctx.player.position, Color(0.5, 0.8, 1.0), 3.0, 1.2, 0.4, 0.2)

func apply_pickup(p) -> void:
	var player := ctx.player
	var hud := ctx.hud
	match p.kind:
		"heal":
			var amount: float = GameData.number("pickups.heal_amount", 22.0)
			heal(amount)
			hud.toast(tr("+%d CAN") % int(amount), KIT.GREEN)
			hud.float_text(player.position, "+%d" % int(amount), KIT.GREEN, 22, 0.9)
			Sound.play("pickup_heal")
		"shield":
			give_shield()
			hud.toast(tr("KALKAN"), Color(0.55, 0.8, 1.0))
		_:
			player.overdrive = GameData.number("pickups.overdrive_time", 6.0)
			hud.toast(tr("AŞIRI YÜK — ateş hızı ×2"), KIT.GOLD)
			Sound.play("pickup_power")
	ctx.effects.on_pickup(str(p.kind))
	ctx.sparks.burst(p.position, p.color(), 18, 8.0, 0.55, 1.1)
	ctx.sparks.ring(player.position, p.color(), 0.4, 3.2, 0.4, 0.2)
	ctx.feedback.tint(p.color(), 0.35)
	Fx.vibrate(15)

# --- Nova -------------------------------------------------------------------------
func try_nova() -> void:
	var t := ctx.tuning
	var player := ctx.player
	if ctx.nova < t.nova_max or not player.alive:
		if player.alive:
			Sound.play("deny")
		return
	ctx.nova = 0.0
	var radius: float = GameData.number("player.nova_radius", 340.0) * ctx.effects.nova_radius_mult()
	var damage: float = GameData.number("player.nova_damage", 70.0) * ctx.loadout.m("damage_mult") * (1.0 + t.nova_wave_scale * float(ctx.run.wave - 1))
	if ctx.loadout.i("doom_nova") > 0:
		radius *= t.nova_doom_radius_mult
		for k in t.nova_doom_aftershocks:
			var at: Vector2 = player.pos2 + Vector2.from_angle(randf() * TAU) * randf_range(radius * t.nova_doom_min, radius * t.nova_doom_max)
			ctx.aftershocks.append({"pos2": at, "t": t.nova_doom_delay + t.nova_doom_delay_step * float(k), "dmg": damage * t.nova_doom_damage})
	blast(radius, damage, Color(1.0, 0.4, 0.85))
	player.invuln = maxf(player.invuln, t.nova_invuln)
	ctx.effects.on_nova(radius, damage)
	Sound.play("nova")
	ctx.hud.show_banner(tr("NOVA"), "", 0.7, KIT.MAGENTA)

func blast(radius: float, damage: float, color: Color) -> void:
	## Oyuncu merkezli patlama (nova, İkinci Şans): düşman mermilerini siler + alan hasarı + büyük efekt.
	var player := ctx.player
	var sparks := ctx.sparks
	var world_r := radius / ArenaSpace.SCALE
	for at in ctx.field.clear_hostile(player.pos2, radius * ctx.tuning.nova_clear_radius_mult):
		sparks.burst(ArenaSpace.to_world(at, 1.0), Color(1.0, 0.5, 0.8), 3, 4.0, 0.3, 0.8)
	area_damage(player.pos2, radius, damage)
	sparks.ring(player.position, color, 0.6, world_r, 0.5, 0.2, 1.0)
	sparks.ring(player.position, Color(1, 1, 1, 0.9), 0.3, world_r * 0.8, 0.38, 0.1)
	sparks.ring(player.position, color, 0.2, world_r * 1.35, 0.75, 0.06)
	sparks.burst(player.position, color, 60, 18.0, 0.7, 1.6, 0.4)
	sparks.burst(player.position, Color(1, 1, 1), 24, 12.0, 0.5, 1.2, 0.4)
	sparks.flash(player.position, color, 14.0, 20.0, 0.4)
	ctx.world.flash_pulse(player.position, 1.0)
	ctx.feedback.tint(color, 1.0)
	Fx.shake(22.0)
	Fx.hitstop(0.07, 0.1)
	Fx.vibrate(70)

func add_nova(amount: float) -> void:
	ctx.nova = minf(ctx.tuning.nova_max, ctx.nova + amount)

# --- Oyuncu hasarı ----------------------------------------------------------------
func on_player_hurt(amount: float) -> void:
	var t := ctx.tuning
	var player := ctx.player
	amount = ctx.effects.on_hurt(amount)
	Sound.play("hurt")
	if ctx.loadout.i("fortress") > 0 and player.alive:
		var dmg: float = t.player_damage * ctx.loadout.m("damage_mult") * t.fortress_damage
		var n := t.fortress_bullets
		for k in n:
			var dir := Vector2.from_angle(TAU * float(k) / float(n))
			var fb = ctx.field.spawn(player.pos2 + dir * 20.0, dir, t.fortress_speed, true, dmg, t.fortress_life, t.fortress_size, false, Color(1.0, 0.75, 0.3))
			fb.pierce = t.fortress_pierce
		ctx.sparks.ring(player.position, Color(1.0, 0.75, 0.3), 0.5, 4.0, 0.3, 0.2)
	ctx.feedback.player_hurt_fx(amount)
	ctx.events.player_hurt.emit(amount)

# --- Düşman ölümü -----------------------------------------------------------------
func reap(e) -> void:
	var t := ctx.tuning
	var run := ctx.run
	var loadout := ctx.loadout
	var sparks := ctx.sparks
	var elite: bool = e.elite
	var points: int = e.points() * (int(GameData.number("elite.points_mult", 3.0)) if elite else 1)
	var before: int = run.score
	run.enemy_died(points)
	var color: Color = e.color()
	var big: bool = e.kind == "tank" or elite
	sparks.burst(e.position, color, 26 if big else 16, 11.0 if big else 9.0, 0.6, 1.4 if big else 1.15)
	sparks.burst(e.position, Color(1, 1, 1), 6, 6.0, 0.3, 0.9)
	sparks.ring(e.position, color, 0.3, 4.2 if big else 2.6, 0.38, 0.2)
	sparks.flash(e.position, color, 4.0 if big else 2.5, 7.0, 0.18)
	ctx.hud.float_text(e.position + Vector3(0, 0.6, 0), "+%d" % (run.score - before), KIT.GOLD if elite else Color(0.75, 0.95, 1.0, 0.9), 22 if elite else 15, 0.8)
	Sound.play("explode_big" if big else "explode", -6.0 if big else 0.0)
	Fx.shake(8.0 if big else 3.5)
	if big:
		Fx.hitstop(0.04, 0.2)
	add_nova(t.player_nova_per_kill * loadout.m("nova_rate_mult") * (t.nova_elite_kill_mult if elite else 1.0) * ctx.effects.nova_kill_mult())
	var vampire: float = loadout.m("vampire") * ctx.effects.vampire_mult()
	if vampire > 0.0:
		heal(vampire)
	if e.kind == "tank" and ctx.state == "playing" and not ctx.bosses.dying:
		for i in t.tank_split_count:
			var offset := Vector2.from_angle(randf() * TAU) * t.tank_split_offset
			ctx.spawner.spawn_enemy("chaser", e.pos2 + offset, t.tank_split_delay, false)
		run.add_alive(t.tank_split_count)
	if e.kind == "bomber":
		_bomber_blast(e)
	var explosive: int = loadout.i("explosive")
	if explosive > 0:
		var er := t.explosive_radius + t.explosive_radius_per_level * float(explosive)
		sparks.ring(e.position, Color(1.0, 0.6, 0.2), 0.3, er / ArenaSpace.SCALE, 0.3, 0.3, 1.0)
		area_damage(e.pos2, er, t.player_damage * loadout.m("damage_mult") * (t.explosive_damage + t.explosive_damage_per_level * float(explosive)), e)
	if elite or randf() < GameData.number("pickups.drop_chance", 0.14):
		ctx.spawner.spawn_pickup(e.pos2, ctx.spawner.roll_pickup())
	ctx.effects.on_kill(e)
	_check_milestone()
	ctx.control.forget_target(e)
	ctx.events.enemy_killed.emit(str(e.kind), elite, run.score - before)
	if is_instance_valid(e):
		e.queue_free()

func _check_milestone() -> void:
	var run := ctx.run
	var list: Array = GameData.value("scoring.milestones", [10, 25, 50, 100])
	if run.combo < int(list[0]):
		_milestone_index = 0
		return
	if _milestone_index < list.size() and run.combo >= int(list[_milestone_index]):
		var names := [tr("SERİ!"), tr("KATLİAM!"), tr("DURDURULAMAZ!"), tr("EFSANE!")]
		ctx.hud.toast(tr("%d KOMBO — %s") % [run.combo, names[mini(_milestone_index, names.size() - 1)]], KIT.GOLD.lerp(KIT.MAGENTA, float(_milestone_index) / 3.0), 1.5)
		Sound.play("combo", 4.0, 1.0 + 0.18 * float(_milestone_index))
		add_nova(ctx.tuning.nova_milestone_gain)
		_milestone_index += 1
