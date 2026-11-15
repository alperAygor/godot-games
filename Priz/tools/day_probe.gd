extends SceneTree

## Gün kipi probu (başsız, aşama 3): GERÇEK Game sahnesinde kesitin her gün seviyesini oynar. Sürüş gerçek
## giriş yolundandır (SliceGame.press/move/release; ana şalter de dokunuşla çekilir). Denetlenenler:
##  * planlamada dilim göstergeleri (hat başına dört tüp) ve cihaz şeritleri TAHTAYLA birebir aynı,
##  * sürüklerken hayalet bloklar YALNIZ cihazın çalıştığı dilimlerde,
##  * ana şalter yalnız tüm cihazlar takılınca canlı; erken çekiş günü başlatmaz,
##  * temiz gün → dilimler sırayla (odak sütunu = dilim) → kazanma → sonuç sayfası (yıldız = kalan sigorta),
##  * bilerek taşan plan → sigorta → plana dönüş, PLAN KORUNUR, cam sigortalardan biri yanık, neden işaretli
##    → düzelt → kazan,
##  * üç atma → kayıp sayfası (+1 sigorta düğmesi var) → ek hak → plana dönüş → düzelt → kazan,
##  * kayıpta "tekrar dene" planı korur; ödüllü ipucu ve gün önizleme kancaları,
##  * dokunuş hızlandırır, duraklatma (sayfa) ve arka plan günü dondurur, gün ortasında sahne yeniden
##    yüklenir (dil değişimi yolu) ve sahne silinince ses katmanı/çizelge sızmaz.
##   godot --headless --path . -s res://tools/day_probe.gd      çıkış 0 + "PROBE SONUC: gecti"
## NOT: `-s` betiği autoload'lardan ÖNCE derlenir: autoload'a değen sınıflar tür olarak anılmaz.

const WATCHDOG_SECONDS: float = 175.0
const WAIT_SECONDS: float = 14.0
## Başsız koşuyu hızlandırır (çizelge ve aralar ölçeklenir; sıra aynı).
const TIME_SCALE: float = 3.0

var _progress: Node = null
var _audio: Node = null
var _game: Node = null
var _failed: bool = false
var _finished: bool = false
var _elapsed: float = 0.0
var _content: PrizContent
var _solver: PrizSolver = PrizSolver.new()
var _day_from: int = 0


class InstantProvider extends AdsProvider:
	func is_ready(_placement: int) -> bool:
		return true

	func show(placement: int) -> void:
		shown.emit()
		if placement == INTERSTITIAL_PLACEMENT:
			dismissed.emit()
		else:
			rewarded.emit()


func _initialize() -> void:
	_progress = root.get_node("Progress")
	_progress.set("persist", false)
	AnalyticsLog.echo = false
	AnalyticsLog.clear()
	_audio = root.get_node("AudioService")
	_run.call_deferred()


func _process(delta: float) -> bool:
	_elapsed += delta / maxf(Engine.time_scale, 1.0)
	if not _finished and _elapsed > WATCHDOG_SECONDS:
		_check(false, "zaman aşımı (%d sn)" % int(WATCHDOG_SECONDS))
		_finish()
	return false


func _finish() -> void:
	if _finished:
		return
	_finished = true
	Engine.time_scale = 1.0
	print("PROBE SONUC: %s" % ("kaldi" if _failed else "gecti"))
	quit(1 if _failed else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		printerr("PROBE HATA: %s" % message)


func _until(condition: Callable, seconds: float = WAIT_SECONDS) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while not bool(condition.call()):
		if Time.get_ticks_msec() > deadline:
			return false
		await process_frame
	return true


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _slice() -> SliceGame:
	return _game.get_node("Slice") as SliceGame


func _run() -> void:
	await process_frame
	_progress.call("reset_state")
	root.get_node("AdManager").call("set_provider", InstantProvider.new())
	_content = PrizContent.load_default()
	var data: SliceData = SliceData.load_default()
	while _day_from < data.level_count() and not data.load_level(_day_from).is_day_mode():
		_day_from += 1
	_check(_day_from < data.level_count(), "gün seviyesi yok")
	_check(data.level_count() - _day_from >= 6, "en az altı gün seviyesi")
	(_progress.get("data") as ProgressData).level = _day_from + 1
	Engine.time_scale = TIME_SCALE
	_game = (load("res://scenes/Game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game
	await process_frame
	await process_frame
	var count: int = data.level_count() - _day_from
	for k: int in range(count):
		var i: int = _day_from + k
		match k:
			0:
				await _play(i, "temiz")          # öğretim: tek kısmi cihaz, hayalet el şalterde
			1:
				await _play(i, "bir_atma")       # aha: önce taşan plan → sigorta → düzelt
			2:
				await _play(i, "uc_atma")        # üç atma → kayıp → ek hak → düzelt
			3:
				await _play(i, "tekrar")         # üç atma → kayıp → tekrar dene (plan korunur)
			4:
				await _play(i, "onizleme")       # ödüllü önizleme + ipucu, sonra temiz
			_:
				await _play(i, "temiz")
		if _failed:
			break
	if not _failed:
		await _reload_mid_day()
	# Sahne silinince katmanlar ve çizelge sızmamalı.
	Engine.time_scale = 1.0
	if _game != null and is_instance_valid(_game):
		_game.queue_free()
	await _wait(0.9)
	var loops: Array = _audio.call("loop_ids") as Array
	_check(loops.is_empty(), "sahneden çıkınca ses katmanı kalmamalı: %s" % str(loops))
	_check(not paused, "ağaç duraklatılmış kalmamalı")
	print("PROBE gün: %d seviye oynandı" % count)
	_finish()


# --- yardımcılar ------------------------------------------------------------------------------

func _plan(st: SliceState) -> Dictionary:
	return _solver.first_solution(st.level, _content.registry)


## Bütün cihazlar takılı ama en az bir dilimde taşan plan (kurallara uygun).
func _bad_plan(st: SliceState) -> Dictionary:
	var board: PrizBoard = PrizBoard.new(st.level, _content.registry)
	var ids: Array[String] = st.device_ids()
	return _dfs_bad(board, ids, 0)


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


## Planı gerçek sürükle-bırakla uygular: farklı yerdekileri önce tepsiye alır, sonra takar.
func _apply(slice: SliceGame, plan: Dictionary, tag: String) -> void:
	var st: SliceState = slice.state
	for id: String in st.device_ids():
		var cur: String = st.board.socket_of(id)
		if cur != "" and cur != str(plan.get(id, "")):
			slice.tap_device(id)
			_check(st.board.socket_of(id) == "", "%s: dokununca %s tepsiye dönmeli" % [tag, id])
			await _until(func() -> bool: return slice.all_settled())
	for key: Variant in plan.keys():
		var id2: String = str(key)
		if st.board.socket_of(id2) == str(plan[key]):
			continue
		var r: StringName = slice.drag_device_to_socket(id2, str(plan[key]))
		_check(r == PrizReason.OK, "%s: %s takılmalı (%s)" % [tag, id2, r])
		await _until(func() -> bool: return slice.all_settled())
	_check(st.board.placement() == plan, "%s: plan tahtada" % tag)


## Göstergeler ve şeritler tahtayla aynı mı (dilim başına blok, kapasite, cihaz maskeleri).
func _check_gauges(slice: SliceGame, tag: String) -> void:
	var st: SliceState = slice.state
	_check(slice.day_gauges.enabled, "%s: gün göstergeleri açık" % tag)
	for line: int in st.room_lines():
		var shown: Vector4 = slice.day_gauges.loads_of(line)
		_check(shown == st.slice_loads(line), "%s: hat %d dilim yükleri %s ≠ tahta %s" % [tag, line, shown,
			st.slice_loads(line)])
		for s: int in PrizSlice.COUNT:
			_check(int(shown[s]) == st.board.line_load(st.level_line_at(line), s), "%s: hat %d dilim %d" % [tag, line, s])
		_check(slice.day_gauges.capacity_of(line) == st.capacity_at(line, 0), "%s: hat %d kapasite" % [tag, line])
	for i: int in st.device_ids().size():
		var id: String = slice.device_order[i]
		_check(slice.day_strips.mask_of(i) == st.device_mask(id), "%s: %s şeridi" % [tag, id])


## Sürüklerken hayalet: yalnız cihazın dilimlerinde (bırakmadan önce bakılır, sonra iptal).
func _check_ghost(slice: SliceGame, tag: String) -> void:
	var st: SliceState = slice.state
	for id: String in st.device_ids():
		if st.board.socket_of(id) != "":
			continue
		var sock: String = st.room_sockets()[0]
		var from: Vector2 = slice.screen_of_device(id)
		slice.press(from)
		if slice.mode != SliceGame.Mode.DRAG:
			slice.release(from)
			continue
		var to: Vector2 = slice.screen_of_room_socket(sock) + Vector2(0.0, SliceGame.LIFT_PX + 30.0)
		slice.move(from.lerp(to, 0.5))
		slice.move(to)
		var line: int = st.room_line_of_room_socket(sock)
		var gh: Vector2 = slice.day_gauges.ghost_of(line)
		_check(int(gh.y) == st.device_mask_at(id, sock), "%s: hayalet maskesi = cihazın dilimleri" % tag)
		_check(int(gh.x) == st.device_blocks(id), "%s: hayalet blok = cihaz yükü" % tag)
		slice.move(Vector2(420.0, 1120.0))
		slice.release(Vector2(420.0, 1120.0))
		await _until(func() -> bool: return slice.all_settled())
		_check(st.board.socket_of(id) == "", "%s: boşa bırakılan fiş tepsiye döner" % tag)
		return


## Şalteri gerçek dokunuşla çeker; gün koşusunu bitene dek izler. Dönüş: sonuç türü.
func _run_day(slice: SliceGame, tag: String, fast: bool) -> StringName:
	_check(slice.is_lever_live(), "%s: şalter canlı olmalı" % tag)
	var lever: Vector2 = slice.screen_of_lever()
	slice.press(lever)
	slice.release(lever)
	_check(slice.is_day_running(), "%s: dokunuş günü başlatmalı" % tag)
	if not slice.is_day_running():
		return &""
	var run: DayRun = slice.day_run()
	var outcome: StringName = run.outcome()
	var last_slice: int = -1
	var order_ok: bool = true
	var tapped: bool = false
	while slice.is_day_running():
		await process_frame
		var cur: int = run.current_slice()
		if cur != last_slice and cur >= 0:
			order_ok = order_ok and cur == last_slice + 1
			last_slice = cur
			if slice.day_gauges.focus() != cur and slice.mode == SliceGame.Mode.DAY:
				_check(false, "%s: odak sütunu dilimi izlemeli (%d/%d)" % [tag, slice.day_gauges.focus(), cur])
		if fast and not tapped and cur >= 0:
			tapped = true
			slice.press(Vector2(540.0, 700.0))
			slice.release(Vector2(540.0, 700.0))
			_check(run.is_fast() or run.clock >= DayRun.LEAD + DayRun.SLICE_SECONDS * 4.0 or run.blow_slice() >= 0,
				"%s: dokunuş hızlandırmalı" % tag)
	_check(order_ok, "%s: dilimler sırayla" % tag)
	if outcome == PrizEvent.WIN:
		_check(last_slice == PrizSlice.NIGHT, "%s: dört dilim oynandı" % tag)
	return outcome


## Sigorta → plana dönüş denetimi (plan korunur, bir cam sigorta yanık, neden işaretli).
func _after_blow(slice: SliceGame, plan_before: Dictionary, rights_before: int, tag: String) -> void:
	var st: SliceState = slice.state
	_check(st.board.placement() == plan_before, "%s: PLAN KORUNMALI" % tag)
	_check(st.board.fuse_rights() == rights_before - 1, "%s: bir hak gitmeli" % tag)
	_check(slice.fuses.rights() == st.board.fuse_rights(), "%s: kutudaki sağlam sigorta = hak" % tag)
	_check(slice.fuses.is_burnt(rights_before - 1), "%s: bir cam sigorta yanık" % tag)
	var info: Dictionary = slice.fault_info()
	_check(not (info["lines"] as Array).is_empty(), "%s: atan hat işaretli" % tag)
	_check(int(info["slice"]) >= 0, "%s: atan dilim işaretli" % tag)
	_check(not (info["devices"] as Array).is_empty(), "%s: o an çalışan cihazlar işaretli" % tag)
	for line: Variant in info["lines"] as Array:
		_check(slice.day_gauges.fault_of(int(line)) == int(info["slice"]), "%s: göstergede neden sütunu" % tag)
	_check(int(_progress.call("fuses_left")) == st.board.fuse_rights(), "%s: kabuk hak sayacı aynı" % tag)


func _finish_win(slice: SliceGame, tag: String, stars: int) -> void:
	_check(await _until(func() -> bool: return slice.mode == SliceGame.Mode.WIN or slice.mode == SliceGame.Mode.DONE),
		"%s: kazanma sahnesi" % tag)
	await _wait(0.6)
	slice.press(Vector2(540.0, 900.0))
	slice.release(Vector2(540.0, 900.0))
	var shown: bool = await _until(func() -> bool: return _game.get("_overlay") != null)
	_check(shown, "%s: sonuç sayfası çıkmalı" % tag)
	if not shown:
		return
	var sheet: Control = _game.get("_overlay") as Control
	var pips: Node = sheet.find_child("StarPips", true, false)
	_check(pips != null, "%s: yıldız noktaları" % tag)
	_check(int(_progress.call("stars_for", int(_game.get("_level_number")))) == stars,
		"%s: yıldız = kalan sigorta (%d)" % [tag, stars])
	var st: SliceState = slice.state
	sheet.emit_signal(&"continue_pressed")
	await _until(func() -> bool:
		return _game.get("_overlay") == null and slice.state != st and slice.mode == SliceGame.Mode.IDLE)


# --- seviye senaryoları -----------------------------------------------------------------------

func _play(i: int, kind: String) -> void:
	var slice: SliceGame = _slice()
	var tag: String = "gün seviyesi %d (%s)" % [i + 1, kind]
	_check(slice.level_index == i, "%s: kesit dizini %d" % [tag, slice.level_index])
	var st: SliceState = slice.state
	_check(st.is_day_mode(), "%s: gün kipi" % tag)
	_check(slice.fuses.visible and slice.fuses.rights() == 3, "%s: üç cam sigorta" % tag)
	_check(not slice.is_lever_live(), "%s: boş planda şalter ölü" % tag)
	_check(not slice.pull_lever(), "%s: erken çekiş günü başlatmaz" % tag)
	_check(not slice.is_day_running(), "%s: gün başlamadı" % tag)
	_check_gauges(slice, tag)
	await _check_ghost(slice, tag)
	var good: Dictionary = _plan(st)
	_check(not good.is_empty(), "%s: çözüm var" % tag)
	match kind:
		"temiz":
			await _apply(slice, good, tag)
			_check_gauges(slice, tag + " takılı")
			if i == _day_from:
				_check(slice.finger != null and slice.finger.is_playing() or not slice.is_lever_live(),
					"%s: ilk gün seviyesinde hayalet el şalteri gösterir" % tag)
			_check(await _run_day(slice, tag, i % 2 == 1) == PrizEvent.WIN, "%s: temiz gün kazanır" % tag)
			await _finish_win(slice, tag, 3)
		"bir_atma":
			var bad: Dictionary = _bad_plan(st)
			_check(not bad.is_empty(), "%s: taşan plan bulunmalı" % tag)
			await _apply(slice, bad, tag + " taşan")
			_check_gauges(slice, tag + " taşan")
			var over: bool = false
			for line: int in st.room_lines():
				over = over or st.overflow_mask(line) != 0
			_check(over, "%s: planlamada taşma görünür (izinli)" % tag)
			_check(await _run_day(slice, tag, true) == PrizEvent.BACK_TO_PLANNING, "%s: sigorta atmalı" % tag)
			await _until(func() -> bool: return slice.mode == SliceGame.Mode.IDLE)
			await _after_blow(slice, bad, 3, tag)
			_check_gauges(slice, tag + " sonrası")
			await _apply(slice, good, tag + " düzelt")
			_check((slice.fault_info()["lines"] as Array).is_empty(), "%s: plan değişince neden işareti kalkar" % tag)
			_check(await _run_day(slice, tag, false) == PrizEvent.WIN, "%s: düzeltince kazanır" % tag)
			await _finish_win(slice, tag, 2)
		"uc_atma", "tekrar":
			var bad2: Dictionary = _bad_plan(st)
			await _apply(slice, bad2, tag + " taşan")
			for n: int in 3:
				var rights: int = st.board.fuse_rights()
				var out: StringName = await _run_day(slice, "%s atma %d" % [tag, n + 1], true)
				if n < 2:
					_check(out == PrizEvent.BACK_TO_PLANNING, "%s: %d. atma plana döner" % [tag, n + 1])
					await _until(func() -> bool: return slice.mode == SliceGame.Mode.IDLE)
					await _after_blow(slice, bad2, rights, tag)
				else:
					_check(out == PrizEvent.LOSE, "%s: üçüncü atma kaybettirir" % tag)
			var lost: bool = await _until(func() -> bool: return _game.get("_overlay") != null)
			_check(lost, "%s: kayıp sayfası" % tag)
			if not lost:
				return
			_check(st.board.is_lost() and st.board.placement() == bad2, "%s: kayıpta plan durur" % tag)
			_check(slice.fuses.rights() == 0, "%s: üç sigorta da yanık" % tag)
			var sheet: Control = _game.get("_overlay") as Control
			_check(sheet.find_child("ReviveButton", true, false) != null, "%s: +1 sigorta sunulur" % tag)
			_check(sheet.find_child("RetryButton", true, false) != null, "%s: tekrar dene" % tag)
			_check(sheet.find_child("HomeButton", true, false) != null, "%s: çık" % tag)
			if kind == "uc_atma":
				sheet.emit_signal(&"revive_pressed")
				await _until(func() -> bool: return _game.get("_overlay") == null)
				_check(st.board.is_planning() and st.board.fuse_rights() == 1, "%s: ek hak plana döner" % tag)
				_check(st.board.placement() == bad2, "%s: ek hakta plan korunur" % tag)
				await _until(func() -> bool: return slice.fuses.rights() == 1)
				await _apply(slice, good, tag + " düzelt")
				_check(await _run_day(slice, tag, true) == PrizEvent.WIN, "%s: ek hakla kazanır" % tag)
				await _finish_win(slice, tag, 1)
			else:
				sheet.emit_signal(&"retry_pressed")
				await _until(func() -> bool: return _game.get("_overlay") == null)
				var st2: SliceState = slice.state
				_check(st2.board.placement() == bad2, "%s: tekrar dene planı korur" % tag)
				_check(st2.board.fuse_rights() == 3 and slice.fuses.rights() == 3, "%s: haklar dolar" % tag)
				_check(slice.is_lever_live(), "%s: plan tam, şalter canlı" % tag)
				await _apply(slice, good, tag + " düzelt")
				await _pause_and_background(slice, tag)
				await _finish_win(slice, tag, 3)
		"onizleme":
			await _apply(slice, good, tag)
			_check(_game.get("_preview_button") != null, "%s: önizleme düğmesi" % tag)
			_game.call("_refresh_offers")
			_check((_game.get("_preview_button") as Control).visible, "%s: önizleme sunulur" % tag)
			_check((_game.get("_hint_button") as Control).visible, "%s: ipucu sunulur" % tag)
			_game.call("_on_preview_pressed")
			_check(await _until(func() -> bool: return slice.is_previewing()), "%s: önizleme açıldı" % tag)
			for s: int in [2, 3, 0]:
				slice.preview_slice(s)
				await _wait(0.3)
				for id: String in st.device_ids():
					var dev: SliceDevice = slice.devices[id] as SliceDevice
					_check(dev.appliance.is_running() == st.board.is_device_active(id, s),
						"%s: önizleme dilim %d — %s çalışma durumu" % [tag, s, id])
				_check(slice.day_gauges.focus() == s, "%s: önizlemede odak sütunu" % tag)
			slice.end_preview()
			_check(slice.mode == SliceGame.Mode.IDLE and not slice.is_previewing(), "%s: önizleme kapanır" % tag)
			_check(st.board.is_planning() and st.board.days_run() == 0, "%s: önizleme günü saymaz" % tag)
			slice.tap_device(st.device_ids()[0])
			await _until(func() -> bool: return slice.all_settled())
			_game.call("_on_hint_pressed")
			_check(await _until(func() -> bool: return float(slice.get("_hint_left")) > 0.0),
				"%s: ödüllü ipucu gösterilir" % tag)
			await _apply(slice, good, tag + " ipucu sonrası")
			_check(await _run_day(slice, tag, true) == PrizEvent.WIN, "%s: kazanır" % tag)
			await _finish_win(slice, tag, 3)
	print("PROBE %s tamam" % tag)


## Gün ortasında duraklatma sayfası ve arka plan: çizelge ilerlemez; dönünce sürer ve kazanır.
func _pause_and_background(slice: SliceGame, tag: String) -> void:
	var lever: Vector2 = slice.screen_of_lever()
	slice.press(lever)
	slice.release(lever)
	_check(slice.is_day_running(), "%s: gün başladı" % tag)
	await _wait(0.6)
	var run: DayRun = slice.day_run()
	_game.call("_on_pause_requested")
	_check(paused, "%s: duraklatma ağacı durdurur" % tag)
	var c0: float = run.clock
	await _wait(0.5)
	_check(absf(run.clock - c0) < 0.0001, "%s: duraklatılmışken gün ilerlemez" % tag)
	var sheet: Node = _game.get("_pause") as Node
	if sheet != null:
		sheet.call("close")
	await _until(func() -> bool: return not paused)
	await _wait(0.3)
	_check(run.clock > c0, "%s: devamda gün sürer" % tag)
	slice.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var c1: float = run.clock
	await _wait(0.4)
	_check(run.is_paused() and absf(run.clock - c1) < 0.0001, "%s: arka planda gün bekler" % tag)
	slice.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(not run.is_paused(), "%s: öne gelince sürer" % tag)
	_check(await _until(func() -> bool: return not slice.is_day_running(), 20.0), "%s: gün biter" % tag)
	_check(run.outcome() == PrizEvent.WIN, "%s: kazanır" % tag)


## Dil değişimi yolu: gün ortasında `GameManager.reload_scene()` → sahne baştan kurulur, eski çizelge ve
## gün sesleri sızmaz, yeni sahne planlamada açılır.
func _reload_mid_day() -> void:
	var slice: SliceGame = _slice()
	var st: SliceState = slice.state
	if not st.is_day_mode():
		(_progress.get("data") as ProgressData).level = _day_from + 1
		var first_id: int = _game.get_instance_id()
		root.get_node("GameManager").call("reload_scene")
		await _until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != first_id)
		_game = current_scene
		await process_frame
		slice = _slice()
		st = slice.state
	await _apply(slice, _plan(st), "yeniden yükleme")
	var lever: Vector2 = slice.screen_of_lever()
	slice.press(lever)
	slice.release(lever)
	await _wait(1.2)
	_check(slice.is_day_running(), "yeniden yükleme: gün sürüyor")
	var old: Node = _game
	var old_id: int = old.get_instance_id()
	root.get_node("GameManager").call("reload_scene")
	_check(await _until(func() -> bool: return current_scene != null and current_scene.get_instance_id() != old_id),
		"sahne yeniden kuruldu")
	_game = current_scene
	await _wait(0.8)
	var fresh: SliceGame = _slice()
	_check(fresh != null and fresh.mode == SliceGame.Mode.IDLE and not fresh.is_day_running(),
		"yeniden kurulan sahne planlamada")
	_check(not is_instance_valid(old), "eski sahne silindi")
	var loops: Array = _audio.call("loop_ids") as Array
	for id: Variant in loops:
		_check(not str(id).begins_with(SliceAudio.DEVICE_PREFIX), "eski gün sesi sızmamalı: %s" % str(id))
	print("PROBE yeniden yükleme (dil değişimi yolu) tamam")
