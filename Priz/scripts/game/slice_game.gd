class_name SliceGame
extends Node3D
## Dikey kesitin oyun sahnesi: diorama (RoomView), duvardaki ve başparmak bölgesindeki sigorta kutusu,
## cihaz tepsisi, fiş sürükleme/mıknatıs/oturma, geri alma, hat inceleme, gerilim, katmanlı ses ve
## kazanma sahnesi. Kurallar `PrizBoard`da (SliceState üzerinden); burası yalnız canlandırır.
##
## Kabuk (scripts/ui/game.gd) bunu örnekler: `start_level(i)`, sinyal `level_won` (kazanma sahnesi bitti),
## `set_input_enabled(bool)`. Düz kip: kayıp yok. Gün kipi (aşama 3) için yer: `Phase.DAY` ve sigorta
## kutusunun ana şalteri `start_day_requested` ile buraya eklenecek.
## Prob/çekim için sürülebilir arayüz: `press/move/release(ekran)`, `drag_device_to_socket`,
## `tap_device`, `screen_of_device`, `screen_of_room_socket`, `skip_win`.

signal level_won
signal level_started(index: int)
## Gün kipi için ayrıldı (aşama 3): sigorta kutusunun ana şalteri.
signal start_day_requested

enum Mode { IDLE, PRESS_TRAY, DRAG, PRESS_PLUGGED, PRESS_SOCKET, PARALLAX, WIN, DONE }
enum Phase { PLAN, DAY }

const HINT_IDLE_SECONDS: float = 6.0
const PULSE_IDLE_SECONDS: float = 2.5
const HINT_SHOW_SECONDS: float = 2.6
## Fiş parmağın bu kadar üstünde durur (başparmak örtmesin).
const LIFT_PX: float = 140.0
const MAGNET_PX: float = 150.0
const SNAP_PX: float = 120.0
const TAP_MOVE_PX: float = 28.0
const PARALLAX_PX: float = 420.0
const DEVICE_PICK_PX: float = 95.0
const SOCKET_PICK_PX: float = 80.0
const TOP_BAR_PX: float = 170.0
const WIN_BEAT_SECONDS: float = 0.55
const WIN_SECONDS: float = 3.6
## Başparmak bölgesi nesneleri (tepsi, büyük sigorta kutusu) kameradan bu derinlikte durur.
const THUMB_DEPTH: float = 12.4
## Kamera kadrajı (dikey; diorama büyük, alt üçte birde tepsi).
const CAM_DISTANCE: float = 12.6
const CAM_PITCH: float = 35.0
const CAM_YAW: float = 42.0
const CAM_FOV: float = 31.5
const CAM_OFFSET: Vector2 = Vector2(0.05, -1.95)
## Tasarım ekranı (1080 genişlik); alt bölge alttan ölçülür (uzun telefonlarda tepsi altta kalır).
const DESIGN: Vector2 = Vector2(1080.0, 1920.0)
## Büyük sigorta kutusu: ekran merkezi (alttan) ve boyu (px).
const PANEL_CENTER: Vector2 = Vector2(215.0, 1525.0)
const PANEL_HEIGHT: float = 600.0
## Tepsi: sütun merkezleri, satır tabanları (alttan), yuva boyu (px).
const TRAY_COLUMNS: Array[float] = [535.0, 735.0, 935.0]
const TRAY_ROWS: Array[float] = [1520.0, 1830.0]
const SLOT_FIT: Vector2 = Vector2(150.0, 205.0)
const SLOT_DISC_PX: float = 92.0
const LINE_COLORS: Array[Color] = [Color(0.95, 0.4, 0.33), Color(0.33, 0.62, 0.95), Color(0.98, 0.78, 0.3)]

var data: SliceData
var content: PrizContent
var state: SliceState
var view: RoomView
var wall_box: FuseBox
var panel_box: FuseBox
var wall_gauges: SliceGauges
var panel_gauges: SliceGauges
var tray: SliceTray
var fx: SliceFx
var audio: SliceAudio
var finger: SliceFinger
var devices: Dictionary = {}          # cihaz kimliği -> SliceDevice
var device_order: Array[String] = []
var level_index: int = 0
var level_time: int = PrizSlice.MORNING
var mode: Mode = Mode.IDLE
var phase: Phase = Phase.PLAN

var _input_enabled: bool = true
var _press_pos: Vector2 = Vector2.ZERO
var _finger_pos: Vector2 = Vector2.ZERO
var _active_device: String = ""
var _press_socket: String = ""
var _hover_socket: String = ""
var _magnet_socket: String = ""
var _accepting: PackedStringArray = PackedStringArray()
var _idle: float = 0.0
var _hint_left: float = 0.0
var _hint_device: String = ""
var _hint_socket: String = ""
var _tutorial: String = ""
var _tutorial_done: bool = false
var _near_lines: Array[int] = []
var _flicker_cooldown: float = 0.0
var _inspect_left: float = 0.0
var _inspect_line: int = 0
var _m_per_px: float = 0.01
var _cam_basis: Basis = Basis.IDENTITY
var _win_tween: Tween
var _solver: PrizSolver = PrizSolver.new()
var _slot_of: Dictionary = {}         # cihaz kimliği -> yuva dizini
var _socket_depth: Dictionary = {}    # oda prizi -> kamera derinliği
var _plug_count: int = 0


func _ready() -> void:
	data = SliceData.load_default()
	content = PrizContent.load_default()
	view = RoomView.new()
	view.name = "RoomView"
	view.start_slice = PrizSlice.MORNING
	add_child(view)
	_frame_camera()
	wall_box = FuseBox.new()
	wall_box.name = "WallFuseBox"
	view.place_at_anchor(wall_box, "Anchor_FuseBox")
	wall_gauges = SliceGauges.new(wall_box)
	panel_box = FuseBox.new()
	panel_box.name = "PanelFuseBox"
	view.add_child(panel_box)
	panel_gauges = SliceGauges.new(panel_box)
	tray = SliceTray.new()
	tray.name = "Tray"
	view.add_child(tray)
	fx = SliceFx.new()
	fx.name = "Fx"
	view.add_child(fx)
	for i: int in range(3):
		var col: Color = LINE_COLORS[i]
		for socket_name: String in data.room_socket_names():
			if data.room_line_of_socket(socket_name) == i + 1:
				fx.add_halo(socket_name, view.get_socket(socket_name), col)
	audio = SliceAudio.new()
	audio.name = "Audio"
	add_child(audio)
	get_viewport().size_changed.connect(_on_viewport_resized)


func _exit_tree() -> void:
	if _win_tween != null and _win_tween.is_valid():
		_win_tween.kill()


## Hayalet parmak katmanı (kabuk verir; 2B, 3B'nin üstünde).
func set_overlay(control: Control) -> void:
	finger = SliceFinger.new()
	finger.name = "GhostFinger"
	control.add_child(finger)


func set_input_enabled(on: bool) -> void:
	_input_enabled = on
	if not on and (mode == Mode.DRAG or mode == Mode.PRESS_TRAY):
		_cancel_drag()
	if not on and mode == Mode.PARALLAX:
		view.camera_rig.set_parallax(Vector2.ZERO)
		mode = Mode.IDLE


# --- seviye ------------------------------------------------------------------------------

## `index` kesit seviyesi (0 tabanlı). Önceki seviyenin cihazları ve sesleri temizlenir.
func start_level(index: int, transition: float = 0.0) -> void:
	_clear_level()
	level_index = clampi(index, 0, maxi(data.level_count() - 1, 0))
	var level: PrizLevel = data.load_level(level_index)
	state = SliceState.new(level, content.registry, data)
	level_time = data.level_time(level_index)
	_tutorial = data.level_tutorial(level_index)
	_tutorial_done = false
	mode = Mode.IDLE
	phase = Phase.PLAN
	view.camera_rig.reset_view()
	view.day_light.set_slice(level_time, transition)
	for box: FuseBox in [wall_box, panel_box]:
		box.set_line_count(state.room_lines().size())
		box.set_slice_dial(level_time, transition)
		box.set_main_lever(false, false)
		for line: int in state.room_lines():
			box.set_line_capacity(line, state.capacity(line))
			box.set_line_fill(line, 0.0)
			box.set_breaker(line, true)
	_apply_room_masks()
	for device: PrizDevice in level.devices:
		var d: SliceDevice = SliceDevice.new()
		d.name = "Device_%s" % device.id
		view.appliances_root.add_child(d)
		d.setup(device.id, device.type, device.blocks, data.appliance(device.type))
		var anchor: Node3D = view.get_anchor(d.room_anchor)
		if anchor != null:
			d.set_room_xform(anchor.global_transform)
		d.arrived.connect(_on_device_arrived)
		devices[device.id] = d
		device_order.append(device.id)
		_slot_of[device.id] = device_order.size() - 1
	tray.set_slot_count(device_order.size())
	tray.set_faded(0.0)
	_layout()
	_refresh_lines(false)
	audio.begin_level(level_time)
	fx.prewarm(view.get_socket("Socket_02").global_position)
	_idle = 0.0
	_hint_left = 0.0
	level_started.emit(level_index)


func _clear_level() -> void:
	if _win_tween != null and _win_tween.is_valid():
		_win_tween.kill()
	if view.day_light.is_win_playing():
		view.day_light.skip_win()
	for id: String in device_order:
		var d: SliceDevice = devices[id] as SliceDevice
		d.appliance.set_running(false, 0.0)
		d.queue_free()
	if audio != null:
		audio.stop_all(0.3)
	devices.clear()
	device_order.clear()
	_slot_of.clear()
	_active_device = ""
	_hover_socket = ""
	_magnet_socket = ""
	_near_lines.clear()
	_plug_count = 0
	if fx != null:
		fx.clear_halos()
	if finger != null:
		finger.stop()


## Seviyede kullanılmayan prizler ve hatlar kalıcı olarak solar.
func _apply_room_masks() -> void:
	var used: PackedStringArray = state.room_sockets()
	for socket_name: String in data.room_socket_names():
		view.set_socket_highlight(socket_name, 0.0)
		view.set_socket_dim(socket_name, 0.0 if used.has(socket_name) else 0.85)
	var lines: Array[int] = state.room_lines()
	for line: int in range(1, 4):
		view.set_line_dim(line, 0.0 if lines.has(line) else 0.8)
		view.set_line_highlight(line, 0.0)
		view.set_line_glow(line, 0.0)


# --- kadraj ve yerleşim ---------------------------------------------------------------------

func _frame_camera() -> void:
	var rig: DioramaCamera = view.camera_rig
	rig.distance = CAM_DISTANCE
	rig.pitch_deg = CAM_PITCH
	rig.yaw_deg = CAM_YAW
	rig.fov_deg = CAM_FOV
	rig.screen_offset = CAM_OFFSET
	rig.reset_view()


func _on_viewport_resized() -> void:
	if state != null:
		_layout()


## Ekran (tasarım px, alt bölge alttan ölçülür) → görünür alan koordinatı.
func _design_to_screen(p: Vector2) -> Vector2:
	var size: Vector2 = get_viewport().get_visible_rect().size
	var sx: float = size.x / DESIGN.x
	return Vector2(p.x * sx, size.y - (DESIGN.y - p.y) * sx)


func _screen_to_world(p: Vector2, depth: float) -> Vector3:
	return view.camera_rig.camera.project_position(p, depth)


## Tepsi, büyük sigorta kutusu ve cihaz yuvaları ekran yerleşiminden dünyaya kurulur.
func _layout() -> void:
	var cam: Camera3D = view.camera_rig.camera
	_cam_basis = cam.global_transform.basis.orthonormalized()
	var a: Vector3 = _screen_to_world(_design_to_screen(Vector2(540.0, 1500.0)), THUMB_DEPTH)
	var b: Vector3 = _screen_to_world(_design_to_screen(Vector2(640.0, 1500.0)), THUMB_DEPTH)
	_m_per_px = a.distance_to(b) / (_design_to_screen(Vector2(640.0, 0.0)).x - _design_to_screen(Vector2(540.0, 0.0)).x)
	var px: float = _m_per_px * (get_viewport().get_visible_rect().size.x / DESIGN.x)
	# Büyük sigorta kutusu: kameraya dönük, hafif çevrik (3B hissi).
	var panel_pos: Vector3 = _screen_to_world(_design_to_screen(PANEL_CENTER), THUMB_DEPTH)
	var panel_scale: float = PANEL_HEIGHT * px / 0.724
	var face: Basis = _cam_basis * Basis(Vector3.UP, deg_to_rad(14.0))
	panel_box.global_transform = Transform3D(face.scaled(Vector3.ONE * panel_scale), panel_pos)
	var block: Vector2 = Vector2(0.046 * panel_scale, 0.2 * panel_scale / SliceGauges.SLOTS)
	# Cihaz yuvaları
	var yaw: float = deg_to_rad(CAM_YAW - 18.0)
	for id: String in device_order:
		var i: int = int(_slot_of[id])
		var col: int = i % TRAY_COLUMNS.size()
		var row: int = i / TRAY_COLUMNS.size()
		var base_screen: Vector2 = _design_to_screen(Vector2(TRAY_COLUMNS[col], TRAY_ROWS[row]))
		var base: Vector3 = _screen_to_world(base_screen, THUMB_DEPTH)
		tray.place_slot(i, base, SLOT_DISC_PX * px)
		var pip_screen: Vector2 = _design_to_screen(Vector2(TRAY_COLUMNS[col] + 78.0, TRAY_ROWS[row] - 12.0))
		var pip_origin: Vector3 = _screen_to_world(pip_screen, THUMB_DEPTH - 0.6)
		var d: SliceDevice = devices[id] as SliceDevice
		d.set_tray_layout(base, yaw, SLOT_FIT * px * Vector2(d_fit(d), d_fit(d)), pip_origin, block, _cam_basis)
	_socket_depth.clear()
	for socket_name: String in data.room_socket_names():
		var s: Node3D = view.get_socket(socket_name)
		_socket_depth[socket_name] = -(cam.global_transform.affine_inverse() * s.global_position).z


func d_fit(d: SliceDevice) -> float:
	return float(data.appliance(d.type).get("tray_fit", 1.0))


# --- ekran sorguları (dokunma sınaması, prob ve çekim aracı) ----------------------------------

func _project(p: Vector3) -> Vector2:
	return view.camera_rig.camera.unproject_position(p)


func screen_of_room_socket(socket_name: String) -> Vector2:
	var s: Node3D = view.get_socket(socket_name)
	return _project(s.global_position) if s != null else Vector2.ZERO


func screen_of_device(device_id: String) -> Vector2:
	var d: SliceDevice = devices.get(device_id, null) as SliceDevice
	return _project(d.pick_center()) if d != null else Vector2.ZERO


## Fişin parmakla tutulacak yeri (tepside fişin kendisi değil cihazın ortası yeter).
func screen_of_plug(device_id: String) -> Vector2:
	var d: SliceDevice = devices.get(device_id, null) as SliceDevice
	return _project(d.plug.global_position) if d != null else Vector2.ZERO


func _tray_device_at(p: Vector2) -> String:
	var best: String = ""
	var best_d: float = INF
	for id: String in device_order:
		var d: SliceDevice = devices[id] as SliceDevice
		if d.place != SliceDevice.Place.TRAY:
			continue
		var c: Vector2 = _project(d.pick_center())
		var base: Vector2 = _project(d.tray_xform.origin)
		# Yuva dikdörtgeni: tabandan tepeye, geniş dokunma alanı (≥ 48 dp).
		var dist: float = minf(p.distance_to(c), minf(p.distance_to(base), p.distance_to((c + base) * 0.5)))
		if dist < DEVICE_PICK_PX * 1.1 and dist < best_d:
			best = id
			best_d = dist
	return best


func _plugged_device_at(p: Vector2) -> String:
	var best: String = ""
	var best_d: float = INF
	for id: String in device_order:
		var d: SliceDevice = devices[id] as SliceDevice
		if d.place != SliceDevice.Place.PLUGGED:
			continue
		var c: Vector2 = _project(d.pick_center())
		var r: float = maxf(DEVICE_PICK_PX * 0.7, d.pick_radius_world() / maxf(_m_per_px, 0.0001) * 0.9)
		var dist: float = p.distance_to(c)
		var plug_d: float = p.distance_to(_project(d.plug.global_position))
		if plug_d < SOCKET_PICK_PX and plug_d < best_d:
			best = id
			best_d = plug_d
		elif dist < r and dist < best_d:
			best = id
			best_d = dist
	return best


func _level_socket_near(p: Vector2, radius: float) -> String:
	var best: String = ""
	var best_d: float = radius
	for socket_name: String in state.room_sockets():
		var dist: float = p.distance_to(screen_of_room_socket(socket_name))
		if dist < best_d:
			best = socket_name
			best_d = dist
	return best


# --- giriş -----------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not _input_enabled:
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null and touch.index == 0:
		if touch.pressed:
			if touch.position.y < TOP_BAR_PX:
				return
			press(touch.position)
		else:
			release(touch.position)
		get_viewport().set_input_as_handled()
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null and drag.index == 0:
		move(drag.position)
		get_viewport().set_input_as_handled()


func press(p: Vector2) -> void:
	_idle = 0.0
	_end_hint()
	_press_pos = p
	_finger_pos = p
	if mode == Mode.WIN:
		skip_win()
		return
	if mode != Mode.IDLE or state == null or not state.board.is_planning():
		return
	var tray_id: String = _tray_device_at(p)
	if tray_id != "":
		_begin_drag(tray_id)
		return
	var plugged: String = _plugged_device_at(p)
	if plugged != "":
		_active_device = plugged
		mode = Mode.PRESS_PLUGGED
		audio.play("ui_soft")
		return
	var sock: String = _level_socket_near(p, SOCKET_PICK_PX)
	if sock != "":
		_press_socket = sock
		mode = Mode.PRESS_SOCKET
		_inspect(sock)
		return
	mode = Mode.PARALLAX


func move(p: Vector2) -> void:
	_finger_pos = p
	_idle = 0.0
	match mode:
		Mode.DRAG:
			_update_drag(p)
		Mode.PARALLAX:
			var v: Vector2 = (p - _press_pos) / PARALLAX_PX
			view.camera_rig.set_parallax(Vector2(-v.x, v.y))
		_:
			pass


func release(p: Vector2) -> void:
	_finger_pos = p
	_idle = 0.0
	match mode:
		Mode.DRAG:
			_drop(p)
		Mode.PRESS_PLUGGED:
			mode = Mode.IDLE
			if p.distance_to(_press_pos) < TAP_MOVE_PX * 3.0:
				unplug(_active_device)
			_active_device = ""
		Mode.PRESS_SOCKET:
			mode = Mode.IDLE
			var dev: String = state.device_at_room_socket(_press_socket)
			if dev != "" and p.distance_to(_press_pos) < TAP_MOVE_PX:
				unplug(dev)
			_press_socket = ""
		Mode.PARALLAX:
			view.camera_rig.set_parallax(Vector2.ZERO)
			mode = Mode.IDLE
		_:
			pass


# --- sürükleme -------------------------------------------------------------------------------

func _begin_drag(device_id: String) -> void:
	var d: SliceDevice = devices[device_id] as SliceDevice
	_active_device = device_id
	mode = Mode.DRAG
	d.lift(true)
	d.begin_drag()
	audio.play("plug_pickup", 0.04)
	Haptics.tick()
	if finger != null:
		finger.stop()
	_accepting = state.accepting_room_sockets(device_id)
	var lines_ok: Dictionary = {}
	for socket_name: String in state.room_sockets():
		var ok: bool = _accepting.has(socket_name)
		view.set_socket_highlight(socket_name, 1.0 if ok else 0.0)
		view.set_socket_dim(socket_name, 0.0 if ok else 0.9)
		fx.set_halo(socket_name, 1.0 if ok else 0.0)
		if ok:
			lines_ok[state.room_line_of_room_socket(socket_name)] = true
	for line: int in state.room_lines():
		view.set_line_dim(line, 0.0 if lines_ok.has(line) else 0.55)
	_update_drag(_finger_pos)


func _update_drag(p: Vector2) -> void:
	var d: SliceDevice = devices.get(_active_device, null) as SliceDevice
	if d == null:
		return
	var cam: Camera3D = view.camera_rig.camera
	var target: Vector2 = p + Vector2(0.0, -LIFT_PX)
	# Derinlik: tepsiden yukarı çıktıkça odaya doğru (en yakın prizin derinliğine).
	var near_sock: String = _level_socket_near(target, 100000.0)
	var room_depth: float = float(_socket_depth.get(near_sock, CAM_DISTANCE)) - 0.7
	var tray_top: float = _design_to_screen(Vector2(0.0, TRAY_ROWS[0] - 260.0)).y
	var up_t: float = clampf((tray_top - target.y) / 360.0, 0.0, 1.0)
	var depth: float = lerpf(THUMB_DEPTH - 0.4, room_depth, smoothstep(0.0, 1.0, up_t))
	var cam_fwd: Vector3 = -cam.global_transform.basis.z
	var free_pos: Vector3 = _in_front_of_room(target, depth, cam, cam_fwd)
	var free_basis: Basis = Basis.looking_at(cam_fwd.lerp(Vector3.DOWN, 0.25).normalized(), Vector3.UP)
	var plug_scale: float = lerpf(SliceDevice.PLUG_TRAY_SCALE, 3.4, up_t)
	# Mıknatıs: en yakın seviye prizi
	var hover: String = _level_socket_near(target, MAGNET_PX)
	var xf: Transform3D = Transform3D(free_basis, free_pos)
	if hover != "":
		var s: Node3D = view.get_socket(hover)
		var dist: float = target.distance_to(screen_of_room_socket(hover))
		var k: float = 1.0 - smoothstep(SNAP_PX * 0.35, MAGNET_PX, dist)
		var accept: bool = _accepting.has(hover)
		if not accept:
			k *= 0.35
		var front: Vector3 = s.global_position + s.global_basis.z * (0.06 + 0.25 * (1.0 - k))
		xf = Transform3D(free_basis.slerp(s.global_basis.orthonormalized(), k * 0.9), free_pos.lerp(front, k * 0.85))
		plug_scale = lerpf(plug_scale, 1.8, k)
		if hover != _magnet_socket and accept:
			audio.play("plug_magnet", 0.05)
			Haptics.tick()
	_magnet_socket = hover
	d.drag_plug_to(xf, plug_scale)
	_set_hover(hover)


## Işın üstünde `depth` derinliğindeki nokta; ama odanın zemininin, arka ve sol duvarının ÖNÜNDE kalır
## (fiş dioramanın içine gömülüp görünmez olmasın). Oda: x 0..5.4, z 0..4.15, zemin y=0.
func _in_front_of_room(p: Vector2, depth: float, cam: Camera3D, fwd: Vector3) -> Vector3:
	var o: Vector3 = cam.project_ray_origin(p)
	var dir: Vector3 = cam.project_ray_normal(p)
	var t: float = depth / maxf(dir.dot(fwd), 0.05)
	var room_t: float = INF
	for plane: Plane in [Plane(Vector3.UP, 0.12), Plane(Vector3.BACK, 0.12), Plane(Vector3.RIGHT, 0.12)]:
		var hit: Variant = plane.intersects_ray(o, dir)
		if hit is Vector3:
			var h: Vector3 = hit as Vector3
			if h.x >= -0.2 and h.x <= 5.6 and h.z >= -0.2 and h.z <= 4.4 and h.y >= -0.3 and h.y <= 2.8:
				room_t = minf(room_t, o.distance_to(h))
	t = minf(t, room_t - 0.35)
	return o + dir * maxf(t, 1.0)


func _set_hover(socket_name: String) -> void:
	if socket_name == _hover_socket:
		return
	if _hover_socket != "" and _accepting.has(_hover_socket):
		fx.set_halo(_hover_socket, 1.0)
	_hover_socket = socket_name
	var d: SliceDevice = devices.get(_active_device, null) as SliceDevice
	if socket_name == "" or d == null:
		wall_gauges.clear_ghost()
		panel_gauges.clear_ghost()
		_highlight_gauge_line(0)
		if d != null:
			d.set_pip_tint(SliceDevice.PIP_COLOR)
		return
	var pv: Dictionary = state.preview(_active_device, socket_name)
	var line: int = int(pv["line"])
	var ghost: float = float(d.blocks)
	wall_gauges.set_ghost(line, ghost)
	panel_gauges.set_ghost(line, ghost)
	_highlight_gauge_line(line)
	d.set_pip_tint(LINE_COLORS[line - 1] if bool(pv["fits"]) else Color(1.0, 0.3, 0.25))
	if _accepting.has(socket_name):
		fx.set_halo(socket_name, 2.0)


func _highlight_gauge_line(line: int) -> void:
	for l: int in range(1, 5):
		var v: float = 0.8 if l == line else 0.0
		wall_box.set_line_highlight(l, v)
		panel_box.set_line_highlight(l, v)


func _drop(p: Vector2) -> void:
	var device_id: String = _active_device
	var d: SliceDevice = devices[device_id] as SliceDevice
	var target: Vector2 = p + Vector2(0.0, -LIFT_PX)
	var sock: String = _level_socket_near(target, SNAP_PX)
	_end_drag_visuals()
	mode = Mode.IDLE
	_active_device = ""
	if sock == "":
		d.return_plug()
		d.set_pip_tint(SliceDevice.PIP_COLOR)
		audio.play("plug_unplug", 0.05)
		return
	var reason: StringName = state.plug_room(device_id, sock)
	if reason != PrizReason.OK:
		_reject(d, sock, reason)
		return
	_seat(d, sock)


func _end_drag_visuals() -> void:
	for socket_name: String in state.room_sockets():
		view.set_socket_highlight(socket_name, 0.0)
		view.set_socket_dim(socket_name, 0.0)
	for line: int in state.room_lines():
		view.set_line_dim(line, 0.0)
	fx.clear_halos()
	wall_gauges.clear_ghost()
	panel_gauges.clear_ghost()
	_highlight_gauge_line(0)
	_hover_socket = ""
	_magnet_socket = ""


func _cancel_drag() -> void:
	var d: SliceDevice = devices.get(_active_device, null) as SliceDevice
	_end_drag_visuals()
	if d != null:
		d.return_plug()
		d.set_pip_tint(SliceDevice.PIP_COLOR)
	_active_device = ""
	mode = Mode.IDLE


func _reject(d: SliceDevice, sock: String, reason: StringName) -> void:
	var s: Node3D = view.get_socket(sock)
	var line: int = state.room_line_of_room_socket(sock)
	audio.play("plug_reject", 0.04)
	Haptics.tick()
	if reason == PrizReason.WOULD_OVERFLOW:
		wall_gauges.set_ghost(line, float(d.blocks))
		panel_gauges.set_ghost(line, float(d.blocks))
		wall_gauges.reject(line)
		panel_gauges.reject(line)
		var t: Tween = create_tween()
		t.tween_interval(0.55)
		t.tween_callback(func() -> void:
			wall_gauges.clear_ghost()
			panel_gauges.clear_ghost())
	view.set_line_highlight(line, 0.0)
	# Fiş prizin ağzına kadar gelir, yumuşakça geri seker.
	var front: Vector3 = s.global_position + s.global_basis.z * 0.12
	d.drag_plug_to(Transform3D(s.global_basis.orthonormalized(), front), 1.3)
	d.set_pip_tint(Color(1.0, 0.3, 0.25))
	var back: Tween = create_tween()
	back.tween_interval(0.12)
	back.tween_callback(func() -> void:
		d.return_plug(0.42)
		d.set_pip_tint(SliceDevice.PIP_COLOR))


func _seat(d: SliceDevice, sock: String) -> void:
	var s: Node3D = view.get_socket(sock)
	var line: int = state.room_line_of_room_socket(sock)
	d.room_socket = sock
	d.place = SliceDevice.Place.TRAVEL
	d.seat_plug(s.global_transform, 0.08)
	_plug_count += 1
	_tutorial_done = true
	if finger != null:
		finger.stop()
	var t: Tween = create_tween()
	t.tween_interval(0.08)
	t.tween_callback(func() -> void:
		audio.seat_click()
		Haptics.thud()
		view.camera_rig.shake(0.55)
		fx.seat_burst(s.global_position, s.global_basis.z, LINE_COLORS[line - 1])
		d.set_pips_full(false, 0.3)
		tray.set_slot_empty(int(_slot_of[d.device_id]), true)
		_refresh_lines(true, line)
		view.set_line_glow(line, 3.2))
	t.tween_interval(0.12)
	t.tween_callback(d.travel_to_room)
	t.tween_interval(0.25)
	t.tween_callback(func() -> void: _refresh_lines(false))


func _on_device_arrived(d: SliceDevice) -> void:
	if d.place != SliceDevice.Place.PLUGGED or state.board.socket_of(d.device_id) == "":
		return
	d.appliance.set_running(true)
	audio.device_on(d.device_id, d.loop_sound)
	if state.board.is_won() and mode != Mode.WIN and mode != Mode.DONE:
		_begin_win()


## Takılı cihazı tepsiye döndürür (sınırsız geri alma).
func unplug(device_id: String) -> bool:
	var d: SliceDevice = devices.get(device_id, null) as SliceDevice
	if d == null or d.place != SliceDevice.Place.PLUGGED:
		return false
	var line: int = state.room_line_of(state.board.line_of_device(device_id))
	if not state.board.unplug(device_id):
		return false
	audio.play("plug_unplug", 0.04)
	audio.device_off(device_id)
	Haptics.tick()
	d.appliance.set_running(false)
	d.travel_to_tray()
	var t: Tween = create_tween()
	t.tween_interval(SliceDevice.RETURN_SECONDS * 0.8)
	t.tween_callback(func() -> void:
		d.set_pips_full(true, 0.3)
		tray.set_slot_empty(int(_slot_of[device_id]), false))
	_refresh_lines(true, line)
	return true


## Hat incele: o hattın tüm prizleri, kablosu ve göstergesi birlikte parlar.
func _inspect(socket_name: String) -> void:
	var line: int = state.room_line_of_room_socket(socket_name)
	if line <= 0:
		return
	audio.play("socket_tick", 0.03)
	Haptics.tick()
	_set_inspect(0)
	_inspect_line = line
	_inspect_left = 1.4
	view.set_line_highlight(line, 1.0)
	wall_box.set_line_highlight(line, 1.0)
	panel_box.set_line_highlight(line, 1.0)
	for s: String in state.room_sockets():
		if state.room_line_of_room_socket(s) == line:
			fx.set_halo(s, 1.4)


func _set_inspect(line: int) -> void:
	if _inspect_line > 0 and line == 0:
		view.set_line_highlight(_inspect_line, 0.0)
		wall_box.set_line_highlight(_inspect_line, 0.0)
		panel_box.set_line_highlight(_inspect_line, 0.0)
		if mode != Mode.DRAG:
			fx.clear_halos()
	_inspect_line = line


# --- hat durumu, gerilim ------------------------------------------------------------------------

## Göstergeler, kablo parlaması, uğultu perdesi ve sınır titremesi tahtadan yeniden okunur.
func _refresh_lines(bounce: bool, bounce_line: int = 0) -> void:
	for line: int in state.room_lines():
		var f: float = state.fill(line)
		wall_box.set_line_fill(line, f)
		panel_box.set_line_fill(line, f)
		view.set_line_glow(line, state.glow_for(line))
	if bounce and bounce_line > 0:
		wall_gauges.bounce(bounce_line)
		panel_gauges.bounce(bounce_line)
	audio.set_tension(state.tension())
	var near: Array[int] = state.near_limit_lines()
	for line: int in near:
		if not _near_lines.has(line):
			_flicker(0.7)
			break
	_near_lines = near


func _flicker(strength: float) -> void:
	_flicker_cooldown = randf_range(3.5, 6.0)
	view.day_light.flicker(strength, 1.1)
	audio.play("lamp_flicker", 0.05)
	for id: String in device_order:
		var d: SliceDevice = devices[id] as SliceDevice
		if d.type == "lamp" and d.place == SliceDevice.Place.PLUGGED:
			var t: Tween = create_tween()
			for v: float in [0.35, 1.0, 0.55, 1.0, 0.7, 1.0]:
				t.tween_callback(d.appliance.set_mains.bind(v))
				t.tween_interval(randf_range(0.04, 0.09))


# --- kazanma ------------------------------------------------------------------------------------

func _begin_win() -> void:
	mode = Mode.WIN
	_end_hint()
	if finger != null:
		finger.stop()
	_win_tween = create_tween()
	_win_tween.tween_interval(WIN_BEAT_SECONDS)
	_win_tween.tween_callback(_play_win)


func _play_win() -> void:
	if mode != Mode.WIN:
		return
	audio.win()
	Haptics.success()
	view.day_light.win_finished.connect(_on_win_finished, CONNECT_ONE_SHOT)
	view.day_light.play_win(WIN_SECONDS)
	for box: FuseBox in [wall_box, panel_box]:
		box.set_slice_dial(PrizSlice.NIGHT, 1.2)
	# Pencereler ve lambalar tek tek: yükselen "tink" dizisi (DayLight'ın ışık sırasıyla aynı ritim).
	var count: int = maxi(view.day_light.interior_lights.size() + 1, 4)
	var step: float = (WIN_SECONDS * 0.6) / float(count)
	var t: Tween = create_tween()
	t.tween_interval(WIN_SECONDS * 0.15)
	for i: int in range(count + 1):
		t.tween_callback(audio.play_pitched.bind("window_light", 1.0 + 0.12 * float(i), -2.0))
		t.tween_interval(step)
	_win_tween = t
	for line: int in state.room_lines():
		view.set_line_glow(line, 1.4)
	# Tepsi işini bitirdi: yavaşça kaybolur, sahne dioramaya kalır.
	var fade: Tween = create_tween()
	fade.tween_method(_set_tray_fade, 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE)


func _set_tray_fade(v: float) -> void:
	tray.set_faded(v)
	for id: String in device_order:
		var d: SliceDevice = devices[id] as SliceDevice
		d.pips.transparency = v
		d.pips.visible = v < 0.99


func _on_win_finished() -> void:
	if mode != Mode.WIN:
		return
	mode = Mode.DONE
	level_won.emit()


## Dokununca kazanma sahnesi sona atlar.
func skip_win() -> void:
	if mode != Mode.WIN:
		return
	if not view.day_light.is_win_playing():
		# Sahne henüz başlamadı (vuruş): hemen başlat ve sona atla.
		if _win_tween != null and _win_tween.is_valid():
			_win_tween.kill()
		_play_win()
	if _win_tween != null and _win_tween.is_valid():
		_win_tween.kill()
	view.day_light.skip_win()


func is_win_playing() -> bool:
	return mode == Mode.WIN


func is_won() -> bool:
	return state != null and state.board.is_won()


# --- ipucu ve öğretim ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	wall_gauges.process(delta)
	panel_gauges.process(delta)
	if state == null:
		return
	if _inspect_left > 0.0:
		_inspect_left -= delta
		if _inspect_left <= 0.0:
			_set_inspect(0)
	if not _near_lines.is_empty() and mode != Mode.WIN and mode != Mode.DONE:
		_flicker_cooldown -= delta
		if _flicker_cooldown <= 0.0:
			_flicker(0.35)
	if mode == Mode.IDLE and state.board.is_planning():
		_idle += delta
		_update_tutorial()
		var wait: float = PULSE_IDLE_SECONDS if _tutorial == "pulse" and _plug_count == 0 else HINT_IDLE_SECONDS
		if _hint_left <= 0.0 and _idle >= wait:
			_show_hint()
	if _hint_left > 0.0:
		_hint_left -= delta
		if _hint_left <= 0.0:
			_end_hint()
			_idle = 0.0


func _update_tutorial() -> void:
	if finger == null:
		return
	if _tutorial != "drag" or _tutorial_done:
		if finger.is_playing():
			finger.stop()
		return
	var h: PrizHint = _solver.hint(state.board)
	if h.kind != PrizHint.PLACE:
		return
	var d: SliceDevice = devices.get(h.device_id, null) as SliceDevice
	if d == null or d.place != SliceDevice.Place.TRAY:
		return
	var to: Vector2 = screen_of_room_socket(state.room_socket_of(h.socket_id))
	finger.play(screen_of_device(h.device_id), to + Vector2(0.0, LIFT_PX))
	fx.set_halo(state.room_socket_of(h.socket_id), 1.0)


func _show_hint() -> void:
	var h: PrizHint = _solver.hint(state.board)
	_hint_left = HINT_SHOW_SECONDS
	if h.kind == PrizHint.PLACE:
		_hint_device = h.device_id
		_hint_socket = state.room_socket_of(h.socket_id)
		var d: SliceDevice = devices.get(h.device_id, null) as SliceDevice
		if d != null and d.place == SliceDevice.Place.TRAY:
			d.set_hint(true)
		fx.set_halo(_hint_socket, 1.6)
	elif h.kind == PrizHint.MOVE:
		_hint_device = h.device_id
		_hint_socket = state.plugged_room_socket(h.device_id)
		fx.set_halo(_hint_socket, 1.6)
		var d2: SliceDevice = devices.get(h.device_id, null) as SliceDevice
		if d2 != null:
			d2.appliance.set_mains(0.4)
	else:
		_hint_left = 0.0


func _end_hint() -> void:
	if _hint_device != "":
		var d: SliceDevice = devices.get(_hint_device, null) as SliceDevice
		if d != null:
			d.set_hint(false)
			d.appliance.set_mains(1.0)
	if _hint_socket != "" and mode != Mode.DRAG:
		fx.set_halo(_hint_socket, 0.0)
	_hint_device = ""
	_hint_socket = ""
	_hint_left = 0.0


# --- prob/çekim aracı için yüksek düzey sürücüler ----------------------------------------------

## Gerçek giriş yolundan sürükle-bırak: cihaza bas, prize sürükle, bırak. Sonuç kodu tahtadan.
func drag_device_to_socket(device_id: String, level_socket_id: String) -> StringName:
	var room_socket: String = state.room_socket_of(level_socket_id)
	var reason: StringName = state.board.can_plug(device_id, level_socket_id)
	press(screen_of_device(device_id))
	if mode != Mode.DRAG or _active_device != device_id:
		release(_press_pos)
		return PrizReason.UNKNOWN
	var to: Vector2 = screen_of_room_socket(room_socket) + Vector2(0.0, LIFT_PX)
	move(_press_pos.lerp(to, 0.5))
	move(to)
	release(to)
	return reason


## Takılı cihaza dokunmak (geri alma) — gerçek giriş yolundan.
func tap_device(device_id: String) -> void:
	var d: SliceDevice = devices.get(device_id, null) as SliceDevice
	if d == null:
		return
	var p: Vector2 = screen_of_device(device_id)
	press(p)
	release(p)


func all_settled() -> bool:
	for id: String in device_order:
		if (devices[id] as SliceDevice).is_busy():
			return false
	return mode == Mode.IDLE or mode == Mode.WIN or mode == Mode.DONE
