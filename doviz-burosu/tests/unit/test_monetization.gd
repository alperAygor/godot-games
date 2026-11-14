extends "res://tests/session_case.gd"
## Para kazanma: AdPolicy koşulları, no_ads satın alma/geri yükleme, ödüllü reklam yerleri (akşam, masa, oyun bitti, modlar), Market.

const DATE := "2026-10-26"

var monetization: Node
var mock_ads: MockAdsProvider
var mock_iap: MockIapProvider
var desk: Control


func before_each() -> void:
	super.before_each()
	monetization = tree.root.get_node("Monetization")
	mock_ads = MockAdsProvider.new()
	mock_iap = MockIapProvider.new()
	tree.root.get_node("Ads").set_provider(mock_ads)
	tree.root.get_node("IAP").set_provider(mock_iap)
	monetization.last_ad_seconds = -100000.0
	monetization.clock_override = -1.0


func after_each() -> void:
	monetization.clock_override = -1.0
	await super.after_each()


func _label(node_name: String) -> String:
	return str(node(node_name).get("text"))


func _event_names() -> Array:
	return tree.root.get_node("Analytics").recent.map(func(e: Dictionary) -> String: return e["name"])


func _good_state() -> Dictionary:
	return {"owns_no_ads": false, "story_day": 5, "units": 10, "last_interstitial_unit": 5,
		"seconds_since_any_ad": 500.0, "session_play_seconds": 600.0, "session_index": 3}


func _wait_frames(count := 3) -> void:
	for i in count:
		await tree.process_frame


# --- AdPolicy ------------------------------------------------------------------------------

func test_interstitial_allowed_when_every_condition_holds() -> void:
	var decision := AdPolicy.interstitial(_good_state())
	assert_true(decision["allowed"])
	assert_eq(decision["blocked_by"], [] as Array[String])


func test_each_interstitial_condition_blocks_on_its_own() -> void:
	var cases := [
		["owns_no_ads", true, AdPolicy.BLOCK_NO_ADS],
		["story_day", 2, AdPolicy.BLOCK_STORY_DAY],
		["last_interstitial_unit", 9, AdPolicy.BLOCK_UNITS],
		["seconds_since_any_ad", 179.0, AdPolicy.BLOCK_ANY_AD],
		["session_play_seconds", 119.0, AdPolicy.BLOCK_SESSION_TIME],
		["session_index", 1, AdPolicy.BLOCK_FIRST_SESSION],
	]
	for case in cases:
		var state := _good_state()
		state[case[0]] = case[1]
		var decision := AdPolicy.interstitial(state)
		assert_false(decision["allowed"], str(case[0]))
		assert_eq(decision["blocked_by"], [case[2]] as Array[String], "yalnızca %s engellemeli" % case[0])


func test_interstitial_boundaries_are_inclusive() -> void:
	var state := _good_state()
	state["story_day"] = 3
	state["last_interstitial_unit"] = 8
	state["seconds_since_any_ad"] = 180.0
	state["session_play_seconds"] = 120.0
	state["session_index"] = 2
	assert_true(AdPolicy.interstitial(state)["allowed"], "tam sınırda gösterilir")


func test_policy_counts_play_units_between_interstitials() -> void:
	var state := _good_state()
	state["units"] = 6
	state["last_interstitial_unit"] = 6
	assert_false(AdPolicy.interstitial(state)["allowed"], "az önce gösterildi")
	state["units"] = 7
	assert_false(AdPolicy.interstitial(state)["allowed"], "1 birim yetmez")
	state["units"] = 8
	assert_true(AdPolicy.interstitial(state)["allowed"], "2 birim sonra")


func test_rewarded_limits_follow_ads_json() -> void:
	assert_true(AdPolicy.rewarded_within_limit("double_pay", 0))
	assert_false(AdPolicy.rewarded_within_limit("double_pay", 1), "günde 1")
	assert_true(AdPolicy.rewarded_within_limit("retry_day", 50), "retry_day sınırsız")
	assert_false(AdPolicy.rewarded_within_limit("daily_retry", 1))
	assert_false(AdPolicy.rewarded_within_limit("endless_continue", 1))
	assert_eq(int(AdPolicy.rewarded_config("overtime")["last_seconds"]), 60)


# --- Geçiş reklamı akışı (Monetization) ----------------------------------------------------------------

func _ready_for_interstitial() -> void:
	save_manager.data["ads"] = {"sessions": 5, "units": 10, "last_interstitial_unit": -1000000}
	save_manager.data["modes"] = {"max_day": 8}
	monetization.clock_override = 1000.0
	monetization.last_ad_seconds = 0.0


func test_allowed_interstitial_shows_then_continues_and_spaces_the_next_one() -> void:
	_ready_for_interstitial()
	assert_true(monetization.interstitial_decision()["allowed"])
	var order: Array = []
	mock_ads.interstitial_closed.connect(func(_p: String) -> void: order.append("closed"))
	monetization.show_interstitial_then("day_end", func() -> void: order.append("then"))
	await _wait_frames()
	assert_true("closed" in order and order.back() != null)
	assert_eq(order.count("then"), 1, "reklam kapanınca devam edilir (bir kez)")
	assert_true("interstitial_shown" in _event_names())
	assert_false(monetization.interstitial_decision()["allowed"], "hemen arkasından ikincisi gösterilmez")
	monetization.count_play_unit()
	monetization.count_play_unit()
	monetization.clock_override = 2000.0
	assert_true(monetization.interstitial_decision()["allowed"], "2 birim ve 180 sn sonra yine")


func test_blocked_interstitial_continues_immediately_without_an_ad() -> void:
	_ready_for_interstitial()
	save_manager.data["ads"]["sessions"] = 1  # ilk oturum
	var called := [0]
	var shown := [false]
	mock_ads.interstitial_closed.connect(func(_p: String) -> void: shown[0] = true)
	monetization.show_interstitial_then("day_end", func() -> void: called[0] += 1)
	assert_eq(called[0], 1)
	await _wait_frames()
	assert_false(shown[0])


func test_no_ads_owner_never_sees_an_interstitial_even_when_everything_else_allows_it() -> void:
	_ready_for_interstitial()
	save_manager.data["purchases"] = ["no_ads"]
	var decision: Dictionary = monetization.interstitial_decision()
	assert_false(decision["allowed"])
	assert_eq(decision["blocked_by"], [AdPolicy.BLOCK_NO_ADS] as Array[String])
	var shown := [false]
	mock_ads.interstitial_closed.connect(func(_p: String) -> void: shown[0] = true)
	monetization.show_interstitial_then("day_end", func() -> void: pass)
	await _wait_frames()
	assert_false(shown[0], "reklam hiç açılmaz")


func test_a_rewarded_ad_also_resets_the_any_ad_cooldown() -> void:
	_ready_for_interstitial()
	monetization.request_reward("rate_tip", func(_r: bool) -> void: pass)
	await _wait_frames()
	assert_true(AdPolicy.BLOCK_ANY_AD in monetization.interstitial_decision()["blocked_by"])


# --- Satın alma ve sahiplik ------------------------------------------------------------------------

func test_purchasing_no_ads_grants_saves_and_logs() -> void:
	assert_false(monetization.owns_no_ads())
	monetization.buy("no_ads")
	var result: Array = await monetization.purchase_result
	assert_eq(result[0], "no_ads")
	assert_true(result[1])
	assert_true(monetization.owns_no_ads())
	assert_true("no_ads" in save_manager.data["purchases"], "kayıt dosyasına yazılır")
	assert_true("iap_purchase" in _event_names())


func test_failed_purchase_grants_nothing() -> void:
	mock_iap.fail_next = "user_cancelled"
	monetization.buy("no_ads")
	var result: Array = await monetization.purchase_result
	assert_false(result[1])
	assert_eq(result[2], "user_cancelled")
	assert_false(monetization.owns_no_ads())


func test_restore_brings_back_ownership_from_the_store() -> void:
	monetization.buy("no_ads")
	await monetization.purchase_result
	save_manager.data.erase("purchases")  # yerel kayıt kaybolsa bile
	assert_false(monetization.owns_no_ads())
	monetization.restore()
	var restored: PackedStringArray = await monetization.restore_result
	assert_true("no_ads" in restored)
	assert_true(monetization.owns_no_ads(), "mağaza doğruluk kaynağıdır")


func test_restore_with_nothing_owned_is_harmless() -> void:
	monetization.restore()
	var restored: PackedStringArray = await monetization.restore_result
	assert_true(restored.is_empty())
	assert_false(monetization.owns_no_ads())


func test_purchase_survives_a_save_and_reload_round_trip() -> void:
	monetization.buy("no_ads")
	await monetization.purchase_result
	save_manager.save_game()
	save_manager.data = {}
	save_manager.load_game()
	assert_true(monetization.owns_no_ads())


# --- Ödüllü reklam çekirdeği ------------------------------------------------------------------------------

func test_rewarded_cancel_gives_no_reward_and_reward_gives_one() -> void:
	var results: Array = []
	mock_ads.cancel_next = true
	monetization.request_reward("rate_tip", func(rewarded: bool) -> void: results.append(rewarded))
	await _wait_frames()
	monetization.request_reward("rate_tip", func(rewarded: bool) -> void: results.append(rewarded))
	await _wait_frames()
	assert_eq(results, [false, true])
	assert_true("ad_offer_shown" in _event_names() and "ad_rewarded" in _event_names())


func test_a_second_request_while_one_is_pending_is_refused() -> void:
	var results: Array = []
	monetization.request_reward("rate_tip", func(rewarded: bool) -> void: results.append(["first", rewarded]))
	monetization.request_reward("double_pay", func(rewarded: bool) -> void: results.append(["second", rewarded]))
	await _wait_frames()
	assert_eq(results, [["second", false], ["first", true]])


func test_offer_state_hides_after_the_limit_and_disables_without_an_ad() -> void:
	assert_true(monetization.rewarded_offer("double_pay", 0)["enabled"])
	assert_false(monetization.rewarded_offer("double_pay", 1)["visible"])
	mock_ads.ready_state = false
	var offer: Dictionary = monetization.rewarded_offer("double_pay", 0)
	assert_true(offer["visible"] and not offer["enabled"], "reklam yoksa görünür ama pasif")


# --- Career ödülleri ---------------------------------------------------------------------------------------

func _evening_career(fines_pl := 0) -> Career:
	var career := Career.load_default("ad-test")
	career.day = 4
	var shift := career.new_shift()
	shift.start()
	shift.stats["bonus_minor"] = Money.units(45)
	shift.stats["fines_minor"] = Money.units(fines_pl)
	shift.advance(400.0)
	career.begin_evening(shift)
	return career


func test_double_pay_doubles_salary_and_bonus_but_not_fines() -> void:
	var career := _evening_career(30)
	var cash_before := career.household.cash_minor
	assert_eq(int(career.pending_report["net_minor"]), Money.units(305 + 45 - 30))
	assert_eq(career.double_pay_preview(), Money.units(305 + 45))
	var extra := career.double_pay()
	assert_eq(extra, Money.units(305 + 45), "fark = maaş + prim")
	assert_eq(int(career.pending_report["net_minor"]), Money.units(2 * (305 + 45) - 30), "ceza bir kez düşer")
	assert_eq(career.household.cash_minor, cash_before + extra)
	assert_eq(career.double_pay(), 0, "bir kez işler")
	assert_eq(career.double_pay_preview(), 0)


func test_rate_tip_matches_tomorrows_move() -> void:
	var career := Career.load_default("tip-test")
	career.day = 6
	var tip := career.rate_tip()
	var real := career.make_context().rates.change_bp("FED", 7)
	assert_eq(int(tip["percent_tenths"]), real / 10)
	assert_eq(int(tip["direction"]), signi(real))


func test_ad_uses_are_per_day_and_survive_save() -> void:
	var career := Career.load_default("uses")
	career.day = 3
	career.begin_day()
	assert_eq(career.ad_uses("double_pay"), 0)
	career.mark_ad_used("double_pay")
	assert_eq(career.ad_uses("double_pay"), 1)
	var loaded := Career.load_default("uses")
	loaded.load_dict(career.to_dict())
	assert_eq(loaded.ad_uses("double_pay"), 1, "kayıttan döner")
	loaded.day = 4
	assert_eq(loaded.ad_uses("double_pay"), 0, "ertesi gün yeniden hak")
	var again := Career.load_default("uses")
	again.load_dict(career.morning_snapshot)
	assert_eq(again.ad_uses("double_pay"), 0, "sabah anlık görüntüsü günün ödülünü içermez (gün tekrarı hakkı geri verir)")


# --- Akşam ekranı --------------------------------------------------------------------------------------------

func _open_evening(day := 4) -> void:
	session.new_game()
	session.career.day = day
	var shift: Shift = session.career.new_shift()
	shift.start()
	shift.advance(400.0)
	session.shift = shift
	await scenes.goto(Scenes.EVENING)
	await tree.process_frame


func test_evening_double_pay_offer_pays_and_disappears() -> void:
	await _open_evening()
	var cash_before: int = session.career.household.cash_minor
	assert_true(node("DoublePayButton") != null)
	await tap("DoublePayButton")
	await _wait_frames()
	assert_true(node("AdBonusLine") != null)
	assert_true(session.career.household.cash_minor > cash_before)
	assert_eq(session.career.ad_uses("double_pay"), 1)
	assert_true(node("DoublePayButton") == null, "günde 1")


func test_evening_cancelled_ad_pays_nothing_and_keeps_the_offer() -> void:
	await _open_evening()
	var cash_before: int = session.career.household.cash_minor
	mock_ads.cancel_next = true
	await tap("DoublePayButton")
	await _wait_frames()
	assert_eq(session.career.household.cash_minor, cash_before)
	assert_true(node("AdBonusLine") == null)
	assert_true(node("DoublePayButton") != null, "iptal edilince teklif durur")


func test_evening_offer_is_disabled_when_no_ad_is_ready() -> void:
	mock_ads.ready_state = false
	await _open_evening()
	var button := node("DoublePayButton") as Button
	assert_true(button != null and button.disabled)
	assert_eq(button.text, "Reklam şu an yok")


func test_evening_rate_tip_reveals_tomorrows_direction() -> void:
	await _open_evening(6)
	assert_true(node("RateTipLine") == null)
	await tap_scrolled("RateTipButton")
	await _wait_frames()
	assert_true(node("RateTipLine") != null)
	assert_true(_label("RateTipLine").contains("FED"))
	assert_true(node("RateTipButton") == null)


func test_going_home_counts_a_play_unit_and_logs_the_day() -> void:
	await _open_evening(2)
	var units_before := int(save_manager.data.get("ads", {}).get("units", 0))
	await tap("GoHomeButton")
	await wait_for_scene(Scenes.MORNING)
	assert_eq(int(save_manager.data["ads"]["units"]), units_before + 1)
	assert_true("day_end" in _event_names() and "day_start" in _event_names())


# --- Masa: mesai uzatma ----------------------------------------------------------------------------------------

func _open_desk(day := 2) -> Career:
	var career := Career.load_default("ot-test")
	career.day = day
	await scenes.goto(Scenes.DESK)
	desk = tree.current_scene
	desk.set_process(false)
	desk.play(career)
	await tree.process_frame
	return career


func test_overtime_offer_appears_in_the_last_minute_and_adds_time() -> void:
	var career := await _open_desk()
	assert_false((node("OvertimeButton") as Control).visible, "başta görünmez")
	desk.shift.elapsed = desk.shift.shift_seconds - 30.0
	desk.tick(0.0)
	await tree.process_frame
	assert_true((node("OvertimeButton") as Control).visible)
	var before: float = desk.shift.shift_seconds
	await tap("OvertimeButton")
	await _wait_frames()
	assert_eq(desk.shift.shift_seconds, before + 45.0)
	assert_eq(career.ad_uses("overtime"), 1)
	desk.tick(0.0)
	assert_false((node("OvertimeButton") as Control).visible, "günde 1")


func test_overtime_can_be_taken_from_the_end_of_shift_sheet() -> void:
	var career := await _open_desk()
	for i in 4:
		desk.tick(120.0)
	await tree.process_frame
	await tap("CompleteButton")  # ekrandaki son müşteri bitirilir, sonra mesai biter
	await tree.process_frame
	await tree.process_frame
	assert_true(node("ToEveningButton") != null, "mesai bitti sayfası")
	assert_true(node("OvertimeEndButton") != null)
	await tap("OvertimeEndButton")
	await _wait_frames()
	assert_true(node("ToEveningButton") == null, "mesai uzadı, sayfa kapandı")
	assert_eq(career.ad_uses("overtime"), 1)
	assert_false(desk.shift.is_closed())


func test_overtime_is_never_offered_in_mode_runs() -> void:
	session.start_daily(DATE)
	await scenes.goto(Scenes.DESK)
	desk = tree.current_scene
	desk.set_process(false)
	await tree.process_frame
	desk.shift.elapsed = desk.shift.shift_seconds - 20.0
	desk.tick(0.0)
	assert_false((node("OvertimeButton") as Control).visible)


# --- Oyun bitti, Günün Kuru, Sonsuz --------------------------------------------------------------------------------

func test_retry_day_needs_the_ad_and_a_cancel_keeps_the_game_over_screen() -> void:
	session.new_game()
	session.career.day = 6
	session.career.begin_day()
	session.career.game_over = "evicted"
	session.save()
	await scenes.goto(Scenes.GAME_OVER)
	await tree.process_frame
	mock_ads.cancel_next = true
	await tap("RetryDayButton")
	await _wait_frames()
	assert_eq(scenes.current_path(), Scenes.GAME_OVER, "iptal: günü tekrar oynamak yok")
	assert_false((node("RetryDayButton") as Button).disabled, "yeniden denenebilir")
	await tap("RetryDayButton")
	await wait_for_scene(Scenes.MORNING)
	assert_false(session.career.is_over())


func test_retry_day_without_an_ad_shows_the_unavailable_text() -> void:
	mock_ads.ready_state = false
	session.new_game()
	session.career.begin_day()
	session.career.game_over = "fired"
	await scenes.goto(Scenes.GAME_OVER)
	await tree.process_frame
	var button := node("RetryDayButton") as Button
	assert_true(button.disabled)
	assert_eq(button.text, "Reklam şu an yok")


func _finish_daily() -> void:
	session.start_daily(DATE)
	await scenes.goto(Scenes.DESK)
	desk = tree.current_scene
	desk.set_process(false)
	await tree.process_frame
	var bot := ClerkBot.new("perfect", "ui")
	for i in 12:
		desk.tick(3.0)
		var result: Dictionary = desk.shift.submit(bot.move_for(desk.shift.current, desk.shift.current_verdict))
		session.mode.on_submit(result)
		desk._shown = null
		desk._clear_customer()
		desk._sync()
	await tree.process_frame
	await tree.process_frame
	await tap("ToResultButton")
	await wait_for_scene(Scenes.MODE_RESULT)


func test_daily_retry_ad_gives_one_more_official_try_per_date() -> void:
	await _finish_daily()
	assert_true(node("DailyRetryButton") != null)
	await tap("DailyRetryButton")
	await wait_for_scene(Scenes.DESK)
	assert_true((session.mode as DailyChallenge).official, "reklamla kazanılan deneme resmi")
	assert_eq(session.modes().bonus_granted(DATE), 1)
	var offer: Dictionary = monetization.rewarded_offer("daily_retry", session.modes().bonus_granted(DATE))
	assert_false(offer["visible"], "aynı tarihte ikinci reklam teklif edilmez")


func test_daily_retry_cancel_changes_nothing() -> void:
	await _finish_daily()
	mock_ads.cancel_next = true
	await tap("DailyRetryButton")
	await _wait_frames()
	assert_eq(scenes.current_path(), Scenes.MODE_RESULT)
	assert_eq(session.modes().bonus_granted(DATE), 0)


func _wrong_move() -> PlayerMove:
	var move := PlayerMove.new()
	var expected: String = desk.shift.current_verdict.decision
	move.decision = Verdict.DECISION_POLICE if expected != Verdict.DECISION_POLICE else Verdict.DECISION_COMPLETE
	return move


func _serve_wrong() -> void:
	desk.tick(3.0)
	var result: Dictionary = desk.shift.submit(_wrong_move())
	session.mode.on_submit(result)
	desk._shown = null
	desk._clear_customer()
	desk._sync()


func test_endless_continue_ad_gives_one_life_once() -> void:
	session.start_endless("ad-1")
	await scenes.goto(Scenes.DESK)
	desk = tree.current_scene
	desk.set_process(false)
	await tree.process_frame
	for i in 3:
		_serve_wrong()
	await tree.process_frame
	await tree.process_frame
	assert_true(node("EndlessContinueButton") != null)
	await tap("EndlessContinueButton")
	await _wait_frames()
	assert_eq((session.mode as EndlessRun).lives, 1)
	assert_true(node("EndlessContinueButton") == null)
	desk.tick(3.0)
	await tree.process_frame
	assert_true(desk.shift.current != null, "koşu devam eder")
	_serve_wrong()
	await tree.process_frame
	await tree.process_frame
	assert_true(node("ToResultButton") != null)
	assert_true(node("EndlessContinueButton") == null, "koşu başına bir kez")


func test_mode_start_is_logged() -> void:
	session.start_endless("log-1")
	assert_true("mode_start" in _event_names())


# --- Market, ayarlar, destekçi süsü --------------------------------------------------------------------------------

func test_main_menu_opens_the_market() -> void:
	await scenes.goto(Scenes.MAIN)
	await tree.process_frame
	assert_false((node("MarketButton") as Button).disabled)
	await tap("MarketButton")
	await wait_for_scene(Scenes.MARKET)
	assert_eq(_label("BuyNoAdsButton"), "Satın al · $2.99")


func test_market_purchase_flow_and_owned_state() -> void:
	await scenes.goto(Scenes.MARKET)
	await tree.process_frame
	await tap("BuyNoAdsButton")
	await _wait_frames()
	assert_true(monetization.owns_no_ads())
	assert_eq(_label("BuyNoAdsButton"), "Satın alındı")
	assert_true((node("BuyNoAdsButton") as Button).disabled)
	assert_true(_label("MarketStatus").contains("Teşekkürler"))


func test_market_failed_purchase_keeps_the_button_usable() -> void:
	await scenes.goto(Scenes.MARKET)
	await tree.process_frame
	mock_iap.fail_next = "network"
	await tap("BuyNoAdsButton")
	await _wait_frames()
	assert_false(monetization.owns_no_ads())
	assert_false((node("BuyNoAdsButton") as Button).disabled)
	assert_true(_label("MarketStatus").contains("tamamlanamadı"))


func test_market_restore_button_reports_the_result() -> void:
	monetization.buy("no_ads")
	await monetization.purchase_result
	save_manager.data.erase("purchases")
	await scenes.goto(Scenes.MARKET)
	await tree.process_frame
	assert_true(_label("BuyNoAdsButton").begins_with("Satın al"))
	await tap("RestoreButton")
	await _wait_frames()
	assert_true(monetization.owns_no_ads())
	assert_eq(_label("MarketStatus"), "Satın alımlar geri yüklendi.")


func test_market_without_a_store_disables_buying() -> void:
	tree.root.get_node("IAP").set_provider(IapProvider.new())
	await scenes.goto(Scenes.MARKET)
	await tree.process_frame
	assert_true((node("BuyNoAdsButton") as Button).disabled)
	assert_eq(_label("BuyNoAdsButton"), "Mağaza şu an yok")


func test_settings_has_a_restore_button() -> void:
	await scenes.goto(Scenes.SETTINGS)
	await tree.process_frame
	assert_true(node("RestoreButton") != null)


func test_supporter_plant_only_for_no_ads_owners() -> void:
	await _open_desk()
	assert_true(node("SupporterDecor") == null)
	save_manager.data["purchases"] = ["no_ads"]
	await _open_desk()
	assert_true(node("SupporterDecor") != null)
