class_name MapDiscButton
extends Button

## Yuvarlak, düz, çizgisiz ikon düğmesi (UiIconButton ile aynı dil) — ama ikon MapIcons'tan gelir.
## Görsel disk dokunma alanından küçüktür (126 px dokunma, varsayılan 88 px disk).

const PRESS_SCALE: float = 0.9
const PRESS_SECONDS: float = 0.12
const ICON_RATIO: float = 0.46

var disc_color: Color = UiKit.DISC_SOFT
var icon_color: Color = UiKit.TEXT
var disc_diameter: float = UiIconButton.DISC_DIAMETER
var _texture: Texture2D = null
var _press: float = 0.0
var _tween: Tween = null


func setup(icon_name: String, diameter: float = UiIconButton.DISC_DIAMETER) -> void:
	_texture = MapIcons.texture(icon_name)
	disc_diameter = diameter
	custom_minimum_size = Vector2(UiKit.MIN_TOUCH, UiKit.MIN_TOUCH)
	size = custom_minimum_size
	focus_mode = Control.FOCUS_NONE
	flat = true
	var none: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, none)
	button_down.connect(_animate_press.bind(1.0))
	button_up.connect(_animate_press.bind(0.0))
	pressed.connect(UiKit.tap_sound)


func _animate_press(target: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_press, _press, target, PRESS_SECONDS)


func _set_press(value: float) -> void:
	_press = value
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var factor: float = lerpf(1.0, PRESS_SCALE, _press)
	draw_circle(center, disc_diameter * 0.5 * factor, disc_color, true, -1.0, true)
	if _texture != null:
		var half: float = disc_diameter * ICON_RATIO * 0.5 * factor
		draw_texture_rect(_texture, Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0), false, icon_color)
