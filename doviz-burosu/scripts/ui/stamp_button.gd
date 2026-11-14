class_name StampButton
extends Button
## Masadaki fiziksel damga: ahşap tutamak + renkli mühür tabanı. Basınca damga kalkar ve iner (`press_animation`).
## `text` erişilebilirlik ve testler için durur; çizimi bu sınıf yapar.

@export var ink := Color("3F7D4E")

const HANDLE_HEIGHT := 40.0


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	for state in ["font_color", "font_pressed_color", "font_hover_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color"]:
		add_theme_color_override(state, Color(0, 0, 0, 0))


func _draw() -> void:
	var down := 5.0 if (get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED) else 0.0
	var alpha := 0.45 if disabled else 1.0
	var width := size.x
	# Tutamak: iki parçalı ahşap (sap + topuz)
	var knob := Rect2(width * 0.22, down, width * 0.56, HANDLE_HEIGHT * 0.62)
	draw_rect(Rect2(width * 0.42, down + HANDLE_HEIGHT * 0.55, width * 0.16, HANDLE_HEIGHT * 0.45), Color("6A4A2C", alpha))
	draw_rect(knob, Color("8A6238", alpha))
	draw_rect(Rect2(knob.position + Vector2(4, 3), Vector2(knob.size.x - 8, 5)), Color(1, 1, 1, 0.18 * alpha))
	# Mühür tabanı
	var body := Rect2(0, HANDLE_HEIGHT + down, width, size.y - HANDLE_HEIGHT - 6.0)
	draw_rect(Rect2(body.position + Vector2(0, 6), body.size), Color(0, 0, 0, 0.45 * alpha))
	draw_rect(body, Color(ink, alpha))
	draw_rect(body, Color(0, 0, 0, 0.5 * alpha), false, 3.0)
	draw_rect(Rect2(body.position + Vector2(8, 8), body.size - Vector2(16, 16)), Color(1, 1, 1, 0.5 * alpha), false, 2.0)
	var font := get_theme_default_font()
	var font_size := 38
	draw_string(font, Vector2(0, body.position.y + body.size.y / 2.0 + font_size * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color("F5EEDC", alpha))


## Damga kalkar, iner; `then` mühür vurulduğu an çağrılır. Animasyonsuz modda hemen.
func press_animation(then: Callable) -> void:
	if Feel.instant or not is_inside_tree():
		then.call()
		return
	pivot_offset = size / 2.0
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.09).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(0.96, 0.96), 0.05).set_ease(Tween.EASE_IN)
	tween.tween_callback(then)
	tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
