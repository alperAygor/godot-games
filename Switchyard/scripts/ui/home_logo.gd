class_name HomeLogo
extends VBoxContainer

## Ana ekran başlık bloğu: oyunun makas simgesi (yuvarlak zemin üstünde ikiye ayrılan hat), ad ve tek satır alt yazı.
## Simge vektörle çizilir (pürüzsüz, her boyda keskin); yazı tipi temadaki Baloo 2.

const MARK_SIZE: float = 128.0
const MARK_RADIUS: int = 40
const MARK_LINE: float = 10.0
const MARK_STEPS: int = 20
const MARK_INSET: float = 30.0
const TAGLINE_COLOR: Color = UiTokens.C_TEXT_MUTED

var _mark: Control = null
var _title: Label = null
var _tagline: Label = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", UiTokens.SPACE_SM)
	_mark = Mark.new()
	_mark.custom_minimum_size = Vector2(MARK_SIZE, MARK_SIZE)
	_mark.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_mark)
	_title = UiKit.wrap_label(UiStrings.game_title(), UiTokens.TYPE_LOGO, UiTokens.C_INK)
	_title.name = "Title"
	add_child(_title)
	_tagline = UiKit.wrap_label(UiStrings.home_tagline(), UiTokens.TYPE_TAGLINE, TAGLINE_COLOR)
	_tagline.name = "Tagline"
	add_child(_tagline)


## Açılış: simge, ad ve alt yazı sırayla yükselerek belirir (az harekette anında).
func play_intro() -> void:
	if UiData.reduced_motion():
		return
	var index: int = 0
	for part: Control in [_mark, _title, _tagline]:
		part.modulate.a = 0.0
		var tween: Tween = part.create_tween()
		tween.tween_interval(float(index) * UiTokens.MOTION_STAGGER_SECONDS * 0.6)
		tween.tween_property(part, "modulate:a", 1.0, UiTokens.MOTION_SCREEN_SECONDS * 1.4)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		index += 1


class Mark extends Control:
	var _left: PackedVector2Array = PackedVector2Array()
	var _right: PackedVector2Array = PackedVector2Array()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = UiTokens.C_PRIMARY
		box.set_corner_radius_all(MARK_RADIUS)
		box.anti_aliasing = true
		box.shadow_color = Color(UiTokens.C_PRIMARY, 0.28)
		box.shadow_size = 18
		box.shadow_offset = Vector2(0.0, 8.0)
		draw_style_box(box, Rect2(Vector2.ZERO, size))
		var inset: float = MARK_INSET
		var base: Vector2 = Vector2(size.x * 0.5, size.y - inset)
		var split: Vector2 = Vector2(size.x * 0.5, size.y * 0.52)
		var reach: float = size.x * 0.5 - inset
		_left = _branch(split, Vector2(size.x * 0.5 - reach * 0.62, inset), -1.0)
		_right = _branch(split, Vector2(size.x * 0.5 + reach * 0.62, inset), 1.0)
		draw_line(base, split, Color.WHITE, MARK_LINE, true)
		draw_polyline(_left, Color.WHITE, MARK_LINE, true)
		draw_polyline(_right, Color(1.0, 1.0, 1.0, 0.55), MARK_LINE, true)
		draw_circle(base, MARK_LINE * 0.5, Color.WHITE, true, -1.0, true)

	func _branch(from_point: Vector2, to_point: Vector2, _direction: float) -> PackedVector2Array:
		var points: PackedVector2Array = PackedVector2Array()
		var pull: float = (from_point.y - to_point.y) * 0.5
		var control_a: Vector2 = from_point + Vector2(0.0, -pull)
		var control_b: Vector2 = to_point + Vector2(0.0, pull)
		for step: int in range(MARK_STEPS + 1):
			points.append(from_point.bezier_interpolate(control_a, control_b, to_point, float(step) / float(MARK_STEPS)))
		return points
