extends SceneTree

## Dil değiştirme probu (headless): ayarlar sayfasındaki dil düğmesi GERÇEKTEN basılır.
##  (a) Ana ekranda tr -> en: sahne baştan kurulur, düğme/etiket metinleri yeni dilde, kayıt "en" der;
##  (b) seçilen dil kayıtta kalır: yerel ayar sıfırlanıp `Loc.apply_saved` ile geri gelir (yeniden açılış);
##  (c) es: ana ekran ve oyun sahnesi (duraklatma sayfası) yeni dilde kurulur;
##  (d) oyunun içinde dil değişse bile (GameManager.reload_scene) seviye sahnesi yeni dille yeniden kurulur;
##  (e) tablodaki HER anahtar her dilde çözülür (eksik/boş çeviri yok, anahtar ham görünmez).
##   godot --headless --path . -s res://tools/lang_probe.gd      çıkış 0 = geçti
## Oyuncunun gerçek kaydına ASLA yazmaz (persist=false).
## NOT: `-s` betiği autoload'lardan ÖNCE derlenir; autoload'a değen UI sınıfları tür olarak anılmaz
## (bkz. play_probe.gd). `Loc`, `UiLanguageRow`, `ProgressData` güvenlidir.

const SETTLE_FRAMES: int = 6
const HOME_SCENE: String = "res://scenes/Home.tscn"
const GAME_SCENE: String = "res://scenes/Game.tscn"
const CSV_PATH: String = "res://data/i18n/strings.csv"
## Oyuncu ilk 3 seviyeyi bitirmiş: ana ekran "Seviye 4" yazar.
const SOLVED_LEVELS: int = 3
const PLAYER_LEVEL: int = SOLVED_LEVELS + 1
const WATCHDOG_SECONDS: float = 60.0

var _progress: Node = null
var _failed: bool = false
var _finished: bool = false
var _elapsed: float = 0.0


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
	# Autoload `_ready`leri bu betiğin `_initialize`inden sonra çalışır: kayıt ilk kareden sonra sıfırlanır.
	await process_frame
	_progress.call("reset_state")
	var entries: Array[Dictionary] = LevelCatalog.entries()
	var finished: LevelProgress = LevelProgress.new()
	for index: int in SOLVED_LEVELS:
		var level_id: String = str(entries[index]["id"])
		finished.record_solve(level_id, int(entries[index]["par"]), int(entries[index]["par"]), 0)
		finished.save(level_id)
	Loc.set_language(Loc.LANG_TR)
	_check_all_keys_resolve()
	await _home_flow()
	await _game_flow()
	Loc.set_language(Loc.LANG_TR)
	_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("PROBE SONUC: %s" % ("BASARISIZ" if _failed else "gecti"))
	quit(1 if _failed else 0)


# --- (e) tablo -------------------------------------------------------------------------------

func _check_all_keys_resolve() -> void:
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	_check(file != null, "strings.csv açılmalı")
	if file == null:
		return
	file.get_csv_line()
	var rows: Array[PackedStringArray] = []
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() >= 4 and not row[0].is_empty():
			rows.append(row)
	_check(rows.size() > 10, "tabloda anahtar bulunmalı")
	for code: String in Loc.LANGUAGES:
		Loc.set_language(code)
		# Sütun sırası: keys, tr, en, es -> dil kodunun dizini + 1.
		var column: int = Loc.LANGUAGES.find(code) + 1
		var missing: Array[String] = []
		for row: PackedStringArray in rows:
			var text: String = Loc.t(row[0])
			# Çeviri çözülmediyse motor anahtarın kendisini döndürür; "OK" gibi anahtarla aynı olan
			# gerçek metin için karşılaştırma tablodaki hücreyle yapılır.
			if text.is_empty() or text != row[column]:
				missing.append(row[0])
		_check(missing.is_empty(), "%s: çözülmeyen/uyuşmayan anahtarlar: %s" % [code, str(missing)])
	Loc.set_language(Loc.LANG_TR)
	print("PROBE %d anahtar x %d dil çözüldü" % [rows.size(), Loc.LANGUAGES.size()])


# --- (a)(b)(c) ana ekran ------------------------------------------------------------------------

func _home_flow() -> void:
	_open_scene(HOME_SCENE)
	await _frames(SETTLE_FRAMES)
	_check(_has_text(current_scene, Loc.f("LEVEL", [PLAYER_LEVEL])) and Loc.language() == "tr", "ana ekran tr açılmalı")
	current_scene.call("_open_settings")
	await _frames(SETTLE_FRAMES)
	var before: Node = current_scene
	var pill: Button = _language_pill("en")
	_check(pill != null, "ayarlarda EN düğmesi bulunmalı")
	if pill != null:
		pill.pressed.emit()
	await _frames(SETTLE_FRAMES * 2)
	_check(current_scene != null and current_scene != before, "dil değişince ana ekran baştan kurulmalı")
	_check(Loc.language() == "en", "dil en olmalı")
	_check(String(_progress.call("module_value", Loc.SETTINGS_SECTION, Loc.SETTINGS_KEY, "")) == "en", "seçim kayda yazılmalı")
	_check(_has_text(current_scene, "Level %d" % PLAYER_LEVEL), "oyna düğmesi yeni dilde olmalı: Level %d" % PLAYER_LEVEL)
	_check(not _has_text(current_scene, "Seviye"), "eski dilden metin kalmamalı")
	# Yeniden açılış: yerel ayar başka dile düşse de kayıtlı dil geri gelir.
	Loc.set_language(Loc.LANG_TR)
	Loc.apply_saved()
	_check(Loc.language() == "en", "kayıtlı dil yeniden açılışta uygulanmalı")
	print("PROBE ana ekran tr->en: yeniden kuruldu, kayıt=en, yeniden açılışta kalıcı")
	current_scene.call("_open_settings")
	await _frames(SETTLE_FRAMES)
	pill = _language_pill("es")
	_check(pill != null, "ayarlarda ES düğmesi bulunmalı")
	before = current_scene
	if pill != null:
		pill.pressed.emit()
	await _frames(SETTLE_FRAMES * 2)
	_check(Loc.language() == "es" and _has_text(current_scene, "Nivel %d" % PLAYER_LEVEL), "es: ana ekran Nivel olmalı")
	print("PROBE ana ekran en->es tamam")


# --- (c)(d) oyun sahnesi ---------------------------------------------------------------------

func _game_flow() -> void:
	_open_scene(GAME_SCENE)
	await _frames(SETTLE_FRAMES * 2)
	current_scene.call("_on_pause_requested")
	await _frames(SETTLE_FRAMES)
	_check(_has_text(current_scene, Loc.t("PAUSED")) and Loc.t("PAUSED") == "En pausa", "duraklatma sayfası es olmalı")
	_check(_has_text(current_scene, "Movimientos") and _has_text(current_scene, "Nivel %d" % PLAYER_LEVEL),
		"es: oyun ekranı HUD'u (Movimientos, Nivel %d)" % PLAYER_LEVEL)
	# Oyunun içinde dil değişir: sahne yeni dille yeniden kurulur.
	Loc.set_language(Loc.LANG_EN)
	var before: Node = current_scene
	root.get_node("GameManager").call("reload_scene")
	await _frames(SETTLE_FRAMES * 2)
	_check(current_scene != null and current_scene != before, "oyun sahnesi baştan kurulmalı")
	current_scene.call("_on_pause_requested")
	await _frames(SETTLE_FRAMES)
	_check(_has_text(current_scene, "Paused") and not _has_text(current_scene, "En pausa"),
		"oyun içi dil değişimi: duraklatma en olmalı")
	_check(_has_text(current_scene, "Moves") and _has_text(current_scene, "Level %d" % PLAYER_LEVEL),
		"en: oyun ekranı HUD'u (Moves, Level %d)" % PLAYER_LEVEL)
	_check(_has_text(current_scene, "Par"), "en: Par başlığı")
	print("PROBE oyun içinde dil değişimi: sahne yeniden kuruldu, metinler yeni dilde")


func _open_scene(path: String) -> void:
	if current_scene != null:
		current_scene.free()
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene


## Ayarlar sayfasındaki dil hapı (düğme içinde TR/EN/ES etiketi olan).
func _language_pill(code: String) -> Button:
	for node: Node in _all_nodes(current_scene):
		if node is UiLanguageRow:
			for button: Node in _all_nodes(node):
				if button is Button and _has_text(button, code.to_upper()):
					return button as Button
	return null


func _all_nodes(from: Node) -> Array[Node]:
	var found: Array[Node] = [from]
	for child: Node in from.get_children():
		found.append_array(_all_nodes(child))
	return found


func _has_text(from: Node, text: String) -> bool:
	for node: Node in _all_nodes(from):
		if node is Label and (node as Label).text == text:
			return true
		if node is Button and (node as Button).text == text:
			return true
	return false


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failed = true
		printerr("PROBE HATA: %s" % message)
