extends TestCase

## SnapRule: en yakin BOS priz, kendi rengi -> SNAP, farkli renk -> WRONG_COLOR,
## yaricap disi -> NONE. z (kameraya kalkma) snap'i etkilemez.

var _sockets: Array[SocketSpec] = []
var _cables: Array[CableSpec] = []


func before_each() -> void:
	_sockets = []
	_cables = []
	_add_socket(0, &"red", Vector3(-0.3, -1.2, 0.055))
	_add_socket(1, &"blue", Vector3(0.0, -1.2, 0.055))
	_add_socket(2, &"yellow", Vector3(0.3, -1.2, 0.055))
	_add_cable(0, &"red")
	_add_cable(1, &"blue")


func _add_socket(index: int, color_id: StringName, position: Vector3) -> void:
	var socket: SocketSpec = SocketSpec.new()
	socket.index = index
	socket.color_id = color_id
	socket.position = position
	_sockets.append(socket)


func _add_cable(index: int, color_id: StringName) -> void:
	var cable: CableSpec = CableSpec.new()
	cable.index = index
	cable.color_id = color_id
	_cables.append(cable)


func _all_free() -> Array[int]:
	return [0, 1, 2]


func test_nearest_socket_picks_closest_free() -> void:
	var nearest: int = SnapRule.nearest_socket(
		Vector3(-0.28, -1.2, 0.4), _sockets, _all_free(), 0.2)
	assert_eq(nearest, 0, "en yakin bos priz")


func test_nearest_socket_skips_occupied() -> void:
	var free: Array[int] = [1, 2]
	var nearest: int = SnapRule.nearest_socket(
		Vector3(-0.05, -1.2, 0.0), _sockets, free, 0.2)
	assert_eq(nearest, 1, "dolu priz atlanir")


func test_nearest_socket_outside_radius_returns_none() -> void:
	var nearest: int = SnapRule.nearest_socket(
		Vector3(-0.3, -0.4, 0.0), _sockets, _all_free(), 0.2)
	assert_eq(nearest, -1)


func test_evaluate_snap_on_own_color() -> void:
	var result: Dictionary = SnapRule.evaluate(
		Vector3(-0.3, -1.2, 0.3), _sockets, _all_free(), 0, _cables, 0.2)
	assert_eq(int(result["result"]), int(SnapRule.Result.SNAP))
	assert_eq(int(result["socket_index"]), 0)
	assert_almost_eq(float(result["distance"]), 0.0, 0.0001)


func test_evaluate_wrong_color() -> void:
	var result: Dictionary = SnapRule.evaluate(
		Vector3(0.0, -1.2, 0.0), _sockets, _all_free(), 0, _cables, 0.2)
	assert_eq(int(result["result"]), int(SnapRule.Result.WRONG_COLOR))
	assert_eq(int(result["socket_index"]), 1)


func test_nearest_wins_even_if_own_socket_in_radius() -> void:
	# Fis (-0.13) konumunda: socket1 (mavi) 0.13, kendi socket0 (kirmizi) 0.17 uzak.
	var result: Dictionary = SnapRule.evaluate(
		Vector3(-0.13, -1.2, 0.05), _sockets, _all_free(), 0, _cables, 0.2)
	assert_eq(int(result["result"]), int(SnapRule.Result.WRONG_COLOR),
		"en yakin priz farkli renkse yanlis priz")
	assert_eq(int(result["socket_index"]), 1)


func test_socket_distance_ignores_camera_lift() -> void:
	var lifted: Dictionary = SnapRule.evaluate(
		Vector3(-0.3, -1.2, 0.5), _sockets, _all_free(), 0, _cables, 0.2)
	assert_eq(int(lifted["result"]), int(SnapRule.Result.SNAP), "z mesafeye girmez")
	assert_almost_eq(float(lifted["distance"]), 0.0, 0.0001)


func test_evaluate_none_when_no_socket_in_radius() -> void:
	var result: Dictionary = SnapRule.evaluate(
		Vector3(0.0, 0.5, 0.0), _sockets, _all_free(), 0, _cables, 0.2)
	assert_eq(int(result["result"]), int(SnapRule.Result.NONE))
	assert_eq(int(result["socket_index"]), -1)


func test_evaluate_none_when_no_free_socket() -> void:
	var free: Array[int] = []
	var result: Dictionary = SnapRule.evaluate(
		Vector3(0.0, -1.2, 0.0), _sockets, free, 0, _cables, 0.2)
	assert_eq(int(result["result"]), int(SnapRule.Result.NONE))


func test_evaluate_invalid_cable_index_is_none() -> void:
	var result: Dictionary = SnapRule.evaluate(
		Vector3(0.0, -1.2, 0.0), _sockets, _all_free(), 5, _cables, 0.2)
	assert_eq(int(result["result"]), int(SnapRule.Result.NONE))


func test_evaluate_invalid_free_index_is_ignored() -> void:
	var free: Array[int] = [-1, 99]
	var result: Dictionary = SnapRule.evaluate(
		Vector3(0.0, -1.2, 0.0), _sockets, free, 1, _cables, 0.2)
	assert_eq(int(result["result"]), int(SnapRule.Result.NONE))
