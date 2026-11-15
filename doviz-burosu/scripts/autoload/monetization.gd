extends Node
## Para kazanma katmanı: ödüllü reklam teklifleri, geçiş reklamı kararı, satın alma (`no_ads`) ve sahiplik.
## Oyun kodu Ads/IAP'yi doğrudan değil BURADAN kullanır. Kurallar AdPolicy'de (saf, testli); ayarlar data/ads.json.
## Debug sürümünde sahte sağlayıcılar (MockAdsProvider/MockIapProvider) kullanılır; Android'de eklenti varsa gerçek SDK sağlayıcıları.
## İLK AÇILIŞ SIRASI (docs/MONETIZATION.md): 1) sağlayıcılar kurulur (SDK henüz BAŞLAMAZ) -> 2) kayıtlı tercihler sağlayıcıya iletilir ->
## 3) UMP onay adımı (`Ads.request_consent`): AB/UK'de Google formu, diğer bölgelerde hiçbir şey -> 4) bölge çözülünce `notice_needed`
## (yalnızca UMP gerekmiyorsa ve daha önce sorulmadıysa; ana menü kısa bilgi penceresini gösterir) -> 5) reklam SDK'sı ancak 3 (form) ya da
## 4 (pencere yanıtlandı) bitince başlar -> 6) mağaza bağlantısı ve sahiplik sorgusu.
## Kayıtlar (SaveManager.data): "ads" = {sessions, units, last_interstitial_unit}, "purchases" = [ürün kimlikleri].

signal purchase_result(product_id: String, success: bool, error: String)
signal restore_result(owned_ids: PackedStringArray)
signal restore_failed(reason: String)
## Mağaza bağlantısı/kullanılabilirliği değişti (geç bağlanma): Market ekranı yeniden çizilir.
signal store_changed
## UMP çözüldü ve oyunun kendi bilgi penceresi gösterilmeli (ana menü dinler).
signal notice_needed
## Ödüllü reklam ödül vermeden bitti. reason: not_ready | busy | timeout | no_reward.
signal reward_failed(placement: String, reason: String)

const NO_ADS := "no_ads"
const NEVER := -1000000

## Son herhangi bir reklamın gösterildiği an (Time.get_ticks_msec/1000); hiç yoksa çok eski.
var last_ad_seconds := -100000.0
## Testlerde saati sabitlemek için (>= 0 ise Time.get_ticks_msec yerine bu kullanılır, saniye).
var clock_override := -1.0
var _waiting_placement := ""
var _wait_token := 0
## UMP/onay adımı bitti mi ve hangi rejim (ConsentFlow.REGIME_*).
var consent_resolved := false
var consent_regime := ConsentFlow.REGIME_UNKNOWN
## Reklam yapılandırması sorunu (AdsConfig.PROBLEM_*); boş = sorun yok. Doluysa reklam SDK'sı kurulmadı.
var config_error := ""
## Yer -> bu oturumda denendi ve ödül gelmedi (ücretsiz yol için, RetryPolicy).
var _ad_failed := {}
## Testlerde zaman aşımlarını kısaltmak için (> 0 ise data/ads.json yerine, saniye).
var rewarded_timeout_override := -1.0
var interstitial_timeout_override := -1.0


func _ready() -> void:
	install_providers()
	Ads.set_personalization(bool(SettingsManager.get_value("game", "ads_personalized")))
	Ads.set_notice_answered(not consent_needed_by_setting())
	Ads.consent_finished.connect(_on_consent_finished)
	Ads.request_consent()  # AB/UK'de UMP formu çıkar; SDK onay çözülmeden BAŞLAMAZ (bkz. ConsentFlow)
	IAP.purchase_finished.connect(_on_purchase_finished)
	IAP.purchases_restored.connect(_on_restored)
	IAP.restore_failed.connect(func(reason: String) -> void: restore_failed.emit(reason))
	IAP.availability_changed.connect(func() -> void: store_changed.emit())
	_state()["sessions"] = int(_state().get("sessions", 0)) + 1
	IAP.restore_purchases()  # mağaza doğruluk kaynağıdır: açılışta sahiplikler sorgulanır


func _now() -> float:
	return clock_override if clock_override >= 0.0 else Time.get_ticks_msec() / 1000.0


## Sağlayıcıları seçer: Android'de eklenti tekili varsa GERÇEK sağlayıcı (data/ads_ids.json `providers`), yoksa debug sürümde
## sahte sağlayıcı; yayın sürümünde eklenti yoksa taban (reklamsız) sağlayıcı kalır.
## `ids`/`release`/`android` testler içindir. YAPILANDIRMA HATASI (mode=real + eksik/test kimlik) her sürümde reklam SDK'sını kurmaz:
## taban (reklamsız) sağlayıcı kalır, `config_error` dolar ve hata yazılır (yayın sürümünde push_error). Sessizce test kimliğine düşülmez.
func install_providers(ids: Dictionary = {}, release := not OS.is_debug_build(), android := OS.has_feature("android")) -> void:
	var cfg := ids if not ids.is_empty() else JsonIO.read_dict("res://data/ads_ids.json")
	var providers: Dictionary = cfg.get("providers", {})
	config_error = AdsConfig.problem(cfg)
	if not config_error.is_empty():
		_report("reklam yapılandırması geçersiz (%s): data/ads_ids.json. Reklam SDK'sı kurulmadı." % config_error, release)
		Ads.set_provider(AdsProvider.new())
	elif android and bool(providers.get("admob", false)) and Engine.has_singleton("AdmobPlugin"):
		if release and str(cfg.get("mode", "test")) != "real":
			push_warning("[Ads] Yayın sürümü TEST reklam kimlikleriyle çalışıyor (mode=test); mağaza yüklemesi için tools/release_check.sh bunu reddeder.")
		Ads.set_provider(AdMobAdsProvider.new(cfg))
	elif not release:
		var mock_ads := MockAdsProvider.new()
		mock_ads.interactive = DisplayServer.get_name() != "headless"
		Ads.set_provider(mock_ads)
	else:
		Ads.set_provider(AdsProvider.new())
	if android and bool(providers.get("play_billing", false)) and Engine.has_singleton("GodotGooglePlayBilling"):
		IAP.set_provider(PlayBillingIapProvider.new())
	elif not release:
		IAP.set_provider(MockIapProvider.new())
	else:
		IAP.set_provider(IapProvider.new())


## Testler bunu değiştirir (verify.sh `ERROR:` satırlarını başarısızlık sayar).
var problem_logger: Callable = Callable()


func _report(message: String, release: bool) -> void:
	if problem_logger.is_valid():
		problem_logger.call(message, release)
	elif release:
		push_error("[Monetization] " + message)
	else:
		push_warning("[Monetization] " + message)


# --- Gizlilik / onay -----------------------------------------------------------------------

## Kayıtlı karar var mı (oyunun bilgi penceresi daha önce yanıtlandı mı)?
func consent_needed_by_setting() -> bool:
	return not bool(SettingsManager.get_value("game", "consent_asked"))


## Oyunun kendi kısa bilgi penceresi şimdi gösterilmeli mi? Yalnızca UMP çözüldüyse, UMP bu bölgeye uygulanmıyorsa (NOTICE) ve sorulmadıysa.
func consent_needed() -> bool:
	return consent_resolved and ConsentFlow.notice_needed(consent_regime, not consent_needed_by_setting())


## Bu cihazda UMP formu geçerli mi (AB/UK...): Ayarlar'da "reklam seçenekleri" düğmesi ve UMP'den yeniden sorma buna bağlı.
func provider_form_applies() -> bool:
	return consent_regime == ConsentFlow.REGIME_FORM


func _on_consent_finished() -> void:
	consent_resolved = true
	consent_regime = Ads.consent_regime()
	if consent_needed():
		notice_needed.emit()


## Oyuncunun REKLAM KİŞİSELLEŞTİRME tercihi (bilgi penceresi/Ayarlar). Analitik için ayrı anahtar yoktur: analitik SDK'sı yok, hiçbir veri gönderilmiyor.
## `game/ads_personalized` = kişiselleştirilmiş reklam; `game/consent_asked` = pencere yanıtlandı (SDK bundan sonra başlayabilir).
func apply_consent(personalized: bool) -> void:
	SettingsManager.set_value("game", "ads_personalized", personalized, false)
	SettingsManager.set_value("game", "consent_asked", true)
	Ads.set_personalization(personalized)
	Ads.set_notice_answered(true)


## ESKİ SÖZLEŞME (settings_screen.gd çağırır): UMP formunu artık burada açmaz — ConsentSheet kendi düğmesiyle açar (iki pencere üst üste çıkmasın).
## T-A2 ayarlar ekranını güncelleyince bu çağrı kalkar; ekran yalnızca `ConsentSheet.new()` eklemelidir.
func open_provider_privacy_options() -> bool:
	return false


## UMP "reklam seçenekleri" formunu açar (yalnızca UMP rejiminde true).
func open_ump_privacy_options() -> bool:
	return Ads.show_privacy_options()


# --- Gizlilik politikası -----------------------------------------------------------------------

func privacy_policy_url() -> String:
	return str(JsonIO.read_dict("res://data/ads_ids.json").get("privacy_policy_url", ""))


## Yer tutucu ya da https olmayan adres yayın sürümünde gösterilmez (AdsConfig.policy_url_visible).
func privacy_policy_visible() -> bool:
	return AdsConfig.policy_url_visible(privacy_policy_url(), not OS.is_debug_build())


func open_privacy_policy() -> bool:
	if not privacy_policy_visible():
		return false
	OS.shell_open(privacy_policy_url())
	return true


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


## Mağaza bağlantısı geç gelirse/koptuysa yeniden bağlanmayı dener (Market ekranı aralıklı çağırır).
func retry_store() -> void:
	IAP.reconnect()


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


func _timeout(key: String, override: float) -> float:
	if override > 0.0:
		return override
	return float(JsonIO.read_shared("res://data/ads.json").get("timeouts", {}).get(key, 120.0))


## Ödüllü reklamı gösterir; bitince `done(rewarded: bool)` TAM BİR KEZ çağrılır. Başka reklam beklerken ikinci istek reddedilir (false).
## Reklam hazır değilse sağlayıcı "ödülsüz" bitirir; SDK hiç yanıt vermezse zaman aşımı (data/ads.json timeouts.rewarded_seconds) aynısını yapar:
## oyuncu asla takılı kalmaz. Başarısızlık nedeni `reward_failed` sinyalinde; ücretsiz yol için `retry_day_options`.
func request_reward(placement: String, done: Callable) -> void:
	if not _waiting_placement.is_empty():
		reward_failed.emit(placement, "busy")
		done.call(false)
		return
	_waiting_placement = placement
	_wait_token += 1
	var token := _wait_token
	var was_ready := Ads.is_rewarded_ready(placement)
	Analytics.log_event("ad_offer_shown", {"placement": placement})
	var state := [false]  # tamamlandı mı (çift çağrıyı önler)
	var handler := func(finished_placement: String, rewarded: bool) -> void:
		if finished_placement != _waiting_placement or state[0]:
			return
		state[0] = true
		_waiting_placement = ""
		last_ad_seconds = _now()
		_record_reward_result(placement, rewarded, "not_ready" if not was_ready else "no_reward")
		done.call(rewarded)
	Ads.rewarded_finished.connect(handler)
	var timer := get_tree().create_timer(_timeout("rewarded_seconds", rewarded_timeout_override), true, false, true)
	timer.timeout.connect(func() -> void:
		if state[0] or token != _wait_token:
			return
		state[0] = true
		_waiting_placement = ""
		_record_reward_result(placement, false, "timeout")
		done.call(false))
	Ads.show_rewarded(placement)
	# handler'ı bitince çöz (bağlantı birikmesin)
	timer.timeout.connect(func() -> void: _disconnect_reward_handler(handler))


func _disconnect_reward_handler(handler: Callable) -> void:
	if Ads.rewarded_finished.is_connected(handler):
		Ads.rewarded_finished.disconnect(handler)


func _record_reward_result(placement: String, rewarded: bool, failure_reason: String) -> void:
	if rewarded:
		_ad_failed.erase(placement)
		Analytics.log_event("ad_rewarded", {"placement": placement})
	else:
		# Ücretsiz yol yalnızca reklam GÖSTERİLEMEDİĞİNDE açılır (hazır değil / zaman aşımı); oyuncunun reklamı erken kapatması (no_reward) açmaz.
		if failure_reason == "not_ready" or failure_reason == "timeout":
			_ad_failed[placement] = true
		reward_failed.emit(placement, failure_reason)


# --- "Günü tekrar oyna" (kovulma/oyun bitti) ---------------------------------------------------------

## Kovulma ekranının seçenekleri (RetryPolicy): {"ad": rewarded_offer, "free": RetryPolicy.free_option}. Reklam gösterilemiyorsa ücretsiz yol AÇIKTIR;
## ilerleme asla yalnızca reklama bağlı değildir. Arayüz (T-B1) ikisini de gösterir; ücretsiz yolun BEDELİ `free.cost_kind/cost_value`
## (karar bekliyor: docs/MONETIZATION.md O8; şu an bedelsiz varsayılan).
func retry_day_options() -> Dictionary:
	var ad := rewarded_offer("retry_day", 0)
	return {"ad": ad, "free": RetryPolicy.free_option(bool(ad["enabled"]), bool(_ad_failed.get("retry_day", false)))}


## Ücretsiz yolu kullanır: uygunsa {"ok": true, "cost_kind", "cost_value"} döner (bedeli UYGULAMAK çağıranındır: Career.restore_morning + ücret).
func take_free_retry() -> Dictionary:
	var free: Dictionary = retry_day_options()["free"]
	if not bool(free["available"]):
		return {"ok": false, "reason": str(free["reason"])}
	Analytics.log_event("retry_day_free", {"reason": free["reason"]})
	_ad_failed.erase("retry_day")
	return {"ok": true, "cost_kind": free["cost_kind"], "cost_value": free["cost_value"]}


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
## Reklam hiç kapanmazsa zaman aşımı (data/ads.json timeouts.interstitial_seconds) `then`'i yine çağırır; `then` TAM BİR KEZ çalışır.
func show_interstitial_then(placement: String, then: Callable) -> void:
	if not bool(interstitial_decision()["allowed"]):
		then.call()
		return
	_state()["last_interstitial_unit"] = int(_state().get("units", 0))
	last_ad_seconds = _now()
	Analytics.log_event("interstitial_shown", {"placement": placement})
	SaveManager.save_game()
	var state := [false]
	var finish := func() -> void:
		if state[0]:
			return
		state[0] = true
		then.call()
	var on_closed := func(_closed: String) -> void: finish.call()
	Ads.interstitial_closed.connect(on_closed, CONNECT_ONE_SHOT)
	get_tree().create_timer(_timeout("interstitial_seconds", interstitial_timeout_override), true, false, true).timeout.connect(func() -> void:
		if Ads.interstitial_closed.is_connected(on_closed):
			Ads.interstitial_closed.disconnect(on_closed)
		finish.call())
	Ads.show_interstitial(placement)
