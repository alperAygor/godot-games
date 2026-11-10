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
