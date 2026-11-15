extends TestCase

## HomeLayout: ana ekran Oyna düğmesi her en-boy oranında ortalı, güvenli alan içinde, alt-ortada.

const BAR: float = 150.0
const PLAY: float = 150.0
const PLAY_WIDTH: float = 590.0
const STREAK: float = 72.0
const TITLE: float = 156.0
## Görünür alanlar ("expand" esnetmesi, taban 1080x1920): 9:16, 9:19.5, 9:20, 9:21, 720x1280 (9:16
## ile aynı görünüm) ve tablet 3:4 (yükseklik sabit, genişlik açılır).
const VIEWS: Array[Vector2] = [Vector2(1080, 1920), Vector2(1080, 2340), Vector2(1080, 2400),
	Vector2(1080, 2520), Vector2(1440, 1920)]
## Çentik / sistem çubuğu payları: masaüstü varsayılanı ve tipik uzun telefon.
const INSETS: Array[Vector4] = [Vector4(0, 72, 0, 64), Vector4(0, 132, 0, 96), Vector4(24, 110, 24, 140)]


func _each(check: Callable) -> void:
	for view: Vector2 in VIEWS:
		for insets: Vector4 in INSETS:
			check.call(view, insets, HomeLayout.compute(view, insets, BAR, PLAY, STREAK, TITLE))


func test_play_is_horizontally_centred_in_usable_area() -> void:
	_each(func(view: Vector2, insets: Vector4, layout: Dictionary) -> void:
		var centre: Vector2 = layout["play_center"] as Vector2
		var usable: Rect2 = layout["usable"] as Rect2
		assert_almost_eq(centre.x, usable.get_center().x, 0.01, "yatay orta %s" % str(view)))


func test_play_inside_safe_area_and_above_tab_bar() -> void:
	_each(func(view: Vector2, insets: Vector4, layout: Dictionary) -> void:
		var centre: Vector2 = layout["play_center"] as Vector2
		var rect: Rect2 = Rect2(centre - Vector2(PLAY_WIDTH, PLAY) * 0.5, Vector2(PLAY_WIDTH, PLAY))
		var usable: Rect2 = layout["usable"] as Rect2
		assert_true(usable.encloses(rect), "güvenli alan içinde %s %s" % [str(view), str(insets)])
		assert_true(rect.end.y + HomeLayout.PLAY_BAR_CLEARANCE <= float(layout["bar_top"]) + 0.01,
			"alt çubuktan boşluk %s" % str(view)))


func test_play_sits_in_lower_middle() -> void:
	# Ne en altta ne yukarıda: kullanılabilir yüksekliğin %60-%80'i arasında.
	_each(func(view: Vector2, insets: Vector4, layout: Dictionary) -> void:
		var usable: Rect2 = layout["usable"] as Rect2
		var ratio: float = ((layout["play_center"] as Vector2).y - usable.position.y) / usable.size.y
		assert_true(ratio > 0.6 and ratio < 0.8, "alt-orta oran %.2f %s" % [ratio, str(view)]))


func test_same_relative_position_on_tall_phones() -> void:
	# Uzun telefonda Oyna "havada" kalmaz: oran 9:16 ile 9:21 arasında 0.03'ten az oynar.
	var insets: Vector4 = INSETS[0]
	var ratios: Array[float] = []
	for view: Vector2 in [Vector2(1080, 1920), Vector2(1080, 2520)]:
		var layout: Dictionary = HomeLayout.compute(view, insets, BAR, PLAY, STREAK, TITLE)
		var usable: Rect2 = layout["usable"] as Rect2
		ratios.append(((layout["play_center"] as Vector2).y - usable.position.y) / usable.size.y)
	assert_true(absf(ratios[0] - ratios[1]) < 0.03, "oranlar %s" % str(ratios))


func test_vertical_order_has_no_overlap() -> void:
	_each(func(view: Vector2, insets: Vector4, layout: Dictionary) -> void:
		var title_bottom: float = float(layout["title_top"]) + TITLE
		var streak_top: float = float(layout["streak_center_y"]) - STREAK * 0.5
		var streak_bottom: float = float(layout["streak_center_y"]) + STREAK * 0.5
		var play_top: float = (layout["play_center"] as Vector2).y - PLAY * 0.5
		assert_true(float(layout["title_top"]) >= insets.y, "başlık güvenli alanın altında %s" % str(view))
		assert_true(title_bottom < float(layout["rope_y"]), "başlık ipin üstünde %s" % str(view))
		assert_true(float(layout["rope_y"]) < float(layout["rack_y"]), "ip askının üstünde %s" % str(view))
		assert_true(float(layout["rack_y"]) < streak_top, "askı seri göstergesinin üstünde %s" % str(view))
		assert_true(streak_bottom < play_top, "seri Oyna'nın üstünde %s" % str(view)))
