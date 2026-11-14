class_name MenuEmblem
extends Control
## Ana menünün amblemi: iki eğik banknot ve bir "KABUL" damgası (veriden çizilir, resim dosyası yok).

const NOTES := [
	{"color": Color("CFE3D2"), "ink": Color("2F5C45"), "denom": "100", "code": "FED", "angle": -0.14, "at": Vector2(-70, 6)},
	{"color": Color("F2DDC4"), "ink": Color("7A4A22"), "denom": "50", "code": "DNR", "angle": 0.12, "at": Vector2(52, 38)},
]
const STAMP := Color("B8362E")


func _init() -> void:
	custom_minimum_size = Vector2(0, 330)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var font := get_theme_default_font()
	var middle := Vector2(size.x / 2.0, size.y * 0.42)
	for spec: Dictionary in NOTES:
		_draw_note(font, middle + spec["at"], float(spec["angle"]), spec)
	draw_set_transform(middle + Vector2(-110, 110), -0.21, Vector2.ONE)
	draw_arc(Vector2.ZERO, 78.0, 0.0, TAU, 48, Color(STAMP, 0.85), 6.0)
	draw_arc(Vector2.ZERO, 64.0, 0.0, TAU, 48, Color(STAMP, 0.5), 2.0)
	var word := tr("FATE_ACCEPT").to_upper()
	var word_size := 46 if word.length() <= 5 else 38  # İngilizce "ACCEPT" damgadan taşmasın
	draw_string(font, Vector2(-64, 14), word, HORIZONTAL_ALIGNMENT_CENTER, 128.0, word_size, Color(STAMP, 0.9))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_note(font: Font, center: Vector2, angle: float, spec: Dictionary) -> void:
	var half := Vector2(165, 82)
	var ink: Color = spec["ink"]
	draw_set_transform(center + Vector2(0, 6), angle, Vector2.ONE)
	draw_rect(Rect2(-half, half * 2.0), Color(0, 0, 0, 0.18))
	draw_set_transform(center, angle, Vector2.ONE)
	draw_rect(Rect2(-half, half * 2.0), spec["color"])
	draw_rect(Rect2(-half + Vector2(8, 8), half * 2.0 - Vector2(16, 16)), Color(ink, 0.55), false, 2.0)
	for i in 3:
		draw_arc(Vector2(-half.x + 70, 4), 22.0 + i * 12.0, 0.0, TAU, 36, Color(ink, 0.2), 1.5)
	draw_circle(Vector2(-half.x + 70, 4), 22.0, Color(ink, 0.25))
	draw_rect(Rect2(half.x * 0.12, -half.y + 8, 10, half.y * 2.0 - 16), Color("3C8D6B", 0.85))
	draw_string(font, Vector2(-half.x + 18, -half.y + 36), str(spec["code"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, ink)
	draw_string(font, Vector2(half.x - 150, 28), str(spec["denom"]), HORIZONTAL_ALIGNMENT_RIGHT, 130.0, 92, ink)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
