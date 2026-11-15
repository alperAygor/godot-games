extends TestCase
## DayRun: olay listesi → zaman çizelgesi. Sıra korunur, gün ≤ ~8 sn, dilim okunacak kadar uzun,
## dokunuş hızlandırır ama sigortadan sonrası gerçek hızdadır, duraklatma/arka plan zamanı yutmaz.

var content: PrizContent
var data: SliceData


func before_each() -> void:
	if content == null:
		content = PrizContent.load_default()
	if data == null:
		data = SliceData.load_default()


func _day_index() -> int:
	for i: int in data.level_count():
		if data.load_level(i).is_day_mode():
			return i
	return -1


## İlk gün seviyesi; `clean` true ise çözücünün planı, değilse ilk iki cihaz aynı hatta (taşar).
func _board(clean: bool) -> PrizBoard:
	var level: PrizLevel = data.load_level(_day_index())
	var board: PrizBoard = PrizBoard.new(level, content.registry)
	if clean:
		board.apply_placement(PrizSolver.new().first_solution(level, content.registry))
	else:
		# Seviye 8: buzdolabı + lamba kırmızı hatta → akşam taşar.
		var red: Array[String] = board.line_sockets(level.lines[0].id)
		board.plug(level.devices[0].id, red[0])
		board.plug(level.devices[1].id, red[1])
	return board


func _drain(run: DayRun, dt: float = 1.0 / 60.0, limit: float = 60.0) -> Array[DayRun.Step]:
	var all: Array[DayRun.Step] = []
	var t: float = 0.0
	while not run.is_finished() and t < limit:
		all.append_array(run.advance(dt))
		t += dt
	return all


func test_day_levels_exist_after_flat_ones() -> void:
	var first: int = _day_index()
	assert_eq(first, 7, "gün kipi sekizinci kesit seviyesinde başlar")
	for i: int in range(first):
		assert_false(data.load_level(i).is_day_mode(), "düz seviyeler önce")


func test_clean_day_preserves_event_order_and_wins() -> void:
	var board: PrizBoard = _board(true)
	var events: Array[PrizEvent] = board.start_day()
	var run: DayRun = DayRun.new(events)
	assert_eq(run.outcome(), PrizEvent.WIN)
	var played: Array[DayRun.Step] = _drain(run)
	assert_eq(played.size(), events.size(), "her olay bir kez")
	for i: int in played.size():
		assert_eq(played[i].event, events[i], "sıra korunur")
		if i > 0:
			assert_true(played[i].time >= played[i - 1].time, "zaman geri gitmez")
	assert_true(run.duration() <= 8.5, "temiz gün ~8 sn (%.2f)" % run.duration())
	assert_true(run.duration() >= 6.5, "dilimler okunacak kadar uzun (%.2f)" % run.duration())


func test_slices_are_spaced_for_reading() -> void:
	var run: DayRun = DayRun.new(_board(true).start_day())
	var begins: Array[float] = []
	for step: DayRun.Step in run.steps:
		if step.event.type == PrizEvent.SLICE_BEGIN:
			begins.append(step.time)
	assert_eq(begins.size(), 4)
	for i: int in range(1, begins.size()):
		var gap: float = begins[i] - begins[i - 1]
		assert_true(gap >= 1.5 and gap <= 2.0, "dilim süresi 1.5-2 sn (%.2f)" % gap)


func test_overflow_blows_then_returns_to_planning_after_drama() -> void:
	var board: PrizBoard = _board(false)
	var run: DayRun = DayRun.new(board.start_day())
	assert_eq(run.outcome(), PrizEvent.BACK_TO_PLANNING)
	assert_eq(run.blow_slice(), PrizSlice.EVENING, "lamba akşam yanınca taşar")
	assert_eq(run.blown_lines().size(), 1)
	var blow_t: float = -1.0
	var back_t: float = -1.0
	for step: DayRun.Step in run.steps:
		if step.event.type == PrizEvent.FUSE_BLOWN:
			blow_t = step.time
		elif step.event.type == PrizEvent.BACK_TO_PLANNING:
			back_t = step.time
	assert_true(back_t - blow_t >= 2.0, "karanlık + sessizlik + neden en az iki saniye")
	assert_true(board.is_planning(), "tahta planlamada")
	assert_eq(board.fuse_rights(), 2, "bir hak gitti")
	assert_eq(board.placement().size(), 2, "plan silinmez")


func test_fast_forward_speeds_slices_but_not_the_blow() -> void:
	var board: PrizBoard = _board(false)
	var run: DayRun = DayRun.new(board.start_day())
	var blow_t: float = 0.0
	for step: DayRun.Step in run.steps:
		if step.event.type == PrizEvent.FUSE_BLOWN:
			blow_t = step.time
	run.advance(0.05)
	run.fast_forward()
	assert_true(run.is_fast())
	var real: float = 0.05
	while run.clock < blow_t and real < 30.0:
		run.advance(1.0 / 60.0)
		real += 1.0 / 60.0
	assert_true(real < blow_t * 0.6, "hızlandırma sigortaya erken varır (%.2f / %.2f)" % [real, blow_t])
	assert_false(run.is_fast(), "sigortada gerçek hıza döner")
	var t0: float = run.clock
	run.fast_forward()
	run.advance(0.1)
	assert_almost_eq(run.clock - t0, 0.1, 0.0001, "sigortadan sonra hızlandırma yok")


func test_pause_and_long_frames_do_not_skip_steps() -> void:
	var run: DayRun = DayRun.new(_board(true).start_day())
	run.advance(0.2)
	run.pause()
	assert_eq(run.advance(5.0).size(), 0, "duraklatılmışken adım yok")
	var c: float = run.clock
	run.resume()
	run.advance(30.0)
	assert_almost_eq(run.clock - c, DayRun.MAX_STEP, 0.0001, "uzun kare (arka plandan dönüş) kısılır")
	assert_false(run.is_finished())


func test_three_blows_lose_and_extra_right_returns_to_planning() -> void:
	var board: PrizBoard = _board(false)
	var outcomes: Array[StringName] = []
	for i: int in 3:
		outcomes.append(DayRun.new(board.start_day()).outcome())
	assert_eq(outcomes, [PrizEvent.BACK_TO_PLANNING, PrizEvent.BACK_TO_PLANNING, PrizEvent.LOSE] as Array[StringName])
	assert_true(board.is_lost())
	assert_eq(board.placement().size(), 2, "kayıpta da plan durur")
	board.grant_extra_right()
	assert_true(board.is_planning())
	assert_eq(board.fuse_rights(), 1)


func test_current_slice_follows_clock() -> void:
	var run: DayRun = DayRun.new(_board(true).start_day())
	assert_eq(run.current_slice(), -1)
	while run.clock < DayRun.LEAD - 0.05:
		run.advance(0.04)
	assert_eq(run.current_slice(), -1)
	run.advance(0.08)
	assert_eq(run.current_slice(), PrizSlice.MORNING)
	while run.clock < DayRun.LEAD + DayRun.SLICE_SECONDS * 2.0 + 0.02:
		run.advance(0.05)
	assert_eq(run.current_slice(), PrizSlice.EVENING)


func test_empty_events_finish_immediately() -> void:
	var run: DayRun = DayRun.new([] as Array[PrizEvent])
	assert_true(run.is_finished())
	assert_eq(run.outcome(), &"")
	assert_eq(run.advance(1.0).size(), 0)
