extends SceneTree

## "Ekranda rakam yok" probu (headless): Priz kuralını çalışma anında doğrular.
## Üç dilde (tr/en/es) şu ekranları açar ve sahne ağacını gezer:
##   Home, Home+ayarlar sayfası, Game, Game+duraklatma, kazanma sayfası (2x sonrası dahil),
##   kayıp sayfası, "bağlantı gerekli" sayfası.
## Herhangi bir Label / Button / RichTextLabel (görünür olsun olmasın) metni rakam içeriyorsa başarısız olur.
## Rakam = ASCII 0-9, Arapça-Hint ve tam genişlik rakamlar.
##   godot --headless --path . -s res://tools/digit_probe.gd      çıkış 0 = geçti
## Oyuncunun gerçek kaydına ASLA yazmaz (persist=false).
## NOT: `-s` betiği autoload'lardan ÖNCE derlenir; autoload'a değen UI sınıfları tür olarak anılmaz
## (bkz. play_probe.gd). Düğümler `Node`/`Control` olarak tutulur, `call`/`emit_signal` ile sürülür.

const WATCHDOG_SECONDS: float = 170.0
const WAIT_SECONDS: float = 15.0
const SETTLE_FRAMES: int = 6
const PLAYER_LEVEL: int = 12
const PLAYER_COINS: int = 250
const HOME_SCENE: String = "res://scenes/Home.tscn"
const GAME_SCENE: String = "res://scenes/Game.tscn"
const ONLINE_SHEET_SCRIPT: String = "res://scripts/net/online_sheet.gd"

var _progress: Node = null
var _failed: bool = false
var _finished: bool = false
var _elapsed: float = 0.0
var _inspected: int = 0
var _screens: int = 0


## Anında biten sahte sağlayıcı (kazanma sayfasında "İkiye katla" çıksın diye).
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
	_run()


func _process(delta: float) -> bool:
	_elapsed += delta
	if not _finished and _elapsed > WATCHDOG_SECONDS:
		_check(false, "zaman aşımı (%d sn)" % int(WATCHDOG_SECONDS))
		_finish()
	return false


func _frames(count: int) -> void:
	for _i: int in range(count):
		await process_frame


func _run() -> void:
	# Autoload `_ready`leri bu betiğin `_initialize`inden sonra çalışır: kayıt/sağlayıcı ilk kareden sonra ayarlanır.
	await process_frame
	root.get_node("AdManager").call("set_provider", InstantProvider.new())
	for code: String in Loc.LANGUAGES:
		await _language_pass(code)
	_check(_screens >= Loc.LANGUAGES.size() * 7, "her dilde 7 ekran/sayfa gezilmeli (gezilen %d)" % _screens)
	_check(_inspected > 100, "yeterince metin düğümü denetlenmeli (denetlenen %d)" % _inspected)
	print("PROBE rakam_denetimi: %d ekran, %d metin düğümü, %d dil" % [_screens, _inspected, Loc.LANGUAGES.size()])
	Loc.set_language(Loc.LANG_TR)
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE SONUC: %s" % ("BASARISIZ" if _failed else "gecti"))
	quit(1 if _failed else 0)


func _language_pass(code: String) -> void:
	_progress.call("reset_state")
	(_progress.get("data") as ProgressData).level = PLAYER_LEVEL
	_progress.call("add_coins", PLAYER_COINS)
	Loc.set_language(code)
	# Home
	_open_scene(HOME_SCENE)
	await _frames(SETTLE_FRAMES)
	_inspect(current_scene, "%s/home" % code)
	current_scene.call("_open_settings")
	await _frames(SETTLE_FRAMES)
	_inspect(current_scene, "%s/home+ayarlar" % code)
	# Game (ilerleme noktaları dolu)
	_open_scene(GAME_SCENE)
	await _frames(SETTLE_FRAMES)
	await _plug_one(current_scene)
	await _frames(SETTLE_FRAMES)
	_inspect(current_scene, "%s/game" % code)
	current_scene.call("_on_pause_requested")
	await _frames(SETTLE_FRAMES)
	_inspect(current_scene, "%s/game+duraklatma" % code)
	# Kazanma sayfası + 2x sonrası
	_open_scene(GAME_SCENE)
	await _frames(SETTLE_FRAMES)
	await _solve(current_scene)
	if await _until(func() -> bool: return current_scene.get("_overlay") != null):
		var sheet: Control = current_scene.get("_overlay") as Control
		await _frames(SETTLE_FRAMES)
		_check(sheet.find_child("DoubleButton", true, false) != null, "%s: ikiye katla düğmesi sunulmalı" % code)
		_inspect(current_scene, "%s/kazanma" % code)
		sheet.emit_signal(&"double_pressed")
		await _frames(SETTLE_FRAMES * 3)
		_inspect(current_scene, "%s/kazanma+2x" % code)
	else:
		_check(false, "%s: kazanma sayfası çıkmadı" % code)
	# Kayıp sayfası (gün kipi kancası; düz kipte oyun kaybettirmez)
	_open_scene(GAME_SCENE)
	await _frames(SETTLE_FRAMES)
	current_scene.call("_show_lose")
	if await _until(func() -> bool: return current_scene.get("_overlay") != null):
		await _frames(SETTLE_FRAMES)
		_inspect(current_scene, "%s/kayip" % code)
	else:
		_check(false, "%s: kayıp sayfası çıkmadı" % code)
	# Bağlantı gerekli sayfası (sınıf adı autoload'a bağlı değil ama yine de dinamik yüklenir)
	_open_scene(HOME_SCENE)
	await _frames(SETTLE_FRAMES)
	var sheet_script: GDScript = load(ONLINE_SHEET_SCRIPT) as GDScript
	var online: Node = sheet_script.call("open", current_scene, OnlineChecker.new()) as Node
	await _frames(SETTLE_FRAMES)
	_inspect(online, "%s/baglanti" % code)
	online.queue_free()
	await _frames(2)


## Kesitte bir cihazı gerçek giriş yolundan takar (oyun ekranı dolu görünsün).
func _plug_one(game: Node) -> void:
	var slice: SliceGame = game.get_node("Slice") as SliceGame
	var plan: Dictionary = PrizSolver.new().first_solution(slice.state.level, PrizContent.load_default().registry)
	var id: String = str(plan.keys()[0])
	slice.drag_device_to_socket(id, str(plan[id]))
	await _until(func() -> bool: return slice.all_settled())


## Seviyeyi çözer ve kazanma sahnesini atlar (sonuç sayfası çıksın).
func _solve(game: Node) -> void:
	var slice: SliceGame = game.get_node("Slice") as SliceGame
	var plan: Dictionary = PrizSolver.new().first_solution(slice.state.level, PrizContent.load_default().registry)
	for id: Variant in plan.keys():
		slice.drag_device_to_socket(str(id), str(plan[id]))
		await _until(func() -> bool: return slice.all_settled())
	await _until(func() -> bool: return slice.mode == SliceGame.Mode.WIN)
	slice.skip_win()


## Koşul sağlanana dek (gerçek zamanlı en çok WAIT_SECONDS) kare bekler.
func _until(condition: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(WAIT_SECONDS * 1000.0)
	while not bool(condition.call()):
		if Time.get_ticks_msec() > deadline:
			return false
		await process_frame
	return true


func _open_scene(path: String) -> void:
	if current_scene != null:
		current_scene.free()
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene


## Ağaçtaki tüm metin taşıyan düğümleri gezer; rakam içeren her metin bir hatadır.
func _inspect(from: Node, label: String) -> void:
	_screens += 1
	for node: Node in _all_nodes(from):
		var text: String = ""
		if node is RichTextLabel:
			text = (node as RichTextLabel).text
		elif node is Label:
			text = (node as Label).text
		elif node is Button:
			text = (node as Button).text
		else:
			continue
		_inspected += 1
		if _has_digit(text):
			_check(false, "%s: rakam var -> '%s' (%s)" % [label, text, node.get_path()])


func _all_nodes(from: Node) -> Array[Node]:
	var found: Array[Node] = [from]
	for child: Node in from.get_children():
		found.append_array(_all_nodes(child))
	return found


func _has_digit(text: String) -> bool:
	for index: int in range(text.length()):
		var code: int = text.unicode_at(index)
		if (code >= 0x30 and code <= 0x39) or (code >= 0x660 and code <= 0x669) or (code >= 0xFF10 and code <= 0xFF19):
			return true
	return false


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		printerr("PROBE HATA: %s" % message)
