extends "res://tests/test_case.gd"
## Varsayılan dil kuralı: kayıtlı dil kazanır; yoksa cihaz dili (destekleniyorsa); değilse İngilizce.

const SUPPORTED := ["en", "tr"]


func test_device_locale_maps_to_supported_language() -> void:
	assert_eq(LanguagePick.resolve("", "tr_TR", SUPPORTED), "tr")
	assert_eq(LanguagePick.resolve("", "en_US", SUPPORTED), "en")
	assert_eq(LanguagePick.resolve("", "tr", SUPPORTED), "tr")
	assert_eq(LanguagePick.resolve("", "en-GB", SUPPORTED), "en")
	assert_eq(LanguagePick.resolve("", "TR_tr", SUPPORTED), "tr", "büyük/küçük harf fark etmez")


func test_unsupported_or_empty_device_locale_is_english() -> void:
	assert_eq(LanguagePick.resolve("", "de_DE", SUPPORTED), "en")
	assert_eq(LanguagePick.resolve("", "ja_JP", SUPPORTED), "en")
	assert_eq(LanguagePick.resolve("", "zh_Hans_CN", SUPPORTED), "en")
	assert_eq(LanguagePick.resolve("", "", SUPPORTED), "en")
	assert_eq(LanguagePick.resolve("", "   ", SUPPORTED), "en")
	assert_eq(LanguagePick.resolve("", "tr_TR", []), "en", "destek listesi boşsa İngilizce")


func test_saved_language_always_wins() -> void:
	assert_eq(LanguagePick.resolve("en", "tr_TR", SUPPORTED), "en", "oyuncu İngilizce seçti, cihaz Türkçe")
	assert_eq(LanguagePick.resolve("tr", "de_DE", SUPPORTED), "tr", "oyuncu Türkçe seçti, cihaz Almanca")
	assert_eq(LanguagePick.resolve("tr", "", SUPPORTED), "tr")


func test_unsupported_saved_language_falls_through_to_device_then_english() -> void:
	assert_eq(LanguagePick.resolve("xx", "tr_TR", SUPPORTED), "tr")
	assert_eq(LanguagePick.resolve("xx", "de_DE", SUPPORTED), "en")


func test_settings_manager_uses_the_rule_and_default_is_unset() -> void:
	var settings: Node = tree.root.get_node("SettingsManager")
	assert_eq(settings.DEFAULTS["game"]["language"], "", "ilk açılışta dil seçilmemiş (cihaz dili/İngilizce kuralı)")
	var original: String = settings.get_value("game", "language")
	settings.set_value("game", "language", "tr", false)
	assert_eq(settings.apply_language(), "tr")
	assert_eq(TranslationServer.get_locale(), "tr")
	settings.set_value("game", "language", "", false)
	var expected := LanguagePick.resolve("", OS.get_locale(), settings.available_languages().keys())
	assert_eq(settings.apply_language(), expected, "seçim yokken cihaz dili ya da İngilizce")
	settings.set_value("game", "language", original, false)


func test_english_is_the_fallback_locale_and_fallback_constant() -> void:
	assert_eq(LanguagePick.FALLBACK, "en")
	assert_eq(str(ProjectSettings.get_setting("internationalization/locale/fallback")), "en")
	assert_eq(str(JsonIO.read_dict("res://data/languages.json").get("default", "")), "en")
