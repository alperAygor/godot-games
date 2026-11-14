extends TestCase
## Gün benzetimi: olay sırası, sigorta hakları, ek hak, plan korunması.

const F: GDScript = preload("res://tests/data/priz_fixtures.gd")
const SAFE: Dictionary = {"d0": "s0", "d1": "s1", "d2": "s2"}
const BAD: Dictionary = {"d0": "s1", "d1": "s2", "d2": "s0"}

var content: PrizContent


func before_each() -> void:
	if content == null:
		content = PrizContent.load_default()


func _board() -> PrizBoard:
	return PrizBoard.new(F.day_b(), content.registry)


static func _compact(events: Array[PrizEvent]) -> Array[String]:
	var out: Array[String] = []
	for e: PrizEvent in events:
		var s: String = String(e.type)
		if e.slice >= 0:
			s += ":%d" % e.slice
		if e.device_id != "":
			s += ":" + e.device_id
		if e.line_id != "":
			s += ":%s=%d/%d" % [e.line_id, e.blocks, e.capacity]
		if e.rights >= 0:
			s += ":r%d" % e.rights
		out.append(s)
	return out


func test_start_requires_all_plugged() -> void:
	var board: PrizBoard = _board()
	assert_eq(board.fuse_rights(), 3)
	assert_false(board.can_start_day())
	assert_true(board.start_day().is_empty())
	board.plug("d0", "s0")
	board.plug("d1", "s1")
	assert_false(board.can_start_day())
	board.plug("d2", "s2")
	assert_true(board.can_start_day())


func test_event_order_survived_day() -> void:
	var board: PrizBoard = _board()
	F.plug_all(board, SAFE)
	var got: Array[String] = _compact(board.start_day())
	var expected: Array[String] = [
		"day_start",
		"slice_begin:0", "device_on:0:d0", "line_load:0:L0=2/3", "line_load:0:L1=0/2",
		"slice_begin:1", "device_on:1:d1", "line_load:1:L0=2/3", "line_load:1:L1=2/2",
		"line_near_limit:1:L1=2/2",
		"slice_begin:2", "device_off:2:d0", "device_off:2:d1", "device_on:2:d2",
		"line_load:2:L0=0/3", "line_load:2:L1=1/2",
		"slice_begin:3", "line_load:3:L0=0/3", "line_load:3:L1=1/2",
		"day_survived", "win",
	]
	assert_eq(got, expected)
	assert_true(board.is_won())
	assert_eq(board.fuse_rights(), 3, "kazanınca hak gitmez")
	assert_eq(board.can_plug("d0", "s1"), PrizReason.NOT_PLANNING)


func test_fill_payload() -> void:
	var board: PrizBoard = _board()
	F.plug_all(board, SAFE)
	for e: PrizEvent in board.start_day():
		if e.type == PrizEvent.LINE_LOAD and e.line_id == "L0" and e.slice == 0:
			assert_almost_eq(e.fill, 2.0 / 3.0)
		if e.type == PrizEvent.LINE_NEAR_LIMIT:
			assert_almost_eq(e.fill, 1.0)


func test_fuse_blows_costs_right_and_keeps_plan() -> void:
	var board: PrizBoard = _board()
	F.plug_all(board, BAD)
	var plan: Dictionary = board.placement()
	var got: Array[String] = _compact(board.start_day())
	var tail: Array[String] = got.slice(got.size() - 2)
	assert_eq(tail, ["fuse_blown:1:L1=4/2:r2", "back_to_planning:1:r2"] as Array[String])
	assert_false(got.has("slice_begin:2"), "ilk taşan dilimde durur")
	assert_eq(board.fuse_rights(), 2)
	assert_true(board.is_planning())
	assert_eq(board.placement(), plan, "plan silinmez")
	assert_eq(board.days_run(), 1)


func test_three_blows_lose_then_extra_right() -> void:
	var board: PrizBoard = _board()
	F.plug_all(board, BAD)
	board.start_day()
	board.start_day()
	var last: Array[PrizEvent] = board.start_day()
	assert_eq(last[last.size() - 1].type, PrizEvent.LOSE)
	assert_eq(last[last.size() - 2].type, PrizEvent.FUSE_BLOWN)
	assert_eq(last[last.size() - 2].rights, 0)
	assert_true(board.is_lost())
	assert_eq(board.fuse_rights(), 0)
	assert_eq(board.can_plug("d0", "s0"), PrizReason.NOT_PLANNING)
	assert_true(board.start_day().is_empty())
	# Ödüllü reklam: +1 hak, plana dönüş, plan korunmuş.
	board.grant_extra_right()
	assert_true(board.is_planning())
	assert_eq(board.fuse_rights(), 1)
	assert_eq(board.placement(), BAD)
	board.clear()
	F.plug_all(board, SAFE)
	var win: Array[PrizEvent] = board.start_day()
	assert_eq(win[win.size() - 1].type, PrizEvent.WIN)


func test_extra_right_during_planning_adds() -> void:
	var board: PrizBoard = _board()
	board.grant_extra_right()
	assert_eq(board.fuse_rights(), 4)


func test_two_lines_blow_same_slice_one_right() -> void:
	var level: PrizLevel = F.level("day", ["day_cycle"], ["living"],
		[F.line("L0", 1), F.line("L1", 1)],
		[F.socket("s0", "L0", "living"), F.socket("s1", "L1", "living")],
		[F.device("d0", 2, "living", ["morning"]), F.device("d1", 2, "living", ["morning"])])
	var board: PrizBoard = PrizBoard.new(level, content.registry)
	board.plug("d0", "s0")
	board.plug("d1", "s1")
	var blown: int = 0
	for e: PrizEvent in board.start_day():
		if e.type == PrizEvent.FUSE_BLOWN:
			blown += 1
			assert_eq(e.rights, 2)
	assert_eq(blown, 2, "taşan her hat için bir olay")
	assert_eq(board.fuse_rights(), 2, "tek hak düşer")


func test_flat_mode_has_no_rights() -> void:
	var board: PrizBoard = PrizBoard.new(F.flat_a(), content.registry)
	assert_eq(board.fuse_rights(), 0)
	assert_false(board.is_day_mode())
	board.grant_extra_right()
	assert_eq(board.fuse_rights(), 0)
