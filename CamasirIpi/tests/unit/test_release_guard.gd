extends TestCase

## ReleaseGuard (yayın koruması) — her ret nedeni ayrı bir test. Gerçek biçimli kimlikler SAHTE
## sayılardır (Google'ın yayıncı kimliği değil), yalnız biçim denetimi içindir.

const REAL_APP: String = "ca-app-pub-1234567890123456~1234567890"
const REAL_REWARDED: String = "ca-app-pub-1234567890123456/1111111111"
const REAL_INTERSTITIAL: String = "ca-app-pub-1234567890123456/2222222222"


func _good() -> Dictionary:
	return {
		"ads_mode": "production",
		"ads_production": {"app_id": REAL_APP, "rewarded_unit_id": REAL_REWARDED,
			"interstitial_unit_id": REAL_INTERSTITIAL},
		"project_app_id": REAL_APP,
		"application_id": "com.clotheslinesort.game",
		"version_code": 2,
		"version_name": "1.0.1",
		"last_uploaded_version_code": 1,
		"target_sdk": 36,
		"min_sdk": 24,
		"permissions": ["android.permission.INTERNET", "android.permission.ACCESS_NETWORK_STATE",
			"com.google.android.gms.permission.AD_ID", "com.android.vending.BILLING"],
		"debug_signing": false,
		"signing_secrets_in_preset": false,
		"release_keystore_ready": true,
		"privacy_policy_url": "https://clothesline.example.org/privacy",
		"export_format": 1,
	}


func _expect(config: Dictionary, code: String) -> void:
	var errors: Array[String] = ReleaseGuard.check(config)
	assert_true(errors.has(code), "'%s' bekleniyordu, gelen %s" % [code, str(errors)])


func test_good_config_passes() -> void:
	assert_eq(ReleaseGuard.check(_good()), [] as Array[String], "temiz yapilandirma gecmeli")


func test_empty_config_fails_everywhere() -> void:
	var errors: Array[String] = ReleaseGuard.check({})
	assert_true(errors.has(ReleaseGuard.E_ADS_PLACEHOLDER))
	assert_true(errors.has(ReleaseGuard.E_APPLICATION_ID))
	assert_true(errors.has(ReleaseGuard.E_VERSION_CODE))
	assert_true(errors.has(ReleaseGuard.E_KEYSTORE_MISSING))


func test_test_mode_is_rejected() -> void:
	var config: Dictionary = _good()
	config["ads_mode"] = "test"
	_expect(config, ReleaseGuard.E_ADS_NOT_PRODUCTION)


func test_consent_cannot_be_disabled_for_release() -> void:
	var config: Dictionary = _good()
	config["ads_request_consent"] = false
	_expect(config, ReleaseGuard.E_ADS_NO_CONSENT)


func test_placeholder_ads_ids_rejected() -> void:
	var config: Dictionary = _good()
	config["ads_production"] = {"app_id": "REPLACE_WITH_REAL_ADMOB_APP_ID",
		"rewarded_unit_id": REAL_REWARDED, "interstitial_unit_id": "REPLACE_WITH_REAL_INTERSTITIAL_UNIT_ID"}
	_expect(config, ReleaseGuard.E_ADS_PLACEHOLDER)


func test_google_test_ids_rejected() -> void:
	var config: Dictionary = _good()
	config["ads_production"] = {"app_id": "ca-app-pub-3940256099942544~3347511713",
		"rewarded_unit_id": "ca-app-pub-3940256099942544/5224354917", "interstitial_unit_id": REAL_INTERSTITIAL}
	_expect(config, ReleaseGuard.E_ADS_TEST_ID)


func test_malformed_ads_id_rejected() -> void:
	var config: Dictionary = _good()
	config["ads_production"] = {"app_id": REAL_APP, "rewarded_unit_id": "ca-app-pub-123/456",
		"interstitial_unit_id": REAL_INTERSTITIAL}
	_expect(config, ReleaseGuard.E_ADS_BAD_FORMAT)
	# Birim kimliği ile uygulama kimliği ayracı karıştırılırsa da biçim hatası.
	config["ads_production"] = {"app_id": REAL_REWARDED, "rewarded_unit_id": REAL_REWARDED,
		"interstitial_unit_id": REAL_INTERSTITIAL}
	_expect(config, ReleaseGuard.E_ADS_BAD_FORMAT)


func test_manifest_app_id_must_match_ads_json() -> void:
	var config: Dictionary = _good()
	config["project_app_id"] = "ca-app-pub-3940256099942544~3347511713"
	_expect(config, ReleaseGuard.E_APP_ID_MISMATCH)
	config["project_app_id"] = ""
	_expect(config, ReleaseGuard.E_APP_ID_MISMATCH)


func test_placeholder_application_ids_rejected() -> void:
	for bad: String in ["com.godot.game", "org.godotengine.editor.v4", "com.example.app",
			"com.camasiripi.game.test", "com.clotheslinesort.game.debug"]:
		var config: Dictionary = _good()
		config["application_id"] = bad
		_expect(config, ReleaseGuard.E_APPLICATION_ID_PLACEHOLDER)


func test_invalid_application_id_rejected() -> void:
	for bad: String in ["", "game", "Com.Upper.Case", "1com.x.y", "com..x"]:
		var config: Dictionary = _good()
		config["application_id"] = bad
		_expect(config, ReleaseGuard.E_APPLICATION_ID)


func test_debug_signing_rejected() -> void:
	var config: Dictionary = _good()
	config["debug_signing"] = true
	_expect(config, ReleaseGuard.E_DEBUG_SIGNING)


func test_secrets_in_preset_rejected() -> void:
	var config: Dictionary = _good()
	config["signing_secrets_in_preset"] = true
	_expect(config, ReleaseGuard.E_SIGNING_SECRET)


func test_missing_release_keystore_rejected() -> void:
	var config: Dictionary = _good()
	config["release_keystore_ready"] = false
	_expect(config, ReleaseGuard.E_KEYSTORE_MISSING)


func test_version_code_must_be_bumped() -> void:
	var config: Dictionary = _good()
	config["version_code"] = 1
	_expect(config, ReleaseGuard.E_VERSION_NOT_BUMPED)
	config["version_code"] = 0
	_expect(config, ReleaseGuard.E_VERSION_CODE)
	# Hiç yükleme yokken (0) 1 geçerlidir.
	config["version_code"] = 1
	config["last_uploaded_version_code"] = 0
	assert_false(ReleaseGuard.check(config).has(ReleaseGuard.E_VERSION_NOT_BUMPED))


func test_empty_version_name_rejected() -> void:
	var config: Dictionary = _good()
	config["version_name"] = " "
	_expect(config, ReleaseGuard.E_VERSION_NAME)


func test_sdk_floors() -> void:
	var config: Dictionary = _good()
	config["target_sdk"] = 35
	_expect(config, ReleaseGuard.E_TARGET_SDK)
	config = _good()
	config["min_sdk"] = 21
	_expect(config, ReleaseGuard.E_MIN_SDK)


func test_extra_permission_rejected() -> void:
	var config: Dictionary = _good()
	config["permissions"] = ["android.permission.INTERNET", "android.permission.CAMERA"]
	_expect(config, ReleaseGuard.E_PERMISSION)
	assert_eq(ReleaseGuard.disallowed_permissions(config["permissions"] as Array),
		["android.permission.CAMERA"] as Array[String])


func test_library_permissions_are_allowed() -> void:
	var config: Dictionary = _good()
	config["permissions"] = ["android.permission.WAKE_LOCK", "android.permission.FOREGROUND_SERVICE",
		"android.permission.READ_BASIC_PHONE_STATE", "com.clotheslinesort.game.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"]
	assert_false(ReleaseGuard.check(config).has(ReleaseGuard.E_PERMISSION))


func test_apk_format_rejected() -> void:
	var config: Dictionary = _good()
	config["export_format"] = 0
	_expect(config, ReleaseGuard.E_NOT_AAB)


func test_privacy_url_placeholder_rejected() -> void:
	for bad: String in ["", "http://insecure.org/p", "https://example.invalid/PRIVACY"]:
		var config: Dictionary = _good()
		config["privacy_policy_url"] = bad
		_expect(config, ReleaseGuard.E_PRIVACY_URL)


func test_every_error_code_has_a_description() -> void:
	for code: Variant in [ReleaseGuard.E_ADS_NOT_PRODUCTION, ReleaseGuard.E_ADS_NO_CONSENT, ReleaseGuard.E_ADS_PLACEHOLDER,
			ReleaseGuard.E_ADS_TEST_ID, ReleaseGuard.E_ADS_BAD_FORMAT, ReleaseGuard.E_APP_ID_MISMATCH,
			ReleaseGuard.E_APPLICATION_ID, ReleaseGuard.E_APPLICATION_ID_PLACEHOLDER,
			ReleaseGuard.E_DEBUG_SIGNING, ReleaseGuard.E_SIGNING_SECRET, ReleaseGuard.E_KEYSTORE_MISSING,
			ReleaseGuard.E_VERSION_CODE, ReleaseGuard.E_VERSION_NOT_BUMPED, ReleaseGuard.E_VERSION_NAME,
			ReleaseGuard.E_TARGET_SDK, ReleaseGuard.E_MIN_SDK, ReleaseGuard.E_PERMISSION,
			ReleaseGuard.E_NOT_AAB, ReleaseGuard.E_PRIVACY_URL]:
		assert_true(ReleaseGuard.DESCRIPTIONS.has(code), "aciklama yok: %s" % str(code))


# --- Üretilmiş AAB denetimi --------------------------------------------------------------

func _good_info() -> Dictionary:
	return {
		"manifest": {"package": "com.clotheslinesort.game", "versionCode": "2", "versionName": "1.0.1",
			"targetSdkVersion": "36", "appId": REAL_APP, "debuggable": null,
			"permissions": ["android.permission.INTERNET", "com.google.android.gms.permission.AD_ID"]},
		"shipped_ads_json": {"admob": {"mode": "production", "production": {"app_id": REAL_APP,
			"rewarded_unit_id": REAL_REWARDED, "interstitial_unit_id": REAL_INTERSTITIAL}}},
		"signature_files": ["META-INF/UPLOAD.RSA"],
		"debug_certificate": false,
		"native_libs": {"arm64-v8a": {"libgodot_android.so": {"min_load_align": 16384}}},
	}


func _expect_artifact(info: Dictionary, code: String) -> void:
	var errors: Array[String] = ReleaseGuard.check_artifact(info, _good())
	assert_true(errors.has(code), "'%s' bekleniyordu, gelen %s" % [code, str(errors)])


func test_good_artifact_passes() -> void:
	assert_eq(ReleaseGuard.check_artifact(_good_info(), _good()), [] as Array[String])


func test_artifact_package_and_version_mismatch() -> void:
	var info: Dictionary = _good_info()
	(info["manifest"] as Dictionary)["package"] = "com.godot.game"
	_expect_artifact(info, ReleaseGuard.E_AAB_PACKAGE)
	info = _good_info()
	(info["manifest"] as Dictionary)["versionCode"] = "1"
	_expect_artifact(info, ReleaseGuard.E_AAB_VERSION)


func test_artifact_manifest_app_id_must_be_production() -> void:
	var info: Dictionary = _good_info()
	(info["manifest"] as Dictionary)["appId"] = "ca-app-pub-3940256099942544~3347511713"
	_expect_artifact(info, ReleaseGuard.E_AAB_APP_ID)


func test_artifact_shipped_ads_json_in_test_mode_rejected() -> void:
	var info: Dictionary = _good_info()
	((info["shipped_ads_json"] as Dictionary)["admob"] as Dictionary)["mode"] = "test"
	_expect_artifact(info, ReleaseGuard.E_AAB_ADS_JSON)
	info["shipped_ads_json"] = null
	_expect_artifact(info, ReleaseGuard.E_AAB_ADS_JSON)


func test_artifact_signature_rules() -> void:
	var info: Dictionary = _good_info()
	info["debug_certificate"] = true
	_expect_artifact(info, ReleaseGuard.E_AAB_DEBUG_CERT)
	info = _good_info()
	info["signature_files"] = []
	_expect_artifact(info, ReleaseGuard.E_AAB_UNSIGNED)


func test_artifact_permissions_sdk_alignment_debuggable() -> void:
	var info: Dictionary = _good_info()
	(info["manifest"] as Dictionary)["permissions"] = ["android.permission.CAMERA"]
	_expect_artifact(info, ReleaseGuard.E_AAB_PERMISSION)
	info = _good_info()
	(info["manifest"] as Dictionary)["targetSdkVersion"] = "35"
	_expect_artifact(info, ReleaseGuard.E_AAB_TARGET_SDK)
	info = _good_info()
	((info["native_libs"] as Dictionary)["arm64-v8a"] as Dictionary)["libx.so"] = {"min_load_align": 4096}
	_expect_artifact(info, ReleaseGuard.E_AAB_16K)
	info = _good_info()
	info["native_libs"] = {}
	_expect_artifact(info, ReleaseGuard.E_AAB_16K)
	info = _good_info()
	(info["manifest"] as Dictionary)["debuggable"] = "true"
	_expect_artifact(info, ReleaseGuard.E_AAB_DEBUGGABLE)
