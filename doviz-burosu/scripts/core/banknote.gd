class_name Banknote
extends RefCounted
## Tek bir banknotun tüm gözlemlenebilir özellikleri. Sahte = gerçek özellikten farklı parametre.
## `fakes` üreticinin koyduğu sahtecilik etiketleridir; `discrepancies()` ise özelliklere bakıp
## gerçek banknotla farkı yeniden bulur (kural motoru ve testler bunu kullanır).

const FAKE_COLOR := "wrong_color"
const FAKE_SIZE := "wrong_size"
const FAKE_PORTRAIT := "wrong_portrait"
const FAKE_UV_MISSING := "uv_missing"
const FAKE_UV_COLOR := "uv_wrong_color"
const FAKE_WM_MISSING := "watermark_missing"
const FAKE_WM_SHAPE := "watermark_wrong_shape"
const FAKE_MICROTEXT := "microtext_error"

const FAKE_TYPES: Array[String] = [
	FAKE_COLOR, FAKE_SIZE, FAKE_PORTRAIT, FAKE_UV_MISSING, FAKE_UV_COLOR,
	FAKE_WM_MISSING, FAKE_WM_SHAPE, FAKE_MICROTEXT,
]

var currency := ""
var denom := 0
var series_id := ""
var serial := ""

var color := ""
var size_mm := Vector2i.ZERO
var pattern := ""
var portrait := ""
var uv_present := true
var uv_color := ""
var uv_position := ""
var watermark_present := true
var watermark_shape := ""
var microtext := ""

## Üreticinin eklediği sahtecilik etiketleri (FAKE_TYPES'tan).
var fakes: Array[String] = []
## Bantla onarılmış ama tam banknot: geçerlidir.
var taped := false
## Banknottan kalan yüzde; yarıdan azı kalan iade edilir (Banknote.is_unfit).
var remaining_percent := 100


func is_genuine() -> bool:
	return fakes.is_empty()


func value_minor() -> int:
	return Money.units(denom)


## Kalan parça `min_remaining_percent`in altındaysa kullanılamaz (iade).
func is_unfit(min_remaining_percent: int) -> bool:
	return remaining_percent < min_remaining_percent


## Özelliklere bakarak gerçek banknottan farkları bulur (FAKE_TYPES sırasıyla).
func discrepancies(book: CurrencyBook) -> Array[String]:
	var expected := book.spec(currency, denom)
	var found: Array[String] = []
	if color != expected["color"]:
		found.append(FAKE_COLOR)
	if size_mm != expected["size_mm"]:
		found.append(FAKE_SIZE)
	if portrait != expected["portrait"]:
		found.append(FAKE_PORTRAIT)
	if not uv_present:
		found.append(FAKE_UV_MISSING)
	elif uv_color != expected["uv_color"]:
		found.append(FAKE_UV_COLOR)
	if not watermark_present:
		found.append(FAKE_WM_MISSING)
	elif watermark_shape != expected["watermark_shape"]:
		found.append(FAKE_WM_SHAPE)
	if microtext != expected["microtext"]:
		found.append(FAKE_MICROTEXT)
	# FAKE_TYPES sırasına göre sırala (UV/filigran sırası sabit kalsın).
	found.sort_custom(func(a: String, b: String) -> bool: return FAKE_TYPES.find(a) < FAKE_TYPES.find(b))
	return found


func to_dict() -> Dictionary:
	return {
		"currency": currency, "denom": denom, "series_id": series_id, "serial": serial,
		"color": color, "size_mm": [size_mm.x, size_mm.y], "pattern": pattern, "portrait": portrait,
		"uv_present": uv_present, "uv_color": uv_color, "uv_position": uv_position,
		"watermark_present": watermark_present, "watermark_shape": watermark_shape,
		"microtext": microtext, "fakes": fakes.duplicate(), "taped": taped,
		"remaining_percent": remaining_percent,
	}


static func from_dict(data: Dictionary) -> Banknote:
	var note := Banknote.new()
	note.currency = str(data.get("currency", ""))
	note.denom = int(data.get("denom", 0))
	note.series_id = str(data.get("series_id", ""))
	note.serial = str(data.get("serial", ""))
	note.color = str(data.get("color", ""))
	var size: Array = data.get("size_mm", [0, 0])
	note.size_mm = Vector2i(int(size[0]), int(size[1]))
	note.pattern = str(data.get("pattern", ""))
	note.portrait = str(data.get("portrait", ""))
	note.uv_present = bool(data.get("uv_present", true))
	note.uv_color = str(data.get("uv_color", ""))
	note.uv_position = str(data.get("uv_position", ""))
	note.watermark_present = bool(data.get("watermark_present", true))
	note.watermark_shape = str(data.get("watermark_shape", ""))
	note.microtext = str(data.get("microtext", ""))
	for fake: Variant in data.get("fakes", []):
		note.fakes.append(str(fake))
	note.taped = bool(data.get("taped", false))
	note.remaining_percent = int(data.get("remaining_percent", 100))
	return note
