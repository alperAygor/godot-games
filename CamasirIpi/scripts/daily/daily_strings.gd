class_name DailyStrings
extends RefCounted

## Günlük bulmaca ve takvimin metinleri: `strings.csv` anahtarlarına ince sarmalayıcılar.
## Kasıtlı az metin: anlatımı ikonlar ve sayılar yapar.

const STREAK_FORMAT: String = "%d"
const REWARD_FORMAT: String = "+%d"
const BOOSTER_FORMAT: String = "+%d"
const CALENDAR_DAY_FORMAT: String = "%d"

## Güçlendirici kimliği -> ikon (kimlik tanınmazsa paket ikonu).
const BOOSTER_ICONS: Dictionary = {
	"undo": "lucide/rotate-ccw",
	"pin_remover": "lucide/zap",
	"extra_slot": "lucide/plus",
}
const DEFAULT_BOOSTER_ICON: String = "lucide/package"


static func puzzle_title() -> String:
	return Loc.t("DAILY_PUZZLE_TITLE")


static func puzzle_ready() -> String:
	return Loc.t("DAILY_PUZZLE_READY")


static func puzzle_locked(level: int) -> String:
	return Loc.f("DAILY_PUZZLE_LOCKED", [level])


static func puzzle_tomorrow() -> String:
	return Loc.t("DAILY_PUZZLE_TOMORROW")


static func play() -> String:
	return Loc.t("DAILY_PLAY")


static func win_title() -> String:
	return Loc.t("DAILY_WIN_TITLE")


static func win_again() -> String:
	return Loc.t("DAILY_WIN_AGAIN")


static func continue_text() -> String:
	return Loc.t("WIN_CONTINUE")


static func lose_title() -> String:
	return Loc.t("LOSE_TITLE")


static func lose_retry() -> String:
	return Loc.t("LOSE_RETRY")


static func calendar_title() -> String:
	return Loc.t("DAILY_CALENDAR_TITLE")


static func claim() -> String:
	return Loc.t("DAILY_CLAIM")


static func claimed_today() -> String:
	return Loc.t("DAILY_CLAIMED_TODAY")


static func close() -> String:
	return Loc.t("DAILY_CLOSE")
