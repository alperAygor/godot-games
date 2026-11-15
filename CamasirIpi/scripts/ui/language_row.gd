class_name UiLanguageRow
extends VBoxContainer

## Ayarlar sayfasındaki dil satırı: yedi dil, her biri KENDİ adıyla (Türkçe, English, Español, Português, Deutsch,
## 日本語, 한국어) küçük düz hap düğme; seçili olan vurgulu. Sığmayanlar alt satıra akar (HFlowContainer).
## Japonca/Korece adlar Baloo'da yoktur: bu etiketler HER dilde sistem CJK zincirini kullanır (`LocFonts`).
## Stil `UiKit` ile aynı çizgide: düz, çizgisiz, yumuşak renk. Seçim `Loc.choose` ile kaydedilir.

signal language_changed

const PILL_FONT_SIZE: int = UiKit.TYPE_CAPTION + 4
const PILL_MIN_WIDTH: float = 132.0
const PILL_PAD: float = 36.0
const PILL_HEIGHT: float = 84.0
const PILL_GAP: int = UiTokens.SPACE_MD
const PILL_STATES: Array[String] = ["normal", "hover", "pressed", "focus", "disabled"]
const PILL_OFF_FILL: Color = Color(0.0, 0.0, 0.0, 0.06)



func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Altyazı yok: yerel adlar kendini açıklar (az metin kuralı).
	var row: HFlowContainer = HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", PILL_GAP)
	row.add_theme_constant_override("v_separation", 0)
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
	button.name = "Lang_" + code
	button.set_meta(&"language", code)
	var font: Font = LocFonts.selector_font(code)
	var name_text: String = String(Loc.NATIVE_NAMES[code])
	var text_width: float = font.get_string_size(name_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, PILL_FONT_SIZE).x
	button.custom_minimum_size = Vector2(maxf(PILL_MIN_WIDTH, text_width + PILL_PAD * 2.0), UiKit.MIN_TOUCH)
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
	var caption: Label = UiKit.label(name_text, PILL_FONT_SIZE, Color.WHITE if selected else UiKit.TEXT)
	caption.add_theme_font_override("font", font)
	# Han birleştirmesi: kanji/hangul etiketi kendi dilinin biçimiyle çizilsin.
	caption.language = code
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
