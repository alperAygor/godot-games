extends "res://tests/session_case.gd"
## Hikaye ekranları: masadaki olay sayfası (söz, seçim, kilitli seçenek), akşam mektubu ve zarf, sonlar ekranı.

var desk: Control


func _open_desk(day: int, salt := "story-ui") -> Career:
	var career := Career.load_default(salt)
	career.day = day
	career.story_enabled = true
	await scenes.goto(Scenes.DESK)
	desk = tree.current_scene
	desk.set_process(false)
	desk.play(career)
	await tree.process_frame
	return career


## Masada `count` müşteriyi kusursuz işler (olay sayfası açık değilken).
func _serve(count: int) -> void:
	var bot := ClerkBot.new("perfect", "ui")
	for i in count:
		desk.tick(3.0)
		await tree.process_frame
		assert_true(desk.shift.current != null, "müşteri gelmeli")
		desk.shift.submit(bot.move_for(desk.shift.current, desk.shift.current_verdict))
		desk._shown = null
		desk._clear_customer()
		desk._sync()
	desk.tick(3.0)
	await tree.process_frame


func _text(node_name: String) -> String:
	return (node(node_name) as Label).text


func test_boss_greeting_opens_before_the_first_customer_and_freezes_time() -> void:
	await _open_desk(1)
	assert_true(node("StorySheet") != null, "ilk gün önce radyo, sonra patron konuşur")
	assert_eq(_text("SheetTitle"), "Radyo")
	assert_eq(_text("CustomerName"), "", "olay bitmeden müşteri görünmez")
	await tap("StoryContinueButton")
	assert_eq(_text("SheetTitle"), "Rıza Bey (patron)")
	assert_true(_text("StoryLine1").contains("Rıza"))
	assert_eq(_text("CustomerName"), "", "olay bitmeden müşteri görünmez")
	assert_true((node("CompleteButton") as Button).disabled)
	var clock := _text("ClockLabel")
	desk.tick(30.0)
	assert_eq(_text("ClockLabel"), clock, "olay açıkken saat durur")
	assert_true(desk.handle_back(), "geri tuşu yutulur")
	assert_true(node("StorySheet") != null, "geri tuşu olay sayfasını kapatmaz")
	await tap("StoryContinueButton")
	assert_true(node("StorySheet") == null)
	assert_ne(_text("CustomerName"), "")
	assert_false((node("CompleteButton") as Button).disabled)


func test_choice_sheet_takes_the_envelope_then_shows_the_customer() -> void:
	var career := await _open_desk(5)
	await _serve(3)
	assert_true(node("StorySheet") != null, "3. müşteriden sonra Tilki")
	assert_eq(_text("SheetTitle"), "Tilki")
	assert_eq(_text("CustomerName"), "", "seçim yapılmadan müşteri görünmez")
	assert_false((node("StoryOption_take") as Button).disabled)
	await tap("StoryOption_take")
	assert_true(node("StorySheet") == null)
	assert_eq(career.story.counter("tilki_money"), 1)
	assert_eq(_text("CustomerName"), "Kemal Tilki")
	assert_eq(int(desk.shift.stats["story_minor"]), Money.units(200))


func test_refusing_the_envelope_keeps_the_money_out() -> void:
	var career := await _open_desk(5)
	await _serve(3)
	await tap("StoryOption_refuse")
	assert_eq(career.story.counter("tilki_money"), 0)
	assert_eq(career.story.counter("tilki_refused"), 1)
	assert_eq(int(desk.shift.stats["story_minor"]), 0)


func test_the_passport_option_is_locked_without_trust_and_savings() -> void:
	await _open_desk(15)
	await tap("StoryContinueButton")  # radyo
	await tap("StoryContinueButton")  # Rıza
	await _serve(2)
	assert_true(node("StorySheet") != null)
	assert_true((node("StoryOption_passport") as Button).disabled)
	assert_true((node("StoryOption_passport") as Button).text.contains("olanaksız"))
	assert_false((node("StoryOption_refuse") as Button).disabled)
	var career: Career = desk.career
	career.story.add("tilki_money")
	career.household.savings["FED"] = 1000
	desk._story_sheet_for = ""
	desk._close_sheet()
	desk._sync()
	await tree.process_frame
	assert_false((node("StoryOption_passport") as Button).disabled, "güven ve birikimle pasaport açılır")
	await tap("StoryOption_passport")
	assert_true(career.story.flag("passport"))


func test_evening_shows_the_letter_and_the_envelope() -> void:
	session.new_game()
	var career: Career = session.career
	career.story_enabled = true
	career.day = 5
	var shift := career.new_shift()
	shift.start()
	shift.stats["story_minor"] = Money.units(200)
	shift.advance(400.0)
	career.story.add("tilki_money")
	session.shift = shift
	await scenes.goto(Scenes.EVENING)
	await tree.process_frame
	assert_true(node("LetterCard") != null)
	assert_true(_text("LetterText").contains("sakin"), "zarf alındıysa Selma'nın şüpheli mektubu")
	var summary := ""
	for label in node("SummaryCard").find_children("*", "Label", true, false):
		summary += (label as Label).text + "\n"
	assert_true(summary.contains("Zarf"), summary)


func test_evening_without_story_has_no_letter() -> void:
	session.new_game()
	var shift: Shift = session.career.new_shift()
	shift.start()
	shift.advance(400.0)
	session.shift = shift
	await scenes.goto(Scenes.EVENING)
	await tree.process_frame
	assert_true(node("LetterCard") == null)


func test_ending_screen_shows_title_body_and_counts_endings_across_games() -> void:
	session.new_game()
	var career: Career = session.career
	career.day = 16
	career.story.set_flag("deniz_evidence")
	await scenes.goto(Scenes.GAME_OVER)
	await tree.process_frame
	assert_eq(_text("GameOverTitle"), "Muhbir")
	assert_true(_text("GameOverMessage").contains("Tilki"))
	assert_true(_text("EndingCount").contains("1 / 7"))
	assert_eq(session.endings_seen(), ["informant"] as Array[String])
	# Yeni oyun sonları silmez; ikinci son sayıya eklenir.
	session.new_game()
	session.career.day = 16
	session.career.story.set_flag("passport")
	await scenes.goto(Scenes.GAME_OVER)
	await tree.process_frame
	assert_eq(_text("GameOverTitle"), "Kaçış")
	assert_true(_text("EndingCount").contains("2 / 7"))
	await scenes.goto(Scenes.GAME_OVER)
	await tree.process_frame
	assert_true(_text("EndingCount").contains("2 / 7"), "aynı son iki kez sayılmaz")


func test_arrest_ending_shows_the_story_and_the_reason() -> void:
	session.new_game()
	session.career.day = 14
	session.career.begin_day()
	session.career.game_over = "arrested"
	await scenes.goto(Scenes.GAME_OVER)
	await tree.process_frame
	assert_eq(_text("GameOverTitle"), "Tutuklandın")
	assert_true(_text("GameOverMessage").contains("Nalan"))
	assert_true(_text("GameOverMessage").contains("Müfettiş seni yakaladı"))
