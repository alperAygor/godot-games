class_name UiKit
extends RefCounted

## v0.2 tasarım kiti: data/theme.json palet/metriklerinin kod aynası + dinamik
## düğüm üretimi için küçük yardımcılar. StyleBox'ların çoğu temadan (tür
## varyasyonları) gelir; buradakiler yalnızca çalışma anında doğan düğümler için.
## GOTCHAS #19: Label tür varyasyonu punto/renk zincirlemiyor → etiketler
## sahnede theme_override_* ile ayarlanır; fontlar burada sabittir.

const FONT_BODY: Font = preload("res://assets/fonts/body_font.tres")
const FONT_TITLE: Font = preload("res://assets/fonts/title_font.tres")

## data/theme.json paleti (tek kaynak: tema dosyası; bu kopya yalnızca renk
## karşılaştırmaları ve dinamik etiketler içindir). 8 px grid.
const COLOR_BG: Color = Color(0.0784, 0.0667, 0.0627, 1.0)
const COLOR_SURFACE: Color = Color(0.1294, 0.1137, 0.1020, 1.0)
const COLOR_SURFACE_HIGH: Color = Color(0.1686, 0.1490, 0.1333, 1.0)
const COLOR_PRIMARY: Color = Color(0.4980, 0.9098, 0.7961, 1.0)
const COLOR_PRIMARY_DARK: Color = Color(0.2431, 0.6196, 0.5333, 1.0)
const COLOR_ACCENT: Color = Color(0.9529, 0.7882, 0.4784, 1.0)
const COLOR_ACCENT_DARK: Color = Color(0.6549, 0.4980, 0.2275, 1.0)
const COLOR_DANGER: Color = Color(0.9373, 0.5608, 0.4941, 1.0)
const COLOR_DANGER_DARK: Color = Color(0.6588, 0.3412, 0.2902, 1.0)
const COLOR_SHIELD: Color = Color(0.5608, 0.8275, 0.9412, 1.0)
const COLOR_TEXT: Color = Color(0.9490, 0.9216, 0.8902, 1.0)
const COLOR_MUTED: Color = Color(0.6275, 0.5843, 0.5412, 1.0)
const COLOR_ON_PRIMARY: Color = Color(0.0392, 0.1647, 0.1373, 1.0)
const COLOR_ON_ACCENT: Color = Color(0.1647, 0.1176, 0.0314, 1.0)
const COLOR_OUTLINE: Color = Color(0.2275, 0.2000, 0.1765, 1.0)

const MARGIN: float = 48.0
const GAP: float = 16.0
const BUTTON_HEIGHT: float = 96.0
const FADE_SECONDS: float = 0.35


static func body_font() -> Font:
	return FONT_BODY


static func title_font() -> Font:
	return FONT_TITLE


## Dinamik etiket (seviye kartları, rozetler): tema varsayılanı yerine açık
## font/punto/renk verir — varyasyon zinciri güvenilmez (GOTCHAS #19).
static func make_label(text: String, size: int, color: Color, title: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", FONT_TITLE if title else FONT_BODY)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


## Tek satırlık, taşmayan etiket (autowrap kapalı + kırpma).
static func compact_label(text: String, size: int, color: Color) -> Label:
	var label: Label = make_label(text, size, color)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.clip_text = true
	return label


static func make_star(size: int, lit: bool) -> TextureRect:
	var star: TextureRect = TextureRect.new()
	star.texture = Icons.texture("lucide/star")
	star.custom_minimum_size = Vector2(float(size), float(size))
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.modulate = COLOR_ACCENT if lit else Color(COLOR_OUTLINE.r, COLOR_OUTLINE.g,
		COLOR_OUTLINE.b, 1.0)
	return star


## Yumuşak giriş: alpha 0 → 1, opsiyonel küçük yukarı kayma. ASMR easing.
static func fade_in(item: CanvasItem, delay: float = 0.0, duration: float = FADE_SECONDS) -> Tween:
	item.modulate.a = 0.0
	var tween: Tween = item.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(delay)
	tween.tween_property(item, "modulate:a", 1.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return tween


## LevelSelect kartı: okunur koyu yüzey + ince çerçeve. Kilitli kart da
## okunur kalır (disabled stilini ezmek için tüm durumlar açıkça verilir).
static func apply_card_styles(button: Button, available: bool) -> void:
	var bg: Color = Color(COLOR_SURFACE.r, COLOR_SURFACE.g, COLOR_SURFACE.b,
		0.62 if available else 0.52)
	var border: Color = Color(COLOR_OUTLINE.r, COLOR_OUTLINE.g, COLOR_OUTLINE.b,
		0.65 if available else 0.62)
	button.add_theme_stylebox_override("normal", _card_style(bg, border, 24))
	button.add_theme_stylebox_override("hover",
		_card_style(Color(bg.r + 0.03, bg.g + 0.03, bg.b + 0.03, bg.a), border, 24))
	button.add_theme_stylebox_override("pressed",
		_card_style(Color(bg.r - 0.02, bg.g - 0.02, bg.b - 0.02, bg.a), border, 24))
	button.add_theme_stylebox_override("disabled", _card_style(bg, border, 24))
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_disabled_color", COLOR_MUTED)


static func _card_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 16.0
	style.content_margin_bottom = 16.0
	return style


## Tek dokunuş: tüm ana eylemlerde aynı yumuşak UI sesi (AudioService).
static func tap() -> void:
	AudioService.play("ui_tap")
