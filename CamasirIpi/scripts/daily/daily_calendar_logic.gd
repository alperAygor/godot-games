class_name DailyCalendarLogic
extends RefCounted

## 7 günlük giriş takviminin saf mantığı. Durum: {last_claim: "YYYY-MM-DD", day: 1..7}
## (`day` = en son alınan gün; hiç alınmadıysa 0). "Bugün" parametredir.
## Kural: gün atlanırsa başa dönülür (`reset_on_miss` veri bayrağı); 7. günden sonra döngü başa sarar.

const CONFIG_PATH: String = "res://data/daily_calendar.json"
const TILE_CLAIMED: int = 0
const TILE_TODAY: int = 1
const TILE_UPCOMING: int = 2
const NONE_AVAILABLE: int = 0

static var _config_cache: Dictionary = {}


static func config() -> Dictionary:
	if _config_cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if parsed is Dictionary:
			_config_cache = parsed as Dictionary
		else:
			push_error("DailyCalendarLogic: %s okunamadı" % CONFIG_PATH)
	return _config_cache


static func day_count() -> int:
	return maxi((config().get("days", []) as Array).size(), 1)


## Gün numarasının (1..N) ödülü: {coins, booster, count}.
static func reward_for_day(day: int) -> Dictionary:
	var days: Array = config().get("days", []) as Array
	if days.is_empty():
		return {"coins": 0, "booster": "", "count": 0}
	var entry: Dictionary = days[clampi(day, 1, days.size()) - 1] as Dictionary
	return {"coins": int(entry.get("coins", 0)), "booster": String(entry.get("booster", "")),
		"count": int(entry.get("count", 0))}


## Bugün alınırsa hangi gün olur (1..N); bugün zaten alındıysa NONE_AVAILABLE.
static func claimable_day(state: Dictionary, today: String) -> int:
	var last: String = String(state.get("last_claim", ""))
	var day: int = int(state.get("day", 0))
	if last.is_empty() or day <= 0:
		return 1
	var gap: int = DailyDate.days_between(last, today)
	if gap == 0:
		return NONE_AVAILABLE
	# Saat geri alınmış / geçersiz kayıt: güvenli tarafta kalıp başa döner.
	if gap < 0:
		return 1
	if gap > 1 and bool(config().get("reset_on_miss", true)):
		return 1
	return day % day_count() + 1


static func can_claim_today(state: Dictionary, today: String) -> bool:
	return claimable_day(state, today) != NONE_AVAILABLE


## Alma: {ok, day, reward, state}. Aynı gün ikinci kez -> ok=false, durum değişmez.
static func claim(state: Dictionary, today: String) -> Dictionary:
	var day: int = claimable_day(state, today)
	if day == NONE_AVAILABLE:
		return {"ok": false, "day": int(state.get("day", 0)), "reward": {}, "state": state.duplicate()}
	return {"ok": true, "day": day, "reward": reward_for_day(day),
		"state": {"last_claim": today, "day": day}}


## 7 karo için görünüm: CLAIMED / TODAY / UPCOMING.
static func tile_states(state: Dictionary, today: String) -> Array[int]:
	var tiles: Array[int] = []
	var next_day: int = claimable_day(state, today)
	# Alınmış günler: bugün alındıysa son alınan güne kadar; alınabiliyorsa bugünün önceki günlerine kadar.
	var claimed_through: int = int(state.get("day", 0)) if next_day == NONE_AVAILABLE else next_day - 1
	for day: int in range(1, day_count() + 1):
		if day <= claimed_through:
			tiles.append(TILE_CLAIMED)
		elif day == next_day:
			tiles.append(TILE_TODAY)
		else:
			tiles.append(TILE_UPCOMING)
	return tiles
