class_name Accessibility
extends RefCounted
## Erişilebilirlik kuralları (saf, testli): yazı boyutu kademeleri, renk körü paleti ve renkten bağımsız işaretler.
## Ayarlar `SettingsManager` "access" bölümünde durur (text_size / color_blind / reduced_motion); uygulama `A11y` (arayüz) ve
## `ThemeVariants` (tema türetme) içindedir. Oyun içinde renkle anlatılan her şeyin yanında bir metin ya da `mark()` işareti bulunur.

const TEXT_NORMAL := "normal"
const TEXT_LARGE := "large"
const TEXT_SIZES: Array[String] = [TEXT_NORMAL, TEXT_LARGE]
## Tema yazı boyutlarının çarpanı (build_theme.py FONT_SCALE zaten uygulanmış temaya göre).
const TEXT_SCALES := {TEXT_NORMAL: 1.0, TEXT_LARGE: 1.2}

## Karar/kader türleri → renkten bağımsız işaret (VT323'te ▲ ✓ gibi imler yok; yalnız ASCII).
const KIND_GOOD := "good"
const KIND_WARN := "warn"
const KIND_BAD := "bad"
const MARKS := {KIND_GOOD: "[+]", KIND_WARN: "[!]", KIND_BAD: "[x]"}


static func sanitize_text_size(value: Variant) -> String:
	var text := str(value)
	return text if TEXT_SIZES.has(text) else TEXT_NORMAL


static func text_scale(text_size: Variant) -> float:
	return float(TEXT_SCALES[sanitize_text_size(text_size)])


## Ölçeklenmiş yazı boyutu (en az 1).
static func scaled_size(base: int, text_size: Variant) -> int:
	return maxi(1, roundi(base * text_scale(text_size)))


## Renk körü kipinde işaret önekiyle: "[+] Kabul". Kip kapalıysa metin değişmez.
static func marked(kind: String, text: String, color_blind: bool) -> String:
	if not color_blind or not MARKS.has(kind):
		return text
	return "%s %s" % [MARKS[kind], text]


## Renk körü dostu renk: yeşil → mavi, kırmızı → koyu portakal (vermilyon), altın → parlak kehribar. Gri/krem (doygunluğu düşük)
## renkler değişmez; alfa korunur. Kip kapalıysa renk aynen döner. Kırmızı-yeşil karışıklığını kaldırır; parlaklık farkı da ayırır.
static func adapt(color: Color, color_blind: bool) -> Color:
	if not color_blind:
		return color
	if color.s < 0.28 or color.v < 0.25:  # kâğıt/krem/mürekkep gibi soluk ya da koyu renkler anlam taşımaz: değişmez
		return color
	var hue := color.h
	var sat := color.s
	var value := color.v
	if hue >= 0.17 and hue <= 0.50:  # yeşil/sarı-yeşil/turkuaz → mavi
		hue = 0.585
		sat = maxf(sat, 0.55)
	elif hue >= 0.93 or hue <= 0.04:  # kırmızı → koyu vermilyon
		hue = 0.045
		value *= 0.88
	elif hue > 0.04 and hue < 0.17:  # turuncu/altın/sarı → parlak kehribar (kırmızıdan hem tonla hem parlaklıkla ayrılır)
		hue = 0.125
		value = minf(1.0, value * 1.12)
		sat = minf(1.0, sat * 1.05)
	return Color.from_hsv(hue, sat, value, color.a)


## Bir renk için 1..6 arası "ton numarası" (renk tonuna göre): banknot/UV şerit rengi gibi YALNIZ renkle ayırt edilen şeylerin yanına
## o kadar çentik çizilebilsin diye (renk körü kipi, T-D1 sözleşmesi). Aynı renk hep aynı numarayı verir; gri renkler 0 (çentiksiz).
static func tone_marks(color: Color) -> int:
	if color.s < 0.12:
		return 0
	return 1 + clampi(int(floorf(color.h * 6.0)), 0, 5)
