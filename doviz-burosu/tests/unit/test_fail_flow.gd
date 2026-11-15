extends "res://tests/session_case.gd"
## Kovulma/oyun bitti akışı (O8, T-B1): ücretsiz hak → bedelli tekrar → reklamla bedelsiz tekrar → reklam yokken bedelli yol →
## no_ads sahibi bedelsiz → yeni oyun; uygulama oyun bitti ekranında kapanınca haklar korunur. Kural DayRetry, sayılar data/ads.json.

var mock_ads: MockAdsProvider
var _original_ads: Variant


func before_each() -> void:
	super.before_each()
	_original_ads = tree.root.get_node("Ads").provider
	mock_ads = MockAdsProvider.new()
	tree.root.get_node("Ads").set_provider(mock_ads)
	tree.root.get_node("Monetization")._ad_failed.clear()


func after_each() -> void:
	await super.after_each()
	tree.root.get_node("Ads").set_provider(_original_ads)


func _cfg() -> Dictionary:
	return DayRetry.config()


func _price() -> int:
	return DayRetry.price_minor(_cfg())


## 6. gün sabahı (nakit `cash_pl`) ve o gün kovulmuş kariyer; kayıtlı.
func _fired_on_day_six(cash_pl := 600) -> Career:
	session.new_game()
	var career: Career = session.career
	career.day = 6
	career.household.cash_minor = Money.units(cash_pl)
	career.begin_day()
	career.household.cash_minor = Money.units(cash_pl + 333)  # akşamın etkisi (geri alınacak)
	career.game_over = "fired"
	session.save()
	return career


func _fail_again() -> void:
	session.career.game_over = "fired"
	session.career.household.cash_minor += Money.units(77)
	session.save()
	await scenes.goto(Scenes.GAME_OVER)
	await tree.process_frame


func _button_text(node_name: String) -> String:
	return str(node(node_name).get("text"))


# --- Çekirdek (DayRetry + Career) ------------------------------------------------------------------

func test_shipped_rule_is_decided_and_never_gates_progress_behind_an_ad() -> void:
	var cfg := _cfg()
	assert_false(bool(cfg["decision_pending"]))
	assert_eq(str(cfg["available_when"]), RetryPolicy.WHEN_ALWAYS)
	assert_true(int(cfg["free_per_day"]) >= 1)
	assert_true(bool(cfg["no_ads_free"]))
	assert_eq(str(cfg["cost"]["kind"]), "cash_pl")
	assert_true(_price() > 0, "bedelli tekrar hissedilir olmalı")


func test_first_retry_of_a_day_is_free_then_paid_from_the_morning_cash() -> void:
	var career := _fired_on_day_six(600)
	var first := DayRetry.quote(career, false)
	assert_eq([first["kind"], first["cost_minor"], first["free_left"]], [DayRetry.KIND_FREE, 0, 1])
	assert_false(bool(first["ad_useful"]), "ücretsiz hak varken reklamın anlamı yok")
	assert_true(DayRetry.apply(career, first))
	assert_false(career.is_over())
	assert_eq(career.day, 6)
	assert_eq(career.household.cash_minor, Money.units(600), "sabah nakdine bedelsiz döndü")
	assert_eq(career.retries_used(), 1)
	career.game_over = "fired"
	var second := DayRetry.quote(career, false)
	assert_eq(second["kind"], DayRetry.KIND_PAID)
	assert_eq(second["cost_minor"], _price())
	assert_true(bool(second["ad_useful"]))
	assert_true(DayRetry.apply(career, second))
	assert_eq(career.household.cash_minor, Money.units(600) - _price())
	career.game_over = "fired"
	assert_true(DayRetry.apply(career, DayRetry.quote(career, false)))
	assert_eq(career.household.cash_minor, Money.units(600) - _price(), "bedel birikmez: her tekrar aynı sabahtan bir kez düşer")
	assert_eq(career.retries_used(), 3)


func test_paid_retry_never_takes_cash_below_the_floor() -> void:
	var floor := DayRetry.floor_minor(_cfg())
	var career := _fired_on_day_six(floor / Money.UNIT + 10)
	career.retries["6"] = 1
	var offer := DayRetry.quote(career, false)
	assert_eq(offer["cost_minor"], mini(_price(), Money.units(10)))
	assert_true(int(offer["cash_after_minor"]) >= floor)
	var poor := _fired_on_day_six(0)
	poor.retries["6"] = 1
	assert_eq(DayRetry.quote(poor, false)["cost_minor"], 0, "tabanın altındaki oyuncudan bedel alınmaz: oyun kazanılamaz hale gelmez")


func test_no_ads_owner_retries_without_cost_or_ad() -> void:
	var career := _fired_on_day_six()
	career.retries["6"] = 4
	var offer := DayRetry.quote(career, true)
	assert_eq([offer["kind"], offer["cost_minor"], offer["ad_useful"]], [DayRetry.KIND_NO_ADS, 0, false])


func test_free_replay_is_per_day_and_survives_saving() -> void:
	var career := _fired_on_day_six()
	assert_true(DayRetry.apply(career, DayRetry.quote(career, false)))
	var copy := Career.load_default("story")
	copy.load_dict(career.to_dict())
	assert_eq(copy.retries_used(6), 1, "kayıtla gider")
	assert_eq(copy.retries_used(7), 0, "başka günün hakkı ayrı")
	assert_true(Career.is_valid_dict(career.to_dict()))
	copy.game_over = "fired"
	assert_true(copy.restore_morning())
	assert_eq(copy.retries_used(6), 1, "sabaha dönmek hakkı geri vermez")


# --- Arayüz: tüm yol -----------------------------------------------------------------------------

func test_whole_fail_path_free_then_paid_then_ad_then_no_ad_then_no_ads_owner_then_new_game() -> void:
	mock_ads.ready_state = true
	_fired_on_day_six(600)
	await scenes.goto(Scenes.GAME_OVER)
	await tree.process_frame
	# 1) Ücretsiz hak: tek birincil düğme, reklam teklifi yok, sonuç önceden yazılı.
	assert_eq(_button_text("RetryDayButton"), "Günü tekrar oyna: ücretsiz")
	assert_true(node("RetryAdButton") == null)
	assert_true((node("RetryKeep") as Label).text.contains("600"), "sabah nakdi seçimden önce görünür")
	await tap("RetryDayButton")
	await wait_for_scene(Scenes.MORNING)
	assert_eq(session.career.household.cash_minor, Money.units(600))
	assert_eq(session.career.retries_used(), 1)
	# 2) Hak bitti: bedel düğmede ve notta; reklam alternatifi açık.
	await _fail_again()
	var price_text := UiKit.money(_price(), "PL")
	assert_true(_button_text("RetryDayButton").contains(price_text), _button_text("RetryDayButton"))
	assert_true((node("RetryDetail") as Label).text.contains(UiKit.money(Money.units(600) - _price(), "PL")))
	assert_false((node("RetryAdButton") as Button).disabled)
	await tap("RetryDayButton")
	await wait_for_scene(Scenes.MORNING)
	assert_eq(session.career.household.cash_minor, Money.units(600) - _price(), "bedelli tekrar")
	# 3) Reklamla bedelsiz tekrar.
	await _fail_again()
	await tap("RetryAdButton")
	await wait_for_scene(Scenes.MORNING)
	assert_eq(session.career.household.cash_minor, Money.units(600), "reklam bedeli siler")
	# 4) Reklam yok: reklam düğmesi pasif, bedelli yol açık.
	mock_ads.ready_state = false
	await _fail_again()
	assert_true((node("RetryAdButton") as Button).disabled)
	assert_eq(_button_text("RetryAdButton"), "Reklam şu an yok")
	assert_false((node("RetryDayButton") as Button).disabled)
	await tap("RetryDayButton")
	await wait_for_scene(Scenes.MORNING)
	assert_eq(session.career.household.cash_minor, Money.units(600) - _price())
	# 5) no_ads sahibi: reklamsız ve bedelsiz.
	save_manager.data["purchases"] = ["no_ads"]
	await _fail_again()
	assert_eq(_button_text("RetryDayButton"), "Günü tekrar oyna: ücretsiz (reklamsız)")
	assert_true(node("RetryAdButton") == null)
	await tap("RetryDayButton")
	await wait_for_scene(Scenes.MORNING)
	assert_eq(session.career.household.cash_minor, Money.units(600))
	assert_eq(session.career.retries_used(), 5)
	save_manager.data["purchases"] = []
	# 6) Yeni oyun her zaman var (tek çıkış değil).
	await _fail_again()
	assert_true(node("NewGameNote") != null)
	await tap("NewGameButton")
	await wait_for_scene(Scenes.MORNING)
	assert_eq(session.career.day, 1)
	assert_false(session.career.is_over())


func test_closing_the_app_on_the_game_over_screen_keeps_the_choice_and_the_spent_free_replay() -> void:
	mock_ads.ready_state = false
	_fired_on_day_six(600)
	await scenes.goto(Scenes.GAME_OVER)
	await tree.process_frame
	# Uygulama kapandı: bellek gider, kayıt kalır.
	session.career = null
	assert_true(session.continue_game())
	assert_eq(session.route(), Scenes.GAME_OVER)
	await scenes.goto(Scenes.GAME_OVER)
	await tree.process_frame
	assert_eq(_button_text("RetryDayButton"), "Günü tekrar oyna: ücretsiz", "kapanış hakkı yakmaz")
	await tap("RetryDayButton")
	await wait_for_scene(Scenes.MORNING)
	# Ücretsiz hak harcandıktan sonra tekrar kovuldu ve kapattı: hak geri gelmez, bedelli yol hazır.
	session.career.game_over = "fired"
	session.save()
	session.career = null
	assert_true(session.continue_game())
	assert_eq(session.career.retries_used(), 1)
	await scenes.goto(Scenes.GAME_OVER)
	await tree.process_frame
	assert_true(_button_text("RetryDayButton").contains(UiKit.money(_price(), "PL")))
	assert_true(node("NewGameButton") != null and node("MenuButton") != null)


func test_story_end_has_one_primary_action_and_no_retry_card() -> void:
	session.last_playable_day = 3
	session.new_game()
	session.career.day = 4
	await scenes.goto(Scenes.GAME_OVER)
	await tree.process_frame
	assert_true(node("RetryCard") == null)
	assert_eq((node("NewGameButton") as Button).theme_type_variation, &"InkButton")
