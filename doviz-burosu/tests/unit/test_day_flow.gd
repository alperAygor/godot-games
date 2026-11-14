extends "res://tests/session_case.gd"
## Gün akışı: ana menü -> sabah gazetesi -> masa -> akşam -> sabah; kayıt/devam, geri tuşları, oyun bitti.


func _new_game_from_menu() -> void:
	await scenes.goto(Scenes.MAIN)
	await tap("NewGameButton")
	await wait_for_scene(Scenes.MORNING)


## Belirli bir günün sabahını açar (kariyer ve kayıt hazır).
func _open_morning(day: int) -> void:
	session.new_game()
	session.career.day = day
	session.career.household.flags["mother_sick"] = day >= 6
	await scenes.goto(Scenes.MORNING)
	await tree.process_frame


## Vardiyası biten bir günün akşamını açar.
func _open_evening(day := 1, cash_pl := -1) -> void:
	session.new_game()
	session.career.day = day
	session.career.household.flags["mother_sick"] = day >= 6
	var shift: Shift = session.career.new_shift()
	shift.start()
	shift.advance(400.0)
	session.shift = shift
	if cash_pl >= 0:
		session.career.household.cash_minor = Money.units(cash_pl)
	await scenes.goto(Scenes.EVENING)
	await tree.process_frame


func _label_text(node_name: String) -> String:
	return (node(node_name) as Label).text


# --- Ana menü ----------------------------------------------------------------

func test_main_menu_hides_continue_without_a_save() -> void:
	await scenes.goto(Scenes.MAIN)
	assert_false(node("ContinueButton").visible)
	assert_true(node("NewGameButton").visible)


func test_new_game_opens_the_first_morning_and_saves() -> void:
	await _new_game_from_menu()
	assert_eq(session.career.day, 1)
	assert_true(session.has_save())
	assert_true(FileAccess.file_exists(SESSION_TEST_PATH))
	assert_eq(_label_text("DayLabel"), "Gün 1")


func test_continue_button_shows_the_saved_day_and_resumes_it() -> void:
	session.new_game()
	session.career.day = 2
	session.save()
	await scenes.goto(Scenes.MAIN)
	assert_true(node("ContinueButton").visible)
	assert_true((node("ContinueButton") as Button).text.contains("Gün 2"))
	await tap("ContinueButton")
	await wait_for_scene(Scenes.MORNING)
	assert_eq(_label_text("DayLabel"), "Gün 2")


func test_new_game_over_a_save_asks_for_confirmation() -> void:
	session.new_game()
	session.career.day = 2
	session.save()
	await scenes.goto(Scenes.MAIN)
	await tap("NewGameButton")
	assert_true(node("NewGameConfirm") != null)
	await tap("ConfirmNoButton")
	assert_true(node("NewGameConfirm") == null)
	assert_eq(session.saved_day(), 2, "hayır: kayıt korunur")
	await tap("NewGameButton")
	assert_true(tree.current_scene.handle_back(), "geri tuşu onayı kapatır")
	assert_true(node("NewGameConfirm") == null)
	assert_false(tree.current_scene.handle_back(), "onay yoksa ana menüde geri tuşu uygulamayı kapatır")
	await tap("NewGameButton")
	await tap("ConfirmYesButton")
	await wait_for_scene(Scenes.MORNING)
	assert_eq(session.saved_day(), 1, "evet: yeni oyun kaydı değiştirir")


# --- Sabah -------------------------------------------------------------------

func test_morning_paper_content_on_day_one() -> void:
	await _open_morning(1)
	assert_true(node("Masthead") != null)
	assert_eq(_label_text("Headline"), tr("NEWS_01_HEAD"))
	assert_true(node("Rate_FED") != null)
	assert_true(node("Rate_AVR") == null, "AVR 2. günde")
	assert_true(node("NewRule_R_EXCHANGE") != null)
	assert_true(node("BulletinCard") == null, "bülten 7. günde")
	assert_true(node("FamilyLine") != null)
	assert_true((node("CashLine") as Label).text.contains("300"))


func test_morning_paper_content_on_special_days() -> void:
	await _open_morning(3)
	assert_true(node("NewTool_uv") != null, "UV lamba 3. günde verilir")
	await _open_morning(5)
	assert_true(node("RentLine") != null, "5. gün kira günü")
	await _open_morning(7)
	assert_true(node("BulletinCard") != null, "çalıntı listesi 7. günde")
	assert_true(node("NewRule_R_STOLEN") != null)
	await _open_morning(12)
	assert_true(node("WantedFaces") != null, "aranan yüzler 12. günde")
	await _open_morning(14)
	assert_true(node("NoNewRule") != null, "14. günde yeni kural yok")


func test_morning_saves_the_game() -> void:
	await _open_morning(3)
	assert_eq(session.saved_day(), 3)
	assert_true(FileAccess.file_exists(SESSION_TEST_PATH))


func test_morning_shows_what_was_not_paid_yesterday() -> void:
	session.new_game()
	session.career.household.cash_minor = Money.units(5000)
	var shift: Shift = session.career.new_shift()
	shift.start()
	shift.advance(400.0)
	session.career.finish_day(shift, [])  # hiçbir şey ödenmedi
	await scenes.goto(Scenes.MORNING)
	await tree.process_frame
	assert_true(node("UnpaidLine") != null)
	assert_true(_label_text("UnpaidLine").contains("Yemek"))
	assert_true(_label_text("FamilyLine").contains("endişeli") or _label_text("FamilyLine").contains("iyi"))


func test_morning_back_button_asks_before_leaving() -> void:
	await _open_morning(1)
	var morning := tree.current_scene
	assert_true(morning.handle_back())
	await tree.process_frame
	assert_true(node("LeaveSheet") != null)
	assert_true(morning.handle_back(), "ikinci geri tuşu soruyu kapatır")
	assert_true(node("LeaveSheet") == null)
	morning.handle_back()
	await tree.process_frame
	await tap("LeaveNoButton")
	assert_true(node("LeaveSheet") == null)
	assert_eq(scenes.current_path(), Scenes.MORNING)
	morning.handle_back()
	await tree.process_frame
	await tap("LeaveYesButton")
	await wait_for_scene(Scenes.MAIN)


func test_start_shift_button_opens_the_desk() -> void:
	await _open_morning(2)
	await tap("StartShiftButton")
	await wait_for_scene(Scenes.DESK)
	assert_eq((node("DayLabel") as Label).text, "Gün 2")
	assert_true(session.career.day == 2)


# --- Akşam -------------------------------------------------------------------

func test_evening_summary_expenses_and_go_home() -> void:
	await _open_evening(1)
	assert_eq(_label_text("EveningTitle"), "Gün 1 akşamı")
	assert_true(node("SummaryCard") != null)
	assert_true(_label_text("NetPay").contains("305"), "hiç müşteri işlenmedi: yalnızca maaş")
	var food: Button = node("Expense_food")
	assert_true(food.button_pressed, "yetiyorsa varsayılan olarak seçili")
	assert_false(node("WarnLabel").visible, "her şey ödeniyor: uyarı yok")
	var cash_before_text := _label_text("AfterLabel")
	assert_true((node("Expense_food") as Button).text.contains("ödenecek"))
	await tap("Expense_food")
	assert_false((node("Expense_food") as Button).button_pressed)
	assert_true((node("Expense_food") as Button).text.contains("ödenmeyecek"))
	assert_true(node("WarnLabel").visible, "ödenmeyen gider uyarısı")
	assert_ne(_label_text("AfterLabel"), cash_before_text)
	await tap("Expense_food")
	assert_true((node("Expense_food") as Button).button_pressed)
	await tap("GoHomeButton")
	await wait_for_scene(Scenes.MORNING)
	assert_eq(session.career.day, 2)
	assert_eq(session.saved_day(), 2)
	assert_eq(session.career.history.size(), 1)
	assert_eq(session.career.household.mood, 100)


func test_evening_back_button_does_nothing() -> void:
	await _open_evening(1)
	assert_true(tree.current_scene.handle_back())
	assert_eq(scenes.current_path(), Scenes.EVENING)


func test_evening_does_not_let_you_pick_an_unaffordable_expense() -> void:
	await _open_evening(5, 0)  # nakit 0 + günün 305 PL maaşı: kira (1.100+) yetmez
	assert_true((node("Expense_rent") as Button).disabled)
	assert_false((node("Expense_rent") as Button).button_pressed)
	assert_true((node("Expense_rent") as Button).text.contains("yetmiyor"))
	assert_false((node("Expense_food") as Button).disabled)


func test_evening_savings_buttons_convert_cash_and_back() -> void:
	await _open_evening(1)
	var career: Career = session.career
	var cash_before := career.household.cash_minor
	await tap("ToForeign_100")
	assert_eq(career.household.cash_minor, cash_before - Money.units(100))
	assert_true(int(career.household.savings["FED"]) > 0)
	assert_true(_label_text("SavingsLine").contains("FED"))
	await tap("SellAllButton")
	assert_eq(int(career.household.savings["FED"]), 0)
	assert_true((node("SellAllButton") as Button).disabled, "bozdurulacak bir şey kalmadı")


func test_evening_buttons_are_disabled_when_cash_is_short() -> void:
	await _open_evening(1, 0)  # nakit 0 + 305 PL maaş
	assert_false((node("ToForeign_100") as Button).disabled)
	assert_true((node("ToForeign_500") as Button).disabled, "500 PL yok (305 PL var)")
	assert_true((node("ToForeign_1000") as Button).disabled, "1.000 PL yok")


func test_evening_shop_sells_the_tools_of_the_day() -> void:
	await _open_evening(3, 1000)
	assert_true(node("NoTools") != null, "3. günde dükkan boş")
	await _open_evening(4, 1000)
	assert_true(node("BuyTool_counter") != null)
	assert_true(node("BuyTool_rate_calc") != null)
	assert_true(node("BuyTool_magnifier") == null, "büyüteç 7. günde")
	var cash_before: int = session.career.household.cash_minor
	await tap_scrolled("BuyTool_counter")
	assert_true(session.career.has_tool("counter"))
	assert_eq(session.career.household.cash_minor, cash_before - Money.units(120))
	assert_true(node("BuyTool_counter") == null, "alınan araç listeden kalkar")
	assert_true(node("BuyTool_rate_calc") != null)
	await tap("GoHomeButton")
	await wait_for_scene(Scenes.MORNING)
	assert_true(session.career.has_tool("counter"), "araç sonraki güne taşınır")
	assert_eq(session.saved_day(), 5)


func test_evening_shop_disables_tools_you_cannot_afford() -> void:
	await _open_evening(7, 0)  # 0 + 305 PL maaş
	assert_false((node("BuyTool_magnifier") as Button).disabled, "60 PL yeter")
	assert_false((node("BuyTool_rate_calc") as Button).disabled, "200 PL yeter (305 PL var)")
	await tap_scrolled("BuyTool_counter")
	await tap_scrolled("BuyTool_magnifier")
	assert_true((node("BuyTool_rate_calc") as Button).disabled, "geriye 125 PL kaldı: 200 PL'lik araç alınamaz")


func test_evening_without_a_finished_shift_returns_to_the_menu() -> void:
	session.new_game()
	session.shift = null
	await scenes.goto(Scenes.EVENING)
	await wait_for_scene(Scenes.MAIN)


# --- Tüm akış, kayıt ve oyun bitti ----------------------------------------------

func _play_a_day_quickly() -> void:
	await tap("StartShiftButton")
	await wait_for_scene(Scenes.DESK)
	var desk := tree.current_scene
	desk.set_process(false)
	desk.tick(400.0)
	await tap("CompleteButton")
	await tap("ToEveningButton")
	await wait_for_scene(Scenes.EVENING)
	await tap("GoHomeButton")


func test_days_one_to_three_run_end_to_end_and_end_with_an_ending() -> void:
	session.last_playable_day = 3  # kısa bir oynanabilir bölüm gibi davran
	await _new_game_from_menu()
	for day in [1, 2, 3]:
		assert_eq(session.career.day, day)
		await _play_a_day_quickly()
		if day < 3:
			await wait_for_scene(Scenes.MORNING)
	await wait_for_scene(Scenes.GAME_OVER)
	assert_eq(session.career.day, 4)
	assert_eq(_label_text("GameOverTitle"), "Dürüst Memur", "hiçbir bayrak yok: kuralına uyan memur")
	assert_true(_label_text("EndingCount").contains("1 / 7"))
	assert_true(node("RetryDayButton") == null, "oyun bitmedi: tekrar oynama yok")
	assert_eq(session.career.history.size(), 3)
	await tap("NewGameButton")
	await wait_for_scene(Scenes.MORNING)
	assert_eq(session.career.day, 1)


func test_game_over_screen_offers_to_replay_the_day() -> void:
	session.new_game()
	var career: Career = session.career
	career.day = 6
	career.begin_day()
	career.game_over = "evicted"
	session.save()
	await scenes.goto(Scenes.GAME_OVER)
	await tree.process_frame
	assert_eq(_label_text("GameOverTitle"), "Kovuldun")
	assert_true(_label_text("GameOverMessage").contains("Evden atıldın"))
	await tap("RetryDayButton")
	await wait_for_scene(Scenes.MORNING)
	assert_eq(session.career.day, 6)
	assert_false(session.career.is_over())
	assert_eq(_label_text("DayLabel"), "Gün 6")


func test_game_over_without_a_snapshot_cannot_replay_and_menu_works() -> void:
	session.new_game()
	session.career.game_over = "fired"
	await scenes.goto(Scenes.GAME_OVER)
	await tree.process_frame
	assert_true(node("RetryDayButton") == null)
	assert_true(_label_text("GameOverMessage").contains("Kovuldun"))
	assert_true(tree.current_scene.handle_back())
	await wait_for_scene(Scenes.MAIN)


func test_relaunching_after_a_finished_day_returns_to_the_next_morning() -> void:
	await _new_game_from_menu()
	await _play_a_day_quickly()
	await wait_for_scene(Scenes.MORNING)
	var cash: int = session.career.household.cash_minor
	# Uygulama kapanıp açılmış gibi: bellek sıfırlanır, kayıt dosyadan okunur.
	session.career = null
	save_manager.data = {}
	save_manager.load_game()
	await scenes.goto(Scenes.MAIN)
	assert_true((node("ContinueButton") as Button).text.contains("Gün 2"))
	await tap("ContinueButton")
	await wait_for_scene(Scenes.MORNING)
	assert_eq(session.career.day, 2)
	assert_eq(session.career.household.cash_minor, cash)


func test_quitting_in_the_middle_of_a_shift_returns_to_that_morning() -> void:
	await _new_game_from_menu()
	var morning_cash: int = session.career.household.cash_minor
	await tap("StartShiftButton")
	await wait_for_scene(Scenes.DESK)
	var desk := tree.current_scene
	desk.set_process(false)
	desk.tick(60.0)
	await tap("CompleteButton")  # vardiyada bir müşteri işlendi, akşam yok
	session.career = null
	save_manager.data = {}
	save_manager.load_game()
	assert_true(session.continue_game())
	assert_eq(session.career.day, 1)
	assert_eq(session.career.household.cash_minor, morning_cash, "vardiya kazancı kaydedilmedi")
	assert_eq(session.route(), Scenes.MORNING)
