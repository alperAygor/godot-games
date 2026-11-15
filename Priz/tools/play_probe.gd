extends SceneTree

## Oynanış probu (headless): dikey kesiti GERÇEK Game sahnesinde oynar ve kabuk akışını doğrular:
##  * kazanma yolu: çözücünün çözümü sürükle-bırakla takılır, kazanma sahnesi dokunarak atlanır -> sonuç sayfası -> jeton ödülü + yıldız + seviye ilerlemesi -> "Devam" -> yeni tur,
##  * ilk 3 seviye sessiz (ödüllü düğme yok), sonrasında "İkiye katla" (ödüllü reklam, simge sayısı artar),
##  * geçiş reklamı kuralı (5. seviyeden sonra, 2-3 seviyede bir; ödüllü izlenen geçişte yok),
##  * kayıp yolu (kabuk kancası `_show_lose` doğrudan çağrılır; gerçek sigorta akışı `tools/day_probe.gd`): kayıp
##    sayfası -> "Bir hak daha" (ödüllü, tur başına bir kez) -> tekrar kayıp -> hak yok -> "Tekrar dene" (gün kipinde
##    plan korunur, haklar dolar; düz kipte temiz başlar),
##  * aşama 3: kesitin 8. seviyesinden itibaren gün kipi — seviye ana şalterle (gerçek dokunuş) ve hızlandırılmış
##    günle kazanılır,
##  * duraklatma sayfası oyunu durdurur ve kapanınca devam ettirir,
##  * ana ekran: "Oyna" düğmesi + ayarlar sayfası açılır, banner yalnız ana ekranda (oyun ekranında gizli).
## Reklamlar anında biten sahte sağlayıcıyla sürülür (gerçek zamanlı bekleme yok).
##   godot --headless --path . -s res://tools/play_probe.gd      çıkış 0 = geçti
## NOT: `-s` betiği autoload'lardan ÖNCE derlenir; bu yüzden burada autoload'a değen sınıflar
## (ResultSheet, PauseSheet, SettingsSheet, RunFlow...) tür olarak ANILMAZ (derleme hatası verir):
## düğümler `Control`/`Node` olarak tutulur, sinyal/metot `emit_signal`/`call` ile çağrılır.
## Kesit sınıfları (SliceGame, SliceState) autoload'a dokunmaz; tür olarak anılabilir.

const WATCHDOG_SECONDS: float = 170.0
const WAIT_SECONDS: float = 15.0
const WIN_REWARD: int = 20
const WIN_STARS: int = 3
## Adım: [2x izlensin mi, geçiş reklamı beklenir mi, "İkiye katla" düğmesi sunulur mu]. Seviye 1'den başlar.
const WIN_PLAN: Array[Array] = [
	[false, false, false],  # 1: sessiz dönem
	[false, false, false],  # 2: sessiz dönem
	[false, false, false],  # 3: sessiz dönem
	[false, false, true],   # 4: ödüllü açık, geçiş reklamı henüz yok (5. seviyeden sonra)
	[false, true, true],    # 5: ilk geçiş reklamı
	[false, false, true],   # 6: bekleme (2 seviye) dolmadı
	[true, false, true],    # 7: ödüllü izlendi -> geçiş reklamı YOK
	[false, true, true],    # 8: geçiş reklamı
	[false, false, true],   # 9: bekleme (3 seviye)
	[false, false, true],   # 10
	[false, true, true],    # 11: geçiş reklamı
]

var _game: Node = null
var _progress: Node = null
var _ads: Node = null
var _provider: InstantProvider = null
var _failed: bool = false
var _finished: bool = false
var _elapsed: float = 0.0


## Anında biten sahte sağlayıcı: ödüllü -> rewarded, geçiş -> dismissed.
class InstantProvider extends AdsProvider:
	var shown_count: int = 0

	func is_ready(_placement: int) -> bool:
		return true

	func show(placement: int) -> void:
		shown_count += 1
		shown.emit()
		if placement == INTERSTITIAL_PLACEMENT:
			dismissed.emit()
		else:
			rewarded.emit()


func _initialize() -> void:
	# Prob oyuncunun gerçek kaydını ASLA ezmemeli: ilk iş.
	_progress = root.get_node("Progress")
	_progress.set("persist", false)
	AnalyticsLog.echo = false
	AnalyticsLog.clear()
	_ads = root.get_node("AdManager")
	_run()


func _process(delta: float) -> bool:
	_elapsed += delta
	if not _finished and _elapsed > WATCHDOG_SECONDS:
		_check(false, "zaman aşımı (%d sn): akış takıldı" % int(WATCHDOG_SECONDS))
		_finish()
	return false


func _run() -> void:
	# Autoload'ların `_ready`si bu betiğin `_initialize`inden SONRA çalışır (kayıt yüklenir, AdManager
	# kendi sağlayıcısını kurar): sahte sağlayıcı ve temiz ilerleme ilk kareden sonra konur.
	await process_frame
	_progress.call("reset_state")
	_provider = InstantProvider.new()
	_ads.call("set_provider", _provider)
	await _play_win_levels()
	await _play_lose_paths()
	await _check_pause()
	await _check_home()
	_check(AnalyticsLog.count("level_win") == WIN_PLAN.size(), "level_win olayı sayısı")
	_check(AnalyticsLog.count("rewarded_watched") >= 2, "ödüllü izleme olayları (2x + ek hak)")
	print("PROBE analitik win=%d lose=%d ödüllü=%d geçiş=%d" % [AnalyticsLog.count("level_win"),
		AnalyticsLog.count("level_lose"), AnalyticsLog.count("rewarded_watched"),
		AnalyticsLog.count("interstitial_shown")])
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE SONUC: %s" % ("kaldi" if _failed else "gecti"))
	quit(1 if _failed else 0)


func _open_scene(path: String) -> void:
	if current_scene != null:
		current_scene.free()
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene


func _open_game() -> void:
	_open_scene("res://scenes/Game.tscn")
	_game = current_scene


## Koşul sağlanana dek (gerçek zamanlı en çok WAIT_SECONDS) kare bekler.
func _until(condition: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(WAIT_SECONDS * 1000.0)
	while not bool(condition.call()):
		if Time.get_ticks_msec() > deadline:
			return false
		await process_frame
	return true


func _overlay() -> Control:
	return _game.get("_overlay") as Control


## Betik sınıf adı (class_name) bu düğümle eşleşiyor mu: tür anmadan sınıf denetimi.
func _is_class(node: Node, class_label: StringName) -> bool:
	var script: Script = node.get_script() as Script
	return script != null and script.get_global_name() == class_label


func _child_of_class(parent: Node, class_label: StringName) -> Node:
	for child: Node in parent.get_children():
		if _is_class(child, class_label):
			return child
	return null


func _slice() -> SliceGame:
	return _game.get_node("Slice") as SliceGame


## Seviyeyi çözer (gerçek giriş yolu) ve kazanma sahnesini dokunarak atlar.
func _solve_current() -> bool:
	var slice: SliceGame = _slice()
	var st: SliceState = slice.state
	var plan: Dictionary = PrizSolver.new().first_solution(st.level, PrizContent.load_default().registry)
	for id: Variant in plan.keys():
		if slice.drag_device_to_socket(str(id), str(plan[id])) != PrizReason.OK:
			return false
		await _until(func() -> bool: return slice.all_settled())
	if slice.is_day_mode():
		# Gün kipi: ana şalter gerçek dokunuşla çekilir, gün dokunuşla hızlanır.
		var lever: Vector2 = slice.screen_of_lever()
		slice.press(lever)
		slice.release(lever)
		if not slice.is_day_running():
			return false
		while slice.is_day_running():
			slice.press(Vector2(540.0, 700.0))
			slice.release(Vector2(540.0, 700.0))
			await process_frame
	if not await _until(func() -> bool: return slice.mode == SliceGame.Mode.WIN):
		return false
	await process_frame
	slice.press(Vector2(540.0, 900.0))
	slice.release(Vector2(540.0, 900.0))
	return st.board.is_won()


func _fresh_level() -> bool:
	var slice: SliceGame = _slice()
	return slice.state != null and slice.state.board.placement().is_empty() and slice.state.board.is_planning()


# --- Kazanma yolu ---------------------------------------------------------------------------

func _play_win_levels() -> void:
	_open_game()
	await process_frame
	var interstitials_expected: int = 0
	var data: ProgressData = _progress.get("data") as ProgressData
	for step: int in range(WIN_PLAN.size()):
		var double_it: bool = bool((WIN_PLAN[step] as Array)[0])
		var expect_interstitial: bool = bool((WIN_PLAN[step] as Array)[1])
		var expect_double_button: bool = bool((WIN_PLAN[step] as Array)[2])
		var level: int = int(_progress.call("level"))
		var coins: int = int(_progress.call("coins"))
		_check(level == step + 1, "adım %d: seviye numarası beklenen" % step)
		_check(int(_game.get("_level_number")) == level, "adım %d: oyun seviyesi kayıtla aynı olmalı" % step)
		_check(_game.find_child("LevelPips", true, false) != null, "adım %d: HUD seviye noktaları" % step)
		_check(await _solve_current(), "adım %d: seviye çözülüp kazanılmalı" % step)
		var shown: bool = await _until(func() -> bool: return _overlay() != null)
		_check(shown, "adım %d: kazanma sayfası çıkmalı" % step)
		if not shown:
			return
		var sheet: Control = _overlay()
		_check(int(_progress.call("level")) == level + 1, "adım %d: seviye ilerlemeli" % step)
		_check(int(_progress.call("coins")) == coins + WIN_REWARD, "adım %d: ödül jetonu eklenmeli" % step)
		_check(int(_progress.call("stars_for", level)) == WIN_STARS, "adım %d: yıldız kaydedilmeli" % step)
		_check(int(_progress.call("win_streak")) == step + 1, "adım %d: galibiyet serisi" % step)
		_check((sheet.find_child("DoubleButton", true, false) != null) == expect_double_button,
			"adım %d: ikiye katla düğmesi sunumu (sessiz dönem kuralı)" % step)
		var reward_icons: int = int(sheet.call("reward_icons"))
		var icons_ready: bool = await _until(func() -> bool: return int(sheet.call("reward_icons")) == 2)
		_check(icons_ready, "adım %d: ödül 2 jeton simgesi olmalı (görünen %d)" % [step, reward_icons])
		if double_it:
			sheet.emit_signal(&"double_pressed")
			_check(int(_progress.call("coins")) == coins + WIN_REWARD * 2, "adım %d: 2x jeton verilmeli" % step)
			var counted: bool = await _until(func() -> bool: return int(sheet.call("reward_icons")) == 4)
			_check(counted, "adım %d: ödül simgeleri çoğalmalı" % step)
			sheet.emit_signal(&"double_pressed")
			_check(int(_progress.call("coins")) == coins + WIN_REWARD * 2, "adım %d: 2x iki kez verilmemeli" % step)
		if expect_interstitial:
			interstitials_expected += 1
		# 90 sn kuralı birim testlerinde sınanır; burada akışı hızlandırmak için son reklam zamanı geriye alınır.
		if data.last_interstitial_time > 0.0:
			data.last_interstitial_time -= 100.0
		sheet.emit_signal(&"continue_pressed")
		var next_started: bool = await _until(func() -> bool:
			return _overlay() == null and int(_game.get("_level_number")) == level + 1 and _fresh_level())
		_check(next_started, "adım %d: Devam yeni turu başlatmalı" % step)
		_check(AnalyticsLog.count("interstitial_shown") == interstitials_expected,
			"adım %d: geçiş reklamı sayısı %d olmalı (şu an %d)" % [step, interstitials_expected,
			AnalyticsLog.count("interstitial_shown")])
		_check(not bool(_ads.get("banner_visible")), "adım %d: oyun ekranında banner YOK" % step)
	print("PROBE kazanma_yolu tamam: %d seviye, geçiş reklamı=%d" % [WIN_PLAN.size(), interstitials_expected])


# --- Kayıp yolu -----------------------------------------------------------------------------

func _play_lose_paths() -> void:
	var level: int = int(_progress.call("level"))
	var coins: int = int(_progress.call("coins"))
	var streak: int = int(_progress.call("win_streak"))
	_check(int(_progress.call("fuses_left")) == 3, "tur 3 sigorta hakkıyla başlamalı")
	# Bir cihaz takılı iken kayıp (gün kipi kancası): plan korunmalı.
	var slice: SliceGame = _slice()
	var st: SliceState = slice.state
	var plan: Dictionary = PrizSolver.new().first_solution(st.level, PrizContent.load_default().registry)
	var first: String = str(plan.keys()[0])
	slice.drag_device_to_socket(first, str(plan[first]))
	await _until(func() -> bool: return slice.all_settled())
	_game.call("_show_lose")
	_check(await _until(func() -> bool: return _overlay() != null), "kayıp sayfası çıkmalı")
	var sheet: Control = _overlay()
	_check(sheet.find_child("ReviveButton", true, false) != null, "ilk kayıpta Bir hak daha sunulmalı")
	_check(int(_progress.call("coins")) == coins and int(_progress.call("level")) == level,
		"kayıpta jeton/seviye değişmemeli")
	_check(int(_progress.call("win_streak")) == 0 and streak > 0, "kayıp galibiyet serisini bitirmeli")
	sheet.emit_signal(&"revive_pressed")
	_check(await _until(func() -> bool: return _overlay() == null), "ek hak sayfayı kapatmalı")
	_check(st.board.socket_of(first) == str(plan[first]), "ek hak turu kaldığı yerden sürdürmeli (plan korunur)")
	_check(bool(slice.get("_input_enabled")), "ek haktan sonra giriş açık")
	_check(int(_progress.call("fuses_left")) == 4, "ödüllü reklam +1 sigorta hakkı vermeli")
	_game.call("_show_lose")
	_check(await _until(func() -> bool: return _overlay() != null), "ikinci kayıp sayfası çıkmalı")
	sheet = _overlay()
	_check(sheet.find_child("ReviveButton", true, false) == null, "tur başına yalnız bir ek hak")
	var placed: Dictionary = st.board.placement()
	sheet.emit_signal(&"retry_pressed")
	if slice.is_day_mode():
		_check(await _until(func() -> bool: return _overlay() == null and slice.state != st),
			"Tekrar dene yeni tur başlatmalı")
		_check(slice.state.board.placement() == placed, "gün kipinde Tekrar dene planı korur")
		_check(slice.state.board.fuse_rights() == 3, "Tekrar dene hakları doldurur")
	else:
		_check(await _until(func() -> bool: return _overlay() == null and _fresh_level()), "Tekrar dene temiz tur başlatmalı")
	_check(int(_progress.call("level")) == level, "Tekrar dene seviyeyi değiştirmemeli")
	_check(int(_progress.call("fuses_left")) == 3, "yeni tur hakları yeniler (seviye başına, kaydedilmez)")
	print("PROBE kayip_yolu tamam (kayıp kancası + ek hak + tekrar dene)")


# --- Duraklatma -----------------------------------------------------------------------------

func _check_pause() -> void:
	_game.call("_on_pause_requested")
	await process_frame
	_check(paused, "duraklatma sayfası oyunu durdurmalı")
	var sheet: Node = _child_of_class(_game, &"PauseSheet")
	_check(sheet != null, "PauseSheet açılmalı")
	if sheet != null:
		sheet.emit_signal(&"resume_pressed")
		sheet.call("close")
	await process_frame
	_check(not paused, "duraklatma kalkmalı")
	print("PROBE duraklatma tamam")


# --- Ana ekran ------------------------------------------------------------------------------

func _check_home() -> void:
	_open_scene("res://scenes/Home.tscn")
	await process_frame
	var play: Button = current_scene.find_child("PlayButton", true, false) as Button
	_check(play != null, "ana ekranda Oyna düğmesi olmalı")
	if play != null:
		var caption: Label = play.get_meta(UiKit.CAPTION_META) as Label
		_check(caption.text == Loc.t("PLAY"), "düğme Oyna yazmalı (seviye numarası değil)")
	_check(current_scene.find_child("LevelPips", true, false) != null, "ana ekranda seviye noktaları olmalı")
	_check(bool(_ads.get("banner_visible")) and _ads.get("banner_screen") == &"neighbourhood",
		"banner ana ekranda (mahalle) görünmeli")
	current_scene.call("_open_settings")
	await process_frame
	_check(_child_of_class(current_scene, &"SettingsSheet") != null, "ayarlar sayfası açılmalı")
	print("PROBE ana_ekran tamam")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		printerr("PROBE HATA: %s" % message)
