extends GameModule
class_name WeaponSystem
## Silahlar ve mermiler: gemi silahı (atış topu / saçma / ray / roket; gemi verisi `weapon`), roket güdümü,
## düşman mermisi, refakat dronları. Mermi çarpışması CombatSystem'de.

const BulletFieldScript = preload("res://scripts/world/bullet_field.gd")

func _fire_one(origin: Vector2, dir: Vector2, speed: float, damage: float, life: float, size: float, style: int, tint: Color) -> BulletFieldScript.Bullet:
	var loadout := ctx.loadout
	var crit: bool = randf() < loadout.m("crit")
	var b = ctx.field.spawn(origin, dir, speed, true, damage * (2.0 if crit else 1.0), life, size, crit, Color(0, 0, 0, 0) if crit else tint)
	b.style = style
	b.pierce = loadout.i("pierce")
	return b

func on_player_shot(origin: Vector2, direction: Vector2) -> void:
	var t := ctx.tuning
	var player := ctx.player
	var loadout := ctx.loadout
	var sparks := ctx.sparks
	var w: Dictionary = ctx.weapon
	var kind := str(w.get("type", "blaster"))
	var damage: float = t.player_damage * loadout.m("damage_mult") * float(w.get("damage", 1.0))
	var speed := float(w.get("speed", 980.0))
	var life := float(w.get("life", 0.85))
	var spread := float(w.get("spread", 0.035))
	var size: float = loadout.m("bullet_size") * float(w.get("size", 1.0))
	var extra: int = loadout.i("projectiles") - 1
	var tint: Color = player.ship_color.lerp(Color(1, 1, 1), 0.3)
	var muzzle := ArenaSpace.to_world(origin, 1.05)
	var dir3 := ArenaSpace.dir_to_world(direction)
	match kind:
		"scatter":
			var pellets := int(w.get("pellets", 6)) + extra * t.weapons_scatter_pellets_per_extra
			var arc := float(w.get("arc", 0.6)) + float(extra) * t.weapons_scatter_arc_per_extra
			for i in pellets:
				var u := float(i) / float(maxi(1, pellets - 1)) - 0.5
				var dir := direction.rotated(u * arc + randf_range(-spread, spread))
				_fire_one(origin, dir, speed * randf_range(0.88, 1.08), damage, life * randf_range(0.85, 1.1), size, BulletFieldScript.STYLE_PELLET, tint)
			sparks.spray(muzzle, dir3, tint, 9, 12.0, 0.16, 0.9, 0.45)
			Sound.play("shoot_scatter")
			player.velocity2 -= direction * t.weapons_scatter_recoil
			Fx.punch(-direction, 2.6)
			Fx.shake(1.6)
		"rail":
			var side := Vector2(-direction.y, direction.x)
			for i in extra + 1:
				var off := (float(i) - float(extra) * 0.5) * t.weapons_rail_offset
				var b = _fire_one(origin + side * off, direction, speed, damage, life, size, BulletFieldScript.STYLE_RAIL, tint)
				b.pierce += int(w.get("pierce", 4))
				var start := ArenaSpace.to_world(origin + side * off, 1.05)
				sparks.beam(start, start + dir3 * 9.0, tint, 0.1 * size, 0.1)
			sparks.spray(muzzle, dir3, Color(1, 1, 1), 6, 14.0, 0.14, 0.8, 0.25)
			Sound.play("shoot_rail")
			player.velocity2 -= direction * t.weapons_rail_recoil
			Fx.punch(-direction, 3.4)
			Fx.shake(2.4)
		"rocket":
			for i in extra + 1:
				var off := (float(i) - float(extra) * 0.5) * t.weapons_rocket_offset
				var b = _fire_one(origin, direction.rotated(off + randf_range(-spread, spread)), speed, damage, life, size, BulletFieldScript.STYLE_ROCKET, Color(1.0, 0.75, 0.4))
				b.homing = float(w.get("homing", 6.0))
				b.blast = float(w.get("blast", 72.0))
				b.accel = float(w.get("accel", 1400.0))
				b.max_speed = float(w.get("max_speed", 980.0))
				b.pierce = 0
			sparks.spray(muzzle, dir3, Color(1.0, 0.7, 0.35), 5, 7.0, 0.22, 1.0, 0.5)
			Sound.play("shoot_rocket")
			Fx.punch(-direction, 1.4)
		_:
			var count := extra + 1
			for i in count:
				var offset := 0.0
				if count > 1:
					offset = (float(i) - float(count - 1) * 0.5) * t.weapons_blaster_offset
				_fire_one(origin, direction.rotated(offset + randf_range(-spread, spread)), speed, damage, life, size, BulletFieldScript.STYLE_BLASTER, Color(0, 0, 0, 0))
			sparks.spray(muzzle, dir3, Color(0.6, 0.95, 1.0), 3, 9.0, 0.14, 0.7, 0.3)
			Sound.play("shoot", randf_range(-2.0, 0.0), 1.18 if player.overdrive > 0.0 else 1.0)
			player.velocity2 -= direction * t.player_knockback * t.weapons_blaster_recoil_mult
			Fx.punch(-direction, 0.9)

func _nearest_hostile(from: Vector2, radius: float, heading: Vector2) -> Object:
	var best: Object = null
	var best_score := 1e12
	var fwd := heading.normalized()
	for e in ctx.enemies:
		if e.dead or e.is_spawning():
			continue
		var to: Vector2 = e.pos2 - from
		var d := to.length()
		if d > radius:
			continue
		var score := d * (1.0 + maxf(0.0, -fwd.dot(to / maxf(d, 0.001))) * 1.5)
		if score < best_score:
			best_score = score
			best = e
	var boss := ctx.boss
	if boss != null and is_instance_valid(boss) and boss.alive and boss.intro <= 0.0:
		var db: float = boss.pos2.distance_to(from) - boss.radius
		if db < radius and db < best_score:
			best = boss
	return best

func steer_rockets(delta: float) -> void:
	var boss := ctx.boss
	var sparks := ctx.sparks
	for b in ctx.field.bullets:
		if b.dead or not b.friendly or b.homing <= 0.0:
			continue
		b.retarget -= delta
		if b.retarget <= 0.0 or not PlayerControl.is_valid_target(b.target, boss):
			b.retarget = 0.15
			b.target = _nearest_hostile(b.pos2, 600.0, b.velocity2)
		if PlayerControl.is_valid_target(b.target, boss):
			var tp: Vector2 = b.target.pos2
			var diff := wrapf((tp - b.pos2).angle() - b.velocity2.angle(), -PI, PI)
			b.velocity2 = b.velocity2.rotated(clampf(diff, -b.homing * delta, b.homing * delta))
		if randf() < 0.7:
			var fwd := ArenaSpace.dir_to_world(b.velocity2)
			sparks.trail(ArenaSpace.to_world(b.pos2, BulletFieldScript.HEIGHT) - fwd * 0.45, fwd, Color(1.0, 0.55, 0.25), 1.2)

func fire_enemy_bullet(e) -> void:
	var t := ctx.tuning
	var dir: Vector2 = (ctx.player.pos2 - e.pos2).normalized()
	var speed := float(e.stats.get("bullet_speed", 330.0))
	var sniper: bool = e.kind == "sniper"
	var tint: Color = e.color().lerp(Color(1.0, 0.25, 0.55), 0.35)
	ctx.field.spawn(e.pos2 + dir * (e.radius + 6.0), dir, speed, false, e.damage_value * t.enemy_bullets_damage, t.enemy_bullets_life, t.enemy_bullets_sniper_size if sniper else 1.0, false, Color(tint.r, tint.g, tint.b, 1.0))
	ctx.sparks.spray(e.position, ArenaSpace.dir_to_world(dir), e.color(), 4, 5.0, 0.2, 0.8)
	Sound.play("shoot_sniper" if sniper else "shoot_enemy", -4.0 if sniper else 0.0)

# --- Refakat dronları ---------------------------------------------------------------
func sync_drones() -> void:
	var drones := ctx.drones
	var want: int = ctx.loadout.i("drones")
	while drones.size() < want:
		var node := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.2
		ball.height = 0.4
		ball.radial_segments = 10
		ball.rings = 5
		node.mesh = ball
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.6, 1.9, 2.2)
		node.material_override = mat
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ctx.host.add_child(node)
		drones.append({"node": node, "angle": 0.0, "cd": 0.0})
	while drones.size() > want:
		var drone = drones.pop_back()
		if is_instance_valid(drone["node"]):
			drone["node"].queue_free()

func tick_drones(delta: float) -> void:
	var drones := ctx.drones
	if drones.is_empty():
		return
	var t := ctx.tuning
	var player := ctx.player
	var boss := ctx.boss
	var count := drones.size()
	for i in count:
		var drone: Dictionary = drones[i]
		drone["angle"] = float(drone["angle"]) + delta * t.drones_spin
		var offset := Vector2.from_angle(float(drone["angle"]) + TAU * float(i) / float(count)) * t.drones_orbit
		var at: Vector2 = player.pos2 + offset
		var node: MeshInstance3D = drone["node"]
		if is_instance_valid(node):
			node.position = ArenaSpace.to_world(at, 1.35)
			node.visible = player.alive
			ctx.sparks.glow_add(node.position.x, node.position.z, 0.9, Color(0.6, 0.9, 1.0, 0.3))
		drone["cd"] = float(drone["cd"]) - delta
		if float(drone["cd"]) <= 0.0 and player.alive:
			var target_pos: Variant = null
			var best := t.drones_range
			for e in ctx.enemies:
				if e.dead or e.is_spawning():
					continue
				var d: float = e.pos2.distance_to(at)
				if d < best:
					best = d
					target_pos = e.pos2
			if target_pos == null and boss != null and is_instance_valid(boss) and boss.alive and boss.pos2.distance_to(at) < t.drones_boss_range:
				target_pos = boss.pos2
			if target_pos != null:
				drone["cd"] = t.drones_hive_cooldown if ctx.loadout.i("hive") > 0 else t.drones_cooldown
				var dir: Vector2 = ((target_pos as Vector2) - at).normalized()
				var b = ctx.field.spawn(at, dir, t.drones_bullet_speed, true, t.player_damage * ctx.loadout.m("damage_mult") * t.drones_damage, t.drones_life, t.drones_size)
				b.chain = 1
