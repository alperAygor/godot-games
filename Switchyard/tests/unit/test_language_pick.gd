extends TestCase

## LanguagePick ve Loc.apply_saved: kayıtlı seçim kazanır; yoksa cihaz dili destekleniyorsa o; yoksa İngilizce.
## Cihaz yerel adı DIŞARIDAN verilir: test bu makinenin diline (Türkçe) bağlı değildir.

const SUPPORTED: Array[String] = ["tr", "en", "es"]

var _progress: Node = null
var _old_persist: bool = true


func before_each() -> void:
	_progress = autoload_node("Progress")
	_old_persist = bool(_progress.get("persist"))
	_progress.set("persist", false)
	_progress.call("reset_state")


func after_each() -> void:
	_progress.call("reset_state")
	_progress.set("persist", _old_persist)
	Loc.set_language(Loc.LANG_EN)


func test_saved_choice_wins_over_device() -> void:
	assert_eq(LanguagePick.resolve("es", "tr_TR", SUPPORTED), "es")
	assert_eq(LanguagePick.resolve("en", "tr_TR", SUPPORTED), "en")


func test_device_language_used_when_supported() -> void:
	assert_eq(LanguagePick.resolve("", "tr_TR", SUPPORTED), "tr")
	assert_eq(LanguagePick.resolve("", "es-MX", SUPPORTED), "es")
	assert_eq(LanguagePick.resolve("", "en_US.UTF-8", SUPPORTED), "en")
	assert_eq(LanguagePick.resolve("", "ES", SUPPORTED), "es")


func test_unsupported_device_language_is_english() -> void:
	assert_eq(LanguagePick.resolve("", "de_DE", SUPPORTED), "en")
	assert_eq(LanguagePick.resolve("", "zh_Hans_CN", SUPPORTED), "en")
	assert_eq(LanguagePick.resolve("", "", SUPPORTED), "en")
	assert_eq(LanguagePick.resolve("", "   ", SUPPORTED), "en")


func test_unsupported_saved_value_falls_through_to_device() -> void:
	assert_eq(LanguagePick.resolve("fr", "tr_TR", SUPPORTED), "tr")
	assert_eq(LanguagePick.resolve("fr", "de_DE", SUPPORTED), "en")


func test_language_of_parses_locale_names() -> void:
	assert_eq(LanguagePick.language_of("tr_TR"), "tr")
	assert_eq(LanguagePick.language_of("en-US"), "en")
	assert_eq(LanguagePick.language_of("zh_Hans_CN"), "zh")
	assert_eq(LanguagePick.language_of(""), "")


func test_apply_saved_follows_device_when_nothing_saved() -> void:
	assert_eq(Loc.apply_saved("es_ES"), "es")
	assert_eq(Loc.language(), "es")
	assert_eq(Loc.apply_saved("ja_JP"), "en")
	assert_eq(Loc.language(), "en")
	assert_eq(String(_progress.call("module_value", Loc.SETTINGS_SECTION, Loc.SETTINGS_KEY, "")), "",
		"cihaz dili kayda yazılmaz: sonradan değişirse oyun da izler")


func test_apply_saved_prefers_players_choice() -> void:
	Loc.choose("tr")
	assert_eq(Loc.apply_saved("es_ES"), "tr")
	assert_eq(Loc.language(), "tr")


func test_fallback_locale_is_english_in_project() -> void:
	assert_eq(String(ProjectSettings.get_setting("internationalization/locale/fallback")), "en")
