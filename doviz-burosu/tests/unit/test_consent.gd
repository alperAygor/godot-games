extends "res://tests/session_case.gd"
## Gizlilik / onay: ilk açılışta soru, kabul/ret, analitik ve reklam kişiselleştirme bağı, Ayarlar > Gizlilik seçenekleri.

var settings: Node
var analytics: Node
var _saved_consent := false


func before_each() -> void:
	super.before_each()
	settings = tree.root.get_node("SettingsManager")
	analytics = tree.root.get_node("Analytics")
	_saved_consent = bool(settings.get_value("game", "analytics_consent"))
	settings.set_value("game", "consent_asked", false, false)
	settings.set_value("game", "analytics_consent", false, false)
	analytics.consent_given = false


func after_each() -> void:
	settings.set_value("game", "analytics_consent", _saved_consent, false)
	analytics.consent_given = _saved_consent
	await super.after_each()


func test_the_first_launch_asks_before_anything_else() -> void:
	await scenes.goto(Scenes.MAIN)
	await tree.process_frame
	assert_true(node("ConsentSheet") != null)
	assert_true(node("ConsentAcceptButton") != null and node("ConsentDeclineButton") != null)


func test_accepting_enables_analytics_and_personalization_and_is_remembered() -> void:
	var provider := MockAdsProvider.new()
	tree.root.get_node("Ads").set_provider(provider)
	await scenes.goto(Scenes.MAIN)
	await tree.process_frame
	await tap("ConsentAcceptButton")
	await tree.process_frame
	assert_true(bool(settings.get_value("game", "analytics_consent")))
	assert_true(bool(settings.get_value("game", "consent_asked")))
	assert_true(analytics.consent_given)
	assert_true(node("ConsentSheet") == null, "pencere kapanır")
	await scenes.goto(Scenes.MAIN)
	await tree.process_frame
	assert_true(node("ConsentSheet") == null, "bir daha sorulmaz")


func test_declining_keeps_analytics_off_and_asks_only_once() -> void:
	await scenes.goto(Scenes.MAIN)
	await tree.process_frame
	await tap("ConsentDeclineButton")
	await tree.process_frame
	assert_false(bool(settings.get_value("game", "analytics_consent")))
	assert_true(bool(settings.get_value("game", "consent_asked")), "ret de bir karardır")
	assert_false(analytics.consent_given)


func test_events_are_kept_in_memory_but_not_sent_without_consent() -> void:
	analytics.consent_given = false
	analytics.log_event("probe", {})
	assert_eq(analytics.recent.back()["name"], "probe")
	assert_false(analytics.consent_given)


class RecordingAds extends MockAdsProvider:
	var seen: Array = []

	func set_personalization(allowed: bool) -> void:
		seen.append(allowed)


func test_personalization_choice_reaches_the_ads_provider() -> void:
	var provider := RecordingAds.new()
	tree.root.get_node("Ads").set_provider(provider)
	var monetization := tree.root.get_node("Monetization")
	monetization.apply_consent(false)
	monetization.apply_consent(true)
	assert_eq(provider.seen, [false, true])
	assert_true(bool(settings.get_value("game", "analytics_consent")))


func test_settings_privacy_button_reopens_the_question() -> void:
	settings.set_value("game", "consent_asked", true, false)
	await scenes.goto(Scenes.SETTINGS)
	await tree.process_frame
	await tap("PrivacyButton")
	await tree.process_frame
	assert_true(node("ConsentSheet") != null)
	await tap("ConsentAcceptButton")
	await tree.process_frame
	assert_true(analytics.consent_given)
