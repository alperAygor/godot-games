extends "res://tests/session_case.gd"
## Tek onay deneyimi: UMP'nin geçerli olduğu bölgede yalnız UMP, diğerlerinde kısa bilgi penceresi; kişiselleştirme ayrı anahtar;
## analitik vaadi yok; gizlilik politikası bağlantısı (tek yer tutucu adres); SDK onaydan önce başlamaz. Saf kurallar: ConsentFlow, AdsConfig.

var settings: Node
var monetization: Node
var analytics: Node
var _saved_personalized := false
var _saved_resolved := false
var _saved_regime := ConsentFlow.REGIME_UNKNOWN


class RecordingAds extends MockAdsProvider:
	var seen: Array = []
	var answered: Array = []
	var privacy_calls := 0

	func set_personalization(allowed: bool) -> void:
		seen.append(allowed)

	func set_notice_answered(value: bool) -> void:
		answered.append(value)

	func show_privacy_options() -> bool:
		privacy_calls += 1
		return regime == ConsentFlow.REGIME_FORM


func before_each() -> void:
	super.before_each()
	settings = tree.root.get_node("SettingsManager")
	monetization = tree.root.get_node("Monetization")
	analytics = tree.root.get_node("Analytics")
	_saved_personalized = bool(settings.get_value("game", "ads_personalized"))
	_saved_resolved = monetization.consent_resolved
	_saved_regime = monetization.consent_regime
	settings.set_value("game", "consent_asked", false, false)
	settings.set_value("game", "ads_personalized", false, false)
	_resolve(ConsentFlow.REGIME_NOTICE)


func after_each() -> void:
	settings.set_value("game", "ads_personalized", _saved_personalized, false)
	monetization.consent_resolved = _saved_resolved
	monetization.consent_regime = _saved_regime
	await super.after_each()


func _resolve(regime: String) -> void:
	monetization.consent_resolved = true
	monetization.consent_regime = regime


# --- Saf kurallar -------------------------------------------------------------------------------

func test_regime_comes_from_the_ump_status() -> void:
	assert_eq(ConsentFlow.regime_for_status("REQUIRED"), ConsentFlow.REGIME_FORM)
	assert_eq(ConsentFlow.regime_for_status("OBTAINED"), ConsentFlow.REGIME_FORM)
	assert_eq(ConsentFlow.regime_for_status("NOT_REQUIRED"), ConsentFlow.REGIME_NOTICE)
	assert_eq(ConsentFlow.regime_for_status("UNKNOWN"), ConsentFlow.REGIME_NOTICE, "bölge bilinemezse dürüst varsayılan: bilgi penceresi")
	assert_eq(ConsentFlow.regime_for_status(""), ConsentFlow.REGIME_NOTICE)


func test_the_games_notice_is_needed_only_outside_ump_regions_and_only_once() -> void:
	assert_true(ConsentFlow.notice_needed(ConsentFlow.REGIME_NOTICE, false))
	assert_false(ConsentFlow.notice_needed(ConsentFlow.REGIME_NOTICE, true), "bir kez sorulur")
	assert_false(ConsentFlow.notice_needed(ConsentFlow.REGIME_FORM, false), "UMP bölgesinde oyun penceresi YOK (çift gösterim kalktı)")
	assert_false(ConsentFlow.notice_needed(ConsentFlow.REGIME_NONE, false), "reklam SDK'sı yoksa sorulacak şey yok")
	assert_false(ConsentFlow.notice_needed(ConsentFlow.REGIME_UNKNOWN, false), "UMP bitmeden sorulmaz")


func test_the_sdk_starts_only_after_consent_is_resolved() -> void:
	assert_false(ConsentFlow.sdk_may_start(ConsentFlow.REGIME_UNKNOWN, true))
	assert_false(ConsentFlow.sdk_may_start(ConsentFlow.REGIME_NOTICE, false), "pencere yanıtlanmadan reklam isteği yok")
	assert_true(ConsentFlow.sdk_may_start(ConsentFlow.REGIME_NOTICE, true))
	assert_true(ConsentFlow.sdk_may_start(ConsentFlow.REGIME_FORM, false), "UMP formu yeterli")
	assert_false(ConsentFlow.sdk_may_start(ConsentFlow.REGIME_NONE, true))


func test_personalization_is_umps_in_ump_regions_and_the_players_elsewhere() -> void:
	assert_true(ConsentFlow.personalization_for(ConsentFlow.REGIME_FORM, false))
	assert_false(ConsentFlow.personalization_for(ConsentFlow.REGIME_NOTICE, false))
	assert_true(ConsentFlow.personalization_for(ConsentFlow.REGIME_NOTICE, true))


func test_privacy_policy_link_is_hidden_while_placeholder_in_release() -> void:
	var placeholder := "https://example.com/doviz-burosu/privacy-placeholder"
	assert_false(AdsConfig.policy_url_visible(placeholder, true), "yayın sürümünde yer tutucu gizli")
	assert_true(AdsConfig.policy_url_visible(placeholder, false), "hata ayıklamada görünür (tasarım kontrolü)")
	assert_false(AdsConfig.policy_url_visible("", false))
	assert_false(AdsConfig.policy_url_visible("http://owner.org/p", false), "https olmayan gösterilmez")
	assert_true(AdsConfig.policy_url_visible("https://owner.org/privacy", true))


func test_the_single_privacy_url_is_the_one_the_release_gate_reads() -> void:
	var url := str(JsonIO.read_dict("res://data/ads_ids.json").get("privacy_policy_url", ""))
	assert_true(url.begins_with("https://") and url.contains(AdsConfig.PLACEHOLDER_MARKER), "kayıtlı adres yer tutucu")
	assert_eq(monetization.privacy_policy_url(), url)
	assert_eq(AdsConfig.PLACEHOLDER_MARKER, ReleaseGuard.PRIVACY_URL_PLACEHOLDER_MARKER, "kapı ve oyun aynı yer tutucu işaretini kullanır")
	assert_true(ReleaseGuard.check_store({"privacy_policy_url": url}).has(ReleaseGuard.E_PRIVACY_URL), "yer tutucu yayın kapısından geçmez")
	assert_false(FileAccess.get_file_as_string("res://tools/release_state.json").contains("privacy_policy_url\": \"\""), "ikinci bir adres alanı kalmadı")


func test_ads_config_problems() -> void:
	var test_ids := {"test_app_id": "a", "test_rewarded_unit": "b", "test_interstitial_unit": "c"}
	assert_eq(AdsConfig.problem({"mode": "test", "android": test_ids}), "")
	assert_eq(AdsConfig.problem({"mode": "test", "android": {}}), AdsConfig.PROBLEM_TEST_IDS_MISSING)
	assert_eq(AdsConfig.problem({"mode": "live", "android": test_ids}), AdsConfig.PROBLEM_BAD_MODE)
	var real := test_ids.merged({"real_app_id": "ca-app-pub-1~2", "real_rewarded_unit": "ca-app-pub-1/3", "real_interstitial_unit": ""})
	assert_eq(AdsConfig.problem({"mode": "real", "android": real}), AdsConfig.PROBLEM_REAL_INCOMPLETE)
	real["real_interstitial_unit"] = "ca-app-pub-1/4"
	assert_eq(AdsConfig.problem({"mode": "real", "android": real}), "")
	assert_true(AdsConfig.is_real({"mode": "real", "android": real}))
	real["real_rewarded_unit"] = "ca-app-pub-3940256099942544/5224354917"
	assert_eq(AdsConfig.problem({"mode": "real", "android": real}), AdsConfig.PROBLEM_REAL_IS_TEST)
	assert_false(AdsConfig.is_real({"mode": "real", "android": real}), "real kipte test kimliği asla gerçek sayılmaz")


# --- İlk açılış sırası -----------------------------------------------------------------------------

func test_the_first_launch_outside_ump_regions_asks_once_before_anything_else() -> void:
	await scenes.goto(Scenes.MAIN)
	await tree.process_frame
	assert_true(node("ConsentSheet") != null)
	assert_true(node("ConsentAcceptButton") != null and node("ConsentDeclineButton") != null)
	assert_true(node("ConsentFormButton") == null, "UMP düğmesi yalnız UMP bölgesinde")


func test_in_ump_regions_the_first_launch_shows_no_game_dialog() -> void:
	_resolve(ConsentFlow.REGIME_FORM)
	await scenes.goto(Scenes.MAIN)
	await tree.process_frame
	assert_true(node("ConsentSheet") == null, "yalnız Google'ın UMP formu çıkar; oyun penceresi ikinci kez sormaz")


func test_the_notice_waits_for_the_consent_step_and_appears_when_it_resolves() -> void:
	monetization.consent_resolved = false
	monetization.consent_regime = ConsentFlow.REGIME_UNKNOWN
	await scenes.goto(Scenes.MAIN)
	await tree.process_frame
	assert_true(node("ConsentSheet") == null, "UMP bitmeden sorulmaz")
	assert_false(monetization.consent_needed())
	var provider := MockAdsProvider.new()
	tree.root.get_node("Ads").set_provider(provider)
	monetization._on_consent_finished()  # UMP bitti: bu bölgede form yok
	await tree.process_frame
	assert_true(node("ConsentSheet") != null)


func test_resolving_to_ump_or_no_sdk_never_raises_the_notice() -> void:
	var provider := MockAdsProvider.new()
	var raised := [0]
	monetization.notice_needed.connect(func() -> void: raised[0] += 1, CONNECT_ONE_SHOT)
	tree.root.get_node("Ads").set_provider(provider)
	provider.regime = ConsentFlow.REGIME_FORM
	monetization._on_consent_finished()
	assert_eq(raised[0], 0)
	provider.regime = ConsentFlow.REGIME_NONE
	monetization._on_consent_finished()
	assert_eq(raised[0], 0)
	assert_false(monetization.consent_needed())
	provider.regime = ConsentFlow.REGIME_NOTICE
	monetization._on_consent_finished()
	assert_eq(raised[0], 1)


func test_accepting_personalizes_ads_and_is_remembered() -> void:
	var provider := RecordingAds.new()
	tree.root.get_node("Ads").set_provider(provider)
	await scenes.goto(Scenes.MAIN)
	await tree.process_frame
	await tap("ConsentAcceptButton")
	await tree.process_frame
	assert_true(bool(settings.get_value("game", "ads_personalized")))
	assert_true(bool(settings.get_value("game", "consent_asked")))
	assert_eq(provider.seen, [true])
	assert_eq(provider.answered, [true], "SDK bu karardan sonra başlayabilir")
	assert_true(node("ConsentSheet") == null, "pencere kapanır")
	await scenes.goto(Scenes.MAIN)
	await tree.process_frame
	assert_true(node("ConsentSheet") == null, "bir daha sorulmaz")


func test_declining_means_non_personalized_ads_and_asks_only_once() -> void:
	var provider := RecordingAds.new()
	tree.root.get_node("Ads").set_provider(provider)
	await scenes.goto(Scenes.MAIN)
	await tree.process_frame
	await tap("ConsentDeclineButton")
	await tree.process_frame
	assert_false(bool(settings.get_value("game", "ads_personalized")))
	assert_true(bool(settings.get_value("game", "consent_asked")), "ret de bir karardır")
	assert_eq(provider.seen, [false])
	assert_eq(provider.answered, [true], "kişiselleştirilmemiş reklamla da SDK başlar")


func test_the_choice_is_personalization_only_and_there_is_no_analytics_path() -> void:
	assert_false(analytics.has_method("_send"), "ölü gönderim yolu kaldırıldı")
	assert_false(analytics.has_method("set_consent"))
	analytics.log_event("probe", {})
	assert_eq(analytics.recent.back()["name"], "probe", "yerel günlük (bellekte) çalışır")
	assert_false(SettingsManager.DEFAULTS["game"].has("analytics_consent"), "eski analitik anahtarı kullanılmaz")


func test_the_shown_text_makes_no_analytics_promise() -> void:
	for key in ["MON_NOTICE_TEXT", "MON_FORM_TEXT"]:
		for locale in ["en", "tr"]:
			TranslationServer.set_locale(locale)
			var text := TranslationServer.translate(key).to_lower()
			assert_false(text.contains("improve the game") or text.contains("usage data") or text.contains("kullanım verisi toplayabil"), "%s/%s analitik vaat etmemeli" % [key, locale])
			assert_true(text.contains("analytic") or text.contains("analitik"), "%s/%s analitik OLMADIĞINI söylemeli" % [key, locale])
	SettingsManager.apply_language()


func test_settings_privacy_button_reopens_the_choice() -> void:
	settings.set_value("game", "consent_asked", true, false)
	var provider := RecordingAds.new()
	tree.root.get_node("Ads").set_provider(provider)
	await scenes.goto(Scenes.SETTINGS)
	await tree.process_frame
	await tap("PrivacyButton")
	await tree.process_frame
	assert_true(node("ConsentSheet") != null)
	assert_eq(provider.privacy_calls, 0, "UMP bölgesi değilse UMP formu açılmaz")
	await tap("ConsentAcceptButton")
	await tree.process_frame
	assert_true(bool(settings.get_value("game", "ads_personalized")))


func test_in_ump_regions_settings_offers_the_ump_form_and_the_policy_link() -> void:
	settings.set_value("game", "consent_asked", true, false)
	_resolve(ConsentFlow.REGIME_FORM)
	var provider := RecordingAds.new()
	provider.regime = ConsentFlow.REGIME_FORM
	tree.root.get_node("Ads").set_provider(provider)
	await scenes.goto(Scenes.SETTINGS)
	await tree.process_frame
	await tap("PrivacyButton")
	await tree.process_frame
	assert_true(node("ConsentFormButton") != null)
	assert_true(node("ConsentAcceptButton") == null, "kişiselleştirme kararı UMP'nindir")
	assert_true(node("PrivacyPolicyButton") != null, "hata ayıklamada yer tutucu adres görünür")
	await tap("ConsentFormButton")
	await tree.process_frame
	assert_eq(provider.privacy_calls, 1)
	assert_true(node("ConsentSheet") == null)
	assert_false(monetization.open_provider_privacy_options(), "eski çağrı artık UMP'yi açmaz (çift pencere olmasın)")
