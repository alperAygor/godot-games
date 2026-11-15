extends GameModule
class_name HudBridge
## HUD yapıştırıcısı: güvenli alan kenar boşlukları ve her kare HUD/dokunmatik durum sözlüğü.
## hud.gd / touch_controls.gd arayüzü değişmedi (update_state anahtarları aynı).

var _layout_size := Vector2.ZERO

func update_layout() -> void:
	var vp: Vector2 = ctx.host.get_viewport().get_visible_rect().size
	if vp == _layout_size:
		return
	_layout_size = vp
	var m := Vector4(28, 20, 28, 20)
	if Settings.touch:
		m = Vector4(40, 22, 40, 24)
	if OS.has_feature("mobile"):
		var win := Vector2(DisplayServer.window_get_size())
		var safe := DisplayServer.get_display_safe_area()
		if win.x > 0.0 and win.y > 0.0 and safe.size.x > 0:
			var sx := vp.x / win.x
			var sy := vp.y / win.y
			m.x = maxf(m.x, float(safe.position.x) * sx + 14.0)
			m.y = maxf(m.y, float(safe.position.y) * sy + 10.0)
			m.z = maxf(m.z, (win.x - float(safe.end.x)) * sx + 14.0)
			m.w = maxf(m.w, (win.y - float(safe.end.y)) * sy + 10.0)
	ctx.hud.set_margins(m)
	ctx.touch.set_margins(m)
	ctx.menus.set_margins(m)
	ctx.feedback.vignette_mat.set_shader_parameter("resolution", vp)

func update() -> void:
	if ctx.state == "menu":
		return
	var run := ctx.run
	var player := ctx.player
	var nova_max := ctx.tuning.nova_max
	var enemy_positions: Array = []
	var elite_positions: Array = []
	var bars: Array = []
	var pointers: Array = []
	var few: bool = run.enemies_left() <= 5
	for e in ctx.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		if e.elite:
			elite_positions.append(e.pos2)
		else:
			enemy_positions.append(e.pos2)
		if e.hp_shown > 0.0 and (e.elite or e.max_hp >= 60.0) and not e.is_spawning():
			bars.append([e.position, e.hp_ratio(), e.elite])
		if few or e.elite:
			pointers.append([e.position, KIT.GOLD if e.elite else KIT.RED, 1.0])
	var pickup_positions: Array = []
	for p in ctx.pickups:
		if is_instance_valid(p):
			pickup_positions.append(p.pos2)
			pointers.append([p.position, p.color(), 0.8])
	var boss_pos: Variant = null
	var boss_ratio := 0.0
	var boss := ctx.boss
	var boss_on: bool = boss != null and is_instance_valid(boss)
	if boss_on:
		boss_pos = boss.pos2
		boss_ratio = clampf(boss.hp / maxf(1.0, boss.max_hp), 0.0, 1.0)
		pointers.append([boss.position, boss.color(), 1.5])
	ctx.touch.dash_ratio = player.dash_ratio()
	ctx.touch.nova_ratio = ctx.nova / nova_max
	ctx.touch.auto_fire = Settings.auto_fire
	ctx.hud.update_state({
		"hp": player.hp, "max_hp": player.max_hp, "shield": player.shield, "score": run.score,
		"wave": run.wave, "combo": run.combo, "combo_ratio": run.combo_ratio(), "mult": run.multiplier(),
		"dash_ratio": player.dash_ratio(), "nova_ratio": ctx.nova / nova_max,
		"overdrive": player.overdrive, "left": run.enemies_left(),
		"best": Settings.best, "level": run.level, "xp_ratio": run.hp_ratio_for_next(),
		"map_name": str(GameData.map_theme(ctx.map_index).get("name", "")),
		"boss_active": boss_on and boss.alive, "boss_ratio": boss_ratio,
		"boss_name": boss.display_name if boss_on else "", "boss_phase": boss.phase if boss_on else 1,
		"boss_color": boss.color() if boss_on else KIT.RED,
		"in_break": run.phase == RunState.PHASE_BREAK,
		"minimap": {
			"arena": ARENA, "player": player.pos2, "aim": player.aim2, "enemies": enemy_positions,
			"elites": elite_positions, "pickups": pickup_positions, "boss": boss_pos, "obstacles": ctx.obstacles,
		},
		"bars": bars, "pointers": pointers,
	})
