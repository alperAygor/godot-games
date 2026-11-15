extends GameModule
class_name Spawner
## Düşman/toplanabilir doğurma, dalga temposu (av modu), düşman hareketinin arena kuralları (engel kaçınma,
## itme, sınır, birbirinden ayrılma). Ne zaman/hangi tür doğacağına RunState karar verir (spawn_due sinyali).

const EnemyScript = preload("res://scripts/entities3d/enemy3d.gd")
const PickupScript = preload("res://scripts/entities3d/pickup3d.gd")

var wave_time := 0.0
var _hunt_timer := 0.0
var _seen_kinds: Dictionary = {}   ## bu koşuda ilk kez görülen yeni türler (tek seferlik ipucu)

func on_wave_started(wave: int) -> void:
	var t := ctx.tuning
	wave_time = 0.0
	_hunt_timer = t.run_hunt_after
	if wave <= 1:
		_seen_kinds.clear()
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
			_on_enemy_death(e)
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
		if e.action != EnemyScript.ACT_NONE:
			var act: int = e.action
			e.action = EnemyScript.ACT_NONE
			_do_action(e, act)

# --- C2: yeni türlerin eylemleri (ctx gerektiren her şey burada) ----------------------------------
func _do_action(e, act: int) -> void:
	var st: Dictionary = e.stats
	var sparks := ctx.sparks
	var player := ctx.player
	match act:
		EnemyScript.ACT_MINE:
			var count := int(st.get("mine_count", 2))
			var lead: Vector2 = player.velocity2 * float(st.get("mine_lead", 0.35))
			for k in count:
				var at: Vector2 = player.pos2 + lead
				if k > 0:
					at += Vector2.from_angle(randf() * TAU) * float(st.get("mine_spread", 110.0))
				add_zone(at, float(st.get("mine_radius", 88.0)), float(st.get("mine_delay", 1.3)), e.damage_value, e.color())
			Sound.play("bomb_beep", -4.0, 0.9)
		EnemyScript.ACT_PULSE_START:
			var radius := float(st.get("heal_radius", 290.0))
			if heal_targets(e, radius).is_empty():
				e.cancel_charge()
				return
			var charge := float(st.get("pulse_charge", 0.85))
			sparks.ring(e.position, Color(e.color(), 0.9), 0.4, radius / ArenaSpace.SCALE, charge, 0.12, 0.12)
			sparks.burst(e.position, e.color(), 6, 4.0, 0.4, 0.8)
			Sound.play("laser_charge", -8.0, 1.5)
		EnemyScript.ACT_PULSE:
			var radius_p := float(st.get("heal_radius", 290.0))
			var frac := float(st.get("heal_frac", 0.35))
			var beams := 0
			for other in heal_targets(e, radius_p):
				other.heal(other.max_hp * frac)
				sparks.burst(other.position, e.color(), 8, 4.0, 0.45, 0.9)
				if beams < 4:
					beams += 1
					sparks.lightning(e.position, other.position, e.color(), 0.06, 0.25)
			sparks.ring(e.position, e.color(), radius_p / ArenaSpace.SCALE * 0.9, radius_p / ArenaSpace.SCALE, 0.25, 0.1)
			Sound.play("pickup_heal", -6.0, 1.3)
		EnemyScript.ACT_BLINK_START:
			var win := float(st.get("blink_windup", 0.7))
			sparks.ring(e.position, Color(e.color(), 0.95), 2.4, 0.3, win, 0.1, 0.3)
			sparks.burst(e.position, e.color(), 8, 5.0, 0.5, 0.9)
			Sound.play("laser_charge", -8.0, 1.8)
		EnemyScript.ACT_BLINK_LAND:
			var old_world := ArenaSpace.to_world(e.action_pos, 0.9)
			sparks.burst(old_world, e.color(), 14, 8.0, 0.4, 1.0)
			e.pos2 = ArenaGeometry.push_out(ctx.obstacles, e.pos2, e.radius)
			e.pos2.x = clampf(e.pos2.x, ARENA.position.x + e.radius, ARENA.end.x - e.radius)
			e.pos2.y = clampf(e.pos2.y, ARENA.position.y + e.radius, ARENA.end.y - e.radius)
			e.position = ArenaSpace.to_world(e.pos2, 0.9)
			sparks.burst(e.position, e.color(), 18, 9.0, 0.45, 1.1)
			sparks.flash(e.position, e.color(), 3.0, 6.0, 0.15)
			add_zone(e.pos2, float(st.get("strike_radius", 140.0)), float(st.get("strike_delay", 0.9)), e.damage_value, e.color())
			Sound.play("leap", -6.0, 1.4)
		EnemyScript.ACT_HATCH_START:
			var r_h: float = e.radius / ArenaSpace.SCALE
			sparks.ring(e.position, Color(e.color(), 0.9), r_h * 1.2, r_h * 2.6, float(st.get("hatch_charge", 0.9)), 0.12, 0.2)
			Sound.play("bomb_beep", -8.0, 0.7)
		EnemyScript.ACT_HATCH:
			var n := int(st.get("hatch_count", 2))
			var hk := str(st.get("hatch_kind", "swarmer"))
			for k in n:
				var off: Vector2 = Vector2.from_angle(randf() * TAU) * (e.radius + 24.0)
				spawn_enemy(hk, e.pos2 + off, 0.5, false)
			ctx.run.add_alive(n)
			sparks.burst(e.position, e.color(), 16, 7.0, 0.5, 1.1)
			Sound.play("spawn", -2.0, 0.8)

func heal_targets(medic, radius: float) -> Array:
	## Onarıcının darbe yarıçapındaki yaralı müttefikler (kendisi hariç). Seyrek çağrılır (uyarı + darbe).
	var out: Array = []
	for other in ctx.enemies:
		if other == medic or not is_instance_valid(other) or other.dead or other.is_spawning():
			continue
		if other.hp < other.max_hp * 0.92 and other.pos2.distance_to(medic.pos2) <= radius:
			out.append(other)
	return out

func add_zone(at: Vector2, radius: float, delay: float, dmg: float, color: Color) -> void:
	## Uyarılı yer bölgesi: boss'un yer tehlikesiyle AYNI sistem (ctx.hazards → BossEvents.tick_hazards patlatır, otopilot kaçınır).
	at = at.clamp(ARENA.position + Vector2(40, 40), ARENA.end - Vector2(40, 40))
	ctx.hazards.append({"pos2": at, "radius": radius, "t": delay, "max": delay, "dmg": dmg, "burst": 0, "kind": "slam"})
	var w := ArenaSpace.to_world(at, 0.0)
	var r := radius / ArenaSpace.SCALE
	ctx.sparks.ring(w, Color(color, 0.9), r, r, delay, 0.07, 0.5)
	ctx.sparks.ring(w, Color(color, 0.7), 0.1, r, delay, 0.9, 0.0)

func _on_enemy_death(e) -> void:
	## Combat.reap'ten ÖNCE: elit ön eki ölüm etkileri (bölünme, ek ödül). Reap'in kendi kural/kancaları değişmez.
	if ctx.state != "playing" or ctx.bosses.dying:
		return
	if e.split_count > 0 and not e.from_split:
		for i in e.split_count:
			var child = spawn_enemy(e.kind, e.pos2 + Vector2.from_angle(randf() * TAU) * (e.radius * 0.8 + 10.0), e.split_delay, false)
			child.shrink(e.split_hp_frac, 0.78)
			child.from_split = true
		ctx.run.add_alive(e.split_count)
		ctx.sparks.ring(e.position, e.prefix_color, 0.4, 3.2, 0.35, 0.18)
	for i in e.bonus_pickups:
		spawn_pickup(e.pos2 + Vector2.from_angle(randf() * TAU) * 28.0, roll_pickup())

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
	spawn_enemy(resolve_kind(kind), spawn_point(), 0.6)

func resolve_kind(kind: String) -> String:
	## `enemies.json` zamanlama kuralları (EnemyData.resolve_kind): sektör uygunluğu + eşzamanlı üst sınır → `fallback`.
	var def: Dictionary = (GameData.balance.get("enemies", {}) as Dictionary).get(kind, {})
	if not def.has("sectors") and not def.has("max_alive"):
		return kind
	var counts: Dictionary = {}
	if def.has("max_alive"):
		for other in ctx.enemies:
			if is_instance_valid(other) and not other.dead:
				counts[other.kind] = int(counts.get(other.kind, 0)) + 1
	var sector := ctx.run.map_index % maxi(1, GameData.maps.size())
	return EnemyData.resolve_kind(GameData.balance["enemies"], kind, sector, counts)

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

func spawn_enemy(kind: String, at: Vector2, delay := 0.5, allow_elite := true):
	var run := ctx.run
	var elite_def: Dictionary = {}
	if allow_elite and kind != "swarmer":
		var def: Dictionary = GameData.elite_def()
		if not def.is_empty() and run.wave >= int(def.get("from_wave", 4)) and not run.is_boss_wave(run.wave):
			var chance := minf(float(def.get("chance_max", 0.16)), float(def.get("chance", 0.05)) + float(def.get("chance_per_wave", 0.006)) * float(run.wave))
			if randf() < chance:
				elite_def = EnemyData.merged_elite(def, EnemyData.pick_prefix(def, kind, run.wave, randf()))
	var e = EnemyScript.new()
	var stats: Dictionary = GameData.enemy_stats(kind)
	stats["spawn_delay"] = delay
	e.setup(kind, stats, run.hp_scale(), run.damage_scale(), run.speed_scale(), elite_def)
	e.pos2 = at
	e.position = ArenaSpace.to_world(at, 0.3)
	ctx.entities.add_child(e)
	ctx.enemies.append(e)
	var c: Color = (e.prefix_color if e.prefix != "" else KIT.GOLD) if e.elite else e.color()
	var r: float = e.radius / ArenaSpace.SCALE
	ctx.sparks.ring(e.position, c, r * 4.0, r * 1.1, delay, 0.14, 1.0)
	ctx.sparks.burst(e.position, c, 6, 4.0, 0.4, 0.8)
	if e.elite:
		Sound.play("elite")
		var elite_name := tr("ELİT DÜŞMAN")
		if e.prefix != "":
			elite_name += " · " + tr(str(GameData.elite_def()["prefixes"][e.prefix]["name"]))
		ctx.hud.toast(elite_name, c, 1.4)
	else:
		Sound.play("spawn")
	if stats.has("hint") and not _seen_kinds.has(kind) and not e.from_split:
		_seen_kinds[kind] = true
		ctx.hud.toast(tr(str(stats["hint"])), e.color(), 2.6)
	return e

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
