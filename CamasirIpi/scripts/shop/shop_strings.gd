class_name ShopStrings
extends RefCounted

## Mağaza metinleri: `data/i18n/strings.csv` anahtarlarına ince sarmalayıcılar (dil değişince yeniden çözülür).
## Ürün adları (güçlendirici) için mevcut öğretici başlıkları kullanılır: aynı sözcük her yerde aynı.

const PACK_FORMAT: String = "×%d"
const DISCOUNT_FORMAT: String = "-%d%%"
const FREE_PLUS_FORMAT: String = "+1"
const BOOSTER_NAME_KEYS: Dictionary = {
	"undo": "TUT_UNDO_TITLE",
	"pin_remover": "TUT_PIN_REMOVER_TITLE",
	"extra_slot": "TUT_EXTRA_SLOT_TITLE",
}


static func title() -> String:
	return Loc.t("SHOP_TITLE")


static func boosters() -> String:
	return Loc.t("SHOP_BOOSTERS")


static func skins() -> String:
	return Loc.t("SHOP_SKINS")


static func pins() -> String:
	return Loc.t("SHOP_PINS")


static func ropes() -> String:
	return Loc.t("SHOP_ROPES")


static func remove_ads() -> String:
	return Loc.t("SHOP_REMOVE_ADS")


static func remove_ads_note() -> String:
	return Loc.t("SHOP_REMOVE_ADS_NOTE")


static func owned() -> String:
	return Loc.t("SHOP_OWNED")


static func restore() -> String:
	return Loc.t("SHOP_RESTORE")


static func restored() -> String:
	return Loc.t("SHOP_RESTORED")


static func nothing_to_restore() -> String:
	return Loc.t("SHOP_NOTHING_TO_RESTORE")


static func store_unavailable() -> String:
	return Loc.t("SHOP_STORE_UNAVAILABLE")


static func purchase_failed() -> String:
	return Loc.t("SHOP_PURCHASE_FAILED")


static func free_one() -> String:
	return Loc.t("SHOP_FREE_ONE")


static func no_price() -> String:
	return Loc.t("SHOP_NO_PRICE")


static func ad_unavailable() -> String:
	return Loc.t("SHOP_AD_UNAVAILABLE")


static func booster_name(id: String) -> String:
	return Loc.t(String(BOOSTER_NAME_KEYS.get(id, "")))
