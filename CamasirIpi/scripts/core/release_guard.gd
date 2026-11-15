class_name ReleaseGuard
extends RefCounted

## Yayın koruması — SAF fonksiyon (dosya/sahne yok). Üretim (Play) yapısı; yer tutucu ya da test
## kimlikleriyle, hata ayıklama imzasıyla, artırılmamış sürüm koduyla, test kipindeki reklam
## yapılandırmasıyla alınamasın diye `tools/release_check.sh` tarafından çağrılır.
## `check()` hata kodlarının listesini döndürür; boş liste = geçti. Her kod bir cümleyle
## `describe()` ile açıklanır (betik çıktısı ve testler aynı kodları kullanır).
##
## Girdi sözlüğü (`config`), hepsi isteğe bağlıdır; eksik alan "bilinmiyor" sayılır ve hata verir:
##   ads_mode, ads_production {app_id, rewarded_unit_id, interstitial_unit_id}, project_app_id,
##   application_id, version_code, version_name, last_uploaded_version_code,
##   target_sdk, min_sdk, permissions (Array), debug_signing (bool), signing_secrets_in_preset (bool),
##   release_keystore_ready (bool), privacy_policy_url, export_format (0 apk, 1 aab).

const GOOGLE_TEST_PUBLISHER: String = "ca-app-pub-3940256099942544"
const PLACEHOLDER_PREFIX: String = "REPLACE_"
## Gerçek biçim: uygulama `ca-app-pub-<16>~<10>`, birim `ca-app-pub-<16>/<10>`.
const APP_ID_PATTERN: String = "^ca-app-pub-[0-9]{16}~[0-9]{10}$"
const UNIT_ID_PATTERN: String = "^ca-app-pub-[0-9]{16}/[0-9]{10}$"
## Paket adı: en az iki parça, her parça harfle başlar (Android kuralı), küçük harf/rakam/alt çizgi.
const PACKAGE_PATTERN: String = "^[a-z][a-z0-9_]*(\\.[a-z][a-z0-9_]*)+$"
## Yayın paketine hiç yakışmayan paket adı parçaları.
const PLACEHOLDER_PACKAGES: Array[String] = ["com.godot.game", "org.godotengine", "com.example", "com.camasiripi.game.test"]
const PLACEHOLDER_PACKAGE_SUFFIXES: Array[String] = [".test", ".debug", ".dev", ".example"]
const MIN_TARGET_SDK: int = 36
const MIN_MIN_SDK: int = 24
const ALIGN_16K: int = 16384
## Yayın manifestinde izin verilen tek izinler. Kaynakları (birleşik manifest raporu, 2026-11-15):
##  * INTERNET, ACCESS_NETWORK_STATE: önayar + Poing AdMob AAR,
##  * android.permission.AD_ID + com.google.android.gms.permission.AD_ID: Poing AAR ve Google Mobile Ads Next-Gen SDK 1.4.0,
##  * READ_BASIC_PHONE_STATE: Google Mobile Ads Next-Gen SDK 1.4.0,
##  * WAKE_LOCK + FOREGROUND_SERVICE: androidx.work:work-runtime 2.7.0 (reklam SDK'sının geçişli bağımlılığı),
##  * com.android.vending.BILLING: Play Billing kitaplığı (eklenti kurulunca).
## `<paket>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` AndroidX'in imza düzeyi izni; sonek olarak kabul edilir.
const ALLOWED_PERMISSIONS: Array[String] = [
	"android.permission.INTERNET",
	"android.permission.ACCESS_NETWORK_STATE",
	"android.permission.AD_ID",
	"com.google.android.gms.permission.AD_ID",
	"android.permission.READ_BASIC_PHONE_STATE",
	"android.permission.WAKE_LOCK",
	"android.permission.FOREGROUND_SERVICE",
	"com.android.vending.BILLING",
]
const ALLOWED_PERMISSION_SUFFIXES: Array[String] = [".DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"]
const PRIVACY_URL_PLACEHOLDER_MARKER: String = "example.invalid"

const E_ADS_NOT_PRODUCTION: String = "ads_not_production"
const E_ADS_PLACEHOLDER: String = "ads_placeholder_id"
const E_ADS_TEST_ID: String = "ads_google_test_id"
const E_ADS_BAD_FORMAT: String = "ads_bad_id_format"
const E_ADS_NO_CONSENT: String = "ads_consent_disabled"
const E_APP_ID_MISMATCH: String = "project_app_id_mismatch"
const E_APPLICATION_ID: String = "application_id_invalid"
const E_APPLICATION_ID_PLACEHOLDER: String = "application_id_placeholder"
const E_DEBUG_SIGNING: String = "debug_signing"
const E_SIGNING_SECRET: String = "signing_secret_in_preset"
const E_KEYSTORE_MISSING: String = "release_keystore_missing"
const E_VERSION_CODE: String = "version_code_invalid"
const E_VERSION_NOT_BUMPED: String = "version_code_not_bumped"
const E_VERSION_NAME: String = "version_name_empty"
const E_TARGET_SDK: String = "target_sdk_too_low"
const E_MIN_SDK: String = "min_sdk_too_low"
const E_PERMISSION: String = "permission_not_allowed"
const E_NOT_AAB: String = "export_format_not_aab"
const E_PRIVACY_URL: String = "privacy_policy_url_missing"
## Üretilen AAB denetimi (tools/aab_inspect.py çıktısı):
const E_AAB_PACKAGE: String = "aab_package_mismatch"
const E_AAB_VERSION: String = "aab_version_mismatch"
const E_AAB_APP_ID: String = "aab_manifest_app_id_mismatch"
const E_AAB_ADS_JSON: String = "aab_ads_json_not_production"
const E_AAB_DEBUG_CERT: String = "aab_debug_certificate"
const E_AAB_UNSIGNED: String = "aab_unsigned"
const E_AAB_PERMISSION: String = "aab_permission_not_allowed"
const E_AAB_TARGET_SDK: String = "aab_target_sdk_too_low"
const E_AAB_16K: String = "aab_native_lib_not_16k_aligned"
const E_AAB_DEBUGGABLE: String = "aab_debuggable"

const DESCRIPTIONS: Dictionary = {
	E_ADS_NOT_PRODUCTION: "data/ads.json admob.mode 'production' degil (test modunda yayin yapilamaz)",
	E_ADS_PLACEHOLDER: "admob.production icinde REPLACE_* yer tutucu kaldi",
	E_ADS_TEST_ID: "admob.production icinde Google TEST kimligi (ca-app-pub-3940256099942544) var",
	E_ADS_BAD_FORMAT: "admob.production kimlik bicimi gecersiz (ca-app-pub-<16 hane>~/<10 hane>)",
	E_ADS_NO_CONSENT: "data/ads.json admob.request_consent=false (UMP onayi kapatilamaz; AB/BK politikasi)",
	E_APP_ID_MISMATCH: "project.godot [admob] general/android/app_id, ads.json production.app_id ile ayni degil (manifest yanlis kimlikle cikar)",
	E_APPLICATION_ID: "uygulama kimligi (package/unique_name) gecersiz ya da bos",
	E_APPLICATION_ID_PLACEHOLDER: "uygulama kimligi yer tutucu/test (com.godot.game, org.godotengine.*, *.test ...)",
	E_DEBUG_SIGNING: "yayin on ayari hata ayiklama anahtariyla imzalaniyor (keystore/release ya da debug anahtari kullaniliyor)",
	E_SIGNING_SECRET: "export_presets.cfg icinde imza sifresi/yolu var (yalniz ortam degiskeni kullanilmali)",
	E_KEYSTORE_MISSING: "GODOT_ANDROID_KEYSTORE_RELEASE_PATH/_USER/_PASSWORD tanimli degil ya da anahtar dosyasi yok",
	E_VERSION_CODE: "version/code gecersiz (>= 1 tam sayi olmali)",
	E_VERSION_NOT_BUMPED: "version/code, son yuklenen kodtan buyuk degil (docs/store/release_state.json)",
	E_VERSION_NAME: "version/name bos",
	E_TARGET_SDK: "hedef API 36'dan dusuk (Play zorunlulugu)",
	E_MIN_SDK: "min SDK 24'ten dusuk (AdMob Next-Gen SDK gereksinimi)",
	E_PERMISSION: "izin verilenler listesinde olmayan bir izin istenmis",
	E_NOT_AAB: "yayin on ayari AAB uretmiyor (export_format=1 olmali)",
	E_PRIVACY_URL: "gizlilik politikasi URL'si bos ya da yer tutucu (data/store.json)",
	E_AAB_PACKAGE: "AAB manifest paket adi on ayardakiyle ayni degil",
	E_AAB_VERSION: "AAB versionCode/versionName on ayardakiyle ayni degil",
	E_AAB_APP_ID: "AAB manifestindeki com.google.android.gms.ads.APPLICATION_ID gercek (production) kimlik degil",
	E_AAB_ADS_JSON: "AAB icine giren data/ads.json mode=production degil ya da yer tutucu/test kimligi iceriyor",
	E_AAB_DEBUG_CERT: "AAB hata ayiklama sertifikasiyla imzali",
	E_AAB_UNSIGNED: "AAB imzasiz (Play yuklemesi icin yukleme anahtariyla imzalanmali: docs/store/SIGNING.md)",
	E_AAB_PERMISSION: "AAB birlesik manifestinde izin verilenler listesinde olmayan izin var",
	E_AAB_TARGET_SDK: "AAB hedef API 36'dan dusuk",
	E_AAB_16K: "AAB icindeki bir .so dosyasi 16 KB (2**14) hizali degil",
	E_AAB_DEBUGGABLE: "AAB debuggable=true (yayin yapisi hata ayiklanabilir olamaz)",
}


## Tüm denetimleri çalıştırır; hata kodları listesi döner (boş = geçti).
static func check(config: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	errors.append_array(check_ads(config))
	errors.append_array(check_package(config))
	errors.append_array(check_signing(config))
	errors.append_array(check_version(config))
	errors.append_array(check_platform(config))
	errors.append_array(check_store(config))
	return errors


## AdMob: üretim modu + gerçek biçimli, test olmayan, yer tutucusuz kimlikler + manifest kimliği tutarlı.
static func check_ads(config: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if String(config.get("ads_mode", "test")) != "production":
		errors.append(E_ADS_NOT_PRODUCTION)
	if not bool(config.get("ads_request_consent", true)):
		errors.append(E_ADS_NO_CONSENT)
	var production: Variant = config.get("ads_production")
	var ids: Dictionary = production as Dictionary if production is Dictionary else {}
	var placeholder: bool = false
	var test_id: bool = false
	var bad_format: bool = false
	for key: String in ["app_id", "rewarded_unit_id", "interstitial_unit_id"]:
		var value: String = String(ids.get(key, ""))
		if value.is_empty() or value.begins_with(PLACEHOLDER_PREFIX):
			placeholder = true
			continue
		if value.contains(GOOGLE_TEST_PUBLISHER):
			test_id = true
			continue
		var pattern: String = APP_ID_PATTERN if key == "app_id" else UNIT_ID_PATTERN
		if not _matches(pattern, value):
			bad_format = true
	if placeholder:
		errors.append(E_ADS_PLACEHOLDER)
	if test_id:
		errors.append(E_ADS_TEST_ID)
	if bad_format:
		errors.append(E_ADS_BAD_FORMAT)
	# Manifest uygulama kimliği proje ayarından yazılır; ads.json ile aynı olmak zorunda.
	if String(config.get("project_app_id", "")) != String(ids.get("app_id", "")) or String(ids.get("app_id", "")).is_empty():
		errors.append(E_APP_ID_MISMATCH)
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
	if String(config.get("version_name", "")).strip_edges().is_empty():
		errors.append(E_VERSION_NAME)
	return errors


static func check_platform(config: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if int(config.get("target_sdk", 0)) < MIN_TARGET_SDK:
		errors.append(E_TARGET_SDK)
	if int(config.get("min_sdk", 0)) < MIN_MIN_SDK:
		errors.append(E_MIN_SDK)
	if int(config.get("export_format", 0)) != 1:
		errors.append(E_NOT_AAB)
	var permissions: Variant = config.get("permissions", [])
	if permissions is Array:
		if not disallowed_permissions(permissions as Array).is_empty():
			errors.append(E_PERMISSION)
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
	var production: Dictionary = config.get("ads_production", {}) as Dictionary
	var manifest_app_id: String = str(manifest.get("appId", ""))
	if manifest_app_id.is_empty() or manifest_app_id.contains(GOOGLE_TEST_PUBLISHER) \
			or manifest_app_id != String(production.get("app_id", "")):
		errors.append(E_AAB_APP_ID)
	var shipped: Variant = info.get("shipped_ads_json")
	if shipped is Dictionary:
		var admob: Dictionary = (shipped as Dictionary).get("admob", {}) as Dictionary
		var shipped_errors: Array[String] = check_ads({"ads_mode": admob.get("mode", "test"),
			"ads_production": admob.get("production", {}), "project_app_id": manifest_app_id})
		if not shipped_errors.is_empty():
			errors.append(E_AAB_ADS_JSON)
	else:
		errors.append(E_AAB_ADS_JSON)
	if bool(info.get("debug_certificate", false)):
		errors.append(E_AAB_DEBUG_CERT)
	elif (info.get("signature_files", []) as Array).is_empty():
		errors.append(E_AAB_UNSIGNED)
	var permissions: Array = manifest.get("permissions", []) as Array
	if not disallowed_permissions(permissions).is_empty():
		errors.append(E_AAB_PERMISSION)
	var libs: Dictionary = info.get("native_libs", {}) as Dictionary
	var aligned: bool = not libs.is_empty()
	for abi: Variant in libs.keys():
		for lib_info: Variant in (libs[abi] as Dictionary).values():
			if int((lib_info as Dictionary).get("min_load_align", 0)) < ALIGN_16K:
				aligned = false
	if not aligned:
		errors.append(E_AAB_16K)
	if str(manifest.get("debuggable", "")) == "true":
		errors.append(E_AAB_DEBUGGABLE)
	return errors


static func describe(code: String) -> String:
	return String(DESCRIPTIONS.get(code, code))


## İzin listesinden izin verilmeyenleri döndürür (manifest taraması için).
static func disallowed_permissions(permissions: Array) -> Array[String]:
	var bad: Array[String] = []
	for permission: Variant in permissions:
		if not permission_allowed(String(permission)):
			bad.append(String(permission))
	return bad


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
