extends GameModule
class_name Autopilot
## Demo/test botu (`--demo`, `player.autopilot`): en yakın düşmanı nişanlar, yan yan kaçar, mermi/tehlike/
## ışın/engel/duvardan uzak durur, kalabalıkta nova. Smoke testi, sahne probu ve kalibrasyon bunu kullanır:
## davranışı değişirse tools/sim/baseline yeniden üretilmeli.

func plan() -> Dictionary:
	## {"move": Vector2, "aim": Vector2, "fire": bool, "dash": bool, "nova": bool}
	var player := ctx.player
	var boss := ctx.boss
	var nearest = null
	var nearest_dist := 1e9
	var close := 0
	for e in ctx.enemies:
		if e.dead:
			continue
		var d: float = e.pos2.distance_to(player.pos2)
		if d < 300.0:
			close += 1
		if d < nearest_dist:
			nearest_dist = d
			nearest = e
	var aim_target: Vector2 = player.pos2 + player.aim2 * 200.0
	var move := Vector2.ZERO
	if nearest != null:
		aim_target = nearest.pos2 + nearest.velocity2 * 0.12
		var away: Vector2 = (player.pos2 - nearest.pos2).normalized()
		var side := Vector2(-away.y, away.x)
		move = (side * 0.9 + away * 0.45).normalized()
		if str(ctx.weapon.get("type", "")) == "scatter" and nearest_dist > 230.0:
			# Kısa menzilli silah: yaklaş ve yan yan dolaş.
			move = (side * 0.7 - away * 0.8).normalized()
		elif nearest_dist < 150.0:
			move = away
	var boss_near := false
	if boss != null and is_instance_valid(boss) and boss.alive:
		aim_target = boss.pos2
		var away_b: Vector2 = (player.pos2 - boss.pos2).normalized()
		var dist_b: float = player.pos2.distance_to(boss.pos2)
		boss_near = dist_b < 330.0
		if dist_b < 300.0:
			move = away_b
		elif nearest == null:
			move = Vector2(-away_b.y, away_b.x)
	for b in ctx.field.bullets:
		if b.friendly or b.dead:
			continue
		var to_player: Vector2 = player.pos2 - b.pos2
		var d2: float = to_player.length()
		if d2 < 170.0 and b.velocity2.dot(to_player) > 0.0:
			move += Vector2(-b.velocity2.y, b.velocity2.x).normalized() * 0.8
	for h in ctx.hazards:
		var to_h: Vector2 = player.pos2 - h["pos2"]
		var lim: float = float(h["radius"]) + 70.0
		if to_h.length() < lim:
			move += to_h.normalized() * 2.5
	var beam_close := false
	if boss != null and is_instance_valid(boss) and boss.beam_state != Boss3D.BEAM_IDLE:
		for angle in boss.beam_angles:
			var bd := Vector2.from_angle(angle)
			var rel: Vector2 = player.pos2 - boss.pos2
			var along := rel.dot(bd)
			if along > 0.0 and along < boss.beam_length:
				var side_v := rel - bd * along
				if side_v.length() < 140.0:
					move += side_v.normalized() * 2.0 + Vector2(-bd.y, bd.x) * 0.5
				if boss.beam_state == Boss3D.BEAM_FIRE and side_v.length() < 70.0:
					beam_close = true
	for o in ctx.obstacles:
		var to_obs: Vector2 = player.pos2 - o["pos2"]
		var dist_o := to_obs.length()
		var guard: float = float(o["radius"]) + 80.0
		if dist_o < guard and dist_o > 0.01:
			move += to_obs / dist_o * (1.0 - dist_o / guard) * 1.8
	if player.pos2.x < ARENA.position.x + 160.0:
		move.x += 1.4
	if player.pos2.x > ARENA.end.x - 160.0:
		move.x -= 1.4
	if player.pos2.y < ARENA.position.y + 160.0:
		move.y += 1.4
	if player.pos2.y > ARENA.end.y - 160.0:
		move.y -= 1.4
	move = move.normalized() if move.length() > 0.001 else Vector2.ZERO
	return {
		"move": move,
		"aim": aim_target,
		"fire": true,
		"dash": (nearest_dist < 120.0 or beam_close) and player.dash_ready(),
		"nova": ctx.nova >= ctx.tuning.nova_max and (close >= 4 or boss_near),
	}
