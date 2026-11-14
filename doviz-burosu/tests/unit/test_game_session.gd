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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


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
