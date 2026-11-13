class_name EcoFlow
extends Node

## Oyun ekranı ile ekonomi/reklam/analitik arasındaki yapıştırıcı. game.gd yalnız kısa
## çağrılar yapar; kararlar `Progress`, `AdPacing` ve `AdManager`dadır.

const MS_PER_SECOND: float = 1000.0

var _level_started_msec: int = 0
## Aynı anda tek reklam akışı: bekleyen yerleşim ve ödül geri çağrısı.
var _pending_placement: int = -1
var _pending_reward: Callable = Callable()
var _pending_failure: Callable = Callable()
var _pending_interstitial: Callable = Callable()
var _pending_interstitial_level: int = 0


func _ready() -> void:
	AdManager.rewarded_finished.connect(_on_rewarded_finished)
	AdManager.interstitial_finished.connect(_on_interstitial_finished)
	AdManager.ad_failed.connect(_on_ad_failed)


## Seviye başı: seri bonusu varsa askı eklenir (askı kurulmadan ÖNCE çağrılmalı).
func on_level_start(level_number: int, board: LaundryBoard) -> bool:
	# Reklam sınırı "seviye başına" sayılır.
	AdManager.reset_run_limits()
	var bonus: bool = Progress.streak_extra_slot()
	if bonus:
		board.add_rack_slot()
	_level_started_msec = Time.get_ticks_msec()
	AnalyticsLog.level_start(level_number, board.rack_slots())
	return bonus


## Kazanç: ilerlemeyi işler. Dönen sözlük `Progress.complete_level` çıktısıdır.
func on_win(level_number: int, board: LaundryBoard, hard: bool) -> Dictionary:
	AnalyticsLog.level_win(level_number, _elapsed_seconds(), board.moves(),
		board.rack_count(), board.remaining_on_line())
	return Progress.complete_level(hard)


func on_lose(level_number: int, board: LaundryBoard, remaining: int) -> void:
	AnalyticsLog.level_lose(level_number, _elapsed_seconds(), board.moves(),
		board.rack_count(), remaining)
	Progress.fail_level()


## Ödüllü reklam sunulabilir mi (sağlayıcı hazır + sınır dolmadı).
func can_watch(placement: AdManager.Placement) -> bool:
	return _pending_placement == -1 and AdManager.can_offer(placement)


## Ödüllü reklamı izletir; ödül YALNIZ başarıda `on_success` ile verilir.
func watch(placement: AdManager.Placement, on_success: Callable,
		on_failure: Callable = Callable()) -> void:
	if not can_watch(placement):
		return
	var key: String = String(AdManager.PLACEMENT_KEYS.get(placement, ""))
	AnalyticsLog.rewarded_offered(key)
	_pending_placement = placement
	_pending_reward = on_success
	_pending_failure = on_failure
	AdManager.show_rewarded(placement)


## Güçlendirici sayısı 0 iken reklamla +1: UI işçisi bu yardımcıyı çağırır.
func refill_booster(id: String, on_done: Callable = Callable()) -> void:
	var grant: int = ProgressData.to_count(Progress.balance_table().get("refill_booster_grant"), 1)
	watch(AdManager.Placement.REFILL_BOOSTER, func() -> void:
		Progress.add_booster(id, grant)
		if on_done.is_valid():
			on_done.call())


## Seviye geçişinde (Devam) geçiş reklamı gerekiyorsa gösterir, sonra `then` çalışır.
func maybe_interstitial(next_level: int, then: Callable) -> void:
	var pacing: Dictionary = Progress.balance_table().get("interstitial", {}) as Dictionary
	var counters: ProgressData = Progress.data
	var show: bool = AdPacing.should_show(next_level, counters.levels_since_interstitial,
		Time.get_unix_time_from_system(), counters.last_interstitial_time,
		counters.last_rewarded_time, pacing)
	if not show or _pending_placement != -1:
		then.call()
		return
	# Geri çağrı reklamdan ÖNCE kaydedilir: eşzamanlı biten sağlayıcıda sinyal show içinde gelir.
	_pending_interstitial = then
	_pending_interstitial_level = next_level
	if not AdManager.show_interstitial():
		_pending_interstitial = Callable()
		then.call()


func _on_rewarded_finished(placement: AdManager.Placement, success: bool) -> void:
	if int(placement) != _pending_placement:
		return
	var key: String = String(AdManager.PLACEMENT_KEYS.get(placement, ""))
	var reward: Callable = _pending_reward
	var failure: Callable = _pending_failure
	_pending_placement = -1
	_pending_reward = Callable()
	_pending_failure = Callable()
	if success:
		AnalyticsLog.rewarded_watched(key)
		Progress.mark_rewarded_watched()
		if reward.is_valid():
			reward.call()
	else:
		AnalyticsLog.rewarded_skipped(key)
		if failure.is_valid():
			failure.call()


## Sınır/bekleyen yüzünden hiç başlamayan reklam: ödülsüz "atlandı" say.
func _on_ad_failed(placement: AdManager.Placement, _reason: String) -> void:
	if int(placement) == _pending_placement:
		_on_rewarded_finished(placement, false)


func _on_interstitial_finished(success: bool) -> void:
	if not _pending_interstitial.is_valid():
		return
	var then: Callable = _pending_interstitial
	_pending_interstitial = Callable()
	if success:
		AnalyticsLog.interstitial_shown(_pending_interstitial_level)
		Progress.mark_interstitial_shown()
	then.call()


func _elapsed_seconds() -> float:
	return float(Time.get_ticks_msec() - _level_started_msec) / MS_PER_SECOND
