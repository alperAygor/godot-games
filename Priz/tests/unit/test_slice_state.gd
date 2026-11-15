extends TestCase
## SliceState: tahtanın sahneye çevrilmesi (eşleme, önizleme, gerilim, parlaklık) saf ve doğru mu.

var content: PrizContent
var data: SliceData


func before_each() -> void:
	if content == null:
		content = PrizContent.load_default()
	if data == null:
		data = SliceData.load_default()


func _state(index: int) -> SliceState:
	return SliceState.new(data.load_level(index), content.registry, data)


func test_mapping_round_trip() -> void:
	var st: SliceState = _state(1)
	for socket: PrizSocket in st.level.sockets:
		var node_name: String = st.room_socket_of(socket.id)
		assert_true(node_name.begins_with("Socket_"), socket.id)
		assert_eq(st.level_socket_at(node_name), socket.id)
	assert_eq(st.level_socket_at("Socket_99"), "")
	assert_eq(st.room_lines(), [1, 2] as Array[int])
	assert_eq(st.room_line_of(st.level_line_at(2)), 2)


func test_preview_reports_ghost_blocks_and_fit() -> void:
	# Seviye 2: kırmızı ve mavi hat 3'er blok; tv 2, vantilatör 1, tost makinesi 2.
	var st: SliceState = _state(1)
	var tv: String = _device_of(st, "tv")
	var toaster: String = _device_of(st, "toaster")
	var p: Dictionary = st.preview(tv, "Socket_01")
	assert_eq(int(p["line"]), 1)
	assert_eq(int(p["before"]), 0)
	assert_eq(int(p["after"]), 2)
	assert_eq(int(p["capacity"]), 3)
	assert_true(bool(p["fits"]))
	assert_eq(st.plug_room(tv, "Socket_01"), PrizReason.OK)
	assert_almost_eq(st.fill(1), 2.0 / 3.0)
	var q: Dictionary = st.preview(toaster, "Socket_02")
	assert_eq(int(q["before"]), 2)
	assert_eq(int(q["after"]), 4)
	assert_false(bool(q["fits"]), "taşacak cihaz oturmaz")
	assert_eq(q["reason"], PrizReason.WOULD_OVERFLOW)
	assert_false(st.accepting_room_sockets(toaster).has("Socket_02"))
	assert_true(st.accepting_room_sockets(toaster).has("Socket_03"))
	# Taşıma önizlemesi kendini saymaz.
	var m: Dictionary = st.preview(tv, "Socket_02")
	assert_eq(int(m["before"]), 0, "aynı hatta taşımada cihaz iki kez sayılmaz")
	assert_eq(st.plugged_room_socket(tv), "Socket_01")
	assert_eq(st.device_at_room_socket("Socket_01"), tv)


func test_tension_glow_and_near_limit() -> void:
	var st: SliceState = _state(1)
	assert_almost_eq(st.tension(), 0.0)
	assert_almost_eq(st.glow_for(1), 0.0)
	st.plug_room(_device_of(st, "tv"), "Socket_01")
	st.plug_room(_device_of(st, "fan"), "Socket_02")
	assert_almost_eq(st.tension(), 1.0)
	assert_eq(st.near_limit_lines(), [1] as Array[int])
	assert_almost_eq(st.glow_for(1), 2.5)
	assert_almost_eq(st.glow_for(2), 0.0)


func test_win_comes_from_board() -> void:
	var st: SliceState = _state(0)
	var plan: Dictionary = PrizSolver.new().first_solution(st.level, content.registry)
	for device_id: Variant in plan.keys():
		assert_eq(st.board.plug(str(device_id), str(plan[device_id])), PrizReason.OK)
	assert_true(st.board.is_won())


func _device_of(st: SliceState, type: String) -> String:
	for device: PrizDevice in st.level.devices:
		if device.type == type:
			return device.id
	return ""
