extends "res://tests/engine_case.gd"
## Hikaye çekirdeği: koşullar, yönetmen (olay/müşteri/seçim), vardiya entegrasyonu, müfettiş, sonlar ve içerik denetçisi.

var db: StoryDb


func before_each() -> void:
	super.before_each()
	db = StoryDb.load_default()


func _career(day: int, salt := "story-test") -> Career:
	var career := Career.load_default(salt)
	career.day = day
	career.story_enabled = true
	return career


func _beat(day: int, beat_id: String) -> Dictionary:
	for beat: Dictionary in db.day_def(day)["beats"]:
		if beat["id"] == beat_id:
			return beat
	fail("olay yok: %s" % beat_id)
	return {}


# --- Koşullar ---------------------------------------------------------------------

func test_story_state_conditions() -> void:
	var state := StoryState.new()
	assert_true(state.matches({}), "boş koşul her zaman sağlanır")
	assert_true(state.matches({"flags": {"x": false}}), "olmayan bayrak false sayılır")
	assert_false(state.matches({"flags": {"x": true}}))
	state.set_flag("x")
	state.add("n", 2)
	assert_true(state.matches({"flags": {"x": true}, "counters_min": {"n": 2}, "counters_max": {"n": 2}}))
	assert_false(state.matches({"counters_min": {"n": 3}}))
	assert_false(state.matches({"counters_max": {"n": 1}}))
	assert_false(state.matches({"flags": {"x": true}, "counters_min": {"n": 3}}), "hepsi sağlanmalı")


# --- İçerik denetçisi ----------------------------------------------------------------

func test_shipped_content_is_valid() -> void:
	var errors := StoryValidator.validate(db)
	assert_eq(errors, [] as Array[String], "\n".join(errors))


func test_validator_catches_broken_content() -> void:
	var broken := StoryDb.load_default()
	var day: Dictionary = broken._days[5]
	var beat: Dictionary = day["beats"][0].duplicate(true)
	beat["character"] = "nobody"
	beat["lines"] = ["NO_SUCH_KEY"]
	beat["customer"] = {"scenario": "no_such_scenario"}
	beat["after"] = 99
	beat["requires"] = {"flags": {"never_written": true}}
	beat["choice"]["options"].pop_back()
	day["beats"] = [beat]
	day["letters"] = []
	var text := "\n".join(StoryValidator.validate(broken))
	for expected in ["bilinmeyen karakter", "NO_SUCH_KEY", "bilinmeyen senaryo", "'after'", "never_written", "en az iki seçenek", "akşam mektubu yok"]:
		assert_true(text.contains(expected), "denetçi yakalamalı: %s\n%s" % [expected, text])


func test_validator_catches_unbuildable_customer_and_missing_free_option() -> void:
	var broken := StoryDb.load_default()
	var day: Dictionary = broken._days[2]
	var beat: Dictionary = day["beats"][0].duplicate(true)
	beat["customer"] = {"scenario": "stolen"}  # 2. günde R_STOLEN kapalı
	beat["choice"] = {"options": [
		{"id": "a", "text": "S_D05_TILKI_OPT_TAKE", "effects": {}, "requires": {"counters_min": {"skim_count": 1}}},
		{"id": "b", "text": "S_D05_TILKI_OPT_TAKE", "effects": {}, "requires": {"counters_min": {"skim_count": 1}}},
	]}
	day["beats"] = [beat]
	var text := "\n".join(StoryValidator.validate(broken))
	assert_true(text.contains("kurulamadı"), text)
	assert_true(text.contains("koşulsuz bir seçenek"), text)


# --- Yönetmen -----------------------------------------------------------------------

func test_director_serves_each_beat_once_in_order_and_respects_after() -> void:
	var career := _career(14)
	var director := StoryDirector.new(career, db)
	assert_eq(str(director.next_beat(0)["id"]), "d14_riza", "kesinti kapalıyken patronun normal sözü")
	assert_true(director.next_beat(0).is_empty(), "aynı olay iki kez çıkmaz; şapkalı müşteri 3 müşteri sonra")
	assert_true(director.next_beat(2).is_empty())
	assert_eq(str(director.next_beat(3)["id"]), "d14_stranger")
	career.story.set_flag("skim_accepted")
	assert_eq(str(StoryDirector.new(career, db).next_beat(0)["id"]), "d14_riza_skim", "kesinti kabul edildiyse patron başka konuşur")


func test_director_builds_the_scripted_customer_deterministically() -> void:
	var career := _career(5)
	var beat := _beat(5, "d05_tilki")
	var ctx := career.make_context()
	var first := StoryDirector.new(career, db).build_customer(beat, ctx)
	var second := StoryDirector.new(career, db).build_customer(beat, ctx)
	assert_true(first != null)
	assert_eq(first.holder_name, "Kemal Tilki")
	assert_eq(first.face_id, 902)
	assert_eq(first.character, "tilki")
	assert_eq(first.beat_id, "d05_tilki")
	assert_eq(first.scenario, "id_missing")
	assert_eq(first.truth["decision"], "reject", "beklenen hükme çıkana dek denenir")
	assert_eq(first.notes.size(), second.notes.size())
	assert_eq(first.notes[0].serial, second.notes[0].serial, "aynı oyun aynı müşteriyi verir")


func test_scripted_customer_documents_carry_the_character_identity() -> void:
	var career := _career(10)
	var customer := StoryDirector.new(career, db).build_customer(_beat(10, "d10_tilki"), career.make_context())
	assert_true(customer.id_card != null, "büyük işlem: kimlik gerekir")
	assert_eq(customer.id_card.holder_name, "Kemal Tilki")
	assert_eq(customer.id_card.face_id, customer.face_id)
	var verdict := RuleEngine.new(career.make_context()).evaluate(customer)
	assert_eq(verdict.decision, customer.truth["decision"], "motor, senaryonun doğrusunu onaylar")
	assert_eq(verdict.decision, "police")


func test_choice_applies_effects_and_money() -> void:
	var career := _career(5)
	var director := StoryDirector.new(career, db)
	var beat := _beat(5, "d05_tilki")
	var outcome := director.choose(beat, "take")
	assert_true(outcome["ok"])
	assert_eq(outcome["story_minor"], Money.units(200))
	assert_eq(career.story.counter("tilki_money"), 1)
	assert_false(director.choose(beat, "nope")["ok"], "olmayan seçenek")


func test_locked_options_cannot_be_chosen_and_unlock_with_requirements() -> void:
	var career := _career(15)
	var director := StoryDirector.new(career, db)
	var beat := _beat(15, "d15_tilki")
	var options := director.options(beat)
	assert_false(options[0]["available"], "pasaport: güven ve birikim yok")
	assert_true(options[1]["available"])
	assert_false(director.choose(beat, "passport")["ok"])
	career.story.add("tilki_money")
	assert_false(director.requirement_met({"counters_min": {"tilki_money": 1}, "savings_min": {"FED": 1000}}), "birikim hâlâ yok")
	career.household.savings["FED"] = 1000
	assert_true(director.choose(beat, "passport")["ok"])
	assert_true(career.story.flag("passport"))
	assert_eq(int(career.household.savings["FED"]), 0, "pasaportun bedeli birikimden düşer")


func test_pick_option_prefers_tags_then_honest() -> void:
	var career := _career(5)
	var director := StoryDirector.new(career, db)
	var beat := _beat(5, "d05_tilki")
	assert_eq(director.pick_option(beat, ["bribe"]), "take")
	assert_eq(director.pick_option(beat, []), "refuse", "etiket yoksa dürüst seçenek")
	assert_eq(director.pick_option(beat, ["ally"]), "refuse", "eşleşen etiket yoksa dürüst seçenek")


func test_on_decision_effects_follow_the_players_decision() -> void:
	var career := _career(5)
	var director := StoryDirector.new(career, db)
	director.on_decision("d05_tilki", "complete")
	director.on_decision("d05_tilki", "police")
	director.on_decision("d05_tilki", "reject")
	assert_eq(career.story.counter("tilki_helped"), 1)
	assert_eq(career.story.counter("tilki_reported"), 1)


func test_letters_pick_the_first_matching_variant() -> void:
	var story := StoryState.new()
	assert_eq(db.letter_key(5, story), "L_05_A")
	story.add("tilki_money")
	assert_eq(db.letter_key(5, story), "L_05_TAKEN")
	assert_eq(db.letter_key(1, story), "L_01_A")


# --- Vardiya entegrasyonu ------------------------------------------------------------

func test_shift_waits_for_the_opening_beat_and_freezes_time() -> void:
	var career := _career(1)
	var shift := career.new_shift()
	shift.start()
	assert_eq(str(shift.pending_beat["id"]), "d01_radio", "güne radyo haberiyle başlanır")
	assert_true(shift.resolve_beat())
	assert_eq(str(shift.pending_beat["id"]), "d01_riza")
	var before := shift.elapsed
	shift.advance(30.0)
	assert_eq(shift.elapsed, before, "olay bekleyen vardiyada zaman ilerlemez")
	assert_true(shift.resolve_beat(), "seçimsiz olay çözülür")
	assert_true(shift.pending_beat.is_empty())
	shift.advance(1.0)
	assert_true(shift.elapsed > before)


func test_shift_without_story_never_creates_beats() -> void:
	var career := _career(1)
	career.story_enabled = false
	var shift := career.new_shift()
	shift.start()
	assert_true(shift.pending_beat.is_empty())
	assert_true(shift.director == null)


func test_scripted_customer_arrives_after_the_right_number_of_customers() -> void:
	var career := _career(2)
	var shift := career.new_shift()
	shift.start()
	var bot := ClerkBot.new("perfect", "x")
	for i in 2:
		assert_true(shift.pending_beat.is_empty())
		assert_eq(shift.current.character, "")
		shift.advance(5.0)
		shift.submit(bot.move_for(shift.current, shift.current_verdict))
		shift.advance(5.0)
	assert_eq(str(shift.pending_beat["id"]), "d02_hayri")
	assert_eq(shift.current.character, "hayri")


func test_envelope_money_reaches_the_evening_cash() -> void:
	var career := _career(5)
	var shift := career.new_shift()
	shift.start()
	shift.stats["served"] = 3
	shift.pending_beat = {}
	shift._spawn()
	assert_eq(str(shift.pending_beat["id"]), "d05_tilki")
	assert_true(shift.resolve_beat("take"))
	var cash_before := career.household.cash_minor
	var report := career.begin_evening(shift)
	assert_eq(int(report["story_minor"]), Money.units(200))
	assert_eq(career.household.cash_minor, cash_before + int(report["net_minor"]) + Money.units(200))


func test_completing_the_dirty_customer_is_a_mistake_and_counts_as_helping() -> void:
	var career := _career(5)
	var shift := career.new_shift()
	shift.start()
	shift.stats["served"] = 3
	shift._spawn()
	shift.resolve_beat("refuse")
	var move := PlayerMove.new()
	move.decision = Verdict.DECISION_COMPLETE
	for i in shift.current.notes.size():
		move.fates.append(Verdict.FATE_ACCEPT)
	var result := shift.submit(move)
	assert_false(result["correct"], "kuralı eğmek hatadır")
	assert_eq(career.story.counter("tilki_helped"), 1)


func test_accepting_the_bosses_offer_starts_the_skim_in_the_same_shift() -> void:
	var career := _career(8)
	var shift := career.new_shift()
	shift.start()
	assert_eq(shift.skim_minor, 0)
	assert_true(shift.resolve_beat())  # radyo haberi
	assert_true(shift.resolve_beat("accept"))
	assert_eq(shift.skim_minor, Money.units(5))
	assert_true(career.story.flag("skim_accepted"))


func test_boss_offer_is_skipped_when_already_accepted() -> void:
	var career := _career(8)
	career.accept_skim()
	var shift := career.new_shift()
	shift.start()
	assert_true(shift.pending_beat.is_empty() or shift.pending_beat["id"] != "d08_riza")


func test_hayris_gift_depends_on_how_the_dilemma_was_resolved() -> void:
	var kind := _career(11)
	kind.story.add("hayri_helped")
	var shift := kind.new_shift()
	shift.start()
	shift.stats["served"] = 1
	shift._spawn()
	assert_eq(str(shift.pending_beat["id"]), "d11_hayri_thanks")
	shift.resolve_beat()
	assert_eq(int(shift.stats["story_minor"]), Money.units(60))
	var cold := _career(11)
	var cold_shift := cold.new_shift()
	cold_shift.start()
	cold_shift.stats["served"] = 1
	cold_shift._spawn()
	assert_eq(str(cold_shift.pending_beat["id"]), "d11_hayri_cold")
	cold_shift.resolve_beat()
	assert_eq(int(cold_shift.stats["story_minor"]), 0)


# --- Müfettiş -------------------------------------------------------------------------

func test_inspector_chance_combines_skims_tilki_and_good_behaviour() -> void:
	var career := _career(14)
	assert_eq(career.inspector_chance_percent(), 0, "temiz sicil")
	assert_false(career.inspector_catches())
	career.story.add("skim_count", 10)
	assert_eq(career.inspector_chance_percent(), 20)
	career.story.add("tilki_money", 1)
	career.story.add("tilki_helped", 1)
	assert_eq(career.inspector_chance_percent(), 80)
	career.story.add("tilki_helped", 1)
	assert_eq(career.inspector_chance_percent(), 90, "üst sınır")
	career.story.set_flag("inspector_pleased")
	assert_eq(career.inspector_chance_percent(), 45, "şapkalı müşteriye kurala uygun davranmak olasılığı yarıya indirir")
	career.story.set_flag("deniz_evidence")
	assert_eq(career.inspector_chance_percent(), 10, "tanıksan Tilki ile ilişkin silinir; yalnızca kesinti kalır, yarıya iner")


# --- Sonlar ---------------------------------------------------------------------------

func _ending_for(configure: Callable, game_over := "") -> String:
	var career := _career(16)
	career.game_over = game_over
	configure.call(career)
	return str(Endings.resolve(career, db)["id"])


func test_endings_resolve_by_priority() -> void:
	assert_eq(_ending_for(func(_c: Career) -> void: pass), "honest")
	assert_eq(_ending_for(func(c: Career) -> void: c.story.set_flag("skim_accepted")), "muddle")
	assert_eq(_ending_for(func(c: Career) -> void: c.story.add("tilki_money")), "muddle")
	assert_eq(_ending_for(func(c: Career) -> void: c.story.add("kind", 2)), "honest", "iki iyilik yetmez")
	assert_eq(_ending_for(func(c: Career) -> void: c.story.add("kind", 3)), "mercy")
	assert_eq(_ending_for(func(c: Career) -> void:
		c.story.add("kind", 3)
		c.story.add("tilki_money")), "muddle", "rüşvet merhameti siler")
	assert_eq(_ending_for(func(c: Career) -> void: c.story.set_flag("passport")), "escape")
	assert_eq(_ending_for(func(c: Career) -> void: c.story.set_flag("deniz_evidence")), "informant")
	assert_eq(_ending_for(func(c: Career) -> void:
		c.story.set_flag("deniz_evidence")
		c.story.set_flag("passport")), "informant", "kanıt vermek kaçıştan önce gelir")
	for reason in ["fired", "evicted", "family_left"]:
		assert_eq(_ending_for(func(c: Career) -> void: c.story.set_flag("deniz_evidence"), reason), "fired", reason)
	assert_eq(_ending_for(func(_c: Career) -> void: pass, "arrested"), "arrested")


func test_every_ending_has_texts_and_is_listed() -> void:
	assert_eq(Endings.all_ids(db).size(), 7)
	for ending_id in Endings.all_ids(db):
		for suffix in ["TITLE", "BODY"]:
			var key := "ENDING_%s_%s" % [ending_id.to_upper(), suffix]
			assert_ne(tree.root.tr(key), key, "%s çevrilmeli" % key)


# --- Botlarla tüm hikaye yolları ----------------------------------------------------------

func _play(profile: String, salt: String) -> Dictionary:
	var career := _career(1, salt)
	var bot := ClerkBot.new(profile, salt)
	var reports := bot.play_career(career, 15)
	var ending := Endings.resolve(career, db)
	return {"career": career, "reports": reports, "ending": str(ending.get("id", ""))}


func test_perfect_play_with_story_has_no_mistakes_and_reaches_the_honest_ending() -> void:
	for salt in ["sim-1", "sim-2", "sim-3"]:
		var run := _play("perfect", salt)
		var career: Career = run["career"]
		assert_eq(run["ending"], "honest", salt)
		assert_eq(career.day, 16, "15 gün bitti")
		assert_false(career.is_over(), salt)
		var mistakes := 0
		for report: Dictionary in run["reports"]:
			mistakes += int(report["shift"]["mistake_transactions"])
		assert_eq(mistakes, 0, "hikaye müşterileri de kusursuz oynanabilir: %s" % salt)
		assert_true(career.household.cash_minor > Money.units(20), "hikayeli oyun da yaşanabilir: %s" % salt)


func test_merciful_play_pays_from_the_pocket_without_breaking_a_rule_and_reaches_the_mercy_ending() -> void:
	for salt in ["sim-1", "sim-2", "sim-3"]:
		var run := _play("merciful", salt)
		var career: Career = run["career"]
		assert_eq(run["ending"], "mercy", salt)
		assert_true(career.story.counter("kind") >= 3, salt)
		assert_false(career.is_over(), "iyilik yaşanabilir kalmalı: %s" % salt)
		var mistakes := 0
		for report: Dictionary in run["reports"]:
			mistakes += int(report["shift"]["mistake_transactions"])
		assert_eq(mistakes, 0, "merhamet kuralı bozmadan yapılır: %s" % salt)


func test_ally_reaches_the_informant_ending() -> void:
	for salt in ["sim-1", "sim-2", "sim-3"]:
		var run := _play("ally", salt)
		assert_eq(run["ending"], "informant", salt)
		var story: StoryState = run["career"].story
		assert_true(story.flag("deniz_ally") and story.flag("deniz_evidence"))
		assert_true(story.counter("tilki_reported") >= 1, "kanıt, Tilki'yi polise bildirmekten gelir")


func test_escaper_reaches_the_escape_ending_with_the_passport() -> void:
	var escaped := 0
	for salt in ["sim-1", "sim-2", "sim-3", "sim-4"]:
		var run := _play("escaper", salt)
		assert_true(run["ending"] in ["escape", "arrested"], "%s: %s" % [salt, run["ending"]])
		if run["ending"] == "escape":
			escaped += 1
			assert_true(run["career"].story.flag("passport"))
	assert_true(escaped >= 3, "zarflar ve birikimle kaçış genelde olur (%d/4)" % escaped)


func test_cheating_paths_end_either_arrested_or_gray() -> void:
	var seen := {}
	for salt in ["sim-1", "sim-2", "sim-3", "sim-4", "sim-5", "sim-6", "sim-7", "sim-8"]:
		var run := _play("helper", salt)
		seen[run["ending"]] = true
		assert_true(run["ending"] in ["muddle", "arrested"], "%s: %s" % [salt, run["ending"]])
	assert_true(seen.has("muddle") and seen.has("arrested"), "kuralı eğen hem yakalanabilir hem sıyrılabilir: %s" % [seen.keys()])


func test_careless_play_can_end_fired() -> void:
	var career := _career(1, "sim-1")
	career.household.cash_minor = 0
	career.household.rent_missed = 1
	var bot := ClerkBot.new("careless", "x")
	bot.profile = bot.profile.duplicate()
	bot.profile["error_percent"] = 60  # çok dikkatsiz: bir gün 8 hatalı işleme varır
	bot.play_career(career, 15)
	assert_true(career.is_over())
	assert_eq(str(Endings.resolve(career, db)["id"]), "fired")
