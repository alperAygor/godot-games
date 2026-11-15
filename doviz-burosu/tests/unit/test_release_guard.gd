extends "res://tests/test_case.gd"
## ReleaseGuard (tools/release_guard.gd): her ret nedeni ayrı test. Gerçek biçimli kimlikler SAHTE sayılardır
## (Google'ın yayıncı kimliği değil), yalnız biçim denetimi içindir.

const REAL_APP: String = "ca-app-pub-1234567890123456~1234567890"
const REAL_REWARDED: String = "ca-app-pub-1234567890123456/1111111111"
const REAL_INTERSTITIAL: String = "ca-app-pub-1234567890123456/2222222222"
const PERMS: Array = ["android.permission.INTERNET", "android.permission.ACCESS_NETWORK_STATE",
	"android.permission.VIBRATE", "com.google.android.gms.permission.AD_ID", "com.android.vending.BILLING"]


func _good() -> Dictionary:
	return {
		"ads_mode": "real",
		"ads_real": {"app_id": REAL_APP, "rewarded_unit": REAL_REWARDED, "interstitial_unit": REAL_INTERSTITIAL},
		"admob_cfg_is_real": true, "admob_cfg_release_app_id": REAL_APP, "play_billing": true,
		"application_id": "com.dovizburosu.game", "version_code": 2, "version_name": "1.0.1", "project_version": "1.0.1",
		"last_uploaded_version_code": 1, "target_sdk": 36, "min_sdk": 24, "export_format": 1,
		"architectures": ["arm64-v8a"], "permissions": PERMS,
		"debug_signing": false, "signing_secrets_in_preset": false, "release_keystore_ready": true,
		"privacy_policy_url": "https://owner.test-domain.org/privacy",
	}


func _good_info() -> Dictionary:
	return {
		"file": "x.aab", "size_bytes": 1000,
		"manifest": {"package": "com.dovizburosu.game", "versionCode": "2", "versionName": "1.0.1",
			"minSdkVersion": "24", "targetSdkVersion": "36", "permissions": PERMS, "debuggable": null,
			"appId": REAL_APP, "screenOrientations": ["portrait"]},
		"native_libs": {"arm64-v8a": {"libgodot_android.so": {"min_load_align": 16384, "bytes": 1}}},
		"signature_files": ["META-INF/UPLOAD.RSA"], "debug_certificate": false,
		"shipped_ads_ids": {"mode": "real", "providers": {"play_billing": true},
			"android": {"real_app_id": REAL_APP, "real_rewarded_unit": REAL_REWARDED, "real_interstitial_unit": REAL_INTERSTITIAL}},
	}


func _expect(config: Dictionary, code: String) -> void:
	var errors: Array[String] = ReleaseGuard.check(config)
	assert_true(errors.has(code), "'%s' bekleniyordu, gelen %s" % [code, str(errors)])


func _expect_artifact(info: Dictionary, code: String) -> void:
	var errors: Array[String] = ReleaseGuard.check_artifact(info, _good())
	assert_true(errors.has(code), "'%s' bekleniyordu, gelen %s" % [code, str(errors)])


func test_good_config_passes() -> void:
	assert_eq(ReleaseGuard.check(_good()), [] as Array[String])


func test_good_artifact_passes() -> void:
	assert_eq(ReleaseGuard.check_artifact(_good_info(), _good()), [] as Array[String])


func test_empty_config_fails_everywhere() -> void:
	var errors: Array[String] = ReleaseGuard.check({})
	for code: String in [ReleaseGuard.E_ADS_NOT_REAL, ReleaseGuard.E_ADS_REAL_EMPTY, ReleaseGuard.E_APPLICATION_ID,
			ReleaseGuard.E_VERSION_CODE, ReleaseGuard.E_KEYSTORE_MISSING, ReleaseGuard.E_PRIVACY_URL, ReleaseGuard.E_NOT_AAB,
			ReleaseGuard.E_TARGET_SDK, ReleaseGuard.E_BILLING_OFF]:
		assert_true(errors.has(code), code)


func test_test_mode_rejected() -> void:
	var config: Dictionary = _good()
	config["ads_mode"] = "test"
	_expect(config, ReleaseGuard.E_ADS_NOT_REAL)


func test_empty_real_ids_rejected() -> void:
	var config: Dictionary = _good()
	config["ads_real"] = {"app_id": REAL_APP, "rewarded_unit": "", "interstitial_unit": REAL_INTERSTITIAL}
	_expect(config, ReleaseGuard.E_ADS_REAL_EMPTY)


func test_google_test_ids_rejected() -> void:
	var config: Dictionary = _good()
	config["ads_real"] = {"app_id": "ca-app-pub-3940256099942544~3347511713",
		"rewarded_unit": "ca-app-pub-3940256099942544/5224354917", "interstitial_unit": REAL_INTERSTITIAL}
	_expect(config, ReleaseGuard.E_ADS_TEST_ID)


func test_malformed_ads_id_rejected() -> void:
	var config: Dictionary = _good()
	config["ads_real"] = {"app_id": REAL_APP, "rewarded_unit": "ca-app-pub-123/456", "interstitial_unit": REAL_INTERSTITIAL}
	_expect(config, ReleaseGuard.E_ADS_BAD_FORMAT)


func test_manifest_cfg_must_be_synced() -> void:
	var config: Dictionary = _good()
	config["admob_cfg_release_app_id"] = "ca-app-pub-3940256099942544~3347511713"
	_expect(config, ReleaseGuard.E_ADS_CFG_NOT_SYNCED)
	config = _good()
	config["admob_cfg_is_real"] = false
	_expect(config, ReleaseGuard.E_ADS_CFG_NOT_SYNCED)


func test_billing_must_be_on() -> void:
	var config: Dictionary = _good()
	config["play_billing"] = false
	_expect(config, ReleaseGuard.E_BILLING_OFF)


func test_placeholder_package_rejected() -> void:
	for bad: String in ["com.example.dovizburosu", "com.example", "com.godot.game", "org.godotengine.app", "com.foo.game.test", "com.foo.debug"]:
		var config: Dictionary = _good()
		config["application_id"] = bad
		_expect(config, ReleaseGuard.E_APPLICATION_ID_PLACEHOLDER)


func test_invalid_package_rejected() -> void:
	for bad: String in ["", "dovizburosu", "Com.Foo.Bar", "com.1foo.bar", "com..bar"]:
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


func test_missing_keystore_rejected() -> void:
	var config: Dictionary = _good()
	config["release_keystore_ready"] = false
	_expect(config, ReleaseGuard.E_KEYSTORE_MISSING)


func test_version_must_be_bumped() -> void:
	var config: Dictionary = _good()
	config["version_code"] = 1
	_expect(config, ReleaseGuard.E_VERSION_NOT_BUMPED)
	config["version_code"] = 0
	_expect(config, ReleaseGuard.E_VERSION_CODE)


func test_version_name_rules() -> void:
	var config: Dictionary = _good()
	config["version_name"] = " "
	_expect(config, ReleaseGuard.E_VERSION_NAME)
	config = _good()
	config["project_version"] = "0.0.1"
	_expect(config, ReleaseGuard.E_VERSION_MISMATCH)


func test_sdk_levels() -> void:
	var config: Dictionary = _good()
	config["target_sdk"] = 35
	_expect(config, ReleaseGuard.E_TARGET_SDK)
	config = _good()
	config["min_sdk"] = 21
	_expect(config, ReleaseGuard.E_MIN_SDK)


func test_must_be_aab_arm64_only() -> void:
	var config: Dictionary = _good()
	config["export_format"] = 0
	_expect(config, ReleaseGuard.E_NOT_AAB)
	config = _good()
	config["architectures"] = ["arm64-v8a", "x86_64"]
	_expect(config, ReleaseGuard.E_ABI)


func test_permissions() -> void:
	var config: Dictionary = _good()
	config["permissions"] = PERMS + ["android.permission.READ_CONTACTS"]
	_expect(config, ReleaseGuard.E_PERMISSION)
	config = _good()
	config["permissions"] = ["android.permission.INTERNET", "android.permission.ACCESS_NETWORK_STATE"]
	_expect(config, ReleaseGuard.E_PERMISSION_MISSING)  # VIBRATE eksik
	assert_true(ReleaseGuard.permission_allowed("com.dovizburosu.game.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION"))
	assert_false(ReleaseGuard.permission_allowed("android.permission.CAMERA"))


func test_privacy_url_rules() -> void:
	for bad: String in ["", "http://owner.org/p", "https://example.com/privacy", "owner.org/privacy"]:
		var config: Dictionary = _good()
		config["privacy_policy_url"] = bad
		_expect(config, ReleaseGuard.E_PRIVACY_URL)


func test_artifact_identity_and_levels() -> void:
	var info: Dictionary = _good_info()
	(info["manifest"] as Dictionary)["package"] = "com.example.dovizburosu"
	_expect_artifact(info, ReleaseGuard.E_AAB_PACKAGE)
	info = _good_info()
	(info["manifest"] as Dictionary)["versionCode"] = "1"
	_expect_artifact(info, ReleaseGuard.E_AAB_VERSION)
	info = _good_info()
	(info["manifest"] as Dictionary)["targetSdkVersion"] = "34"
	_expect_artifact(info, ReleaseGuard.E_AAB_TARGET_SDK)
	info = _good_info()
	(info["manifest"] as Dictionary)["debuggable"] = "true"
	_expect_artifact(info, ReleaseGuard.E_AAB_DEBUGGABLE)
	info = _good_info()
	(info["manifest"] as Dictionary)["screenOrientations"] = ["landscape"]
	_expect_artifact(info, ReleaseGuard.E_AAB_ORIENTATION)


func test_artifact_ads_and_signing() -> void:
	var info: Dictionary = _good_info()
	(info["manifest"] as Dictionary)["appId"] = "ca-app-pub-3940256099942544~3347511713"
	_expect_artifact(info, ReleaseGuard.E_AAB_APP_ID)
	info = _good_info()
	(info["shipped_ads_ids"] as Dictionary)["mode"] = "test"
	_expect_artifact(info, ReleaseGuard.E_AAB_ADS_MODE)
	info = _good_info()
	info.erase("shipped_ads_ids")
	_expect_artifact(info, ReleaseGuard.E_AAB_ADS_MODE)
	info = _good_info()
	info["signature_files"] = []
	_expect_artifact(info, ReleaseGuard.E_AAB_UNSIGNED)
	info = _good_info()
	info["debug_certificate"] = true
	_expect_artifact(info, ReleaseGuard.E_AAB_DEBUG_CERT)


func test_artifact_permissions_and_libs() -> void:
	var info: Dictionary = _good_info()
	(info["manifest"] as Dictionary)["permissions"] = PERMS + ["android.permission.CAMERA"]
	_expect_artifact(info, ReleaseGuard.E_AAB_PERMISSION)
	info = _good_info()
	(info["manifest"] as Dictionary)["permissions"] = ["android.permission.INTERNET"]
	_expect_artifact(info, ReleaseGuard.E_AAB_PERMISSION_MISSING)
	info = _good_info()
	info["native_libs"] = {"arm64-v8a": {"a.so": {"min_load_align": 4096, "bytes": 1}}}
	_expect_artifact(info, ReleaseGuard.E_AAB_16K)
	info = _good_info()
	info["native_libs"] = {}
	_expect_artifact(info, ReleaseGuard.E_AAB_16K)
	info = _good_info()
	(info["native_libs"] as Dictionary)["x86_64"] = {"a.so": {"min_load_align": 16384, "bytes": 1}}
	_expect_artifact(info, ReleaseGuard.E_AAB_ABI)


func test_every_code_is_described() -> void:
	for code: String in ReleaseGuard.DESCRIPTIONS:
		assert_ne(ReleaseGuard.describe(code), code, "%s açıklaması" % code)
	assert_eq(ReleaseGuard.describe("bilinmeyen"), "bilinmeyen")

