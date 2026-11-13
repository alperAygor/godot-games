class_name MetaStrings
extends RefCounted

## Meta katmanının (çamaşırhane + koleksiyon) metinleri: `strings.csv` anahtarlarına sarmalayıcılar.
## NEDEN ayrı dosya: meta ekranları başka işçiyle paralel geliştirildi; ortak `UiStrings`'e
## dokunmadan dil/metin cilası tek yerden yapılabilsin.

# Çamaşırhane: kimlik -> CSV anahtarı
const LOCATION_KEYS: Dictionary[String, String] = {
	"corner": "META_LOC_CORNER",
	"seaside": "META_LOC_SEASIDE",
	"attic": "META_LOC_ATTIC",
	"hotel": "META_LOC_HOTEL",
}
const TASK_KEYS: Dictionary[String, String] = {
	"floor": "META_TASK_FLOOR",
	"wall": "META_TASK_WALL",
	"machine1": "META_TASK_MACHINE1",
	"shelf": "META_TASK_SHELF",
	"sign": "META_TASK_SIGN",
	"plant": "META_TASK_PLANT",
	"lamp": "META_TASK_LAMP",
	"window": "META_TASK_WINDOW",
	"counter": "META_TASK_COUNTER",
	"machine2": "META_TASK_MACHINE2",
	"rug": "META_TASK_RUG",
	"door": "META_TASK_DOOR",
}
const SET_KEYS: Dictionary[String, String] = {
	"turkiye": "META_SET_TURKIYE",
	"japonya": "META_SET_JAPONYA",
	"meksika": "META_SET_MEKSIKA",
	"iskocya": "META_SET_ISKOCYA",
	"hindistan": "META_SET_HINDISTAN",
	"hollanda": "META_SET_HOLLANDA",
}
const PROGRESS_FORMAT: String = "%d/%d"
const COST_FORMAT: String = "%d"
const BONUS_FORMAT: String = "+%d"
const SET_PROGRESS_FORMAT: String = "%d/%d"


static func location_name(id: String) -> String:
	return Loc.t(LOCATION_KEYS[id]) if LOCATION_KEYS.has(id) else id


static func task_name(id: String) -> String:
	return Loc.t(TASK_KEYS[id]) if TASK_KEYS.has(id) else id


static func country_name(id: String) -> String:
	return Loc.t(SET_KEYS[id]) if SET_KEYS.has(id) else id


static func need_stars() -> String:
	return Loc.t("META_NEED_STARS")


static func pick_look() -> String:
	return Loc.t("META_PICK_LOOK")


static func location_done() -> String:
	return Loc.t("META_LOCATION_DONE")


static func soon() -> String:
	return Loc.t("META_SOON")


static func collection_title() -> String:
	return Loc.t("META_COLLECTION_TITLE")


static func next_piece(remaining: int) -> String:
	return Loc.n("META_NEXT_PIECE_ONE", "META_NEXT_PIECE_OTHER", remaining) % remaining


static func all_pieces() -> String:
	return Loc.t("META_ALL_PIECES")
