extends SceneTree

## Dikey kesit çekim aracı (GERÇEK pencere ister; başsız modda çizim yoktur). Oyun sahnesini (Game.tscn)
## sahte parmakla oynar ve `build/shots/slice/` altına kare yazar. İç çizim 1080x1920 sabittir.
##
##   godot --path . -s res://tools/slice_shot.gd                       # tüm kareler + PERF satırları
##   godot --path . -s res://tools/slice_shot.gd -- --only=win          # yalnız bir bölüm (start|drag|reject|full|win|perf)
##   godot --path . --write-movie build/shots/slice/priz_slice.avi --fixed-fps 30 -s res://tools/slice_shot.gd -- --video
## Aşama 3 (gün kipi) kareleri `build/shots/day/` altına:
##   godot --path . -s res://tools/slice_shot.gd -- --only=day         # planlama, sürükleme, dört dilim, sigorta,
##                                                                      # kayıp, kazanma, önizleme, şalter öğretimi
##   godot --path . -s res://tools/slice_shot.gd -- --only=dayperf     # gün koşarken ölçüm (PERF satırları)
##   godot --path . --write-movie build/shots/day/priz_day.avi --fixed-fps 30 -s res://tools/slice_shot.gd -- --dayvideo
##
## Sert zaman aşımıyla çalıştırılmalı (öndeki başka pencere çizimi askıya alabilir; macOS Metal kapanışı
## bazen asılır): çağıran, "SLICE_SHOT_DONE" satırını görünce ya da süre dolunca KENDİ PID'ini öldürür.
## Oyuncunun kaydına ASLA yazmaz (persist=false).

const OUT_DIR: String = "build/shots/slice"
const DAY_DIR: String = "build/shots/day"
const WATCHDOG_SECONDS: float = 150.0

var _game: Node
var _slice: Node
var _only: String = ""
var _video: bool = false
var _day_video: bool = false
var _out: String = OUT_DIR
var _frames_dir: String = ""
var _frame_no: int = 0
var _touch: TouchDot
var _elapsed: float = 0.0
var _done: bool = false


## Videoda sahte parmağın görünür izi (yarı saydam disk).
class TouchDot extends Control:
	var pos: Vector2 = Vector2(-500.0, -500.0)
	var down: bool = false
	var alpha: float = 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _process(delta: float) -> void:
		alpha = move_toward(alpha, 1.0 if down else 0.0, delta * 6.0)
		queue_redraw()

	func _draw() -> void:
		if alpha <= 0.0:
			return
		draw_circle(pos, 44.0, Color(1, 1, 1, 0.28 * alpha))
		draw_arc(pos, 44.0, 0.0, TAU, 48, Color(1, 1, 1, 0.7 * alpha), 4.0, true)


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			_only = arg.substr(7)
		elif arg == "--video":
			_video = true
		elif arg == "--dayvideo":
			_day_video = true
		elif arg.begins_with("--frames="):
			# Tam çözünürlüklü video: her karede iç çizim (1080x1920) JPG olarak yazılır (`--fixed-fps 30` ile
			# çalıştır; --write-movie pencere boyutunda kaydeder). Sonra ffmpeg ile mp4.
			_frames_dir = arg.substr(9)
			DirAccess.make_dir_recursive_absolute(_frames_dir)
	root.get_node("Progress").set("persist", false)
	AnalyticsLog.echo = false
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(DAY_DIR)
	# build/ içe aktarılmasın (kareler .import üretmesin).
	if not FileAccess.file_exists("build/.gdignore"):
		FileAccess.open("build/.gdignore", FileAccess.WRITE).close()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_size = Vector2i(1080, 1920)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(540, 960)
	_run.call_deferred()


func _process(delta: float) -> bool:
	_elapsed += delta
	if _frames_dir != "" and not _done and _game != null:
		var img: Image = root.get_texture().get_image()
		img.save_jpg("%s/f_%05d.jpg" % [_frames_dir, _frame_no], 0.9)
		_frame_no += 1
	if not _done and _elapsed > WATCHDOG_SECONDS and not _video and not _day_video and not _only.begins_with("day") and _only != "blowperf":
		print("SLICE_SHOT zaman aşımı")
		_finish()
	return false


func _finish() -> void:
	if _done:
		return
	_done = true
	print("SLICE_SHOT_DONE")
	quit(0)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _save(shot_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	img.save_png("%s/%s.png" % [_out, shot_name])
	print("SLICE_SHOT ", shot_name)


func _open_game(level: int) -> void:
	if _game != null:
		_game.queue_free()
		await process_frame
	var progress: Node = root.get_node("Progress")
	progress.call("reset_state")
	(progress.get("data") as ProgressData).level = level
	_game = (load("res://scenes/Game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game
	_slice = _game.get_node("Slice")
	if _touch == null or not is_instance_valid(_touch):
		_touch = TouchDot.new()
		var layer: CanvasLayer = CanvasLayer.new()
		layer.layer = 50
		root.add_child(layer)
		layer.add_child(_touch)


func _run() -> void:
	await process_frame
	if _video:
		await _video_run()
		_finish()
		return
	if _day_video:
		_out = DAY_DIR
		await _day_video_run()
		_finish()
		return
	if _only == "day":
		_out = DAY_DIR
		await _day_shots()
		_finish()
		return
	if _only == "dayperf":
		_out = DAY_DIR
		await _day_perf()
		_finish()
		return
	if _only == "blowperf":
		_out = DAY_DIR
		await _blow_perf()
		_finish()
		return
	if _only == "" or _only == "start":
		await _shots_start()
	if _only == "" or _only == "drag":
		await _shots_drag()
	if _only == "" or _only == "reject":
		await _shots_reject()
	if _only == "" or _only == "full":
		await _shots_full()
	if _only == "" or _only == "win":
		await _shots_win()
	if _only == "" or _only == "perf":
		await _perf()
	_finish()


# --- parmak --------------------------------------------------------------------------------

## Gerçek giriş yolu: SliceGame.press/move/release (dokunma olaylarının gittiği yer).
func _finger_drag(from: Vector2, to: Vector2, seconds: float, release_at_end: bool = true) -> void:
	_touch.down = true
	_touch.pos = from
	_slice.call("press", from)
	var steps: int = maxi(int(seconds * 30.0), 2)
	for i: int in range(1, steps + 1):
		var t: float = float(i) / float(steps)
		var e: float = t * t * (3.0 - 2.0 * t)
		var p: Vector2 = from.lerp(to, e) + Vector2(0.0, -sin(t * PI) * 90.0)
		_touch.pos = p
		_slice.call("move", p)
		await process_frame
	if release_at_end:
		_slice.call("release", to)
		_touch.down = false


func _tap(p: Vector2) -> void:
	_touch.down = true
	_touch.pos = p
	_slice.call("press", p)
	await _wait(0.12)
	_slice.call("release", p)
	_touch.down = false


func _plan() -> Dictionary:
	var st: SliceState = _slice.get("state") as SliceState
	return PrizSolver.new().first_solution(st.level, PrizContent.load_default().registry)


func _socket_target(level_socket: String) -> Vector2:
	var st: SliceState = _slice.get("state") as SliceState
	var room: String = st.room_socket_of(level_socket)
	return (_slice.call("screen_of_room_socket", room) as Vector2) + Vector2(0.0, float(SliceGame.LIFT_PX))


func _drag_to(device_id: String, level_socket: String, seconds: float = 0.7) -> void:
	var from: Vector2 = _slice.call("screen_of_device", device_id) as Vector2
	await _finger_drag(from, _socket_target(level_socket), seconds)


# --- bölümler ------------------------------------------------------------------------------

func _shots_start() -> void:
	await _open_game(1)
	await _wait(2.2)
	await _save("01_level1_start")
	await _wait(0.9)
	await _save("02_level1_ghost_finger")


func _shots_drag() -> void:
	await _open_game(2)
	await _wait(1.6)
	var plan: Dictionary = _plan()
	var st: SliceState = _slice.get("state") as SliceState
	var dev: String = st.device_ids()[0]
	var from: Vector2 = _slice.call("screen_of_device", dev) as Vector2
	var mid: Vector2 = from.lerp(_socket_target(str(plan[dev])), 0.55) + Vector2(60.0, 0.0)
	await _finger_drag(from, mid, 0.5, false)
	await _wait(0.25)
	await _save("03_mid_drag_glowing_sockets")
	# Prizin yakınına: mıknatıs + hayalet bloklar
	var near: Vector2 = _socket_target(str(plan[dev])) + Vector2(45.0, 35.0)
	_slice.call("move", near)
	_touch.pos = near
	await _wait(0.3)
	await _save("04_magnet_ghost_blocks")
	_slice.call("release", _socket_target(str(plan[dev])))
	_touch.down = false
	await _wait(0.1)
	await _save("05_seat_moment")
	await _wait(0.25)
	await _save("06_seat_travel")
	await _wait(1.2)
	await _save("07_running_after_seat")


func _shots_reject() -> void:
	await _open_game(2)
	await _wait(1.2)
	var st: SliceState = _slice.get("state") as SliceState
	var tv: String = _type(st, "tv")
	var toaster: String = _type(st, "toaster")
	await _drag_to(tv, st.level_socket_at("Socket_01"))
	await _wait(1.2)
	var from: Vector2 = _slice.call("screen_of_device", toaster) as Vector2
	await _finger_drag(from, _socket_target(st.level_socket_at("Socket_02")), 0.6, false)
	await _wait(0.2)
	await _save("08_overflow_preview")
	_slice.call("release", _socket_target(st.level_socket_at("Socket_02")))
	_touch.down = false
	await _wait(0.16)
	await _save("09_rejected_plug")


func _shots_full() -> void:
	await _open_game(7)
	await _wait(1.0)
	var plan: Dictionary = _plan()
	var ids: Array = plan.keys()
	for i: int in range(ids.size() - 1):
		await _drag_to(str(ids[i]), str(plan[ids[i]]), 0.45)
		await _wait(0.75)
	await _wait(1.6)
	await _save("10_mostly_full_running")


func _shots_win() -> void:
	await _open_game(3)
	await _wait(1.0)
	var plan: Dictionary = _plan()
	for id: Variant in plan.keys():
		await _drag_to(str(id), str(plan[id]), 0.5)
		await _wait(0.8)
	var marks: Array[float] = [0.2, 0.9, 1.6, 2.4, 3.2, 4.4]
	var last: float = 0.0
	for i: int in marks.size():
		await _wait(marks[i] - last)
		last = marks[i]
		await _save("11_win_%d" % i)
	await _wait(2.2)
	await _save("12_result_sheet")


## Tüm cihazlar çalışırken ölçüm (kesit 7: altı cihaz; kalan ikisi de odaya eklenir ki sekizi çalışsın).
func _perf() -> void:
	await _open_game(7)
	await _wait(1.0)
	var plan: Dictionary = _plan()
	var ids: Array = plan.keys()
	var plug_ms: Array[float] = []
	for i: int in range(ids.size() - 1):
		var t0: int = Time.get_ticks_usec()
		await _drag_to(str(ids[i]), str(plan[ids[i]]), 0.3)
		await process_frame
		plug_ms.append(float(Time.get_ticks_usec() - t0) / 1000.0)
		await _wait(0.8)
	# Kesitte olmayan iki cihazı da odada çalıştır (sekiz cihaz birden).
	var view: RoomView = _slice.get("view") as RoomView
	var data: SliceData = _slice.get("data") as SliceData
	var st: SliceState = _slice.get("state") as SliceState
	for type: String in data.appliance_types():
		if _type(st, type) != "":
			continue
		var script: GDScript = load(str(data.appliance(type)["fx"])) as GDScript
		var a: Appliance = script.new() as Appliance
		view.place_at_anchor(a, str(data.appliance(type)["anchor"]))
		a.set_running(true)
	await _wait(2.5)
	await _save("13_perf_all_eight")
	var times: Array[float] = []
	var worst_plug: float = 0.0
	var last: int = Time.get_ticks_usec()
	# Son cihazı ölçüm penceresinde tak (takılma anı kare süresi).
	var from: Vector2 = _slice.call("screen_of_device", str(ids[ids.size() - 1])) as Vector2
	_slice.call("press", from)
	for i: int in range(240):
		await process_frame
		var now: int = Time.get_ticks_usec()
		var ms: float = float(now - last) / 1000.0
		times.append(ms)
		last = now
		if i == 60:
			var to: Vector2 = _socket_target(str(plan[ids[ids.size() - 1]]))
			_slice.call("move", to)
			_slice.call("release", to)
		if i >= 60 and i < 90:
			worst_plug = maxf(worst_plug, ms)
	times.sort()
	var total: float = 0.0
	for v: float in times:
		total += v
	print("PERF kare ms: ort=%.2f p50=%.2f p99=%.2f en_kotu=%.2f takma_anı_en_kotu=%.2f" % [total / times.size(),
		times[times.size() / 2], times[int(times.size() * 0.99)], times[times.size() - 1], worst_plug])
	print("PERF çizim çağrısı=%d nesne=%d ilkel(üçgen)=%d" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	print("PERF fps=%d düğüm=%d bellek_video_MB=%.1f" % [int(Performance.get_monitor(Performance.TIME_FPS)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)) / 1048576.0])


## Video: seviye 1 → 2, sahte parmakla (yaklaşık 25 sn). --write-movie ile sabit kare hızında çalışır.
func _video_run() -> void:
	await _open_game(1)
	await _wait(2.6)
	var plan: Dictionary = _plan()
	var ids: Array = plan.keys()
	await _drag_to(str(ids[0]), str(plan[ids[0]]), 1.0)
	await _wait(1.4)
	# Hat incele
	var st: SliceState = _slice.get("state") as SliceState
	await _tap(_slice.call("screen_of_room_socket", st.room_socket_of(str(plan[ids[0]]))) as Vector2)
	await _wait(0.9)
	await _drag_to(str(ids[1]), str(plan[ids[1]]), 0.9)
	await _wait(5.2)
	_game.call("_on_continue_pressed")
	await _wait(2.4)
	# Seviye 2: bir ret, bir geri alma, sonra çözüm
	st = _slice.get("state") as SliceState
	var tv: String = _type(st, "tv")
	var toaster: String = _type(st, "toaster")
	await _drag_to(tv, st.level_socket_at("Socket_01"), 0.8)
	await _wait(0.9)
	await _drag_to(toaster, st.level_socket_at("Socket_02"), 0.8)
	await _wait(1.0)
	await _tap(_slice.call("screen_of_device", tv) as Vector2)
	await _wait(1.0)
	plan = _plan()
	for id: Variant in plan.keys():
		await _drag_to(str(id), str(plan[id]), 0.7)
		await _wait(0.8)
	await _wait(5.0)


func _type(st: SliceState, type: String) -> String:
	for device: PrizDevice in st.level.devices:
		if device.type == type:
			return device.id
	return ""


# --- aşama 3: gün kipi --------------------------------------------------------------------------

func _day_index(n: int) -> int:
	# n: kesitteki gün seviyesi sırası (0 = ilk gün seviyesi). Dönüş: oyuncu seviyesi (1 tabanlı).
	var data: SliceData = SliceData.load_default()
	var first: int = 0
	while first < data.level_count() and not data.load_level(first).is_day_mode():
		first += 1
	return first + n + 1


func _bad_plan_of(st: SliceState) -> Dictionary:
	var board: PrizBoard = PrizBoard.new(st.level, PrizContent.load_default().registry)
	return _dfs_bad(board, st.device_ids(), 0)


func _dfs_bad(board: PrizBoard, ids: Array[String], k: int) -> Dictionary:
	if k == ids.size():
		return board.placement() if not board.overflows().is_empty() else {}
	for socket: PrizSocket in board.level.sockets:
		if board.can_plug(ids[k], socket.id) != PrizReason.OK:
			continue
		board.plug(ids[k], socket.id)
		var found: Dictionary = _dfs_bad(board, ids, k + 1)
		board.unplug(ids[k])
		if not found.is_empty():
			return found
	return {}


func _apply_plan(plan: Dictionary, seconds: float, pause: float) -> void:
	var st: SliceState = _slice.get("state") as SliceState
	for id: String in st.device_ids():
		var cur: String = st.board.socket_of(id)
		if cur != "" and cur != str(plan.get(id, "")):
			await _tap(_slice.call("screen_of_device", id) as Vector2)
			await _wait(pause)
	for key: Variant in plan.keys():
		if st.board.socket_of(str(key)) == str(plan[key]):
			continue
		await _drag_to(str(key), str(plan[key]), seconds)
		await _wait(pause)


func _pull_lever(drag: bool = true) -> void:
	var g: Vector2 = _slice.call("screen_of_lever") as Vector2
	if drag:
		await _finger_drag(g, g + Vector2(0.0, 130.0), 0.35)
	else:
		await _tap(g)


func _run_slice_time() -> float:
	var run: DayRun = _slice.call("day_run") as DayRun
	return run.clock if run != null else -1.0


func _wait_clock(t: float) -> void:
	var guard: int = 0
	while guard < 2000:
		var run: DayRun = _slice.call("day_run") as DayRun
		if run == null or run.clock >= t:
			return
		await process_frame
		guard += 1


func _day_shots() -> void:
	# 1) Şalter öğretimi (ilk gün seviyesi): her şey takılı, hayalet el kolu çeker.
	await _open_game(_day_index(0))
	await _wait(1.4)
	await _save("d00_first_day_level_plan")
	var plan: Dictionary = _plan()
	await _apply_plan(plan, 0.45, 0.7)
	await _wait(1.2)
	await _save("d01_lever_live_ghost_hand")
	# 2) Planlama göstergeleri ve şeritler (gerçek bir gün, yarım plan) + sürükleme hayaleti
	await _open_game(_day_index(2))
	await _wait(1.2)
	plan = _plan()
	var ids: Array = plan.keys()
	for i: int in range(ids.size() - 2):
		await _drag_to(str(ids[i]), str(plan[ids[i]]), 0.4)
		await _wait(0.6)
	await _wait(1.0)
	await _save("d02_planning_gauges_strips")
	var dev: String = str(ids[ids.size() - 2])
	var from: Vector2 = _slice.call("screen_of_device", dev) as Vector2
	var target: Vector2 = _socket_target(str(plan[dev]))
	await _finger_drag(from, target + Vector2(30.0, 25.0), 0.6, false)
	await _wait(0.35)
	await _save("d03_drag_slice_ghost")
	_slice.call("release", target)
	_touch.down = false
	await _wait(1.0)
	# Taşan hayalet: son cihazı yanlış (dolu) hatta tut
	var st: SliceState = _slice.get("state") as SliceState
	var last: String = str(ids[ids.size() - 1])
	var bad_sock: String = ""
	for socket: PrizSocket in st.level.sockets:
		if st.board.can_plug(last, socket.id) != PrizReason.OK:
			continue
		var dp: Dictionary = st.day_preview(last, st.room_socket_of(socket.id))
		if int(dp["overflow_mask"]) != 0:
			bad_sock = socket.id
			break
	if bad_sock != "":
		from = _slice.call("screen_of_device", last) as Vector2
		await _finger_drag(from, _socket_target(bad_sock) + Vector2(30.0, 25.0), 0.6, false)
		await _wait(0.35)
		await _save("d04_drag_overflow_ghost")
		_slice.call("release", _socket_target(bad_sock))
		_touch.down = false
		await _wait(1.0)
		await _save("d05_overflow_allowed_in_planning")
	# 3) Temiz gün: dört dilim ortası
	await _apply_plan(plan, 0.4, 0.6)
	await _wait(0.8)
	await _pull_lever()
	var mids: Array[String] = ["d06_slice_morning", "d07_slice_noon", "d08_slice_evening", "d09_slice_night"]
	for s: int in 4:
		await _wait_clock(DayRun.LEAD + DayRun.SLICE_SECONDS * float(s) + 1.25)
		await _save(mids[s])
	await _wait(1.6)
	await _save("d10_win_lights")
	await _wait(1.2)
	await _save("d11_win_pullback")
	await _wait(4.2)
	await _save("d12_result_stars")
	# 4) Sınıra yakın titreme + sigorta atması dizisi + neden + yanık sigorta
	await _open_game(_day_index(1))
	await _wait(1.0)
	st = _slice.get("state") as SliceState
	var bad: Dictionary = _bad_plan_of(st)
	await _apply_plan(bad, 0.4, 0.6)
	await _wait(1.0)
	await _save("d13_bad_plan_overflow_marked")
	await _pull_lever(false)
	var run: DayRun = _slice.call("day_run") as DayRun
	var blow_t: float = 0.0
	for step: DayRun.Step in run.steps:
		if step.event.type == PrizEvent.FUSE_BLOWN:
			blow_t = step.time
			break
	await _wait_clock(blow_t - 0.25)
	await _save("d14_before_blow_tension")
	await _wait_clock(blow_t + 0.03)
	await _save("d15_blow_crack")
	await _wait_clock(blow_t + 0.6)
	await _save("d16_blackout")
	await _wait_clock(blow_t + DayRun.BLOW_SECONDS - 0.2)
	await _save("d17_return_blackout_recover")
	await _wait(0.9)
	await _save("d18_cause_indicated_burnt_fuse")
	# 5) Kayıp: iki atma daha
	for n: int in 2:
		await _pull_lever(false)
		await _wait(0.2)
		var r: DayRun = _slice.call("day_run") as DayRun
		while r != null and _slice.call("is_day_running"):
			await process_frame
	await _wait(1.6)
	await _save("d19_lose_sheet")
	# 6) Gün önizleme (ödüllü)
	await _open_game(_day_index(4))
	await _wait(1.0)
	await _apply_plan(_plan(), 0.35, 0.5)
	await _wait(0.8)
	_slice.call("begin_preview")
	await _wait(0.9)
	await _save("d20_preview_morning")
	_slice.call("preview_slice", 2)
	await _wait(1.0)
	await _save("d21_preview_evening")
	_slice.call("end_preview")
	await _wait(0.6)
	# 7) Sınıra yakın: her dilimde dolu bir plan (ilk çözüm) gece ışığında
	await _save("d22_back_from_preview")


## Gün koşarken ölçüm: en çok cihazlı gün seviyesi, temiz plan, tüm cihazlar açıkken (ve kalanlar odada).
func _day_perf() -> void:
	await _open_game(_day_index(7))
	await _wait(1.0)
	await _apply_plan(_plan(), 0.3, 0.5)
	var view: RoomView = _slice.get("view") as RoomView
	var data: SliceData = _slice.get("data") as SliceData
	var st: SliceState = _slice.get("state") as SliceState
	await _wait(0.8)
	await _pull_lever(false)
	# Akşam dilimi (en çok cihaz) içinde ölç; kalan iki tür de odada çalışsın (sekiz cihaz).
	await _wait_clock(DayRun.LEAD + DayRun.SLICE_SECONDS * 2.0 + 0.5)
	var run: DayRun = _slice.call("day_run") as DayRun
	run.pause()
	for type: String in data.appliance_types():
		if _type(st, type) != "":
			continue
		var script: GDScript = load(str(data.appliance(type)["fx"])) as GDScript
		var a: Appliance = script.new() as Appliance
		view.place_at_anchor(a, str(data.appliance(type)["anchor"]))
		a.set_running(true)
	for id: String in st.device_ids():
		((_slice.get("devices") as Dictionary)[id] as SliceDevice).appliance.set_running(true)
	await _wait(1.5)
	await _save("d30_perf_running_day_all_on")
	var times: Array[float] = []
	var last: int = Time.get_ticks_usec()
	for i: int in range(240):
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		last = now
	times.sort()
	var total: float = 0.0
	for v: float in times:
		total += v
	print("PERF gün kare ms: ort=%.2f p50=%.2f p99=%.2f en_kotu=%.2f" % [total / times.size(), times[times.size() / 2],
		times[int(times.size() * 0.99)], times[times.size() - 1]])
	print("PERF gün çizim çağrısı=%d nesne=%d ilkel(üçgen)=%d" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
	# Sigorta anı ve ilk dilim geçişi takılıyor mu: gün sürerken kare süreleri.
	run.resume()
	var worst: float = 0.0
	last = Time.get_ticks_usec()
	while _slice.call("is_day_running"):
		await process_frame
		var now2: int = Time.get_ticks_usec()
		worst = maxf(worst, float(now2 - last) / 1000.0)
		last = now2
	print("PERF gün sonu dilim geçişleri en kötü kare ms=%.2f" % worst)
	await _blow_perf()


## İlk sigorta atması: taşan planla gün; ilk dilim ve atma/karartma boyunca en kötü kare.
func _blow_perf() -> void:
	var st: SliceState
	var last: int = 0
	await _open_game(_day_index(1))
	await _wait(1.0)
	st = _slice.get("state") as SliceState
	await _apply_plan(_bad_plan_of(st), 0.3, 0.5)
	await _wait(0.8)
	var first_slice_worst: float = 0.0
	var blow_worst: float = 0.0
	await _pull_lever(false)
	last = Time.get_ticks_usec()
	while _slice.call("is_day_running"):
		await process_frame
		var now3: int = Time.get_ticks_usec()
		var ms3: float = float(now3 - last) / 1000.0
		last = now3
		var r3: DayRun = _slice.call("day_run") as DayRun
		if r3 == null:
			break
		if r3.current_slice() == 0:
			first_slice_worst = maxf(first_slice_worst, ms3)
		if r3.blow_slice() >= 0 and r3.current_slice() == r3.blow_slice():
			blow_worst = maxf(blow_worst, ms3)
	print("PERF ilk dilim en kötü kare ms=%.2f, sigorta atması/karartma en kötü kare ms=%.2f" % [first_slice_worst,
		blow_worst])


## Video (~35 sn): ikinci gün seviyesi — taşan plan, şalter, sigorta, neden; düzelt, temiz gün, kazanma.
func _day_video_run() -> void:
	await _open_game(_day_index(1))
	await _wait(1.6)
	var st: SliceState = _slice.get("state") as SliceState
	var bad: Dictionary = _bad_plan_of(st)
	await _apply_plan(bad, 0.8, 0.9)
	await _wait(1.4)
	await _pull_lever()
	while _slice.call("is_day_running"):
		await process_frame
	await _wait(2.2)
	# Düzelt: neden olan cihazı diğer hatta taşı
	await _apply_plan(_plan(), 0.8, 1.0)
	await _wait(1.2)
	await _pull_lever()
	while _slice.call("is_day_running"):
		await process_frame
	await _wait(6.5)
