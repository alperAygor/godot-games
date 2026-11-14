extends TestCase
## Denge verisi tutarlı mı? Kodda varsayılanı olmayan alanlar burada yakalanır.

const RunStateScript = preload("res://scripts/core/run_state.gd")

func _data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))

func test_sections_exist() -> void:
	var data := _data()
	for key in ["player", "enemies", "boss", "waves", "scoring", "leveling", "pickups", "difficulty"]:
		check(data.has(key), "balance.json bölümü eksik: " + key)

func test_enemy_kinds_have_stats() -> void:
	var data := _data()
	for kind in ["chaser", "shooter", "tank", "swarmer", "bomber", "sniper", "orbiter"]:
		var stats: Dictionary = data["enemies"].get(kind, {})
		check(not stats.is_empty(), "düşman türü yok: " + kind)
		for field in ["hp", "speed", "radius", "damage", "points", "color", "unlock"]:
			check(stats.has(field), "%s.%s eksik" % [kind, field])
		if stats.has("color"):
			check(Color.from_string(str(stats["color"]), Color.BLACK) != Color.BLACK, "geçersiz renk: " + kind)

func test_unlocks_are_ordered() -> void:
	var data := _data()
	var first_seen := 99
	for kind in data["enemies"]:
		var unlock := int(data["enemies"][kind].get("unlock", 1))
		check(unlock >= 1, "unlock pozitif olmalı: " + kind)
		first_seen = mini(first_seen, unlock)
	eq(first_seen, 1, "en az bir düşman 1. dalgada açık olmalı")

func test_wave_numbers_sane() -> void:
	var data := _data()
	var waves: Dictionary = data["waves"]
	gt(float(waves["base_count"]), 0.0, "base_count pozitif olmalı")
	gt(float(waves["growth"]), 0.0, "growth pozitif olmalı")
	gt(float(waves["min_interval"]), 0.0, "min_interval pozitif olmalı")
	check(float(waves["spawn_interval"]) >= float(waves["min_interval"]), "spawn_interval min'den küçük olmamalı")
	gt(float(waves["boss_every"]), 1.0, "boss_every > 1 olmalı")

func test_intervals_shrink_with_waves() -> void:
	var a = RunStateScript.new(_data(), 3)
	a.wave = 1
	var early: float = a.spawn_interval()
	a.wave = 8
	var late: float = a.spawn_interval()
	check(late <= early, "sonraki dalgalarda doğma aralığı artmamalı")

func test_cards_data_is_valid() -> void:
	var cards: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json"))
	check(cards is Array and cards.size() >= 10, "en az 10 kart olmalı")
	var ids := {}
	for card in cards:
		for field in ["id", "name", "desc", "tier", "effect"]:
			check(card.has(field), "kart alanı eksik: " + str(card.get("id", "?")) + "." + field)
		ids[card.get("id", "")] = true
	eq(ids.size(), cards.size(), "kart kimlikleri benzersiz olmalı")

func test_maps_data_is_valid() -> void:
	var maps: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps.json"))
	check(maps is Array and maps.size() >= 2, "en az 2 harita olmalı")
	for theme in maps:
		for field in ["id", "name", "floor_base", "floor_line", "light_a", "props"]:
			check(theme.has(field), "harita alanı eksik: " + str(theme.get("id", "?")) + "." + field)

func test_elite_and_mobile_fields_exist() -> void:
	var data := _data()
	check(data.has("elite"), "elite bölümü eksik")
	for field in ["from_wave", "chance", "hp_mult", "scale", "points_mult"]:
		check(data["elite"].has(field), "elite." + field + " eksik")
	for field in ["nova_per_kill", "nova_radius", "nova_damage", "auto_aim_range"]:
		check(data["player"].has(field), "player." + field + " eksik")

func test_maps_define_a_boss() -> void:
	var maps: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps.json"))
	for theme in maps:
		check(theme.has("boss_name"), "boss adı eksik: " + str(theme.get("id", "?")))
		check(Color.from_string(str(theme.get("boss_color", "")), Color.BLACK) != Color.BLACK, "boss rengi geçersiz: " + str(theme.get("id", "?")))
