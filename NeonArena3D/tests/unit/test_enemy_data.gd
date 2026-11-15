extends TestCase
## C2 saf mantığı: elit ön eki seçimi, sektör/üst-sınır yedek kuralı, birleştirme (EnemyData).

func _data() -> Dictionary:
	return BalanceData.load_dir()["data"]

func test_pick_prefix_respects_wave_kind_and_roll() -> void:
	var elite: Dictionary = _data()["elite"]
	eq(EnemyData.pick_prefix(elite, "chaser", 3, 0.5), "", "4. dalgadan önce ön ek yok")
	for roll in [0.0, 0.3, 0.6, 0.99]:
		check(EnemyData.pick_prefix(elite, "chaser", 5, roll) in ["armored", "swift"], "5. dalga yalnız zırhlı/çevik (roll %.2f)" % roll)
	var seen := {}
	for roll in [0.0, 0.2, 0.4, 0.6, 0.8, 0.99]:
		seen[EnemyData.pick_prefix(elite, "chaser", 12, roll)] = true
	eq(seen.size(), 4, "12. dalgada chaser için dört ön ek de çıkabilir")
	eq(EnemyData.pick_prefix(elite, "swarmer", 30, 0.4), "", "swarmer ön ek almaz")
	for roll in [0.0, 0.5, 0.99]:
		check(EnemyData.pick_prefix(elite, "bomber", 30, roll) in ["armored", "swift"], "bombacı bölünmez/emmez")
		check(EnemyData.pick_prefix(elite, "orbiter", 30, roll) != "vampiric", "yalnız yakın dövüşçüler emici olur")

func test_pick_prefix_is_a_pure_function() -> void:
	var elite: Dictionary = _data()["elite"]
	eq(EnemyData.pick_prefix(elite, "tank", 20, 0.37), EnemyData.pick_prefix(elite, "tank", 20, 0.37), "aynı girdi aynı sonuç")
	eq(EnemyData.pick_prefix({}, "tank", 20, 0.5), "", "ön eksiz veri düz elit")

func test_merged_elite_overrides_and_keeps_base() -> void:
	var elite: Dictionary = _data()["elite"]
	var m := EnemyData.merged_elite(elite, "armored")
	eq(m["prefix"], "armored", "ön ek kimliği taşınır")
	near(float(m["hp_mult"]), float(elite["prefixes"]["armored"]["hp_mult"]), 0.0001, "ön ek can çarpanı genel çarpanı ezer")
	check(not m.has("prefixes"), "birleşik sözlükte ön ek tablosu yok")
	near(float(m["chance"]), float(elite["chance"]), 0.0001, "genel alanlar korunur")
	var plain := EnemyData.merged_elite(elite, "")
	check(not plain.has("prefix"), "ön eksiz birleşim düz elittir")
	near(float(plain["hp_mult"]), float(elite["hp_mult"]), 0.0001, "düz elit genel çarpan")

func test_resolve_kind_sector_and_cap() -> void:
	var en: Dictionary = _data()["enemies"]
	eq(EnemyData.resolve_kind(en, "chaser", 0, {}), "chaser", "kuralsız tür aynen")
	eq(EnemyData.resolve_kind(en, "minelayer", 0, {}), en["minelayer"]["fallback"], "yanlış sektörde yedek")
	eq(EnemyData.resolve_kind(en, "minelayer", 1, {}), "minelayer", "doğru sektörde kendisi")
	eq(EnemyData.resolve_kind(en, "minelayer", 1, {"minelayer": 2}), en["minelayer"]["fallback"], "üst sınırda yedek")
	eq(EnemyData.resolve_kind(en, "medic", 2, {"medic": 1}), "medic", "üst sınırın altında kendisi")
	eq(EnemyData.resolve_kind(en, "brooder", 2, {}), en["brooder"]["fallback"], "kuluçka 2. sektörde yok")

func test_waves_one_to_three_have_no_new_types() -> void:
	## Yeni düşmanlar RunState.unlocked_kinds üzerinden zamanlanır (unlock + weight): ilk 3 dalga eskisi gibi nazik.
	var bal := _data()
	var run := RunState.new({"enemies": bal["enemies"], "waves": bal["waves"], "scoring": bal["scoring"], "leveling": bal["leveling"], "difficulty": bal["difficulty"], "boss": bal["boss"]}, 3)
	var new_kinds := ["charger", "shielder", "medic", "minelayer", "blinker", "brooder"]
	for wave in [1, 2, 3]:
		for entry in run.unlocked_kinds(wave):
			check(not (str(entry["kind"]) in new_kinds), "dalga %d'te yeni tür açık olmamalı: %s" % [wave, entry["kind"]])
	var late: Array = []
	for entry in run.unlocked_kinds(14):
		late.append(str(entry["kind"]))
	for kind in new_kinds:
		check(kind in late, "14. dalgada açık: " + kind)
