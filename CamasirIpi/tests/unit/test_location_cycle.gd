extends TestCase

## LocationCycle: seviye -> mekân eşlemesi, "yeni yer" ilk seviyeleri, mekân paleti ve
## mekân verisinin (katman dosyaları, boyutlar, çapalar) bahçe sözleşmesine uyması.

const GARDEN_DIR: String = "res://assets/sprites/bg/"
## Doku kenarları VRAM sıkıştırma blokları (4x4) için 4'ün katı olmalı.
const BLOCK: int = 4


func test_level_spans_follow_the_journey() -> void:
	assert_eq(LocationCycle.location_for(1), "garden")
	assert_eq(LocationCycle.location_for(40), "garden")
	assert_eq(LocationCycle.location_for(41), "beach")
	assert_eq(LocationCycle.location_for(80), "beach")
	assert_eq(LocationCycle.location_for(81), "rooftop")
	assert_eq(LocationCycle.location_for(120), "rooftop")


func test_cycle_wraps_after_last_location() -> void:
	var length: int = LocationCycle.cycle_length()
	assert_eq(length, 120)
	assert_eq(LocationCycle.location_for(length + 1), "garden")
	assert_eq(LocationCycle.location_for(length + 41), "beach")
	assert_eq(LocationCycle.location_for(length * 3 + 90), "rooftop")


func test_invalid_levels_fall_back_to_first_location() -> void:
	assert_eq(LocationCycle.location_for(0), "garden")
	assert_eq(LocationCycle.location_for(-7), "garden")
	assert_eq(LocationCycle.index_for(-7), 0)


func test_first_level_of_location() -> void:
	for level: int in [1, 41, 81, 121, 161]:
		assert_true(LocationCycle.is_first_level_of_location(level), "seviye %d ilk olmalı" % level)
	for level: int in [2, 40, 42, 52, 80, 90, 120]:
		assert_false(LocationCycle.is_first_level_of_location(level), "seviye %d ilk olmamalı" % level)
	assert_eq(LocationCycle.first_level_of(52), 41)
	assert_eq(LocationCycle.first_level_of(120), 81)
	assert_eq(LocationCycle.first_level_of(125), 121)


func test_every_location_has_name_and_ambience() -> void:
	for index: int in range(LocationCycle.count()):
		var id: String = LocationCycle.id_at(index)
		assert_true(LocationCycle.NAME_KEYS.has(LocationCycle.name_key(id)), "%s ad anahtarı listede yok" % id)
		assert_true(Loc.t(LocationCycle.name_key(id)) != LocationCycle.name_key(id), "%s çevirisi yok" % id)
		assert_false(String(LocationCycle.data_for(id).get("ambience", "")).is_empty(), "%s ortam sesi" % id)
	assert_eq(LocationCycle.ambience_for(52), "waves")


func test_location_layers_exist_and_match_garden_footprint() -> void:
	var garden_pixels: int = _pixels("garden")
	for index: int in range(LocationCycle.count()):
		var id: String = LocationCycle.id_at(index)
		var data: Dictionary = LocationCycle.data_for(id)
		for file_name: String in _files(data):
			var path: String = String(data["dir"]) + file_name + ".png"
			assert_true(ResourceLoader.exists(path), "%s eksik: %s" % [id, path])
			var texture: Texture2D = load(path) as Texture2D
			if texture == null:
				continue
			assert_eq(int(texture.get_width()) % BLOCK, 0, "%s genişlik 4'ün katı değil" % path)
			assert_eq(int(texture.get_height()) % BLOCK, 0, "%s yükseklik 4'ün katı değil" % path)
		# Bütçe: yeni mekânın katmanları bahçeninkinden fazla piksel tutmaz.
		assert_true(_pixels(id) <= garden_pixels, "%s doku bütçesi aşıldı" % id)


func test_layer_anchors_match_garden_contract() -> void:
	var garden: Dictionary = LocationCycle.data_for("garden")
	for index: int in range(LocationCycle.count()):
		var data: Dictionary = LocationCycle.data_for(LocationCycle.id_at(index))
		for key: String in ["back", "front"]:
			var mine: Array = data[key] as Array
			var reference: Array = garden[key] as Array
			assert_eq(mine.size(), reference.size())
			for layer_index: int in range(mine.size()):
				assert_eq((mine[layer_index] as Dictionary)["pos"], (reference[layer_index] as Dictionary)["pos"],
					"%s %s katman konumu" % [data["id"], key])


func test_palette_adjusts_copy_not_shared_day_look() -> void:
	var base: DayLook = DayCycle.look_for_phase(0)
	var base_bottom: Color = base.sky_bottom
	var beach: DayLook = LocationCycle.look_for(0, "beach")
	assert_true(beach != base, "mekân görünümü paylaşılan nesne olmamalı")
	assert_true(beach.sky_bottom != base_bottom, "sahil gökyüzü tabanı ayarlanmalı")
	assert_eq(base.sky_bottom, base_bottom, "DayCycle'ın paylaşılan görünümü bozulmamalı")
	# Önbellek: aynı mekân/aşama aynı nesneyi döndürür (seviye başında yeniden üretilmez).
	assert_true(LocationCycle.look_for(0, "beach") == beach)


func test_phase_override_applies_only_to_named_phase() -> void:
	var night: int = DayCycle.PHASE_COUNT - 1
	assert_eq(LocationCycle.look_for(night, "beach").scenery_tint, Color.html("#6478b4"))
	assert_true(LocationCycle.look_for(1, "beach").scenery_tint != Color.html("#6478b4"))


func test_garden_palette_is_unchanged() -> void:
	for phase: int in range(DayCycle.PHASE_COUNT):
		var garden: DayLook = LocationCycle.look_for(phase, "garden")
		var base: DayLook = DayCycle.look_for_phase(phase)
		assert_eq(garden.sky_top, base.sky_top)
		assert_eq(garden.scenery_tint, base.scenery_tint)


func test_level_look_uses_day_phase_and_forced_phase() -> void:
	var level: int = 52
	var look: DayLook = LocationCycle.look_for_level(level, "beach")
	assert_eq(look.phase_name, DayCycle.phase_name(DayCycle.phase_for(level)))
	assert_eq(LocationCycle.look_for_level(level, "beach", 7).phase_name, DayCycle.phase_name(7))


func _files(data: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for key: String in ["back", "front", "decor"]:
		for raw: Variant in (data.get(key, []) as Array):
			var file_name: String = String((raw as Dictionary)["file"])
			if not names.has(file_name):
				names.append(file_name)
	var hero: Dictionary = data["hero"] as Dictionary
	names.append(String(hero["trunk"]))
	names.append(String(hero["crown"]))
	names.append(String(data["pole"]))
	return names


func _pixels(id: String) -> int:
	var data: Dictionary = LocationCycle.data_for(id)
	var total: int = 0
	for file_name: String in _files(data):
		var texture: Texture2D = load(String(data["dir"]) + file_name + ".png") as Texture2D
		if texture != null:
			total += texture.get_width() * texture.get_height()
	return total
