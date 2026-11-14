class_name AdMobAdsProvider
extends AdsProvider
## Gerçek AdMob sağlayıcısı (godot-sdk-integrations/godot-admob v7.0 eklentisini sarar). Oyun kodu yalnızca `Ads` autoload'unu bilir.
## - Reklam kimlikleri data/ads_ids.json'dan: mode=test iken Google'ın herkese açık TEST kimlikleri (eklentinin debug alanları).
## - Ödüllü ve geçiş reklamı önceden yüklenir; gösterilince bir sonraki yüklenir. Yükleme hatasında üstel beklemeyle yeniden denenir.
## - Ödül yalnızca `rewarded_ad_user_earned_reward` gelirse verilir; kapatılırsa/başarısız olursa `rewarded=false`.
## - Onay: UMP (update_consent_info -> gerekiyorsa form) bitmeden SDK başlatılmaz.
## `admob` bir Admob düğümü ya da aynı sinyal/metotlara sahip sahte nesne olabilir (testler); verilmezse oluşturulur ve ağaca eklenir.

const CONSENT_REQUIRED := "REQUIRED"

var admob: Node
var config: Dictionary
var initialized := false

var _rewarded_placement := ""
var _rewarded_earned := false
var _interstitial_placement := ""
var _rewarded_retry := 0
var _interstitial_retry := 0
var _personalization_allowed := true
var _consent_started := false
var _tree: SceneTree
var _owns_node := false


func _init(ids_config: Dictionary = {}, existing_node: Node = null) -> void:
	config = ids_config if not ids_config.is_empty() else JsonIO.read_dict("res://data/ads_ids.json")
	admob = existing_node


## Gerçek kimlikler kullanılacak mı: mode=real VE üç gerçek kimlik dolu. Aksi halde (boşsa sessizce) test.
func uses_real_ids() -> bool:
	var android: Dictionary = config.get("android", {})
	return str(config.get("mode", "test")) == "real" and not str(android.get("real_app_id", "")).is_empty() \
		and not str(android.get("real_rewarded_unit", "")).is_empty() and not str(android.get("real_interstitial_unit", "")).is_empty()


func initialize() -> void:
	_tree = Engine.get_main_loop() as SceneTree
	_owns_node = admob == null
	if _owns_node:
		admob = Admob.new()
	_configure(admob)
	if _owns_node and _tree != null:
		_tree.root.add_child.call_deferred(admob)  # otomatik yükleme sırasında kök meşgul: bir sonraki kareye ertelenir
	_connect_signals()


## Eklenti düğümünün dışarıdan verilen ayarları (kimlikler, içerik sınıfı).
func _configure(node: Node) -> void:
	var android: Dictionary = config.get("android", {})
	var real := uses_real_ids()
	node.set("is_real", real)
	node.set("android_debug_application_id", str(android.get("test_app_id", "")))
	node.set("auto_configure_on_initialize", true)
	if real:
		node.set("android_real_application_id", str(android["real_app_id"]))
		node.set("android_real_rewarded_id", str(android["real_rewarded_unit"]))
		node.set("android_real_interstitial_id", str(android["real_interstitial_unit"]))
	var ratings := {"G": 0, "PG": 1, "T": 2, "MA": 3}
	node.set("max_ad_content_rating", int(ratings.get(str(config.get("ads", {}).get("max_ad_content_rating", "PG")), 1)))
	node.set("remove_rewarded_ads_after_displayed", true)
	node.set("remove_interstitial_ads_after_displayed", true)


func _connect_signals() -> void:
	admob.connect("initialization_completed", _on_initialized)
	admob.connect("consent_info_updated", _on_consent_info_updated)
	admob.connect("consent_info_update_failed", _on_consent_failed)
	admob.connect("consent_form_loaded", _on_consent_form_loaded)
	admob.connect("consent_form_failed_to_load", _on_consent_failed)
	admob.connect("consent_form_dismissed", _on_consent_dismissed)
	admob.connect("rewarded_ad_loaded", _on_rewarded_loaded)
	admob.connect("rewarded_ad_failed_to_load", _on_rewarded_load_failed)
	admob.connect("rewarded_ad_user_earned_reward", _on_reward_earned)
	admob.connect("rewarded_ad_dismissed_full_screen_content", _on_rewarded_dismissed)
	admob.connect("rewarded_ad_failed_to_show_full_screen_content", _on_rewarded_show_failed)
	admob.connect("interstitial_ad_loaded", _on_interstitial_loaded)
	admob.connect("interstitial_ad_failed_to_load", _on_interstitial_load_failed)
	admob.connect("interstitial_ad_dismissed_full_screen_content", _on_interstitial_dismissed)
	admob.connect("interstitial_ad_failed_to_show_full_screen_content", _on_interstitial_show_failed)


# --- Onay ------------------------------------------------------------------------------

func request_consent() -> void:
	if _consent_started:
		return
	_consent_started = true
	_when_node_ready(func() -> void: admob.call("update_consent_info"))


func show_privacy_options() -> bool:
	if admob == null:
		return false
	_consent_started = true
	_when_node_ready(func() -> void: admob.call("update_consent_info"))
	return true


## Eklenti düğümü ağaçta ve hazır olmadan (tekil bağlanmadan) SDK çağrılamaz; kendi oluşturduğumuz düğüm hazır olunca `action` çalışır.
func _when_node_ready(action: Callable) -> void:
	if not _owns_node or admob.is_node_ready():
		action.call()
	else:
		admob.ready.connect(action, CONNECT_ONE_SHOT)


func set_personalization(allowed: bool) -> void:
	_personalization_allowed = allowed
	if admob != null:
		admob.call("set_personalization_state", 1 if allowed else 2)  # AdmobConfig.PersonalizationState.ENABLED / DISABLED
		if initialized:
			admob.call("set_request_configuration")  # başlatıldıktan sonra değişiklik SDK'ya yeniden uygulanır


func _on_consent_info_updated() -> void:
	var consent: Variant = admob.call("get_consent_status")
	var status_text := str(consent.to_status_string()) if consent != null else ""
	if status_text == CONSENT_REQUIRED and bool(admob.call("is_consent_form_available")):
		admob.call("load_consent_form")
	else:
		_finish_consent()


func _on_consent_form_loaded() -> void:
	admob.call("show_consent_form")


func _on_consent_dismissed(_error: Variant = null) -> void:
	_finish_consent()


func _on_consent_failed(_error: Variant = null) -> void:
	_finish_consent()  # onay alınamadı: reklamlar yine de başlar (SDK kendi kısıtını uygular)


## Onay adımı bitti: SDK'yı başlat (bir kez) ve onay sinyalini yay.
func _finish_consent() -> void:
	set_personalization(_personalization_allowed)
	if not initialized:
		admob.call("initialize")
	consent_finished.emit()


func _on_initialized(_status: Variant = null) -> void:
	initialized = true
	_load_rewarded()
	_load_interstitial()


# --- Ödüllü --------------------------------------------------------------------------------

func is_rewarded_ready(_placement: String) -> bool:
	return initialized and admob != null and bool(admob.call("is_rewarded_ad_loaded"))


func show_rewarded(placement: String) -> void:
	if not is_rewarded_ready(placement) or not _rewarded_placement.is_empty():
		rewarded_finished.emit.call_deferred(placement, false)
		_load_rewarded()
		return
	_rewarded_placement = placement
	_rewarded_earned = false
	admob.call("show_rewarded_ad")


func _on_reward_earned(_ad_info: Variant = null, _reward: Variant = null) -> void:
	_rewarded_earned = true


func _on_rewarded_dismissed(_ad_info: Variant = null) -> void:
	_finish_rewarded(_rewarded_earned)


func _on_rewarded_show_failed(_ad_info: Variant = null, _error: Variant = null) -> void:
	_finish_rewarded(false)


func _finish_rewarded(rewarded: bool) -> void:
	var placement := _rewarded_placement
	_rewarded_placement = ""
	_rewarded_earned = false
	if not placement.is_empty():
		rewarded_finished.emit(placement, rewarded)
	_load_rewarded()


func _load_rewarded() -> void:
	if initialized and not bool(admob.call("is_rewarded_ad_loaded")):
		admob.call("load_rewarded_ad")


func _on_rewarded_loaded(_ad_info: Variant = null, _response: Variant = null) -> void:
	_rewarded_retry = 0


func _on_rewarded_load_failed(_ad_info: Variant = null, _error: Variant = null) -> void:
	_rewarded_retry += 1
	_retry_later(_rewarded_retry, _load_rewarded)


# --- Geçiş ---------------------------------------------------------------------------------

func show_interstitial(placement: String) -> void:
	if not initialized or not bool(admob.call("is_interstitial_ad_loaded")) or not _interstitial_placement.is_empty():
		interstitial_closed.emit.call_deferred(placement)  # reklam hazır değil: oyun beklemeden devam eder
		_load_interstitial()
		return
	_interstitial_placement = placement
	admob.call("show_interstitial_ad")


func _on_interstitial_dismissed(_ad_info: Variant = null) -> void:
	_finish_interstitial()


func _on_interstitial_show_failed(_ad_info: Variant = null, _error: Variant = null) -> void:
	_finish_interstitial()


func _finish_interstitial() -> void:
	var placement := _interstitial_placement
	_interstitial_placement = ""
	if not placement.is_empty():
		interstitial_closed.emit(placement)
	_load_interstitial()


func _load_interstitial() -> void:
	if initialized and not bool(admob.call("is_interstitial_ad_loaded")):
		admob.call("load_interstitial_ad")


func _on_interstitial_loaded(_ad_info: Variant = null, _response: Variant = null) -> void:
	_interstitial_retry = 0


func _on_interstitial_load_failed(_ad_info: Variant = null, _error: Variant = null) -> void:
	_interstitial_retry += 1
	_retry_later(_interstitial_retry, _load_interstitial)


## Üstel bekleme: 20 sn, 40 sn, 80 sn... en çok 240 sn (data/ads_ids.json ads.*).
func retry_delay(attempt: int) -> float:
	var ads: Dictionary = config.get("ads", {})
	var base := float(ads.get("reload_delay_seconds", 20))
	var cap := float(ads.get("reload_max_delay_seconds", 240))
	return minf(cap, base * pow(2.0, maxf(0.0, attempt - 1.0)))


func _retry_later(attempt: int, action: Callable) -> void:
	if _tree == null:
		return
	_tree.create_timer(retry_delay(attempt)).timeout.connect(action)
