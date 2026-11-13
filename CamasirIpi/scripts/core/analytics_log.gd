class_name AnalyticsLog
extends RefCounted

## Ağsız, bellek içi olay kaydı (halka tampon). Hata ayıklama sürümünde `print` eder.
## Autoload gerektirmez: her yerden `AnalyticsLog.level_win(...)` çağrılır.

const MAX_EVENTS: int = 200

static var echo: bool = OS.is_debug_build()
static var _events: Array[Dictionary] = []


static func record(event_name: String, params: Dictionary = {}) -> void:
	var entry: Dictionary = {"name": event_name, "time": Time.get_unix_time_from_system()}
	entry.merge(params, true)
	_events.append(entry)
	# Halka tampon: eski olaylar düşer, bellek sınırsız büyümez.
	if _events.size() > MAX_EVENTS:
		_events.pop_front()
	if echo:
		print("ANALYTICS %s %s" % [event_name, str(params)])


static func events() -> Array[Dictionary]:
	return _events


static func clear() -> void:
	_events.clear()


static func count(event_name: String) -> int:
	var total: int = 0
	for entry: Dictionary in _events:
		if String(entry["name"]) == event_name:
			total += 1
	return total


static func level_start(level: int, rack_slots: int) -> void:
	record("level_start", {"level": level, "rack": rack_slots})


static func level_win(level: int, seconds: float, moves: int, rack: int, remaining: int) -> void:
	record("level_win", {"level": level, "seconds": seconds, "moves": moves,
		"rack": rack, "remaining": remaining})


static func level_lose(level: int, seconds: float, moves: int, rack: int, remaining: int) -> void:
	record("level_lose", {"level": level, "seconds": seconds, "moves": moves,
		"rack": rack, "remaining": remaining})


static func booster_used(id: String, source: String) -> void:
	record("booster_used", {"id": id, "source": source})


static func rewarded_offered(placement: String) -> void:
	record("rewarded_offered", {"placement": placement})


static func rewarded_watched(placement: String) -> void:
	record("rewarded_watched", {"placement": placement})


static func rewarded_skipped(placement: String) -> void:
	record("rewarded_skipped", {"placement": placement})


static func interstitial_shown(level: int) -> void:
	record("interstitial_shown", {"level": level})
