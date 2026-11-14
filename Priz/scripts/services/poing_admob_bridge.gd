class_name PoingAdmobBridge
extends AdmobBridge

## Poing Studios "godot-admob-plugin" v5.1.0 (Godot 4, Android) köprüsü.
## Eklentinin GDScript API sınıfları (MobileAds, RewardedAdLoader, InterstitialAdLoader, AdRequest,
## FullScreenContentCallback, OnUserEarnedRewardListener, UserMessagingPlatform ...) eklenti
## `res://addons/admob/` altında olunca `class_name` ile kaydolur. Eklenti YOKKEN bu dosya yine
## derlenmelidir; bu yüzden sınıflara adla DEĞİL, çalışma anında global sınıf listesinden bulunup
## dinamik çağrılır (`Object.call/set/get`). Eklenti sürümü API'yi değiştirirse yalnız bu dosya güncellenir.
## DOĞRULAMA: adlar/imzalar eklenti v5.1.0 KAYNAĞINDAN satır satır doğrulandı (gdscript/src/api, /ump).
## Cihazda (gerçek native tekil nesnelerle) çalıştırılması hâlâ gerekir: docs/MONETIZATION.md "Test listesi".
## Masaüstünde `is_present()` false döner; oyun kendi MockAdsProvider'ını kullanır (eklentinin editör
## mock'u 8 sn'lik gerçek zamanlı bir sahte reklam penceresi açar, bu yüzden probe/test için belirsizdir).

const REQUIRED_CLASSES: Array[StringName] = [&"MobileAds", &"AdRequest", &"RewardedAdLoader",
	&"RewardedAdLoadCallback", &"InterstitialAdLoader", &"InterstitialAdLoadCallback",
	&"FullScreenContentCallback", &"OnUserEarnedRewardListener"]
const ANDROID_OS_NAME: String = "Android"
## Eklentinin Android'de kaydettiği native tekil nesneler (export eklentisi + AAR'lar doğru kurulduysa vardır).
const REQUIRED_SINGLETONS: Array[String] = ["PoingGodotAdMob", "PoingGodotAdMobRewardedAd",
	"PoingGodotAdMobInterstitialAd"]
## UMP tekil nesneleri; yoksa onay adımı atlanır (reklamlar yine başlar).
const CONSENT_SINGLETONS: Array[String] = ["PoingGodotAdMobUserMessagingPlatform", "PoingGodotAdMobConsentInformation"]
## ConsentInformation.ConsentStatus.REQUIRED (sabit haritası okunamazsa yedek değer).
const CONSENT_STATUS_REQUIRED_FALLBACK: int = 2
## DebugGeography.Values eşlemesi (yalnız hata ayıklama sürümünde `consent_debug_geography` ile).
const DEBUG_GEOGRAPHY: Dictionary = {"eea": 1, "not_eea": 2}

var _rewarded_ad: Object = null
var _interstitial_ad: Object = null
## Yükleyiciler/dinleyiciler gösterim bitene dek canlı tutulur (RefCounted düşerse geri çağrı kaybolur).
var _keep_alive: Array[Object] = []


func is_present() -> bool:
	if OS.get_name() != ANDROID_OS_NAME:
		return false
	for singleton: String in REQUIRED_SINGLETONS:
		if not Engine.has_singleton(singleton):
			return false
	for required: StringName in REQUIRED_CLASSES:
		if _script(required) == null:
			return false
	return true


func initialize(config: Dictionary, on_done: Callable) -> void:
	var mobile_ads: GDScript = _script(&"MobileAds")
	if mobile_ads == null:
		on_done.call()
		return
	var request_configuration: Object = _new(&"RequestConfiguration")
	if request_configuration != null:
		# Test cihazı: kendi cihazınızda gerçek kimlikle bile test reklamı gelir.
		# `RequestConfiguration.test_device_ids` türlü bir Array[String]'dir (PackedStringArray atanamaz).
		var ids: Array[String] = _test_device_ids(config)
		request_configuration.set("test_device_ids", ids)
		mobile_ads.call("set_request_configuration", request_configuration)
	var listener: Object = _new(&"OnInitializationCompleteListener")
	if listener == null:
		mobile_ads.call("initialize")
		on_done.call()
		return
	listener.set("on_initialization_complete", func(_status: Variant) -> void: on_done.call())
	_keep_alive.append(listener)
	mobile_ads.call("initialize", listener)


## UMP (GDPR/ABD eyalet) onayı. Eklenti akışı (v5.1.0 örnek `Ump.gd`):
## `UserMessagingPlatform.consent_information.update(params, ok, fail)` -> form uygunsa
## `UserMessagingPlatform.load_consent_form(ok, fail)` -> durum REQUIRED ise `form.show(dismissed)`.
## Her yol (hata, uygun değil, kapatıldı) `on_done`a düşer; eklenti/native yoksa hemen devam eder.
func request_consent(config: Dictionary, on_done: Callable) -> void:
	for singleton: String in CONSENT_SINGLETONS:
		if not Engine.has_singleton(singleton):
			on_done.call(true)
			return
	var platform: GDScript = _script(&"UserMessagingPlatform")
	var parameters: Object = _new(&"ConsentRequestParameters")
	if platform == null or parameters == null:
		on_done.call(true)
		return
	var info: Variant = platform.get("consent_information")
	if not (info is Object) or not (info as Object).has_method("update"):
		on_done.call(true)
		return
	var debug_settings: Object = _consent_debug_settings(config)
	if debug_settings != null:
		parameters.set("consent_debug_settings", debug_settings)
	var finish: Callable = func(_error: Variant = null) -> void: on_done.call(true)
	var on_form_loaded: Callable = func(form: Object) -> void:
		if form != null and int((info as Object).call("get_consent_status")) == _consent_required_value():
			form.call("show", finish)
		else:
			on_done.call(true)
	var on_updated: Callable = func() -> void:
		if bool((info as Object).call("get_is_consent_form_available")):
			platform.call("load_consent_form", on_form_loaded, finish)
		else:
			on_done.call(true)
	(info as Object).call("update", parameters, on_updated, finish)


func load_rewarded(unit_id: String, on_loaded: Callable, on_failed: Callable) -> void:
	var loader: Object = _new(&"RewardedAdLoader")
	var callback: Object = _new(&"RewardedAdLoadCallback")
	if loader == null or callback == null:
		on_failed.call("no_plugin")
		return
	callback.set("on_ad_loaded", func(ad: Object) -> void:
		_rewarded_ad = ad
		on_loaded.call())
	callback.set("on_ad_failed_to_load", func(error: Variant) -> void: on_failed.call(_error_text(error)))
	_keep_alive.append(callback)
	loader.call("load", unit_id, _new(&"AdRequest"), callback)


func load_interstitial(unit_id: String, on_loaded: Callable, on_failed: Callable) -> void:
	var loader: Object = _new(&"InterstitialAdLoader")
	var callback: Object = _new(&"InterstitialAdLoadCallback")
	if loader == null or callback == null:
		on_failed.call("no_plugin")
		return
	callback.set("on_ad_loaded", func(ad: Object) -> void:
		_interstitial_ad = ad
		on_loaded.call())
	callback.set("on_ad_failed_to_load", func(error: Variant) -> void: on_failed.call(_error_text(error)))
	_keep_alive.append(callback)
	loader.call("load", unit_id, _new(&"AdRequest"), callback)


func show_rewarded(on_shown: Callable, on_earned: Callable, on_dismissed: Callable, on_failed: Callable) -> void:
	var ad: Object = _rewarded_ad
	_rewarded_ad = null
	if ad == null:
		on_failed.call("not_loaded")
		return
	ad.set("full_screen_content_callback", _content_callback(ad, on_shown, on_dismissed, on_failed))
	var reward_listener: Object = _new(&"OnUserEarnedRewardListener")
	reward_listener.set("on_user_earned_reward", func(_item: Variant) -> void: on_earned.call())
	_keep_alive.append(reward_listener)
	ad.call("show", reward_listener)


func show_interstitial(on_shown: Callable, on_dismissed: Callable, on_failed: Callable) -> void:
	var ad: Object = _interstitial_ad
	_interstitial_ad = null
	if ad == null:
		on_failed.call("not_loaded")
		return
	ad.set("full_screen_content_callback", _content_callback(ad, on_shown, on_dismissed, on_failed))
	ad.call("show")


func _content_callback(ad: Object, on_shown: Callable, on_dismissed: Callable, on_failed: Callable) -> Object:
	var callback: Object = _new(&"FullScreenContentCallback")
	callback.set("on_ad_showed_full_screen_content", func() -> void: on_shown.call())
	callback.set("on_ad_dismissed_full_screen_content", func() -> void:
		_release(ad)
		on_dismissed.call())
	callback.set("on_ad_failed_to_show_full_screen_content", func(error: Variant) -> void:
		_release(ad)
		on_failed.call(_error_text(error)))
	_keep_alive.append(callback)
	return callback


## Kullanılmış reklam nesnesi bırakılır (eklenti `destroy` sunuyorsa çağrılır) ve canlı tutma listesi budanır.
func _release(ad: Object) -> void:
	if ad != null and ad.has_method("destroy"):
		ad.call("destroy")
	if _keep_alive.size() > 16:
		_keep_alive = _keep_alive.slice(_keep_alive.size() - 8)


## `admob.test_device_ids` -> Array[String] (boş girdiler atılır).
func _test_device_ids(config: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for entry: Variant in config.get("test_device_ids", []) as Array:
		var text: String = String(entry).strip_edges()
		if not text.is_empty():
			ids.append(text)
	return ids


## Yalnız hata ayıklama sürümünde ve `consent_debug_geography` ("eea"/"not_eea") verildiyse UMP
## hata ayıklama ayarı; AB dışındaki bir cihazda formu denemek içindir.
func _consent_debug_settings(config: Dictionary) -> Object:
	var geography: String = String(config.get("consent_debug_geography", "")).to_lower()
	if not OS.is_debug_build() or not DEBUG_GEOGRAPHY.has(geography):
		return null
	var settings: Object = _new(&"ConsentDebugSettings")
	if settings == null:
		return null
	settings.set("debug_geography", int(DEBUG_GEOGRAPHY[geography]))
	settings.set("test_device_hashed_ids", _test_device_ids(config))
	return settings


func _consent_required_value() -> int:
	var info_script: GDScript = _script(&"ConsentInformation")
	if info_script != null:
		var statuses: Variant = info_script.get_script_constant_map().get("ConsentStatus")
		if statuses is Dictionary and (statuses as Dictionary).has("REQUIRED"):
			return int((statuses as Dictionary)["REQUIRED"])
	return CONSENT_STATUS_REQUIRED_FALLBACK


func _error_text(error: Variant) -> String:
	if error is Object and "message" in (error as Object):
		return String((error as Object).get("message"))
	return "error"


## Global sınıf listesinden betiği bulur (eklenti yoksa null).
func _script(class_id: StringName) -> GDScript:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if StringName(String(entry.get("class", ""))) == class_id:
			return load(String(entry.get("path", ""))) as GDScript
	return null


func _new(class_id: StringName) -> Object:
	var script: GDScript = _script(class_id)
	return script.new() as Object if script != null else null
