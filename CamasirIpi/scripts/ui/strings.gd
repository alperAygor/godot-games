class_name UiStrings
extends RefCounted

## Arayüzün kullanıcıya görünen metinleri: `data/i18n/strings.csv` anahtarlarına ince sarmalayıcılar.
## NEDEN işlev (sabit değil): metin dil değişince yeniden çözülmeli; sabit yükleme anında donardı.
## Dile bağlı olmayan biçimler (sayı + işaret) sabit kalır.

const WIN_DOUBLE: String = "2×"
const REWARD_FORMAT: String = "+%d"


static func game_title() -> String:
	return Loc.t("GAME_TITLE")


static func level(number: int) -> String:
	return Loc.f("LEVEL", [number])


static func soon_title() -> String:
	return Loc.t("SOON_TITLE")


static func soon_body() -> String:
	return Loc.t("SOON_BODY")


static func ok() -> String:
	return Loc.t("OK")


static func settings_title() -> String:
	return Loc.t("SETTINGS_TITLE")


static func sound() -> String:
	return Loc.t("SETTINGS_SOUND")


static func music() -> String:
	return Loc.t("SETTINGS_MUSIC")


static func vibration() -> String:
	return Loc.t("SETTINGS_VIBRATION")


static func language_caption() -> String:
	return Loc.t("SETTINGS_LANGUAGE")


static func paused() -> String:
	return Loc.t("PAUSED")


static func resume() -> String:
	return Loc.t("RESUME")


static func win_title() -> String:
	return Loc.t("WIN_TITLE")


static func win_continue() -> String:
	return Loc.t("WIN_CONTINUE")


static func perfect_title() -> String:
	return Loc.t("WIN_PERFECT")


static func coins_added(amount: int) -> String:
	return Loc.n("WIN_COINS_ADDED_ONE", "WIN_COINS_ADDED_OTHER", amount) % amount


static func lose_title() -> String:
	return Loc.t("LOSE_TITLE")


static func lose_title_moves() -> String:
	return Loc.t("LOSE_TITLE_MOVES")


static func lose_revive() -> String:
	return Loc.t("LOSE_REVIVE")


## Hamle bitince devam: +1 askı ile birlikte ek hamle de verilir; düğme bunu söyler.
static func lose_revive_moves() -> String:
	return Loc.t("LOSE_REVIVE_MOVES")


static func lose_coins(cost: int) -> String:
	return Loc.n("LOSE_COINS_ONE", "LOSE_COINS_OTHER", cost) % cost


static func lose_retry() -> String:
	return Loc.t("LOSE_RETRY")


static func daily_title() -> String:
	return Loc.t("DAILY_TITLE")


## "Kalan çamaşır" cümlesi; `number_markup` sayının (biçimli) metnidir. `few` ise "Sadece ..." vurgusu.
static func remaining_sentence(number_markup: String, remaining: int, few: bool) -> String:
	if few:
		return Loc.n("LOSE_LEFT_FEW_ONE", "LOSE_LEFT_FEW_OTHER", remaining) % number_markup
	return Loc.n("LOSE_LEFT_ONE", "LOSE_LEFT_OTHER", remaining) % number_markup
