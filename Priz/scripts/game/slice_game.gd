class_name SliceGame
extends Node3D
## Dikey kesitin oyun sahnesi: diorama (RoomView), duvardaki ve başparmak bölgesindeki sigorta kutusu,
## cihaz tepsisi, fiş sürükleme/mıknatıs/oturma, geri alma, hat inceleme, gerilim, katmanlı ses ve
## kazanma sahnesi. Kurallar `PrizBoard`da (SliceState üzerinden); burası yalnız canlandırır.
##
## Kabuk (scripts/ui/game.gd) bunu örnekler: `start_level(i)`, sinyal `level_won` (kazanma sahnesi bitti),
## `set_input_enabled(bool)`. Düz kip: kayıp yok.
## Gün kipi (aşama 3): planlamada dilim göstergeleri (DayGauges) ve cihaz şeritleri (DayStrips); tüm cihazlar
## takılınca kutunun kırmızı ana şalteri canlanır, çekilince (dokun ya da sürükle) `PrizBoard.start_day()`
## olayları `DayRun` çizelgesiyle oynatılır. Sigorta atarsa hak gider (`fuse_spent`), plan korunur; haklar
## biterse `day_lost`. Temiz gün → kazanma sahnesi → `level_won`. Ödüllü kancalar: `show_hint()`,
## `begin_preview()` (dilimleri elle gezme), `grant_extra_right()`, `restart_keep_plan()`.
## Prob/çekim için sürülebilir arayüz: `press/move/release(ekran)`, `drag_device_to_socket`,
## `tap_device`, `screen_of_device`, `screen_of_room_socket`, `screen_of_lever`, `pull_lever`, `skip_win`.

signal level_won
signal level_started(index: int)
## Gün testi başladı (ana şalter çekildi).
signal day_started
## Sigorta attı; kalan hak (rakamsız gösterilir: kutudaki cam sigortalar).
signal fuse_spent(rights_left: int)
## Haklar bitti: kabuk kayıp sayfasını açar (ek hak / tekrar / çık).
signal day_lost
## Gün testi bitti ve planlamaya dönüldü (sigorta attıktan sonra).
signal back_to_planning

enum Mode { IDLE, PRESS_TRAY, DRAG, PRESS_PLUGGED, PRESS_SOCKET, PARALLAX, PRESS_LEVER, DAY, PREVIEW, LOST, WIN,
	DONE }
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
const PANEL_CENTER: Vector2 = Vector2(215.0, 1505.0)
const PANEL_HEIGHT: float = 600.0
## Tepsi: sütun merkezleri, satır tabanları (alttan), yuva boyu (px).
const TRAY_COLUMNS: Array[float] = [535.0, 735.0, 935.0]
const TRAY_ROWS: Array[float] = [1520.0, 1830.0]
const SLOT_FIT: Vector2 = Vector2(150.0, 205.0)
const SLOT_DISC_PX: float = 92.0
const LINE_COLORS: Array[Color] = [Color(0.95, 0.4, 0.33), Color(0.33, 0.62, 0.95), Color(0.98, 0.78, 0.3)]
## Ana şalter: dokunma yarıçapı ve "çekildi" sayılan sürükleme boyu (px).
const LEVER_PICK_PX: float = 120.0
const LEVER_PULL_PX: float = 110.0
const LEVER_GLOW_SHADER: Shader = preload("res://scenes/game/lever_glow.gdshader")
## Sigorta atınca: karanlıkta plan ışığına geçiş ve gösterge kararması.
const BLOW_DARK_SECONDS: float = 1.35
## Ödüllü ipucu daha uzun görünür.
const PAID_HINT_SECONDS: float = 4.5
## Odadaki cihaz şeridi: genişlik (m) ve cihazın tepesinden yükseklik.
const ROOM_STRIP_WIDTH: float = 0.58
const ROOM_STRIP_LIFT: float = 0.2
## Büyük kutunun ana şalteri "açık"ta bu kadar iner (kol ekran altına taşmasın).
const PANEL_LEVER_ON: float = 0.55
## Tepsi şeridi cihaz tabanının bu kadar altında (px).
const TRAY_STRIP_DROP_PX: float = 46.0

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

# --- gün kipi ---
var day_gauges: DayGauges
var day_strips: DayStrips
var fuses: DayFuses
## Boşta otomatik ipucu (kabuk: yalnız sessiz dönemde; sonrası ödüllü ipucu).
var auto_hint: bool = true
var _run: DayRun
var _planning_slice: int = PrizSlice.MORNING
var _lever_live: bool = false
var _lever_node: Node3D
var _lever_glow: ShaderMaterial
var _lever_t: float = 0.0
var _lever_pulled_once: bool = false
var _fault_lines: Array[int] = []
var _fault_slice: int = -1
var _fault_devices: Array[String] = []
var _fault_t: float = 0.0
var _day_tension: float = 0.0
var _slice_loaded: bool = false
var _slice_near: bool = false
var _strip_tray_pos: Dictionary = {}  # cihaz kimliği -> tepsi şeridi merkezi (dünya)
var tray_fade: float = 0.0
var _preview_slice: int = -1
var _preview_bar: DayPreviewBar
var _bg_paused: bool = false


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
	# Gün kipi parçaları: hepsi baştan kurulur ve ısıtılır (ilk dilimde/sigortada takılma olmasın).
	day_gauges = DayGauges.new(panel_box)
	day_strips = DayStrips.new(view)
	fuses = DayFuses.new()
	fuses.name = "Fuses"
	var model: Node = panel_box.get_node_or_null("Model")
	(model if model != null else panel_box).add_child(fuses)
	_lever_node = panel_box.find_child("MainLever", true, false) as Node3D
	_lever_glow = ShaderMaterial.new()
	_lever_glow.shader = LEVER_GLOW_SHADER
	# Tepsi ışığı: gölgesiz, yalnız tepsi katmanını (SliceDevice.TRAY_LAYER) aydınlatır — kameranın sol
	# üstünden önden vuran yumuşak ışık; TV, vantilatör gibi koyu/ince modeller tepside okunur.
	var tray_light: DirectionalLight3D = DirectionalLight3D.new()
	tray_light.name = "TrayLight"
	tray_light.shadow_enabled = false
	tray_light.light_cull_mask = SliceDevice.TRAY_LAYER
	tray_light.light_energy = 0.75
	tray_light.light_color = Color(1.0, 0.95, 0.88)
	tray_light.light_specular = 0.6
	add_child(tray_light)
	var cam_b: Basis = view.camera_rig.camera.global_transform.basis
	tray_light.global_basis = Basis.looking_at(-(cam_b.z * 0.75 + cam_b.y * 0.45 - cam_b.x * 0.35).normalized(), Vector3.UP)
	get_viewport().size_changed.connect(_on_viewport_resized)


func _exit_tree() -> void:
	if _win_tween != null and _win_tween.is_valid():
		_win_tween.kill()
	_run = null


## Uygulama arka plana giderse gün testi bekler; dönünce kaldığı yerden sürer.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			_bg_paused = true
			if _run != null:
				_run.pause()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			_bg_paused = false
			if _run != null:
				_run.resume()


## Hayalet parmak katmanı (kabuk verir; 2B, 3B'nin üstünde).
func set_overlay(control: Control) -> void:
	finger = SliceFinger.new()
	finger.name = "GhostFinger"
	control.add_child(finger)
	_preview_bar = DayPreviewBar.new()
	_preview_bar.name = "DayPreviewBar"
	control.add_child(_preview_bar)
	_preview_bar.slice_chosen.connect(preview_slice)
	_preview_bar.closed.connect(end_preview)


func set_input_enabled(on: bool) -> void:
	_input_enabled = on
	if not on and (mode == Mode.DRAG or mode == Mode.PRESS_TRAY):
		_cancel_drag()
	if not on and mode == Mode.PRESS_LEVER:
		_release_lever(false)
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
	_planning_slice = level_time
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
	_setup_day_mode()
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
	_set_tray_fade(0.0)
	_setup_strips()
	_layout()
	_refresh_lines(false)
	audio.begin_level(level_time)
	var loops: Array[String] = []
	for id: String in device_order:
		loops.append((devices[id] as SliceDevice).loop_sound)
	audio.preload_sounds(loops)
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
	_run = null
	_preview_slice = -1
	_clear_fault()
	_set_lever_live(false)
	if _preview_bar != null:
		_preview_bar.close_bar()
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
		var strip_screen: Vector2 = _design_to_screen(Vector2(TRAY_COLUMNS[col] - 8.0, TRAY_ROWS[row] + TRAY_STRIP_DROP_PX))
		_strip_tray_pos[id] = _screen_to_world(strip_screen, THUMB_DEPTH - 0.9)
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
	if mode == Mode.DAY:
		# Dokunuş günü hızlandırır (sigortaya kadar).
		if _run != null and not _run.is_fast():
			_run.fast_forward()
			if _run.is_fast():
				audio.play("ui_soft")
				Haptics.tick()
		return
	if mode == Mode.PREVIEW:
		_scrub(p)
		return
	if mode != Mode.IDLE or state == null or not state.board.is_planning():
		return
	if is_day_mode() and p.distance_to(screen_of_lever()) < LEVER_PICK_PX:
		_press_lever()
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
		Mode.PRESS_LEVER:
			_drag_lever(p)
		Mode.PREVIEW:
			_scrub(p)
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
		Mode.PRESS_LEVER:
			_release_lever(true)
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
		day_gauges.clear_ghost()
		_highlight_gauge_line(0)
		if d != null:
			d.set_pip_tint(SliceDevice.PIP_COLOR)
		return
	if is_day_mode():
		_set_day_hover(d, socket_name)
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


## Gün kipi hayaleti: cihazın blokları YALNIZ çalıştığı dilimlerin tüplerinde belirir.
func _set_day_hover(d: SliceDevice, socket_name: String) -> void:
	var dp: Dictionary = state.day_preview(d.device_id, socket_name)
	var line: int = int(dp["line"])
	var ghost: Vector4 = dp["ghost"] as Vector4
	var amount: float = maxf(maxf(ghost.x, ghost.y), maxf(ghost.z, ghost.w))
	var over: bool = int(dp["overflow_mask"]) != 0
	day_gauges.set_ghost(line, amount, state.device_mask_at(d.device_id, socket_name), 0)
	_highlight_gauge_line(line)
	d.set_pip_tint(LINE_COLORS[line - 1] if not over else Color(1.0, 0.42, 0.3))
	if _accepting.has(socket_name):
		fx.set_halo(socket_name, 2.0)


func _highlight_gauge_line(line: int) -> void:
	day_gauges.set_highlight(line, line > 0)
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
	day_gauges.clear_ghost()
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
	_clear_fault()
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
	d.route_cable(view.get_socket(d.room_socket))
	if _runs_in_planning(d.device_id) and phase == Phase.PLAN and mode != Mode.PREVIEW:
		d.appliance.set_running(true)
		audio.device_on(d.device_id, d.loop_sound)
	if not is_day_mode() and state.board.is_won() and mode != Mode.WIN and mode != Mode.DONE:
		_begin_win()


## Takılı cihazı tepsiye döndürür (sınırsız geri alma).
func unplug(device_id: String) -> bool:
	var d: SliceDevice = devices.get(device_id, null) as SliceDevice
	if d == null or d.place != SliceDevice.Place.PLUGGED:
		return false
	var line: int = state.room_line_of(state.board.line_of_device(device_id))
	if not state.board.unplug(device_id):
		return false
	_clear_fault()
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
	day_gauges.set_highlight(line, true)
	for s: String in state.room_sockets():
		if state.room_line_of_room_socket(s) == line:
			fx.set_halo(s, 1.4)


func _set_inspect(line: int) -> void:
	if _inspect_line > 0 and line == 0:
		view.set_line_highlight(_inspect_line, 0.0)
		wall_box.set_line_highlight(_inspect_line, 0.0)
		panel_box.set_line_highlight(_inspect_line, 0.0)
		day_gauges.set_highlight(0, false)
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
	_refresh_day_gauges()
	_refresh_lever()
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
	day_strips.mmi.visible = false
	# Tepsi işini bitirdi: yavaşça kaybolur, sahne dioramaya kalır.
	var fade: Tween = create_tween()
	fade.tween_method(_set_tray_fade, 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE)


func _set_tray_fade(v: float) -> void:
	tray_fade = v
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


# --- gün kipi: kurulum ve planlama göstergeleri ---------------------------------------------------

func is_day_mode() -> bool:
	return state != null and state.is_day_mode()


func _setup_day_mode() -> void:
	if state.is_day_mode():
		var caps: Dictionary = {}
		for line: int in state.room_lines():
			caps[line] = state.capacity_at(line, PrizSlice.MORNING)
		day_gauges.enable(state.room_lines(), caps, state.max_capacity() + 1)
		day_gauges.set_power(1.0)
		day_gauges.set_focus(-1)
		fuses.visible = true
		fuses.set_rights(state.board.fuse_rights())
	else:
		if day_gauges.enabled:
			day_gauges.disable()
		fuses.visible = false
	_lever_pulled_once = false
	_set_lever_live(false)
	if state.is_day_mode():
		_prewarm_lever_glow()


## Şalter parıltısı gölgelendiricisi seviye açılışında bir kez görünmeden çizilir (ilk canlanışta takılma olmasın).
func _prewarm_lever_glow() -> void:
	var mi: MeshInstance3D = _lever_node as MeshInstance3D
	if mi == null or _lever_live:
		return
	_lever_glow.set_shader_parameter("strength", 0.0)
	mi.material_overlay = _lever_glow
	var t: Tween = create_tween()
	t.tween_interval(0.15)
	t.tween_callback(func() -> void:
		_lever_glow.set_shader_parameter("strength", 1.0)
		if not _lever_live:
			mi.material_overlay = null)


func _setup_strips() -> void:
	if not state.is_day_mode():
		day_strips.clear()
		return
	var masks: Array[int] = []
	for id: String in device_order:
		masks.append(state.device_mask(id))
	day_strips.setup(masks)
	day_strips.set_power(1.0)


## Şeritler: tepside cihazın önünde (blok genişliği göstergeyle aynı), odada cihazın üstünde.
func _update_strips() -> void:
	if day_strips.count == 0:
		return
	var col_w: float = day_gauges.column_world_width()
	var unit_w: float = DayGauges.unit_size(0.0).x
	for i: int in device_order.size():
		var d: SliceDevice = devices[device_order[i]] as SliceDevice
		match d.place:
			SliceDevice.Place.TRAY, SliceDevice.Place.DRAGGING:
				if _strip_tray_pos.has(d.device_id):
					day_strips.place(i, _strip_tray_pos[d.device_id] as Vector3, col_w * unit_w, _cam_basis)
				else:
					day_strips.hide(i)
			SliceDevice.Place.PLUGGED:
				var top: float = d.model_aabb.end.y * d.appliance.global_transform.basis.get_scale().y
				day_strips.place(i, d.appliance.global_position + Vector3.UP * (top + ROOM_STRIP_LIFT), ROOM_STRIP_WIDTH,
					_cam_basis)
			_:
				day_strips.hide(i)


func _refresh_day_gauges() -> void:
	if not is_day_mode():
		return
	for line: int in state.room_lines():
		day_gauges.set_loads(line, state.slice_loads(line), state.capacity_at(line, PrizSlice.MORNING))


## Planlamada cihaz çalışır mı: düz kipte takılıysa; gün kipinde takılı VE planlama dilimindeyse.
func _runs_in_planning(device_id: String) -> bool:
	if state.board.socket_of(device_id) == "":
		return false
	return not is_day_mode() or state.board.is_device_active(device_id, _planning_slice)


# --- ana şalter -------------------------------------------------------------------------------

func _set_lever_live(on: bool) -> void:
	var was: bool = _lever_live
	_lever_live = on
	var mi: MeshInstance3D = _lever_node as MeshInstance3D
	if mi != null:
		mi.material_overlay = _lever_glow if on else null
	if on and not was and state != null:
		# Hazır: kol hafifçe kalkıp iner, yumuşak tık (sesi kapalıyken de görünür).
		audio.play("socket_tick", 0.03)
		_lever_wiggle(-12.0)


func _refresh_lever() -> void:
	var live: bool = is_day_mode() and phase == Phase.PLAN and state.board.can_start_day() \
		and (mode == Mode.IDLE or mode == Mode.PRESS_LEVER)
	_set_lever_live(live)


func is_lever_live() -> bool:
	return _lever_live


## Kolun ekrandaki tutamak noktası (dokunma ve hayalet el).
func screen_of_lever() -> Vector2:
	var mi: MeshInstance3D = _lever_node as MeshInstance3D
	if mi == null:
		return Vector2(-1000.0, -1000.0)
	var aabb: AABB = mi.get_aabb()
	var grip: Vector3 = aabb.get_center()
	grip.z = aabb.end.z
	return _project(mi.global_transform * grip)


func _set_lever_angle(t: float) -> void:
	if _lever_node != null:
		_lever_node.rotation.x = deg_to_rad(lerpf(FuseBox.MAIN_OFF_DEG, FuseBox.MAIN_ON_DEG * PANEL_LEVER_ON, t))


func _lever_wiggle(deg: float) -> void:
	if _lever_node == null:
		return
	var off: float = deg_to_rad(FuseBox.MAIN_OFF_DEG)
	var t: Tween = create_tween()
	t.tween_property(_lever_node, "rotation:x", off + deg_to_rad(deg), 0.07).set_ease(Tween.EASE_OUT)
	t.tween_property(_lever_node, "rotation:x", off, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _press_lever() -> void:
	mode = Mode.PRESS_LEVER
	_lever_t = 0.0
	Haptics.tick()
	if _lever_live:
		audio.play("ui_soft")
	else:
		# Hazır değil: kol direnir, tepside bekleyen cihazlar zıplar ("önce hepsini tak").
		audio.play("plug_reject", 0.04)
		_lever_wiggle(10.0)
		for id: String in device_order:
			var d: SliceDevice = devices[id] as SliceDevice
			if d.place == SliceDevice.Place.TRAY:
				d.set_hint(true)
				var t: Tween = create_tween()
				t.tween_interval(0.7)
				t.tween_callback(d.set_hint.bind(false))


func _drag_lever(p: Vector2) -> void:
	if not _lever_live:
		return
	_lever_t = clampf((p.y - _press_pos.y) / LEVER_PULL_PX, 0.0, 1.0)
	_set_lever_angle(_lever_t)


func _release_lever(allow: bool) -> void:
	mode = Mode.IDLE
	var tapped: bool = _finger_pos.distance_to(_press_pos) < TAP_MOVE_PX * 2.0
	if allow and _lever_live and (tapped or _lever_t >= 0.55):
		pull_lever()
		return
	if _lever_live:
		var t: Tween = create_tween()
		t.tween_property(_lever_node, "rotation:x", deg_to_rad(FuseBox.MAIN_OFF_DEG), 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Günü başlatır (dokunuş, sürükleme ya da prob). Hazır değilse kol direnir; false döner.
func pull_lever() -> bool:
	if not is_day_mode() or not state.board.can_start_day() or phase != Phase.PLAN \
			or (mode != Mode.IDLE and mode != Mode.PRESS_LEVER):
		if mode == Mode.IDLE and is_day_mode():
			_press_lever()
			mode = Mode.IDLE
		return false
	_lever_pulled_once = true
	_tutorial_done = true
	if finger != null:
		finger.stop()
	_begin_day()
	return true


# --- gün testi ----------------------------------------------------------------------------------

func _begin_day() -> void:
	_end_hint()
	_set_inspect(0)
	_clear_fault()
	var events: Array[PrizEvent] = state.board.start_day()
	if events.is_empty():
		return
	_run = DayRun.new(events)
	if _bg_paused:
		_run.pause()
	phase = Phase.DAY
	mode = Mode.DAY
	_set_lever_live(false)
	day_started.emit()
	_apply_steps(_run.advance(0.0))


func is_day_running() -> bool:
	return _run != null


func day_run() -> DayRun:
	return _run


func _apply_steps(steps: Array[DayRun.Step]) -> void:
	for step: DayRun.Step in steps:
		_apply_step(step.event)
		if _run == null:
			return


func _time_k() -> float:
	return 1.0 / maxf(_run.time_scale(), 1.0) if _run != null else 1.0


func _apply_step(e: PrizEvent) -> void:
	match e.type:
		PrizEvent.DAY_START:
			_day_start()
		PrizEvent.SLICE_BEGIN:
			_day_slice(e.slice)
		PrizEvent.DEVICE_OFF:
			_day_device(e.device_id, false)
		PrizEvent.DEVICE_ON:
			_day_device(e.device_id, true)
		PrizEvent.LINE_LOAD:
			_day_line_load(e)
		PrizEvent.LINE_NEAR_LIMIT:
			_day_near()
		PrizEvent.FUSE_BLOWN:
			_day_blow(e)
		PrizEvent.BACK_TO_PLANNING:
			_day_end_blow(false)
		PrizEvent.LOSE:
			_day_end_blow(true)
		PrizEvent.DAY_SURVIVED:
			_day_survived()
		PrizEvent.WIN:
			_run = null
			_begin_win()
		_:
			pass


func _day_start() -> void:
	wall_box.set_main_lever(true)
	var from: float = _lever_node.rotation.x if _lever_node != null else 0.0
	panel_box.set_main_lever(true, false)
	if _lever_node != null:
		_lever_node.rotation.x = from
		var lt: Tween = create_tween()
		lt.tween_property(_lever_node, "rotation:x", deg_to_rad(FuseBox.MAIN_ON_DEG * PANEL_LEVER_ON), 0.16) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	audio.day_begin()
	_fade_tray(1.0)
	Haptics.thud()
	view.camera_rig.shake(0.5)
	# Şalter: her şey bir an susar, sonra sabahın cihazları tek tek açılır (neden-sonuç görünür).
	for id: String in device_order:
		var d: SliceDevice = devices[id] as SliceDevice
		d.appliance.set_running(false, 0.2)
		audio.device_off(id)
	for line: int in state.room_lines():
		wall_box.set_line_fill(line, 0.0)
		view.set_line_glow(line, 0.0)
	day_gauges.set_focus(-1)
	day_strips.set_focus(-1)
	_near_lines.clear()


func _day_slice(slice: int) -> void:
	var k: float = _time_k()
	_slice_loaded = false
	_slice_near = false
	_day_tension = 0.0
	view.day_light.set_slice(slice, 0.95 * k)
	for box: FuseBox in [wall_box, panel_box]:
		box.set_slice_dial(slice, 0.7 * k)
	audio.play("slice_transition", 0.03)
	audio.set_ambience(slice)
	day_gauges.set_focus(slice)
	day_gauges.reveal_hold()
	day_strips.set_focus(slice)
	Haptics.tick()


func _day_device(device_id: String, on: bool) -> void:
	var d: SliceDevice = devices.get(device_id, null) as SliceDevice
	if d == null:
		return
	d.appliance.set_running(on)
	if on:
		audio.device_on(device_id, d.loop_sound)
		if d.room_socket != "":
			fx.set_halo(d.room_socket, 1.2)
			var t: Tween = create_tween()
			t.tween_interval(0.35)
			t.tween_callback(fx.set_halo.bind(d.room_socket, 0.0))
	else:
		audio.device_off(device_id)


func _day_line_load(e: PrizEvent) -> void:
	var line: int = state.room_line_of(e.line_id)
	if not _slice_loaded:
		_slice_loaded = true
		day_gauges.reveal(0.35 * _time_k())
	wall_box.set_line_fill(line, e.fill)
	panel_box.set_line_fill(line, e.fill)
	view.set_line_glow(line, 0.0 if e.blocks <= 0 else 1.0 + 1.5 * smoothstep(0.75, 1.0, e.fill))
	_day_tension = maxf(_day_tension, e.fill)
	audio.set_tension(_day_tension)


func _day_near() -> void:
	if _slice_near:
		return
	_slice_near = true
	_flicker(0.85)


func _day_blow(e: PrizEvent) -> void:
	var line: int = state.room_line_of(e.line_id)
	for box: FuseBox in [wall_box, panel_box]:
		box.trip(line)
	day_gauges.set_fault(line, e.slice)
	day_gauges.set_dim(line, true)
	_fault_slice = e.slice
	if not _fault_lines.has(line):
		_fault_lines.append(line)
	for id: String in state.devices_on_line_at(line, e.slice):
		if not _fault_devices.has(id):
			_fault_devices.append(id)
	if _fault_lines.size() > 1:
		return  # aynı dilimde ikinci hat: yalnız şalteri iner, dram bir kez
	# "Çat": kıvılcım, anlık karanlık, cihazlar söner, sonra sessizlik.
	audio.fuse_blow()
	Haptics.thud()
	view.camera_rig.shake(1.0)
	var breaker: Node3D = panel_box.find_child("Breaker_%d" % line, true, false) as Node3D
	if breaker != null:
		fx.seat_burst(breaker.global_position, panel_box.global_basis.z.normalized(), Color(1.0, 0.55, 0.25))
	fuses.set_rights(e.rights, true)
	view.day_light.blackout(BLOW_DARK_SECONDS)
	for id: String in device_order:
		(devices[id] as SliceDevice).appliance.set_running(false, 0.5)
	for l: int in state.room_lines():
		view.set_line_glow(l, 0.0)
		wall_box.set_line_fill(l, 0.0)
	day_gauges.set_power(0.1)
	day_strips.set_power(0.1)
	fuse_spent.emit(e.rights)
	# Karanlıkta plan ışığına geçilir; ışık geri geldiğinde oda planlamadadır.
	var t: Tween = create_tween()
	t.tween_interval(BLOW_DARK_SECONDS * 0.8)
	t.tween_callback(func() -> void:
		view.day_light.set_slice(_planning_slice, 0.0)
		for box: FuseBox in [wall_box, panel_box]:
			box.set_slice_dial(_planning_slice, 0.0))
	t.tween_interval(BLOW_DARK_SECONDS * 0.4)
	t.tween_callback(func() -> void:
		day_gauges.set_power(1.0)
		day_strips.set_power(1.0))


## Sigortadan sonra: şalterler yeniden kalkar, oda planlamaya döner, neden işaretli kalır.
func _day_end_blow(lost: bool) -> void:
	_run = null
	phase = Phase.PLAN
	for line: int in _fault_lines:
		day_gauges.set_dim(line, false)
		for box: FuseBox in [wall_box, panel_box]:
			box.set_breaker(line, true)
	audio.play("breaker_flip", 0.03)
	for box: FuseBox in [wall_box, panel_box]:
		box.set_main_lever(false)
	_resume_planning_scene()
	_show_fault()
	if lost:
		mode = Mode.LOST
		var t: Tween = create_tween()
		t.tween_interval(0.6)
		t.tween_callback(func() -> void:
			if mode == Mode.LOST:
				day_lost.emit())
	else:
		mode = Mode.IDLE
		_refresh_lever()
		back_to_planning.emit()


func _day_survived() -> void:
	for line: int in state.room_lines():
		view.set_line_glow(line, 1.4)
	day_gauges.set_focus(-1)
	day_strips.set_focus(-1)
	audio.play_pitched("window_light", 1.4, -4.0)
	Haptics.tick()


## Plan ışığı, planlama diliminin cihazları, müzik, tepsi; göstergeler tüm günü yeniden gösterir.
func _resume_planning_scene() -> void:
	view.day_light.set_slice(_planning_slice, 0.6)
	for box: FuseBox in [wall_box, panel_box]:
		box.set_slice_dial(_planning_slice, 0.6)
	day_gauges.set_focus(-1)
	day_gauges.reveal(0.0)
	day_strips.set_focus(-1)
	audio.resume_planning(_planning_slice)
	_fade_tray(0.0)
	for id: String in device_order:
		var d: SliceDevice = devices[id] as SliceDevice
		var run: bool = _runs_in_planning(id)
		d.appliance.set_running(run)
		if run:
			audio.device_on(id, d.loop_sound)
		else:
			audio.device_off(id)
	_refresh_lines(false)


func _show_fault() -> void:
	_fault_t = 0.0
	for i: int in device_order.size():
		if _fault_devices.has(device_order[i]):
			day_strips.set_fault(i, _fault_slice)
			var d: SliceDevice = devices[device_order[i]] as SliceDevice
			d.nudge()
			if d.room_socket != "":
				fx.set_halo(d.room_socket, 1.5)


func _clear_fault() -> void:
	if day_gauges != null:
		day_gauges.clear_fault()
	if day_strips != null:
		day_strips.clear_fault()
	for line: int in _fault_lines:
		view.set_line_highlight(line, 0.0)
	if not _fault_devices.is_empty() and fx != null and mode != Mode.DRAG:
		fx.clear_halos()
	_fault_lines.clear()
	_fault_devices.clear()
	_fault_slice = -1


## Sigortanın attığı hat/dilim ve o anda çalışan cihazlar (prob/çekim).
func fault_info() -> Dictionary:
	return {"lines": _fault_lines.duplicate(), "slice": _fault_slice, "devices": _fault_devices.duplicate()}


## Ödüllü "+1 sigorta": kayıptan planlamaya döner, plan korunur, yeni cam sigorta yuvasına kayar.
func grant_extra_right() -> void:
	if state == null or not is_day_mode():
		return
	state.board.grant_extra_right()
	fuses.set_rights(state.board.fuse_rights(), true)
	audio.play("breaker_flip", 0.03)
	Haptics.tick()
	phase = Phase.PLAN
	mode = Mode.IDLE
	_refresh_lever()


## Tekrar dene (plan korunur): seviye baştan kurulur, haklar dolar, cihazlar aynı prizlere anında takılır.
func restart_keep_plan() -> void:
	var plan: Dictionary = state.board.placement() if state != null else {}
	start_level(level_index, 0.6)
	_apply_plan_instant(plan)


func _apply_plan_instant(plan: Dictionary) -> void:
	for key: Variant in plan.keys():
		var device_id: String = str(key)
		var sid: String = str(plan[key])
		if state.board.plug(device_id, sid) != PrizReason.OK:
			continue
		var d: SliceDevice = devices.get(device_id, null) as SliceDevice
		var sock: String = state.room_socket_of(sid)
		if d == null or sock == "":
			continue
		d.room_socket = sock
		d.snap_plugged(view.get_socket(sock).global_transform)
		d.route_cable(view.get_socket(sock))
		d.set_pips_full(false, 0.0)
		tray.set_slot_empty(int(_slot_of[device_id]), true)
		_plug_count += 1
		if _runs_in_planning(device_id):
			d.appliance.set_running(true, 0.0)
			audio.device_on(device_id, d.loop_sound)
	_refresh_lines(false)


# --- gün önizleme (ödüllü): dilimleri elle gezme ------------------------------------------------

func can_preview() -> bool:
	return is_day_mode() and mode == Mode.IDLE and phase == Phase.PLAN and state.board.is_planning()


func begin_preview() -> bool:
	if not can_preview():
		return false
	_end_hint()
	_set_inspect(0)
	mode = Mode.PREVIEW
	if _preview_bar != null:
		_preview_bar.open_bar()
	_fade_tray(1.0)
	preview_slice(PrizSlice.MORNING)
	return true


func is_previewing() -> bool:
	return mode == Mode.PREVIEW


func preview_slice(slice: int) -> void:
	if mode != Mode.PREVIEW or slice == _preview_slice:
		return
	_preview_slice = clampi(slice, 0, PrizSlice.COUNT - 1)
	if _preview_bar != null:
		_preview_bar.set_current(_preview_slice)
	view.day_light.set_slice(_preview_slice, 0.55)
	for box: FuseBox in [wall_box, panel_box]:
		box.set_slice_dial(_preview_slice, 0.45)
	audio.play("slice_transition", 0.03)
	audio.set_ambience(_preview_slice)
	Haptics.tick()
	for id: String in device_order:
		var d: SliceDevice = devices[id] as SliceDevice
		var run: bool = state.board.socket_of(id) != "" and state.board.is_device_active(id, _preview_slice)
		d.appliance.set_running(run)
		if run:
			audio.device_on(id, d.loop_sound)
		else:
			audio.device_off(id)
	for line: int in state.room_lines():
		var cap: int = state.capacity_at(line, _preview_slice)
		var blocks: int = state.load_at(line, _preview_slice)
		var f: float = float(blocks) / float(maxi(cap, 1)) if cap > 0 else (2.0 if blocks > 0 else 0.0)
		wall_box.set_line_fill(line, f)
		view.set_line_glow(line, 0.0 if blocks <= 0 else 1.0 + 1.5 * smoothstep(0.75, 1.0, f))
	audio.set_tension(state.tension_at(_preview_slice))
	day_gauges.set_focus(_preview_slice)
	day_gauges.reveal(0.3)
	day_strips.set_focus(_preview_slice)
	if state.tension_at(_preview_slice) >= PrizBoard.NEAR_LIMIT_FILL:
		_flicker(0.6)


func preview_index() -> int:
	return _preview_slice


func end_preview() -> void:
	if mode != Mode.PREVIEW:
		return
	if _preview_bar != null:
		_preview_bar.close_bar()
	_preview_slice = -1
	mode = Mode.IDLE
	_fade_tray(0.0)
	_resume_planning_scene()


func _scrub(p: Vector2) -> void:
	var w: float = get_viewport().get_visible_rect().size.x
	preview_slice(clampi(int(p.x / maxf(w, 1.0) * 4.0), 0, 3))


func _fade_tray(target: float) -> void:
	var t: Tween = create_tween()
	t.tween_method(_set_tray_fade, tray_fade, target, 0.3).set_trans(Tween.TRANS_SINE)


## Ödüllü ipucu: cihaz ve doğru prizi daha uzun süre atar.
func show_hint() -> void:
	if state == null or not state.board.is_planning() or mode != Mode.IDLE:
		return
	_show_hint()
	if _hint_left > 0.0:
		_hint_left = PAID_HINT_SECONDS


# --- ipucu ve öğretim ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	wall_gauges.process(delta)
	panel_gauges.process(delta)
	if state == null:
		return
	if _run != null:
		_apply_steps(_run.advance(delta))
		if _run != null and _run.is_finished():
			_run = null
	_update_strips()
	if not _fault_lines.is_empty() and mode == Mode.IDLE:
		_fault_t += delta
		var v: float = 0.45 + 0.4 * sin(_fault_t * 5.0)
		for line: int in _fault_lines:
			view.set_line_highlight(line, v)
	if _inspect_left > 0.0:
		_inspect_left -= delta
		if _inspect_left <= 0.0:
			_set_inspect(0)
	if not _near_lines.is_empty() and phase == Phase.PLAN and (mode == Mode.IDLE or mode == Mode.DRAG):
		_flicker_cooldown -= delta
		if _flicker_cooldown <= 0.0:
			_flicker(0.35)
	if mode == Mode.IDLE and state.board.is_planning():
		_idle += delta
		_update_tutorial()
		var wait: float = PULSE_IDLE_SECONDS if _tutorial == "pulse" and _plug_count == 0 else HINT_IDLE_SECONDS
		if auto_hint and _hint_left <= 0.0 and _idle >= wait:
			_show_hint()
	if _hint_left > 0.0:
		_hint_left -= delta
		if _hint_left <= 0.0:
			_end_hint()
			_idle = 0.0


func _update_tutorial() -> void:
	if finger == null:
		return
	if _tutorial == "lever":
		# İlk gün seviyesi: her şey takılınca hayalet el kolu aşağı çeker (bir kez çekilene dek).
		if _lever_live and not _lever_pulled_once:
			var g: Vector2 = screen_of_lever()
			finger.play(g + Vector2(0.0, -20.0), g + Vector2(0.0, LEVER_PULL_PX * 0.8))
		elif finger.is_playing():
			finger.stop()
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
