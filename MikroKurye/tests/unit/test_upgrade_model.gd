extends TestCase

## UpgradeModel: yükseltme bedeli, satın alma ve toplam modlar. Sözleşme: ARCHITECTURE.md §4.5.
## Sınıf henüz YOK — testler sözleşmeden türetildi (kırmızı aşama).
##
## Test tablosu bilerek `JSON.parse_string` ile üretilir: gerçek `upgrades.json` gibi bütün
## sayılar float gelir (GOTCHAS #20). Böylece `cost` ve `purchase`'ın tamsayıya güvenli
## çevirdiği doğrulanır.
##
## Varsayımlar (sözleşmede açık değil):
## - Başarısız `purchase` sonucundaki `reason` boş olmayan bir metindir.
## - Eksik `wallet`/`cost` anahtarı 0 sayılır (Wallet.can_afford ile aynı tolerans).
## - Seviyesi 0 olan kategori `stats` çıktısına katkı vermez; hiç mod yoksa sözlük boştur.

const FIXTURE_JSON: String = """
{
  "chassis": {"max_level": 3, "levels": [
    {"cost": {"gold": 100, "scrap": 5}, "mods": {"cargo_damping_bonus": 1.0}},
    {"cost": {"gold": 200, "scrap": 10}, "mods": {"cargo_damping_bonus": 1.0}},
    {"cost": {"gold": 350, "scrap": 18}, "mods": {"cargo_damping_bonus": 1.0}}
  ]},
  "wheels": {"max_level": 2, "levels": [
    {"cost": {"gold": 80, "scrap": 4}, "mods": {"wheel_grip_bonus": 0.6}},
    {"cost": {"gold": 160, "scrap": 8}, "mods": {"wheel_grip_bonus": 0.6}}
  ]},
  "battery": {"max_level": 2, "levels": [
    {"cost": {"gold": 80, "scrap": 3}, "mods": {"battery_capacity_bonus": 15.0}},
    {"cost": {"gold": 160, "scrap": 7}, "mods": {"battery_capacity_bonus": 15.0}}
  ]}
}
"""


func _table() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FIXTURE_JSON)
	if not parsed is Dictionary:
		fail("test tablosu ayrıştırılamadı")
		return {}
	return parsed as Dictionary


func _levels(chassis: int = 0, wheels: int = 0, battery: int = 0) -> Dictionary:
	return {"chassis": chassis, "wheels": wheels, "battery": battery}


func test_cost_returns_level_cost_as_integers() -> void:
	var table: Dictionary = _table()
	var chassis_one: Dictionary = UpgradeModel.cost(table, "chassis", 1)
	assert_eq(chassis_one, {"gold": 100, "scrap": 5}, "chassis 1. seviye bedeli")
	assert_eq(typeof(chassis_one.get("gold", 0)), TYPE_INT, "gold tamsayı olmalı (JSON float gelir)")
	assert_eq(typeof(chassis_one.get("scrap", 0)), TYPE_INT, "scrap tamsayı olmalı (JSON float gelir)")

	var wheels_two: Dictionary = UpgradeModel.cost(table, "wheels", 2)
	assert_eq(wheels_two, {"gold": 160, "scrap": 8}, "wheels 2. seviye bedeli")

	var chassis_three: Dictionary = UpgradeModel.cost(table, "chassis", 3)
	assert_eq(chassis_three, {"gold": 350, "scrap": 18}, "maksimum seviyenin bedeli de okunmalı")


func test_cost_invalid_level_or_category_returns_empty() -> void:
	var table: Dictionary = _table()
	assert_eq(UpgradeModel.cost(table, "chassis", 0), {}, "seviye 0 satın alınamaz")
	assert_eq(UpgradeModel.cost(table, "chassis", -1), {}, "negatif seviye geçersiz")
	assert_eq(UpgradeModel.cost(table, "chassis", 4), {}, "max_level üstü geçersiz")
	assert_eq(UpgradeModel.cost(table, "wings", 1), {}, "bilinmeyen kategori geçersiz")
	assert_eq(UpgradeModel.cost({}, "chassis", 1), {}, "boş tablo geçersiz")


func test_can_afford_boundaries_and_missing_keys() -> void:
	assert_true(UpgradeModel.can_afford({"gold": 100, "scrap": 5}, {"gold": 100, "scrap": 5}),
		"tam yeten bakiye yeterlidir")
	assert_true(UpgradeModel.can_afford({"gold": 101, "scrap": 6}, {"gold": 100, "scrap": 5}),
		"fazla bakiye yeterlidir")
	assert_false(UpgradeModel.can_afford({"gold": 99, "scrap": 5}, {"gold": 100, "scrap": 5}),
		"1 gold eksik yetmez")
	assert_false(UpgradeModel.can_afford({"gold": 100, "scrap": 4}, {"gold": 100, "scrap": 5}),
		"1 scrap eksik yetmez")
	assert_true(UpgradeModel.can_afford({"gold": 10}, {"gold": 10}),
		"eksik cost anahtarı 0 sayılır")
	assert_false(UpgradeModel.can_afford({"gold": 10}, {"gold": 10, "scrap": 1}),
		"eksik wallet anahtarı 0 sayılır")


func test_purchase_success_deducts_cost_and_raises_level() -> void:
	var table: Dictionary = _table()
	var wallet: Dictionary = {"gold": 500, "scrap": 20}
	var levels: Dictionary = _levels(0, 0, 0)
	var result: Dictionary = UpgradeModel.purchase(table, wallet, levels, "chassis")

	assert_eq(result.get("ok"), true, "yeterli bakiyede satın alma başarılı olmalı")
	assert_eq(result.get("wallet"), {"gold": 400, "scrap": 15}, "bedel cüzdandan düşmeli")
	assert_eq(result.get("levels"), {"chassis": 1, "wheels": 0, "battery": 0},
		"yalnız satın alınan kategori artmalı")
	assert_eq(wallet, {"gold": 500, "scrap": 20}, "girdi cüzdanı değişmemeli")
	assert_eq(levels, {"chassis": 0, "wheels": 0, "battery": 0}, "girdi seviyeleri değişmemeli")


func test_purchase_exact_balance_leaves_zero() -> void:
	var table: Dictionary = _table()
	var wallet: Dictionary = {"gold": 350, "scrap": 18}
	var levels: Dictionary = _levels(2, 0, 0)
	var result: Dictionary = UpgradeModel.purchase(table, wallet, levels, "chassis")

	assert_eq(result.get("ok"), true, "tam yeten bakiye satın almaya yeter")
	assert_eq(result.get("wallet"), {"gold": 0, "scrap": 0}, "tam bakiye sıfıra inmeli")
	assert_eq(result.get("levels"), {"chassis": 3, "wheels": 0, "battery": 0},
		"3. seviyeye çıkmalı")


func test_purchase_insufficient_gold_fails_without_changes() -> void:
	var table: Dictionary = _table()
	var wallet: Dictionary = {"gold": 99, "scrap": 5}
	var levels: Dictionary = _levels(0, 0, 0)
	var result: Dictionary = UpgradeModel.purchase(table, wallet, levels, "chassis")

	assert_eq(result.get("ok"), false, "yetersiz gold ile satın alma başarısız olmalı")
	assert_true(not String(result.get("reason", "")).is_empty(), "başarısızlık nedeni metin olmalı")
	assert_eq(result.get("wallet"), wallet, "başarısızlıkta cüzdan değişmemeli")
	assert_eq(result.get("levels"), levels, "başarısızlıkta seviyeler değişmemeli")
	assert_eq(wallet, {"gold": 99, "scrap": 5}, "girdi cüzdanı da değişmemeli")


func test_purchase_insufficient_scrap_fails_without_changes() -> void:
	var table: Dictionary = _table()
	var wallet: Dictionary = {"gold": 100, "scrap": 4}
	var levels: Dictionary = _levels(0, 0, 0)
	var result: Dictionary = UpgradeModel.purchase(table, wallet, levels, "chassis")

	assert_eq(result.get("ok"), false, "yetersiz scrap ile satın alma başarısız olmalı")
	assert_true(not String(result.get("reason", "")).is_empty(), "başarısızlık nedeni metin olmalı")
	assert_eq(result.get("wallet"), {"gold": 100, "scrap": 4}, "başarısızlıkta cüzdan değişmemeli")
	assert_eq(result.get("levels"), {"chassis": 0, "wheels": 0, "battery": 0},
		"başarısızlıkta seviye değişmemeli")


func test_purchase_at_max_level_fails_without_changes() -> void:
	var table: Dictionary = _table()
	var wallet: Dictionary = {"gold": 9999, "scrap": 999}
	var levels: Dictionary = _levels(3, 0, 0)
	var result: Dictionary = UpgradeModel.purchase(table, wallet, levels, "chassis")

	assert_eq(result.get("ok"), false, "maksimum seviyede satın alma başarısız olmalı")
	assert_true(not String(result.get("reason", "")).is_empty(), "başarısızlık nedeni metin olmalı")
	assert_eq(result.get("wallet"), {"gold": 9999, "scrap": 999}, "maksimumda para harcanmamalı")
	assert_eq(result.get("levels"), {"chassis": 3, "wheels": 0, "battery": 0},
		"maksimum seviye aşılmamalı")


func test_purchase_unknown_category_fails_without_changes() -> void:
	var table: Dictionary = _table()
	var wallet: Dictionary = {"gold": 9999, "scrap": 999}
	var levels: Dictionary = _levels(0, 0, 0)
	var result: Dictionary = UpgradeModel.purchase(table, wallet, levels, "wings")

	assert_eq(result.get("ok"), false, "bilinmeyen kategori satın alınamaz")
	assert_true(not String(result.get("reason", "")).is_empty(), "başarısızlık nedeni metin olmalı")
	assert_eq(result.get("wallet"), {"gold": 9999, "scrap": 999}, "bilinmeyen kategoride para harcanmamalı")
	assert_eq(result.get("levels"), {"chassis": 0, "wheels": 0, "battery": 0},
		"bilinmeyen kategoride seviye değişmemeli")


func test_purchase_accepts_whole_floats_from_json() -> void:
	var table: Dictionary = _table()
	var wallet: Dictionary = {"gold": 200.0, "scrap": 10.0}
	var levels: Dictionary = {"chassis": 1.0, "wheels": 0.0, "battery": 0.0}
	var result: Dictionary = UpgradeModel.purchase(table, wallet, levels, "chassis")

	assert_eq(result.get("ok"), true, "küsuratsız float seviye tamsayı sayılmalı")
	assert_eq(result.get("wallet"), {"gold": 0, "scrap": 0}, "JSON float bakiyesi tamsayıya inmeli")
	var result_levels: Dictionary = result.get("levels", {})
	assert_eq(result_levels, {"chassis": 2, "wheels": 0, "battery": 0},
		"küsuratsız float seviye +1 artmalı")
	assert_eq(typeof(result_levels.get("chassis", 0)), TYPE_INT,
		"dönen seviye tamsayı olmalı")


func test_purchase_returns_independent_copies() -> void:
	var table: Dictionary = _table()
	var wallet: Dictionary = {"gold": 500, "scrap": 20}
	var levels: Dictionary = _levels(0, 0, 0)
	var result: Dictionary = UpgradeModel.purchase(table, wallet, levels, "chassis")
	if result.get("ok") != true:
		fail("kopya testi için satın alma başarılı olmalı")
		return

	var result_wallet: Dictionary = result.get("wallet", {})
	var result_levels: Dictionary = result.get("levels", {})
	result_wallet["gold"] = 999
	result_levels["chassis"] = 99

	assert_eq(wallet, {"gold": 500, "scrap": 20},
		"dönen cüzdanı değiştirmek girdi cüzdanını etkilememeli")
	assert_eq(levels, {"chassis": 0, "wheels": 0, "battery": 0},
		"dönen seviyeleri değiştirmek girdi seviyelerini etkilememeli")


func test_stats_sums_owned_levels_only() -> void:
	var table: Dictionary = _table()
	var levels: Dictionary = _levels(2, 1, 0)
	var sums: Dictionary = UpgradeModel.stats(table, levels)

	assert_almost_eq(float(sums.get("cargo_damping_bonus", 0.0)), 2.0, 0.0001,
		"chassis 1..2 toplamı 2.0 olmalı")
	assert_almost_eq(float(sums.get("wheel_grip_bonus", 0.0)), 0.6, 0.0001,
		"wheels 1..1 toplamı 0.6 olmalı")
	assert_false(sums.has("battery_capacity_bonus"), "seviye 0 mod üretmemeli")
	assert_eq(levels, {"chassis": 2, "wheels": 1, "battery": 0},
		"stats girdi seviyelerini değiştirmemeli")


func test_stats_zero_levels_is_empty() -> void:
	var table: Dictionary = _table()
	assert_eq(UpgradeModel.stats(table, _levels(0, 0, 0)), {},
		"hiç seviye yoksa mod toplamı boş olmalı")
	assert_eq(UpgradeModel.stats(table, {}), {},
		"seviye sözlüğü boşsa mod toplamı boş olmalı")


func test_stats_max_levels_sums_every_level() -> void:
	var table: Dictionary = _table()
	var sums: Dictionary = UpgradeModel.stats(table, _levels(3, 2, 2))

	assert_almost_eq(float(sums.get("cargo_damping_bonus", 0.0)), 3.0, 0.0001,
		"chassis 1..3 toplamı 3.0 olmalı")
	assert_almost_eq(float(sums.get("wheel_grip_bonus", 0.0)), 1.2, 0.0001,
		"wheels 1..2 toplamı 1.2 olmalı")
	assert_almost_eq(float(sums.get("battery_capacity_bonus", 0.0)), 30.0, 0.0001,
		"battery 1..2 toplamı 30.0 olmalı")


func test_stats_ignores_unknown_category() -> void:
	var table: Dictionary = _table()
	var levels: Dictionary = {"chassis": 1, "wings": 5}
	var sums: Dictionary = UpgradeModel.stats(table, levels)

	assert_almost_eq(float(sums.get("cargo_damping_bonus", 0.0)), 1.0, 0.0001,
		"bilinen kategori toplanmalı")
	assert_false(sums.has("wheel_grip_bonus"), "sahip olunmayan kategori eklenmemeli")
	assert_eq(sums.size(), 1, "bilinmeyen kategori yok sayılmalı")


func test_stats_accepts_whole_float_levels() -> void:
	var table: Dictionary = _table()
	var sums: Dictionary = UpgradeModel.stats(table, {"chassis": 2.0, "wheels": 1.0, "battery": 0.0})

	assert_almost_eq(float(sums.get("cargo_damping_bonus", 0.0)), 2.0, 0.0001,
		"küsuratsız float seviye tamsayı sayılmalı")
	assert_almost_eq(float(sums.get("wheel_grip_bonus", 0.0)), 0.6, 0.0001,
		"küsuratsız float seviye toplamı")
