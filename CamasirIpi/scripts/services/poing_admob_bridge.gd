class_name PoingAdmobBridge
extends AdmobBridge

## Poing Studios "godot-admob-plugin" (Godot 4, Android) köprüsü.
## Eklentinin GDScript API sınıfları (MobileAds, RewardedAdLoader, InterstitialAdLoader, AdRequest,
## FullScreenContentCallback, OnUserEarnedRewardListener, UserMessagingPlatform ...) eklenti
## kurulunca `class_name` ile kaydolur. Eklenti YOKKEN bu dosya yine derlenmelidir; bu yüzden
## sınıflara adla DEĞİL, çalışma anında global sınıf listesinden bulunup dinamik çağrılır
## (`Object.call/set`). Eklenti sürümü API'yi değiştirirse yalnız bu dosya güncellenir.
## DOĞRULANMADI: gerçek eklenti bu depoda yok; adlar eklentinin README'sine göre yazıldı —
## entegrasyonda cihazda doğrulanmalı (docs/MONETIZATION.md, "Test listesi").

const REQUIRED_CLASSES: Array[StringName] = [&"MobileAds", &"AdRequest", &"RewardedAdLoader",
	&"RewardedAdLoadCallback", &"InterstitialAdLoader", &"InterstitialAdLoadCallback",
	&"FullScreenContentCallback", &"OnUserEarnedRewardListener"]
const ANDROID_OS_NAME: String = "Android"

var _rewarded_ad: Object = null
var _interstitial_ad: Object = null
## Yükleyiciler/dinleyiciler gösterim bitene dek canlı tutulur (RefCounted düşerse geri çağrı kaybolur).
var _keep_alive: Array[Object] = []


func is_present() -> bool:
	if OS.get_name() != ANDROID_OS_NAME:
		return false
	for required: StringName in REQUIRED_CLASSES:
		if _script(required) == null:
			return false
	return true


func initialize(config: Dictionary, on_done: Callable) -> void:
	var mobile_ads: GDScript = _script(&"MobileAds")
	var test_ids: Array = config.get("test_device_ids", []) as Array
	var request_configuration: Object = _new(&"RequestConfiguration")
	if request_configuration != null and not test_ids.is_empty():
		# Test cihazı: kendi cihazınızda gerçek kimlikle bile test reklamı gelir.
		request_configuration.set("test_device_ids", PackedStringArray(test_ids))
		mobile_ads.call("set_request_configuration", request_configuration)
	var listener: Object = _new(&"OnInitializationCompleteListener")
	if listener == null:
		mobile_ads.call("initialize")
		on_done.call()
		return
	listener.set("on_initialization_complete", func(_status: Variant) -> void: on_done.call())
	_keep_alive.append(listener)
	mobile_ads.call("initialize", listener)


## UMP (GDPR/ABD eyalet) onayı. Eklentinin `UserMessagingPlatform` sınıfı yoksa ya da AB dışındaysa
## onay gerekmez ve akış hemen devam eder.
func request_consent(_config: Dictionary, on_done: Callable) -> void:
	var platform: GDScript = _script(&"UserMessagingPlatform")
	var parameters: Object = _new(&"ConsentRequestParameters")
	if platform == null or parameters == null:
		on_done.call(true)
		return
	var info: Variant = platform.get("consent_information") if "consent_information" in platform else null
	if not (info is Object) or not (info as Object).has_method("update"):
		on_done.call(true)
		return
	# AB dışındaysanız formu denemek için eklentinin ConsentDebugSettings'i (debug_geography = EEA)
	# `parameters`a bağlanabilir; docs/MONETIZATION.md test listesinde anlatılır.
	var on_updated: Callable = func() -> void:
		if platform.has_method("load_and_show_consent_form_if_required"):
			platform.call("load_and_show_consent_form_if_required",
				func(_error: Variant) -> void: on_done.call(true))
		else:
			on_done.call(true)
	var on_update_failed: Callable = func(_error: Variant) -> void: on_done.call(true)
	(info as Object).call("update", parameters, on_updated, on_update_failed)


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
