class_name DailyStore
extends RefCounted

## Günlük bulmaca + takvim kaydı: TÜM durum `Progress` modül bölümü "daily" altındadır.
## Neden ayrı sınıf: mantık dosyaları (DailyPuzzle, DailyCalendarLogic) saf ve testli kalır;
## bu sınıf yalnız onları Progress'e (jeton, güçlendirici, kayıt) bağlar.

const SECTION: String = "daily"
const KEY_LAST_WON: String = "last_won"
const KEY_STREAK: String = "streak"
const KEY_BEST: String = "best"
const KEY_LAST_CLAIM: String = "last_claim"
const KEY_CLAIM_DAY: String = "day"


static func puzzle_state() -> Dictionary:
	return {
		KEY_LAST_WON: String(Progress.module_value(SECTION, KEY_LAST_WON, "")),
		KEY_STREAK: int(Progress.module_value(SECTION, KEY_STREAK, 0)),
		KEY_BEST: int(Progress.module_value(SECTION, KEY_BEST, 0)),
	}


static func calendar_state() -> Dictionary:
	return {
		KEY_LAST_CLAIM: String(Progress.module_value(SECTION, KEY_LAST_CLAIM, "")),
		KEY_CLAIM_DAY: int(Progress.module_value(SECTION, KEY_CLAIM_DAY, 0)),
	}


static func puzzle_available(today: String = "") -> bool:
	var date_key: String = today if not today.is_empty() else DailyDate.today_key()
	return DailyPuzzle.is_available(puzzle_state(), date_key, Progress.level())


static func calendar_available(today: String = "") -> bool:
	var date_key: String = today if not today.is_empty() else DailyDate.today_key()
	return DailyCalendarLogic.can_claim_today(calendar_state(), date_key)


## Bugünün bulmacası (oyuncunun seviye kovasına göre).
static func todays_level(today: String = "") -> Dictionary:
	var date_key: String = today if not today.is_empty() else DailyDate.today_key()
	return DailyPuzzle.build_level(date_key, Progress.level())


## Günlük kazanım: ilk kez ise ödül verir ve seriyi işler. Tekrar -> {first: false}.
## Dönen: {first, streak, best, coins, booster, booster_count}.
static func record_win(date_key: String) -> Dictionary:
	var state: Dictionary = puzzle_state()
	if DailyPuzzle.won_on(state, date_key):
		return {"first": false, "streak": int(state[KEY_STREAK]), "best": int(state[KEY_BEST]),
			"coins": 0, "booster": "", "booster_count": 0}
	var next_state: Dictionary = DailyPuzzle.state_after_win(state, date_key)
	var reward: Dictionary = DailyPuzzle.reward_for(int(next_state[KEY_STREAK]), Progress.level())
	# Önce durum yazılır, sonra ödül: yarıda kapanırsa iki kez ödül verilmez.
	Progress.set_module_value(SECTION, KEY_LAST_WON, next_state[KEY_LAST_WON])
	Progress.set_module_value(SECTION, KEY_STREAK, next_state[KEY_STREAK])
	Progress.set_module_value(SECTION, KEY_BEST, next_state[KEY_BEST])
	Progress.add_coins(int(reward["coins"]))
	if int(reward["booster_count"]) > 0:
		Progress.add_booster(String(reward["booster"]), int(reward["booster_count"]))
	return {"first": true, "streak": int(next_state[KEY_STREAK]), "best": int(next_state[KEY_BEST]),
		"coins": int(reward["coins"]), "booster": String(reward["booster"]),
		"booster_count": int(reward["booster_count"])}


## Takvim ödülünü alır: DailyCalendarLogic.claim sonucu + Progress'e yazım.
static func claim_calendar(today: String = "") -> Dictionary:
	var date_key: String = today if not today.is_empty() else DailyDate.today_key()
	var result: Dictionary = DailyCalendarLogic.claim(calendar_state(), date_key)
	if not bool(result["ok"]):
		return result
	var next_state: Dictionary = result["state"] as Dictionary
	Progress.set_module_value(SECTION, KEY_LAST_CLAIM, next_state[KEY_LAST_CLAIM])
	Progress.set_module_value(SECTION, KEY_CLAIM_DAY, next_state[KEY_CLAIM_DAY])
	var reward: Dictionary = result["reward"] as Dictionary
	Progress.add_coins(int(reward["coins"]))
	if int(reward["count"]) > 0 and not String(reward["booster"]).is_empty():
		Progress.add_booster(String(reward["booster"]), int(reward["count"]))
	return result
