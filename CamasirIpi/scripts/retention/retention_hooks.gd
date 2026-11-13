class_name RetentionHooks
extends RefCounted

## game.gd'nin tek satırlık kancalarının hedefi. Neden ayrı sınıf: game.gd'ye mantık girmesin;
## oyun yalnız kendi bildiği değerleri verir, olay sözlüğünü burası kurar.

## Seviye (ya da günlük bulmaca) başladı.
static func level_started(level_number: int, is_daily: bool) -> void:
	RetentionEvents.emit(RetentionEvents.LEVEL_STARTED, 1, {"level": level_number, "daily": is_daily})
	RetentionHub.refresh_notifications()


## Seviye kazanıldı (ekonomi işlenmeden ÖNCE çağrılır; Progress.level() henüz ilerlememiştir).
static func level_won(level_number: int, stats: RunStats, board: LaundryBoard, is_daily: bool) -> void:
	var items: int = board.item_ids().size()
	var stars: int = StarRating.rate_stats(stats, items, RetentionStore.balance())
	var data: Dictionary = {"level": level_number, "stars": stars, "rack_total": stats.rack_total,
		"rack_max": stats.rack_max, "best_chain": stats.best_chain,
		"boosters_used": stats.boosters_used, "daily": is_daily}
	if stats.boosters_used > 0:
		RetentionEvents.emit(RetentionEvents.BOOSTER_USED, stats.boosters_used, data)
	if is_daily:
		# Günlük bulmaca normal ilerlemeden ayrıdır: "seviye bitir" görevine sayılmaz.
		RetentionEvents.emit(RetentionEvents.DAILY_WON, 1, data)
	else:
		RetentionEvents.emit(RetentionEvents.LEVEL_WON, 1, data)
	RetentionHub.refresh_notifications()


## Bir sepet tamamlandı. `event`: LaundryBoard'un BASKET_DONE olayı ("color": renk kimliği,
## "chain": RunStats'ın zincir adımı); `garments`: sepetteki çamaşır sayısı.
static func basket_done(event: Dictionary, garments: int) -> void:
	RetentionEvents.emit(RetentionEvents.BASKET_COMPLETED, 1, {
		"color": int(event.get("color", -1)),
		"count": maxi(garments, 1),
		"chain": int(event.get(RunStats.EVENT_CHAIN_KEY, 1))})
