class_name UiLanguageRow
extends VBoxContainer

## Ayarlar sayfasındaki dil satırı: TR / EN / ES üç küçük düz hap düğme, seçili olan vurgulu.
## Stil `UiKit` ile aynı çizgide: düz, çizgisiz, yumuşak renk. Seçim `Loc.choose` ile kaydedilir.

signal language_changed

const PILL_FONT_SIZE: int = UiKit.TYPE_CAPTION + 4
const PILL_WIDTH: float = 132.0
const PILL_HEIGHT: float = 84.0
const PILL_GAP: int = UiTokens.SPACE_MD
const PILL_STATES: Array[String] = ["normal", "hover", "pressed", "focus", "disabled"]
const PILL_OFF_FILL: Color = Color(0.0, 0.0, 0.0, 0.06)



func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Altyazı yok: TR/EN/ES hapları kendini açıklar (az metin kuralı).
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", PILL_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for code: String in Loc.LANGUAGES:
		row.add_child(_pill(code))


## Dokunma alanı 126 px, görsel hap 84 px: düğme boş stillidir, hap ve yazı çocuk olarak çizilir
## (UiIconButton ile aynı ilke: küçük görsel, büyük dokunma hedefi).
func _pill(code: String) -> Button:
	var selected: bool = code == Loc.language()
	var button: Button = Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(PILL_WIDTH, UiKit.MIN_TOUCH)
	button.disabled = selected
	button.flat = true
	var none: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: String in PILL_STATES:
		button.add_theme_stylebox_override(state, none)
	var plate: Panel = Panel.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = UiKit.ACCENT if selected else PILL_OFF_FILL
	box.set_corner_radius_all(int(PILL_HEIGHT * 0.5))
	box.anti_aliasing = true
	plate.add_theme_stylebox_override("panel", box)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	var inset: float = (UiKit.MIN_TOUCH - PILL_HEIGHT) * 0.5
	plate.offset_top = inset
	plate.offset_bottom = -inset
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(plate)
	var caption: Label = UiKit.label(code.to_upper(), PILL_FONT_SIZE, Color.WHITE if selected else UiKit.TEXT)
	caption.set_anchors_preset(Control.PRESET_FULL_RECT)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_child(caption)
	UiKit.attach_press_scale(button)
	button.pressed.connect(_on_pressed.bind(code))
	return button


func _on_pressed(code: String) -> void:
	UiKit.tap_sound()
	Loc.choose(code)
	language_changed.emit()
