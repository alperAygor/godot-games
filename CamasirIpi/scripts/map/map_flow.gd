class_name MapFlow
extends RefCounted

## Harita ile oyun sahnesi arasındaki köprü: "tekrar oyna" devri ve tekrar kazancı.
## Tekrar (replay) kuralı: seviye ilerlemez, seri değişmez, geçiş reklamı sayacı artmaz; yalnız
## yıldız FARKI (ve fark varsa ek jeton) ödenir (ProgressData.complete_level_rated bunu zaten yapar).
## Günlük bulmacadaki "bekleyen seviye" deseniyle aynı: oyun sahnesi `_ready`de değeri alıp temizler.

const EVENT_MAP_OPEN: String = "map_open"
const EVENT_REPLAY_START: String = "replay_start"
const EVENT_REPLAY_WIN: String = "replay_win"

## Oynanacak tekrar seviyesi (0 = yok). Tek seferlik.
static var pending_replay: int = 0
## Tekrar bitince ana ekran haritayı yeniden açsın (oyuncu kaldığı yerden devam eder).
static var reopen_map: bool = false


static func take_pending_replay() -> int:
	var level: int = pending_replay
	pending_replay = 0
	return level


static func take_reopen_map() -> bool:
	var value: bool = reopen_map
	reopen_map = false
	return value


## Bitirilmiş bir seviyeyi tekrar oynat.
static func start_replay(level: int) -> void:
	pending_replay = level
	AnalyticsLog.record(EVENT_REPLAY_START, {"level": level, "best": Progress.best_stars(level)})
	GameManager.start_game()


## Güncel seviyeyi başlat (haritada mevcut seviyeye dokunuş).
static func start_current() -> void:
	pending_replay = 0
	GameManager.start_game()


## Tekrar kazanıldı: derecelendirme normal akışla aynı hesaplanır, ama kayıt `level_number`
## seviyesine yapılır (Progress.level() ilerlemez). Dönen sözlük ResultSheet.win'in beklediği
## alanları taşır; "stars" = BU tekrarda kazanılan yıldız FARKI.
static func replay_win(level_number: int, board: LaundryBoard, hard: bool, stats: RunStats) -> Dictionary:
	var balance: Dictionary = Progress.balance_table()
	var rating: int = StarRating.rate_stats(stats, board.item_ids().size(), balance)
	var base_coins: int = ProgressData.to_count(balance.get("hard_win_coins" if hard else "win_coins"))
	var extra: Dictionary = StarRating.breakdown(base_coins, rating, stats.best_chain, balance)
	var bonus: int = int(extra["perfect"]) + int(extra["chain"])
	var before: int = Progress.best_stars(level_number)
	var result: Dictionary = Progress.complete_level_rated(hard, rating, bonus, level_number)
	result["perfect_bonus"] = int(extra["perfect"]) if int(result["bonus_coins"]) > 0 else 0
	result["chain_bonus"] = int(extra["chain"]) if int(result["bonus_coins"]) > 0 else 0
	result["best_chain"] = stats.best_chain
	result["rack_max"] = stats.rack_max
	result["total_coins"] = int(result["coins"])
	AnalyticsLog.record(EVENT_REPLAY_WIN, {"level": level_number, "stars": rating,
		"best_before": before, "delta": int(result["stars"]), "coins": int(result["coins"])})
	return result


## Tekrar bitince ana ekrana (haritayı açık bırakarak) dön.
static func finish_replay() -> void:
	reopen_map = true
	GameManager.goto_scene(&"home")
