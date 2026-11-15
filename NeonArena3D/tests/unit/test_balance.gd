extends TestCase
## Denge verisi tutarlı mı? Kodda varsayılanı olmayan alanlar burada yakalanır.
## Veri data/balance/*.json'dadır (BalanceData birleştirir + doğrular); içerik doğrulaması ContentValidation.

const RunStateScript = preload("res://scripts/core/run_state.gd")

func _data() -> Dictionary:
	return BalanceData.load_dir()["data"]

func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

func test_sections_exist() -> void:
	var data := _data()
	for key in ["player", "enemies", "boss", "waves", "scoring", "leveling", "pickups", "difficulty", "combat"]:
		check(data.has(key), "denge bölümü eksik: " + key)

func test_shipped_balance_has_no_errors() -> void:
	var loaded := BalanceData.load_dir()
	eq(Array(loaded["errors"]), [], "data/balance/*.json doğrulama hatasız olmalı")
	for name in BalanceData.FILES:
		check(FileAccess.file_exists(BalanceData.DIR.path_join(name + ".json")), "denge dosyası yok: " + name)
	check(not FileAccess.file_exists("res://data/balance.json"), "eski tek dosya data/balance.json geri gelmemeli (iki kaynak olur)")

func test_each_section_has_one_source_file() -> void:
	var sources: Dictionary = BalanceData.load_dir()["sources"]
	eq(str(sources.get("enemies", "")).get_file(), "enemies.json", "enemies bölümü enemies.json'da")
	eq(str(sources.get("boss_kinds", "")).get_file(), "bosses.json", "boss_kinds bölümü bosses.json'da")
	eq(str(sources.get("waves", "")).get_file(), "waves.json", "waves bölümü waves.json'da")
	eq(str(sources.get("combat", "")).get_file(), "combat.json", "combat bölümü combat.json'da")

func test_merge_reports_duplicate_section() -> void:
	var out := BalanceData.merge([["a.json", {"player": {}}, ""], ["b.json", {"player": {}}, ""]])
	var joined := " | ".join(out["errors"])
	check("iki dosyada" in joined and "a.json" in joined and "b.json" in joined, "çift bölüm iki dosya adıyla raporlanmalı: " + joined)

func test_merge_reports_unreadable_file() -> void:
	var out := BalanceData.merge([["bozuk.json", null, ""], ["yok.json", null, "denge dosyası yok: yok.json"]])
	var joined := " | ".join(out["errors"])
	check("sözdizimi" in joined and "bozuk.json" in joined, "bozuk JSON dosya adıyla raporlanmalı: " + joined)
	check("yok.json" in joined, "eksik dosya raporlanmalı: " + joined)

func test_missing_dir_reports_every_file() -> void:
	var out := BalanceData.load_dir("res://data/__olmayan_klasor__")
	eq((out["errors"] as PackedStringArray).size(), BalanceData.FILES.size(), "her eksik dosya için bir hata")

func test_validate_catches_bad_values() -> void:
	var data := _data().duplicate(true)
	data["waves"].erase("max_alive")
	data["enemies"]["chaser"]["hp"] = "çok"
	data["enemies"]["shooter"]["color"] = "mavi-ish"
	data["scoring"]["milestones"] = [10, 5]
	data["combat"]["nova"].erase("wave_scale")
	data["combat"]["hits"]["chain_rnage"] = 240
	var joined := " | ".join(BalanceData.validate(data))
	for needle in ["waves.max_alive eksik", "enemies.chaser.hp sayı olmalı", "enemies.shooter.color", "milestones", "combat.nova.wave_scale", "combat.hits.chain_rnage bilinmeyen"]:
		check(needle in joined, "doğrulama şunu yakalamalı: %s (gelen: %s)" % [needle, joined])

func test_validate_requires_sections() -> void:
	var errors := BalanceData.validate({"player": {}})
	check(errors.size() >= BalanceData.SECTIONS.size() - 1, "eksik bölümler tek tek raporlanmalı (%d)" % errors.size())

func test_tuning_reads_combat_section() -> void:
	var data := _data()
	var t := GameTuning.from_balance(data)
	eq(Array(GameTuning.validate(data["combat"])), [], "combat.json doğrulama hatasız")
	near(t.nova_wave_scale, float(data["combat"]["nova"]["wave_scale"]), 0.0, "nova_wave_scale JSON'dan")
	eq(t.run_base_rerolls, int(data["combat"]["run"]["base_rerolls"]), "tam sayı alan int okunur")
	eq(typeof(t.fortress_bullets), TYPE_INT, "sayaç alanları int kalır")
	near(t.nova_max, float(data["player"]["nova_cost"]), 0.0, "nova_max = player.nova_cost")
	near(t.player_damage, float(data["player"]["damage"]), 0.0, "player.damage önbelleği")
	for group in GameTuning.SCHEMA:
		for key in GameTuning.SCHEMA[group]:
			check(("%s_%s" % [group, key]) in t, "GameTuning alanı tanımlı: %s_%s" % [group, key])

func test_tuning_rejects_fraction_for_counts() -> void:
	var combat: Dictionary = _data()["combat"].duplicate(true)
	combat["fortress"]["bullets"] = 12.5
	combat["drones"]["range"] = -1
	var joined := " | ".join(GameTuning.validate(combat))
	check("fortress.bullets tam sayı" in joined, "sayaç alanı kesirli olamaz: " + joined)
	check("drones.range negatif" in joined, "negatif değer yakalanmalı: " + joined)

func test_content_validation_passes_on_shipped_data() -> void:
	var errors := ContentValidation.validate(_json("res://data/cards.json"), _json("res://data/ships.json"), _json("res://data/upgrades.json"), _json("res://data/maps.json"), _data())
	eq(Array(errors), [], "kart/gemi/atölye/harita verisi doğrulama hatasız")

func test_content_validation_catches_mistakes() -> void:
	var cards: Array = _json("res://data/cards.json")
	cards.append({"id": "guc", "name": "x", "desc": "x", "tier": "legend", "effect": {"damage_mul": 0.1}})
	cards.append({"id": "s_yeni", "name": "x", "desc": "x", "tier": "synergy", "effect": {}, "requires": ["yok_kart"]})
	var ships: Array = _json("res://data/ships.json")
	ships.append({"id": "yeni", "name": "x", "color": "#fff", "cost": 1, "model": "", "weapon": {"type": "laser"}})
	var maps: Array = _json("res://data/maps.json")
	var bad_map: Dictionary = (maps[0] as Dictionary).duplicate()
	bad_map["boss"] = "ejderha"
	maps.append(bad_map)
	var joined := " | ".join(ContentValidation.validate(cards, ships, _json("res://data/upgrades.json"), maps, _data()))
	for needle in ["tekrar ediyor: guc", "bilinmeyen tier 'legend'", "bilinmeyen etki 'damage_mul'", "tanımsız: yok_kart", "weapon.type", "ejderha"]:
		check(needle in joined, "içerik doğrulaması şunu yakalamalı: %s (gelen: %s)" % [needle, joined])

func test_game_data_loaded_without_errors() -> void:
	var gd: Node = load("res://scripts/autoload/game_data.gd").new()
	gd.load_all()
	eq(Array(gd.errors), [], "GameData açılış doğrulaması hatasız")
	near(float(gd.value("waves.max_alive", -1.0)), float(_data()["waves"]["max_alive"]), 0.0, "GameData.value yol API'si bölünmüş veriden okur")
	near(gd.number("boss_kinds.titan.radius", -1.0), 72.0, 0.0, "iç içe yol: boss_kinds.titan.radius")
	near(float(gd.boss_stats("titan").get("hp_mult", 0.0)), 1.25, 0.0, "boss_stats: temel + tür birleşimi")
	near(gd.tuning.nova_max, 100.0, 0.0, "GameData.tuning kuruldu")
	gd.free()

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
	var cards: Array = _json("res://data/cards.json")
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
