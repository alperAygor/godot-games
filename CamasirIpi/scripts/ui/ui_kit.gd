class_name UiKit
extends RefCounted

## Ortak arayüz yardımcıları: renkler, güvenli alan, etiket/düğme üreticileri.
## Düz, çizgisiz, neredeyse gölgesiz; kullanıcı tercihi "minimal modern" (CLAUDE.md).

const TEXT: Color = Color("2f3a36")
const TEXT_MUTED: Color = Color("7c8580")
const ACCENT: Color = Color("38a276")
const ACCENT_SOFT: Color = Color("dcefe3")
const SHEET: Color = Color("fbf8f0")
const GOLD: Color = Color("f2b63d")
const FLAME: Color = Color("f5894a")
const DANGER: Color = Color("f08a78")
const DISC_SOFT: Color = Color(1.0, 1.0, 1.0, 0.62)
const DISC_OFF: Color = Color("e9e6dc")
const DIM: Color = Color(0.1, 0.16, 0.13, 0.4)

## Dokunma hedefi alt sınırı (px) — görsel daha küçük olabilir.
const MIN_TOUCH: float = 126.0
const SIDE_MARGIN: float = 56.0
## Kenara yapışmasın: güvenli alan 0 olsa bile bırakılan en az boşluk.
const MIN_TOP_MARGIN: float = 72.0
const MIN_BOTTOM_MARGIN: float = 64.0
## Reklam düğmesi ile devam/tekrar düğmesi arası en az boşluk (42 px = 16 dp), biraz payla.
const AD_BUTTON_GAP: float = 54.0
const BUTTON_ICON_PIXELS: float = 44.0
const BUTTON_ICON_GAP: int = 16
const PRIMARY_FONT_SIZE: int = 46
const SECONDARY_FONT_SIZE: int = 38
const CAPTION_META: StringName = &"caption_label"
const TAP_SOUND: String = "ui_soft"
const TAP_VOLUME_DB: float = -4.0


## Güvenli alan boşlukları, görünüm (viewport) pikselinde: x=sol, y=üst, z=sağ, w=alt.
## Masaüstünde sistem güvenli alanı pencereyle ilgisiz olduğundan yalnız asgari boşluk verilir.
static func safe_insets(viewport_size: Vector2) -> Vector4:
	var insets: Vector4 = Vector4(0.0, MIN_TOP_MARGIN, 0.0, MIN_BOTTOM_MARGIN)
	if not OS.has_feature("mobile"):
		return insets
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	var screen: Vector2i = DisplayServer.screen_get_size()
	if screen.x <= 0 or screen.y <= 0 or safe.size.x <= 0:
		return insets
	var scale: float = viewport_size.x / float(screen.x)
	insets.x = maxf(float(safe.position.x) * scale, 0.0)
	insets.y = maxf(float(safe.position.y) * scale, MIN_TOP_MARGIN)
	insets.z = maxf(float(screen.x - safe.end.x) * scale, 0.0)
	insets.w = maxf(float(screen.y - safe.end.y) * scale, MIN_BOTTOM_MARGIN)
	return insets


static func label(text: String, font_size: int, color: Color = TEXT) -> Label:
	var node: Label = Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.add_theme_color_override("font_color", color)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func tap_sound() -> void:
	AudioService.play_pitched(TAP_SOUND, 1.0, TAP_VOLUME_DB)


## Temalı hap düğme. `variant`: &"" (birincil) ya da &"SecondaryButton".
## İkonlu düğmede ikon+metin birlikte ortalanır: Button.icon kullanılsaydı ikon sol kenara
## yapışır ya da metnin üstüne biner; bu yüzden içerik ayrı bir satır olarak kurulur.
static func button(text: String, variant: StringName, icon_name: String, min_height: float) -> Button:
	var node: Button = Button.new()
	node.theme_type_variation = variant
	node.custom_minimum_size = Vector2(0.0, maxf(min_height, MIN_TOUCH))
	node.focus_mode = Control.FOCUS_NONE
	node.pressed.connect(tap_sound)
	if icon_name.is_empty() or Icons.texture(icon_name) == null:
		node.text = text
		return node
	var secondary: bool = variant == &"SecondaryButton"
	var tint: Color = TEXT if secondary else Color.WHITE
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(center)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", BUTTON_ICON_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(row)
	var icon: TextureRect = tinted_icon(icon_name, BUTTON_ICON_PIXELS, tint)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var caption: Label = label(text, SECONDARY_FONT_SIZE if secondary else PRIMARY_FONT_SIZE, tint)
	row.add_child(caption)
	node.set_meta(CAPTION_META, caption)
	return node


## `button()` ile üretilmiş düğmenin metnini değiştirir (ikonlu düğmede metin ayrı etikettedir).
static func set_button_text(node: Button, text: String) -> void:
	if node.has_meta(CAPTION_META):
		(node.get_meta(CAPTION_META) as Label).text = text
	else:
		node.text = text


static func spacer(height: float) -> Control:
	var node: Control = Control.new()
	node.custom_minimum_size = Vector2(0.0, height)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


static func tinted_icon(icon_name: String, pixels: float, color: Color) -> TextureRect:
	var node: TextureRect = TextureRect.new()
	node.texture = Icons.texture(icon_name)
	node.custom_minimum_size = Vector2(pixels, pixels)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.modulate = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
