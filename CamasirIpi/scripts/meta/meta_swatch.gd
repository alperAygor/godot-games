class_name MetaSwatch
extends Button

## Varyant seçimi için yuvarlak renk örneği. Seçili olan hafifçe büyür ve ortasında beyaz
## onay ikonu belirir — çerçeve/halka YOK (kullanıcı: kenarlıksız, düz).
## Görsel daire dokunma alanından küçüktür (UiIconButton ile aynı yaklaşım).

const DIAMETER: float = 96.0
const SELECTED_SCALE: float = 1.16
const PRESS_SCALE: float = 0.9
const ANIM_SECONDS: float = 0.22
const CHECK_PIXELS: float = 40.0
## Çok açık renklerde beyaz onay görünmez; bu parlaklığın üstünde koyu onay çizilir.
const LIGHT_LUMA: float = 0.8
## Açık renkli örnek kremsi kartta kaybolmasın: çok hafif bir taban gölgesi.
const SHADOW: Color = Color(0.18, 0.22, 0.2, 0.13)
const SHADOW_OFFSET: Vector2 = Vector2(0.0, 5.0)

var color: Color = Color.WHITE
var _selected: float = 0.0
var _press: float = 0.0
var _check: Texture2D = null


func setup(swatch_color: Color) -> void:
	color = swatch_color
	_check = Icons.texture("lucide/check")
	custom_minimum_size = Vector2(UiKit.MIN_TOUCH, UiKit.MIN_TOUCH)
	focus_mode = Control.FOCUS_NONE
	flat = true
	var none: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, none)
	button_down.connect(_animate.bind(&"_press", 1.0))
	button_up.connect(_animate.bind(&"_press", 0.0))


func set_selected(on: bool, animated: bool = true) -> void:
	if not animated:
		_selected = 1.0 if on else 0.0
		queue_redraw()
		return
	_animate(&"_selected", 1.0 if on else 0.0)


func _animate(property: StringName, target: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_method(_set_value.bind(property), float(get(property)), target, ANIM_SECONDS)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_value(value: float, property: StringName) -> void:
	set(property, value)
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var factor: float = lerpf(1.0, SELECTED_SCALE, _selected) * lerpf(1.0, PRESS_SCALE, _press)
	var radius: float = DIAMETER * 0.5 * factor
	draw_circle(center + SHADOW_OFFSET, radius, SHADOW, true, -1.0, true)
	draw_circle(center, radius, color, true, -1.0, true)
	if _check != null and _selected > 0.01:
		var tint: Color = UiKit.TEXT if color.get_luminance() > LIGHT_LUMA else Color.WHITE
		tint.a = clampf(_selected, 0.0, 1.0)
		var half: float = CHECK_PIXELS * 0.5 * factor
		draw_texture_rect(_check, Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0), false, tint)
