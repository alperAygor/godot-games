extends TestCase

## Arayüz yardımcıları: güvenli alan asgari boşluğu, dokunma hedefi, sayı biçimi, düğme üretimi.

func test_safe_insets_keep_minimum_margins() -> void:
	var insets: Vector4 = UiKit.safe_insets(Vector2(1080.0, 1920.0))
	assert_true(insets.y >= UiKit.MIN_TOP_MARGIN, "üst boşluk asgariden az olamaz")
	assert_true(insets.w >= UiKit.MIN_BOTTOM_MARGIN, "alt boşluk asgariden az olamaz")


func test_ad_button_gap_is_at_least_16dp() -> void:
	assert_true(UiKit.AD_BUTTON_GAP >= 42.0, "reklam ile devam düğmesi arası >= 42 px")


func test_touch_target_is_at_least_126() -> void:
	var button: UiIconButton = UiIconButton.new()
	add_node(button)
	button.setup("lucide/pause")
	assert_true(button.custom_minimum_size.x >= 126.0, "dokunma hedefi >= 126 px")
	button.free()


func test_button_never_smaller_than_touch_target() -> void:
	var button: Button = UiKit.button("x", &"", "", 40.0)
	assert_true(button.custom_minimum_size.y >= UiKit.MIN_TOUCH)
	button.free()


func test_set_button_text_works_with_and_without_icon() -> void:
	var plain: Button = UiKit.button("a", &"", "", 130.0)
	UiKit.set_button_text(plain, "b")
	assert_eq(plain.text, "b")
	var with_icon: Button = UiKit.button("a", &"", "lucide/play", 130.0)
	UiKit.set_button_text(with_icon, "c")
	assert_eq((with_icon.get_meta(UiKit.CAPTION_META) as Label).text, "c")
	plain.free()
	with_icon.free()


func test_fmt_int_groups_thousands_per_language() -> void:
	Loc.set_language(Loc.LANG_TR)
	assert_eq(UiKit.fmt_int(999), "999")
	assert_eq(UiKit.fmt_int(1234), "1234", "dört haneye kadar ayraçsız")
	assert_eq(UiKit.fmt_int(12480), "12.480")
	Loc.set_language(Loc.LANG_EN)
	assert_eq(UiKit.fmt_int(12480), "12,480")
	assert_eq(UiKit.fmt_int(-1234567), "-1,234,567")
	Loc.set_language(Loc.LANG_TR)


func test_tokens_match_theme_json() -> void:
	var theme: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/theme.json")) as Dictionary
	assert_eq(UiTokens.TYPE_TITLE, int((theme["type"] as Dictionary)["title"]), "ui_tokens.gd güncel (build_theme.py)")
	assert_eq(UiTokens.C_PRIMARY.to_html(false).to_lower(), String((theme["palette"] as Dictionary)["primary"]).trim_prefix("#").to_lower())
