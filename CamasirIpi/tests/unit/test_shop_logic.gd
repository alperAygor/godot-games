extends TestCase

## ShopLogic: paket fiyatları ve indirimler (denge dosyasındaki gerçek değerlerle).

var _balance: Dictionary = {}


func before_each() -> void:
	_balance = ProgressData.load_balance()


func test_pack_sizes_are_one_three_five() -> void:
	assert_eq(ShopLogic.pack_sizes(_balance), [1, 3, 5])


func test_single_pack_has_no_discount() -> void:
	assert_eq(ShopLogic.pack_price(_balance, "undo", 1), 60)
	assert_eq(ShopLogic.pack_price(_balance, "pin_remover", 1), 80)
	assert_eq(ShopLogic.pack_price(_balance, "extra_slot", 1), 100)


func test_bigger_packs_are_cheaper_per_unit() -> void:
	for id: String in ProgressData.BOOSTER_IDS:
		var one: int = ShopLogic.pack_price(_balance, id, 1)
		var three: int = ShopLogic.pack_price(_balance, id, 3)
		var five: int = ShopLogic.pack_price(_balance, id, 5)
		assert_true(three < one * 3, "x3 indirimli: %s" % id)
		assert_true(five < one * 5 and five * 3 < three * 5, "x5 daha da indirimli: %s" % id)


func test_known_prices() -> void:
	assert_eq(ShopLogic.pack_price(_balance, "undo", 3), 162)
	assert_eq(ShopLogic.pack_price(_balance, "undo", 5), 240)
	assert_eq(ShopLogic.pack_price(_balance, "extra_slot", 5), 400)


func test_unknown_booster_costs_nothing_and_cannot_be_bought() -> void:
	assert_eq(ShopLogic.pack_price(_balance, "nope", 3), 0)
	assert_false(ShopLogic.can_afford(1000, 0))


func test_discount_is_clamped() -> void:
	var table: Dictionary = {"shop": {"pack_discount_percent": {"3": 250}}, "booster_cost": {"undo": 60}}
	assert_eq(ShopLogic.discount_percent(table, 3), 90)
	assert_true(ShopLogic.pack_price(table, "undo", 3) >= 1)


func test_bad_data_falls_back() -> void:
	assert_eq(ShopLogic.pack_sizes({}), [1, 3, 5])
	assert_eq(ShopLogic.discount_percent({}, 3), 0)


func test_can_afford() -> void:
	assert_true(ShopLogic.can_afford(60, 60))
	assert_false(ShopLogic.can_afford(59, 60))


func test_purchase_booster_is_atomic() -> void:
	var script: GDScript = load("res://scripts/autoload/Progress.gd") as GDScript
	var progress: Node = script.new()
	progress.set("persist", false)
	progress.set("balance", _balance)
	progress.call("add_coins", 200)
	assert_false(bool(progress.call("purchase_booster", "undo", 5, 240)), "yetersiz jeton")
	assert_eq(int(progress.call("coins")), 200)
	assert_eq(int(progress.call("booster_count", "undo")), 0)
	assert_true(bool(progress.call("purchase_booster", "undo", 3, ShopLogic.pack_price(_balance, "undo", 3))))
	assert_eq(int(progress.call("coins")), 38)
	assert_eq(int(progress.call("booster_count", "undo")), 3)
	assert_false(bool(progress.call("purchase_booster", "bogus", 1, 1)), "bilinmeyen id")
	progress.free()
