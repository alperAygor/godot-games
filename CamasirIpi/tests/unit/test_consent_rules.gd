extends TestCase

## UMP durum kuralları (saf): hangi durumda reklam istenebilir / form gösterilir / giriş görünür.

func test_ads_only_when_consent_not_required_or_obtained() -> void:
	assert_true(ConsentRules.can_request_ads(ConsentRules.STATUS_NOT_REQUIRED))
	assert_true(ConsentRules.can_request_ads(ConsentRules.STATUS_OBTAINED))
	assert_false(ConsentRules.can_request_ads(ConsentRules.STATUS_REQUIRED), "AB'de onay verilmedi")
	assert_false(ConsentRules.can_request_ads(ConsentRules.STATUS_UNKNOWN), "bilinmiyorsa istenmez")
	assert_false(ConsentRules.can_request_ads(99))


func test_form_only_when_required_and_available() -> void:
	assert_true(ConsentRules.should_show_form(ConsentRules.STATUS_REQUIRED, true))
	assert_false(ConsentRules.should_show_form(ConsentRules.STATUS_REQUIRED, false))
	assert_false(ConsentRules.should_show_form(ConsentRules.STATUS_OBTAINED, true))
	assert_false(ConsentRules.should_show_form(ConsentRules.STATUS_NOT_REQUIRED, true))


func test_privacy_options_entry_only_when_required() -> void:
	assert_true(ConsentRules.privacy_options_visible(ConsentRules.PRIVACY_REQUIRED))
	assert_false(ConsentRules.privacy_options_visible(ConsentRules.PRIVACY_NOT_REQUIRED))
	assert_false(ConsentRules.privacy_options_visible(ConsentRules.PRIVACY_UNKNOWN))
