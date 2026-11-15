class_name AdMobAdsProvider
extends AdsProvider
## Gerçek AdMob sağlayıcısı (godot-sdk-integrations/godot-admob v7.0 eklentisini sarar). Oyun kodu yalnızca `Ads` autoload'unu bilir.
## - Reklam kimlikleri data/ads_ids.json'dan: mode=test iken Google'ın herkese açık TEST kimlikleri (eklentinin debug alanları).
## - Ödüllü ve geçiş reklamı önceden yüklenir; gösterilince bir sonraki yüklenir. Yükleme hatasında üstel beklemeyle yeniden denenir.
## - Ödül yalnızca `rewarded_ad_user_earned_reward` gelirse verilir; kapatılırsa/başarısız olursa `rewarded=false`.
## - Onay: UMP (update_consent_info -> gerekiyorsa form) bitmeden SDK başlatılmaz. UMP gerekmeyen bölgede (NOTICE rejimi) SDK, oyunun kısa bilgi
##   penceresi yanıtlanana kadar da bekler (`set_notice_answered`). Bkz. ConsentFlow.
## - Yapılandırma: mode=real iken kimlik eksik/test ise SDK HİÇ başlatılmaz ve hata yazılır (sessizce test'e düşmez); bkz. AdsConfig.
## - Zaman aşımı: gösterilen ödüllü/geçiş reklamı hiç kapanmazsa (`ads.show_timeout_seconds`) sağlayıcı kendini sıfırlar; oyun takılmaz.
## `admob` bir Admob düğümü ya da aynı sinyal/metotlara sahip sahte nesne olabilir (testler); verilmezse oluşturulur ve ağaca eklenir.

const CONSENT_REQUIRED := "REQUIRED"

## Yapılandırma hatası günlüğü. Varsayılan: yayın sürümünde push_error (yüksek sesle), hata ayıklamada push_warning.
## Testler `initialize()`'dan önce bunu değiştirir (verify.sh `ERROR:` satırlarını başarısızlık sayar).
var problem_logger: Callable = Callable()

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
var _blocked := false
var _regime := ConsentFlow.REGIME_UNKNOWN
var _notice_answered := false
var _sdk_started := false
var _rewarded_token := 0
var _interstitial_token := 0
## Saniye; testlerde kısaltılır. <= 0 ise ads_ids.json `ads.show_timeout_seconds`.
var show_timeout_override := -1.0


func _init(ids_config: Dictionary = {}, existing_node: Node = null) -> void:
	config = ids_config if not ids_config.is_empty() else JsonIO.read_dict("res://data/ads_ids.json")
	admob = existing_node


## Gerçek kimlikler kullanılacak mı: mode=real VE kimlikler tam/geçerli. mode=real ama eksikse sessizce test'e DÜŞMEZ: `config_problem()` dolar, SDK başlamaz.
func uses_real_ids() -> bool:
	return AdsConfig.is_real(config)


func config_problem() -> String:
	return AdsConfig.problem(config)


func consent_regime() -> String:
	return ConsentFlow.REGIME_NONE if _blocked else _regime


func initialize() -> void:
	_tree = Engine.get_main_loop() as SceneTree
	var problem := config_problem()
	if not problem.is_empty():
		_blocked = true
		_report_problem("AdMob yapılandırma hatası (%s): data/ads_ids.json mode=%s. Reklam SDK'sı BAŞLATILMADI; test kimliğine düşülmedi." % [problem, str(config.get("mode", "?"))])
		return
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
	if _blocked:
		consent_finished.emit.call_deferred()  # SDK yok: bekleyen kimse kalmasın
		return
	if _consent_started:
		return
	_consent_started = true
	_when_node_ready(func() -> void: admob.call("update_consent_info"))


## Ayarlar > "Gizlilik seçenekleri" (UMP rejimi): eklenti v7.0 UMP'nin "gizlilik seçenekleri formu" API'sini sunmaz; bu yüzden kayıtlı onay
## sıfırlanıp form yeniden istenir (kullanıcı kararını yeniden verir). NOTICE rejiminde false döner: oyunun kendi penceresi tercihi sorar.
func show_privacy_options() -> bool:
	if admob == null or _blocked or _regime != ConsentFlow.REGIME_FORM:
		return false
	_consent_started = true
	_when_node_ready(func() -> void:
		admob.call("reset_consent_info")
		admob.call("update_consent_info"))
	return true


func set_notice_answered(answered: bool) -> void:
	_notice_answered = answered
	_maybe_start_sdk()


## Eklenti düğümü ağaçta ve hazır olmadan (tekil bağlanmadan) SDK çağrılamaz; kendi oluşturduğumuz düğüm hazır olunca `action` çalışır.
func _when_node_ready(action: Callable) -> void:
	if not _owns_node or admob.is_node_ready():
		action.call()
	else:
		admob.ready.connect(action, CONNECT_ONE_SHOT)


func set_personalization(allowed: bool) -> void:
	_personalization_allowed = allowed
	if admob != null and not _blocked:
		var effective := ConsentFlow.personalization_for(_regime, allowed)  # UMP rejiminde karar UMP'nindir
		admob.call("set_personalization_state", 1 if effective else 2)  # AdmobConfig.PersonalizationState.ENABLED / DISABLED
		if initialized:
			admob.call("set_request_configuration")  # başlatıldıktan sonra değişiklik SDK'ya yeniden uygulanır


func _on_consent_info_updated() -> void:
	var consent: Variant = admob.call("get_consent_status")
	var status_text := str(consent.to_status_string()) if consent != null else ""
	_regime = ConsentFlow.regime_for_status(status_text)
	if status_text == CONSENT_REQUIRED and bool(admob.call("is_consent_form_available")):
		admob.call("load_consent_form")
	else:
		_finish_consent()


func _on_consent_form_loaded() -> void:
	admob.call("show_consent_form")


func _on_consent_dismissed(_error: Variant = null) -> void:
	_finish_consent()


func _on_consent_failed(_error: Variant = null) -> void:
	# UMP yanıt vermedi (ağ yok vb.): bölge bilinemedi. Dürüst varsayılan: oyunun bilgi penceresi; SDK kendi kısıtını (onaysız kişiselleştirme yok) uygular.
	if _regime == ConsentFlow.REGIME_UNKNOWN:
		_regime = ConsentFlow.REGIME_NOTICE
	_finish_consent()


## Onay adımı bitti: kişiselleştirmeyi uygula, onay sinyalini yay, SDK'yı (koşullar tamamsa, bir kez) başlat.
func _finish_consent() -> void:
	set_personalization(_personalization_allowed)
	consent_finished.emit()
	_maybe_start_sdk()


## SDK başlatma TEK yerde: onay çözülmüş ve ConsentFlow izin veriyorsa.
func _maybe_start_sdk() -> void:
	if _blocked or admob == null or initialized or _sdk_started:
		return
	if not ConsentFlow.sdk_may_start(_regime, _notice_answered):
		return
	_sdk_started = true
	admob.call("initialize")


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
	_arm_watchdog(true)


func _on_reward_earned(_ad_info: Variant = null, _reward: Variant = null) -> void:
	_rewarded_earned = true


func _on_rewarded_dismissed(_ad_info: Variant = null) -> void:
	_finish_rewarded(_rewarded_earned)


func _on_rewarded_show_failed(_ad_info: Variant = null, _error: Variant = null) -> void:
	_finish_rewarded(false)


func _finish_rewarded(rewarded: bool) -> void:
	_rewarded_token += 1
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
	_arm_watchdog(false)


func _on_interstitial_dismissed(_ad_info: Variant = null) -> void:
	_finish_interstitial()


func _on_interstitial_show_failed(_ad_info: Variant = null, _error: Variant = null) -> void:
	_finish_interstitial()


func _finish_interstitial() -> void:
	_interstitial_token += 1
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


# --- Zaman aşımı ve günlük -----------------------------------------------------------------

func show_timeout() -> float:
	if show_timeout_override > 0.0:
		return show_timeout_override
	return float((config.get("ads", {}) as Dictionary).get("show_timeout_seconds", 120))


## Gösterilen reklam hiç kapanmazsa (SDK takıldı) durumu sıfırlar: ödüllü "ödülsüz" biter, geçiş "kapandı" sayılır.
func _arm_watchdog(rewarded: bool) -> void:
	if _tree == null:
		return
	var token := _rewarded_token if rewarded else _interstitial_token
	_tree.create_timer(show_timeout(), true, false, true).timeout.connect(func() -> void:
		if rewarded and token == _rewarded_token and not _rewarded_placement.is_empty():
			_finish_rewarded(false)
		elif not rewarded and token == _interstitial_token and not _interstitial_placement.is_empty():
			_finish_interstitial())


func _report_problem(message: String) -> void:
	if problem_logger.is_valid():
		problem_logger.call(message)
	elif OS.is_debug_build():
		push_warning(message)
	else:
		push_error(message)
