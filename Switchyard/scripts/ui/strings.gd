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


static func paused() -> String:
	return Loc.t("PAUSED")


static func resume() -> String:
	return Loc.t("RESUME")


static func win_title() -> String:
	return Loc.t("WIN_TITLE")


static func win_continue() -> String:
	return Loc.t("WIN_CONTINUE")


static func lose_title() -> String:
	return Loc.t("LOSE_TITLE")


static func lose_revive() -> String:
	return Loc.t("LOSE_REVIVE")


static func lose_retry() -> String:
	return Loc.t("LOSE_RETRY")


# --- Yer tutucu oyun (gerçek oyunda silinir) ---

static func placeholder_tap() -> String:
	return Loc.t("PH_TAP")


static func placeholder_lose() -> String:
	return Loc.t("PH_LOSE")


static func placeholder_left(count: int) -> String:
	return Loc.n("PH_LEFT_ONE", "PH_LEFT_OTHER", count) % count
