extends TestCase

## StubSession: LevelSession sözleşmesinin sahte uygulaması (kabuk probeleri buna güvenir).
## Her dokunuş bir hamle; `solve_at`/par hamlede çözülür; geri al / baştan / ipucu sözleşmeye uyar.

var _session: StubSession = null
var _moves: Array[int] = []
var _pars: Array[int] = []
var _undo_flags: Array[bool] = []
var _solved: Array[Dictionary] = []
var _hints: Array[int] = [0]


func before_each() -> void:
	_moves.clear()
	_pars.clear()
	_undo_flags.clear()
	_solved.clear()
	_hints[0] = 0
	_session = StubSession.new()
	add_node(_session)
	_session.move_count_changed.connect(func(moves: int, par: int) -> void:
		_moves.append(moves)
		_pars.append(par))
	_session.can_undo_changed.connect(func(flag: bool) -> void: _undo_flags.append(flag))
	_session.solved.connect(func(result: Dictionary) -> void: _solved.append(result))
	_session.hint_finished.connect(func() -> void: _hints[0] += 1)


func after_each() -> void:
	_session.queue_free()


func test_unknown_level_is_refused() -> void:
	assert_false(_session.load_level("yok-boyle-seviye"))
	assert_true(_session.load_level(str(LevelCatalog.entries()[0]["id"])))


func test_load_reports_zero_moves_and_level_par() -> void:
	var entry: Dictionary = LevelCatalog.entries()[0]
	_session.load_level(str(entry["id"]))
	assert_eq(_moves.back(), 0)
	assert_eq(_pars.back(), int(entry["par"]))


func test_taps_count_as_moves_and_enable_undo() -> void:
	_session.load_level(str(LevelCatalog.entries()[1]["id"]))
	_session.solve_at = 50
	assert_true(_session.tap())
	assert_true(_session.tap())
	assert_eq(_moves.back(), 2)
	assert_true(_undo_flags.back())
	_session.undo()
	assert_eq(_moves.back(), 1)
	_session.undo()
	assert_false(_undo_flags.back(), "geri alınacak bir şey kalmadı")
	_session.undo()
	assert_eq(_moves.back(), 0, "boşken geri al taşmaz")


func test_restart_resets_moves() -> void:
	_session.load_level(str(LevelCatalog.entries()[1]["id"]))
	_session.solve_at = 50
	_session.tap()
	_session.tap()
	_session.restart()
	assert_eq(_moves.back(), 0)
	assert_false(_undo_flags.back())


func test_input_disabled_blocks_taps() -> void:
	_session.load_level(str(LevelCatalog.entries()[1]["id"]))
	_session.solve_at = 50
	_session.set_input_enabled(false)
	assert_false(_session.tap())
	assert_eq(_session.moves(), 0)
	_session.set_input_enabled(true)
	assert_true(_session.tap())


func test_solves_at_par_by_default_and_emits_once_after_celebration() -> void:
	var entry: Dictionary = LevelCatalog.entries()[0]
	_session.load_level(str(entry["id"]))
	for _i: int in int(entry["par"]):
		_session.tap()
	assert_false(_session.tap(), "çözüldükten sonra dokunuş işlenmez")
	assert_eq(_solved.size(), 0, "kutlama bekleyişi bitmeden sinyal yok")
	_session._emit_solved()
	_session._emit_solved()
	assert_eq(_solved.size(), 1, "solved tek kez")
	assert_eq(str(_solved[0]["level_id"]), str(entry["id"]))
	assert_eq(int(_solved[0]["moves"]), int(entry["par"]))
	assert_eq(int(_solved[0]["par"]), int(entry["par"]))


func test_solve_at_override_allows_above_par_results() -> void:
	var entry: Dictionary = LevelCatalog.entries()[0]
	_session.load_level(str(entry["id"]))
	_session.solve_at = int(entry["par"]) + 2
	for _i: int in int(entry["par"]) + 2:
		_session.tap()
	_session._emit_solved()
	assert_eq(int(_solved[0]["moves"]), int(entry["par"]) + 2)


func test_hint_finishes_with_signal() -> void:
	_session.load_level(str(LevelCatalog.entries()[1]["id"]))
	_session.show_hint()
	_session._finish_hint()
	assert_eq(_hints[0], 1)
