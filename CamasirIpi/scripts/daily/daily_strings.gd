class_name DailyStrings
extends RefCounted

## Günlük bulmaca ve takvimin tüm kullanıcıya görünen metinleri (Türkçe), tek yerde.
## Kasıtlı az metin: anlatımı ikonlar ve sayılar yapar.

const PUZZLE_TITLE: String = "Günün bulmacası"
const PUZZLE_READY: String = "Bugün seni bekliyor"
const PUZZLE_DONE: String = "Bugünkü bulmaca çözüldü"
const PUZZLE_LOCKED: String = "Seviye %d'de açılır"
const PUZZLE_TOMORROW: String = "Yarın yenisi gelecek"
const PLAY: String = "Oyna"
const STREAK_FORMAT: String = "%d"
const BEST_FORMAT: String = "En iyi %d"
const REWARD_FORMAT: String = "+%d"
const BOOSTER_FORMAT: String = "+%d"

const WIN_TITLE: String = "Bulmaca çözüldü"
const WIN_AGAIN: String = "Bugünün ödülünü zaten aldın"
const CONTINUE: String = "Devam"
const LOSE_TITLE: String = "Fırtına çıktı"
const LOSE_RETRY: String = "Tekrar dene"

const CALENDAR_TITLE: String = "Günlük hediye"
const CALENDAR_DAY_FORMAT: String = "%d"
const CLAIM: String = "Al"
const CLAIMED_TODAY: String = "Yarın yine gel"
const CLOSE: String = "Kapat"

## Güçlendirici kimliği -> ikon (kimlik tanınmazsa paket ikonu).
const BOOSTER_ICONS: Dictionary = {
	"undo": "lucide/rotate-ccw",
	"pin_remover": "lucide/zap",
	"extra_slot": "lucide/plus",
}
const DEFAULT_BOOSTER_ICON: String = "lucide/package"
