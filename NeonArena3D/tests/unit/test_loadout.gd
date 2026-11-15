extends TestCase
## Kart havuzu, çarpanlar ve sınırlar.

const LoadoutScript = preload("res://scripts/core/loadout.gd")

func _cards() -> Array:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json"))

func _loadout() -> Loadout:
	return LoadoutScript.new(_cards())

func _by_id(id: String) -> Dictionary:
	for card in _cards():
		if card["id"] == id:
			return card
	return {}

func test_rolls_unique_cards() -> void:
	var l := _loadout()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var cards := l.roll(3, rng)
	eq(cards.size(), 3, "3 kart gelmeli")
	var ids := {}
	for card in cards:
		ids[card["id"]] = true
	eq(ids.size(), 3, "kartlar benzersiz olmalı")

func test_damage_card_increases_multiplier() -> void:
	var l := _loadout()
	var before: float = l.m("damage_mult")
	l.apply(_by_id("guc"))
	gt(l.m("damage_mult"), before, "hasar çarpanı artmalı")
	eq(l.taken.size(), 1, "alınan kart kaydedilmeli")

func test_projectiles_capped() -> void:
	var l := _loadout()
	for i in 8:
		l.apply(_by_id("coklu"))
	eq(l.i("projectiles"), 3, "mermi sayısı 3 ile sınırlı olmalı")

func test_drones_capped() -> void:
	var l := _loadout()
	for i in 5:
		l.apply(_by_id("drone"))
	eq(l.i("drones"), 2, "drone sayısı 2 ile sınırlı olmalı")

func test_reset_clears_mods() -> void:
	var l := _loadout()
	l.apply(_by_id("zirh"))
	l.reset()
	near(l.m("max_hp_bonus"), 0.0, 0.001, "sıfırlanınca bonus kalmamalı")
	eq(l.taken.size(), 0, "kart listesi boşalmalı")

func test_speed_card() -> void:
	var l := _loadout()
	l.apply(_by_id("cevik"))
	near(l.m("speed_mult"), 1.10, 0.001, "hız çarpanı 1.10 olmalı")

func test_dash_card_shortens_cooldown() -> void:
	var l := _loadout()
	l.apply(_by_id("atilma"))
	check(l.m("dash_cd_mult") < 1.0, "atılma kartı beklemeyi kısaltmalı")

func test_new_cards_are_capped() -> void:
	var l := _loadout()
	for i in 6:
		l.apply(_by_id("zincir"))
		l.apply(_by_id("ikincisans"))
		l.apply(_by_id("kalkan"))
	eq(l.i("chain"), 3, "zincir 3 ile sınırlı olmalı")
	eq(l.i("revive"), 1, "ikinci şans tek seferlik olmalı")
	eq(l.i("shield_regen"), 1, "kalkan üreteci tek olmalı")

func test_maxed_cards_leave_the_pool() -> void:
	var l := _loadout()
	l.apply(_by_id("ikincisans"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for n in 40:
		for card in l.roll(3, rng):
			check(card["id"] != "ikincisans", "dolmuş kart tekrar sunulmamalı")

func test_every_card_effect_is_known() -> void:
	var l := _loadout()
	for card in _cards():
		for key in card["effect"]:
			check(l.mods.has(key), "bilinmeyen kart etkisi: %s.%s" % [card["id"], key])
		check(card.has("icon"), "kart ikonu eksik: " + str(card["id"]))

func test_summary_counts_stacks() -> void:
	var l := _loadout()
	l.apply(_by_id("guc"))
	l.apply(_by_id("guc"))
	l.apply(_by_id("cevik"))
	var summary := l.summary()
	eq(summary.size(), 2, "özet benzersiz kartları listelemeli")
	eq(int(summary[0]["count"]), 2, "aynı kart sayılmalı")

func test_apply_effects_handles_new_mult_keys() -> void:
	var l := _loadout()
	l.apply_effects({"xp_mult": 0.16, "brand_new_mult": 0.5, "rerolls": 2})
	near(l.m("xp_mult"), 1.16, 0.001, "xp çarpanı 1.16 olmalı")
	near(l.m("brand_new_mult"), 1.5, 0.001, "bilinmeyen _mult anahtarı 1'den başlamalı")
	eq(l.i("rerolls"), 2, "yenileme hakkı eklenmeli")
	eq(l.taken.size(), 0, "kalıcı etkiler kart sayılmamalı")

func _rolls_include(l: Loadout, id: String, tries := 60) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for n in tries:
		for card in l.roll(3, rng):
			if card["id"] == id:
				return true
	return false

func test_synergy_needs_both_cards() -> void:
	var l := _loadout()
	check(not _rolls_include(l, "s_firtina"), "gereksinimsiz sinerji sunulmamalı")
	l.apply(_by_id("zincir"))
	check(not _rolls_include(l, "s_firtina"), "tek kartla sinerji sunulmamalı")
	l.apply(_by_id("kritik"))
	check(_rolls_include(l, "s_firtina"), "iki kart alınınca sinerji sunulmalı")
	eq(l.synergies_ready().size(), 1, "tam bir sinerji hazır olmalı")

func test_synergy_only_once() -> void:
	var l := _loadout()
	l.apply(_by_id("zincir"))
	l.apply(_by_id("kritik"))
	l.apply(_by_id("s_firtina"))
	check(not _rolls_include(l, "s_firtina"), "alınan sinerji tekrar sunulmamalı")
	eq(l.i("storm"), 1, "fırtına etkisi açık olmalı")

func test_hive_mind_raises_drone_cap() -> void:
	var l := _loadout()
	for i in 3:
		l.apply(_by_id("drone"))
	eq(l.i("drones"), 2, "sinerjisiz sınır 2")
	l.apply(_by_id("coklu"))
	l.apply(_by_id("s_kovan"))
	eq(l.i("drones"), 3, "kovan zihni ile 3 drone")
	l.apply(_by_id("drone"))
	eq(l.i("drones"), 3, "sınır 3'ü aşmamalı")

func test_every_synergy_requirement_exists() -> void:
	var ids := {}
	for card in _cards():
		ids[card["id"]] = true
	for card in _cards():
		for req in card.get("requires", []):
			check(ids.has(req), "sinerji gereksinimi tanımsız: %s → %s" % [card["id"], req])

# --- C3: kurallar, evrim, yasaklama, lanet, acıma, kayıt ---------------------------------------
func test_rules_come_from_data() -> void:
	var rules := Loadout.load_rules()
	check(rules.has("tier_weight") and rules.has("limits") and rules.has("params"), "card_rules.json okunmalı")
	var l := _loadout()
	eq(l.limit("projectiles"), int(rules["limits"]["projectiles"]), "mermi sınırı veriden gelmeli")
	for tier in Loadout.TIER_WEIGHT:
		check((rules["tier_weight"] as Dictionary).has(tier), "kademe ağırlığı veride olmalı: " + tier)

func test_card_text_is_short_and_bilingual() -> void:
	for card in _cards():
		check(str(card.get("name_en", "")) != "" and str(card.get("desc_en", "")) != "", "İngilizce metin eksik: " + str(card["id"]))
		check(str(card["desc"]).length() <= 80, "telefonda okunur tek satır açıklama (≤80): %s (%d)" % [card["id"], str(card["desc"]).length()])

func test_pool_has_45_regular_cards_and_evolutions() -> void:
	var counts := {}
	for card in _cards():
		counts[card["tier"]] = int(counts.get(card["tier"], 0)) + 1
	eq(int(counts.get("common", 0)) + int(counts.get("rare", 0)) + int(counts.get("epic", 0)), 45, "45 normal kart")
	check(int(counts.get("evolution", 0)) >= 5, "en az 5 evrim")
	check(int(counts.get("cursed", 0)) >= 5, "en az 5 lanetli kart")

func test_every_evolution_recipe_exists() -> void:
	var ids := {}
	for card in _cards():
		ids[card["id"]] = true
	for card in _cards():
		if card["tier"] == "evolution":
			var need := Loadout.recipe_of(card)
			check(not need.is_empty(), "evrim tarifi boş: " + str(card["id"]))
			for id in need:
				check(ids.has(id), "evrim parçası tanımsız: %s → %s" % [card["id"], id])

func test_max_field_stops_duplicates() -> void:
	var l := _loadout()
	l.apply(_by_id("infaz"))
	l.apply(_by_id("infaz"))
	check(l._is_maxed(_by_id("infaz")), "max=2 olan kart 2 kez alınınca dolmalı")
	check(not _rolls_include(l, "infaz"), "dolmuş kart sunulmamalı")

func test_evolution_needs_levels_then_is_guaranteed() -> void:
	var l := _loadout()
	l.apply(_by_id("coklu"))
	l.apply(_by_id("delici"))
	l.apply(_by_id("delici"))
	check(not _rolls_include(l, "e_yildiz"), "seviyeler tamamlanmadan evrim sunulmamalı")
	var prog := l.evolution_progress()
	check(not prog.is_empty() and prog[0]["card"]["id"] == "e_yildiz" and int(prog[0]["done"]) == 3 and int(prog[0]["total"]) == 4, "evrim ilerlemesi 3/4 olmalı")
	l.apply(_by_id("coklu"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var offer := l.roll(3, rng)
	eq(str(offer[0]["id"]), "e_yildiz", "hazır evrim ilk yuvada garanti")
	l.apply(_by_id("e_yildiz"))
	eq(l.i("projectiles"), 4, "evrim mermi sınırını 4'e çıkarır")
	check(not _rolls_include(l, "e_yildiz"), "evrim bir kez alınır")
	check(l.evolution_progress().all(func(p): return p["card"]["id"] != "e_yildiz"), "alınan evrim ipucundan düşer")

func test_banish_removes_card_and_is_limited() -> void:
	var l := _loadout()
	var per_run := int(Loadout.load_rules()["banish"]["per_run"])
	eq(l.banishes_total(), per_run, "koşu başına yasaklama hakkı veriden")
	check(l.banish("guc"), "yasaklama çalışmalı")
	check(not l.banish("guc"), "aynı kart iki kez yasaklanmaz")
	check(not _rolls_include(l, "guc", 120), "yasaklı kart sunulmamalı")
	for k in per_run - 1:
		check(l.banish(["tetik", "cevik", "zirh", "miknatis"][k]), "hak kadar yasaklama")
	check(not l.banish("atilma"), "hak bitince yasaklanamaz")
	check(not l.can_banish("l_cam"), "lanetli kart yasaklanamaz")
	l.reset()
	eq(l.banishes_total(), per_run, "yeni koşuda hak yenilenir")
	eq(l.banished.size(), 0, "yeni koşuda yasak listesi boş")

func test_cursed_cards_api() -> void:
	var l := _loadout()
	check(not _rolls_include(l, "l_cam", 200), "lanetli kart normal havuzda yok")
	var list := l.cursed_cards()
	check(list.size() >= 5, "lanet listesi")
	var info := Loadout.curse_info(_by_id("l_cam"))
	check(float(info["reward_mult"]) > 1.0 and str(info["drawback"]) != "", "lanet bilgisi: ödül çarpanı + bedel")
	var hp_before := l.m("max_hp_bonus")
	check(l.apply_curse("l_cam"), "lanet uygulanmalı")
	check(l.m("max_hp_bonus") < hp_before and l.m("damage_mult") > 1.5, "lanetin gücü ve bedeli uygulanmalı")
	near(l.m("core_mult"), float(info["reward_mult"]), 0.001, "ödül çarpanı core_mult'a işlenmeli")
	near(l.curse_reward_mult(), float(info["reward_mult"]), 0.001, "toplam ödül çarpanı")
	check(not l.apply_curse("l_cam"), "aynı lanet iki kez alınmaz")
	check(not l.apply_curse("guc"), "lanetli olmayan kart lanet olarak uygulanmaz")
	eq(l.cursed_cards().size(), list.size() - 1, "alınan lanet listeden düşer")
	check(l.curses.has("l_cam") and l.taken.has("l_cam"), "lanet defterde")

func test_greed_curse_shrinks_offer() -> void:
	var l := _loadout()
	l.apply_curse("l_acgoz")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	eq(l.roll(3, rng).size(), 2, "Açgözlülük: 2 kart")

func test_missing_synergy_piece_gets_pity_weight() -> void:
	var l := _loadout()
	var base := l.card_weight(_by_id("drone"))
	l.apply(_by_id("coklu"))
	gt(l.card_weight(_by_id("drone")), base * 2.0, "elinde parçası olan sinerjinin eksik parçası daha sık sunulmalı")
	near(l.card_weight(_by_id("guc")), float(Loadout.load_rules()["tier_weight"]["common"]), 0.001, "ilgisiz kartın ağırlığı değişmez")

func test_ready_synergy_is_forced_after_misses() -> void:
	var l := _loadout()
	l.apply(_by_id("drone"))
	l.apply(_by_id("coklu"))
	var pity := int(Loadout.load_rules()["offer"]["synergy_pity_rolls"])
	l.synergy_miss = pity
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var offer := l.roll(3, rng)
	check(offer.any(func(c): return c["id"] == "s_kovan"), "acıma dolunca hazır sinerji garanti")
	eq(l.synergy_miss, 0, "sunulunca sayaç sıfırlanır")

func test_save_restore_round_trip() -> void:
	var l := _loadout()
	var base := [{"damage_mult": 0.1}]
	l.apply_effects(base[0])
	for id in ["guc", "coklu", "coklu", "delici"]:
		l.apply(_by_id(id))
	l.apply_curse("l_kor")
	l.banish("tetik")
	var saved := l.to_dict()
	var r := _loadout()
	r.from_dict(JSON.parse_string(JSON.stringify(saved)), base)
	eq(r.taken, l.taken, "kartlar aynı sırada")
	eq(r.banished, l.banished, "yasaklar")
	eq(r.banishes_left, l.banishes_left, "kalan yasak hakkı")
	eq(r.curses, l.curses, "lanetler")
	for key in l.mods:
		near(r.m(key), l.m(key), 0.0001, "çarpan aynı: " + str(key))

func test_offers_have_no_duplicates_over_many_rolls() -> void:
	var l := _loadout()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for n in 200:
		var offer := l.roll(3, rng)
		var ids := {}
		for c in offer:
			check(not ids.has(c["id"]), "aynı çekilişte tekrar yok")
			ids[c["id"]] = true
			check(c["tier"] != "cursed", "lanet sunulmaz")
		if not offer.is_empty():
			l.apply(offer[rng.randi() % offer.size()])
