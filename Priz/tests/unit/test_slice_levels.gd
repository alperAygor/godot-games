extends TestCase
## Dikey kesit seviye seti kabul kapısı: her dosya yüklenir, geçerlidir, ÇÖZÜLEBİLİR (çözücü),
## yalnız modellenmiş sekiz cihaz türünü kullanır, aynı cihaz iki kez yoktur, tek odadadır,
## priz yerleri odadaki gerçek `Socket_0N` düğümlerine ve doğru kablo hattına eşlenir.

const ROOM_SCENE: String = "res://assets/models/room/room_studio.glb"
const MIN_LEVELS: int = 13
const MAX_LEVELS: int = 16
## Aşama 3: ilk yedi kesit seviyesi düz kip, sonrası gün kipi (öğretim sırası).
const FLAT_COUNT: int = 7
const CATALOG_PATH: String = "res://data/balance/devices.json"

var content: PrizContent
var data: SliceData


func before_each() -> void:
	if content == null:
		content = PrizContent.load_default()
	if data == null:
		data = SliceData.load_default()


func test_level_count_in_range() -> void:
	assert_true(data.level_count() >= MIN_LEVELS and data.level_count() <= MAX_LEVELS,
		"kesit %d-%d seviye olmalı (%d)" % [MIN_LEVELS, MAX_LEVELS, data.level_count()])


func test_every_slice_level_is_valid_and_solvable() -> void:
	var solver: PrizSolver = PrizSolver.new()
	for i: int in data.level_count():
		var path: String = data.level_path(i)
		var level: PrizLevel = data.load_level(i)
		assert_not_null(level, "yüklenemedi: %s" % path)
		if level == null:
			continue
		var errors: PackedStringArray = level.validate(content.registry)
		assert_true(errors.is_empty(), "%s: %s" % [path, str(errors)])
		var res: PrizSolveResult = solver.count_solutions(level, content.registry, 1000)
		assert_false(res.node_limit_hit, "%s: düğüm sınırı" % path)
		assert_true(res.count > 0, "ÇÖZÜLEMEZ: %s" % path)
		# İlk çözüm gerçekten tahtada oynanabiliyor ve kazandırıyor.
		var board: PrizBoard = PrizBoard.new(level, content.registry)
		var plan: Dictionary = solver.first_solution(level, content.registry)
		assert_eq(plan.size(), level.devices.size(), "%s: çözüm tüm cihazları kapsamalı" % path)
		assert_true(board.apply_placement(plan).is_empty(), "%s: ilk çözüm uygulanabilmeli" % path)
		if level.is_day_mode():
			assert_true(board.can_start_day(), "%s: tüm cihazlar takılı, gün başlatılabilir" % path)
			var events: Array[PrizEvent] = board.start_day()
			assert_eq(events[events.size() - 1].type, PrizEvent.WIN, "%s: temiz gün kazandırmalı" % path)
		assert_true(board.is_won(), "%s: ilk çözüm kazandırmalı" % path)


func test_flat_mode_single_room_two_or_three_lines() -> void:
	for i: int in data.level_count():
		var level: PrizLevel = data.load_level(i)
		var path: String = data.level_path(i)
		if i < FLAT_COUNT:
			assert_eq(level.mode, PrizLevel.MODE_FLAT, path)
			assert_eq(level.fuse_rights, 0, path)
			assert_true(level.elements.is_empty(), "%s: düz kipte öğe yok" % path)
		else:
			assert_eq(level.mode, PrizLevel.MODE_DAY, path)
			assert_eq(level.fuse_rights, 3, "%s: üç sigorta hakkı" % path)
			assert_eq(level.elements, ["day_cycle"] as Array[String], path)
			assert_eq(data.level_time(i), PrizSlice.MORNING, "%s: gün seviyesi sabah planlanır" % path)
			for line: PrizLine in level.lines:
				assert_true(line.capacity >= 1 and line.capacity <= 6, "%s: gösterge yuvası (kapasite ≤ 6)" % path)
		assert_eq(level.rooms, [data.room_id] as Array[String], path)
		assert_true(level.lines.size() >= 2 and level.lines.size() <= 3, "%s: 2-3 hat" % path)
		assert_true(level.devices.size() >= 2 and level.devices.size() <= 6, "%s: tepsi en çok 6 cihaz" % path)


func test_only_modelled_types_and_no_duplicates() -> void:
	for i: int in data.level_count():
		var level: PrizLevel = data.load_level(i)
		var seen: Dictionary = {}
		for device: PrizDevice in level.devices:
			assert_true(data.has_appliance(device.type), "%s: modelsiz tür %s" % [data.level_path(i), device.type])
			assert_false(seen.has(device.type), "%s: aynı cihaz iki kez %s" % [data.level_path(i), device.type])
			seen[device.type] = true


func test_anchors_map_to_real_sockets_on_matching_lines() -> void:
	var room_sockets: Dictionary = _room_socket_nodes()
	assert_eq(room_sockets.size(), 7, "odada yedi priz düğümü olmalı")
	for node_name: String in data.room_socket_names():
		assert_true(room_sockets.has(node_name), "oda tablosundaki priz odada yok: %s" % node_name)
		assert_eq(data.room_line_of_socket(node_name), int(RoomView.SOCKET_LINES.get(node_name, -1)),
			"oda tablosu RoomView ile aynı hattı vermeli: %s" % node_name)
	for i: int in data.level_count():
		var level: PrizLevel = data.load_level(i)
		var path: String = data.level_path(i)
		var used_nodes: Dictionary = {}
		var used_room_lines: Dictionary = {}
		for line: PrizLine in level.lines:
			var room_line: int = data.room_line_of_color(line.color)
			assert_true(room_line > 0, "%s: hat rengi odada yok %s" % [path, line.color])
			assert_false(used_room_lines.has(room_line), "%s: iki hat aynı oda hattında" % path)
			used_room_lines[room_line] = true
		# Sigorta kutusu modülleri 1..n sırayla görünür: hatlar 1..n olmalı (boşluksuz).
		for k: int in range(1, level.lines.size() + 1):
			assert_true(used_room_lines.has(k), "%s: oda hatları 1..%d sırasıyla kullanılmalı" % [path, level.lines.size()])
		for socket: PrizSocket in level.sockets:
			var node_name: String = data.room_socket(socket.anchor)
			assert_true(room_sockets.has(node_name), "%s: %s düğüme eşlenmiyor" % [path, socket.anchor])
			assert_false(used_nodes.has(node_name), "%s: iki priz aynı düğümde" % path)
			used_nodes[node_name] = true
			var line: PrizLine = level.find_line(socket.line)
			assert_eq(data.room_line_of_socket(node_name), data.room_line_of_color(line.color),
				"%s: %s odada başka hatta" % [path, socket.id])


## Gün seviyeleri cihaz dilimlerini katalogdaki desenlerden alır (tür başına izinli seçenekler).
func test_day_levels_use_catalog_slice_patterns() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	var options: Dictionary = {}
	for entry: Variant in (parsed as Dictionary).get("devices", []) as Array:
		var e: Dictionary = entry as Dictionary
		var masks: Array[int] = []
		for pattern: Variant in e.get("slices", []) as Array:
			var ids: Array[String] = []
			for id: Variant in pattern as Array:
				ids.append(str(id))
			masks.append(PrizSlice.mask_from_ids(ids))
		options[str(e.get("type", ""))] = masks
	for i: int in range(FLAT_COUNT, data.level_count()):
		var level: PrizLevel = data.load_level(i)
		for device: PrizDevice in level.devices:
			var allowed: Array[int] = options.get(device.type, [] as Array[int]) as Array[int]
			assert_true(allowed.has(device.slices), "%s: %s dilimleri katalogda yok" % [data.level_path(i), device.type])


## Öğretim sırası: (1) yalnız BİR cihazın günü kısmi, (2) iki cihaz düz kipte sığmaz ama farklı saatlerde
## çalıştıkları için aynı hatta sığar ("zaman ek kapasitedir"), (3) gerçek bir gün.
func test_day_teaching_sequence() -> void:
	var solver: PrizSolver = PrizSolver.new()
	var first: PrizLevel = data.load_level(FLAT_COUNT)
	var partial: int = 0
	for device: PrizDevice in first.devices:
		if device.slices != PrizSlice.ALL_MASK:
			partial += 1
	assert_eq(partial, 1, "ilk gün seviyesinde tek kısmi cihaz")
	assert_eq(data.level_tutorial(FLAT_COUNT), "lever", "ilk gün seviyesinde şalter öğretimi")
	var aha: PrizLevel = data.load_level(FLAT_COUNT + 1)
	var flat: PrizLevel = aha.copy()
	flat.mode = PrizLevel.MODE_FLAT
	assert_false(solver.is_solvable(flat, content.registry), "ikinci gün seviyesi zamansız çözülemez")
	assert_true(solver.is_solvable(aha, content.registry), "zamanla çözülür")
	var shared: bool = false
	var plan: Dictionary = solver.first_solution(aha, content.registry)
	var board: PrizBoard = PrizBoard.new(aha, content.registry)
	board.apply_placement(plan)
	for line: PrizLine in aha.lines:
		var devs: Array[String] = board.line_devices(line.id)
		var sum: int = 0
		for d: String in devs:
			sum += aha.find_device(d).blocks
		if devs.size() >= 2 and sum > line.capacity:
			shared = true
	assert_true(shared, "çözümde iki cihaz toplamı hattı aşar ama farklı saatlerde çalışır")
	var real: PrizLevel = data.load_level(FLAT_COUNT + 2)
	assert_true(real.devices.size() >= 4, "üçüncü gün seviyesi gerçek bir gün")


func test_appliance_table_points_to_existing_assets() -> void:
	var anchors: Dictionary = _room_anchor_nodes()
	assert_eq(data.appliance_types().size(), 8, "sekiz modellenmiş cihaz")
	for type: String in data.appliance_types():
		var spec: Dictionary = data.appliance(type)
		assert_true(ResourceLoader.exists(str(spec.get("fx", ""))), "%s: Fx betiği yok" % type)
		assert_true(anchors.has(str(spec.get("anchor", ""))), "%s: oda yeri yok" % type)
		assert_true(str(spec.get("loop", "")).begins_with("loop_"), "%s: döngü sesi" % type)
		assert_greater(float(spec.get("tray_fit", 0.0)), 0.0, "%s: tepsi ölçeği" % type)


func test_first_levels_are_gentle_and_times_cover_three_daylight_slices() -> void:
	var solver: PrizSolver = PrizSolver.new()
	var times: Dictionary = {}
	for i: int in data.level_count():
		times[data.level_time(i)] = true
		assert_true(data.level_time(i) != PrizSlice.NIGHT, "kazanma gecesi için seviye gündüz başlar")
	assert_true(times.has(PrizSlice.MORNING) and times.has(PrizSlice.NOON) and times.has(PrizSlice.EVENING),
		"sabah, öğle ve akşam görülmeli")
	assert_eq(data.level_tutorial(0), "drag", "ilk seviyede hayalet el")
	# 1-3: yazısız geçilebilir, çok çözümlü ve az cihazlı.
	for i: int in range(3):
		var level: PrizLevel = data.load_level(i)
		assert_true(level.devices.size() <= 3, "seviye %d en çok üç cihaz" % (i + 1))
		var res: PrizSolveResult = solver.count_solutions(level, content.registry, 1000)
		assert_true(res.count >= 2 or i == 0, "seviye %d birden çok çözümlü olmalı" % (i + 1))
	assert_eq(data.index_for_progress(1), 0)
	assert_eq(data.index_for_progress(data.level_count() + 1), 0, "kesit bitince başa sarar")


func _room_socket_nodes() -> Dictionary:
	var result: Dictionary = {}
	var root: Node = (load(ROOM_SCENE) as PackedScene).instantiate()
	_collect(root, "Socket_", result)
	root.free()
	return result


func _room_anchor_nodes() -> Dictionary:
	var result: Dictionary = {}
	var root: Node = (load(ROOM_SCENE) as PackedScene).instantiate()
	_collect(root, "Anchor_", result)
	root.free()
	return result


func _collect(node: Node, prefix: String, into: Dictionary) -> void:
	if String(node.name).begins_with(prefix):
		into[String(node.name)] = true
	for child: Node in node.get_children():
		_collect(child, prefix, into)
