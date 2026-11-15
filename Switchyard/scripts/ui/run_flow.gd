class_name RunFlow
extends Node

## Oyun ekranı ile reklam/analitik arasındaki yapıştırıcı. game.gd yalnız kısa çağrılar yapar;
## kararlar `LevelProgress`, `AdPacing` ve `AdManager`dadır.
## Ekranın alt düğümü olarak eklenir (`add_child(RunFlow.new())`); sahneyle birlikte silinir.
## Sahibin reklam kararı (docs/MONETIZATION.md): ipucu ve seviye atlama = birer ödüllü reklam;
## geçiş reklamı yalnız seviye arasında ve `AdPacing` izin verirse.

const MS_PER_SECOND: float = 1000.0
## Reklam sunulamama nedenleri (UI yalnız bu kodlara bakar; metin `UiStrings.ad_reason`).
const REASON_NOT_READY: String = "not_ready"
const REASON_OFFLINE: String = "offline"
const REASON_TIMEOUT: String = "timeout"
const REASON_NOT_FINISHED: String = "not_finished"

## Reklam sunulamadı / başarısız oldu (düğme nedenini söylesin).
signal ad_unavailable(placement: AdManager.Placement, reason: String)

## Unix saniyesi veren saat; boşsa sistem saati. Probe/test geçiş reklamı aralığını buradan sürer.
var time_source: Callable = Callable()

var _level_started_msec: int = 0
var _level_number: int = 0
## Aynı anda tek reklam akışı: bekleyen yerleşim ve geri çağrılar.
var _pending_placement: int = -1
var _pending_reward: Callable = Callable()
var _pending_failure: Callable = Callable()
var _pending_interstitial: Callable = Callable()
var _pending_interstitial_number: int = 0
## Bu seviyede (ipucu ya da atlama ile) ödüllü reklam izlendi mi: geçiş reklamı kararına girer.
var _rewarded_this_level: bool = false


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


## Yeni seviye yüklendi (aynı seviyeyi baştan başlatmak buraya GELMEZ): reklam sınırları sıfırlanır.
func on_level_start(level_number: int) -> void:
	AdManager.reset_run_limits()
	_rewarded_this_level = false
	_level_number = level_number
	_level_started_msec = Time.get_ticks_msec()
	AnalyticsLog.level_start(level_number)


func on_solved(level_number: int) -> void:
	AnalyticsLog.level_win(level_number, _elapsed_seconds())


func rewarded_this_level() -> bool:
	return _rewarded_this_level


## İpucu / atlama düğmeleri bu seviyede görünsün mü (ilk 3 seviyede hayır).
func rewarded_buttons_visible(level_number: int) -> bool:
	return AdPacing.rewarded_buttons_visible(level_number, AdManager.rewarded_config())


## Ödüllü reklam sunulabilir mi (sağlayıcı hazır + sınır dolmadı + başka reklam yok).
func can_watch(placement: AdManager.Placement) -> bool:
	return _pending_placement == -1 and AdManager.can_offer(placement)


## Ödüllü reklam sunulamıyorsa nedeni.
func unavailable_reason() -> String:
	if OnlineGate.is_active() and not OnlineGate.checker().is_fresh():
		return REASON_OFFLINE
	return REASON_NOT_READY


## Ödüllü reklamı izletir; ödül YALNIZ başarıda `on_success` ile verilir. Sunulamazsa `ad_unavailable`
## sinyali neden ile gelir, `on_failure` çalışır ve akış takılmaz. Dönen: reklam başlatıldı mı.
func watch(placement: AdManager.Placement, on_success: Callable,
		on_failure: Callable = Callable()) -> bool:
	if not can_watch(placement):
		ad_unavailable.emit(placement, unavailable_reason())
		if on_failure.is_valid():
			on_failure.call()
		return false
	var key: String = String(AdManager.PLACEMENT_KEYS.get(placement, ""))
	AnalyticsLog.rewarded_offered(key)
	_pending_placement = placement
	_pending_reward = on_success
	_pending_failure = on_failure
	AdManager.show_rewarded(placement)
	return true


## Seviye arası geçiş reklamı: `AdPacing` izin veriyorsa gösterir, sonra (her durumda) `then` çalışır.
## `completed_number`: biten seviyenin sıra numarası; `first_completion`: ilk kez mi tamamlandı.
## Reklam hazır değilse/zaman aşımında akış sessizce sürer.
func maybe_interstitial(completed_number: int, first_completion: bool, then: Callable) -> void:
	var pacing: Dictionary = AdManager.interstitial_pacing()
	var show: bool = AdPacing.should_show(completed_number, first_completion, Progress.remove_ads_owned(),
		_rewarded_this_level, AdPacing.seconds_since(_now(), Progress.data.last_interstitial_time), pacing)
	if not show or _pending_placement != -1:
		then.call()
		return
	# Geri çağrı reklamdan ÖNCE kaydedilir: eşzamanlı biten sağlayıcıda sinyal show içinde gelir.
	_pending_interstitial = then
	_pending_interstitial_number = completed_number
	if not AdManager.show_interstitial():
		_pending_interstitial = Callable()
		then.call()


func _now() -> float:
	return float(time_source.call()) if time_source.is_valid() else Time.get_unix_time_from_system()


func _on_rewarded_finished(placement: AdManager.Placement, success: bool) -> void:
	if int(placement) != _pending_placement or not success:
		return
	var key: String = String(AdManager.PLACEMENT_KEYS.get(placement, ""))
	var reward: Callable = _pending_reward
	_clear_pending()
	AnalyticsLog.rewarded_watched(key)
	_rewarded_this_level = true
	Progress.mark_rewarded_watched()
	if reward.is_valid():
		reward.call()


## Başlamayan / yarım kalan / zaman aşımına uğrayan ödüllü reklam: ödülsüz, nedeniyle bildirilir.
func _on_ad_failed(placement: AdManager.Placement, reason: String) -> void:
	if int(placement) != _pending_placement:
		return
	var key: String = String(AdManager.PLACEMENT_KEYS.get(placement, ""))
	var failure: Callable = _pending_failure
	_clear_pending()
	AnalyticsLog.rewarded_skipped(key)
	ad_unavailable.emit(placement, _reason_code(reason))
	if failure.is_valid():
		failure.call()


func _clear_pending() -> void:
	_pending_placement = -1
	_pending_reward = Callable()
	_pending_failure = Callable()


static func _reason_code(provider_reason: String) -> String:
	match provider_reason:
		"timeout":
			return REASON_TIMEOUT
		"dismissed_early":
			return REASON_NOT_FINISHED
		_:
			return REASON_NOT_READY


func _on_interstitial_finished(success: bool) -> void:
	if not _pending_interstitial.is_valid():
		return
	var then: Callable = _pending_interstitial
	_pending_interstitial = Callable()
	if success:
		AnalyticsLog.interstitial_shown(_pending_interstitial_number)
		Progress.mark_interstitial_shown(_now())
	then.call()


func _elapsed_seconds() -> float:
	return float(Time.get_ticks_msec() - _level_started_msec) / MS_PER_SECOND
