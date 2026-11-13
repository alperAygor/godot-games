class_name UiLanguageRow
extends VBoxContainer

## Ayarlar sayfasındaki dil satırı: TR / EN / ES üç küçük düz hap düğme, seçili olan vurgulu.
## Stil `UiKit` ile aynı çizgide: düz, çizgisiz, yumuşak renk. Seçim `Loc.choose` ile kaydedilir.

signal language_changed

const CAPTION_SIZE: int = 28
const PILL_FONT_SIZE: int = 32
const PILL_WIDTH: float = 132.0
const PILL_HEIGHT: float = 84.0
const PILL_GAP: int = 16
const CAPTION_GAP: int = 12
const PILL_STATES: Array[String] = ["normal", "hover", "pressed", "focus", "disabled"]
## Seçili dil tıklanamaz (disabled) ama okunur kalsın diye yazı rengi elle verilir.
const FONT_KEYS: Array[String] = ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]
const PILL_OFF_FILL: Color = Color(0.0, 0.0, 0.0, 0.06)


func _init() -> void:
	add_theme_constant_override("separation", CAPTION_GAP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(UiKit.label(UiStrings.language_caption(), CAPTION_SIZE, UiKit.TEXT_MUTED))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", PILL_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	for code: String in Loc.LANGUAGES:
		row.add_child(_pill(code))


func _pill(code: String) -> Button:
	var selected: bool = code == Loc.language()
	var button: Button = Button.new()
	button.text = code.to_upper()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(PILL_WIDTH, PILL_HEIGHT)
	button.disabled = selected
	var fill: Color = UiKit.ACCENT if selected else PILL_OFF_FILL
	for state: String in PILL_STATES:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = fill.darkened(0.08) if state == "pressed" else fill
		box.set_corner_radius_all(int(PILL_HEIGHT * 0.5))
		box.anti_aliasing = true
		button.add_theme_stylebox_override(state, box)
	var tint: Color = Color.WHITE if selected else UiKit.TEXT
	for key: String in FONT_KEYS:
		button.add_theme_color_override(key, tint)
	button.add_theme_font_size_override("font_size", PILL_FONT_SIZE)
	button.pressed.connect(_on_pressed.bind(code))
	return button


func _on_pressed(code: String) -> void:
	UiKit.tap_sound()
	Loc.choose(code)
	language_changed.emit()
