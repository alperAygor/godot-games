extends Control
class_name SectorHud
## C1: ekranda koşu hedefi ve ilerleme. Üst ortada, dalga yazısının altında: "SEKTÖR 2/3" + sektördeki dalga pipleri
## (son pip = boss, elmas) + etkin kapı bedeli ("zor sektör") ve ödül çarpanı. Yalnız sonlu modlarda ve oyun sırasında.
## hud.gd'ye dokunmaz: kendi CanvasLayer'ında (menülerin altında) çizilir; durumu `ctx`'ten okur.

const KIT = preload("res://scripts/ui/ui_kit.gd")

var ctx: GameContext
var _t := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	var vp := get_viewport_rect().size
	if size != vp:
		size = vp
	var want := ctx != null and ctx.run != null and ctx.state == "playing" and ctx.hud.active and ctx.run.has_goal()
	visible = want
	if want:
		queue_redraw()


func _draw() -> void:
	var run := ctx.run
	var s := Settings.ui_scale()
	var a := 0.4 if ctx.hud.dimmed else 1.0
	var vp := get_viewport_rect().size
	var top := ctx.menus.margin.y + (82.0 if run.boss_alive else 66.0) * s
	var n := run.waves_per_sector()
	var at := run.wave_in_sector()
	var r := 6.0 * s
	var gap := 22.0 * s
	var label := tr("SEKTÖR %d/%d") % [run.current_sector(), run.total_sectors()]
	var font := KIT.bold()
	var fs := int(14 * s)
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pips_w := gap * float(n - 1)
	var total_w := lw + 16.0 * s + pips_w
	var x0 := vp.x * 0.5 - total_w * 0.5
	draw_string(font, Vector2(x0, top + 5.0 * s), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(KIT.GOLD, 0.95 * a))
	var px := x0 + lw + 16.0 * s
	var between := run.phase == RunState.PHASE_BREAK   # ara: bu dalga (ya da boss) temizlendi
	var done_count := at if between else at - 1
	for i in n:
		var c := Vector2(px + gap * float(i), top)
		var done := i < done_count
		var current := i == done_count and not between
		var col := KIT.RED if i == n - 1 else KIT.CYAN
		if i > 0:
			draw_line(Vector2(c.x - gap + r, c.y), Vector2(c.x - r, c.y), Color(KIT.DIM, 0.35 * a), 2.0)
		if i == n - 1:
			var rr := r * 1.35
			var diamond := PackedVector2Array([c + Vector2(0, -rr), c + Vector2(rr, 0), c + Vector2(0, rr), c + Vector2(-rr, 0)])
			if done or current:
				draw_colored_polygon(diamond, Color(col, (0.55 + 0.45 * sin(_t * 6.0) if current else 1.0) * a))
			diamond.append(diamond[0])
			draw_polyline(diamond, Color(col, a), 2.0, true)
		else:
			if done:
				draw_circle(c, r, Color(col, a))
			elif current:
				draw_circle(c, r, Color(col, (0.45 + 0.4 * sin(_t * 6.0)) * a))
			draw_arc(c, r, 0.0, TAU, 20, Color(col, 0.9 * a), 2.0, true)
	var tags: Array = []
	if run.enemy_hp_mod > 1.001 or run.enemy_damage_mod > 1.001:
		tags.append(tr("ZOR SEKTÖR"))
	if run.reward_mult > 1.001:
		tags.append(tr("ödül ×%.2f") % run.reward_mult)
	if not tags.is_empty():
		draw_string(KIT.font(), Vector2(0, top + 24.0 * s), "  ·  ".join(PackedStringArray(tags)), HORIZONTAL_ALIGNMENT_CENTER, vp.x, int(12 * s), Color(KIT.RED.lerp(KIT.GOLD, 0.5), 0.9 * a))
