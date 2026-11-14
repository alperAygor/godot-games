extends "res://tests/session_case.gd"
## "Nasıl oynanır" rehberi: ilk yeni oyunda otomatik açılır, bir kez görülünce tekrar çıkmaz, menüden yeniden açılır,
## sayfalar gezilir, her sayfanın metni ve çevirisi vardır.

var settings: Node


func before_each() -> void:
	super.before_each()
	settings = tree.root.get_node("SettingsManager")


func test_the_first_new_game_shows_the_guide_before_the_morning() -> void:
	settings.set_value("game", "guide_seen", false, false)
	await scenes.goto(Scenes.MAIN)
	await tap("NewGameButton")
	await tree.process_frame
	assert_true(node("GuideSheet") != null)
	assert_eq(scenes.current_path(), Scenes.MAIN)


func test_finishing_the_guide_continues_to_the_first_morning_and_is_remembered() -> void:
	settings.set_value("game", "guide_seen", false, false)
	await scenes.goto(Scenes.MAIN)
	await tap("NewGameButton")
	await tree.process_frame
	for i in GuideSheet.PAGES.size():
		await tap("GuideNext")
		await tree.process_frame
	await tree.create_timer(0.3).timeout
	assert_eq(scenes.current_path(), Scenes.MORNING)
	assert_true(bool(settings.get_value("game", "guide_seen")))


func test_skipping_also_counts_as_seen() -> void:
	settings.set_value("game", "guide_seen", false, false)
	await scenes.goto(Scenes.MAIN)
	await tap("NewGameButton")
	await tree.process_frame
	await tap("GuideSkip")
	await tree.create_timer(0.3).timeout
	assert_eq(scenes.current_path(), Scenes.MORNING)
	assert_true(bool(settings.get_value("game", "guide_seen")))


func test_a_new_game_after_the_guide_goes_straight_to_the_morning() -> void:
	settings.set_value("game", "guide_seen", true, false)
	await scenes.goto(Scenes.MAIN)
	await tap("NewGameButton")
	await tree.create_timer(0.3).timeout
	assert_true(node("GuideSheet") == null)
	assert_eq(scenes.current_path(), Scenes.MORNING)


func test_the_help_button_reopens_the_guide_and_closing_returns_to_the_menu() -> void:
	await scenes.goto(Scenes.MAIN)
	await tap("HelpButton")
	await tree.process_frame
	assert_true(node("GuideSheet") != null)
	await tap("GuideSkip")
	await tree.process_frame
	await tree.process_frame
	assert_true(node("GuideSheet") == null)
	assert_eq(scenes.current_path(), Scenes.MAIN)


func test_pages_can_be_walked_back_and_forth_and_back_key_steps_back() -> void:
	await scenes.goto(Scenes.MAIN)
	await tap("HelpButton")
	await tree.process_frame
	var guide: GuideSheet = node("GuideSheet")
	assert_eq(guide.page, 0)
	assert_false(node("GuideBack").visible)
	await tap("GuideNext")
	await tap("GuideNext")
	assert_eq(guide.page, 2)
	assert_true(node("GuideBack").visible)
	await tap("GuideBack")
	assert_eq(guide.page, 1)
	assert_true(guide.handle_back())
	assert_eq(guide.page, 0)


func test_every_page_has_its_own_title_and_text_in_both_languages() -> void:
	for locale in ["tr", "en"]:
		TranslationServer.set_locale(locale)
		var seen := {}
		for i in GuideSheet.PAGES.size():
			var text_id := int((GuideSheet.PAGES[i] as Dictionary).get("n", i + 1))
			var title := tr("GUIDE_T%d" % text_id)
			var body := tr("GUIDE_B%d" % text_id)
			assert_ne(title, "GUIDE_T%d" % text_id)
			assert_ne(body, "GUIDE_B%d" % text_id)
			assert_false(seen.has(title))
			seen[title] = true
	TranslationServer.set_locale("tr")


func test_the_android_back_key_walks_the_guide_back_then_closes_it() -> void:
	await scenes.goto(Scenes.MAIN)
	await tap("HelpButton")
	await tree.process_frame
	await tap("GuideNext")
	await TouchInput.back(tree)
	assert_eq((node("GuideSheet") as GuideSheet).page, 0)
	await TouchInput.back(tree)
	await tree.process_frame
	await tree.process_frame
	assert_true(node("GuideSheet") == null)
	assert_eq(scenes.current_path(), Scenes.MAIN)
