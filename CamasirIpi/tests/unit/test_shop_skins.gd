extends TestCase

## SkinCatalog / SkinStore / RopePainter: kaplama kuralları, koleksiyon eşlemesi ve alım akışı.
## Gerçek kayda dokunmamak için diske yazmayan (persist=false) ayrı bir Progress örneği kullanılır.

var _progress: Node = null
var _catalog: SkinCatalog = null


func before_each() -> void:
	var script: GDScript = load("res://scripts/autoload/Progress.gd") as GDScript
	_progress = script.new()
	_progress.set("persist", false)
	_progress.set("save_path", "user://test_skins_never_written.json")
	_progress.set("balance", ProgressData.load_balance())
	_catalog = SkinCatalog.load_default()


func after_each() -> void:
	_progress.free()


func test_catalog_has_enough_skins() -> void:
	assert_true(_catalog.ids(SkinCatalog.KIND_PIN).size() >= 5, "varsayılan + en az 4 mandal")
	assert_true(_catalog.ids(SkinCatalog.KIND_ROPE).size() >= 5, "varsayılan + en az 4 ip")
	for kind: String in SkinCatalog.KINDS:
		assert_true(_catalog.has_skin(_catalog.default_id(kind)), "varsayılan var: %s" % kind)
		assert_eq(_catalog.source_type(_catalog.default_id(kind)), SkinCatalog.SOURCE_DEFAULT)


func test_every_collection_reward_maps_to_a_skin() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/meta_collection.json"))
	assert_true(parsed is Dictionary)
	for entry: Variant in (parsed as Dictionary)["sets"] as Array:
		var set_data: Dictionary = entry as Dictionary
		var reward: String = String(set_data["reward"])
		assert_true(_catalog.has_skin(reward), "ödül kaplaması var: %s" % reward)
		assert_eq(_catalog.source_type(reward), SkinCatalog.SOURCE_COLLECTION)
		assert_eq(_catalog.set_id(reward), String(set_data["id"]), "set eşleşmesi: %s" % reward)


func test_every_pin_texture_and_rope_style_is_valid() -> void:
	for id: String in _catalog.ids(SkinCatalog.KIND_PIN):
		assert_true(ResourceLoader.exists(_catalog.texture_path(id)), "doku var: %s" % id)
	for id: String in _catalog.ids(SkinCatalog.KIND_ROPE):
		var style: Dictionary = _catalog.rope_style(id)
		assert_true(String(style["pattern"]) in ["solid", "alternate", "dots"], "desen: %s" % id)
		assert_true(float(style["width"]) > 0.0)
		assert_false(RopePainter.parse_colors(style["colors"], Color.BLACK).is_empty())


func test_coin_skins_have_prices_and_collection_skins_none() -> void:
	for kind: String in SkinCatalog.KINDS:
		for id: String in _catalog.ids(kind):
			match _catalog.source_type(id):
				SkinCatalog.SOURCE_COINS:
					assert_true(_catalog.price(id) > 0, "fiyat var: %s" % id)
				SkinCatalog.SOURCE_COLLECTION:
					assert_eq(_catalog.price(id), 0)
					assert_false(_catalog.set_id(id).is_empty())


func test_availability_rules() -> void:
	assert_true(_catalog.is_available("pin_wood", [], []), "varsayılan herkeste")
	assert_false(_catalog.is_available("pin_mint", [], []), "satın alınmadı")
	assert_true(_catalog.is_available("pin_mint", ["pin_mint"], []))
	assert_false(_catalog.is_available("pin_tulip", ["pin_tulip"], []), "koleksiyon skini satın alınamaz/sayılmaz")
	assert_true(_catalog.is_available("pin_tulip", [], ["pin_tulip"]))
	assert_false(_catalog.is_available("yok", [], []))


func test_selection_falls_back_to_default() -> void:
	assert_eq(_catalog.resolve_selected("pin", "", [], []), "pin_wood")
	assert_eq(_catalog.resolve_selected("pin", "pin_mint", [], []), "pin_wood", "sahip değil")
	assert_eq(_catalog.resolve_selected("pin", "pin_mint", ["pin_mint"], []), "pin_mint")
	assert_eq(_catalog.resolve_selected("pin", "rope_gold", ["rope_gold"], []), "pin_wood", "yanlış tür")
	assert_eq(_catalog.resolve_selected("rope", "rope_sakura", [], ["rope_sakura"]), "rope_sakura")


func test_store_buy_spends_coins_and_selects() -> void:
	var store: SkinStore = SkinStore.new(_progress, _catalog)
	assert_false(store.buy("pin_mint"), "jeton yok")
	assert_false(store.is_available("pin_mint"))
	_progress.call("add_coins", 500)
	assert_true(store.can_buy("pin_mint"))
	assert_true(store.buy("pin_mint"))
	assert_eq(int(_progress.call("coins")), 200)
	assert_eq(store.selected("pin"), "pin_mint", "alınca seçilir")
	assert_false(store.buy("pin_mint"), "ikinci kez alınmaz")
	assert_eq(int(_progress.call("coins")), 200)
	var again: SkinStore = SkinStore.new(_progress, _catalog)
	assert_eq(again.selected("pin"), "pin_mint", "kayıttan okunur")


func test_store_cannot_buy_collection_or_unaffordable() -> void:
	var store: SkinStore = SkinStore.new(_progress, _catalog)
	_progress.call("add_coins", 100)
	assert_false(store.buy("pin_tulip"), "koleksiyon skini jetonla alınmaz")
	assert_false(store.buy("pin_star"), "yetersiz jeton")
	assert_eq(int(_progress.call("coins")), 100)


func test_store_collection_unlock_via_meta_cosmetics() -> void:
	var store: SkinStore = SkinStore.new(_progress, _catalog)
	assert_false(store.select("rope_tartan"), "kilitliyken seçilemez")
	_progress.call("set_module_value", "meta", "cosmetics", ["rope_tartan"])
	assert_true(store.is_available("rope_tartan"))
	assert_true(store.select("rope_tartan"))
	assert_eq(store.selected("rope"), "rope_tartan")


func test_rope_points_and_colors() -> void:
	var points: PackedVector2Array = RopePainter.build_points(0.0, 100.0, 10.0, 8.0, 24)
	assert_eq(points.size(), 25)
	assert_almost_eq(points[0].y, 10.0)
	assert_almost_eq(points[12].y, 18.0)
	assert_almost_eq(points[24].x, 100.0)
	assert_eq(RopePainter.parse_colors([], Color.RED).size(), 1, "boşsa yedek renk")
	assert_eq(RopePainter.parse_colors(["#ff0000", "#00ff00"], Color.BLACK).size(), 2)
