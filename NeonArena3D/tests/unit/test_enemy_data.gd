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
	# Entegrasyon (sektör karışımı): kuluçka artık 3. sektörde (BUZ TERMİNALİ) de var; standart modda başka türlü hiç görünmezdi.
	eq(EnemyData.resolve_kind(en, "brooder", 2, {}), "brooder", "kuluçka 3. sektörde var")
	eq(EnemyData.resolve_kind(en, "blinker", 1, {}), en["blinker"]["fallback"], "sıçrayıcı yalnız 3. sektörde")

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

func test_elite_chance_uses_effective_wave() -> void:
	## Entegrasyon (C1 × C2): elit eşiği/şansı etkin dalgayla. Sonsuz/standartta etkin dalga = n → eski formül birebir.
	var defs := _data()
	var elite: Dictionary = defs["elite"]
	var from := float(elite.get("from_wave", 4))
	for n in [1, 3, 4, 7, 12, 30]:
		var legacy := -1.0
		if float(n) >= from:
			legacy = minf(float(elite["chance_max"]), float(elite["chance"]) + float(elite["chance_per_wave"]) * float(n))
		eq(EnemyData.elite_chance(elite, float(n), false), legacy, "dalga %d: eski formül" % n)
		eq(EnemyData.prefix_wave(float(n)), n, "ön ek dalgası = n")
	eq(EnemyData.elite_chance(elite, 12.0, true), -1.0, "boss dalgasında elit yok")
	var quick := RunState.new(defs, 3)
	quick.set_mode("quick")
	var scale := float(defs["run"]["modes"]["quick"]["wave_scale"])
	check(scale > 1.0, "hızlı mod sıkıştırılmış (wave_scale > 1)")
	for n in [4, 6, 8]:
		var eff := quick.difficulty_wave(n)
		near(eff, 1.0 + float(n - 1) * scale, 0.0001, "hızlı %d. dalga etkin %.2f" % [n, eff])
		gt(EnemyData.elite_chance(elite, eff, false), EnemyData.elite_chance(elite, float(n), false), "hızlı %d. dalga: elit şansı etkin dalgadan (daha yüksek)" % n)
		eq(EnemyData.prefix_wave(eff), int(floor(eff + 0.0001)), "ön ek dalgası = etkin dalganın tam kısmı")
