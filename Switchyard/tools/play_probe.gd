extends SceneTree

## Oynanış probu (headless): yer tutucu oyunu GERÇEK Game sahnesinde oynar ve akışı doğrular:
##  * kazanma yolu: N dokunuş -> sonuç sayfası -> jeton ödülü + seviye ilerlemesi -> "Devam" -> yeni tur,
##  * 2x jeton (ödüllü reklam) ve geçiş reklamı kuralı (4. seviyeden itibaren; ödüllü izlenen geçişte yok),
##  * kayıp yolu: "Kaybet" -> kayıp sayfası -> "Devam et" (ödüllü, tur başına bir kez) -> tekrar kayıp ->
##    devam yok -> "Tekrar dene" temiz başlar,
##  * duraklatma sayfası oyunu durdurur ve kapanınca devam ettirir,
##  * ana ekran: "Seviye N" düğmesi + ayarlar sayfası açılır.
## Reklamlar anında biten sahte sağlayıcıyla sürülür (gerçek zamanlı bekleme yok).
##   godot --headless --path . -s res://tools/play_probe.gd      çıkış 0 = geçti
## NOT: `-s` betiği autoload'lardan ÖNCE derlenir; bu yüzden burada autoload'a değen sınıflar
## (ResultSheet, PauseSheet, SettingsSheet, RunFlow...) tür olarak ANILMAZ (derleme hatası verir):
## düğümler `Control`/`Node` olarak tutulur, sinyal/metot `emit_signal`/`call` ile çağrılır.
## Oyun mekaniği değişince bu probun "oynama" kısmı (dokunuş döngüsü) yeni oyuna göre güncellenir;
## iskelet kontrolleri (sonuç sayfası, ödül, reklam, kayıt) aynı kalır.

const WATCHDOG_SECONDS: float = 120.0
const WAIT_SECONDS: float = 15.0
const WIN_REWARD: int = 20
## Win -> double -> continue sırası: [2x izlensin mi, geçiş reklamı beklenir mi (sonraki seviye için)]
const WIN_PLAN: Array[Array] = [
	[true, false],   # 1 -> 2: ödüllü izlendi, zaten 4. seviye öncesi
	[false, false],  # 2 -> 3
	[false, true],   # 3 -> 4: ilk geçiş reklamı
	[true, false],   # 4 -> 5: ödüllü izlendi -> geçiş reklamı YOK
	[false, true],   # 5 -> 6: geçiş reklamı
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
	_check(AnalyticsLog.count("rewarded_watched") >= 2, "ödüllü izleme olayları")
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


func _run_state() -> PlaceholderRun:
	return _game.get("_run") as PlaceholderRun


# --- Kazanma yolu ---------------------------------------------------------------------------

func _play_win_levels() -> void:
	_open_game()
	await process_frame
	var interstitials_expected: int = 0
	for step: int in range(WIN_PLAN.size()):
		var double_it: bool = bool((WIN_PLAN[step] as Array)[0])
		var expect_interstitial: bool = bool((WIN_PLAN[step] as Array)[1])
		var level: int = int(_progress.call("level"))
		var coins: int = int(_progress.call("coins"))
		_check(int(_game.get("_level_number")) == level, "adım %d: oyun seviyesi kayıtla aynı olmalı" % step)
		var run: PlaceholderRun = _run_state()
		for _tap: int in range(run.target):
			_game.call("_on_tap_pressed")
		_check(run.is_won(), "adım %d: hedef dokunuştan sonra kazanılmış olmalı" % step)
		var shown: bool = await _until(func() -> bool: return _overlay() != null)
		_check(shown, "adım %d: kazanma sayfası çıkmalı" % step)
		if not shown:
			return
		var sheet: Control = _overlay()
		_check(int(_progress.call("level")) == level + 1, "adım %d: seviye ilerlemeli" % step)
		_check(int(_progress.call("coins")) == coins + WIN_REWARD, "adım %d: ödül jetonu eklenmeli" % step)
		_check(sheet.find_child("DoubleButton", true, false) != null, "adım %d: 2x düğmesi sunulmalı" % step)
		if double_it:
			sheet.emit_signal(&"double_pressed")
			_check(int(_progress.call("coins")) == coins + WIN_REWARD * 2, "adım %d: 2x jeton verilmeli" % step)
			var counted: bool = await _until(func() -> bool: return String(sheet.call("reward_text")) == "+%d" % (WIN_REWARD * 2))
			_check(counted, "adım %d: ödül etiketi +%d sayılmalı" % [step, WIN_REWARD * 2])
			sheet.emit_signal(&"double_pressed")
			_check(int(_progress.call("coins")) == coins + WIN_REWARD * 2, "adım %d: 2x iki kez verilmemeli" % step)
		if expect_interstitial:
			interstitials_expected += 1
		sheet.emit_signal(&"continue_pressed")
		var next_started: bool = await _until(func() -> bool:
			return _overlay() == null and int(_game.get("_level_number")) == level + 1 and _run_state().taps == 0)
		_check(next_started, "adım %d: Devam yeni turu başlatmalı" % step)
		_check(AnalyticsLog.count("interstitial_shown") == interstitials_expected,
			"adım %d: geçiş reklamı sayısı %d olmalı (şu an %d)" % [step, interstitials_expected,
			AnalyticsLog.count("interstitial_shown")])
	print("PROBE kazanma_yolu tamam: %d seviye, geçiş reklamı=%d" % [WIN_PLAN.size(), interstitials_expected])


# --- Kayıp yolu -----------------------------------------------------------------------------

func _play_lose_paths() -> void:
	var level: int = int(_progress.call("level"))
	var coins: int = int(_progress.call("coins"))
	_game.call("_on_tap_pressed")
	_game.call("_on_lose_pressed")
	_check(_run_state().is_lost(), "Kaybet turu kaybettirmeli")
	_check(await _until(func() -> bool: return _overlay() != null), "kayıp sayfası çıkmalı")
	var sheet: Control = _overlay()
	_check(sheet.find_child("ReviveButton", true, false) != null, "ilk kayıpta Devam et sunulmalı")
	_check(int(_progress.call("coins")) == coins and int(_progress.call("level")) == level,
		"kayıpta jeton/seviye değişmemeli")
	sheet.emit_signal(&"revive_pressed")
	_check(_run_state().is_playing() and _run_state().taps == 1, "Devam et turu kaldığı yerden sürdürmeli")
	_check(await _until(func() -> bool: return _overlay() == null), "Devam et sayfayı kapatmalı")
	_game.call("_on_lose_pressed")
	_check(await _until(func() -> bool: return _overlay() != null), "ikinci kayıp sayfası çıkmalı")
	sheet = _overlay()
	_check(sheet.find_child("ReviveButton", true, false) == null, "tur başına yalnız bir Devam et")
	sheet.emit_signal(&"retry_pressed")
	_check(await _until(func() -> bool: return _overlay() == null and _run_state().taps == 0 and _run_state().is_playing()),
		"Tekrar dene temiz tur başlatmalı")
	_check(int(_progress.call("level")) == level, "Tekrar dene seviyeyi değiştirmemeli")
	print("PROBE kayip_yolu tamam (devam et + tekrar dene)")


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
		_check(caption.text == Loc.f("LEVEL", [int(_progress.call("level"))]), "düğme güncel seviyeyi yazmalı")
	current_scene.call("_open_settings")
	await process_frame
	_check(_child_of_class(current_scene, &"SettingsSheet") != null, "ayarlar sayfası açılmalı")
	print("PROBE ana_ekran tamam")


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		printerr("PROBE HATA: %s" % message)
