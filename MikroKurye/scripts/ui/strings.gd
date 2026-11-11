class_name UiStrings
extends RefCounted

## Arayüz metinleri tek yerde: çok dil sonra `tr()`/veri anahtarına taşınacak.
## Sözleşme: ARCHITECTURE.md §5.4. Sahneler sabit dizge taşımaz; buradan okur.

const MENU_PLAY: String = "Oyna"
const MENU_GARAGE: String = "Garaj"
const MENU_HINT: String = "Siparişini seç, kuryeni geliştir."
const BACK: String = "Geri"
const ORDER_TITLE: String = "Sipariş Seç"
const ORDER_HINT: String = "Taşımak istediğin kargoyu seç."
const GARAGE_TITLE: String = "Garaj"
const GARAGE_HINT: String = "Altın ve hurdayla kuryeni güçlendir."
const DIFFICULTY: String = "Zorluk"
const REWARD: String = "Ödül"
const GOLD: String = "Altın"
const SCRAP: String = "Hurda"
const LEVEL: String = "Seviye"
const MAX_LEVEL: String = "MAKS"
const GOLD_SUFFIX: String = "Altın"
const SCRAP_SUFFIX: String = "Hurda"
const WALLET: String = "Cüzdan"


## `data/cargo.json` içindeki `name_key` -> görünen ad. Bilinmeyen anahtar
## olduğu gibi gösterilir; yeni kargo verisi kod değişikliği gerektirmez.
static func cargo_name(name_key: String) -> String:
	match name_key:
		"cargo.battery":
			return "Pil"
		"cargo.sd_card":
			return "SD Kart"
		"cargo.espresso":
			return "Espresso Kapsülü"
		_:
			return name_key


static func cargo_card(name: String, difficulty: int, reward_gold: int) -> String:
	return "%s\n%s %d · %s %d %s" % [
		name, DIFFICULTY, difficulty, REWARD, reward_gold, GOLD_SUFFIX]


static func category_name(category: String) -> String:
	match category:
		"chassis":
			return "Şasi"
		"wheels":
			return "Tekerlek"
		"battery":
			return "Batarya"
		_:
			return category


static func gold_label(amount: int) -> String:
	return "%s: %d" % [GOLD, amount]


static func scrap_label(amount: int) -> String:
	return "%s: %d" % [SCRAP, amount]


static func wallet_label(gold: int, scrap: int) -> String:
	return "%s: %d %s · %d %s" % [WALLET, gold, GOLD_SUFFIX, scrap, SCRAP_SUFFIX]


## Seviye/maliyet metni; `cost` boşsa kategori maksimumdadır.
static func upgrade_button(category: String, level: int, max_level: int,
		cost: Dictionary) -> String:
	var name: String = category_name(category)
	if cost.is_empty():
		return "%s\n%s %d/%d · %s" % [name, LEVEL, level, max_level, MAX_LEVEL]
	var gold: int = int(cost.get("gold", 0))
	var scrap: int = int(cost.get("scrap", 0))
	return "%s\n%s %d/%d · %d %s / %d %s" % [
		name, LEVEL, level, max_level, gold, GOLD_SUFFIX, scrap, SCRAP_SUFFIX]
