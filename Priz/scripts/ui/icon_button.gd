class_name UiIconButton
extends Button

## Küçük düz ikon düğmesi: görsel daire ~88 px, ama dokunma alanı 126 px.
## Neden özel çizim: StyleBox görsel boyutu = dokunma boyutu olurdu; burada daire
## kontrolden küçük çizilir, çevresi görünmez ama dokunulabilir.
## Aç/kapa kipinde (toggle_mode) açıkken vurgu renginde dolu, kapalıyken sönük ve çizgili.

const DISC_DIAMETER: float = 88.0
const ICON_PIXELS: float = 40.0
const PRESS_SCALE: float = 0.9
const PRESS_SECONDS: float = 0.12
const SLASH_WIDTH: float = 4.0

var disc_color: Color = UiKit.DISC_SOFT
var icon_color: Color = UiKit.TEXT
## Aç/kapa kipinde açık/kapalı renkleri.
var on_disc: Color = UiKit.ACCENT
var on_icon: Color = Color.WHITE
var off_disc: Color = UiKit.DISC_OFF
var off_icon: Color = UiKit.TEXT_MUTED
var _texture: Texture2D = null
var _press: float = 0.0
var _tween: Tween = null


func setup(icon_name: String, toggle: bool = false) -> void:
	_texture = Icons.texture(icon_name)
	toggle_mode = toggle
	custom_minimum_size = Vector2(UiKit.MIN_TOUCH, UiKit.MIN_TOUCH)
	focus_mode = Control.FOCUS_NONE
	flat = true
	var none: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, none)
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	toggled.connect(_on_toggled)
	pressed.connect(UiKit.tap_sound)


func _on_toggled(_on: bool) -> void:
	queue_redraw()


func _on_down() -> void:
	_animate_press(1.0)


func _on_up() -> void:
	_animate_press(0.0)


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
	var disc: Color = disc_color
	var tint: Color = icon_color
	var is_off: bool = false
	if toggle_mode:
		is_off = not button_pressed
		disc = off_disc if is_off else on_disc
		tint = off_icon if is_off else on_icon
	draw_circle(center, DISC_DIAMETER * 0.5 * factor, disc, true, -1.0, true)
	var half: float = ICON_PIXELS * 0.5 * factor
	if _texture != null:
		draw_texture_rect(_texture, Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0), false, tint)
	if is_off:
		# Kapalı durum: ikonun üstünden çapraz çizgi ("sessiz" göstergesi).
		var reach: float = half * 1.05
		draw_line(center + Vector2(-reach, -reach), center + Vector2(reach, reach), tint, SLASH_WIDTH, true)
