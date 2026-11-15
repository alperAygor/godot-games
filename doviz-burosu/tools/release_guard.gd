class_name ReleaseGuard
extends RefCounted

## Yayın kapısı — SAF fonksiyonlar (dosya/sahne yok). Üretim (Play) paketinin; yer tutucu paket adıyla, test reklam
## kimlikleriyle, hata ayıklama imzasıyla, artırılmamış sürüm koduyla, gizlilik URL'si olmadan alınmasını engeller.
## `tools/release_check.gd` yapılandırmayı toplayıp `check()` / `check_artifact()` çağırır; `tools/release_build.sh`
## bunlar geçmeden AAB üretmez. Çekirdek oyun koduna girmez (tools/ export'a dahil değildir).
## `check()` hata kodlarının listesini döndürür; boş liste = geçti. `describe()` her kodu bir cümleyle açıklar.
##
## Girdi sözlüğü (`config`); eksik alan "bilinmiyor" sayılır ve hata verir:
##   ads_mode ("test"|"real"), ads_real {app_id, rewarded_unit, interstitial_unit} (data/ads_ids.json android.real_*),
##   admob_cfg_is_real (bool), admob_cfg_release_app_id (addons/AdmobPlugin/android_export.cfg [Release] app_id),
##   play_billing (bool; data/ads_ids.json providers.play_billing),
##   application_id, version_code, version_name, project_version (project.godot config/version),
##   last_uploaded_version_code, target_sdk, min_sdk, export_format (0 apk, 1 aab), architectures (Array),
##   permissions (Array, preset), debug_signing (bool), signing_secrets_in_preset (bool),
##   release_keystore_ready (bool), privacy_policy_url.

const GOOGLE_TEST_PUBLISHER: String = "ca-app-pub-3940256099942544"
const APP_ID_PATTERN: String = "^ca-app-pub-[0-9]{16}~[0-9]{10}$"
const UNIT_ID_PATTERN: String = "^ca-app-pub-[0-9]{16}/[0-9]{10}$"
## Android paket adı: en az iki parça, her parça harfle başlar, küçük harf/rakam/alt çizgi.
const PACKAGE_PATTERN: String = "^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$"
## Yayın paketine hiç yakışmayan paket adı önekleri/sonekleri.
const PLACEHOLDER_PACKAGES: Array[String] = ["com.godot.game", "org.godotengine", "com.example", "com.android"]
const PLACEHOLDER_PACKAGE_SUFFIXES: Array[String] = [".test", ".debug", ".dev", ".example"]
const MIN_TARGET_SDK: int = 36
const MIN_MIN_SDK: int = 24
const ALIGN_16K: int = 16384
const ALLOWED_ABIS: Array[String] = ["arm64-v8a"]
## Oyunun kendisinin istediği izinler (preset) — yayında bunlar MUTLAKA bulunur.
const REQUIRED_PERMISSIONS: Array[String] = [
	"android.permission.INTERNET",
	"android.permission.ACCESS_NETWORK_STATE",
	"android.permission.VIBRATE",
]
## Birleşik manifestte izin verilen izinler. Kaynakları (build/release debug AAB, 2026-11-15, T-R1 raporu):
##  * INTERNET, ACCESS_NETWORK_STATE, VIBRATE: preset (Feel.haptic -> Input.vibrate_handheld),
##  * AD_ID (android.permission + com.google.android.gms.permission), ACCESS_ADSERVICES_AD_ID/ATTRIBUTION/TOPICS:
##    AdMob eklentisi + Google Mobile Ads SDK (Play "Reklam kimliği" beyanı gerekir),
##  * WAKE_LOCK + FOREGROUND_SERVICE: androidx.work (reklam SDK'sının geçişli bağımlılığı),
##  * com.android.vending.BILLING: Play Billing kitaplığı (GodotGooglePlayBilling).
## `<paket>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` AndroidX'in imza düzeyi izni; sonek olarak kabul edilir.
const ALLOWED_PERMISSIONS: Array[String] = [
	"android.permission.INTERNET",
	"android.permission.ACCESS_NETWORK_STATE",
	"android.permission.VIBRATE",
	"android.permission.AD_ID",
	"com.google.android.gms.permission.AD_ID",
	"android.permission.ACCESS_ADSERVICES_AD_ID",
	"android.permission.ACCESS_ADSERVICES_ATTRIBUTION",
	"android.permission.ACCESS_ADSERVICES_TOPICS",
	"android.permission.WAKE_LOCK",
	"android.permission.FOREGROUND_SERVICE",
	"com.android.vending.BILLING",
]
const ALLOWED_PERMISSION_SUFFIXES: Array[String] = [".DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"]
const PRIVACY_URL_PLACEHOLDER_MARKER: String = "example."

const E_ADS_NOT_REAL: String = "ads_not_real"
const E_ADS_REAL_EMPTY: String = "ads_real_id_empty"
const E_ADS_TEST_ID: String = "ads_google_test_id"
const E_ADS_BAD_FORMAT: String = "ads_bad_id_format"
const E_ADS_CFG_NOT_SYNCED: String = "ads_manifest_cfg_not_synced"
const E_BILLING_OFF: String = "play_billing_disabled"
const E_APPLICATION_ID: String = "application_id_invalid"
const E_APPLICATION_ID_PLACEHOLDER: String = "application_id_placeholder"
const E_DEBUG_SIGNING: String = "debug_signing"
const E_SIGNING_SECRET: String = "signing_secret_in_preset"
const E_KEYSTORE_MISSING: String = "release_keystore_missing"
const E_VERSION_CODE: String = "version_code_invalid"
const E_VERSION_NOT_BUMPED: String = "version_code_not_bumped"
const E_VERSION_NAME: String = "version_name_empty"
const E_VERSION_MISMATCH: String = "version_name_mismatch_project"
const E_TARGET_SDK: String = "target_sdk_too_low"
const E_MIN_SDK: String = "min_sdk_too_low"
const E_PERMISSION: String = "permission_not_allowed"
const E_PERMISSION_MISSING: String = "permission_missing"
const E_NOT_AAB: String = "export_format_not_aab"
const E_ABI: String = "abi_not_arm64_only"
const E_PRIVACY_URL: String = "privacy_policy_url_missing"
## Üretilen AAB denetimi (tools/aab_inspect.py çıktısı):
const E_AAB_PACKAGE: String = "aab_package_mismatch"
const E_AAB_VERSION: String = "aab_version_mismatch"
const E_AAB_APP_ID: String = "aab_manifest_app_id_not_real"
const E_AAB_ADS_MODE: String = "aab_ads_ids_not_real"
const E_AAB_DEBUG_CERT: String = "aab_debug_certificate"
const E_AAB_UNSIGNED: String = "aab_unsigned"
const E_AAB_PERMISSION: String = "aab_permission_not_allowed"
const E_AAB_PERMISSION_MISSING: String = "aab_permission_missing"
const E_AAB_TARGET_SDK: String = "aab_target_sdk_too_low"
const E_AAB_MIN_SDK: String = "aab_min_sdk_too_low"
const E_AAB_16K: String = "aab_native_lib_not_16k_aligned"
const E_AAB_ABI: String = "aab_abi_not_arm64_only"
const E_AAB_DEBUGGABLE: String = "aab_debuggable"
const E_AAB_ORIENTATION: String = "aab_not_portrait"

const DESCRIPTIONS: Dictionary = {
	E_ADS_NOT_REAL: "data/ads_ids.json mode 'real' degil (test modunda yayin yapilamaz)",
	E_ADS_REAL_EMPTY: "data/ads_ids.json android.real_app_id / real_rewarded_unit / real_interstitial_unit bos",
	E_ADS_TEST_ID: "real_* alanlarinda Google TEST kimligi (ca-app-pub-3940256099942544) var",
	E_ADS_BAD_FORMAT: "real_* kimlik bicimi gecersiz (ca-app-pub-<16 hane>~/<10 hane>)",
	E_ADS_CFG_NOT_SYNCED: "addons/AdmobPlugin/android_export.cfg guncel degil (is_real / [Release] app_id): python3 tools/sync_ads_config.py",
	E_BILLING_OFF: "data/ads_ids.json providers.play_billing=false (no_ads satin alimi yayin surumunde kapali)",
	E_APPLICATION_ID: "uygulama kimligi (package/unique_name) gecersiz ya da bos",
	E_APPLICATION_ID_PLACEHOLDER: "uygulama kimligi yer tutucu/test (com.example.*, com.godot.game, *.test ...)",
	E_DEBUG_SIGNING: "yayin on ayari hata ayiklama anahtariyla imzalaniyor (GODOT_ANDROID_KEYSTORE_RELEASE_* debug anahtarini gosteriyor)",
	E_SIGNING_SECRET: "export_presets.cfg icinde imza sifresi/yolu var (yalniz ortam degiskeni kullanilmali)",
	E_KEYSTORE_MISSING: "GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD tanimli degil ya da anahtar dosyasi yok",
	E_VERSION_CODE: "version/code gecersiz (>= 1 tam sayi olmali)",
	E_VERSION_NOT_BUMPED: "version/code, son yuklenen kodtan buyuk degil (tools/release_state.json)",
	E_VERSION_NAME: "version/name bos",
	E_VERSION_MISMATCH: "project.godot config/version, preset version/name ile ayni degil (lider guncelleyecek)",
	E_TARGET_SDK: "hedef API 36'dan dusuk (Play zorunlulugu)",
	E_MIN_SDK: "min SDK 24'ten dusuk",
	E_PERMISSION: "izin verilenler listesinde olmayan bir izin istenmis",
	E_PERMISSION_MISSING: "preset'te zorunlu izin yok (INTERNET, ACCESS_NETWORK_STATE, VIBRATE)",
	E_NOT_AAB: "yayin on ayari AAB uretmiyor (export_format=1 olmali)",
	E_ABI: "yayin on ayari yalniz arm64-v8a uretmiyor",
	E_PRIVACY_URL: "gizlilik politikasi URL'si bos ya da yer tutucu (data/ads_ids.json privacy_policy_url, https:// olmali)",
	E_AAB_PACKAGE: "AAB manifest paket adi on ayardakiyle ayni degil",
	E_AAB_VERSION: "AAB versionCode/versionName on ayardakiyle ayni degil",
	E_AAB_APP_ID: "AAB manifestindeki com.google.android.gms.ads.APPLICATION_ID gercek (real_app_id) kimlik degil",
	E_AAB_ADS_MODE: "AAB icine giren data/ads_ids.json mode=real degil ya da bos/test kimligi iceriyor",
	E_AAB_DEBUG_CERT: "AAB hata ayiklama sertifikasiyla imzali",
	E_AAB_UNSIGNED: "AAB imzasiz (Play yuklemesi icin yukleme anahtariyla imzalanmali: docs/store/SIGNING.md)",
	E_AAB_PERMISSION: "AAB birlesik manifestinde izin verilenler listesinde olmayan izin var",
	E_AAB_PERMISSION_MISSING: "AAB birlesik manifestinde zorunlu izin eksik (INTERNET, ACCESS_NETWORK_STATE, VIBRATE)",
	E_AAB_TARGET_SDK: "AAB hedef API 36'dan dusuk",
	E_AAB_MIN_SDK: "AAB min SDK 24'ten dusuk",
	E_AAB_16K: "AAB icindeki bir .so dosyasi 16 KB (2**14) hizali degil ya da hic .so yok",
	E_AAB_ABI: "AAB arm64-v8a disinda ABI iceriyor ya da arm64-v8a yok",
	E_AAB_DEBUGGABLE: "AAB debuggable=true (yayin yapisi hata ayiklanabilir olamaz)",
	E_AAB_ORIENTATION: "AAB ana etkinligi dikey (portrait) degil",
}


## Yapılandırma denetimlerinin hepsi; hata kodları listesi döner (boş = geçti).
static func check(config: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(check_ads(config))
	errors.append_array(check_package(config))
	errors.append_array(check_signing(config))
	errors.append_array(check_version(config))
	errors.append_array(check_platform(config))
	errors.append_array(check_store(config))
	return errors


## AdMob/Billing: mode=real + dolu, gerçek biçimli, test olmayan kimlikler + manifest yapılandırması senkron + billing açık.
static func check_ads(config: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if String(config.get("ads_mode", "test")) != "real":
		errors.append(E_ADS_NOT_REAL)
	var raw: Variant = config.get("ads_real")
	var ids: Dictionary = raw as Dictionary if raw is Dictionary else {}
	var empty: bool = false
	var test_id: bool = false
	var bad_format: bool = false
	for key: String in ["app_id", "rewarded_unit", "interstitial_unit"]:
		var value: String = String(ids.get(key, ""))
		if value.strip_edges().is_empty():
			empty = true
			continue
		if value.contains(GOOGLE_TEST_PUBLISHER):
			test_id = true
			continue
		if not _matches(APP_ID_PATTERN if key == "app_id" else UNIT_ID_PATTERN, value):
			bad_format = true
	if empty:
		errors.append(E_ADS_REAL_EMPTY)
	if test_id:
		errors.append(E_ADS_TEST_ID)
	if bad_format:
		errors.append(E_ADS_BAD_FORMAT)
	# AdMob manifest kaydı android_export.cfg'den gelir: gerçek kipte is_real=true ve [Release] app_id = real_app_id olmalı.
	var real_app: String = String(ids.get("app_id", ""))
	if not bool(config.get("admob_cfg_is_real", false)) or real_app.is_empty() \
			or String(config.get("admob_cfg_release_app_id", "")) != real_app:
		errors.append(E_ADS_CFG_NOT_SYNCED)
	if not bool(config.get("play_billing", false)):
		errors.append(E_BILLING_OFF)
	return errors


static func check_package(config: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var application_id: String = String(config.get("application_id", ""))
	if not _matches(PACKAGE_PATTERN, application_id):
		errors.append(E_APPLICATION_ID)
		return errors
	for placeholder: String in PLACEHOLDER_PACKAGES:
		if application_id == placeholder or application_id.begins_with(placeholder + "."):
			errors.append(E_APPLICATION_ID_PLACEHOLDER)
			return errors
	for suffix: String in PLACEHOLDER_PACKAGE_SUFFIXES:
		if application_id.ends_with(suffix):
			errors.append(E_APPLICATION_ID_PLACEHOLDER)
			return errors
	return errors


## İmza: hata ayıklama anahtarı yok, şifre dosyada yok, ortam değişkenleri hazır.
static func check_signing(config: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if bool(config.get("debug_signing", true)):
		errors.append(E_DEBUG_SIGNING)
	if bool(config.get("signing_secrets_in_preset", false)):
		errors.append(E_SIGNING_SECRET)
	if not bool(config.get("release_keystore_ready", false)):
		errors.append(E_KEYSTORE_MISSING)
	return errors


static func check_version(config: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var code: int = int(config.get("version_code", 0))
	if code < 1:
		errors.append(E_VERSION_CODE)
	elif code <= int(config.get("last_uploaded_version_code", 0)):
		errors.append(E_VERSION_NOT_BUMPED)
	var vname: String = String(config.get("version_name", "")).strip_edges()
	if vname.is_empty():
		errors.append(E_VERSION_NAME)
	elif String(config.get("project_version", "")) != vname:
		errors.append(E_VERSION_MISMATCH)
	return errors


static func check_platform(config: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if int(config.get("target_sdk", 0)) < MIN_TARGET_SDK:
		errors.append(E_TARGET_SDK)
	if int(config.get("min_sdk", 0)) < MIN_MIN_SDK:
		errors.append(E_MIN_SDK)
	if int(config.get("export_format", 0)) != 1:
		errors.append(E_NOT_AAB)
	var abis: Array = config.get("architectures", []) as Array
	if abis.size() != 1 or String(abis[0]) != "arm64-v8a":
		errors.append(E_ABI)
	var permissions: Array = config.get("permissions", []) as Array
	if not disallowed_permissions(permissions).is_empty():
		errors.append(E_PERMISSION)
	if not missing_permissions(permissions).is_empty():
		errors.append(E_PERMISSION_MISSING)
	return errors


static func check_store(config: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var url: String = String(config.get("privacy_policy_url", "")).strip_edges()
	if url.is_empty() or url.contains(PRIVACY_URL_PLACEHOLDER_MARKER) or not url.begins_with("https://"):
		errors.append(E_PRIVACY_URL)
	return errors


## Üretilmiş AAB denetimi. `info`: `tools/aab_inspect.py --json` çıktısı; `config`: `check()` girdisi.
static func check_artifact(info: Dictionary, config: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var manifest: Dictionary = info.get("manifest", {}) as Dictionary
	if str(manifest.get("package", "")) != String(config.get("application_id", "-")):
		errors.append(E_AAB_PACKAGE)
	if int(str(manifest.get("versionCode", "0"))) != int(config.get("version_code", -1)) \
			or str(manifest.get("versionName", "")) != String(config.get("version_name", "-")):
		errors.append(E_AAB_VERSION)
	if int(str(manifest.get("targetSdkVersion", "0"))) < MIN_TARGET_SDK:
		errors.append(E_AAB_TARGET_SDK)
	if int(str(manifest.get("minSdkVersion", "0"))) < MIN_MIN_SDK:
		errors.append(E_AAB_MIN_SDK)
	var real: Dictionary = config.get("ads_real", {}) as Dictionary
	var manifest_app_id: String = str(manifest.get("appId", ""))
	if manifest_app_id.is_empty() or manifest_app_id.contains(GOOGLE_TEST_PUBLISHER) \
			or manifest_app_id != String(real.get("app_id", "")):
		errors.append(E_AAB_APP_ID)
	var shipped: Variant = info.get("shipped_ads_ids")
	if shipped is Dictionary:
		var data: Dictionary = shipped as Dictionary
		var android: Dictionary = data.get("android", {}) as Dictionary
		var shipped_errors: Array[String] = check_ads({
			"ads_mode": data.get("mode", "test"),
			"ads_real": {"app_id": android.get("real_app_id", ""), "rewarded_unit": android.get("real_rewarded_unit", ""),
				"interstitial_unit": android.get("real_interstitial_unit", "")},
			"admob_cfg_is_real": true, "admob_cfg_release_app_id": manifest_app_id,
			"play_billing": (data.get("providers", {}) as Dictionary).get("play_billing", false)})
		if not shipped_errors.is_empty():
			errors.append(E_AAB_ADS_MODE)
	else:
		errors.append(E_AAB_ADS_MODE)
	if bool(info.get("debug_certificate", false)):
		errors.append(E_AAB_DEBUG_CERT)
	elif (info.get("signature_files", []) as Array).is_empty():
		errors.append(E_AAB_UNSIGNED)
	var permissions: Array = manifest.get("permissions", []) as Array
	if not disallowed_permissions(permissions).is_empty():
		errors.append(E_AAB_PERMISSION)
	if not missing_permissions(permissions).is_empty():
		errors.append(E_AAB_PERMISSION_MISSING)
	var libs: Dictionary = info.get("native_libs", {}) as Dictionary
	var aligned: bool = not libs.is_empty()
	for abi: Variant in libs.keys():
		for lib_info: Variant in (libs[abi] as Dictionary).values():
			if int((lib_info as Dictionary).get("min_load_align", 0)) < ALIGN_16K:
				aligned = false
	if not aligned:
		errors.append(E_AAB_16K)
	var abi_keys: Array = libs.keys()
	if abi_keys.size() != 1 or String(abi_keys[0]) != "arm64-v8a":
		errors.append(E_AAB_ABI)
	if str(manifest.get("debuggable", "")) == "true":
		errors.append(E_AAB_DEBUGGABLE)
	if (manifest.get("screenOrientations", []) as Array) != ["portrait"]:
		errors.append(E_AAB_ORIENTATION)
	return errors


static func describe(code: String) -> String:
	return String(DESCRIPTIONS.get(code, code))


## İzin listesinden izin verilmeyenleri döndürür.
static func disallowed_permissions(permissions: Array) -> Array[String]:
	var bad: Array[String] = []
	for permission: Variant in permissions:
		if not permission_allowed(String(permission)):
			bad.append(String(permission))
	return bad


## Zorunlu izinlerden listede olmayanlar.
static func missing_permissions(permissions: Array) -> Array[String]:
	var missing: Array[String] = []
	for required: String in REQUIRED_PERMISSIONS:
		if not permissions.has(required):
			missing.append(required)
	return missing


static func permission_allowed(permission: String) -> bool:
	if ALLOWED_PERMISSIONS.has(permission):
		return true
	for suffix: String in ALLOWED_PERMISSION_SUFFIXES:
		if permission.ends_with(suffix):
			return true
	return false


static func _matches(pattern: String, value: String) -> bool:
	var regex: RegEx = RegEx.new()
	if regex.compile(pattern) != OK:
		return false
	return regex.search(value) != null
