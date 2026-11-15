extends SceneTree

## Yayın denetimi: yapılandırmayı toplar, `ReleaseGuard` ile denetler, PASS/FAIL listesi basar.
## Çıkış kodu: 0 hepsi geçti, 1 en az bir hata. Sahibin yapması gereken şeylerde BAŞARISIZ olması beklenir.
##   godot --headless --path . -s res://tools/release_check.gd -- [--aab-info=/mutlak/yol/aab_info.json] [--config-only]
## Çağrı: tools/release_check.sh (AAB varsa önce tools/aab_inspect.py --json çalıştırır).
## GİZLİLİK: anahtar yolu/şifresi/kimlikler asla basılmaz; yalnız "tanımlı/değil" yazılır.

const PRESET_NAME: String = "Android Release"
const ADS_IDS_PATH: String = "res://data/ads_ids.json"
const ADMOB_CFG_PATH: String = "res://addons/AdmobPlugin/android_export.cfg"
const STATE_PATH: String = "res://tools/release_state.json"
const ENV_PATH: String = "GODOT_ANDROID_KEYSTORE_RELEASE_PATH"
const ENV_USER: String = "GODOT_ANDROID_KEYSTORE_RELEASE_USER"
const ENV_PASSWORD: String = "GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"

var _started: bool = false
var _exit_code: int = 0


func _process(_delta: float) -> bool:
	if _started:
		return true
	_started = true
	_run()
	quit(_exit_code)
	return true


func _run() -> void:
	var config: Dictionary = _collect()
	var errors: Array[String] = ReleaseGuard.check(config)
	print("== Yayin denetimi: yapilandirma (preset '%s') ==" % PRESET_NAME)
	_print_info_config(config)
	_print_group(errors, ["ads_", "play_billing"], "Reklam/Billing")
	_print_group(errors, ["application_id", "export_format", "abi_"], "Paket")
	_print_group(errors, ["debug_signing", "signing_secret", "release_keystore"], "Imza")
	_print_group(errors, ["version_"], "Surum")
	_print_group(errors, ["target_sdk", "min_sdk", "permission_"], "Platform/Izinler")
	_print_group(errors, ["privacy_"], "Magaza")
	var total: int = errors.size()
	var aab_info: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--aab-info="):
			aab_info = arg.substr("--aab-info=".length())
	if not aab_info.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(aab_info))
		if parsed is Dictionary:
			var info: Dictionary = parsed as Dictionary
			var artifact_errors: Array[String] = ReleaseGuard.check_artifact(info, config)
			print("== Uretilmis AAB: %s ==" % String(info.get("file", "?")))
			_print_info_artifact(info)
			_print_group(artifact_errors, ["aab_"], "AAB")
			total += artifact_errors.size()
		else:
			print("  FAIL  aab_info okunamadi: %s" % aab_info)
			total += 1
	else:
		print("== Uretilmis AAB: denetlenmedi (yalniz yapilandirma) ==")
	print("")
	if total == 0:
		print("SONUC: GECTI - yayin yapisi alinabilir")
	else:
		print("SONUC: BASARISIZ (%d hata) - yukaridaki FAIL satirlari giderilmeden Play'e yuklenmez" % total)
		_exit_code = 1


func _print_group(errors: Array[String], prefixes: Array, title: String) -> void:
	var group_errors: Array[String] = []
	for code: String in errors:
		for prefix: Variant in prefixes:
			if code.begins_with(String(prefix)):
				group_errors.append(code)
				break
	if group_errors.is_empty():
		print("  PASS  %s" % title)
		return
	for code: String in group_errors:
		print("  FAIL  %s: %s [%s]" % [title, ReleaseGuard.describe(code), code])


func _print_info_config(config: Dictionary) -> void:
	print("  bilgi  paket=%s versionCode=%s versionName=%s min=%s target=%s ads_mode=%s billing=%s anahtar_env=%s" % [
		config.get("application_id"), config.get("version_code"), config.get("version_name"),
		config.get("min_sdk"), config.get("target_sdk"), config.get("ads_mode"), config.get("play_billing"),
		"tanimli" if config.get("release_keystore_ready") else "yok"])


func _print_info_artifact(info: Dictionary) -> void:
	var manifest: Dictionary = info.get("manifest", {}) as Dictionary
	print("  bilgi  paket=%s versionCode=%s versionName=%s min=%s target=%s boyut=%.1f MiB debuggable=%s" % [
		manifest.get("package"), manifest.get("versionCode"), manifest.get("versionName"),
		manifest.get("minSdkVersion"), manifest.get("targetSdkVersion"),
		float(info.get("size_bytes", 0)) / 1048576.0, manifest.get("debuggable")])
	print("  bilgi  izinler=%s" % str(manifest.get("permissions", [])))


func _collect() -> Dictionary:
	var config: Dictionary = {}
	var ids: Dictionary = _read_json(ADS_IDS_PATH)
	var android: Dictionary = ids.get("android", {}) as Dictionary
	config["ads_mode"] = ids.get("mode", "test")
	config["ads_real"] = {"app_id": android.get("real_app_id", ""), "rewarded_unit": android.get("real_rewarded_unit", ""),
		"interstitial_unit": android.get("real_interstitial_unit", "")}
	config["play_billing"] = bool((ids.get("providers", {}) as Dictionary).get("play_billing", false))
	var admob: ConfigFile = ConfigFile.new()
	admob.load(ADMOB_CFG_PATH)
	config["admob_cfg_is_real"] = bool(admob.get_value("General", "is_real", false))
	config["admob_cfg_release_app_id"] = String(admob.get_value("Release", "app_id", ""))
	var project: ConfigFile = ConfigFile.new()
	project.load("res://project.godot")
	config["project_version"] = String(project.get_value("application", "config/version", ""))
	var presets: ConfigFile = ConfigFile.new()
	presets.load("res://export_presets.cfg")
	var section: String = ""
	for candidate: String in presets.get_sections():
		if not candidate.ends_with(".options") and String(presets.get_value(candidate, "name", "")) == PRESET_NAME:
			section = candidate
	var options: String = section + ".options"
	config["application_id"] = String(presets.get_value(options, "package/unique_name", ""))
	config["version_code"] = int(presets.get_value(options, "version/code", 0))
	config["version_name"] = String(presets.get_value(options, "version/name", ""))
	config["target_sdk"] = int(String(presets.get_value(options, "gradle_build/target_sdk", "0")))
	config["min_sdk"] = int(String(presets.get_value(options, "gradle_build/min_sdk", "0")))
	config["export_format"] = int(presets.get_value(options, "gradle_build/export_format", 0))
	var architectures: Array[String] = []
	for key: String in presets.get_section_keys(options) if presets.has_section(options) else PackedStringArray():
		if key.begins_with("architectures/") and bool(presets.get_value(options, key, false)):
			architectures.append(key.trim_prefix("architectures/"))
	config["architectures"] = architectures
	var permissions: Array[String] = []
	for key: String in presets.get_section_keys(options) if presets.has_section(options) else PackedStringArray():
		if key.begins_with("permissions/") and bool(presets.get_value(options, key, false)):
			permissions.append("android.permission." + key.trim_prefix("permissions/").to_upper())
	config["permissions"] = permissions
	config["signing_secrets_in_preset"] = not (String(presets.get_value(options, "keystore/release", "")).is_empty()
		and String(presets.get_value(options, "keystore/release_user", "")).is_empty()
		and String(presets.get_value(options, "keystore/release_password", "")).is_empty())
	var keystore_path: String = OS.get_environment(ENV_PATH)
	config["release_keystore_ready"] = not keystore_path.is_empty() and FileAccess.file_exists(keystore_path) \
		and not OS.get_environment(ENV_USER).is_empty() and not OS.get_environment(ENV_PASSWORD).is_empty() \
		and bool(presets.get_value(options, "package/signed", false))
	# Hata ayıklama anahtarı: yol adı Godot'un debug keystore'unu/"debug" adını gösteriyor ya da kullanıcı varsayılan debug takma adı.
	config["debug_signing"] = keystore_path.to_lower().contains("debug") \
		or OS.get_environment(ENV_USER) == "androiddebugkey"
	var state: Dictionary = _read_json(STATE_PATH)
	config["privacy_policy_url"] = String(ids.get("privacy_policy_url", ""))  # TEK kaynak: oyun içi bağlantıyla aynı (data/ads_ids.json)
	config["last_uploaded_version_code"] = int(state.get("last_uploaded_version_code", 0))
	return config


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}
