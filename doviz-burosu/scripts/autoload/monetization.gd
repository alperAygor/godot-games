extends Node
## Para kazanma katmanı: ödüllü reklam teklifleri, geçiş reklamı kararı, satın alma (`no_ads`) ve sahiplik.
## Oyun kodu Ads/IAP'yi doğrudan değil BURADAN kullanır. Kurallar AdPolicy'de (saf, testli); ayarlar data/ads.json.
## Debug sürümünde sahte sağlayıcılar (MockAdsProvider/MockIapProvider) kullanılır; gerçek SDK Faz 11'de.
## Kayıtlar (SaveManager.data): "ads" = {sessions, units, last_interstitial_unit}, "purchases" = [ürün kimlikleri].

signal purchase_result(product_id: String, success: bool, error: String)
signal restore_result(owned_ids: PackedStringArray)

const NO_ADS := "no_ads"
const NEVER := -1000000

## Son herhangi bir reklamın gösterildiği an (Time.get_ticks_msec/1000); hiç yoksa çok eski.
var last_ad_seconds := -100000.0
## Testlerde saati sabitlemek için (>= 0 ise Time.get_ticks_msec yerine bu kullanılır, saniye).
var clock_override := -1.0
var _waiting_placement := ""


func _ready() -> void:
	install_providers()
	Ads.set_personalization(bool(SettingsManager.get_value("game", "analytics_consent")))
	Ads.request_consent()  # gerekiyorsa sağlayıcının onay formu (UMP) çıkar; bitmeden SDK başlamaz
	IAP.purchase_finished.connect(_on_purchase_finished)
	IAP.purchases_restored.connect(_on_restored)
	_state()["sessions"] = int(_state().get("sessions", 0)) + 1
	IAP.restore_purchases()  # mağaza doğruluk kaynağıdır: açılışta sahiplikler sorgulanır


func _now() -> float:
	return clock_override if clock_override >= 0.0 else Time.get_ticks_msec() / 1000.0


## Sağlayıcıları seçer: Android'de eklenti tekili varsa GERÇEK sağlayıcı (data/ads_ids.json `providers`), yoksa debug sürümde
## sahte sağlayıcı; yayın sürümünde eklenti yoksa taban (reklamsız) sağlayıcı kalır.
func install_providers() -> void:
	var cfg := JsonIO.read_dict("res://data/ads_ids.json")
	var providers: Dictionary = cfg.get("providers", {})
	if OS.has_feature("android") and bool(providers.get("admob", false)) and Engine.has_singleton("AdmobPlugin"):
		Ads.set_provider(AdMobAdsProvider.new(cfg))
	elif OS.is_debug_build():
		var mock_ads := MockAdsProvider.new()
		mock_ads.interactive = DisplayServer.get_name() != "headless"
		Ads.set_provider(mock_ads)
	if OS.has_feature("android") and bool(providers.get("play_billing", false)) and Engine.has_singleton("GodotGooglePlayBilling"):
		IAP.set_provider(PlayBillingIapProvider.new())
	elif OS.is_debug_build():
		IAP.set_provider(MockIapProvider.new())


# --- Gizlilik / onay -----------------------------------------------------------------------

## İlk açılışta gizlilik penceresi sorulmalı mı?
func consent_needed() -> bool:
	return not bool(SettingsManager.get_value("game", "consent_asked"))


## Kullanıcının kararı: analitik gönderimi ve reklam kişiselleştirme buna bağlanır.
func apply_consent(allowed: bool) -> void:
	SettingsManager.set_value("game", "analytics_consent", allowed, false)
	SettingsManager.set_value("game", "consent_asked", true)
	Analytics.set_consent(allowed)
	Ads.set_personalization(allowed)


## Ayarlar > Gizlilik seçenekleri: sağlayıcının onay formunu da (varsa) yeniden açar.
func open_provider_privacy_options() -> bool:
	return Ads.show_privacy_options()


# --- Kayıt ---------------------------------------------------------------------------

func _state() -> Dictionary:
	if not (SaveManager.data.get("ads") is Dictionary):
		SaveManager.data["ads"] = {"sessions": 0, "units": 0, "last_interstitial_unit": NEVER}
	return SaveManager.data["ads"]


func owned_products() -> PackedStringArray:
	var result := PackedStringArray()
	for product_id: Variant in SaveManager.data.get("purchases", []):
		result.append(str(product_id))
	return result


func owns(product_id: String) -> bool:
	return product_id in owned_products()


func owns_no_ads() -> bool:
	return owns(NO_ADS)


func _grant(product_id: String) -> void:
	if owns(product_id):
		return
	var list := owned_products()
	list.append(product_id)
	SaveManager.data["purchases"] = Array(list)
	SaveManager.save_game()


# --- Satın alma ------------------------------------------------------------------------

func price_text(product_id: String) -> String:
	return IAP.provider.get_price_text(product_id)


func store_available() -> bool:
	return IAP.is_available()


func buy(product_id: String) -> void:
	IAP.purchase(product_id)


func restore() -> void:
	IAP.restore_purchases()


func _on_purchase_finished(product_id: String, success: bool, error: String) -> void:
	if success:
		_grant(product_id)
		Analytics.log_event("iap_purchase", {"product_id": product_id})
	purchase_result.emit(product_id, success, error)


func _on_restored(product_ids: PackedStringArray) -> void:
	for product_id in product_ids:
		_grant(product_id)
	restore_result.emit(product_ids)


# --- Ödüllü reklamlar ------------------------------------------------------------------------

## Teklif durumu: {"visible": sınır dolmadıysa true, "enabled": reklam hazırsa true}. Sınır doluysa teklif hiç gösterilmez;
## reklam hazır değilse buton "Reklam şu an yok" diye pasif görünür (hata gösterilmez).
func rewarded_offer(placement: String, used: int) -> Dictionary:
	var within := AdPolicy.rewarded_within_limit(placement, used)
	return {"visible": within, "enabled": within and Ads.is_rewarded_ready(placement)}


## Ödüllü reklamı gösterir; bitince `done(rewarded: bool)` çağrılır. Başka reklam beklerken ikinci istek reddedilir (false).
func request_reward(placement: String, done: Callable) -> void:
	if not _waiting_placement.is_empty():
		done.call(false)
		return
	_waiting_placement = placement
	Analytics.log_event("ad_offer_shown", {"placement": placement})
	var handler := func(finished_placement: String, rewarded: bool) -> void:
		if finished_placement != _waiting_placement:
			return
		_waiting_placement = ""
		last_ad_seconds = _now()
		if rewarded:
			Analytics.log_event("ad_rewarded", {"placement": placement})
		done.call(rewarded)
	Ads.rewarded_finished.connect(handler, CONNECT_ONE_SHOT)
	Ads.show_rewarded(placement)


# --- Geçiş reklamı ---------------------------------------------------------------------------------

## Tamamlanan bir oyun birimi (biten hikaye günü / mod koşusu). Geçiş reklamı aralığı bunu sayar.
func count_play_unit() -> void:
	_state()["units"] = int(_state().get("units", 0)) + 1


func interstitial_state() -> Dictionary:
	var state := _state()
	return {
		"owns_no_ads": owns_no_ads(),
		"story_day": GameSession.modes().max_day(),
		"units": int(state.get("units", 0)),
		"last_interstitial_unit": int(state.get("last_interstitial_unit", NEVER)),
		"seconds_since_any_ad": _now() - last_ad_seconds,
		"session_play_seconds": _now(),
		"session_index": int(state.get("sessions", 1)),
	}


## Geçiş reklamı göstermeye izin var mı: AdPolicy.interstitial sonucu.
func interstitial_decision() -> Dictionary:
	return AdPolicy.interstitial(interstitial_state())


## Politika izin veriyorsa geçiş reklamını gösterir ve kapanınca `then` çağrılır; yoksa `then` hemen çağrılır.
func show_interstitial_then(placement: String, then: Callable) -> void:
	if not bool(interstitial_decision()["allowed"]):
		then.call()
		return
	_state()["last_interstitial_unit"] = int(_state().get("units", 0))
	last_ad_seconds = _now()
	Analytics.log_event("interstitial_shown", {"placement": placement})
	SaveManager.save_game()
	Ads.interstitial_closed.connect(func(_closed: String) -> void: then.call(), CONNECT_ONE_SHOT)
	Ads.show_interstitial(placement)
