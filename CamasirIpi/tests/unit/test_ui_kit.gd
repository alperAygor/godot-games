extends TestCase

## Arayüz yardımcıları: güvenli alan asgari boşluğu ve reklam düğmesi aralığı kuralı.

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
