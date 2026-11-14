class_name AdmobAdsProvider
extends AdsProvider

## Google AdMob sağlayıcısı: durum makinesi burada, eklenti çağrıları `AdmobBridge`de.
## Davranış:
##  * Açılışta (isteğe bağlı) UMP onayı -> MobileAds başlatma -> ödüllü + geçiş reklamı ÖN YÜKLENİR.
##  * Her gösterimden sonra bir sonraki reklam hemen yüklenir.
##  * Yükleme hatasında `load_retry_seconds` sonra yeniden denenir; yüklü değilse `is_ready` false
##    olur, yani oyun reklam düğmesini hiç sunmaz / geçişte reklamsız devam eder (asla takılmaz).
## Kimlikler `data/ads.json` -> "admob"; varsayılan Google TEST kimlikleridir.

const CONFIG_PATH: String = "res://data/ads.json"
const MODE_PRODUCTION: String = "production"
const PLACEHOLDER_PREFIX: String = "REPLACE_"
## ads.json okunamazsa kullanılan Google TEST kimlikleri.
const TEST_IDS: Dictionary = {
	"app_id": "ca-app-pub-3940256099942544~3347511713",
	"rewarded_unit_id": "ca-app-pub-3940256099942544/5224354917",
	"interstitial_unit_id": "ca-app-pub-3940256099942544/1033173712",
}
const DEFAULT_RETRY_SECONDS: float = 20.0
const DEFAULT_CONSENT_TIMEOUT: float = 8.0

var bridge: AdmobBridge = null
var rewarded_unit_id: String = ""
var interstitial_unit_id: String = ""

var _config: Dictionary = {}
var _tree: SceneTree = null
var _initialized: bool = false
var _rewarded_ready: bool = false
var _interstitial_ready: bool = false
var _rewarded_loading: bool = false
var _interstitial_loading: bool = false
var _earned: bool = false
var _showing: bool = false
var _consent_done: bool = false
var _generation: int = 0


func _init(admob_bridge: AdmobBridge = null, config: Dictionary = {}, debug_build: bool = OS.is_debug_build()) -> void:
	bridge = admob_bridge if admob_bridge != null else PoingAdmobBridge.new()
	_config = config.duplicate(true) if not config.is_empty() else load_admob_config()
	var ids: Dictionary = resolve_ids(_config, debug_build)
	rewarded_unit_id = String(ids["rewarded_unit_id"])
	interstitial_unit_id = String(ids["interstitial_unit_id"])
	_config["app_id"] = ids["app_id"]


## Eklenti çalışma anında var mı (yoksa AdManager mock'a/boş sağlayıcıya düşer).
static func plugin_present() -> bool:
	return PoingAdmobBridge.new().is_present()


static func load_admob_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return {"mode": "test", "test": TEST_IDS.duplicate()}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if parsed is Dictionary and (parsed as Dictionary).get("admob") is Dictionary:
		return ((parsed as Dictionary)["admob"] as Dictionary).duplicate(true)
	return {"mode": "test", "test": TEST_IDS.duplicate()}


## Kimlik seçimi: üretim kimlikleri YALNIZ yayın sürümünde, mode=production iken ve hiçbir alan
## yer tutucu (REPLACE_*) değilken kullanılır; aksi halde Google test kimlikleri (yanlışlıkla
## gerçek reklamı kendine tıklamak hesap yasağı sebebidir).
static func resolve_ids(config: Dictionary, debug_build: bool) -> Dictionary:
	var test_ids: Dictionary = TEST_IDS.duplicate()
	var configured_test: Variant = config.get("test")
	if configured_test is Dictionary:
		test_ids.merge(configured_test as Dictionary, true)
	var production: Variant = config.get("production")
	if debug_build or String(config.get("mode", "test")) != MODE_PRODUCTION or not (production is Dictionary):
		return test_ids
	for key: String in TEST_IDS.keys():
		var value: String = String((production as Dictionary).get(key, ""))
		if value.is_empty() or value.begins_with(PLACEHOLDER_PREFIX):
			return test_ids
	return (production as Dictionary).duplicate()


func initialize() -> void:
	_tree = Engine.get_main_loop() as SceneTree
	if not bridge.is_present():
		return
	_generation += 1
	if bool(_config.get("request_consent", true)):
		_start_consent(_generation)
	else:
		_consent_done = true
		_start_sdk()


func is_ready(placement: int) -> bool:
	if not _initialized or _showing:
		return false
	return _interstitial_ready if placement == INTERSTITIAL_PLACEMENT else _rewarded_ready


func preload_ads() -> void:
	if not _initialized:
		return
	_load_rewarded()
	_load_interstitial()


func show(placement: int) -> void:
	if not is_ready(placement):
		preload_ads()
		failed.emit("not_ready")
		return
	_showing = true
	_earned = false
	if placement == INTERSTITIAL_PLACEMENT:
		_interstitial_ready = false
		bridge.show_interstitial(_on_shown, _on_interstitial_dismissed, _on_show_failed)
	else:
		_rewarded_ready = false
		bridge.show_rewarded(_on_shown, _on_earned, _on_rewarded_dismissed, _on_show_failed)


# --- Başlatma ------------------------------------------------------------------------------

func _start_consent(generation: int) -> void:
	bridge.request_consent(_config, func(_can_request: bool) -> void: _on_consent_done(generation))
	# Onay formu hiç yanıt vermezse (eklenti hatası) reklamlar yine de başlatılır: oyun takılmaz.
	if _tree != null:
		var timeout: float = float(_config.get("consent_timeout_seconds", DEFAULT_CONSENT_TIMEOUT))
		_tree.create_timer(timeout, true, false, true).timeout.connect(_on_consent_done.bind(generation))


func _on_consent_done(generation: int) -> void:
	if generation != _generation or _consent_done:
		return
	_consent_done = true
	_start_sdk()


func _start_sdk() -> void:
	bridge.initialize(_config, _on_sdk_ready)


func _on_sdk_ready() -> void:
	if _initialized:
		return
	_initialized = true
	preload_ads()


# --- Yükleme -------------------------------------------------------------------------------

func _load_rewarded() -> void:
	if _rewarded_ready or _rewarded_loading:
		return
	_rewarded_loading = true
	bridge.load_rewarded(rewarded_unit_id, _on_rewarded_loaded, _on_rewarded_load_failed)


func _load_interstitial() -> void:
	if _interstitial_ready or _interstitial_loading:
		return
	_interstitial_loading = true
	bridge.load_interstitial(interstitial_unit_id, _on_interstitial_loaded, _on_interstitial_load_failed)


func _on_rewarded_loaded() -> void:
	_rewarded_loading = false
	_rewarded_ready = true


func _on_interstitial_loaded() -> void:
	_interstitial_loading = false
	_interstitial_ready = true


func _on_rewarded_load_failed(_reason: String) -> void:
	_rewarded_loading = false
	_schedule_retry(_load_rewarded)


func _on_interstitial_load_failed(_reason: String) -> void:
	_interstitial_loading = false
	_schedule_retry(_load_interstitial)


func _schedule_retry(action: Callable) -> void:
	if _tree == null:
		return
	var delay: float = float(_config.get("load_retry_seconds", DEFAULT_RETRY_SECONDS))
	_tree.create_timer(delay, true, false, true).timeout.connect(action)


# --- Gösterim sonuçları --------------------------------------------------------------------

func _on_shown() -> void:
	shown.emit()


func _on_earned() -> void:
	_earned = true


func _on_rewarded_dismissed() -> void:
	_showing = false
	var earned: bool = _earned
	_earned = false
	# Sonraki reklam hemen hazırlanır; oyuncu bir sonraki fırsatta bekletilmez.
	_load_rewarded()
	if earned:
		rewarded.emit()
	else:
		failed.emit("dismissed_early")


func _on_interstitial_dismissed() -> void:
	_showing = false
	_load_interstitial()
	dismissed.emit()


func _on_show_failed(reason: String) -> void:
	_showing = false
	_earned = false
	preload_ads()
	failed.emit(reason)
