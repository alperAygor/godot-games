class_name RunFlow
extends Node

## Oyun ekranı ile ekonomi/reklam/analitik arasındaki yapıştırıcı. game.gd yalnız kısa
## çağrılar yapar; kararlar `Progress`, `AdPacing` ve `AdManager`dadır.
## Ekranın alt düğümü olarak eklenir (`add_child(RunFlow.new())`); sahneyle birlikte silinir.

const MS_PER_SECOND: float = 1000.0

var _level_started_msec: int = 0
## Aynı anda tek reklam akışı: bekleyen yerleşim ve ödül geri çağrısı.
var _pending_placement: int = -1
var _pending_reward: Callable = Callable()
var _pending_failure: Callable = Callable()
var _pending_interstitial: Callable = Callable()
var _pending_interstitial_level: int = 0
## Oyuncu bu seviye geçişinde (kazanma sayfasında) ödüllü reklam izledi mi? Öyleyse hemen ardından
## geçiş reklamı gösterilmez. Her sonuç sayfasında (kazanma/kayıp) ve seviye başında sıfırlanır.
var _rewarded_in_transition: bool = false


func _ready() -> void:
	AdManager.rewarded_finished.connect(_on_rewarded_finished)
	AdManager.interstitial_finished.connect(_on_interstitial_finished)
	AdManager.ad_failed.connect(_on_ad_failed)


func _exit_tree() -> void:
	# Autoload sinyalleri sahneden uzun yaşar: ölü RunFlow'a bağlı kalmasın.
	if AdManager.rewarded_finished.is_connected(_on_rewarded_finished):
		AdManager.rewarded_finished.disconnect(_on_rewarded_finished)
	if AdManager.interstitial_finished.is_connected(_on_interstitial_finished):
		AdManager.interstitial_finished.disconnect(_on_interstitial_finished)
	if AdManager.ad_failed.is_connected(_on_ad_failed):
		AdManager.ad_failed.disconnect(_on_ad_failed)


## Seviye başı: reklam sınırı "seviye başına" sayılır.
func on_level_start(level_number: int) -> void:
	AdManager.reset_run_limits()
	_rewarded_in_transition = false
	_level_started_msec = Time.get_ticks_msec()
	AnalyticsLog.level_start(level_number)


## Kazanç: ilerlemeyi işler. Dönen sözlük `Progress.complete_level` çıktısıdır
## ({"coins": bu seviyenin kazancı, "level": yeni seviye}).
func on_win(level_number: int) -> Dictionary:
	_rewarded_in_transition = false
	AnalyticsLog.level_win(level_number, _elapsed_seconds())
	return Progress.complete_level()


func on_lose(level_number: int) -> void:
	_rewarded_in_transition = false
	AnalyticsLog.level_lose(level_number, _elapsed_seconds())


## 2x jeton: ödüle EKLENECEK fazlalık (çarpan data/balance.json `double_coins_multiplier`).
func double_bonus(reward: int) -> int:
	var multiplier: int = ProgressData.to_count(Progress.balance_table().get("double_coins_multiplier"), 2)
	return reward * maxi(multiplier - 1, 0)


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


## Seviye geçişinde (Devam) geçiş reklamı gerekiyorsa gösterir, sonra `then` çalışır.
## Karar saf `AdPacing`dedir (data/ads.json): varsayılan 4. seviyeden itibaren her geçişte;
## "reklamları kaldır" varsa asla; bu geçişte ödüllü reklam izlendiyse asla.
## Reklam hazır değilse/zaman aşımında akış sessizce sürer.
func maybe_interstitial(next_level: int, then: Callable) -> void:
	var show: bool = AdPacing.should_show(next_level, Progress.remove_ads_owned(),
		_rewarded_in_transition, AdManager.interstitial_pacing())
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
		_rewarded_in_transition = true
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
