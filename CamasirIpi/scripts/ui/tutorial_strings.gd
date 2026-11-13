class_name TutorialStrings
extends RefCounted

## Öğretici metinlerinin TEK yeri: özellik kimliği -> CSV anahtarları (tr/en/es `strings.csv`).
## Neden anahtar sözlüğü: metin düzeltmek kod/veri dosyasına dokunmayı gerektirmesin.

const CARDS: Dictionary = {
	"wet": {"title": "TUT_WET_TITLE", "line": "TUT_WET_LINE"},
	"mystery": {"title": "TUT_MYSTERY_TITLE", "line": "TUT_MYSTERY_LINE"},
	"lock": {"title": "TUT_LOCK_TITLE", "line": "TUT_LOCK_LINE"},
	"sheet": {"title": "TUT_SHEET_TITLE", "line": "TUT_SHEET_LINE"},
	"sock_pair": {"title": "TUT_SOCK_PAIR_TITLE", "line": "TUT_SOCK_PAIR_LINE"},
	"dye": {"title": "TUT_DYE_TITLE", "line": "TUT_DYE_LINE"},
	"joker": {"title": "TUT_JOKER_TITLE", "line": "TUT_JOKER_LINE"},
	"big_basket": {"title": "TUT_BIG_BASKET_TITLE", "line": "TUT_BIG_BASKET_LINE"},
	"stain": {"title": "TUT_STAIN_TITLE", "line": "TUT_STAIN_LINE"},
	"chain": {"title": "TUT_CHAIN_TITLE", "line": "TUT_CHAIN_LINE"},
	"wind": {"title": "TUT_WIND_TITLE", "line": "TUT_WIND_LINE"},
	"slide": {"title": "TUT_SLIDE_TITLE", "line": "TUT_SLIDE_LINE"},
	"mode_moves": {"title": "TUT_MODE_MOVES_TITLE", "line": "TUT_MODE_MOVES_LINE"},
	"mode_short_rack": {"title": "TUT_MODE_SHORT_RACK_TITLE", "line": "TUT_MODE_SHORT_RACK_LINE"},
	"mode_orders": {"title": "TUT_MODE_ORDERS_TITLE", "line": "TUT_MODE_ORDERS_LINE"},
	"mode_boss": {"title": "TUT_MODE_BOSS_TITLE", "line": "TUT_MODE_BOSS_LINE"},
	"undo": {"title": "TUT_UNDO_TITLE", "line": "TUT_UNDO_LINE"},
	"pin_remover": {"title": "TUT_PIN_REMOVER_TITLE", "line": "TUT_PIN_REMOVER_LINE"},
	"extra_slot": {"title": "TUT_EXTRA_SLOT_TITLE", "line": "TUT_EXTRA_SLOT_LINE"},
}


static func ok_button() -> String:
	return Loc.t("OK")


static func card_title(feature: String) -> String:
	var key: String = String((CARDS.get(feature, {}) as Dictionary).get("title", ""))
	return Loc.t(key) if not key.is_empty() else feature


static func card_line(feature: String) -> String:
	var key: String = String((CARDS.get(feature, {}) as Dictionary).get("line", ""))
	return Loc.t(key) if not key.is_empty() else ""
