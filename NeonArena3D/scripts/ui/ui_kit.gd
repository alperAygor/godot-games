extends RefCounted
class_name UIKit
## Arayüz yapı taşları: renkler, yazı tipleri, neon düğmeler, paneller, kaydırıcılar ve vektör ikonlar.

const BG := Color(0.015, 0.025, 0.055)
const PANEL := Color(0.03, 0.055, 0.105, 0.9)
const CYAN := Color(0.36, 0.92, 1.0)
const MAGENTA := Color(1.0, 0.32, 0.74)
const GOLD := Color(1.0, 0.82, 0.3)
const RED := Color(1.0, 0.3, 0.42)
const GREEN := Color(0.35, 1.0, 0.62)
const VIOLET := Color(0.72, 0.56, 1.0)
const ORANGE := Color(1.0, 0.6, 0.25)
const TEXT := Color(0.88, 0.95, 1.0)
const DIM := Color(0.56, 0.7, 0.88)
const SYNERGY := Color(1.0, 0.45, 0.78)
const TIER_COLOR := {"common": CYAN, "rare": VIOLET, "epic": ORANGE, "synergy": SYNERGY}
const TIER_NAME := {"common": "YAYGIN", "rare": "NADİR", "epic": "DESTANSI", "synergy": "SİNERJİ"}

static var _regular: Font
static var _bold: Font
static var _title: Font
static var _circles: Dictionary = {}

# --- Yazı tipleri -------------------------------------------------------------
const BODY_FONT := "res://assets/fonts/Exo2.ttf"
const TITLE_FONT := "res://assets/fonts/Oxanium.ttf"

static func _variant(path: String, weight: int, spacing := 0) -> Font:
	## Değişken yazı tipinden belirli ağırlıkta bir varyasyon. Dosya yoksa sistem yazı tipine düşer.
	var fv := FontVariation.new()
	if ResourceLoader.exists(path):
		fv.base_font = load(path)
		var tag := TextServerManager.get_primary_interface().name_to_tag("wght")
		fv.variation_opentype = {tag: weight}
	else:
		fv.base_font = ThemeDB.fallback_font
		fv.variation_embolden = clampf(float(weight - 400) / 400.0, 0.0, 1.0)
	fv.spacing_glyph = spacing
	return fv

static func font() -> Font:
	if _regular == null:
		_regular = _variant(BODY_FONT, 500)
	return _regular

static func bold() -> Font:
	if _bold == null:
		_bold = _variant(BODY_FONT, 700, 1)
	return _bold

static func title() -> Font:
	if _title == null:
		_title = _variant(TITLE_FONT, 800, 2)
	return _title

static func t(text: String) -> String:
	## Statik bağlamlar için çeviri (Node.tr() burada yok).
	return String(TranslationServer.translate(text))

# --- Kutular ------------------------------------------------------------------
static func box(bg: Color, border: Color, border_width := 2, cut := 12, glow := 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(cut)
	sb.corner_detail = 1
	sb.anti_aliasing = true
	if glow > 0.0:
		sb.shadow_color = Color(border.r, border.g, border.b, 0.3)
		sb.shadow_size = int(glow)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	return sb

static func button(text: String, accent := CYAN, min_size := Vector2(320, 62), font_size := 24, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", bold())
	b.add_theme_font_size_override("font_size", font_size)
	var base_bg := Color(accent.r * 0.16, accent.g * 0.16, accent.b * 0.16, 0.92) if primary else Color(0.03, 0.06, 0.11, 0.88)
	b.add_theme_stylebox_override("normal", box(base_bg, Color(accent, 0.85 if primary else 0.55), 2, 12, 12.0 if primary else 0.0))
	b.add_theme_stylebox_override("hover", box(Color(accent.r * 0.26, accent.g * 0.26, accent.b * 0.26, 0.95), accent, 2, 12, 16.0))
	b.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.55), 2, 12, 0.0))
	b.add_theme_stylebox_override("pressed", box(Color(accent.r * 0.5, accent.g * 0.5, accent.b * 0.5, 0.98), Color(1, 1, 1, 0.95), 2, 12, 20.0))
	b.add_theme_stylebox_override("disabled", box(Color(0.03, 0.04, 0.07, 0.7), Color(0.3, 0.36, 0.46, 0.5), 2, 12, 0.0))
	b.add_theme_color_override("font_color", Color(1, 1, 1) if primary else TEXT)
	b.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	b.add_theme_color_override("font_pressed_color", Color(1, 1, 1))
	b.add_theme_color_override("font_focus_color", Color(1, 1, 1))
	b.add_theme_color_override("font_disabled_color", Color(0.4, 0.46, 0.56))
	b.pressed.connect(func(): Sound.play("ui_click"))
	if not Settings.touch:
		b.mouse_entered.connect(func():
			if not b.disabled:
				Sound.play("ui_hover"))
	b.button_down.connect(func(): _press_anim(b, 0.96))
	b.button_up.connect(func(): _press_anim(b, 1.0))
	return b

static func _press_anim(node: Control, target: float) -> void:
	if not node.is_inside_tree():
		return
	node.pivot_offset = node.size * 0.5
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE * target, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

static func panel(accent := CYAN, pad := 28.0) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := box(PANEL, Color(accent, 0.5), 2, 18, 22.0)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	p.add_theme_stylebox_override("panel", sb)
	return p

static func label(text: String, size := 20, color := TEXT, use_font: Font = null, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_override("font", use_font if use_font != null else font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func heading(text: String, size := 40, color := CYAN) -> Label:
	var l := label(text, size, color, title(), HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_outline_color", Color(color.r, color.g, color.b, 0.22))
	l.add_theme_constant_override("outline_size", 10)
	return l

static func spacer(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

static func circle_texture(diameter: int, color: Color, ring := 0.0) -> ImageTexture:
	var key := "%d_%s_%.1f" % [diameter, color.to_html(), ring]
	if _circles.has(key):
		return _circles[key]
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var r := float(diameter) * 0.5
	for y in diameter:
		for x in diameter:
			var d := Vector2(float(x) + 0.5 - r, float(y) + 0.5 - r).length()
			var a := clampf(r - d, 0.0, 1.0)
			var c := color
			if ring > 0.0 and d < r - ring:
				c = Color(color.r * 0.25, color.g * 0.25, color.b * 0.25, color.a)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * a))
	var tex := ImageTexture.create_from_image(img)
	_circles[key] = tex
	return tex

static func slider(value: float, accent := CYAN) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(280, 44)
	s.focus_mode = Control.FOCUS_ALL
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.1, 0.16, 0.26, 0.95)
	track.set_corner_radius_all(5)
	track.content_margin_top = 5.0
	track.content_margin_bottom = 5.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = accent
	fill.set_corner_radius_all(5)
	fill.content_margin_top = 5.0
	fill.content_margin_bottom = 5.0
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := circle_texture(34, Color(1, 1, 1), 0.0)
	s.add_theme_icon_override("grabber", knob)
	s.add_theme_icon_override("grabber_highlight", knob)
	s.add_theme_icon_override("grabber_disabled", knob)
	return s

static func toggle(on: bool, accent := CYAN) -> Button:
	var b := button(t("AÇIK") if on else t("KAPALI"), accent if on else Color(0.5, 0.58, 0.7), Vector2(170, 50), 20, on)
	b.toggle_mode = true
	b.button_pressed = on
	return b

static func restyle_toggle(b: Button, on: bool, accent := CYAN) -> void:
	b.text = t("AÇIK") if on else t("KAPALI")
	var c := accent if on else Color(0.5, 0.58, 0.7)
	var bg := Color(c.r * 0.16, c.g * 0.16, c.b * 0.16, 0.92) if on else Color(0.03, 0.06, 0.11, 0.88)
	b.add_theme_stylebox_override("normal", box(bg, Color(c, 0.85 if on else 0.55), 2, 12, 12.0 if on else 0.0))
	b.add_theme_stylebox_override("pressed", box(bg, Color(c, 0.85 if on else 0.55), 2, 12, 12.0 if on else 0.0))
	b.add_theme_stylebox_override("hover", box(Color(c.r * 0.26, c.g * 0.26, c.b * 0.26, 0.95), c, 2, 12, 16.0))
	b.add_theme_stylebox_override("hover_pressed", box(Color(c.r * 0.26, c.g * 0.26, c.b * 0.26, 0.95), c, 2, 12, 16.0))
	b.add_theme_color_override("font_color", Color(1, 1, 1) if on else TEXT)

# --- Sayı biçimi --------------------------------------------------------------
static func fmt(value: int) -> String:
	var text := str(absi(value))
	var out := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-" if value < 0 else "") + out

static func fmt_time(seconds: float) -> String:
	var total := int(seconds)
	return "%d:%02d" % [total / 60, total % 60]

# --- Vektör ikonlar -----------------------------------------------------------
static func _poly(ci: CanvasItem, c: Vector2, s: float, pts: Array, color: Color, closed := true, width := 0.0) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + Vector2(p[0], p[1]) * s)
	if width <= 0.0:
		ci.draw_colored_polygon(out, color)
	else:
		if closed:
			out.append(out[0])
		ci.draw_polyline(out, color, width, true)

static func _star(ci: CanvasItem, c: Vector2, outer: float, inner: float, points: int, color: Color, rot := 0.0) -> void:
	var out := PackedVector2Array()
	for i in points * 2:
		var r := outer if i % 2 == 0 else inner
		out.append(c + Vector2.from_angle(rot + PI * float(i) / float(points) - PI * 0.5) * r)
	ci.draw_colored_polygon(out, color)

static func icon(ci: CanvasItem, kind: String, c: Vector2, s: float, color: Color) -> void:
	## s: ikonun yarı boyutu (piksel). Çizimler [-1, 1] aralığına göre ölçeklenir.
	var w := maxf(2.0, s * 0.13)
	var soft := Color(color.r, color.g, color.b, color.a * 0.35)
	match kind:
		"damage":
			_star(ci, c, s, s * 0.36, 4, color)
			ci.draw_circle(c, s * 0.2, Color(1, 1, 1, color.a))
		"rate":
			for i in 3:
				var x := (float(i) - 1.0) * 0.6
				_poly(ci, c, s, [[x - 0.3, -0.7], [x + 0.3, 0.0], [x - 0.3, 0.7]], Color(color, color.a * (0.45 + 0.27 * float(i))), false, w)
		"speed":
			_poly(ci, c, s, [[-0.2, -0.75], [0.9, 0.0], [-0.2, 0.75], [0.15, 0.0]], color)
			for i in 3:
				var y := (float(i) - 1.0) * 0.45
				ci.draw_line(c + Vector2(-0.95, y) * s, c + Vector2(-0.4, y) * s, soft, w, true)
		"armor", "shield":
			var pts := [[0.0, -0.95], [0.8, -0.6], [0.72, 0.25], [0.0, 0.98], [-0.72, 0.25], [-0.8, -0.6]]
			if kind == "shield":
				_poly(ci, c, s, pts, soft)
			_poly(ci, c, s, pts, color, true, w)
			if kind == "armor":
				ci.draw_line(c + Vector2(0, -0.4) * s, c + Vector2(0, 0.4) * s, color, w, true)
				ci.draw_line(c + Vector2(-0.4, 0) * s, c + Vector2(0.4, 0) * s, color, w, true)
			else:
				ci.draw_arc(c + Vector2(0, -0.05) * s, s * 0.3, 0.0, TAU, 20, color, w, true)
		"dash":
			_poly(ci, c, s, [[-0.1, -0.7], [0.9, 0.0], [-0.1, 0.7]], color, false, w * 1.3)
			_poly(ci, c, s, [[-0.75, -0.5], [-0.05, 0.0], [-0.75, 0.5]], soft, false, w)
		"magnet":
			ci.draw_arc(c + Vector2(0, -0.1) * s, s * 0.62, PI, TAU, 20, color, w * 2.2, true)
			ci.draw_line(c + Vector2(-0.62, -0.1) * s, c + Vector2(-0.62, 0.55) * s, color, w * 2.2)
			ci.draw_line(c + Vector2(0.62, -0.1) * s, c + Vector2(0.62, 0.55) * s, color, w * 2.2)
			ci.draw_line(c + Vector2(-0.62, 0.62) * s, c + Vector2(-0.62, 0.9) * s, Color(1, 1, 1, color.a), w * 2.2)
			ci.draw_line(c + Vector2(0.62, 0.62) * s, c + Vector2(0.62, 0.9) * s, Color(1, 1, 1, color.a), w * 2.2)
		"heavy":
			ci.draw_circle(c, s * 0.55, color)
			ci.draw_arc(c, s * 0.88, 0.0, TAU, 28, soft, w, true)
			ci.draw_circle(c + Vector2(-0.15, -0.15) * s, s * 0.16, Color(1, 1, 1, color.a * 0.9))
		"multi":
			for i in 3:
				var dir := Vector2.from_angle(-PI * 0.5 + (float(i) - 1.0) * 0.55)
				ci.draw_line(c + Vector2(0, 0.8) * s, c + Vector2(0, 0.8) * s + dir * s * 1.45, soft, w, true)
				ci.draw_circle(c + Vector2(0, 0.8) * s + dir * s * 1.5, s * 0.17, color)
		"pierce":
			ci.draw_line(c + Vector2(-0.95, 0) * s, c + Vector2(0.6, 0) * s, color, w * 1.2, true)
			_poly(ci, c, s, [[0.45, -0.35], [1.0, 0.0], [0.45, 0.35]], color)
			ci.draw_line(c + Vector2(-0.15, -0.85) * s, c + Vector2(-0.15, 0.85) * s, soft, w * 2.0)
		"vampire":
			_poly(ci, c, s, [[0.0, -0.95], [0.6, 0.15], [0.42, 0.65], [0.0, 0.9], [-0.42, 0.65], [-0.6, 0.15]], color)
			ci.draw_circle(c + Vector2(-0.14, 0.3) * s, s * 0.14, Color(1, 1, 1, color.a * 0.85))
		"crit":
			ci.draw_arc(c, s * 0.7, 0.0, TAU, 28, color, w, true)
			for i in 4:
				var d := Vector2.from_angle(TAU * float(i) / 4.0)
				ci.draw_line(c + d * s * 0.45, c + d * s * 1.0, color, w, true)
			_star(ci, c, s * 0.3, s * 0.12, 4, Color(1, 1, 1, color.a))
		"regen":
			ci.draw_arc(c, s * 0.82, -PI * 0.4, PI * 1.25, 24, soft, w, true)
			_poly(ci, c, s, [[0.1, -0.98], [0.52, -0.62], [0.02, -0.52]], soft)
			ci.draw_line(c + Vector2(0, -0.42) * s, c + Vector2(0, 0.42) * s, color, w * 1.8)
			ci.draw_line(c + Vector2(-0.42, 0) * s, c + Vector2(0.42, 0) * s, color, w * 1.8)
		"thorns":
			_star(ci, c, s, s * 0.5, 8, color)
			ci.draw_circle(c, s * 0.3, Color(0.03, 0.05, 0.1, color.a))
		"drone":
			ci.draw_arc(c, s * 0.8, 0.0, TAU, 28, soft, w, true)
			ci.draw_circle(c, s * 0.26, color)
			ci.draw_circle(c + Vector2.from_angle(-0.6) * s * 0.8, s * 0.2, Color(1, 1, 1, color.a))
			ci.draw_circle(c + Vector2.from_angle(2.5) * s * 0.8, s * 0.2, Color(1, 1, 1, color.a))
		"chain", "shock":
			if kind == "shock":
				ci.draw_arc(c, s * 0.9, 0.0, TAU, 28, soft, w, true)
			_poly(ci, c, s * (0.8 if kind == "shock" else 1.0), [[0.25, -1.0], [-0.5, 0.12], [0.02, 0.12], [-0.25, 1.0], [0.55, -0.22], [0.0, -0.22]], color)
		"nova":
			ci.draw_circle(c, s * 0.22, Color(1, 1, 1, color.a))
			ci.draw_arc(c, s * 0.5, 0.0, TAU, 24, color, w, true)
			ci.draw_arc(c, s * 0.88, 0.0, TAU, 28, soft, w, true)
			for i in 8:
				var d2 := Vector2.from_angle(TAU * float(i) / 8.0)
				ci.draw_line(c + d2 * s * 0.6, c + d2 * s * 0.8, color, w * 0.8, true)
		"explosive":
			_star(ci, c, s, s * 0.55, 9, color)
			_star(ci, c, s * 0.5, s * 0.25, 9, Color(1, 1, 1, color.a), 0.3)
		"revive":
			_poly(ci, c, s, [[0.0, 0.9], [-0.85, 0.0], [-0.85, -0.45], [-0.5, -0.8], [-0.2, -0.8], [0.0, -0.55], [0.2, -0.8], [0.5, -0.8], [0.85, -0.45], [0.85, 0.0]], color)
			ci.draw_line(c + Vector2(0, -0.2) * s, c + Vector2(0, 0.35) * s, Color(1, 1, 1, color.a), w * 1.3)
			ci.draw_line(c + Vector2(-0.27, 0.07) * s, c + Vector2(0.27, 0.07) * s, Color(1, 1, 1, color.a), w * 1.3)
		"core":
			var hexa := PackedVector2Array()
			for i in 6:
				hexa.append(c + Vector2.from_angle(TAU * float(i) / 6.0 - PI * 0.5) * s * 0.95)
			ci.draw_colored_polygon(hexa, Color(color.r * 0.35, color.g * 0.35, color.b * 0.35, color.a))
			var inner := PackedVector2Array()
			for i in 6:
				inner.append(c + Vector2.from_angle(TAU * float(i) / 6.0 - PI * 0.5) * s * 0.55)
			ci.draw_colored_polygon(inner, color)
			hexa.append(hexa[0])
			ci.draw_polyline(hexa, color, maxf(1.5, w * 0.9), true)
			for i in 3:
				ci.draw_line(inner[i * 2], hexa[i * 2], Color(color, color.a * 0.7), maxf(1.0, w * 0.6), true)
			ci.draw_circle(c + Vector2(-0.18, -0.2) * s, s * 0.13, Color(1, 1, 1, color.a * 0.85))
		"reroll":
			ci.draw_arc(c, s * 0.7, -PI * 0.1, PI * 0.85, 20, color, w * 1.2, true)
			ci.draw_arc(c, s * 0.7, PI * 0.9, PI * 1.85, 20, color, w * 1.2, true)
			_poly(ci, c, s, [[0.7, 0.42], [0.98, 0.0], [0.42, 0.06]], color)
			_poly(ci, c, s, [[-0.7, -0.42], [-0.98, 0.0], [-0.42, -0.06]], color)
		"xp":
			_poly(ci, c, s, [[0.0, -0.95], [0.62, 0.0], [0.0, 0.95], [-0.62, 0.0]], soft)
			_poly(ci, c, s, [[0.0, -0.95], [0.62, 0.0], [0.0, 0.95], [-0.62, 0.0]], color, true, w)
			_star(ci, c, s * 0.42, s * 0.14, 4, Color(1, 1, 1, color.a))
		"pause":
			ci.draw_rect(Rect2(c + Vector2(-0.55, -0.6) * s, Vector2(0.38, 1.2) * s), color, true)
			ci.draw_rect(Rect2(c + Vector2(0.17, -0.6) * s, Vector2(0.38, 1.2) * s), color, true)
		"heal":
			ci.draw_line(c + Vector2(0, -0.7) * s, c + Vector2(0, 0.7) * s, color, w * 2.4)
			ci.draw_line(c + Vector2(-0.7, 0) * s, c + Vector2(0.7, 0) * s, color, w * 2.4)
		"overdrive":
			_poly(ci, c, s, [[0.25, -1.0], [-0.5, 0.12], [0.02, 0.12], [-0.25, 1.0], [0.55, -0.22], [0.0, -0.22]], color)
		_:
			ci.draw_circle(c, s * 0.5, color)
