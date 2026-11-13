extends TestCase

## Mevsim görünümü verisi (data/seasons.json + SeasonLook): her mekân x mevsim x gün aşaması
## çözülür, çamaşır tonu okunaklılık sınırında kalır, mevsimlik dokular var ve yazdaki eşleriyle
## aynı boyutta, afiş anahtarları çevrili, gece koyu kalır (HUD okunur), kış güneşi alçak.

## Doku kenarları VRAM sıkıştırma blokları (4x4) için 4'ün katı olmalı.
const BLOCK: int = 4
## DayCycle testindeki sınırla aynı: çamaşır en fazla %10 koyulaşır.
const GARMENT_MIN: float = 0.9
## Gece göğü bu parlaklığın altında kalmalı (açık HUD yazısı okunsun).
const NIGHT_SKY_MAX_LUMA: float = 0.3


func test_every_location_season_phase_resolves() -> void:
	for index: int in range(LocationCycle.count()):
		var id: String = LocationCycle.id_at(index)
		for season: String in SeasonCycle.ORDER:
			for phase: int in range(DayCycle.PHASE_COUNT):
				var look: DayLook = LocationCycle.look_for(phase, id, season)
				assert_not_null(look, "%s/%s/%d" % [id, season, phase])
				assert_eq(look.phase_name, DayCycle.phase_name(phase), "%s/%s aşama adı" % [id, season])
				var tint: Color = look.garment_tint
				assert_true(minf(tint.r, minf(tint.g, tint.b)) >= GARMENT_MIN,
					"%s/%s/%d çamaşırı çok koyultuyor" % [id, season, phase])


func test_level_look_follows_season_cycle() -> void:
	assert_eq(SeasonLook.season_for_level(20), SeasonCycle.SUMMER)
	assert_eq(SeasonLook.season_for_level(35), SeasonCycle.AUTUMN)
	assert_eq(SeasonLook.season_for_level(70), SeasonCycle.WINTER)
	assert_eq(SeasonLook.season_for_level(100), SeasonCycle.SPRING)
	assert_eq(SeasonLook.season_for_level(130), SeasonCycle.SUMMER)
	var look: DayLook = LocationCycle.look_for_level(70, "beach", -1, SeasonCycle.WINTER)
	assert_eq(look.phase_name, DayCycle.phase_name(DayCycle.phase_for(70)))


func test_summer_keeps_todays_look() -> void:
	# Yaz = bugünkü görünüm: gökyüzü verisi boş, katmanlarda gölgelendirici yok (ek maliyet yok).
	for index: int in range(LocationCycle.count()):
		var id: String = LocationCycle.id_at(index)
		for phase: int in range(DayCycle.PHASE_COUNT):
			assert_eq(LocationCycle.look_for(phase, id, SeasonCycle.SUMMER).sky_top, LocationCycle.look_for(phase, id).sky_top)
		assert_true(SeasonLook.grade_for(id, SeasonCycle.SUMMER, "bg_far").is_empty(), "%s yaz derecelendirmesiz" % id)
		assert_true(SeasonLook.make_material({}) == null)


func test_season_look_is_a_copy_not_shared() -> void:
	var base: DayLook = LocationCycle.look_for(2, "garden")
	var base_top: Color = base.sky_top
	var winter: DayLook = LocationCycle.look_for(2, "garden", SeasonCycle.WINTER)
	assert_true(winter != base, "mevsim görünümü ayrı nesne olmalı")
	assert_true(winter.sky_top != base_top, "kış göğü ayarlanmalı")
	assert_eq(base.sky_top, base_top, "mevsimsiz görünüm bozulmamalı")
	assert_true(LocationCycle.look_for(2, "garden", SeasonCycle.WINTER) == winter, "önbellek")


func test_winter_sun_is_lower_and_nights_stay_dark() -> void:
	var noon: int = 2
	var night: int = DayCycle.PHASE_COUNT - 1
	for index: int in range(LocationCycle.count()):
		var id: String = LocationCycle.id_at(index)
		assert_greater(LocationCycle.look_for(noon, id, SeasonCycle.WINTER).sun_pos.y,
			LocationCycle.look_for(noon, id, SeasonCycle.SUMMER).sun_pos.y + 1.0)
		assert_eq(LocationCycle.look_for(night, id, SeasonCycle.WINTER).firefly_amount, 0.0, "kışın ateş böceği yok")
		for season: String in SeasonCycle.ORDER:
			var luma: float = LocationCycle.look_for(night, id, season).sky_top.get_luminance()
			assert_true(luma < NIGHT_SKY_MAX_LUMA, "%s/%s gece göğü çok açık (%.2f)" % [id, season, luma])


func test_season_textures_exist_and_match_summer_size() -> void:
	for index: int in range(LocationCycle.count()):
		var id: String = LocationCycle.id_at(index)
		var data: Dictionary = LocationCycle.data_for(id)
		for season: String in SeasonCycle.ORDER:
			var swaps: Dictionary = SeasonLook.place_spec(id, season).get("swap", {}) as Dictionary
			for file_name: Variant in swaps:
				var path: String = String(swaps[file_name])
				var original: Texture2D = load(String(data["dir"]) + String(file_name) + ".png") as Texture2D
				var seasonal: Texture2D = _checked(path)
				if seasonal != null and original != null:
					assert_eq(seasonal.get_size(), original.get_size(), "%s aynı boyut/çapa olmalı" % path)
			for path: String in SeasonLook.extra_paths(id, season):
				_checked(path)


func test_arrive_banners_are_translated() -> void:
	for season: String in SeasonCycle.ORDER:
		var key: String = SeasonLook.arrive_key(season)
		assert_true(SeasonLook.ARRIVE_KEYS.has(key), "%s afiş anahtarı listede yok" % season)
		for lang: String in [Loc.LANG_TR, Loc.LANG_EN, Loc.LANG_ES]:
			Loc.set_language(lang)
			assert_true(Loc.t(key) != key, "%s çevirisi yok (%s)" % [key, lang])
		assert_true(ResourceLoader.exists(SeasonLook.icon_path(season)), "%s simgesi yok" % season)
	Loc.set_language(Loc.LANG_TR)


func test_announces_only_first_level_of_new_season() -> void:
	assert_false(SeasonLook.announces(1), "oyun yazla başlar, duyuru yok")
	assert_true(SeasonLook.announces(31))
	assert_true(SeasonLook.announces(121), "döngüde yaz geri gelir")
	assert_false(SeasonLook.announces(32))


func test_every_season_has_fx() -> void:
	for season: String in SeasonCycle.ORDER:
		assert_false(SeasonLook.fx_spec(season).is_empty(), "%s efekt verisi yok" % season)


func test_layer_override_null_disables_grade() -> void:
	assert_true(SeasonLook.grade_for("garden", SeasonCycle.AUTUMN, "tree_trunk").is_empty())
	assert_false(SeasonLook.grade_for("garden", SeasonCycle.AUTUMN, "bg_far").is_empty())
	# Mevsimlik dokusu olan katman derecelendirilmez (zaten mevsim renginde render edildi).
	assert_true(SeasonLook.grade_for("garden", SeasonCycle.WINTER, "tree_crown").is_empty())
	# Direk: yalnız yeşillik maskesi (ahşap griye/beyaza dönmez).
	var prop: Dictionary = SeasonLook.prop_grade("garden", SeasonCycle.WINTER, "pole")
	assert_true(prop.has("a") and not prop.has("b") and not prop.has("sat"))


func _checked(path: String) -> Texture2D:
	assert_true(ResourceLoader.exists(path), "eksik: %s" % path)
	if not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path) as Texture2D
	assert_not_null(texture, path)
	if texture != null:
		assert_eq(int(texture.get_width()) % BLOCK, 0, "%s genişlik 4'ün katı değil" % path)
		assert_eq(int(texture.get_height()) % BLOCK, 0, "%s yükseklik 4'ün katı değil" % path)
	return texture
