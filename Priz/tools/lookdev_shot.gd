extends SceneTree

## Görünüm sahnesinden ekran görüntüleri ve performans ölçümü (gerçek pencere gerekir; başsız
## modda çizim yoktur). İç çizim çözünürlüğü 1080x1920 (pencere küçük olabilir).
##
##   godot --path . -s res://tools/lookdev_shot.gd -- --out=build/shots
##   godot --path . -s res://tools/lookdev_shot.gd -- --only=slices|closeups|perf
##   godot --path . -s res://tools/lookdev_shot.gd -- --quality=high|medium|low
##   godot --headless --path . -s res://tools/lookdev_shot.gd -- --check   (başsız API dumanı → "SONUC: gecti")
##
## Çıktılar: slice_0_morning.png … slice_3_night.png, close_<cihaz>.png, close_fusebox.png,
## close_cable.png, contact_sheet.png ve stdout'ta PERF satırları. Sonda "LOOKDEV_DONE".

const SLICE_NAMES: PackedStringArray = ["morning", "noon", "evening", "night"]
## Dilim başına çalışan cihazlar (gece hepsi).
const SLICE_RUNNING: Array[PackedStringArray] = [
	["fridge", "kettle", "toaster"],
	["fridge", "washer", "fan"],
	["fridge", "oven", "tv", "lamp"],
	["fridge", "oven", "washer", "kettle", "toaster", "tv", "fan", "lamp"],
]
## Yakın plan: cihaz, dilim, uzaklık, yaw, pitch, odak kaydırma (dünya)
const CLOSEUPS: Array[Array] = [
	["fridge", 2, 2.9, 22.0, 12.0, Vector3(0.25, 0.95, 0.0)],
	["oven", 3, 1.7, 22.0, 16.0, Vector3(0.0, 0.42, 0.0)],
	["washer", 1, 1.6, 26.0, 14.0, Vector3(0.0, 0.42, 0.0)],
	["kettle", 0, 0.85, 28.0, 14.0, Vector3(0.0, 0.2, 0.0)],
	["toaster", 2, 0.9, 30.0, 26.0, Vector3(0.0, 0.14, 0.0)],
	["tv", 3, 1.9, 52.0, 10.0, Vector3(0.0, 0.32, 0.0)],
	["fan", 1, 2.1, 20.0, 12.0, Vector3(0.0, 0.7, 0.0)],
	["lamp", 3, 1.3, 30.0, 18.0, Vector3(0.0, 0.3, 0.0)],
]

var _out: String = "build/shots"
var _only: String = ""
var _quality: int = QualityTiers.Tier.HIGH
var _view: RoomView
var _lookdev: Node
var _shots: Array[String] = []
var _check: bool = false


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--only="):
			_only = arg.substr(7)
		elif arg == "--check":
			_check = true
		elif arg.begins_with("--quality="):
			_quality = maxi(0, QualityTiers.TIER_NAMES.find(arg.substr(10)))
	DirAccess.make_dir_recursive_absolute(_out)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = Vector2i(1080, 1920)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.unresizable = true
	root.size = Vector2i(540, 960)
	_lookdev = (load("res://scenes/lookdev/Lookdev.tscn") as PackedScene).instantiate()
	_lookdev.set("autoplay", false)
	# Fare/klavye görüntüyü etkilemesin (paralaks fare hareketiyle değişir)
	_lookdev.set_process_unhandled_input(false)
	root.add_child(_lookdev)
	_lookdev.set_process_unhandled_input(false)
	current_scene = _lookdev
	_view = _lookdev.get_node("RoomView") as RoomView
	_run()


func _run() -> void:
	await process_frame
	if _check:
		await _api_check()
		return
	_view.set_quality(_quality)
	print("lookdev_shot: kalite ", QualityTiers.TIER_NAMES[_quality])
	if _only == "" or _only == "slices":
		await _slices()
	if _only == "" or _only == "closeups":
		await _closeups()
	if _only == "" or _only == "events":
		await _events()
	if _only == "debug_noon":
		_set_running(PackedStringArray())
		_view.day_light.set_slice(1, 0.0)
		await _wait(0.5)
		_view.environment.ambient_light_energy = 0.0
		_view.fill.light_energy = 0.0
		_view.environment.background_mode = Environment.BG_COLOR
		_view.environment.background_color = Color.BLACK
		await _wait(0.5)
		_save("dbg_noon_sun_only")
	if _only == "fusebox":
		await _fusebox_only()
	if _only == "" or _only == "perf":
		await _perf()
	if _shots.size() > 1:
		_contact_sheet()
	print("LOOKDEV_DONE")
	quit(0)


func _slices() -> void:
	for s: int in range(4):
		_set_running(SLICE_RUNNING[s])
		_view.day_light.set_slice(s, 0.0)
		_lookdev.get("fuse_box").call("set_slice_dial", s, 0.0)
		_view.camera_rig.reset_view()
		await _wait(3.4)
		_save("slice_%d_%s" % [s, SLICE_NAMES[s]])


func _closeups() -> void:
	var appl: Dictionary = _lookdev.get("appliances") as Dictionary
	for c: Array in CLOSEUPS:
		var id: String = String(c[0])
		_set_running(PackedStringArray([id, "fridge"]))
		_view.day_light.set_slice(int(c[1]), 0.0)
		var a: Node3D = appl[id] as Node3D
		_view.camera_rig.frame_focus(a.global_position + (c[5] as Vector3), float(c[2]), float(c[3]), float(c[4]))
		await _wait(3.6)
		_save("close_%s" % id)
	# Sigorta kutusu (kısmen dolu göstergeler, bir hat taşmada)
	var fb: Node3D = _lookdev.get("fuse_box") as Node3D
	_set_running(PackedStringArray(["fridge", "oven", "washer", "kettle", "tv", "lamp"]))
	_view.day_light.set_slice(2, 0.0)
	_view.camera_rig.frame_focus(fb.global_position + Vector3(0.0, 0.0, 0.0), 1.25, 72.0, 6.0)
	await _wait(2.0)
	_save("close_fusebox")
	# Fiş + kablo
	_view.day_light.set_slice(1, 0.0)
	var hold: Vector3 = Vector3(4.55, 0.55, 3.45)
	_lookdev.call("hold_plug", hold, 35.0)
	_view.camera_rig.frame_focus(hold + Vector3(0.0, -0.2, 0.0), 1.35, 35.0, 18.0)
	await _wait(1.0)
	_save("close_cable")
	_view.camera_rig.yaw_deg = 42.0
	_view.camera_rig.pitch_deg = 31.0
	_view.camera_rig.reset_view()


func _fusebox_only() -> void:
	var fb: Node3D = _lookdev.get("fuse_box") as Node3D
	_set_running(PackedStringArray(["fridge", "oven", "washer", "kettle", "tv", "lamp"]))
	_view.day_light.set_slice(2, 0.0)
	_view.camera_rig.frame_focus(fb.global_position, 1.25, 72.0, 6.0)
	await _wait(2.0)
	_save("dbg_fusebox_a")
	for n: Node in fb.find_children("*Glass*", "", true, false):
		(n as Node3D).visible = false
	await _wait(0.5)
	_save("dbg_fusebox_b")


## Başsız duman testi: her kamu fonksiyonunu çağırır, birkaç kare ilerletir.
func _api_check() -> void:
	var appl: Dictionary = _lookdev.get("appliances") as Dictionary
	var fb: FuseBox = _lookdev.get("fuse_box") as FuseBox
	var ok: bool = appl.size() == 8 and fb != null and _view.get_socket_ids().size() == 7
	for id: String in _view.get_socket_ids():
		ok = ok and _view.line_of_socket(id) > 0 and _view.get_socket(id) != null
	for a_name: String in ["Anchor_Fridge", "Anchor_Oven", "Anchor_Washer", "Anchor_Kettle", "Anchor_Toaster", "Anchor_TV",
			"Anchor_Fan", "Anchor_Lamp", "Anchor_FuseBox"]:
		ok = ok and _view.get_anchor(a_name) != null
	for a: Appliance in appl.values():
		a.set_running(true, 0.05)
		ok = ok and a.get_plug_anchor() != null
	for s: int in range(4):
		_view.day_light.set_slice(s, 0.1)
		fb.set_slice_dial(s, 0.1)
		await _frames(8)
	for line: int in [1, 2, 3]:
		_view.set_line_glow(line, 1.0)
		_view.set_line_highlight(line, 1.0)
		_view.set_line_dim(line, 0.5)
		fb.set_line_capacity(line, 5)
		fb.set_line_fill(line, 1.2)
		fb.set_line_highlight(line, 1.0)
	_view.set_socket_highlight("Socket_01", 1.0)
	_view.set_socket_dim("Socket_02", 1.0)
	fb.trip(2)
	fb.set_breaker(2, true)
	fb.set_main_lever(true)
	_view.day_light.flicker(1.0, 0.2)
	_view.day_light.blackout(0.2)
	await _frames(40)
	_view.day_light.play_win(0.5)
	await _frames(10)
	_view.day_light.skip_win()
	_view.camera_rig.set_parallax(Vector2(0.5, -0.3))
	for t: int in [0, 1, 2]:
		_view.set_quality(t)
	for a: Appliance in appl.values():
		a.set_running(false, 0.05)
		ok = ok and a.is_running() == false
	await _frames(20)
	print("lookdev check: ", "tamam" if ok else "EKSİK")
	print("SONUC: gecti" if ok else "SONUC: basarisiz")
	quit(0 if ok else 1)


func _frames(n: int) -> void:
	for i: int in range(n):
		await process_frame


## Olay kancaları: sigorta atması (karartma), kazanma sahnesi (ortası ve sonu).
func _events() -> void:
	var fb: FuseBox = _lookdev.get("fuse_box") as FuseBox
	_set_running(SLICE_RUNNING[3])
	_view.day_light.set_slice(3, 0.0)
	_view.camera_rig.reset_view()
	await _wait(3.0)
	fb.trip(1)
	_view.day_light.blackout(1.2)
	await _wait(0.35)
	_save("event_blackout")
	await _wait(2.6)
	fb.set_breaker(1, true)
	fb.set_main_lever(true)
	_view.day_light.set_slice(2, 0.0)
	await _wait(0.5)
	_view.day_light.play_win(3.6)
	await _wait(1.6)
	_save("event_win_mid")
	await _wait(2.6)
	_save("event_win_end")
	_view.camera_rig.reset_view()


## Performans: tüm cihazlar açık, gece (en ağır dilim); 3 sn ortalama kare süresi + çizim istatistikleri.
func _perf() -> void:
	_set_running(SLICE_RUNNING[3])
	_view.day_light.set_slice(3, 0.0)
	_view.camera_rig.reset_view()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var vp_rid: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	await _wait(2.0)
	var cpu_ms: float = 0.0
	var gpu_ms: float = 0.0
	var frames: int = 0
	var t0: int = Time.get_ticks_usec()
	var worst: float = 0.0
	var last: int = t0
	while Time.get_ticks_usec() - t0 < 3000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		worst = maxf(worst, float(now - last) / 1000.0)
		last = now
		frames += 1
		cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(vp_rid)
		gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
	var avg_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0 / float(frames)
	print("PERF kalite=%s kare=%.2fms en_kotu=%.2fms fps=%.1f" % [QualityTiers.TIER_NAMES[_quality], avg_ms, worst,
		1000.0 / avg_ms])
	print("PERF olculen_cpu=%.2fms olculen_gpu=%.2fms (görüntü alanı ölçümü, dikey eşitleme kapalı)" % [
		cpu_ms / float(frames), gpu_ms / float(frames)])
	print("PERF cizim_cagrisi=%d nesne=%d ucgen=%d" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	print("PERF doku_bellek=%.1fMB video_bellek=%.1fMB tampon=%.1fMB" % [
		float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED)) / 1048576.0,
		float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)) / 1048576.0,
		float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED)) / 1048576.0])
	print("PERF monitor_ciz=%d monitor_ucgen=%d" % [
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))])


func _set_running(ids: PackedStringArray) -> void:
	var appl: Dictionary = _lookdev.get("appliances") as Dictionary
	for id: String in appl.keys():
		(appl[id] as Appliance).set_running(ids.has(id))


func _wait(seconds: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(seconds * 1000.0):
		await process_frame
	await RenderingServer.frame_post_draw


func _save(shot_name: String) -> void:
	var img: Image = root.get_texture().get_image()
	var path: String = _out.path_join(shot_name + ".png")
	img.save_png(path)
	_shots.append(path)
	print("SHOT ", path, " ", img.get_size())


func _contact_sheet() -> void:
	var cols: int = 4
	var tw: int = 270
	var th: int = 480
	var rows: int = int(ceil(float(_shots.size()) / float(cols)))
	var sheet: Image = Image.create(cols * tw, rows * th, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.1, 0.1, 0.1))
	for i: int in range(_shots.size()):
		var img: Image = Image.load_from_file(_shots[i])
		if img == null:
			continue
		img.convert(Image.FORMAT_RGB8)
		img.resize(tw, th, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(0, 0, tw, th), Vector2i((i % cols) * tw, (i / cols) * th))
	var path: String = _out.path_join("contact_sheet.png")
	sheet.save_png(path)
	print("SHOT ", path)
