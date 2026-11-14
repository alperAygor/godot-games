extends TestCase
## Dokuz içerik öğesinin kuralları, açılış seviyelerinde üretici + çözücü, ve genişletilebilirlik:
## çekirdeğe dokunmadan veri dosyasıyla eklenen onuncu (yalnız test) öğe.

const F: GDScript = preload("res://tests/data/priz_fixtures.gd")

var content: PrizContent


func before_each() -> void:
	if content == null:
		content = PrizContent.load_default()


func _board(level: PrizLevel) -> PrizBoard:
	return PrizBoard.new(level, content.registry)


func _intro_level(n: int, element_id: String) -> PrizLevel:
	var level: PrizLevel = PrizGenerator.new(content).generate(n)
	assert_not_null(level, "seviye %d üretilemedi" % n)
	if level == null:
		return PrizLevel.new()
	assert_true(level.elements.has(element_id), "%d: %s yok" % [n, element_id])
	var res: PrizSolveResult = PrizSolver.new().count_solutions(level, content.registry, level.band_max + 1)
	assert_true(res.count >= level.band_min and res.count <= level.band_max,
			"%d: çözüm %d aralık dışında" % [n, res.count])
	assert_false(res.node_limit_hit)
	return level


static func _lines_with(level: PrizLevel, prop: String) -> int:
	var n: int = 0
	for line: PrizLine in level.lines:
		if line.props.has(prop):
			n += 1
	return n


static func _sockets_with(level: PrizLevel, prop: String) -> int:
	var n: int = 0
	for socket: PrizSocket in level.sockets:
		if socket.props.has(prop):
			n += 1
	return n


# --- 1. oda kısıtı (6) ---

func test_room_restriction() -> void:
	var board: PrizBoard = _board(F.flat_a())
	assert_eq(board.can_plug("d1", "s0"), PrizReason.WRONG_ROOM)
	var free: PrizLevel = F.flat_a()
	free.elements = ["grounded_socket"]
	assert_eq(_board(free).can_plug("d1", "s0"), PrizReason.OK, "öğe yoksa kısıt yok")
	var level: PrizLevel = _intro_level(6, "room_restriction")
	assert_true(level.rooms.size() >= 2)
	assert_false(PrizGenerator.new(content).generate(5).elements.has("room_restriction"))


# --- 2. çoklu priz (10) ---

func test_multi_socket() -> void:
	var level: PrizLevel = F.level("flat", ["multi_socket"], ["living"], [F.line("L0", 9)],
		[F.socket("s0", "L0", "living", 2)],
		[F.device("d0", 1, "living"), F.device("d1", 2, "living"), F.device("d2", 1, "living")])
	var board: PrizBoard = _board(level)
	assert_eq(board.plug("d0", "s0"), PrizReason.OK)
	assert_eq(board.plug("d1", "s0"), PrizReason.OK)
	assert_eq(board.line_load("L0", 0), 3, "hepsi aynı hatta")
	assert_eq(board.can_plug("d2", "s0"), PrizReason.SOCKET_FULL)
	var intro: PrizLevel = _intro_level(10, "multi_socket")
	var strips: int = 0
	for socket: PrizSocket in intro.sockets:
		if socket.seats > 1:
			strips += 1
	assert_true(strips >= 1, "en az bir uzatma")


# --- 3. gün döngüsü (15) ---

func test_day_cycle() -> void:
	var gen: PrizGenerator = PrizGenerator.new(content)
	var flat: PrizLevel = gen.generate(14)
	assert_eq(flat.mode, PrizLevel.MODE_FLAT)
	assert_eq(flat.fuse_rights, 0)
	var level: PrizLevel = _intro_level(15, "day_cycle")
	assert_eq(level.mode, PrizLevel.MODE_DAY)
	assert_eq(level.fuse_rights, 3)
	var partial: int = 0
	for device: PrizDevice in level.devices:
		if device.slices != PrizSlice.ALL_MASK:
			partial += 1
	assert_true(partial > 0, "cihazlar dilimlere dağılır")
	var intro_ids: Array[String] = []
	for element: PrizElement in content.registry.introduced_at(15):
		intro_ids.append(element.id)
	assert_eq(intro_ids, ["day_cycle"] as Array[String])


# --- 4. eski kablo (25) ---

func test_old_cable() -> void:
	var level: PrizLevel = F.level("day", ["day_cycle", "old_cable"], ["living"],
		[F.line("L0", 5, {"old_cable": 2})], [F.socket("s0", "L0", "living")],
		[F.device("d0", 3, "living", ["noon"])])
	var board: PrizBoard = _board(level)
	for s: int in PrizSlice.COUNT:
		assert_eq(board.line_capacity("L0", s), 3)
	assert_eq(board.line_base_capacity("L0"), 5)
	board.plug("d0", "s0")
	assert_eq(board.start_day().back().type, PrizEvent.WIN, "3/3 sığar")
	var intro: PrizLevel = _intro_level(25, "old_cable")
	assert_eq(_lines_with(intro, "old_cable"), 1)


# --- 5. topraklı priz (35) ---

func test_grounded_socket() -> void:
	var board: PrizBoard = _board(F.flat_a())
	assert_eq(board.can_plug("d2", "s0"), PrizReason.NEEDS_GROUND)
	assert_eq(board.can_plug("d2", "s2"), PrizReason.OK)
	var intro: PrizLevel = _intro_level(35, "grounded_socket")
	assert_true(_sockets_with(intro, "grounded") >= 1)
	var needy: int = 0
	for device: PrizDevice in intro.devices:
		if bool(device.get_prop("needs_ground", false)):
			needy += 1
	assert_eq(needy, 1, "tanıtımda tek cihaz")


# --- 6. güneş paneli (50) ---

func test_solar_panel() -> void:
	var level: PrizLevel = F.level("day", ["day_cycle", "solar_panel"], ["living"],
		[F.line("L0", 3, {"solar": 2})], [F.socket("s0", "L0", "living")],
		[F.device("d0", 5, "living", ["noon"])])
	var board: PrizBoard = _board(level)
	assert_eq(board.line_capacity("L0", PrizSlice.MORNING), 3)
	assert_eq(board.line_capacity("L0", PrizSlice.NOON), 5)
	board.plug("d0", "s0")
	assert_eq(board.start_day().back().type, PrizEvent.WIN, "öğlen 5 blok sığar")
	var intro: PrizLevel = _intro_level(50, "solar_panel")
	assert_eq(_lines_with(intro, "solar"), 1)


# --- 7. komşu hattı (65) ---

func test_neighbour_line() -> void:
	var level: PrizLevel = F.level("day", ["day_cycle", "neighbour_line"], ["living"],
		[F.line("L0", 3, {"neighbour": [0, 2, 1, 0]})], [F.socket("s0", "L0", "living")],
		[F.device("d0", 2, "living", ["noon"])])
	var board: PrizBoard = _board(level)
	assert_eq(board.line_load("L0", PrizSlice.NOON), 2, "boşken de komşu yükü")
	assert_eq(board.line_external_load("L0", PrizSlice.EVENING), 1)
	board.plug("d0", "s0")
	assert_eq(board.line_device_load("L0", PrizSlice.NOON), 2)
	assert_eq(board.line_load("L0", PrizSlice.NOON), 4)
	var events: Array[PrizEvent] = board.start_day()
	assert_eq(events.back().type, PrizEvent.BACK_TO_PLANNING, "öğlen 4 > 3")
	assert_eq(PrizSolver.new().count_solutions(level, content.registry).count, 0)
	var intro: PrizLevel = _intro_level(65, "neighbour_line")
	assert_eq(_lines_with(intro, "neighbour"), 1)


# --- 8. zamanlayıcılı priz (80) ---

func test_timer_socket() -> void:
	var level: PrizLevel = F.level("day", ["day_cycle", "timer_socket"], ["living"],
		[F.line("L0", 2)],
		[F.socket("s0", "L0", "living", 1, {"timer": 1}), F.socket("s1", "L0", "living")],
		[F.device("d0", 2, "living", ["morning"]), F.device("d1", 1, "living", ["morning"])])
	var board: PrizBoard = _board(level)
	assert_eq(board.device_slices_at("d0", "s0"), 1 << PrizSlice.NOON)
	board.plug("d0", "s0")
	assert_false(board.is_device_active("d0", PrizSlice.MORNING))
	assert_true(board.is_device_active("d0", PrizSlice.NOON))
	assert_eq(board.line_load("L0", PrizSlice.NOON), 2)
	assert_eq(board.line_load("L0", PrizSlice.MORNING), 0)
	board.plug("d1", "s1")
	assert_eq(board.start_day().back().type, PrizEvent.WIN)
	# Zamanlayıcı olmasa sabah 3 > 2 taşardı; hangisi zamanlayıcıda olursa olsun sığar: 2 çözüm.
	assert_eq(PrizSolver.new().count_solutions(level, content.registry).count, 2)
	var plain: PrizLevel = level.copy()
	plain.sockets[0].props = {}
	assert_eq(PrizSolver.new().count_solutions(plain, content.registry).count, 0)
	var intro: PrizLevel = _intro_level(80, "timer_socket")
	assert_true(_sockets_with(intro, "timer") >= 1)


# --- 9. kapalı hat (95) ---

func test_line_off() -> void:
	var level: PrizLevel = F.level("day", ["day_cycle", "line_off"], ["living"],
		[F.line("L0", 4, {"off_slice": "night"}), F.line("L1", 4)],
		[F.socket("s0", "L0", "living"), F.socket("s1", "L1", "living")],
		[F.device("d0", 1, "living", ["night"]), F.device("d1", 3, "living", ["morning"])])
	var board: PrizBoard = _board(level)
	assert_eq(board.line_capacity("L0", PrizSlice.NIGHT), 0)
	assert_eq(board.line_capacity("L0", PrizSlice.EVENING), 4)
	board.plug("d0", "s0")
	board.plug("d1", "s1")
	var events: Array[PrizEvent] = board.start_day()
	var blown: PrizEvent = null
	for e: PrizEvent in events:
		if e.type == PrizEvent.FUSE_BLOWN:
			blown = e
	assert_not_null(blown)
	if blown != null:
		assert_eq(blown.slice, PrizSlice.NIGHT)
		assert_eq(blown.line_id, "L0")
	var res: PrizSolveResult = PrizSolver.new().count_solutions(level, content.registry)
	assert_eq(res.count, 1, "yalnız d0→L1, d1→L0")
	var intro: PrizLevel = _intro_level(95, "line_off")
	assert_eq(_lines_with(intro, "off_slice"), 1)


# --- genişletilebilirlik ---

func _extended_content() -> PrizContent:
	var registry: PrizElementRegistry = PrizElementRegistry.create_default()
	assert_true(registry.add_file("res://tests/data/elements/test_surge.json"), str(registry.errors))
	assert_true(registry.add_file("res://tests/data/elements/test_usb_port.json"), str(registry.errors))
	assert_true(registry.errors.is_empty(), str(registry.errors))
	return PrizContent.create(registry, PrizCatalog.create_default())


## Yeni kural türü (testteki küçük betik) + veri dosyası: gece ek yük bindiren "dalgalanma".
func test_tenth_element_with_new_rule_script() -> void:
	var ext: PrizContent = _extended_content()
	assert_eq(ext.registry.elements.size(), 11)
	var element: PrizElement = ext.registry.get_element("test_surge")
	assert_not_null(element)
	var level: PrizLevel = F.level("day", ["day_cycle", "test_surge"], ["living"],
		[F.line("L0", 3)], [F.socket("s0", "L0", "living")],
		[F.device("d0", 2, "living", ["evening", "night"], {"surge": true})])
	var board: PrizBoard = PrizBoard.new(level, ext.registry)
	board.plug("d0", "s0")
	assert_eq(board.line_load("L0", PrizSlice.EVENING), 2)
	assert_eq(board.line_load("L0", PrizSlice.NIGHT), 3, "gece +1 blok")
	# Üretici öğeyi açılış seviyesinde (101) kendiliğinden tanıtır; çözücü doğrular.
	var gen: PrizGenerator = PrizGenerator.new(ext)
	var generated: PrizLevel = gen.generate(101)
	assert_not_null(generated)
	if generated != null:
		assert_true(generated.elements.has("test_surge"))
		var marked: int = 0
		for device: PrizDevice in generated.devices:
			if bool(device.get_prop("surge", false)):
				marked += 1
		assert_true(marked >= 1)
		var res: PrizSolveResult = PrizSolver.new().count_solutions(generated, ext.registry,
				generated.band_max + 1)
		assert_true(res.count >= generated.band_min and res.count <= generated.band_max)
		assert_true(PrizLevel.from_json(generated.to_json()).to_json() == generated.to_json())


## Yalnız veri dosyası (var olan kural türü, yeni ret kodu): USB isteyen cihaz.
func test_data_only_element_with_custom_reason() -> void:
	var ext: PrizContent = _extended_content()
	var level: PrizLevel = F.level("flat", ["test_usb_port"], ["living"],
		[F.line("L0", 5)],
		[F.socket("s0", "L0", "living"), F.socket("s1", "L0", "living", 1, {"usb": true})],
		[F.device("d0", 1, "living", [], {"needs_usb": true})])
	var board: PrizBoard = PrizBoard.new(level, ext.registry)
	assert_eq(board.can_plug("d0", "s0"), &"needs_usb")
	assert_eq(board.can_plug("d0", "s1"), PrizReason.OK)
	var generated: PrizLevel = PrizGenerator.new(ext).generate(102)
	assert_not_null(generated)
	if generated != null:
		assert_true(generated.elements.has("test_usb_port"))
		assert_true(_sockets_with(generated, "usb") >= 1)
		assert_true(PrizSolver.new().is_solvable(generated, ext.registry))


func test_default_registry_unaffected_by_test_elements() -> void:
	assert_eq(content.registry.get_element("test_surge"), null)
	assert_eq(PrizElementRegistry.create_default().elements.size(), 9)
