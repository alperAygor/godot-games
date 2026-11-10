extends TestCase
## Kalıcı ilerleme: çekirdek, yükseltme fiyatları, kayıt/yükleme, ödül formülü.

func _meta() -> MetaProgress:
	var ups: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/upgrades.json"))
	var ships: Array = []
	if FileAccess.file_exists("res://data/ships.json"):
		ships = JSON.parse_string(FileAccess.get_file_as_string("res://data/ships.json"))
	return MetaProgress.new(ups, ships)

func test_upgrade_data_is_valid() -> void:
	var ups: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/upgrades.json"))
	gt(float(ups.size()), 5.0, "en az 6 yükseltme olmalı")
	var ids := {}
	for def in ups:
		for field in ["id", "name", "name_en", "desc", "desc_en", "icon", "costs", "effect"]:
			check(def.has(field), "yükseltme alanı eksik: %s.%s" % [def.get("id", "?"), field])
		var costs: Array = def.get("costs", [])
		check(not costs.is_empty(), "fiyat listesi boş: " + str(def.get("id")))
		for i in range(1, costs.size()):
			check(int(costs[i]) > int(costs[i - 1]), "fiyatlar artmalı: " + str(def.get("id")))
		ids[def["id"]] = true
	eq(ids.size(), ups.size(), "yükseltme kimlikleri benzersiz olmalı")

func test_buy_requires_cores_and_stops_at_max() -> void:
	var m := _meta()
	check(not m.buy("zirh"), "çekirdeksiz alınamamalı")
	m.earn(100000)
	var bought := 0
	while m.buy("zirh"):
		bought += 1
	eq(bought, m.max_level("zirh"), "en üst seviyeye kadar alınabilmeli")
	eq(m.next_cost("zirh"), -1, "en üst seviyede fiyat -1 olmalı")
	check(not m.can_buy("zirh"), "en üst seviyeden sonra alınamamalı")

func test_effects_scale_with_level() -> void:
	var m := _meta()
	m.earn(100000)
	m.buy("silah")
	m.buy("silah")
	m.buy("zirh")
	var fx := m.effects()
	near(float(fx.get("damage_mult", 0.0)), 0.12, 0.0001, "iki seviye silah +%12 olmalı")
	near(float(fx.get("max_hp_bonus", 0.0)), 12.0, 0.0001, "bir seviye zırh +12 olmalı")

func test_round_trip_save() -> void:
	var m := _meta()
	m.earn(500)
	m.buy("cekim")
	var data := m.to_dict()
	var n := _meta()
	n.from_dict(data)
	eq(n.cores, m.cores, "çekirdek korunmalı")
	eq(n.level("cekim"), 1, "seviye korunmalı")
	eq(n.ship, MetaProgress.DEFAULT_SHIP, "varsayılan gemi seçili olmalı")

func test_corrupt_save_is_sanitized() -> void:
	var m := _meta()
	m.from_dict({"cores": -50, "levels": {"zirh": 99, "yok_boyle": 3}, "ships": ["hayali"], "ship": "hayali"})
	eq(m.cores, 0, "negatif çekirdek sıfırlanmalı")
	eq(m.level("zirh"), m.max_level("zirh"), "seviye tavana kırpılmalı")
	check(not m.levels.has("yok_boyle"), "bilinmeyen yükseltme atılmalı")
	eq(m.ship, MetaProgress.DEFAULT_SHIP, "sahip olunmayan gemi seçilememeli")

func test_run_reward_grows() -> void:
	var low := MetaProgress.run_reward(500, 2, 0)
	var high := MetaProgress.run_reward(20000, 15, 2)
	gt(float(high), float(low), "iyi koşu daha çok çekirdek vermeli")
	gt(float(MetaProgress.run_reward(20000, 15, 2, 1.3)), float(high), "çarpan ödülü artırmalı")
	eq(MetaProgress.run_reward(0, 1, 0), 0, "boş koşu 0 vermeli")
