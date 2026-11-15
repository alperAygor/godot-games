extends TestCase
## PoingAdmobBridge: masaüstünde kapalı kalır; eklenti (yalnız Android + yerel tekil nesneler) yokken hiçbir şeyi bozmaz.
## Eklenti projeye eklenmedi (A1 görevi); sınıf adı doğrulamaları eklenti varsa çalışır, yoksa atlanır.

func _bridge() -> PoingAdmobBridge:
	return PoingAdmobBridge.new()

func _addon_present(b: PoingAdmobBridge) -> bool:
	return b._script(&"MobileAds") != null

func test_desktop_bridge_inactive_and_plugin_absent() -> void:
	check(not _bridge().is_present(), "masaüstünde köprü kapalı (MockAdsProvider devrede)")
	check(not AdmobAdsProvider.plugin_present(), "eklenti yok")

func test_inactive_bridge_never_hangs() -> void:
	var b := _bridge()
	if _addon_present(b):
		return
	var out: Array = []
	b.load_rewarded("x", func() -> void: pass, func(r: String) -> void: out.append(r))
	b.load_interstitial("x", func() -> void: pass, func(r: String) -> void: out.append(r))
	eq(out, ["no_plugin", "no_plugin"], "yükleyici yoksa no_plugin")
	var consent: Array = []
	b.request_consent({}, func(can: bool) -> void: consent.append(can))
	eq(consent, [true], "UMP tekil nesnesi yoksa onay adımı atlanır")
	check(not b.privacy_options_required(), "gizlilik formu: doğrulanana dek gizli")

func test_test_device_ids_are_typed_and_trimmed() -> void:
	var ids: Array[String] = _bridge()._test_device_ids({"test_device_ids": ["ABC", " ", "DEF"]})
	eq(ids.size(), 2, "boş girdi atılır")

func test_consent_debug_geography_only_when_configured() -> void:
	var b := _bridge()
	check(b._consent_debug_settings({}) == null, "ayar yok")
	check(b._consent_debug_settings({"consent_debug_geography": "mars"}) == null, "bilinmeyen bölge")
