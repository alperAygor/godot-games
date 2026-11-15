extends SceneTree

## Dil probu (headless). Yedi dilin hepsi için:
##  A) tablo: her anahtar her dilde dolu, yer tutucular tr ile aynı, çeviri sunucusu her dilde anahtarı bulur;
##  B) dil değiştirme: ayarlar sayfasındaki dil düğmeleri GERÇEKTEN basılır (tr -> en -> es -> pt -> de -> ja -> ko),
##     sahne baştan kurulur, kayıt tutulur, yeniden açılışta kalıcıdır; oyun içi dil değişiminde seviye sahnesi yenilenir;
##  C) sığma: ana ekran, ayarlar, mağaza, harita, makineler, görevler, ödül yolu, haftalık, geri dönüş, günlük,
##     koleksiyon/çamaşırhane, çevrimdışı sayfası, öğretici kartları ve oyun sayfaları (duraklat/kazan/kaybet) açılır;
##     her Label/Button gerçek yazı tipiyle ölçülür: ata kutuların dışına taşan veya tek başına sığmayan metin
##     "PROBE TASMA" olarak anahtar ve düğüm yoluyla yazılır.
##   godot --headless --path . -s res://tools/lang_probe.gd            çıkış 0 = geçti (PROBE SONUC: gecti)
##   ... -- --lang=ja                                                  yalnız bir dil (sığma + dil değiştirme dışı)
## Oyuncunun gerçek kaydına ASLA yazmaz (persist=false).

const SETTLE_FRAMES: int = 3
const HOME_SCENE: String = "res://scenes/Home.tscn"
const GAME_SCENE: String = "res://scenes/Game.tscn"
const CSV_PATH: String = "res://data/i18n/strings.csv"
const TUTORIALS_PATH: String = "res://data/tutorials.json"
const PLAYER_LEVEL: int = 12
const FIT_LEVEL: int = 22
const MACHINE_LEVEL: int = 70
const FIT_COINS: int = 900
const TOLERANCE: float = 1.5
const TODAY: String = "2026-11-13"
const WEEK: String = "2026-11-09"
const RETENTION_STORE: String = "res://scripts/retention/retention_store.gd"
const PLACEHOLDER_PATTERN: String = "%[ds]"
## Başka işçinin dosyasındaki bilinen taşmalar: raporda ayrıca listelenir, probu düşürmez (docs/I18N.md "Düzen bulguları").
const KNOWN_OTHER_OWNER: Array[String] = []

var _progress: Node = null
var _started: bool = false
var _failed: bool = false
var _fit_failures: int = 0
var _fit_known: int = 0
var _fit_checked: int = 0
var _seen_fit: Dictionary[String, bool] = {}
var _only_lang: String = ""
var _table: Dictionary = {}
var _languages: Array[String] = []
var _lang_failed: Dictionary[String, bool] = {}
## Yalnız rakam/simge içeren etiketler (sayaç rozetleri, fiyatlar) çevrilmez ve serbest yerleşimlidir: denetim dışı.
var _numbers_only: RegEx = RegEx.new()


func _initialize() -> void:
	_progress = root.get_node("Progress")
	_progress.set("persist", false)
	AnalyticsLog.echo = false
	_numbers_only.compile("[^0-9\\s×+%/.,:\\-]")
	# Headless pencere 64x64'tür ve "expand" kipi mantıksal alanı 1920x1920'ye şişirir; KEEP kipi telefon
	# ölçüsünü (1080x1920) verir, böylece yerleşim gerçek ekranla aynı çözülür.
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--lang="):
			_only_lang = arg.split("=")[1]


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func _run() -> void:
	_languages = Loc.LANGUAGES.duplicate()
	if not _only_lang.is_empty():
		_languages = [_only_lang]
	_check_table()
	if _only_lang.is_empty():
		await _check_switching()
	for code: String in _languages:
		await _check_fit(code)
	for code: String in _languages:
		print("PROBE dil %s: %s" % [code, "BASARISIZ" if _lang_failed.get(code, false) else "gecti"])
	print("PROBE sigma: %d metin denetlendi, %d taşma, %d bilinen (başka sahip)" % [_fit_checked, _fit_failures, _fit_known])
	Loc.set_language(Loc.LANG_TR)
	print("PROBE SONUC: %s" % ("BASARISIZ" if _failed else "gecti"))
	quit(1 if _failed else 0)


# ---------------------------------------------------------------- A) tablo

func _placeholders(text: String) -> Array[String]:
	var found: Array[String] = []
	var regex: RegEx = RegEx.new()
	regex.compile(PLACEHOLDER_PATTERN)
	for hit: RegExMatch in regex.search_all(text.replace("%%", "")):
		found.append(hit.get_string())
	return found


func _check_table() -> void:
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	if file == null:
		_fail("", "CSV açılamadı")
		return
	var header: PackedStringArray = file.get_csv_line()
	var keys_checked: int = 0
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 2 or row[0].is_empty():
			continue
		keys_checked += 1
		_table[row[0]] = row
		if row.size() != header.size():
			_fail("", "%s: sütun sayısı %d (başlık %d)" % [row[0], row.size(), header.size()])
			continue
		var reference: Array[String] = _placeholders(row[1])
		for column: int in range(1, header.size()):
			var code: String = header[column]
			if row[column].strip_edges().is_empty():
				_fail(code, "%s: boş" % row[0])
			elif _placeholders(row[column]) != reference:
				_fail(code, "%s: yer tutucular tr ile uyuşmuyor" % row[0])
	for code: String in Loc.LANGUAGES:
		if not header.has(code):
			_fail(code, "CSV'de %s sütunu yok" % code)
			continue
		var table: Translation = TranslationServer.get_translation_object(code)
		if table == null or table.get_locale() != code:
			_fail(code, "çeviri sunucusunda %s tablosu yok (project.godot locale/translations)" % code)
			continue
		for key: String in _table.keys():
			if String(table.get_message(key)).is_empty():
				_fail(code, "%s: çeviri tablosunda yok" % key)
	print("PROBE tablo: %d anahtar x %d dil denetlendi" % [keys_checked, Loc.LANGUAGES.size()])


# ---------------------------------------------------------------- B) dil değiştirme

func _check_switching() -> void:
	_progress.call("reset_state")
	(_progress.get("data") as ProgressData).level = PLAYER_LEVEL
	Loc.set_language(Loc.LANG_TR)
	await _open_scene(HOME_SCENE)
	_check(_has_text(current_scene, Loc.f("LEVEL", [PLAYER_LEVEL])) and Loc.language() == "tr", "ana ekran tr açılmalı")
	var before: Node = current_scene
	# Dil düğmeleri sırayla gerçekten basılır; her basışta sahne baştan kurulur ve metin yeni dilde olur.
	for code: String in [Loc.LANG_EN, Loc.LANG_ES, Loc.LANG_PT, Loc.LANG_DE, Loc.LANG_JA, Loc.LANG_KO]:
		current_scene.call("_open_settings")
		await _settle()
		var pill: Button = _language_pill(code)
		_check(pill != null, "ayarlarda %s düğmesi bulunmalı" % code)
		if pill == null:
			continue
		var native: String = String(Loc.NATIVE_NAMES[code])
		_check(_has_text(pill, native), "%s düğmesi yerel adı taşımalı: %s" % [code, native])
		before = current_scene
		pill.pressed.emit()
		await _settle(SETTLE_FRAMES * 2)
		_check(current_scene != null and current_scene != before, "%s: dil değişince ana ekran baştan kurulmalı" % code)
		_check(Loc.language() == code, "dil %s olmalı" % code)
		_check(String(_progress.call("module_value", Loc.SETTINGS_SECTION, Loc.SETTINGS_KEY, "")) == code, "seçim kayda yazılmalı: %s" % code)
		_check(_has_text(current_scene, Loc.f("LEVEL", [PLAYER_LEVEL])), "%s: oynat düğmesi yeni dilde olmalı" % code)
		_check(not _has_text(current_scene, "Seviye"), "%s: eski dilden metin kalmamalı" % code)
		# Yeniden açılış: yerel ayar başka dile düşse de kayıtlı dil geri gelir.
		Loc.set_language(Loc.LANG_TR)
		Loc.apply_saved()
		_check(Loc.language() == code, "kayıtlı dil yeniden açılışta uygulanmalı: %s" % code)
	print("PROBE ana ekran: tr -> en/es/pt/de/ja/ko düğmeleri basıldı, sahne yenilendi, kayıt kalıcı")
	# Oyun sahnesi son dilde (ko) duraklatılır; oyun içinde dil değişince sahne yeni dille yeniden kurulur.
	await _open_scene(GAME_SCENE)
	current_scene.call("_on_pause_requested")
	await _settle()
	_check(_has_text(current_scene, Loc.t("PAUSED")) and Loc.t("PAUSED") != "PAUSED", "ko: duraklatma sayfası çevrilmiş olmalı")
	Loc.set_language(Loc.LANG_EN)
	before = current_scene
	root.get_node("GameManager").call("reload_scene")
	await _settle(SETTLE_FRAMES * 2)
	_check(current_scene != null and current_scene != before, "oyun sahnesi baştan kurulmalı")
	current_scene.call("_on_pause_requested")
	await _settle()
	_check(_has_text(current_scene, "Paused"), "oyun içi dil değişimi: duraklatma en olmalı")
	print("PROBE oyun içinde dil değişimi: sahne yeniden kuruldu, metinler yeni dilde")
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	await _settle()


# ---------------------------------------------------------------- C) sığma

func _check_fit(code: String) -> void:
	Loc.set_language(code)
	_progress.call("reset_state")
	_seed_player(FIT_LEVEL)
	(load(RETENTION_STORE) as GDScript).set("today_override", TODAY)
	await _open_scene(HOME_SCENE)
	var home: Node = current_scene
	_preseed_tutorial(home)
	await _settle()
	_audit(code, "home", _all_nodes(root))
	# Ana ekran üstündeki sayfalar: her biri yalnız YENİ düğümleri denetler.
	await _screen(code, "settings", func() -> void: home.call("_open_settings"))
	await _screen(code, "shop", func() -> void: (load("res://scripts/shop/shop.gd") as GDScript).call("open", home))
	await _screen(code, "map", func() -> void: (load("res://scripts/map/level_map.gd") as GDScript).call("open", home))
	await _screen(code, "zen", func() -> void: (load("res://scripts/zen/zen_card.gd") as GDScript).call("open", home))
	await _screen(code, "map_card", func() -> void: (load("res://scripts/map/map_card.gd") as GDScript).call("open", home, 31))
	for state: int in range(3):
		_seed_missions(state)
		await _screen(code, "missions%d" % state, func() -> void: _retention_open("missions", home))
	await _screen(code, "milestones", func() -> void: _retention_open("milestones", home))
	for theme: String in ["blue", "red", "green", "yellow", "purple", "chain", "baskets", "stars"]:
		_progress.call("set_module_value", "retention", "weekly", {"week": WEEK, "theme": theme, "progress": 18, "claimed": [1, 0, 0, 0, 0]})
		await _screen(code, "weekly_" + theme, func() -> void: _retention_open("weekly", home))
	_progress.call("set_module_value", "retention", "comeback", {"last_day": TODAY, "run": 1, "pending": {
		"reward": {"coins": 90, "stars": 0, "boosters": {"undo": 1}}, "away": 4, "streak": 0}})
	await _screen(code, "comeback", func() -> void: (load("res://scripts/retention/comeback_sheet.gd") as GDScript).call("open", home))
	_progress.call("set_module_value", "retention", "comeback", {"last_day": TODAY, "run": 3, "pending": {
		"reward": {"coins": 15, "stars": 0, "boosters": {}}, "away": 0, "streak": 3}})
	await _screen(code, "streak", func() -> void: (load("res://scripts/retention/comeback_sheet.gd") as GDScript).call("open", home))
	await _screen(code, "daily_card", func() -> void: (load("res://scripts/daily/daily_puzzle.gd") as GDScript).call("open_card", home))
	await _screen(code, "daily_calendar", func() -> void: (load("res://scripts/daily/daily_calendar.gd") as GDScript).call("open", home))
	await _screen(code, "laundromat", func() -> void: home.add_child((load("res://scenes/meta/Laundromat.tscn") as PackedScene).instantiate()))
	await _screen(code, "collection", func() -> void: home.add_child((load("res://scenes/meta/Collection.tscn") as PackedScene).instantiate()))
	var checker: RefCounted = (load("res://scripts/net/online_checker.gd") as GDScript).new() as RefCounted
	await _screen(code, "offline", func() -> void: (load("res://scripts/net/online_sheet.gd") as GDScript).call("open", home, checker))
	# Makineler sayfası daha yüksek seviyede açılır.
	_seed_player(MACHINE_LEVEL)
	await _screen(code, "machines", func() -> void: MachineUpgrades.open(home))
	await _fit_cards(code)
	_check_title(code)
	await _fit_game(code)
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
	await _settle()


func _seed_player(level: int) -> void:
	(_progress.get("data") as ProgressData).level = level
	(_progress.get("data") as ProgressData).coins = FIT_COINS
	_progress.call("add_stars", 3)


func _seed_missions(state: int) -> void:
	var sets: Array = [
		[["levels", 3, 2, 20], ["baskets", 8, 3, 20], ["chain", 3, 0, 30]],
		[["stars3", 2, 1, 20], ["low_rack", 2, 0, 20], ["daily", 1, 0, 30]],
		[["booster", 2, 0, 20], ["bird", 3, 1, 20], ["cat", 4, 2, 30]],
	]
	var items: Array = []
	for entry: Array in sets[state]:
		items.append({"id": entry[0], "target": entry[1], "progress": entry[2], "claimed": false, "reward": {"coins": entry[3]}})
	_progress.call("set_module_value", "retention", "missions", {"day": TODAY, "chest": false, "items": items})


func _retention_open(kind: String, parent: Node) -> void:
	(load("res://scripts/retention/retention_hub.gd") as GDScript).call("open_sheet", kind, parent)


## Bir sayfayı açar, yerleşimin oturmasını bekler, YALNIZ yeni düğümleri denetler.
func _screen(code: String, name: String, action: Callable) -> void:
	var seen: Dictionary[int, bool] = _snapshot()
	action.call()
	await _settle()
	var fresh: Array[Node] = []
	for node: Node in _all_nodes(root):
		if not seen.has(node.get_instance_id()):
			fresh.append(node)
	_audit(code, name, fresh)


func _fit_cards(code: String) -> void:
	var spec_all: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string(TUTORIALS_PATH)) as Dictionary)["cards"]
	var palette: Array[Color] = []
	for feature: String in TutorialStrings.CARDS.keys():
		var seen: Dictionary[int, bool] = _snapshot()
		var card: TutorialCard = TutorialCard.new()
		root.add_child(card)
		card.setup(feature, spec_all[feature] as Dictionary, palette)
		await _settle()
		var fresh: Array[Node] = []
		for node: Node in _all_nodes(card):
			if not seen.has(node.get_instance_id()):
				fresh.append(node)
		_audit(code, "card_" + feature, fresh)
		card.queue_free()
		await _settle(1)


## Açılış ekranının başlığı: sahne kurulmadan yazı tipiyle ölçülür (Boot yönlendirir, açılamaz).
func _check_title(code: String) -> void:
	var boot: Node = (load("res://scenes/Boot.tscn") as PackedScene).instantiate()
	var title: Label = boot.get_node("Center/Column/Title") as Label
	var font: Font = LocFonts.base_font()
	var size: int = title.get_theme_font_size(&"font_size")
	var width: float = font.get_string_size(Loc.t("GAME_TITLE"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	_fit_checked += 1
	if width > root.get_visible_rect().size.x - 2.0 * TOLERANCE:
		_report_fit(code, "boot", "GAME_TITLE", "Boot/Title", "genişlik %d > ekran %d" % [int(width), int(root.get_visible_rect().size.x)])
	boot.free()


func _fit_game(code: String) -> void:
	for name: String in ["game", "pause", "win", "lose", "lose_moves", "lose_many"]:
		await _open_scene(GAME_SCENE)
		var game: Node = current_scene
		_preseed_tutorial(game)
		await _settle(SETTLE_FRAMES * 2)
		var seen: Dictionary[int, bool] = _snapshot()
		match name:
			"pause":
				game.call("_on_pause_requested")
			"win":
				game.call("_show_win")
			"lose":
				game.call("_show_lose", 4)
			"lose_many":
				game.call("_show_lose", 11)
			"lose_moves":
				(game.get("_board") as LaundryBoard).set("_lose_reason", LaundryBoard.LOSE_MOVES)
				game.call("_show_lose", 4)
		await _settle()
		var fresh: Array[Node] = []
		for node: Node in _all_nodes(root):
			if name == "game" or not seen.has(node.get_instance_id()):
				fresh.append(node)
		_audit(code, "game_" + name, fresh)


## Tanıtım kartları ekranı örtmesin: tüm kartlar "görüldü" sayılır (yalnız bellekte).
func _preseed_tutorial(scene: Node) -> void:
	if scene.get("_tutorial") is TutorialDirector:
		var flags: Array[String] = []
		for feature: String in TutorialStrings.CARDS.keys():
			flags.append("tut_card_%s" % feature)
		(scene.get("_tutorial") as TutorialDirector).preseed_seen(flags)


func _snapshot() -> Dictionary[int, bool]:
	var seen: Dictionary[int, bool] = {}
	for node: Node in _all_nodes(root):
		seen[node.get_instance_id()] = true
	return seen


## Metin denetimi: (1) her Label/Button ata kutularının (en yakından ekrana) yatay sınırı içinde kalmalı,
## düşey sınır yalnız ekrana karşı (kaydırma kutusu dışında); (2) kırpan/üç nokta koyan denetimlerde metin kutuya
## sığmalı; (3) kelime kırılabilen etiketlerde en uzun TEK kelime etiket genişliğine sığmalı.
func _audit(code: String, screen: String, nodes: Array[Node]) -> void:
	for node: Node in nodes:
		if not (node is Label or node is Button):
			continue
		var control: Control = node as Control
		if not control.is_visible_in_tree():
			continue
		var text: String = String(control.get("text"))
		if text.strip_edges().is_empty() or _numbers_only.search(text) == null:
			continue
		_fit_checked += 1
		var font: Font = control.get_theme_font(&"font")
		var size: int = control.get_theme_font_size(&"font_size")
		var key: String = _key_for(text)
		var message: String = _clipped(control, font, size, text)
		if message.is_empty():
			message = _long_word(control, font, size, text)
		if message.is_empty():
			message = _outside_ancestors(control)
		if not message.is_empty():
			_report_fit(code, screen, key, _node_path(control), message)


func _clipped(control: Control, font: Font, size: int, text: String) -> String:
	var clips: bool = false
	if control is Label:
		var label: Label = control as Label
		clips = label.clip_text or label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
			clips = false
	elif control is Button:
		clips = (control as Button).clip_text
	if not clips:
		return ""
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	if width > control.size.x + TOLERANCE:
		return "metin %d px > kutu %d px (kırpılır)" % [int(width), int(control.size.x)]
	return ""


func _long_word(control: Control, font: Font, size: int, text: String) -> String:
	if not (control is Label) or (control as Label).autowrap_mode == TextServer.AUTOWRAP_OFF:
		return ""
	var longest: float = 0.0
	var longest_word: String = ""
	for word: String in text.replace("⁠", "").split(" ", false):
		var width: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
		if width > longest:
			longest = width
			longest_word = word
	# CJK metinde boşluk yoktur: yalnız Latin dillerde tek-kelime denetimi anlamlıdır.
	if Loc.language() == Loc.LANG_JA or Loc.language() == Loc.LANG_KO:
		return ""
	if longest > control.size.x + TOLERANCE and control.size.x > 0.0:
		return "'%s' %d px > etiket %d px" % [longest_word, int(longest), int(control.size.x)]
	return ""


func _outside_ancestors(control: Control) -> String:
	var offset: Vector2 = control.position
	var in_scroll: bool = false
	var parent: Node = control.get_parent()
	while parent is Control:
		var holder: Control = parent as Control
		if holder is ScrollContainer:
			in_scroll = true
		# Boyutsuz (0 px) ata, serbest yerleşimli rozet/kaplama taşıyıcısıdır: sınır sayılmaz.
		var sized: bool = holder.size.x > 0.0
		if sized and (offset.x < -TOLERANCE or offset.x + control.size.x > holder.size.x + TOLERANCE):
			return "yatay taşma: x=%d..%d, ata '%s' genişliği %d" % [int(offset.x), int(offset.x + control.size.x), holder.name, int(holder.size.x)]
		offset += holder.position
		parent = holder.get_parent()
	# Çizim düğümlerinin (Node2D) içindeki etiketler çizimin parçasıdır; ekran yerleşimi sayılmaz.
	if parent is CanvasItem:
		return ""
	var view: Vector2 = root.get_visible_rect().size
	if offset.x < -TOLERANCE or offset.x + control.size.x > view.x + TOLERANCE:
		return "ekran dışı: x=%d..%d (ekran %d)" % [int(offset.x), int(offset.x + control.size.x), int(view.x)]
	if not in_scroll and (offset.y < -TOLERANCE or offset.y + control.size.y > view.y + TOLERANCE):
		return "ekran dışı: y=%d..%d (ekran %d)" % [int(offset.y), int(offset.y + control.size.y), int(view.y)]
	return ""


func _key_for(text: String) -> String:
	var plain: String = text.replace("⁠", "")
	for key: String in _table.keys():
		var row: PackedStringArray = _table[key]
		for column: int in range(1, row.size()):
			if row[column] == plain:
				return key
	return "(dinamik metin)"


func _node_path(node: Node) -> String:
	var parts: Array[String] = []
	var cursor: Node = node
	while cursor != null and cursor != root:
		parts.push_front(String(cursor.name))
		cursor = cursor.get_parent()
	return "/".join(parts)


func _report_fit(code: String, screen: String, key: String, path: String, message: String) -> void:
	var line: String = "%s|%s|%s|%s" % [code, screen, key, message]
	if _seen_fit.has(line):
		return
	_seen_fit[line] = true
	var known: bool = false
	for owner_pattern: String in KNOWN_OTHER_OWNER:
		if path.contains(owner_pattern) or screen.contains(owner_pattern):
			known = true
	if known:
		_fit_known += 1
		print("PROBE TASMA (bilinen) [%s] %s  anahtar=%s  yol=%s  %s" % [code, screen, key, path, message])
		return
	_fit_failures += 1
	printerr("PROBE TASMA [%s] %s  anahtar=%s  yol=%s  %s" % [code, screen, key, path, message])
	_fail(code, "taşma")


# ---------------------------------------------------------------- yardımcılar

func _settle(frames: int = SETTLE_FRAMES) -> void:
	for _i: int in frames:
		await process_frame


func _open_scene(path: String) -> void:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await process_frame
	var scene: Node = (load(path) as PackedScene).instantiate()
	if path == GAME_SCENE:
		scene.set("_persist", false)
		scene.set("_level_number", FIT_LEVEL)
	root.add_child(scene)
	current_scene = scene
	await _settle()


## Ayarlar sayfasındaki dil düğmesi (adı "Lang_<kod>").
func _language_pill(code: String) -> Button:
	for node: Node in _all_nodes(current_scene):
		if node is UiLanguageRow:
			return (node as UiLanguageRow).find_child("Lang_" + code, true, false) as Button
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


func _fail(code: String, message: String) -> void:
	_failed = true
	if not code.is_empty():
		_lang_failed[code] = true
	printerr("PROBE HATA%s: %s" % [(" [%s]" % code) if not code.is_empty() else "", message])


func _check(ok: bool, message: String) -> void:
	if not ok:
		_fail("", message)
