class_name UiIconButton
extends Button

## Küçük düz ikon düğmesi: görsel daire ~88 px, ama dokunma alanı 126 px.
## Neden özel çizim: StyleBox görsel boyutu = dokunma boyutu olurdu; burada daire
## kontrolden küçük çizilir, çevresi görünmez ama dokunulabilir.
## Aç/kapa kipinde (toggle_mode) açıkken vurgu renginde dolu, kapalıyken sönük ve çizgili.

const DISC_DIAMETER: float = float(UiTokens.ICON_DISC)
const ICON_PIXELS: float = 40.0
const BIG_DISC: float = float(UiTokens.ICON_HUD_DISC)
const BIG_ICON: float = float(UiTokens.ICON_HUD)
const BIG_TOUCH: float = float(UiTokens.ICON_HUD_TOUCH)
const PRESS_SCALE: float = 0.9
const PRESS_SECONDS: float = 0.12
const SLASH_WIDTH: float = 4.0
const RING_WIDTH: float = 8.0
const RING_STEPS: int = 48

## Basılı tutma kipi: REPEAT = basınca hemen etkinleşir, tutulursa `repeated` ile tekrarlar (geri al);
## CONFIRM = yalnız `hold_seconds` boyunca basılı tutulursa `confirmed` (baştan başlat); erken bırakınca `released_early`.
enum Hold { NONE, REPEAT, CONFIRM }

signal repeated
signal confirmed
signal released_early

var disc_color: Color = UiKit.DISC_SOFT
var icon_color: Color = UiKit.TEXT
## Aç/kapa kipinde açık/kapalı renkleri.
var on_disc: Color = UiKit.ACCENT
var on_icon: Color = Color.WHITE
var off_disc: Color = UiKit.DISC_OFF
var off_icon: Color = UiKit.TEXT_MUTED
var hold_mode: Hold = Hold.NONE
var hold_seconds: float = UiTokens.MOTION_HOLD_SECONDS
var _texture: Texture2D = null
var _press: float = 0.0
var _tween: Tween = null
var _big: bool = false
var _held: float = -1.0
var _repeat_clock: float = 0.0
var _fired: bool = false


## `big`: başparmak için büyük disk (HUD alt çubuğu): görsel 120, dokunma 144.
func setup(icon_name: String, toggle: bool = false, big: bool = false) -> void:
	_texture = Icons.texture(icon_name)
	toggle_mode = toggle
	_big = big
	var touch: float = BIG_TOUCH if big else UiKit.MIN_TOUCH
	custom_minimum_size = Vector2(touch, touch)
	set_process(false)
	focus_mode = Control.FOCUS_NONE
	flat = true
	var none: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state, none)
	button_down.connect(_on_down)
	button_up.connect(_on_up)
	toggled.connect(_on_toggled)
	pressed.connect(UiKit.tap_sound)


func set_hold(mode: Hold) -> void:
	hold_mode = mode
	# Tekrarlı düğme basıldığı anda etkinleşir (bırakmayı beklemez).
	action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS if mode == Hold.REPEAT else BaseButton.ACTION_MODE_BUTTON_RELEASE


func _on_toggled(_on: bool) -> void:
	queue_redraw()


func _on_down() -> void:
	_animate_press(1.0)
	if hold_mode != Hold.NONE and not disabled:
		_held = 0.0
		_repeat_clock = 0.0
		_fired = false
		set_process(true)


func _on_up() -> void:
	_animate_press(0.0)
	if hold_mode == Hold.CONFIRM and _held >= 0.0 and not _fired:
		released_early.emit()
	_held = -1.0
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	if _held < 0.0 or disabled:
		return
	_held += delta
	match hold_mode:
		Hold.CONFIRM:
			if not _fired and _held >= hold_seconds:
				_fired = true
				UiData.vibrate(UiTokens.SIZE_HAPTIC_MS)
				confirmed.emit()
			queue_redraw()
		Hold.REPEAT:
			if _held >= UiTokens.MOTION_REPEAT_DELAY:
				_repeat_clock += delta
				if _repeat_clock >= UiTokens.MOTION_REPEAT_RATE:
					_repeat_clock = 0.0
					repeated.emit()


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
	var diameter: float = BIG_DISC if _big else DISC_DIAMETER
	var icon_size: float = BIG_ICON if _big else ICON_PIXELS
	draw_circle(center, diameter * 0.5 * factor, disc, true, -1.0, true)
	if hold_mode == Hold.CONFIRM and _held > 0.0 and not _fired:
		var fraction: float = clampf(_held / hold_seconds, 0.0, 1.0)
		draw_arc(center, diameter * 0.5 * factor + RING_WIDTH, -PI * 0.5, -PI * 0.5 + TAU * fraction, RING_STEPS,
			UiKit.ACCENT, RING_WIDTH, true)
	var half: float = icon_size * 0.5 * factor
	if _texture != null:
		draw_texture_rect(_texture, Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0), false, tint)
	if is_off:
		# Kapalı durum: ikonun üstünden çapraz çizgi ("sessiz" göstergesi).
		var reach: float = half * 1.05
		draw_line(center + Vector2(-reach, -reach), center + Vector2(reach, reach), tint, SLASH_WIDTH, true)
