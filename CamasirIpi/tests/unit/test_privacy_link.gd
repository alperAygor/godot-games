extends TestCase

## Gizlilik politikası bağlantısı: tek yapılandırma değeri, yer tutucu yayında gizlenir.

func test_link_needs_https() -> void:
	assert_false(StoreConfig.privacy_link_visible("", true))
	assert_false(StoreConfig.privacy_link_visible("http://site.org/p", true))
	assert_true(StoreConfig.privacy_link_visible("https://site.org/p", false))


func test_placeholder_visible_only_in_debug() -> void:
	var placeholder: String = "https://example.invalid/clothesline-sort/privacy"
	assert_true(StoreConfig.privacy_link_visible(placeholder, true))
	assert_false(StoreConfig.privacy_link_visible(placeholder, false), "yayın sürümünde yer tutucu gizli")


func test_shipped_config_has_one_clearly_marked_placeholder() -> void:
	var url: String = StoreConfig.privacy_policy_url()
	assert_true(url.begins_with("https://"))
	assert_true(url.contains(StoreConfig.PLACEHOLDER_MARKER), "gerçek adres girilene dek açıkça yer tutucu")
	# Yayın koruması yer tutucuyu reddeder.
	assert_true(ReleaseGuard.check_store({"privacy_policy_url": url}).has(ReleaseGuard.E_PRIVACY_URL))


func test_settings_sheet_shows_policy_button_in_debug() -> void:
	var holder: Control = Control.new()
	add_node(holder)
	var sheet: InfoSheet = InfoSheet.settings(holder)
	var button: Node = sheet.find_child("PrivacyPolicy", true, false)
	if OS.is_debug_build():
		assert_not_null(button, "hata ayıklamada yer tutucu adresle düğme görünür")
	sheet.queue_free()
	holder.queue_free()
