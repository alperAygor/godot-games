extends Control
## Oyun içi gösterge: can/kalkan, XP, dalga, boss barı, skor/kombo, minimap,
## hasar sayıları, ekran dışı okları ve duyuru şeritleri. Menüler menus.gd'de.

const KIT = preload("res://scripts/ui/ui_kit.gd")

var camera: Camera3D
var active := false
var dimmed := false

var hp := 100.0
var max_hp := 100.0
var shield := 0
var score := 0
var best := 0
var wave := 1
var combo := 0
var combo_ratio := 0.0
var mult := 1.0
var dash_ratio := 1.0
var nova_ratio := 0.0
var overdrive := 0.0
var enemies_left := 0
var level := 1
var xp_ratio := 0.0
var map_name := ""
var boss_active := false
var boss_ratio := 0.0
var boss_name := "BOSS"
var boss_phase := 1
var boss_color := KIT.RED
var in_break := false
var minimap: Dictionary = {}
var bars: Array = []
var pointers: Array = []
var hint := ""

var banner_title := ""
var banner_sub := ""
var banner_color := KIT.CYAN
var banner_time := 0.0
var _banner_max := 1.0
var _toast := ""
var _toast_time := 0.0
var _toast_color := KIT.GOLD
var _smooth_hp := 100.0
var _smooth_boss := 1.0
var _shown_score := 0.0
var _score_pop := 0.0
var _combo_pop := 0.0
var _last_combo := 0
var _hp_flash := 0.0
var _time := 0.0
var _floaters: Array[Dictionary] = []
var _margin := Vector4(28, 20, 28, 20)
var _fps := 60.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_margins(m: Vector4) -> void:
	_margin = m

func _process(delta: float) -> void:
	var vp := get_viewport_rect().size
	if size != vp:
		size = vp
		position = Vector2.ZERO
	_time += delta
	_fps = lerpf(_fps, Engine.get_frames_per_second(), 0.1)
	if get_tree().paused:
		queue_redraw()
		return
	banner_time = maxf(0.0, banner_time - delta)
	_toast_time = maxf(0.0, _toast_time - delta)
	_smooth_hp = lerpf(_smooth_hp, hp, clampf(delta * 5.0, 0.0, 1.0))
	_smooth_boss = lerpf(_smooth_boss, boss_ratio, clampf(delta * 4.0, 0.0, 1.0))
	_shown_score = lerpf(_shown_score, float(score), clampf(delta * 10.0, 0.0, 1.0))
	_score_pop = maxf(0.0, _score_pop - delta * 4.0)
	_combo_pop = maxf(0.0, _combo_pop - delta * 5.0)
	_hp_flash = maxf(0.0, _hp_flash - delta * 3.0)
	var i := _floaters.size() - 1
	while i >= 0:
		var f: Dictionary = _floaters[i]
		f["age"] = float(f["age"]) + delta
		if float(f["age"]) >= float(f["life"]):
			_floaters.remove_at(i)
		i -= 1
	queue_redraw()

func update_state(state: Dictionary) -> void:
	hp = float(state.get("hp", hp))
	max_hp = float(state.get("max_hp", max_hp))
	shield = int(state.get("shield", shield))
	var new_score := int(state.get("score", score))
	if new_score > score:
		_score_pop = 1.0
	score = new_score
	wave = int(state.get("wave", wave))
	combo = int(state.get("combo", combo))
	if combo > _last_combo:
		_combo_pop = 1.0
	_last_combo = combo
	combo_ratio = float(state.get("combo_ratio", combo_ratio))
	mult = float(state.get("mult", mult))
	dash_ratio = float(state.get("dash_ratio", dash_ratio))
	nova_ratio = float(state.get("nova_ratio", nova_ratio))
	overdrive = float(state.get("overdrive", overdrive))
	enemies_left = int(state.get("left", enemies_left))
	best = int(state.get("best", best))
	level = int(state.get("level", level))
	xp_ratio = float(state.get("xp_ratio", xp_ratio))
	map_name = str(state.get("map_name", map_name))
	boss_active = bool(state.get("boss_active", boss_active))
	boss_ratio = float(state.get("boss_ratio", boss_ratio))
	boss_name = str(state.get("boss_name", boss_name))
	boss_phase = int(state.get("boss_phase", boss_phase))
	boss_color = state.get("boss_color", boss_color)
	in_break = bool(state.get("in_break", in_break))
	minimap = state.get("minimap", minimap)
	bars = state.get("bars", bars)
	pointers = state.get("pointers", pointers)

func reset() -> void:
	_floaters.clear()
	banner_time = 0.0
	_toast_time = 0.0
	_shown_score = 0.0
	score = 0
	_last_combo = 0
	_smooth_boss = 1.0
	hint = ""

func show_banner(title: String, sub := "", duration := 1.6, color := KIT.CYAN) -> void:
	banner_title = title
	banner_sub = sub
	banner_time = duration
	_banner_max = duration
	banner_color = color

func toast(text: String, color := KIT.GOLD, duration := 1.3) -> void:
	## Küçük, oyunu kapatmayan bildirim (toplanan nesne, kombo eşiği).
	_toast = text
	_toast_color = color
	_toast_time = duration

func flash_damage() -> void:
	_hp_flash = 1.0

func float_text(world: Vector3, text: String, color: Color, size_px := 20, life := 0.7) -> void:
	# Aynı noktada art arda gelen hasar sayılarını topla: "12 12 12" yerine tek "36".
	if text.is_valid_int() and not _floaters.is_empty():
		for i in range(_floaters.size() - 1, maxi(-1, _floaters.size() - 8), -1):
			var f: Dictionary = _floaters[i]
			if float(f["age"]) < 0.22 and str(f["t"]).is_valid_int() and (f["w"] as Vector3).distance_to(world) < 0.9 and f["c"] == color:
				f["t"] = str(int(f["t"]) + int(text))
				f["age"] = 0.0
				f["s"] = mini(int(f["s"]) + 1, size_px + 8)
				return
	if _floaters.size() >= 46:
		_floaters.pop_front()
	_floaters.append({
		"w": world, "t": text, "c": color, "s": size_px, "age": 0.0, "life": life,
		"dx": randf_range(-16.0, 16.0),
	})

# --- Çizim ----------------------------------------------------------------------
func _draw() -> void:
	if not active:
		return
	var vp := get_viewport_rect().size
	var s := Settings.ui_scale()
	var a := 0.4 if dimmed else 1.0
	_draw_world_marks(vp, s, a)
	_draw_vitals(vp, s, a)
	_draw_wave(vp, s, a)
	_draw_score(vp, s, a)
	_draw_minimap(vp, s, a)
	if not Settings.touch:
		_draw_abilities(vp, s, a)
	if not dimmed:
		_draw_banner(vp, s)
		_draw_toast(vp, s)
		_draw_hint(vp, s)
		if not Settings.touch:
			_draw_reticle()
	if Settings.show_fps:
		_text(Vector2(_margin.x, vp.y - _margin.w - 4), "%d FPS" % int(round(_fps)), 14, Color(0.6, 0.8, 0.7, 0.8))

func _draw_world_marks(vp: Vector2, s: float, a: float) -> void:
	if camera == null:
		return
	# Elit / tank can barları
	for entry in bars:
		var world: Vector3 = entry[0]
		if camera.is_position_behind(world):
			continue
		var p := camera.unproject_position(world + Vector3(0, 1.5, 0))
		var w := 46.0 * s * (1.3 if bool(entry[2]) else 1.0)
		var rect := Rect2(p.x - w * 0.5, p.y - 4.0, w, 5.0 * s)
		draw_rect(rect.grow(1.5), Color(0, 0, 0, 0.6 * a), true)
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * float(entry[1]), rect.size.y)), Color(KIT.GOLD if bool(entry[2]) else KIT.RED, a), true)
	# Hasar sayıları
	for f in _floaters:
		var world: Vector3 = f["w"]
		if camera.is_position_behind(world):
			continue
		var t: float = float(f["age"]) / float(f["life"])
		var p := camera.unproject_position(world) + Vector2(float(f["dx"]), -34.0 - 46.0 * (1.0 - pow(1.0 - t, 2.0)))
		var c: Color = f["c"]
		c.a = clampf((1.0 - t) * 2.2, 0.0, 1.0) * a
		var px := int(float(f["s"]) * s * (1.0 + 0.5 * maxf(0.0, 1.0 - t * 5.0)))
		draw_string_outline(KIT.bold(), p - Vector2(100, 0), str(f["t"]), HORIZONTAL_ALIGNMENT_CENTER, 200, px, 5, Color(0, 0, 0, c.a * 0.7))
		draw_string(KIT.bold(), p - Vector2(100, 0), str(f["t"]), HORIZONTAL_ALIGNMENT_CENTER, 200, px, c)
	# Ekran dışı okları
	var center := vp * 0.5
	var inset := Vector2(54.0, 54.0) * s
	for entry in pointers:
		var world: Vector3 = entry[0]
		var p := camera.unproject_position(world)
		if camera.is_position_behind(world):
			p = center - (p - center)
		if p.x > 0.0 and p.x < vp.x and p.y > 0.0 and p.y < vp.y:
			continue
		var dir := (p - center).normalized()
		var half := center - inset
		var scale_x := half.x / maxf(absf(dir.x), 0.001)
		var scale_y := half.y / maxf(absf(dir.y), 0.001)
		var at := center + dir * minf(scale_x, scale_y)
		var c: Color = entry[1]
		var big: float = float(entry[2])
		var pulse := 0.7 + 0.3 * sin(_time * 6.0)
		var r := 11.0 * s * big
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([at + dir * r, at - dir * r * 0.7 + side * r * 0.8, at - dir * r * 0.25, at - dir * r * 0.7 - side * r * 0.8]), Color(c, pulse * a))

func _bar(rect: Rect2, ratio: float, fill: Color, back: Color, skew := 8.0) -> void:
	## Eğik kenarlı (paralelkenar) neon bar.
	var p := rect.position
	var sz := rect.size
	draw_colored_polygon(PackedVector2Array([p + Vector2(skew, 0), p + Vector2(sz.x + skew, 0), p + Vector2(sz.x, sz.y), p + Vector2(0, sz.y)]), back)
	var w := sz.x * clampf(ratio, 0.0, 1.0)
	if w > 1.0:
		draw_colored_polygon(PackedVector2Array([p + Vector2(skew, 0), p + Vector2(w + skew, 0), p + Vector2(w, sz.y), p + Vector2(0, sz.y)]), fill)
		draw_colored_polygon(PackedVector2Array([p + Vector2(skew, 0), p + Vector2(w + skew, 0), p + Vector2(w + skew * 0.6, sz.y * 0.4), p + Vector2(skew * 0.6, sz.y * 0.4)]), Color(1, 1, 1, 0.28 * fill.a))

func _draw_vitals(_vp: Vector2, s: float, a: float) -> void:
	var x := _margin.x
	var y := _margin.y
	# Seviye rozeti
	var badge_r := 27.0 * s
	var bc := Vector2(x + badge_r, y + badge_r + 2.0)
	var hexagon := PackedVector2Array()
	for i in 6:
		hexagon.append(bc + Vector2.from_angle(TAU * float(i) / 6.0 + PI / 6.0) * badge_r)
	draw_colored_polygon(hexagon, Color(0.04, 0.06, 0.13, 0.9 * a))
	hexagon.append(hexagon[0])
	draw_polyline(hexagon, Color(KIT.VIOLET, a), 2.0, true)
	draw_arc(bc, badge_r - 6.0 * s, -PI * 0.5, -PI * 0.5 + TAU * clampf(xp_ratio, 0.0, 1.0), 32, Color(KIT.VIOLET, 0.95 * a), 3.0 * s, true)
	draw_string(KIT.bold(), bc + Vector2(-badge_r, 8.0 * s), str(level), HORIZONTAL_ALIGNMENT_CENTER, badge_r * 2.0, int(22 * s), Color(1, 1, 1, a))
	# Can
	var bar_x := x + badge_r * 2.0 + 12.0 * s
	var bar := Rect2(bar_x, y + 6.0 * s, 250.0 * s, 17.0 * s)
	var ratio := clampf(hp / maxf(1.0, max_hp), 0.0, 1.0)
	var smooth := clampf(_smooth_hp / maxf(1.0, max_hp), 0.0, 1.0)
	var fill := KIT.CYAN
	if ratio < 0.3:
		fill = KIT.RED.lerp(KIT.GOLD, 0.5 + 0.5 * sin(_time * 9.0))
	elif ratio < 0.6:
		fill = KIT.CYAN.lerp(KIT.GOLD, 0.6)
	fill = fill.lerp(Color(1, 1, 1), _hp_flash * 0.7)
	_bar(bar.grow(2.5), 0.0, Color(0, 0, 0, 0), Color(0.3, 0.6, 0.85, 0.35 * a), 8.0 * s)
	_bar(bar, 1.0, Color(0.05, 0.03, 0.08, 0.9 * a), Color(0, 0, 0, 0), 8.0 * s)
	if smooth > ratio:
		_bar(bar, smooth, Color(1.0, 0.3, 0.4, 0.55 * a), Color(0, 0, 0, 0), 8.0 * s)
	_bar(bar, ratio, Color(fill, a), Color(0, 0, 0, 0), 8.0 * s)
	_text(Vector2(bar.end.x + 16.0 * s, bar.end.y - 1.0 * s), "%d" % int(ceil(hp)), int(19 * s), Color(fill, a), true)
	if shield > 0:
		KIT.icon(self, "shield", Vector2(bar.end.x + 74.0 * s, bar.position.y + bar.size.y * 0.5), 12.0 * s, Color(0.5, 0.78, 1.0, a))
	# XP
	var xp_bar := Rect2(bar_x, bar.end.y + 7.0 * s, 250.0 * s, 6.0 * s)
	_bar(xp_bar, 1.0, Color(0.07, 0.07, 0.16, 0.9 * a), Color(0, 0, 0, 0), 3.0 * s)
	_bar(xp_bar, xp_ratio, Color(KIT.VIOLET, a), Color(0, 0, 0, 0), 3.0 * s)
	_text(Vector2(bar_x + 2.0, xp_bar.end.y + 18.0 * s), tr(map_name), int(12 * s), Color(KIT.DIM, 0.8 * a))
	if overdrive > 0.0:
		var od := Rect2(bar_x, xp_bar.end.y + 26.0 * s, 150.0 * s, 6.0 * s)
		_bar(od, 1.0, Color(0.1, 0.08, 0.03, 0.9 * a), Color(0, 0, 0, 0), 3.0 * s)
		_bar(od, overdrive / 6.0, Color(KIT.GOLD, a), Color(0, 0, 0, 0), 3.0 * s)
		_text(Vector2(od.end.x + 12.0 * s, od.end.y + 3.0 * s), tr("AŞIRI YÜK"), int(12 * s), Color(KIT.GOLD, a), true)

func _draw_wave(vp: Vector2, s: float, a: float) -> void:
	var top := _margin.y
	var w := vp.x
	if boss_active:
		var width := minf(520.0 * s, w * 0.4)
		var bar := Rect2(w * 0.5 - width * 0.5, top + 30.0 * s, width, 14.0 * s)
		var c := boss_color
		_text_centered(Vector2(0, top + 20.0 * s), tr(boss_name), int(19 * s), Color(c.lerp(Color(1, 1, 1), 0.3), a), w, KIT.title())
		_bar(bar.grow(2.5), 0.0, Color(0, 0, 0, 0), Color(c, 0.4 * a), 9.0 * s)
		_bar(bar, 1.0, Color(0.1, 0.02, 0.05, 0.92 * a), Color(0, 0, 0, 0), 9.0 * s)
		if _smooth_boss > boss_ratio:
			_bar(bar, _smooth_boss, Color(1, 1, 1, 0.55 * a), Color(0, 0, 0, 0), 9.0 * s)
		_bar(bar, boss_ratio, Color(c, a), Color(0, 0, 0, 0), 9.0 * s)
		var mid := bar.position.x + bar.size.x * 0.5
		draw_line(Vector2(mid + 5.0 * s, bar.position.y - 3.0), Vector2(mid - 4.0 * s, bar.end.y + 3.0), Color(1, 1, 1, 0.8 * a), 2.0)
		if boss_phase >= 2:
			_text_centered(Vector2(0, bar.end.y + 18.0 * s), tr("ÖFKE FAZI"), int(12 * s), Color(KIT.GOLD, (0.7 + 0.3 * sin(_time * 8.0)) * a), w, KIT.bold())
	else:
		_text_centered(Vector2(0, top + 26.0 * s), tr("DALGA %02d") % wave, int(26 * s), Color(KIT.TEXT, a), w, KIT.title())
		var sub := tr("sıradaki dalga geliyor") if in_break else tr("%d düşman kaldı") % enemies_left
		_text_centered(Vector2(0, top + 46.0 * s), sub, int(13 * s), Color(KIT.DIM, 0.9 * a), w)

func _right_edge(vp: Vector2, s: float) -> float:
	# Dokunmatikte sağ üst köşe duraklat düğmesine ayrılır.
	return vp.x - _margin.z - (74.0 * s if Settings.touch else 0.0)

func _draw_score(vp: Vector2, s: float, a: float) -> void:
	var right := _right_edge(vp, s)
	var top := _margin.y
	var pop := 1.0 + 0.16 * _score_pop
	_text_right(Vector2(right, top + 30.0 * s), KIT.fmt(int(round(_shown_score))), int(32 * s * pop), Color(1, 1, 1, a), KIT.title())
	_text_right(Vector2(right, top + 48.0 * s), tr("REKOR  %s") % KIT.fmt(maxi(best, score)), int(12 * s), Color(KIT.DIM, 0.85 * a))
	if combo > 1:
		var heat := clampf(float(combo) / 30.0, 0.0, 1.0)
		var cc := KIT.GOLD.lerp(KIT.MAGENTA, heat)
		var cp := 1.0 + 0.3 * _combo_pop
		_text_right(Vector2(right, top + 82.0 * s), "×%.1f" % mult, int(26 * s * cp), Color(cc, a), KIT.title())
		_text_right(Vector2(right - 84.0 * s, top + 80.0 * s), tr("%d KOMBO") % combo, int(13 * s), Color(cc, 0.9 * a), KIT.bold())
		var cb := Rect2(right - 180.0 * s, top + 90.0 * s, 180.0 * s, 4.0 * s)
		draw_rect(cb, Color(0.1, 0.08, 0.05, 0.8 * a), true)
		draw_rect(Rect2(cb.end.x - cb.size.x * combo_ratio, cb.position.y, cb.size.x * combo_ratio, cb.size.y), Color(cc, a), true)

func _draw_minimap(vp: Vector2, s: float, a: float) -> void:
	if minimap.is_empty():
		return
	var arena_rect: Rect2 = minimap.get("arena", Rect2(0, 0, 1, 1))
	var width := (150.0 if Settings.touch else 180.0) * s
	var mm := Rect2(vp.x - _margin.z - width, _margin.y + 104.0 * s, width, width * arena_rect.size.y / arena_rect.size.x)
	draw_rect(mm.grow(4.0), Color(0.02, 0.04, 0.09, 0.72 * a), true)
	draw_rect(mm.grow(4.0), Color(KIT.CYAN, 0.35 * a), false, 1.5)
	var sc := Vector2(mm.size.x / arena_rect.size.x, mm.size.y / arena_rect.size.y)
	for o in minimap.get("obstacles", []):
		var op: Vector2 = mm.position + (o["pos2"] - arena_rect.position) * sc
		draw_circle(op, maxf(2.0, float(o["radius"]) * sc.x), Color(0.35, 0.5, 0.7, 0.4 * a))
	for entry in minimap.get("pickups", []):
		var pk: Vector2 = mm.position + (entry - arena_rect.position) * sc
		draw_rect(Rect2(pk - Vector2(2, 2), Vector2(4, 4)), Color(KIT.GREEN, 0.95 * a), true)
	for entry in minimap.get("enemies", []):
		var p: Vector2 = mm.position + (entry - arena_rect.position) * sc
		draw_circle(p, 1.9 * s, Color(1.0, 0.35, 0.5, 0.95 * a))
	for entry in minimap.get("elites", []):
		var ep: Vector2 = mm.position + (entry - arena_rect.position) * sc
		draw_circle(ep, 3.2 * s, Color(KIT.GOLD, a))
	var boss_pos: Variant = minimap.get("boss", null)
	if boss_pos != null:
		var bp: Vector2 = mm.position + ((boss_pos as Vector2) - arena_rect.position) * sc
		draw_circle(bp, (4.5 + sin(_time * 6.0)) * s, Color(boss_color, a))
		draw_arc(bp, 7.0 * s, 0.0, TAU, 16, Color(boss_color, 0.6 * a), 1.5)
	var pp: Vector2 = mm.position + ((minimap.get("player", Vector2.ZERO) as Vector2) - arena_rect.position) * sc
	var aim: Vector2 = minimap.get("aim", Vector2.RIGHT)
	var side := Vector2(-aim.y, aim.x)
	draw_colored_polygon(PackedVector2Array([pp + aim * 6.0 * s, pp - aim * 4.0 * s + side * 4.0 * s, pp - aim * 4.0 * s - side * 4.0 * s]), Color(0.6, 1.0, 1.0, a))

func _ability(center: Vector2, r: float, ratio: float, kind: String, key: String, color: Color, a: float) -> void:
	var ready := ratio >= 0.999
	draw_circle(center, r, Color(0.03, 0.06, 0.11, 0.8 * a))
	draw_arc(center, r, 0.0, TAU, 40, Color(color, 0.25 * a), 2.0, true)
	draw_arc(center, r, -PI * 0.5, -PI * 0.5 + TAU * clampf(ratio, 0.0, 1.0), 40, Color(color, a), 3.5, true)
	if ready:
		draw_circle(center, r - 5.0, Color(color, (0.14 + 0.08 * sin(_time * 5.0)) * a))
	KIT.icon(self, kind, center, r * 0.5, Color(color if ready else KIT.DIM, (1.0 if ready else 0.6) * a))
	_text_centered(Vector2(center.x - 60.0, center.y + r + 17.0), key, 12, Color(KIT.DIM, 0.85 * a), 120.0)

func _draw_abilities(vp: Vector2, s: float, a: float) -> void:
	var y := vp.y - _margin.w - 52.0 * s
	_ability(Vector2(_margin.x + 34.0 * s, y), 28.0 * s, dash_ratio, "dash", tr("BOŞLUK"), KIT.CYAN, a)
	_ability(Vector2(_margin.x + 110.0 * s, y), 28.0 * s, nova_ratio, "nova", "Q", KIT.MAGENTA, a)

func _draw_banner(vp: Vector2, s: float) -> void:
	if banner_time <= 0.0:
		return
	var t := 1.0 - banner_time / _banner_max
	var fade_in := clampf(t * _banner_max / 0.22, 0.0, 1.0)
	var fade_out := clampf(banner_time / 0.35, 0.0, 1.0)
	var alpha := fade_in * fade_out
	var y := vp.y * 0.27
	var grow := 1.0 + (1.0 - fade_in) * 0.5
	var c := Color(banner_color, alpha)
	var px := int(54 * s * grow)
	var tw := KIT.title().get_string_size(banner_title, HORIZONTAL_ALIGNMENT_LEFT, -1, int(54 * s)).x
	var line_w := (tw * 0.5 + 70.0 * s) * fade_in
	draw_rect(Rect2(vp.x * 0.5 - line_w, y - 58.0 * s, line_w * 2.0, 88.0 * s), Color(0.01, 0.02, 0.05, 0.5 * alpha), true)
	draw_line(Vector2(vp.x * 0.5 - line_w, y - 58.0 * s), Vector2(vp.x * 0.5 + line_w, y - 58.0 * s), Color(c, alpha * 0.8), 2.0)
	draw_line(Vector2(vp.x * 0.5 - line_w, y + 30.0 * s), Vector2(vp.x * 0.5 + line_w, y + 30.0 * s), Color(c, alpha * 0.8), 2.0)
	draw_string_outline(KIT.title(), Vector2(0, y - 6.0 * s), banner_title, HORIZONTAL_ALIGNMENT_CENTER, vp.x, px, 12, Color(c.r, c.g, c.b, alpha * 0.25))
	draw_string(KIT.title(), Vector2(0, y - 6.0 * s), banner_title, HORIZONTAL_ALIGNMENT_CENTER, vp.x, px, Color(c.lerp(Color(1, 1, 1), 0.55), alpha))
	if banner_sub != "":
		_text_centered(Vector2(0, y + 20.0 * s), banner_sub, int(17 * s), Color(KIT.TEXT, alpha * 0.92), vp.x)

func _draw_toast(vp: Vector2, s: float) -> void:
	if _toast_time <= 0.0:
		return
	var alpha := clampf(_toast_time / 0.3, 0.0, 1.0)
	var rise := (1.0 - clampf(_toast_time, 0.0, 1.0)) * 8.0
	var y := vp.y * 0.66 - rise
	draw_string_outline(KIT.bold(), Vector2(0, y), _toast, HORIZONTAL_ALIGNMENT_CENTER, vp.x, int(22 * s), 6, Color(0, 0, 0, alpha * 0.6))
	draw_string(KIT.bold(), Vector2(0, y), _toast, HORIZONTAL_ALIGNMENT_CENTER, vp.x, int(22 * s), Color(_toast_color, alpha))

func _draw_hint(vp: Vector2, s: float) -> void:
	if hint == "":
		return
	var alpha := 0.7 + 0.3 * sin(_time * 3.0)
	_text_centered(Vector2(0, vp.y * 0.82), hint, int(17 * s), Color(KIT.TEXT, alpha), vp.x, KIT.bold())

func _draw_reticle() -> void:
	var mouse := get_viewport().get_mouse_position()
	var reticle := Color(0.6, 0.95, 1.0, 0.8)
	draw_arc(mouse, 11.0, 0.0, TAU, 24, reticle, 1.5, true)
	for i in 4:
		var ang := TAU * float(i) / 4.0 + _time * 0.6
		draw_line(mouse + Vector2.from_angle(ang) * 15.0, mouse + Vector2.from_angle(ang) * 21.0, reticle, 1.8, true)
	draw_circle(mouse, 1.8, Color(1, 1, 1, 0.95))

func _text(pos: Vector2, text: String, size_px: int, color: Color, strong := false) -> void:
	draw_string(KIT.bold() if strong else KIT.font(), pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func _text_right(pos: Vector2, text: String, size_px: int, color: Color, use_font: Font = null) -> void:
	draw_string(use_font if use_font != null else KIT.font(), Vector2(pos.x - 700.0, pos.y), text, HORIZONTAL_ALIGNMENT_RIGHT, 700, size_px, color)

func _text_centered(pos: Vector2, text: String, size_px: int, color: Color, width := 1280.0, use_font: Font = null) -> void:
	draw_string(use_font if use_font != null else KIT.font(), pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, size_px, color)
