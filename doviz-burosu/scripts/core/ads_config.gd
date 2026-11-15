class_name AdsConfig
extends RefCounted
## Reklam yapılandırması denetimi (saf, testli). `data/ads_ids.json` içeriğini alır.
## Kural: "real" kipi ASLA sessizce test kimliğine düşmez. Kimlikler eksik/test ise `problem()` bir kod döner; çağıran
## (Monetization) reklam SDK'sını hiç başlatmaz ve yüksek sesle hata yazar. Yayın kapısı (tools/release_guard.gd) aynı koşulları denetler.

const GOOGLE_TEST_PUBLISHER := "ca-app-pub-3940256099942544"
const REAL_KEYS: Array[String] = ["real_app_id", "real_rewarded_unit", "real_interstitial_unit"]

const PROBLEM_NONE := ""
const PROBLEM_BAD_MODE := "mode_unknown"
const PROBLEM_REAL_INCOMPLETE := "real_ids_incomplete"
const PROBLEM_REAL_IS_TEST := "real_id_is_google_test_id"
const PROBLEM_TEST_IDS_MISSING := "test_ids_missing"

## Gizlilik politikası adresi yer tutucu mu? Yayın kapısı da aynı işareti (`example.`) kullanır.
const PLACEHOLDER_MARKER := "example."


## "" = sorun yok. mode=test iken test kimlikleri dolu olmalı; mode=real iken üç gerçek kimlik dolu ve Google test kimliği olmamalı.
static func problem(config: Dictionary) -> String:
	var mode := str(config.get("mode", "test"))
	var android: Dictionary = config.get("android", {}) as Dictionary
	if mode == "test":
		for key: String in ["test_app_id", "test_rewarded_unit", "test_interstitial_unit"]:
			if str(android.get(key, "")).strip_edges().is_empty():
				return PROBLEM_TEST_IDS_MISSING
		return PROBLEM_NONE
	if mode != "real":
		return PROBLEM_BAD_MODE
	for key: String in REAL_KEYS:
		var value := str(android.get(key, "")).strip_edges()
		if value.is_empty():
			return PROBLEM_REAL_INCOMPLETE
		if value.contains(GOOGLE_TEST_PUBLISHER):
			return PROBLEM_REAL_IS_TEST
	return PROBLEM_NONE


## Gerçek kimlikler kullanılacak mı: mode=real VE sorun yok.
static func is_real(config: Dictionary) -> bool:
	return str(config.get("mode", "test")) == "real" and problem(config) == PROBLEM_NONE


## Gizlilik politikası bağlantısı oyuncuya gösterilsin mi? Boş, https olmayan ya da (yayın sürümünde) yer tutucu ise hayır.
static func policy_url_visible(url: String, release_build: bool) -> bool:
	var clean := url.strip_edges()
	if clean.is_empty() or not clean.begins_with("https://"):
		return false
	return not (release_build and clean.contains(PLACEHOLDER_MARKER))
