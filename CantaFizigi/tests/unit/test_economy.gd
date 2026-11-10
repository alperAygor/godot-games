extends TestCase

## Economy: fiyat egrisi ve limit kontrolu (data/upgrades.json tablosuyla).

var _table: Dictionary = {}


func before_each() -> void:
	_table = {
		"bag_capacity": {"base_cost": 300, "cost_growth": 1.8, "max_level": 2},
		"insurance": {"base_cost": 600, "cost_growth": 2.0, "max_level": 1},
	}


func test_cost_grows_with_level() -> void:
	assert_eq(Economy.cost(_table, "bag_capacity", 0), 300)
	assert_eq(Economy.cost(_table, "bag_capacity", 1), 540)
	assert_eq(Economy.cost(_table, "bag_capacity", 2), -1, "limitte fiyat yok")


func test_unknown_upgrade_has_no_cost() -> void:
	assert_eq(Economy.cost(_table, "bilinmeyen", 0), -1)
	assert_eq(Economy.max_level(_table, "bilinmeyen"), 0)


func test_can_buy_respects_currency_and_limit() -> void:
	assert_false(Economy.can_buy(_table, "bag_capacity", 0, 299))
	assert_true(Economy.can_buy(_table, "bag_capacity", 0, 300))
	assert_false(Economy.can_buy(_table, "bag_capacity", 2, 99999), "limit asilamaz")


func test_real_table_loads_from_data() -> void:
	var table: Dictionary = GameData.table("upgrades")
	assert_true(table.has("bag_capacity"), "data/upgrades.json yuklenmis olmali")
	assert_greater(float(Economy.cost(table, "bag_capacity", 0)), 0.0)
