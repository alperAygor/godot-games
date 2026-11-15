class_name UiKit
extends RefCounted

## Ortak arayüz yardımcıları: renkler, güvenli alan, etiket/düğme üreticileri.
## Düz, çizgisiz, tek çok yumuşak yükseklik; kullanıcı tercihi "minimal modern" (CLAUDE.md).
## Değerlerin TEK kaynağı data/theme.json'dur (UiTokens üretilir); burada yalnız rol adları var.
## Eski adlar (TEXT, ACCENT, GOLD ...) başka ekranlar kullandığı için korunur.

# --- Renk rolleri ---
const TEXT: Color = UiTokens.C_TEXT
const TEXT_MUTED: Color = UiTokens.C_TEXT_MUTED
const ACCENT: Color = UiTokens.C_PRIMARY
const ACCENT_SOFT: Color = UiTokens.C_ACCENT_SOFT
const SHEET: Color = UiTokens.C_SHEET
const SURFACE_SOFT: Color = UiTokens.C_SURFACE_SOFT
const GOLD: Color = UiTokens.C_COIN
const COIN_SOFT: Color = UiTokens.C_COIN_SOFT
const STAR: Color = UiTokens.C_STAR
const FLAME: Color = UiTokens.C_WARNING
const DANGER: Color = UiTokens.C_DANGER
const DISC_SOFT: Color = Color(1.0, 1.0, 1.0, 0.62)
const DISC_OFF: Color = Color("e9e6dc")
## Sayfa arkası: koyu yeşilimsi, hafif soluk bir ton (gerçek bulanıklık pahalı; ton yeterli).
const DIM: Color = Color(0.1, 0.16, 0.13, UiTokens.ELEV_DIM_ALPHA)
## Satır/karo zemini üstünde yarı saydam beyaz (ikon diski, sönük durum).
const SURFACE_LIFT: Color = Color(1.0, 1.0, 1.0, 0.7)
## Birincil düğmenin üst yarısındaki çok hafif iç ışık.
const SHEEN: Color = Color(1.0, 1.0, 1.0, 0.10)
const SHEEN_INSET: float = 24.0
const SHEEN_TOP: float = 6.0

# --- Aralık, yarıçap, yazı, boy ---
const SPACE_XS: float = float(UiTokens.SPACE_XS)
const SPACE_SM: float = float(UiTokens.SPACE_SM)
const SPACE_MD: float = float(UiTokens.SPACE_MD)
const SPACE_LG: float = float(UiTokens.SPACE_LG)
const SPACE_XL: float = float(UiTokens.SPACE_XL)
const SPACE_XXL: float = float(UiTokens.SPACE_XXL)
const RADIUS_CARD: int = UiTokens.RADIUS_CARD
const RADIUS_TILE: int = UiTokens.RADIUS_TILE
const TYPE_DISPLAY: int = UiTokens.TYPE_DISPLAY
const TYPE_NUMERIC: int = UiTokens.TYPE_NUMERIC
const TITLE_SIZE: int = UiTokens.TYPE_TITLE
const TYPE_HEADING: int = UiTokens.TYPE_HEADING
const TYPE_BODY: int = UiTokens.TYPE_BODY
const TYPE_CAPTION: int = UiTokens.TYPE_CAPTION
const TYPE_MICRO: int = UiTokens.TYPE_MICRO
const HEIGHT_PRIMARY: float = float(UiTokens.H_BUTTON_PRIMARY)
const HEIGHT_SECONDARY: float = float(UiTokens.H_BUTTON_SECONDARY)
const HEIGHT_COMPACT: float = float(UiTokens.H_BUTTON_COMPACT)
const ICON_SM: float = float(UiTokens.ICON_SM)
const ICON_MD: float = float(UiTokens.ICON_MD)
const ICON_LG: float = float(UiTokens.ICON_LG)
const DISC_LG: float = float(UiTokens.ICON_DISC_LG)

## Dokunma hedefi alt sınırı (px) — görsel daha küçük olabilir.
const MIN_TOUCH: float = 126.0
const SIDE_MARGIN: float = 56.0
## Kenara yapışmasın: güvenli alan 0 olsa bile bırakılan en az boşluk.
const MIN_TOP_MARGIN: float = 72.0
const MIN_BOTTOM_MARGIN: float = 64.0
## Reklam düğmesi ile devam/tekrar düğmesi arası en az boşluk (42 px = 16 dp), biraz payla.
const AD_BUTTON_GAP: float = 54.0
const BUTTON_ICON_PIXELS: float = ICON_MD
const BUTTON_ICON_GAP: int = UiTokens.SPACE_MD
const PRIMARY_FONT_SIZE: int = UiTokens.TYPE_BUTTON
const SECONDARY_FONT_SIZE: int = UiTokens.TYPE_BUTTON_SECONDARY
const CAPTION_META: StringName = &"caption_label"
const AUDIO_PATH: NodePath = ^"/root/AudioService"
const TAP_SOUND: String = "ui_soft"
const TAP_VOLUME_DB: float = -4.0
const FONT_PATH: String = "res://assets/fonts/Baloo2.ttf"
const TABULAR_FEATURE: String = "tnum"
const GROUP_FROM_DIGITS: int = 4
const GROUP_SIZE: int = 3
const SHEEN_HALF: float = 0.5
const PRESS_META: StringName = &"press_scale"
const DISABLED_ALPHA: float = 0.5
const COUNT_SECONDS: float = UiTokens.MOTION_COUNT_SECONDS
static var _numeric_font: Font = null


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


## Uzun (EN/ES) metinler için: kutuya sığmazsa kelime sınırında alt satıra kırılır, taşmaz.
static func wrap_label(text: String, font_size: int, color: Color = TEXT) -> Label:
	var node: Label = label(text, font_size, color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return node


## Sayı etiketi: sabit genişlikli rakamlar (tnum). Neden: sayarken ve sütunlarda basamaklar
## zıplamasın, sayılar hizalı dursun. Yazı tipinde tnum yoksa sessizce normal rakamlara düşer.
static func numeric_label(text: String, font_size: int, color: Color = TEXT) -> Label:
	var node: Label = label(text, font_size, color)
	node.add_theme_font_override("font", numeric_font())
	return node


static func numeric_font() -> Font:
	if _numeric_font == null:
		var variation: FontVariation = FontVariation.new()
		variation.base_font = load(FONT_PATH) as Font
		var tag: int = TextServerManager.get_primary_interface().name_to_tag(TABULAR_FEATURE)
		variation.opentype_features = {tag: 1}
		_numeric_font = variation
	return _numeric_font


## Binlik ayraçlı tam sayı ("12.480" tr/es, "12,480" en). Dört haneye kadar ayraçsız: küçük sayılar sade.
static func fmt_int(value: int) -> String:
	var digits: String = str(absi(value))
	if digits.length() <= GROUP_FROM_DIGITS:
		return str(value)
	var separator: String = "," if Loc.language() == Loc.LANG_EN else "."
	var grouped: String = ""
	while digits.length() > GROUP_SIZE:
		grouped = separator + digits.substr(digits.length() - GROUP_SIZE) + grouped
		digits = digits.substr(0, digits.length() - GROUP_SIZE)
	return ("-" if value < 0 else "") + digits + grouped


## Autoload'a düğüm yoluyla erişilir: araç (-s) kipinde betikler autoload'lardan önce derlenir.
static func tap_sound() -> void:
	var audio: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null(AUDIO_PATH)
	if audio != null:
		audio.call("play_pitched", TAP_SOUND, 1.0, TAP_VOLUME_DB)


## Temalı hap düğme. `variant`: &"" (birincil) ya da &"SecondaryButton".
## İkonlu düğmede ikon+metin birlikte ortalanır: Button.icon kullanılsaydı ikon sol kenara
## yapışır ya da metnin üstüne biner; bu yüzden içerik ayrı bir satır olarak kurulur.
## Her düğme basınca hafifçe küçülür (press_scale); birincil düğmede çok hafif iç ışık vardır.
static func button(text: String, variant: StringName, icon_name: String, min_height: float) -> Button:
	var node: Button = Button.new()
	node.theme_type_variation = variant
	node.custom_minimum_size = Vector2(0.0, maxf(min_height, MIN_TOUCH))
	node.focus_mode = Control.FOCUS_NONE
	node.pressed.connect(tap_sound)
	attach_press_scale(node)
	if variant == &"":
		_add_sheen(node)
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


## Üst yarıda yarı saydam beyaz yuvarlak şerit: düz renge "yumuşak ışık" verir, ek doku/shader yok.
static func _add_sheen(node: Button) -> void:
	var sheen: Panel = Panel.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = SHEEN
	box.set_corner_radius_all(UiTokens.RADIUS_PILL)
	box.anti_aliasing = true
	sheen.add_theme_stylebox_override("panel", box)
	sheen.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheen.anchor_bottom = SHEEN_HALF
	sheen.offset_left = SHEEN_INSET
	sheen.offset_right = -SHEEN_INSET
	sheen.offset_top = SHEEN_TOP
	sheen.offset_bottom = 0.0
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheen.name = "Sheen"
	node.add_child(sheen)


## Basınca yumuşakça küçülüp bırakınca yaylanarak dönen düğme geri bildirimi (her düğme ailesi için ortak).
static func attach_press_scale(node: Control) -> void:
	node.resized.connect(_center_pivot.bind(node))
	node.set_meta(PRESS_META, true)
	if node is BaseButton:
		var base: BaseButton = node as BaseButton
		base.button_down.connect(_press_to.bind(node, UiTokens.MOTION_PRESS_SCALE, UiTokens.MOTION_PRESS_SECONDS, false))
		base.button_up.connect(_press_to.bind(node, 1.0, UiTokens.MOTION_RELEASE_SECONDS, true))


static func _center_pivot(node: Control) -> void:
	node.pivot_offset = node.size * 0.5


static func _press_to(node: Control, target: float, seconds: float, springy: bool) -> void:
	if not node.is_inside_tree():
		return
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE * target, seconds)\
		.set_trans(Tween.TRANS_BACK if springy else Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## `button()` ile üretilmiş düğmenin metnini değiştirir (ikonlu düğmede metin ayrı etikettedir).
static func set_button_text(node: Button, text: String) -> void:
	if node.has_meta(CAPTION_META):
		(node.get_meta(CAPTION_META) as Label).text = text
	else:
		node.text = text


## Kapalı durum: arka plan temadan, ikonlu içerik burada soluklaşır (tek görünüm her yerde).
static func set_enabled(node: Button, enabled: bool) -> void:
	node.disabled = not enabled
	for child: Node in node.get_children():
		if child is CenterContainer:
			(child as CenterContainer).modulate.a = 1.0 if enabled else DISABLED_ALPHA


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


## Düz daire + ortada ikon (görev/ödül/boş durum diski). Eski yerel `disc` kopyalarının yerine.
static func disc(icon_name: String, bg: Color, fg: Color, diameter: float = DISC_LG,
		icon_pixels: float = ICON_LG) -> Panel:
	var node: Panel = Panel.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.set_corner_radius_all(int(diameter * 0.5))
	box.anti_aliasing = true
	node.add_theme_stylebox_override("panel", box)
	node.custom_minimum_size = Vector2(diameter, diameter)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon: TextureRect = tinted_icon(icon_name, icon_pixels, fg)
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	node.add_child(icon)
	return node


## Ortalanmış disk (sayfa tepesinde tek başına dururken).
static func centered_disc(icon_name: String, bg: Color = ACCENT_SOFT, fg: Color = ACCENT) -> Control:
	var holder: CenterContainer = CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(disc(icon_name, bg, fg))
	return holder


## Düz yuvarlatılmış yüzey stili (kart/karo): çizgisiz, gölgesiz.
static func card_style(color: Color = SURFACE_SOFT, radius: int = RADIUS_CARD, pad_x: int = 28,
		pad_y: int = 22) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	return box


static func card(color: Color = SURFACE_SOFT, radius: int = RADIUS_CARD, pad_x: int = 28,
		pad_y: int = 22) -> PanelContainer:
	var node: PanelContainer = PanelContainer.new()
	node.add_theme_stylebox_override("panel", card_style(color, radius, pad_x, pad_y))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Boş / kilitli durum: küçük ikon diski + tek kısa, sönük satır. Gürültüsüz, sakin.
static func empty_state(icon_name: String, text: String) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", int(SPACE_LG))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(centered_disc(icon_name))
	column.add_child(wrap_label(text, TYPE_BODY, TEXT_MUTED))
	return column


## Ödül anı: yumuşak "pop" (büyüyüp yerine oturur). Sayfa/ödül düğümleri ortak kullanır.
static func pop(node: Control) -> void:
	if not node.is_inside_tree():
		return
	node.pivot_offset = node.size * 0.5
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "scale", Vector2.ONE * UiTokens.MOTION_POP_SCALE, UiTokens.MOTION_PRESS_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, UiTokens.MOTION_RELEASE_SECONDS)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Sayıya yumuşakça sayma. `format` her karede metni üretir (ör. "+%d"). Dönen tween iptal edilebilir.
static func count_up(label_node: Label, from_value: float, to_value: float, format: String = "%d",
		seconds: float = COUNT_SECONDS, delay: float = 0.0) -> Tween:
	var tween: Tween = label_node.create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_method(_write_count.bind(label_node, format), from_value, to_value, seconds)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tween


static func _write_count(value: float, label_node: Label, format: String) -> void:
	label_node.text = format % roundi(value)
