class_name LocFonts
extends RefCounted

## Dile göre yazı tipi zinciri. Latin metin (tr/en/es/pt/de) paketteki Baloo 2 alt kümesiyle çizilir;
## Japonca ve Korece Baloo'da yoktur: cihazın kendi CJK yazı tipine (SystemFont) düşer.
## NEDEN sistem yazı tipi: paket boyutu +0 (Noto Sans CJK ~16 MB/ağırlık olurdu). Bedeli: görünüm cihaza göre
## değişir (Android'de Noto Sans CJK, iOS'ta Hiragino/Apple SD Gothic Neo). Paketli CJK alt kümesi sonraya
## bırakıldı (sahibin indirme onayı gerekir).
## Han birleştirmesi: aynı kanji Japonca/Çince/Korece farklı çizilir. Godot'nun yapabildiği: (1) `font_names`
## sırasında o dilin bölgesel ailesini öne koymak, (2) metin dilini (`TranslationServer` yerel ayarı = ja/ko)
## HarfBuzz'a ve sistem yazı tipi seçimine vermek. Yapamadığı: tek bir .ttc içinden belirli yüzü (JP/KR)
## kendisi seçmek; Android'de ortak Noto Sans CJK .ttc'sinde yüz seçimi cihazın fonts.xml'ine bağlıdır.

const BASE_FONT_PATH: String = "res://assets/fonts/Baloo2.ttf"
const LANG_JA: String = "ja"
const LANG_KO: String = "ko"
## Öncelik sırası: Android (Noto), macOS/iOS (Hiragino / Apple SD Gothic Neo), Windows (Yu Gothic / Malgun), genel.
const NAMES_JA: PackedStringArray = ["Noto Sans CJK JP", "Noto Sans JP", "Hiragino Sans", "Hiragino Kaku Gothic ProN",
	"Yu Gothic UI", "Yu Gothic", "Meiryo", "sans-serif"]
const NAMES_KO: PackedStringArray = ["Noto Sans CJK KR", "Noto Sans KR", "Apple SD Gothic Neo", "Malgun Gothic",
	"NanumGothic", "sans-serif"]
## Baloo normal ağırlığıyla yan yana ince durmasın diye bir kademe kalın (Medium); yüklü değilse Regular'a düşer.
const CJK_WEIGHT: int = 500
## CJK glifleri Baloo'ya göre ölçeklenir (tek ayar noktası). 1.0 = olduğu gibi.
const CJK_GLYPH_SCALE: float = 1.0
## Baloo'nun satır yüksekliği zaten geniştir; CJK için ek üst/alt boşluk gerekmez (px).
const CJK_SPACING_TOP: int = 0
const CJK_SPACING_BOTTOM: int = 0

static var _system_fonts: Dictionary[String, Font] = {}


## Paketli Latin yazı tipi (tema varsayılanıyla aynı örnek).
static func base_font() -> Font:
	return load(BASE_FONT_PATH) as Font


## Dilin CJK yazı tipi; Latin diller için null.
static func cjk_font(code: String) -> Font:
	if code != LANG_JA and code != LANG_KO:
		return null
	if _system_fonts.has(code):
		return _system_fonts[code]
	var system: SystemFont = SystemFont.new()
	system.font_names = NAMES_JA if code == LANG_JA else NAMES_KO
	system.font_weight = CJK_WEIGHT
	system.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	system.allow_system_fallback = true
	var wrapped: FontVariation = FontVariation.new()
	wrapped.base_font = system
	wrapped.variation_transform = Transform2D(Vector2(CJK_GLYPH_SCALE, 0.0), Vector2(0.0, CJK_GLYPH_SCALE), Vector2.ZERO)
	wrapped.spacing_top = CJK_SPACING_TOP
	wrapped.spacing_bottom = CJK_SPACING_BOTTOM
	_system_fonts[code] = wrapped
	return wrapped


## Etkin dile göre paketli yazı tipinin yedek zincirini kurar. Tema ve `UiKit.numeric_font` aynı Baloo örneğini
## paylaştığı için tek yerde kurmak bütün ekranlara yeter.
static func apply(code: String) -> void:
	var base: Font = base_font()
	if base == null:
		return
	var chain: Array[Font] = []
	var cjk: Font = cjk_font(code)
	if cjk != null:
		chain.append(cjk)
		# Karışık metin (ör. Korece ekranda Japonca ad) yine de çizilsin: öbür CJK ailesi sona eklenir.
		chain.append(cjk_font(LANG_KO if code == LANG_JA else LANG_JA))
	base.fallbacks = chain


## Dil seçicideki yerel ad için yazı tipi: HER dilde sistem CJK zincirini kullanır (ad Latin değilse).
static func selector_font(code: String) -> Font:
	var cjk: Font = cjk_font(code)
	return cjk if cjk != null else base_font()
