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
## locked_socket: kilitli priz yanında fiş tutulurken/kilide bırakılırken ipucu.
signal locked_socket_hint(socket_index: int)
signal socket_unlocked(socket_index: int)
## blackout: 0 = aydınlık, 1 = karanlık (yumuşak geçiş; board/game uygular).
signal blackout_changed(amount: float)

var knot: KnotLevel = null
var cables: Array[CableNode] = []
## sway modifier'ı: panoya sabitlenmiş, yavaşça salınan canlı hatlar.
var obstacles: Array[CableNode] = []
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

## --- modifier durumu (ARCHITECTURE §12) ---
var _locked_modifier: bool = false
var _sway_modifier: bool = false
var _blackout_modifier: bool = false
var _hold_seconds: float = SocketNode.DEFAULT_HOLD_SECONDS
var _hold_radius: float = 0.16
var _hold_socket: int = -1
var _hold_progress: float = 0.0
var _blackout_cycle: float = 16.0
var _blackout_time: float = 0.0
var _blackout_amount: float = 0.0


## Bölümü kurar: kablolar CableRoot'a, prizler ve kelepçeler panoya eklenir.
func build(level: KnotLevel, board: BoardBuilder, cable_root: Node3D,
		sparks: SparkBurst, camera: CameraRig) -> void:
	knot = level
	_sparks = sparks
	_camera = camera
	overload = monitor.overload
	_read_balance()
	_read_modifier_balance()
	monitor.configure(GameData.table("balance"), knot.modifiers)
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
	_locked_modifier = knot.has_modifier(KnotLevel.MODIFIER_LOCKED_SOCKET)
	_sway_modifier = knot.has_modifier(KnotLevel.MODIFIER_SWAY)
	_blackout_modifier = knot.has_modifier(KnotLevel.MODIFIER_BLACKOUT)
	if _sway_modifier:
		_build_obstacles(board)
	if _blackout_modifier:
		_blackout_time = _blackout_cycle * 0.5


## sway: panoda yavaşça salınan 1-2 canlı hat (uçları sabit).
func _build_obstacles(board: BoardBuilder) -> void:
	var sway_cfg: Dictionary = _modifier_config("sway")
	var count: int = clampi(knot.cables.size() - int(sway_cfg.get("base_cables", 4)),
		1, maxi(1, int(sway_cfg.get("max_obstacles", 2))))
	var board_cfg: Dictionary = {
		"width": board.width,
		"height": board.height,
		"board_surface_z": board.surface_z,
	}
	var plans: Array[Dictionary] = ObstacleCable.plan_obstacles(knot.seed, count,
		board_cfg, sway_cfg)
	var live_color: Color = Color.from_string(
		String(sway_cfg.get("color", "#FFB347")), Color(1.0, 0.72, 0.28))
	for i: int in plans.size():
		var obstacle: ObstacleCable = ObstacleCable.new()
		obstacle.name = "LiveWire%d" % i
		board.add_child(obstacle)
		obstacle.setup_obstacle(plans[i], live_color)
		obstacles.append(obstacle)


# --- fizik / temas -------------------------------------------------------

func tick(delta: float) -> void:
	if knot == null or blown:
		return
	_tick_force_restore(delta)
	if dragging_index >= 0:
		_tick_hold(delta)
	else:
		_reset_hold()
	_tick_blackout(delta)
	monitor.tick(delta, cables, obstacles)


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
		_reset_hold()
		return
	var cable_index: int = dragging_index
	var cable: CableNode = cables[cable_index]
	var plug: Vector3 = cable.plug_position()
	dragging_index = -1
	cable.end_drag(false)
	_evaluate_release(cable_index, plug)
	_reset_hold()


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
	# QA/altın keski otoriterdir: kilitli kapak açılır (force_snap 12 bölümü bitirir).
	if socket.is_locked():
		socket.set_locked(false, false)
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
	var target_index: int = int(result.get("socket_index", -1))
	# locked_socket: kilitliyken snap yok, ceza da yok; oyuncu fişi tutmaya devam eder.
	if (outcome != SnapRule.Result.NONE and target_index >= 0
			and target_index < sockets.size() and sockets[target_index].is_locked()):
		_reset_hold()
		locked_socket_hint.emit(target_index)
		return
	if outcome == SnapRule.Result.SNAP:
		_connect_cable(cable_index, target_index)
	elif outcome == SnapRule.Result.WRONG_COLOR:
		_reject_wrong(cable_index, target_index, plug)


func _connect_cable(cable_index: int, socket_index: int) -> void:
	if socket_index < 0 or socket_index >= sockets.size():
		return
	if not free_sockets.has(socket_index) or cables[cable_index].is_linked():
		return
	var socket: SocketNode = sockets[socket_index]
	if socket.is_locked():
		return  # kapak açılmadan bağlantı kurulmaz
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


# --- modifier'lar (ARCHITECTURE §12) -------------------------------------

## locked_socket: sürüklenen fiş kendi rengindeki kilitli prizin yanında tutulursa
## kapak 0.6 sn sonra açılır (saf kural SocketNode'da; burada sadece zamanlama).
func _tick_hold(delta: float) -> void:
	if not _locked_modifier or dragging_index < 0 or dragging_index >= cables.size():
		_reset_hold()
		return
	var cable: CableNode = cables[dragging_index]
	if cable.is_linked() or cable.spec == null:
		_reset_hold()
		return
	var socket_index: int = _nearby_locked_socket(cable)
	if socket_index < 0:
		_reset_hold()
		return
	if socket_index != _hold_socket:
		_hold_socket = socket_index
		_hold_progress = 0.0
		locked_socket_hint.emit(socket_index)
	_hold_progress = SocketNode.advance_hold(_hold_progress, delta, _hold_seconds)
	var socket: SocketNode = sockets[socket_index]
	socket.set_hold_progress(_hold_progress / maxf(_hold_seconds, 0.001))
	if SocketNode.is_hold_complete(_hold_progress, _hold_seconds):
		_unlock_socket(socket_index)


func _nearby_locked_socket(cable: CableNode) -> int:
	var plug: Vector3 = cable.plug_position()
	var color_id: StringName = cable.spec.color_id
	for socket_index: int in free_sockets:
		if socket_index < 0 or socket_index >= sockets.size():
			continue
		var socket: SocketNode = sockets[socket_index]
		if not socket.is_locked() or socket.spec == null:
			continue
		if socket.spec.color_id != color_id:
			continue
		var flat: float = Vector2(plug.x - socket.position.x,
			plug.y - socket.position.y).length()
		if flat <= _hold_radius:
			return socket_index
	return -1


func _unlock_socket(socket_index: int) -> void:
	if socket_index < 0 or socket_index >= sockets.size():
		return
	var socket: SocketNode = sockets[socket_index]
	if not socket.is_locked():
		return
	socket.set_locked(false, true)
	_reset_hold()
	socket_unlocked.emit(socket_index)


func _reset_hold() -> void:
	if _hold_socket >= 0 and _hold_socket < sockets.size():
		sockets[_hold_socket].set_hold_progress(0.0)
	_hold_socket = -1
	_hold_progress = 0.0


## blackout: yumuşak döngü (aydınlık -> kısık -> aydınlık). Görsel uygulama
## board.set_blackout(amount) ile game.gd'de; drag engellenmez.
func _tick_blackout(delta: float) -> void:
	if not _blackout_modifier:
		return
	_blackout_time += delta
	var phase: float = fposmod(_blackout_time / _blackout_cycle, 1.0)
	var amount: float = blackout_amount_for_phase(phase)
	if absf(amount - _blackout_amount) >= 0.01:
		_blackout_amount = amount
		blackout_changed.emit(amount)


## ASMR oynanabilirlik sınırı: pano asla tam karanlık olmaz; kablolar/fişler/priz
## halkaları emissive olduğu için okunur kalır (ARCHITECTURE §12 + §16).
const MAX_BLACKOUT_AMOUNT: float = 0.6


## Saf kural (birim testli): döngü fazına göre karanlık miktarı 0..0.6.
## Yumuşak sinus: faz 0 aydınlık, 0.5 en kısık, 1 tekrar aydınlık (period >= 6 sn).
static func blackout_amount_for_phase(phase: float) -> float:
	var p: float = fposmod(phase, 1.0)
	var wave: float = 0.5 - 0.5 * cos(TAU * p)
	return MAX_BLACKOUT_AMOUNT * wave


func _read_modifier_balance() -> void:
	var balance: Dictionary = GameData.table("balance")
	var modifiers_cfg: Dictionary = _section(balance, "modifiers")
	var locked_cfg: Dictionary = _section(modifiers_cfg, "locked_socket")
	var blackout_cfg: Dictionary = _section(modifiers_cfg, "blackout")
	_hold_seconds = maxf(0.05, float(locked_cfg.get("hold_seconds",
		SocketNode.DEFAULT_HOLD_SECONDS)))
	_hold_radius = maxf(0.02, float(locked_cfg.get("hold_radius", 0.16)))
	_blackout_cycle = maxf(4.0, float(blackout_cfg.get("cycle_seconds", 16.0)))


func _modifier_config(modifier: String) -> Dictionary:
	var balance: Dictionary = GameData.table("balance")
	var modifiers_cfg: Dictionary = _section(balance, "modifiers")
	return _section(modifiers_cfg, modifier)


## --- QA/tanı yardımcıları ---
func obstacle_count() -> int:
	return obstacles.size()


func locked_socket_count() -> int:
	var total: int = 0
	for socket: SocketNode in sockets:
		if socket.is_locked():
			total += 1
	return total


func hold_progress() -> float:
	return _hold_progress


func blackout_amount() -> float:
	return _blackout_amount


func has_modifier(modifier: StringName) -> bool:
	return knot != null and knot.has_modifier(modifier)


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
