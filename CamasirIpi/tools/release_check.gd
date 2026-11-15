extends SceneTree

## Yayın denetimi: yapılandırmayı toplar, `ReleaseGuard` ile denetler, PASS/FAIL listesi basar.
## Çıkış kodu: 0 hepsi geçti, 1 en az bir hata. Sahibin yapması gereken şeylerde BAŞARISIZ olması beklenir.
##   godot --headless --path . -s res://tools/release_check.gd -- [--aab-info=/mutlak/yol/aab_info.json]
## Çağrı: tools/release_check.sh (AAB varsa önce tools/aab_inspect.py --json çalıştırır).
## GİZLİLİK: anahtar yolu/şifresi/kimlikler asla basılmaz; yalnız "tanımlı/değil" yazılır.

const PRESET_NAME: String = "Android (release)"
const ADS_PATH: String = "res://data/ads.json"
const STORE_PATH: String = "res://data/store.json"
const STATE_PATH: String = "res://docs/store/release_state.json"
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
	print("== Yayin denetimi: yapilandirma (%s) ==" % PRESET_NAME)
	_print_group(errors, ["ads_", "project_app_id"], "AdMob")
	_print_group(errors, ["application_id", "export_format"], "Paket")
	_print_group(errors, ["debug_signing", "signing_secret", "release_keystore"], "Imza")
	_print_group(errors, ["version_"], "Surum")
	_print_group(errors, ["target_sdk", "min_sdk", "permission_not_allowed"], "Platform")
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
			_print_info(info)
			_print_group(artifact_errors, ["aab_"], "AAB")
			total += artifact_errors.size()
		else:
			print("  FAIL  aab_info okunamadi: %s" % aab_info)
			total += 1
	else:
		print("== Uretilmis AAB: yok (build/release/*.aab bulunamadi; yalniz yapilandirma denetlendi) ==")
	print("")
	if total == 0:
		print("SONUC: GECTI - yayin yapisi alinabilir")
	else:
		print("SONUC: BASARISIZ (%d hata) - yukaridaki FAIL satirlari giderilmeden Play'e yuklenmez" % total)
		_exit_code = 1


## Bir gruptaki PASS/FAIL satırları: grup başlığı + o gruba ait hata kodları (varsa) ya da PASS.
func _print_group(errors: Array[String], prefixes: Array, title: String) -> void:
	var group_errors: Array[String] = []
	for code: String in errors:
		for prefix: Variant in prefixes:
			if code.begins_with(String(prefix)) or code.contains(String(prefix)):
				group_errors.append(code)
				break
	if group_errors.is_empty():
		print("  PASS  %s" % title)
		return
	for code: String in group_errors:
		print("  FAIL  %s: %s [%s]" % [title, ReleaseGuard.describe(code), code])


func _print_info(info: Dictionary) -> void:
	var manifest: Dictionary = info.get("manifest", {}) as Dictionary
	print("  bilgi  paket=%s versionCode=%s versionName=%s min=%s target=%s boyut=%.1f MiB" % [
		manifest.get("package"), manifest.get("versionCode"), manifest.get("versionName"),
		manifest.get("minSdkVersion"), manifest.get("targetSdkVersion"),
		float(info.get("size_bytes", 0)) / 1048576.0])
	print("  bilgi  izinler=%s" % str(manifest.get("permissions", [])))


func _collect() -> Dictionary:
	var config: Dictionary = {}
	var ads: Dictionary = _read_json(ADS_PATH).get("admob", {}) as Dictionary
	config["ads_mode"] = ads.get("mode", "test")
	config["ads_production"] = ads.get("production", {})
	config["ads_request_consent"] = bool(ads.get("request_consent", true))
	var project: ConfigFile = ConfigFile.new()
	project.load("res://project.godot")
	config["project_app_id"] = String(project.get_value("admob", "general/android/app_id", ""))
	var presets: ConfigFile = ConfigFile.new()
	presets.load("res://export_presets.cfg")
	var section: String = ""
	for candidate: String in presets.get_sections():
		if candidate.ends_with(".options"):
			continue
		if String(presets.get_value(candidate, "name", "")) == PRESET_NAME:
			section = candidate
	var options: String = section + ".options"
	config["application_id"] = String(presets.get_value(options, "package/unique_name", ""))
	config["version_code"] = int(presets.get_value(options, "version/code", 0))
	config["version_name"] = String(presets.get_value(options, "version/name", ""))
	config["target_sdk"] = int(String(presets.get_value(options, "gradle_build/target_sdk", "0")))
	config["min_sdk"] = int(String(presets.get_value(options, "gradle_build/min_sdk", "0")))
	config["export_format"] = int(presets.get_value(options, "gradle_build/export_format", 0))
	var permissions: Array[String] = []
	for key: String in presets.get_section_keys(options):
		if key.begins_with("permissions/") and bool(presets.get_value(options, key, false)):
			permissions.append("android.permission." + key.trim_prefix("permissions/").to_upper())
	config["permissions"] = permissions
	config["signing_secrets_in_preset"] = not (String(presets.get_value(options, "keystore/release", "")).is_empty()
		and String(presets.get_value(options, "keystore/release_user", "")).is_empty()
		and String(presets.get_value(options, "keystore/release_password", "")).is_empty())
	var keystore_path: String = OS.get_environment(ENV_PATH)
	config["release_keystore_ready"] = FileAccess.file_exists(keystore_path) \
		and not OS.get_environment(ENV_USER).is_empty() and not OS.get_environment(ENV_PASSWORD).is_empty() \
		and bool(presets.get_value(options, "package/signed", false))
	# Hata ayıklama anahtarı: yol adında "debug" geçiyorsa ya da kullanıcı varsayılan debug takma adıysa.
	config["debug_signing"] = keystore_path.to_lower().contains("debug") \
		or OS.get_environment(ENV_USER) == "androiddebugkey"
	config["privacy_policy_url"] = String(_read_json(STORE_PATH).get("privacy_policy_url", ""))
	config["last_uploaded_version_code"] = int(_read_json(STATE_PATH).get("last_uploaded_version_code", 0))
	return config


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}
