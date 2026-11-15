extends SceneTree

## Oynanış probu (headless): kabuğun GERÇEK akışını sahte saha (StubSession) ve sahte reklam sağlayıcısıyla sürer:
##  * Ana ekran "devam" hedefi, harita karoları (çözüldü / atlandı / kilitli / şimdiki),
##  * 12 seviyelik temiz geçiş: sonuç sayfası yıldızları, kilitler, en iyi hamle, geçiş reklamı TAM 3, 6, 9, 12 bitişlerinde
##    (oyun sırasında asla), ilk 3 seviyede ipucu/atla düğmesi yok,
##  * ipucu akışı (bir reklam = bir ipucu), atlama akışı (onay, vazgeç, onay + reklam -> atlandı + sıradaki seviye, yıldız yok),
##  * en az aralık (60 sn) geçiş reklamını engeller; "reklamları kaldır" yalnız geçiş reklamını kapatır (ipucu hâlâ reklam ister);
##    ödüllü izlenen seviyede geçiş reklamı yok; reklam hazır değilken düğme nedenini söyler ve akış takılmaz,
##  * duraklatma sayfası oyunu durdurur,
##  * oyuncunun gerçek kaydı DEĞİŞMEZ (Progress.persist=false; dosya özeti başta ve sonda karşılaştırılır).
## Reklamlar anında biten sahte sağlayıcıyla, geçiş aralığı sahte saatle sürülür (gerçek zamanda bekleme yok;
## yalnız StubSession'ın 0,35 sn'lik kutlama bekleyişi gerçek zamandır).
##   godot --headless --path . -s res://tools/play_probe.gd      çıkış 0 = geçti
## NOT: `-s` betiği autoload'lardan ÖNCE derlenir; autoload'a değen sınıflar (Game, RunFlow, ResultSheet, SkipSheet...)
## tür olarak ANILMAZ: düğümler `Node`/`Control` tutulur, sinyal/metot `emit_signal`/`call`/`get` ile çağrılır.

const WATCHDOG_SECONDS: float = 300.0
const WAIT_SECONDS: float = 15.0
const SAVE_PATH: String = "user://progress.json"
const CLOCK_START: float = 2000000.0
## Sentetik katalog: kabuk probu gerçek seviye dizinine (değişecek) bağlı kalmaz.
const LEVEL_COUNT: int = 13
const WORLD_SIZE: int = 6
const PAR_BASE: int = 3
const PAR_SPREAD: int = 4
const GAP: float = 60.0
const HINT_PLACEMENT: int = 0
const SKIP_PLACEMENT: int = 1

var _game: Node = null
var _progress: Node = null
var _ads: Node = null
var _provider: ProbeProvider = null
var _failed: bool = false
var _finished: bool = false
var _elapsed: float = 0.0
var _clock: float = CLOCK_START
var _save_before: String = ""
var _save_existed: bool = false


## Anında biten sahte sağlayıcı; geçiş reklamının YALNIZ seviye arasında istendiğini denetler.
class ProbeProvider extends AdsProvider:
	var ready: bool = true
	var fail_reason: String = ""
	var rewarded_shown: int = 0
	var interstitial_shown: int = 0
	var interstitial_guard: Callable = Callable()
	var violations: Array[String] = []

	func is_ready(_placement: int) -> bool:
		return ready

	func show(placement: int) -> void:
		shown.emit()
		if not fail_reason.is_empty():
			failed.emit(fail_reason)
			return
		if placement == INTERSTITIAL_PLACEMENT:
			interstitial_shown += 1
			if interstitial_guard.is_valid() and not bool(interstitial_guard.call()):
				violations.append("geçiş reklamı oyun sırasında istendi")
			dismissed.emit()
		else:
			rewarded_shown += 1
			rewarded.emit()


func _initialize() -> void:
	# Prob oyuncunun gerçek kaydını ASLA ezmemeli: ilk iş.
	_progress = root.get_node("Progress")
	_progress.set("persist", false)
	AnalyticsLog.echo = false
	AnalyticsLog.clear()
	_ads = root.get_node("AdManager")
	_save_existed = FileAccess.file_exists(SAVE_PATH)
	_save_before = FileAccess.get_file_as_string(SAVE_PATH) if _save_existed else ""
	_run()


func _process(delta: float) -> bool:
	_elapsed += delta
	if not _finished and _elapsed > WATCHDOG_SECONDS:
		_check(false, "zaman aşımı (%d sn): akış takıldı" % int(WATCHDOG_SECONDS))
		_finish()
	return false


func _run() -> void:
	# Autoload'ların `_ready`si bu betiğin `_initialize`inden SONRA çalışır: sağlayıcı ve temiz ilerleme ilk kareden sonra konur.
	await process_frame
	Loc.set_language(Loc.LANG_EN)
	_install_catalog()
	_provider = ProbeProvider.new()
	_ads.call("set_provider", _provider)
	await _pass_clean_twelve()
	await _pass_gap()
	await _pass_remove_ads()
	await _pass_rewarded_suppression()
	await _pass_unavailable_ad()
	await _pass_pause_and_home()
	_check_real_save_untouched()
	_check(_provider.violations.is_empty(), "ihlaller: %s" % str(_provider.violations))
	LevelCatalog.reload()
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE SONUC: %s" % ("kaldi" if _failed else "gecti"))
	quit(1 if _failed else 0)


# --- Hazırlık --------------------------------------------------------------------------------

func _install_catalog() -> void:
	var entries: Array[Dictionary] = []
	for index: int in LEVEL_COUNT:
		entries.append({"id": "probe-%02d" % (index + 1), "world": 1 + index / WORLD_SIZE,
			"par": _par_of(index + 1), "difficulty": 1})
	LevelCatalog._entries = entries
	LevelCatalog._loaded = true


func _par_of(number: int) -> int:
	return PAR_BASE + number % PAR_SPREAD


func _id_of(number: int) -> String:
	return "probe-%02d" % number


## Her geçiş için temiz başlangıç: kayıt, sayaçlar, sağlayıcı, saat.
func _fresh_state() -> void:
	_progress.call("reset_state")
	_ads.call("reset_session_limits")
	AnalyticsLog.clear()
	_provider.ready = true
	_provider.fail_reason = ""
	_provider.rewarded_shown = 0
	_provider.interstitial_shown = 0
	_clock = CLOCK_START


func _open_scene(path: String) -> Node:
	if current_scene != null:
		current_scene.free()
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	return scene


func _open_game(start_number: int) -> void:
	root.get_node("GameManager").set("selected_level_id", _id_of(start_number))
	_game = _open_scene("res://scenes/Game.tscn")
	_game.get("_flow").set("time_source", func() -> float: return _clock)
	_provider.interstitial_guard = func() -> bool:
		# Geçiş reklamı yalnız biten bir seviyenin ardından (seviye arası) istenebilir.
		return LevelProgress.load_saved().is_completed(String(_game.get("_level_id")))
	await process_frame


## Koşul sağlanana dek (gerçek zamanda en çok WAIT_SECONDS) kare bekler.
func _until(condition: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(WAIT_SECONDS * 1000.0)
	while not bool(condition.call()):
		if Time.get_ticks_msec() > deadline:
			return false
		await process_frame
	return true


func _level_number() -> int:
	return int(_game.get("_level_number"))


func _overlay() -> Control:
	return _game.get("_overlay") as Control


func _session() -> Control:
	return _game.get("_session") as Control


func _button(node_name: String) -> Button:
	return _game.find_child(node_name, true, false) as Button


func _label_text(parent: Node, node_name: String) -> String:
	var node: Label = parent.find_child(node_name, true, false) as Label
	return node.text if node != null else ""


## Dokunuşlarla seviyeyi `moves` hamlede çözer; sonuç sayfasını bekler. Dönen: sayfa (yoksa null).
func _solve(moves: int) -> Control:
	var session: Control = _session()
	session.set("solve_at", moves)
	for _tap: int in range(moves):
		session.call("tap")
	var shown: bool = await _until(func() -> bool: return _overlay() != null)
	_check(shown, "seviye %d: sonuç sayfası çıkmalı" % _level_number())
	return _overlay() if shown else null


## Sonuç sayfasında Sonraki: sıradaki seviye yüklenene dek bekler. Dönen: bu geçişte gösterilen geçiş reklamı sayısı.
func _next_level() -> int:
	var before_number: int = _level_number()
	var before_ads: int = _provider.interstitial_shown
	_overlay().emit_signal(&"next_pressed")
	var moved: bool = await _until(func() -> bool:
		return _level_number() == before_number + 1 and _overlay() == null)
	_check(moved, "seviye %d -> %d: sıradaki seviye açılmalı" % [before_number, before_number + 1])
	return _provider.interstitial_shown - before_ads


func _press(node_name: String) -> void:
	var button: Button = _button(node_name)
	_check(button != null, "düğme bulunmalı: " + node_name)
	if button != null:
		button.pressed.emit()


# --- Geçiş 1: temiz 12 seviye -----------------------------------------------------------------

func _pass_clean_twelve() -> void:
	_fresh_state()
	# Ana ekran: ilk bitmemiş seviye, harita karoları.
	var home: Node = _open_scene("res://scenes/Home.tscn")
	await process_frame
	_check(String(home.get("_target_id")) == _id_of(1), "ana ekran ilk seviyeden devam etmeli")
	var play: Button = home.find_child("PlayButton", true, false) as Button
	_check(play != null and (play.get_meta(UiKit.CAPTION_META) as Label).text == "Level 1", "Oyna 'Level 1' yazmalı")
	_check(home.find_child("LevelsButton", true, false) != null, "ana ekranda Seviyeler düğmesi olmalı")
	await _open_game(1)
	var ads_after: Array[int] = []
	var stars_seen: Array[int] = []
	var par_result: Array[int] = [3, 2, 1]
	for number: int in range(1, 13):
		_check(_level_number() == number, "seviye sırası: beklenen %d, gelen %d" % [number, _level_number()])
		var par: int = _par_of(number)
		_check(String(_game.get("_hud").call("title_text")) == "Level %d" % number, "HUD seviye başlığı")
		_check(String(_game.get("_hud").call("par_text")) == str(par), "HUD par değeri")
		var rewarded_visible: bool = bool(_game.get("_bar").call("rewarded_visible"))
		_check(rewarded_visible == (number >= 4), "seviye %d: ipucu/atla düğmeleri %s olmalı" % [number, "görünür" if number >= 4 else "gizli"])
		_check(_button("HintButton").visible == (number >= 4), "ipucu düğmesi görünürlüğü (%d)" % number)
		_check(_button("SkipButton").visible == (number >= 4), "atla düğmesi görünürlüğü (%d)" % number)
		_check(_button("UndoButton").disabled, "başlangıçta geri al kapalı")
		# Seviye 4: ipucu akışı. Seviye 5: atlama akışı (önce vazgeç, sonra onayla).
		if number == 4:
			await _hint_flow()
		if number == 5:
			await _skip_flow()
			ads_after.append(0)
			stars_seen.append(0)
			continue
		# Hamle sayısı: 1-3. seviyelerde 3, 2, 1 yıldız; sonrakilerde par.
		var target: int = par
		if number <= 3:
			target = _moves_for_stars(par, par_result[number - 1])
		var sheet: Control = await _solve(target)
		if sheet == null:
			return
		var expected_stars: int = LevelProgress.stars_for(target, par, 0)
		_check(int(sheet.call("stars_shown")) == expected_stars, "seviye %d: sonuç %d yıldız göstermeli" % [number, expected_stars])
		_check(_label_text(sheet, "Detail") == "Moves %d · Par %d" % [target, par], "seviye %d: hamle/par satırı" % number)
		_check(sheet.find_child("NextButton", true, false) != null, "Sonraki düğmesi")
		var progress: LevelProgress = LevelProgress.load_saved()
		_check(progress.is_solved(_id_of(number)) and progress.stars(_id_of(number)) == expected_stars, "seviye %d kaydı" % number)
		_check(progress.best_moves(_id_of(number)) == target, "en iyi hamle kaydı")
		stars_seen.append(expected_stars)
		_clock += GAP + 1.0
		if number == 12:
			var last_ads: int = _provider.interstitial_shown
			sheet.emit_signal(&"next_pressed")
			await _until(func() -> bool: return _level_number() == 13 and _overlay() == null)
			ads_after.append(_provider.interstitial_shown - last_ads)
		else:
			ads_after.append(await _next_level())
	_check(ads_after == [0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1], "geçiş reklamı tam 3, 6, 9, 12 bitişlerinde olmalı: %s" % str(ads_after))
	_check(_provider.interstitial_shown == 4, "toplam 4 geçiş reklamı")
	_check(AnalyticsLog.count("interstitial_shown") == 4, "geçiş analitiği")
	_check(stars_seen.slice(0, 3) == [3, 2, 1], "ilk üç seviye 3/2/1 yıldız: %s" % str(stars_seen.slice(0, 3)))
	# Kilitler ve harita.
	var progress_now: LevelProgress = LevelProgress.load_saved()
	var ids: Array[String] = LevelProgress.ids_of(LevelCatalog.entries())
	_check(progress_now.is_skipped(_id_of(5)) and progress_now.stars(_id_of(5)) == 0, "5. seviye atlandı, yıldızsız")
	_check(progress_now.frontier(ids) == 12, "devam hedefi 13. seviye (12 tamam, 5 atlandı)")
	_check(progress_now.is_unlocked(ids, 12), "13. seviye açık")
	var map: Node = _open_scene("res://scenes/Map.tscn")
	await process_frame
	var modes: Array[int] = []
	for number: int in range(1, 14):
		var tile: Node = map.find_child("Tile_%s" % _id_of(number), true, false)
		_check(tile != null, "harita karosu %d" % number)
		modes.append(int(tile.get("mode")) if tile != null else -1)
	var solved_mode: int = LevelTile.Mode.SOLVED
	var skipped_mode: int = LevelTile.Mode.SKIPPED
	var current_mode: int = LevelTile.Mode.CURRENT
	_check(modes[4] == skipped_mode, "harita: 5. karo atlandı işaretli")
	_check(modes[0] == solved_mode and modes[11] == solved_mode, "harita: çözülenler")
	_check(modes[12] == current_mode, "harita: 13. karo şimdiki")
	print("PROBE gecis1 tamam: reklam=%s yildiz=%s" % [str(ads_after), str(stars_seen)])


## Hedef yıldız için hamle sayısı: 3 = par, 2 = ceil(par x 1,5), 1 = bir fazlası.
func _moves_for_stars(par: int, stars: int) -> int:
	if stars >= 3:
		return par
	var two_star: int = (par * 3 + 1) / 2
	return two_star if stars == 2 else two_star + 1


## İpucu: bir reklam = bir ipucu; reklamdan sonra ipucu gösterilir, bitince düğme açılır.
func _hint_flow() -> void:
	var rewarded_before: int = _provider.rewarded_shown
	_press("HintButton")
	_check(_provider.rewarded_shown == rewarded_before + 1, "ipucu bir ödüllü reklam göstermeli")
	_check(bool(_game.get("_hint_showing")), "ödülden sonra ipucu gösterilmeli")
	_check(not bool(_game.get("_bar").call("hint_enabled")), "ipucu sürerken düğme kapalı")
	var done: bool = await _until(func() -> bool: return not bool(_game.get("_hint_showing")))
	_check(done, "ipucu bitmeli")
	_check(bool(_game.get("_bar").call("hint_enabled")), "ipucu bitince düğme açılmalı")
	_press("HintButton")
	_check(_provider.rewarded_shown == rewarded_before + 2, "ikinci ipucu ikinci bir reklam ister")
	await _until(func() -> bool: return not bool(_game.get("_hint_showing")))
	_check(_game.get("_flow").call("rewarded_this_level") == true, "ipucu sonrası: bu seviyede ödüllü izlendi")


## Atla: onay sayfası, vazgeç (reklam yok), sonra onayla (reklam) -> atlandı + sıradaki seviye + yıldız yok + geçiş reklamı yok.
func _skip_flow() -> void:
	var number: int = _level_number()
	var rewarded_before: int = _provider.rewarded_shown
	var interstitial_before: int = _provider.interstitial_shown
	_press("SkipButton")
	var sheet: Node = _game.get("_skip_sheet") as Node
	_check(sheet != null, "atla onay sayfası açılmalı")
	if sheet == null:
		return
	_check(_provider.rewarded_shown == rewarded_before, "onaydan önce reklam yok")
	var cancel: Button = sheet.find_child("CancelButton", true, false) as Button
	cancel.pressed.emit()
	await _until(func() -> bool: return _game.get("_skip_sheet") == null)
	_check(_provider.rewarded_shown == rewarded_before and _level_number() == number, "vazgeçince hiçbir şey olmaz")
	_check(not LevelProgress.load_saved().is_skipped(_id_of(number)), "vazgeçince atlanmış sayılmaz")
	await process_frame
	_press("SkipButton")
	sheet = _game.get("_skip_sheet") as Node
	var watch: Button = sheet.find_child("WatchButton", true, false) as Button
	watch.pressed.emit()
	var moved: bool = await _until(func() -> bool: return _level_number() == number + 1)
	_check(moved, "atlayınca sıradaki seviye açılmalı")
	_check(_provider.rewarded_shown == rewarded_before + 1, "atlama bir ödüllü reklam")
	_check(_provider.interstitial_shown == interstitial_before, "atlama geçişinde geçiş reklamı yok")
	var progress: LevelProgress = LevelProgress.load_saved()
	_check(progress.is_skipped(_id_of(number)) and not progress.is_solved(_id_of(number)), "seviye atlandı işaretli")
	_check(progress.stars(_id_of(number)) == 0, "atlanan seviyede yıldız yok")
	_check(progress.is_unlocked(LevelProgress.ids_of(LevelCatalog.entries()), number), "sıradaki seviye açıldı")


# --- Geçiş 2: en az aralık ------------------------------------------------------------------

func _pass_gap() -> void:
	_fresh_state()
	await _open_game(1)
	var ads: Array[int] = []
	for number: int in range(1, 7):
		var sheet: Control = await _solve(_par_of(number))
		if sheet == null:
			return
		# Hızlı oyuncu: bitişler arası yalnız 10 sn -> 6. seviyedeki reklam, 3'ten 30 sn sonra geldiği için engellenir.
		_clock += 10.0
		ads.append(await _next_level())
	_check(ads == [0, 0, 1, 0, 0, 0], "aralık (60 sn) dolmadan ikinci geçiş reklamı olmamalı: %s" % str(ads))
	print("PROBE aralik tamam: reklam=%s" % str(ads))


# --- Geçiş 3: reklamları kaldır ------------------------------------------------------------

func _pass_remove_ads() -> void:
	_fresh_state()
	# Satın alma mock mağaza üzerinden (gerçek servis): sahiplik kayda yazılır.
	var service: Node = IapService.ensure(self)
	await process_frame
	await process_frame
	service.call("set_provider", MockIapProvider.new())
	service.call("buy_remove_ads")
	_check(bool(_progress.call("remove_ads_owned")), "satın alma sahiplik yazmalı")
	await _open_game(1)
	var total: int = 0
	for number: int in range(1, 10):
		var sheet: Control = await _solve(_par_of(number))
		if sheet == null:
			return
		_clock += GAP + 1.0
		total += await _next_level()
	_check(total == 0 and _provider.interstitial_shown == 0, "reklamlar kaldırılınca geçiş reklamı olmamalı")
	# Ödüllü reklam açık kalır: ipucu hâlâ bir reklam ister.
	var rewarded_before: int = _provider.rewarded_shown
	_press("HintButton")
	_check(_provider.rewarded_shown == rewarded_before + 1, "reklamlar kaldırılsa da ipucu ödüllü reklam ister")
	await _until(func() -> bool: return not bool(_game.get("_hint_showing")))
	_progress.call("set_remove_ads_owned", false)
	print("PROBE reklamlari_kaldir tamam")


# --- Geçiş 4: ödüllü izlenen seviyede geçiş reklamı yok ------------------------------------

func _pass_rewarded_suppression() -> void:
	_fresh_state()
	await _open_game(1)
	var ads: Array[int] = []
	for number: int in range(1, 10):
		if number == 6:
			# 6. seviye (sıra gelmişti): ipucu izlendi -> bu geçişte geçiş reklamı yok.
			_press("HintButton")
			await _until(func() -> bool: return not bool(_game.get("_hint_showing")))
		if number == 9:
			# 9. seviye (sıra gelmişti): atla -> geçiş reklamı yok.
			var before: int = _provider.interstitial_shown
			_press("SkipButton")
			(_game.get("_skip_sheet") as Node).find_child("WatchButton", true, false).emit_signal(&"pressed")
			await _until(func() -> bool: return _level_number() == 10)
			ads.append(_provider.interstitial_shown - before)
			continue
		var sheet: Control = await _solve(_par_of(number))
		if sheet == null:
			return
		_clock += GAP + 1.0
		ads.append(await _next_level())
	_check(ads == [0, 0, 1, 0, 0, 0, 0, 0, 0], "ödüllü izlenen 6 ve 9'da geçiş reklamı olmamalı: %s" % str(ads))
	print("PROBE odullu_baskilama tamam: reklam=%s" % str(ads))


# --- Geçiş 5: reklam hazır değil / yarım kaldı ---------------------------------------------

func _pass_unavailable_ad() -> void:
	_fresh_state()
	await _open_game(4)
	_provider.ready = false
	var rewarded_before: int = _provider.rewarded_shown
	_press("HintButton")
	await process_frame
	_check(_provider.rewarded_shown == rewarded_before, "hazır olmayan reklam gösterilmez")
	_check(not bool(_game.get("_hint_showing")) and bool(_game.get("_bar").call("hint_enabled")), "düğme takılmaz")
	_check(_has_toast(), "düğme nedenini söylemeli (toast)")
	_check(bool(_session().get("_input_enabled")), "saha girdisi açık kalmalı")
	_press("SkipButton")
	await process_frame
	_check(_game.get("_skip_sheet") == null, "reklam yokken atlama onayı açılmaz")
	_check(not LevelProgress.load_saved().is_skipped(_id_of(4)), "reklam yokken seviye atlanmaz")
	_provider.ready = true
	_provider.fail_reason = "dismissed_early"
	_press("HintButton")
	await process_frame
	_check(not bool(_game.get("_hint_showing")), "yarıda kapatılan reklam ipucu vermez")
	_check(bool(_game.get("_bar").call("hint_enabled")), "yarım kalan reklamda düğme açılır")
	_provider.fail_reason = ""
	print("PROBE reklam_yok tamam")


func _has_toast() -> bool:
	for child: Node in _game.get_children():
		if child is UiToast:
			return true
	return false


# --- Geçiş 6: duraklatma + ayarlar ---------------------------------------------------------

func _pass_pause_and_home() -> void:
	_fresh_state()
	await _open_game(2)
	_game.call("_on_pause_requested")
	await process_frame
	_check(paused, "duraklatma sayfası oyunu durdurmalı")
	var sheet: Node = null
	for child: Node in _game.get_children():
		var script: Script = child.get_script() as Script
		if script != null and script.get_global_name() == &"PauseSheet":
			sheet = child
	_check(sheet != null, "PauseSheet açılmalı")
	if sheet != null:
		sheet.call("close")
	await _until(func() -> bool: return not paused)
	_check(not paused, "duraklatma kalkmalı")
	# Ayarlar sayfasında reklam kaldırma satırı.
	var home: Node = _open_scene("res://scenes/Home.tscn")
	await process_frame
	home.call("_open_settings")
	await process_frame
	await process_frame
	_check(home.find_child("RemoveAdsButton", true, false) != null, "ayarlarda 'Reklamları kaldır' satırı olmalı")
	_check(home.find_child("RestoreButton", true, false) != null, "ayarlarda geri yükleme olmalı")
	print("PROBE duraklatma_ayarlar tamam")


func _check_real_save_untouched() -> void:
	var exists_now: bool = FileAccess.file_exists(SAVE_PATH)
	_check(exists_now == _save_existed, "gerçek kayıt dosyası oluşturulmamalı/silinmemeli")
	if exists_now:
		_check(FileAccess.get_file_as_string(SAVE_PATH) == _save_before, "gerçek kayıt DEĞİŞMEMELİ")
	print("PROBE gercek_kayit dokunulmadi (var=%s)" % str(exists_now))


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		printerr("PROBE HATA: %s" % message)
