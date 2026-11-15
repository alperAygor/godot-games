extends "res://tests/engine_case.gd"
## GameSession: kayıt, devam, yeni oyun, yönlendirme. Gerçek kaydı bozmamak için test dosyası kullanılır.

const TEST_PATH := "user://test_session_save.json"

var session: Node
var save_manager: Node
var _original_path := ""
var _original_data := {}


func before_each() -> void:
	super.before_each()
	session = tree.root.get_node("GameSession")
	save_manager = tree.root.get_node("SaveManager")
	_original_path = save_manager.save_path
	_original_data = save_manager.data.duplicate(true)
	save_manager.save_path = TEST_PATH
	save_manager.data = {}
	session.career = null
	session.shift = null


func after_each() -> void:
	save_manager.save_path = _original_path
	save_manager.data = _original_data
	session.career = null
	session.shift = null
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH + suffix))


func test_new_game_creates_a_career_and_saves_it() -> void:
	assert_false(session.has_save())
	session.new_game()
	assert_true(session.has_save())
	assert_eq(session.saved_day(), 1)
	assert_eq(session.career.day, 1)
	assert_true(FileAccess.file_exists(TEST_PATH), "diske yazıldı")


func test_continue_restores_the_saved_state_through_the_file() -> void:
	session.new_game()
	session.career.day = 2
	session.career.household.cash_minor = Money.units(777)
	session.career.household.savings = {"FED": 5000}
	session.career.accept_skim()
	session.career.tools.append("uv")
	session.save()
	# Uygulama kapanıp açılmış gibi: bellek sıfırlanır, dosyadan okunur.
	session.career = null
	save_manager.data = {}
	save_manager.load_game()
	assert_true(session.has_save())
	assert_true(session.continue_game())
	assert_eq(session.career.day, 2)
	assert_eq(session.career.household.cash_minor, Money.units(777))
	assert_eq(session.career.household.savings, {"FED": 5000})
	assert_true(session.career.story.flag("skim_accepted"))
	assert_true(session.career.has_tool("uv"))


func test_continue_without_a_save_does_nothing() -> void:
	assert_false(session.continue_game())
	assert_eq(session.career, null)


func test_new_game_replaces_the_old_save() -> void:
	session.new_game()
	session.career.day = 3
	session.save()
	session.new_game()
	assert_eq(session.saved_day(), 1)


func test_clear_removes_the_save() -> void:
	session.new_game()
	session.clear()
	assert_false(session.has_save())
	save_manager.data = {}
	save_manager.load_game()
	assert_false(session.has_save(), "dosyada da yok")


func test_route_follows_the_game_state() -> void:
	session.new_game()
	assert_eq(session.route(), Scenes.MORNING)
	assert_false(session.is_finished())
	session.career.day = GameSession_last() + 1
	assert_true(session.is_finished(), "prototip sınırı aşıldı")
	assert_eq(session.route(), Scenes.GAME_OVER)
	session.career.day = 2
	session.career.game_over = "fired"
	assert_eq(session.route(), Scenes.GAME_OVER)


func GameSession_last() -> int:
	return session.LAST_PLAYABLE_DAY


func test_a_finished_day_saved_as_game_over_can_replay_the_morning() -> void:
	session.new_game()
	var career: Career = session.career
	career.day = 4
	career.begin_day()  # sabah anlık görüntüsü
	career.game_over = "fired"
	session.save()
	session.career = null
	assert_true(session.continue_game())
	assert_true(session.career.is_over())
	assert_true(session.career.restore_morning())
	assert_false(session.career.is_over())
	assert_eq(session.career.day, 4)


# --- Yaşam döngüsü kaydı ve bozuk kariyer bloğu ---------------------------------------------------------------

func test_pause_writes_the_in_memory_career_to_disk() -> void:
	session.new_game()
	session.career.household.cash_minor = Money.units(555)
	save_manager.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var on_disk: Dictionary = JsonIO.inspect(TEST_PATH)["data"]["data"]["career"]
	assert_eq(int(on_disk["household"]["cash_minor"]), Money.units(555))


func test_pause_during_the_evening_does_not_double_count_the_report() -> void:
	session.new_game()
	var before := Money.units(100)
	session.career.household.cash_minor = before
	session.save()
	session.career.pending_report = {"net_minor": 5000}  # akşam başladı: nakit işlendi, rapor kayda girmez
	session.career.household.cash_minor = before + 5000
	save_manager.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var on_disk: Dictionary = JsonIO.inspect(TEST_PATH)["data"]["data"]["career"]
	assert_eq(int(on_disk["household"]["cash_minor"]), before, "akşam ortasında son güvenli kayıt korunur")


func test_pause_in_a_mode_run_does_not_replace_the_story_save() -> void:
	session.new_game()
	var story_cash := Money.units(42)
	session.career.household.cash_minor = story_cash
	session.save()
	session.start_endless("lifecycle")
	session.career.household.cash_minor = Money.units(9999)
	save_manager.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var on_disk: Dictionary = JsonIO.inspect(TEST_PATH)["data"]["data"]["career"]
	assert_eq(int(on_disk["household"]["cash_minor"]), story_cash)
	session.abort_mode()


func test_continue_game_survives_a_corrupt_career_block() -> void:
	session.new_game()
	save_manager.data[session.SAVE_KEY] = {"day": "bozuk", "household": 7}
	assert_false(session.continue_game(), "okunamayan blok oyunu çökertmez")
	var good := Career.load_default("story")
	good.day = 3
	var broken := good.to_dict()
	broken["household"] = "bozuk"
	broken["morning_snapshot"] = good.to_dict()
	save_manager.data[session.SAVE_KEY] = broken
	assert_true(session.continue_game(), "sabah anlık görüntüsüne düşer")
	assert_eq(session.career.day, 3)
