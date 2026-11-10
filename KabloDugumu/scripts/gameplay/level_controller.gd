class_name LevelController
extends RefCounted

## Bir bölümün dünya tarafı: CableNode/SocketNode kurulumu, sürükle-bırak,
## snap kuralı, ödüller, QA kancaları, temas/aşırı yük koordinasyonu.
## Temas mantığı ContactMonitor'da, oturum/UI game.gd'de; burada HUD yok.

signal snap_done(cable_index: int, socket_index: int)
signal wrong_socket_try(cable_index: int, socket_index: int)
signal short_circuit(point: Vector3, color: Color)
signal connections_changed(done: int, total: int)
signal fuse_blown()
signal level_completed()

var knot: KnotLevel = null
var cables: Array[CableNode] = []
var sockets: Array[SocketNode] = []
var free_sockets: Array[int] = []
var connected: int = 0
var blown: bool = false
var dragging_index: int = -1
var monitor: ContactMonitor = ContactMonitor.new()
var overload: OverloadModel = null

## Bölümdeki kısa devre sayısı (skor için; revive sıfırlamaz).
var shorts: int:
	get:
		return monitor.shorts

var _sparks: SparkBurst = null
var _camera: CameraRig = null
var _snap_radius: float = 0.16
var _grab_radius: float = 0.17
var _reject_bounce: float = 0.25
var _won: bool = false
var _revive_seconds: float = 15.0
var _force_restore: Array[Dictionary] = []


## Bölümü kurar: kablolar CableRoot'a, prizler ve kelepçeler panoya eklenir.
func build(level: KnotLevel, board: BoardBuilder, cable_root: Node3D,
		sparks: SparkBurst, camera: CameraRig) -> void:
	knot = level
	_sparks = sparks
	_camera = camera
	overload = monitor.overload
	_read_balance()
	monitor.configure(GameData.table("balance"))
	monitor.short_circuit.connect(_on_short_circuit)
	monitor.fuse_blown.connect(_on_fuse_blown)
	monitor.shield_changed.connect(_on_shield_changed)
	for cable_spec: CableSpec in knot.cables:
		var cable: CableNode = CableNode.new()
		cable.name = "Cable%d" % cable_spec.index
		cable_root.add_child(cable)
		cable.setup(cable_spec)
		cables.append(cable)
		board.add_source_clamp(cable_spec.source, cable_spec.color, cable_spec.voltage)
	for socket_spec: SocketSpec in knot.sockets:
		var socket: SocketNode = SocketNode.new()
		socket.name = "Socket%d" % socket_spec.index
		board.add_child(socket)
		socket.setup(socket_spec)
		sockets.append(socket)
		free_sockets.append(socket_spec.index)


# --- fizik / temas -------------------------------------------------------

func tick(delta: float) -> void:
	if knot == null or blown:
		return
	_tick_force_restore(delta)
	monitor.tick(delta, cables)


func total_cables() -> int:
	return cables.size()


# --- sürükle-bırak -------------------------------------------------------

## Dokunulan noktaya grab_radius içindeki en yakın bağlanmamış fişi seçer.
func pick_cable(point: Vector3) -> int:
	var best: int = -1
	var best_distance: float = _grab_radius
	for cable: CableNode in cables:
		if not cable.is_grabbable() or cable.is_linked() or not cable.is_inside_tree():
			continue
		var plug: Vector3 = cable.plug_position()
		var d: float = Vector2(plug.x - point.x, plug.y - point.y).length()
		if d <= best_distance:
			best_distance = d
			best = cable.index
	return best


func begin_drag(cable_index: int, target: Vector3) -> bool:
	if blown or _won or knot == null:
		return false
	if cable_index < 0 or cable_index >= cables.size():
		return false
	var cable: CableNode = cables[cable_index]
	if cable.is_linked() or not cable.is_grabbable():
		return false
	if dragging_index >= 0:
		end_drag()
	dragging_index = cable_index
	cable.begin_drag(target)
	return true


func update_drag(target: Vector3) -> void:
	if dragging_index < 0 or dragging_index >= cables.size():
		return
	cables[dragging_index].update_drag(target)


func is_dragging() -> bool:
	return dragging_index >= 0


func end_drag() -> void:
	if dragging_index < 0 or dragging_index >= cables.size():
		dragging_index = -1
		return
	var cable_index: int = dragging_index
	var cable: CableNode = cables[cable_index]
	var plug: Vector3 = cable.plug_position()
	dragging_index = -1
	cable.end_drag(false)
	_evaluate_release(cable_index, plug)


# --- ödüller / QA --------------------------------------------------------

## Yedek sigorta: yük ve temas sayaçları sıfırlanır, kalkan verilir.
func revive(shield_for: float = -1.0) -> void:
	var seconds: float = _revive_seconds if shield_for < 0.0 else shield_for
	monitor.reset()
	overload.add_shield(seconds)
	monitor.refresh_shield()
	blown = false
	_force_restore.clear()
	if dragging_index >= 0 and dragging_index < cables.size():
		cables[dragging_index].end_drag(false)
	dragging_index = -1


## Yalıtım spreyi / keski bonusu: kalkan ekle.
func apply_shield(seconds: float) -> void:
	if seconds <= 0.0:
		return
	overload.add_shield(seconds)
	monitor.refresh_shield()


## Altın yan keski hedefi: en çok temas etmiş, bağlanmamış kablo.
func best_cutter_target() -> int:
	var best: int = -1
	var best_ticks: int = -1
	for cable: CableNode in cables:
		if cable.is_linked() or not cable.is_grabbable():
			continue
		var ticks: int = int(monitor.contact_ticks.get(cable.index, 0))
		if ticks > best_ticks:
			best_ticks = ticks
			best = cable.index
	if best >= 0:
		return best
	for cable: CableNode in cables:
		if not cable.is_linked():
			return cable.index
	return -1


## Altın yan keski: kabloyu altın yayla kendi prizine oturtur.
func cutter_snap(cable_index: int) -> bool:
	return _snap_cable(cable_index, true)


## QA: kabloyu anında kendi prizine bağlar (normal akışın aynısı, animasyonsuz).
func force_snap(cable_index: int) -> bool:
	return _snap_cable(cable_index, false)


## QA: iki kabloyu gerçekten temas ettirir; tarama kıvılcım/sayacı üretir.
func force_contact(cable_index_a: int, cable_index_b: int) -> void:
	if knot == null or blown:
		return
	if cable_index_a < 0 or cable_index_a >= cables.size() or cable_index_b < 0 \
			or cable_index_b >= cables.size() or cable_index_a == cable_index_b:
		return
	var cable_b: CableNode = cables[cable_index_b]
	if cable_b.is_linked() or cable_b.is_dragging():
		return
	var offset: Vector3 = cables[cable_index_a].plug_position() - cable_b.plug_position()
	var original: Vector3 = cable_b.position
	cable_b.position = original + offset * 0.95
	# QA enjeksiyonu: temas gerçek taramadan gelsin diye sürükleme kapısı kısa süre açık
	monitor.force_active_contacts = true
	_force_restore.append({"node": cable_b, "position": original, "frames": 30})


# --- iç işleyiş ----------------------------------------------------------

func _snap_cable(cable_index: int, animated: bool) -> bool:
	if knot == null or cable_index < 0 or cable_index >= cables.size():
		return false
	var cable: CableNode = cables[cable_index]
	if cable.is_linked():
		return false
	var socket_index: int = cable.spec.socket_index
	if not free_sockets.has(socket_index):
		return false
	var socket: SocketNode = sockets[socket_index]
	dragging_index = -1
	free_sockets.erase(socket_index)
	if animated:
		cable.force_snap_animation(socket.spec.position)
	else:
		cable.snap_instant(socket.spec.position)
	socket.set_occupied(true)
	connected += 1
	_after_connection(cable_index, socket_index)
	return true


func _evaluate_release(cable_index: int, plug: Vector3) -> void:
	if knot == null or cable_index < 0 or cable_index >= cables.size():
		return
	var result: Dictionary = SnapRule.evaluate(plug, knot.sockets, free_sockets,
		cable_index, knot.cables, _snap_radius)
	var outcome: int = int(result.get("result", SnapRule.Result.NONE))
	if outcome == SnapRule.Result.SNAP:
		_connect_cable(cable_index, int(result.get("socket_index", -1)))
	elif outcome == SnapRule.Result.WRONG_COLOR:
		_reject_wrong(cable_index, int(result.get("socket_index", -1)), plug)


func _connect_cable(cable_index: int, socket_index: int) -> void:
	if socket_index < 0 or socket_index >= sockets.size():
		return
	if not free_sockets.has(socket_index) or cables[cable_index].is_linked():
		return
	var socket: SocketNode = sockets[socket_index]
	free_sockets.erase(socket_index)
	cables[cable_index].snap_to_with_socket(socket.spec.position, socket_index)
	socket.set_occupied(true)
	connected += 1
	_after_connection(cable_index, socket_index)


func _after_connection(cable_index: int, socket_index: int) -> void:
	snap_done.emit(cable_index, socket_index)
	connections_changed.emit(connected, cables.size())
	if connected >= cables.size() and not _won:
		_won = true
		for socket: SocketNode in sockets:
			socket.celebrate()
		level_completed.emit()


func _reject_wrong(cable_index: int, socket_index: int, plug: Vector3) -> void:
	var cable: CableNode = cables[cable_index]
	cable.bounce_up(_reject_bounce)
	cable.notify_wrong_socket()
	if socket_index >= 0 and socket_index < sockets.size():
		sockets[socket_index].flash_wrong()
	if _sparks != null:
		_sparks.burst(plug + Vector3(0.0, 0.0, 0.06), cable.spec.color, 1.2)
	if _camera != null:
		_camera.shake(0.3)
	monitor.apply_wrong_socket_penalty()
	wrong_socket_try.emit(cable_index, socket_index)


func _on_short_circuit(point: Vector3, color: Color) -> void:
	if _sparks != null:
		_sparks.burst(point, color, 1.0)
	if _camera != null:
		_camera.shake(0.35)
	short_circuit.emit(point, color)


func _on_fuse_blown() -> void:
	blown = true
	if dragging_index >= 0 and dragging_index < cables.size():
		cables[dragging_index].end_drag(false)
	dragging_index = -1
	if _sparks != null:
		_sparks.burst(Vector3(0.0, 0.7, 0.16), Color(1.0, 0.86, 0.4), 2.2)
	if _camera != null:
		_camera.shake(0.9)
	fuse_blown.emit()


func _on_shield_changed(active: bool) -> void:
	for cable: CableNode in cables:
		cable.set_shielded(active)


func _tick_force_restore(delta: float) -> void:
	if _force_restore.is_empty():
		return
	var remaining: Array[Dictionary] = []
	for entry: Dictionary in _force_restore:
		var frames: int = int(entry.get("frames", 0)) - 1
		var node: Node3D = entry.get("node") as Node3D
		if frames <= 0:
			if node != null and is_instance_valid(node):
				node.position = entry.get("position", node.position)
			continue
		entry["frames"] = frames
		remaining.append(entry)
	_force_restore = remaining
	if _force_restore.is_empty():
		monitor.force_active_contacts = false


## Sadece bu sınıfın kullandığı denge değerleri; bar/kalkan ContactMonitor'da.
func _read_balance() -> void:
	var balance: Dictionary = GameData.table("balance")
	var snap_cfg: Dictionary = _section(balance, "snap")
	var cable_cfg: Dictionary = _section(balance, "cable")
	var overload_cfg: Dictionary = _section(balance, "overload")
	_snap_radius = float(snap_cfg.get("radius", 0.16))
	_reject_bounce = float(snap_cfg.get("reject_bounce", 0.25))
	_grab_radius = float(cable_cfg.get("grab_radius", 0.17))
	_revive_seconds = float(overload_cfg.get("revive_shield_seconds", 15.0))


func _section(balance: Dictionary, key: String) -> Dictionary:
	var raw: Variant = balance.get(key, {})
	if raw is Dictionary:
		return raw as Dictionary
	return {}
