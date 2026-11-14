extends TestCase
## Tahta kuralları: her ret kodu, tak/çıkar, sınırsız geri alma, vurgu sorguları, düz kip kazanma.

const F: GDScript = preload("res://tests/data/priz_fixtures.gd")

var content: PrizContent


func before_each() -> void:
	if content == null:
		content = PrizContent.load_default()


func _board(level: PrizLevel) -> PrizBoard:
	return PrizBoard.new(level, content.registry)


func test_registry_loads_nine_elements() -> void:
	assert_true(content.registry.errors.is_empty(), "öğe hatası: %s" % str(content.registry.errors))
	assert_eq(content.registry.elements.size(), 9)
	var expected: Dictionary = {"room_restriction": 6, "multi_socket": 10, "day_cycle": 15,
		"old_cable": 25, "grounded_socket": 35, "solar_panel": 50, "neighbour_line": 65,
		"timer_socket": 80, "line_off": 95}
	for element_id: String in expected.keys():
		var element: PrizElement = content.registry.get_element(element_id)
		assert_not_null(element, element_id)
		if element != null:
			assert_eq(element.unlock_level, int(expected[element_id]), element_id)
			assert_true(element.intro_art != "" and element.intro_title != "", element_id + " kart")


func test_reason_unknown() -> void:
	var board: PrizBoard = _board(F.flat_a())
	assert_eq(board.can_plug("yok", "s0"), PrizReason.UNKNOWN)
	assert_eq(board.can_plug("d0", "yok"), PrizReason.UNKNOWN)
	assert_eq(board.plug("yok", "s0"), PrizReason.UNKNOWN)


func test_reason_ok_and_wrong_room() -> void:
	var board: PrizBoard = _board(F.flat_a())
	assert_eq(board.can_plug("d0", "s0"), PrizReason.OK)
	assert_eq(board.can_plug("d0", "s1"), PrizReason.WRONG_ROOM)
	assert_eq(board.plug("d0", "s1"), PrizReason.WRONG_ROOM)
	assert_eq(board.socket_of("d0"), "", "reddedilen fiş oturmaz")


func test_reason_needs_ground() -> void:
	var board: PrizBoard = _board(F.flat_a())
	assert_eq(board.can_plug("d2", "s0"), PrizReason.NEEDS_GROUND)
	assert_eq(board.can_plug("d2", "s2"), PrizReason.OK)
	assert_eq(board.can_plug("d0", "s2"), PrizReason.OK, "topraklı priz her cihazı alır")


func test_reason_socket_full() -> void:
	var board: PrizBoard = _board(F.flat_a())
	assert_eq(board.plug("d2", "s2"), PrizReason.OK)
	assert_eq(board.can_plug("d0", "s2"), PrizReason.SOCKET_FULL)
	assert_eq(board.free_seats("s2"), 0)
	assert_eq(board.free_seats("s3"), 2)


func test_reason_would_overflow_flat() -> void:
	var board: PrizBoard = _board(F.flat_a())
	assert_eq(board.plug("d2", "s2"), PrizReason.OK)
	assert_eq(board.can_plug("d1", "s3"), PrizReason.WOULD_OVERFLOW, "2+2 > 3")
	assert_eq(board.plug("d1", "s3"), PrizReason.WOULD_OVERFLOW)
	assert_eq(board.line_load("L1", 0), 2, "taşan cihaz oturmadı")


func test_day_mode_allows_overflow_in_planning() -> void:
	var level: PrizLevel = F.flat_a()
	level.mode = PrizLevel.MODE_DAY
	level.fuse_rights = 3
	var board: PrizBoard = _board(level)
	board.plug("d2", "s2")
	assert_eq(board.can_plug("d1", "s3"), PrizReason.OK)
	board.plug("d1", "s3")
	assert_eq(board.line_load("L1", 0), 4)
	assert_greater(board.line_fill("L1", 0), 1.0, "taşma oranı 1'i aşar")
	assert_eq(board.overflows().size(), 4, "dört dilimde de taşıyor")


func test_reason_not_planning_after_win() -> void:
	var board: PrizBoard = _board(F.flat_a())
	assert_eq(board.plug("d0", "s0"), PrizReason.OK)
	assert_eq(board.plug("d2", "s2"), PrizReason.OK)
	assert_false(board.is_won())
	assert_eq(board.plug("d1", "s1"), PrizReason.OK)
	assert_true(board.is_won(), "düz kipte tüm cihazlar takılınca kazanılır")
	assert_eq(board.can_plug("d1", "s3"), PrizReason.NOT_PLANNING)
	assert_false(board.unplug("d1"))
	assert_true(board.start_day().is_empty(), "düz kipte gün başlatılmaz")


func test_plug_moves_and_unplug_unlimited_undo() -> void:
	var board: PrizBoard = _board(F.flat_a())
	for i: int in 50:
		assert_eq(board.plug("d0", "s0"), PrizReason.OK)
		assert_eq(board.line_load("L0", 1), 3)
		assert_eq(board.plug("d0", "s2"), PrizReason.OK, "takılı cihaz taşınır")
		assert_eq(board.line_load("L0", 1), 0)
		assert_eq(board.line_load("L1", 1), 3)
		assert_true(board.unplug("d0"))
		assert_eq(board.line_load("L1", 1), 0)
	assert_false(board.unplug("d0"), "takılı değil")
	assert_eq(board.plug("d0", "s0"), PrizReason.OK)
	assert_eq(board.can_plug("d0", "s0"), PrizReason.OK, "aynı prize yeniden takmak OK")
	board.clear()
	assert_eq(board.unplugged_devices().size(), 3)


func test_move_within_same_line_is_not_overflow() -> void:
	# L0 kapasite 5: d0 (3) s0'dan aynı hattaki başka prize taşınırken kendi yükü iki kez sayılmaz.
	var level: PrizLevel = F.flat_a()
	level.elements = []
	level.sockets.append(PrizSocket.from_dict(F.socket("s4", "L0", "living")))
	var board: PrizBoard = _board(level)
	board.plug("d0", "s0")
	board.plug("d1", "s1")
	assert_eq(board.line_load("L0", 0), 5)
	assert_eq(board.can_plug("d0", "s4"), PrizReason.OK)
	assert_eq(board.can_plug("d2", "s4"), PrizReason.WOULD_OVERFLOW)


func test_highlight_queries() -> void:
	var board: PrizBoard = _board(F.flat_a())
	var accepting: Array[String] = board.sockets_accepting("d2")
	assert_eq(accepting, ["s2"] as Array[String])
	var reasons: Dictionary = board.plug_reasons("d2")
	assert_eq(reasons["s1"], PrizReason.WRONG_ROOM)
	assert_eq(reasons["s0"], PrizReason.NEEDS_GROUND)
	assert_eq(board.line_sockets("L1"), ["s2", "s3"] as Array[String])
	board.plug("d0", "s0")
	assert_eq(board.line_devices("L0"), ["d0"] as Array[String])
	assert_eq(board.line_of_socket("s3"), "L1")
	assert_eq(board.line_of_device("d0"), "L0")
	assert_eq(board.devices_in("s0"), ["d0"] as Array[String])


func test_loads_are_blocks_and_fill_ratios() -> void:
	var board: PrizBoard = _board(F.flat_a())
	board.plug("d0", "s0")
	assert_eq(board.line_load("L0", 0), 3)
	assert_eq(board.line_capacity("L0", 0), 5)
	assert_almost_eq(board.line_fill("L0", 0), 0.6)
	assert_almost_eq(board.line_peak_fill("L0"), 0.6)
	assert_eq(board.line_load("L0", 9), 0, "geçersiz dilim")
	assert_true(board.is_device_active("d0", PrizSlice.NIGHT), "düz kipte cihaz hep çalışır")


func test_placement_save_restore() -> void:
	var board: PrizBoard = _board(F.flat_a())
	board.plug("d0", "s0")
	board.plug("d2", "s2")
	var plan: Dictionary = board.placement()
	var other: PrizBoard = _board(F.flat_a())
	var rejected: Array[String] = other.apply_placement(plan)
	assert_true(rejected.is_empty())
	assert_eq(other.placement(), plan)


func test_slice_helpers() -> void:
	assert_eq(PrizSlice.rotate(1, 1), 2)
	assert_eq(PrizSlice.rotate(8, 1), 1, "gece → sabah")
	assert_eq(PrizSlice.rotate(3, -1), 9)
	assert_eq(PrizSlice.mask_from_ids(["noon", "night"]), 10)
	assert_eq(PrizSlice.ids_from_mask(5), ["morning", "evening"] as Array[String])
	assert_eq(PrizSlice.from_id("bogus"), -1)
