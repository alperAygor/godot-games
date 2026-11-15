extends SceneTree

## Dikey kesit probu (başsız): GERÇEK Game sahnesinde kesitin her seviyesini oynar. Denetleyiciyi gerçek
## giriş yolundan sürer (SliceGame.press/move/release — dokunma olaylarının gittiği yöntemler):
##  * her seviyede çözücünün ilk çözümü (`PrizSolver.first_solution`) sürükle-bırakla takılır,
##  * bir REDDEDİLEN takma (tahta değişmez, cihaz tepsiye döner, gösterge ret parlaması),
##  * bir GERİ ALMA (takılı cihaza dokun → tepsiye döner, döngü sesi katmanı kalkar, blok boşalır),
##  * takılan cihaz çalışır ve ses katmanı açılır; uğultu katmanı vardır,
##  * kazanma: kazanma sahnesi (bazı seviyelerde dokunarak atlanır) → ResultSheet → Devam → sıradaki seviye,
##  * sahne silinince ses katmanı sızmaz.
##   godot --headless --path . -s res://tools/slice_probe.gd      çıkış 0 + "PROBE SONUC: gecti"
## NOT: `-s` betiği autoload'lardan ÖNCE derlenir: autoload'a değen sınıflar (ResultSheet, RunFlow ...) tür
## olarak anılmaz. Kesit sınıfları (SliceGame, SliceState ...) autoload'a dokunmaz; anılabilir.

const WATCHDOG_SECONDS: float = 170.0
const WAIT_SECONDS: float = 12.0

var _progress: Node = null
var _audio: Node = null
var _game: Node = null
var _failed: bool = false
var _finished: bool = false
var _elapsed: float = 0.0
var _content: PrizContent


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
	_elapsed += delta
	if not _finished and _elapsed > WATCHDOG_SECONDS:
		_check(false, "zaman aşımı (%d sn)" % int(WATCHDOG_SECONDS))
		_finish()
	return false


func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE SONUC: %s" % ("kaldi" if _failed else "gecti"))
	quit(1 if _failed else 0)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		printerr("PROBE HATA: %s" % message)


func _until(condition: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(WAIT_SECONDS * 1000.0)
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
	_game = (load("res://scenes/Game.tscn") as PackedScene).instantiate()
	root.add_child(_game)
	current_scene = _game
	await process_frame
	var count: int = _slice().data.level_count()
	_check(count >= 6, "kesitte en az altı seviye")
	for i: int in range(count):
		await _play_level(i)
		if _failed:
			break
	_check(AnalyticsLog.count("level_win") == count, "her kesit seviyesi kazanılmalı (%d/%d)" % [AnalyticsLog.count("level_win"), count])
	_check(int(_progress.call("level")) == count + 1, "ilerleme kesit sonuna gelmeli")
	_check(_slice().level_index == 0, "kesit bitince başa sarar")
	# Sahne silinince katmanlar sızmamalı.
	_game.queue_free()
	await _wait(0.8)
	var loops: Array = _audio.call("loop_ids") as Array
	_check(loops.is_empty(), "sahneden çıkınca ses katmanı kalmamalı: %s" % str(loops))
	print("PROBE kesit: %d seviye oynandı" % count)
	_finish()


func _play_level(i: int) -> void:
	var slice: SliceGame = _slice()
	_check(slice.level_index == i, "seviye %d: kesit dizini %d" % [i + 1, slice.level_index])
	var st: SliceState = slice.state
	var tag: String = "seviye %d" % (i + 1)
	_check(st.board.is_planning() and not st.board.is_won(), "%s: planlama ile başlar" % tag)
	_check(slice.devices.size() == st.level.devices.size(), "%s: her cihaz tepside" % tag)
	_check(_audio.call("is_loop_playing", SliceAudio.HUM_ID), "%s: elektrik uğultusu katmanı" % tag)
	var plan: Dictionary = PrizSolver.new().first_solution(st.level, _content.registry)
	_check(not plan.is_empty(), "%s: çözüm var" % tag)
	var ids: Array = plan.keys()
	# 1) İlk cihaz: tak → çalışır → geri al → tekrar tak
	var first: String = str(ids[0])
	_check(slice.drag_device_to_socket(first, str(plan[first])) == PrizReason.OK, "%s: ilk takma OK" % tag)
	_check(st.board.socket_of(first) == str(plan[first]), "%s: tahta takılı görmeli" % tag)
	_check(await _until(func() -> bool: return slice.all_settled()), "%s: yolculuk bitmeli" % tag)
	var dev: SliceDevice = slice.devices[first] as SliceDevice
	_check(dev.place == SliceDevice.Place.PLUGGED and dev.appliance.is_running(), "%s: takılan cihaz çalışmalı" % tag)
	_check(_audio.call("is_loop_playing", SliceAudio.DEVICE_PREFIX + first), "%s: cihaz döngü sesi" % tag)
	var line: int = st.room_line_of(st.board.line_of_device(first))
	_check(absf(float((slice.panel_box.get("_fill") as Array)[line - 1]) - st.fill(line)) < 0.001, "%s: gösterge doluluğu tahtayla aynı" % tag)
	if ids.size() > 1 or i == 0:
		slice.tap_device(first)
		_check(st.board.socket_of(first) == "", "%s: dokununca tepsiye dönmeli" % tag)
		_check(await _until(func() -> bool: return slice.all_settled() and dev.place == SliceDevice.Place.TRAY),
			"%s: cihaz tepsiye varmalı" % tag)
		_check(not dev.appliance.is_running(), "%s: geri alınan cihaz durmalı" % tag)
		_check(not bool(_audio.call("is_loop_playing", SliceAudio.DEVICE_PREFIX + first)), "%s: döngü sesi kalkmalı" % tag)
		_check(slice.drag_device_to_socket(first, str(plan[first])) == PrizReason.OK, "%s: yeniden takma" % tag)
		await _until(func() -> bool: return slice.all_settled())
	# 2) Ret: kalan bir cihaz için takılamayan bir seviye prizi
	var rejected: bool = false
	for k: int in range(1, ids.size()):
		var d: String = str(ids[k])
		for socket: PrizSocket in st.level.sockets:
			if st.board.can_plug(d, socket.id) == PrizReason.OK:
				continue
			var placement_before: Dictionary = st.board.placement()
			var r: StringName = slice.drag_device_to_socket(d, socket.id)
			_check(r != PrizReason.OK, "%s: ret beklenirdi" % tag)
			_check(st.board.placement() == placement_before, "%s: ret tahtayı değiştirmemeli" % tag)
			_check(await _until(func() -> bool: return (slice.devices[d] as SliceDevice).place == SliceDevice.Place.TRAY),
				"%s: reddedilen fiş tepsiye dönmeli" % tag)
			rejected = true
			break
		if rejected:
			break
	if i >= 1:
		_check(rejected, "%s: en az bir ret denenmeli" % tag)
	# 3) Kalanlar
	for k: int in range(1, ids.size()):
		var d2: String = str(ids[k])
		_check(slice.drag_device_to_socket(d2, str(plan[d2])) == PrizReason.OK, "%s: %s takılmalı" % [tag, d2])
		await _until(func() -> bool: return slice.all_settled())
	_check(st.board.is_won(), "%s: tahta kazanılmış olmalı" % tag)
	_check(await _until(func() -> bool: return slice.mode == SliceGame.Mode.WIN), "%s: kazanma sahnesi başlamalı" % tag)
	if i % 2 == 1:
		await _wait(0.8)
		slice.press(Vector2(540.0, 900.0))
		slice.release(Vector2(540.0, 900.0))
		_check(slice.mode == SliceGame.Mode.DONE, "%s: dokunuş kazanma sahnesini atlamalı" % tag)
	var shown: bool = await _until(func() -> bool: return _game.get("_overlay") != null)
	_check(shown, "%s: sonuç sayfası çıkmalı" % tag)
	if not shown:
		return
	var sheet: Control = _game.get("_overlay") as Control
	_check(sheet.find_child("ContinueButton", true, false) != null, "%s: Devam düğmesi" % tag)
	_check(int(_progress.call("level")) == i + 2, "%s: ilerleme kaydedilmeli" % tag)
	sheet.emit_signal(&"continue_pressed")
	var next: bool = await _until(func() -> bool:
		return _game.get("_overlay") == null and slice.state != st and slice.mode == SliceGame.Mode.IDLE)
	_check(next, "%s: Devam sıradaki seviyeyi başlatmalı" % tag)
	await _wait(0.3)
	print("PROBE %s tamam (%d cihaz, ret=%s)" % [tag, ids.size(), str(rejected)])
