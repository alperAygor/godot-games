extends TestCase

## PoingAdmobBridge: eklenti v5.1.0 sınıf adları/imzaları gerçek eklenti kaynağına karşı doğrulanır.
## Eklenti klasörü yoksa (silinmişse) sınıf kontrolleri atlanır; masaüstü davranışı yine sınanır.

var _bridge: PoingAdmobBridge = null


func before_each() -> void:
	_bridge = PoingAdmobBridge.new()


func _addon_present() -> bool:
	return _bridge._script(&"MobileAds") != null


func test_desktop_uses_own_mock_not_plugin_mock() -> void:
	assert_false(_bridge.is_present(), "masaüstünde köprü kapalı (MockAdsProvider devrede)")
	assert_false(AdmobAdsProvider.plugin_present())


func test_required_plugin_classes_resolve() -> void:
	if not _addon_present():
		return
	for class_id: StringName in PoingAdmobBridge.REQUIRED_CLASSES:
		assert_not_null(_bridge._script(class_id), String(class_id))
	for extra: StringName in [&"UserMessagingPlatform", &"ConsentRequestParameters",
			&"ConsentDebugSettings", &"RequestConfiguration", &"ConsentInformation"]:
		assert_not_null(_bridge._script(extra), String(extra))


func test_ump_consent_information_is_reachable() -> void:
	if not _addon_present():
		return
	var platform: GDScript = _bridge._script(&"UserMessagingPlatform")
	var info: Variant = platform.get("consent_information")
	assert_true(info is Object and (info as Object).has_method("update"))
	assert_true((info as Object).has_method("get_is_consent_form_available"))
	assert_true((info as Object).has_method("get_consent_status"))
	assert_true(platform.has_method("load_consent_form"))
	assert_eq(_bridge._consent_required_value(), 2, "ConsentStatus.REQUIRED")


func test_request_configuration_accepts_typed_test_ids() -> void:
	var ids: Array[String] = _bridge._test_device_ids({"test_device_ids": ["ABC", " ", "DEF"]})
	assert_eq(ids.size(), 2, "boş girdi atılır")
	if not _addon_present():
		return
	var configuration: Object = _bridge._new(&"RequestConfiguration")
	configuration.set("test_device_ids", ids)
	assert_eq((configuration.get("test_device_ids") as Array).size(), 2)


func test_consent_debug_geography_only_when_configured() -> void:
	assert_true(_bridge._consent_debug_settings({}) == null)
	assert_true(_bridge._consent_debug_settings({"consent_debug_geography": "mars"}) == null)
	if not _addon_present() or not OS.is_debug_build():
		return
	var settings: Object = _bridge._consent_debug_settings({"consent_debug_geography": "EEA"})
	assert_eq(int(settings.get("debug_geography")), 1, "DebugGeography.Values.EEA")


func test_load_without_native_plugin_does_not_hang() -> void:
	# Masaüstünde eklenti kapalı; yine de çağrılırsa çökmemeli. Yükleyici yoksa "no_plugin" döner.
	var failures: Array[String] = []
	if _addon_present():
		return
	_bridge.load_rewarded("x", func() -> void: pass, func(reason: String) -> void: failures.append(reason))
	assert_eq(failures, ["no_plugin"] as Array[String])
