extends TestCase

## Harita modeli: dünya koordinatı, özel seviye türleri, bölge sınırları, sandıklar.


func before_each() -> void:
	Loc.set_language(Loc.LANG_TR)


func test_world_coordinates_roundtrip() -> void:
	for level: int in [1, 2, 17, 250, 600]:
		assert_almost_eq(MapModel.level_at(MapModel.world_y(float(level))), float(level), 0.0001)
	assert_true(MapModel.world_y(2.0) < MapModel.world_y(1.0), "yeni seviye yukarıda (y küçük)")


func test_rope_stays_inside_screen() -> void:
	var margin: float = MapCanvas.CURRENT_RADIUS + MapCanvas.HALO_EXTRA + MapCanvas.CHEST_SIZE
	var level: float = 1.0
	while level < 200.0:
		var x: float = MapModel.world_x(level)
		assert_true(x > 160.0 and x < 920.0, "sicim kenara taşmamalı (x=%.0f, seviye %.2f)" % [x, level])
		level += 0.37
	assert_true(margin > 0.0)


func test_kinds_follow_generator_modes() -> void:
	var bosses: int = 0
	for level: int in range(1, 241):
		var kind: int = MapModel.kind_for(level)
		var mode: String = LevelGenerator.mode_for(level)
		if mode == LaundryBoard.MODE_BOSS:
			assert_eq(kind, MapModel.Kind.BOSS, "patron %d" % level)
			bosses += 1
		elif mode != LaundryBoard.MODE_NONE:
			assert_true(kind != MapModel.Kind.NORMAL and kind != MapModel.Kind.HARD, "kip %d" % level)
		elif bool(LevelGenerator.params_for(level).get("hard", false)):
			assert_eq(kind, MapModel.Kind.HARD, "zor %d" % level)
		else:
			assert_eq(kind, MapModel.Kind.NORMAL, "normal %d" % level)
	assert_true(bosses >= 10, "haritada patron seviyeleri görünmeli")
	assert_eq(MapModel.kind_for(1), MapModel.Kind.NORMAL)
	assert_eq(MapModel.kind_for(30), MapModel.Kind.BOSS)


func test_dividers_mark_places_and_seasons() -> void:
	var dividers: PackedInt32Array = MapModel.dividers(260)
	for level: int in [1, 31, 41, 61, 81, 91, 121, 151, 161, 181, 201, 211, 241]:
		assert_true(dividers.has(level), "ayraç olmalı: %d" % level)
	for index: int in range(1, dividers.size()):
		assert_true(dividers[index] > dividers[index - 1], "artan sırada")
	assert_false(dividers.has(2))
	assert_eq(MapModel.divider_label(1), "Bahçe · Yaz")
	assert_eq(MapModel.divider_label(31), "Sonbahar")
	assert_eq(MapModel.divider_label(41), "Sahil")
	assert_eq(MapModel.divider_label(121), "Bahçe · Yaz", "döngü başa sarar")
	Loc.set_language(Loc.LANG_EN)
	assert_eq(MapModel.divider_label(31), "Autumn")
	assert_eq(MapModel.divider_label(41), "Seaside")


func test_divider_tints_are_distinct_between_seasons() -> void:
	assert_true(MapModel.tint_for(1) != MapModel.tint_for(31), "mevsim tonu değişmeli")
	assert_true(MapModel.tint_for(1).a > 0.99)


func test_chests_come_from_milestone_data() -> void:
	var chests: Dictionary[int, bool] = MapModel.chest_levels(130)
	for level: int in [5, 10, 15, 20, 30, 40, 50, 60, 70, 100, 110, 120, 130]:
		assert_true(chests.has(level), "sandık: %d" % level)
	assert_false(chests.has(7))
	assert_false(chests.has(131))


func test_total_levels_and_visible_range() -> void:
	assert_eq(MapModel.total_levels(1), MapModel.MIN_LEVELS)
	assert_eq(MapModel.total_levels(500), 500 + MapModel.FUTURE_LEVELS)
	var span: Vector2i = MapModel.visible_range(MapModel.world_y(30.0), MapModel.world_y(20.0), 100, 2)
	assert_true(span.x <= 20 and span.y >= 30, "pencere kapsanmalı")
	assert_true(span.y - span.x < 20, "yalnız görünür aralık (sanallaştırma)")
	var edge: Vector2i = MapModel.visible_range(MapModel.world_y(1.0) + 500.0, MapModel.world_y(1.0) + 2000.0, 100, 2)
	assert_eq(edge.x, 1, "sınırlara kıstırılır")
