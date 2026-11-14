class_name Loc
extends RefCounted

## Yerelleştirme yardımcısı: Godot'nun çeviri sunucusunun üstünde ince, statik bir katman.
## NEDEN statik sarmalayıcı: metin tutucu sınıflar (UiStrings vb.) RefCounted'dır; `tr()` ise
## bir Object örneği ister. Anahtarlar `data/i18n/strings.csv` içindedir (tr/en/es).

const LANG_TR: String = "tr"
const LANG_EN: String = "en"
const LANG_ES: String = "es"
const LANGUAGES: Array[String] = [LANG_TR, LANG_EN, LANG_ES]
## Cihaz dili desteklenmiyorsa düşülen dil.
const DEFAULT_UNKNOWN: String = LANG_EN
const SETTINGS_SECTION: String = "settings"
const SETTINGS_KEY: String = "language"
const PROGRESS_PATH: NodePath = ^"/root/Progress"


## Anahtarın geçerli dildeki karşılığı. Anahtar tabloda yoksa anahtarın kendisi döner.
static func t(key: String) -> String:
	return String(TranslationServer.translate(key))


## Biçimli metin: `args` sırasıyla %d/%s yerlerine konur.
static func f(key: String, args: Array) -> String:
	return t(key) % args


## Çoğul duyarlı seçim: 1 ise `key_one`, değilse `key_other`. Türkçede sayıdan sonra çoğul
## eki yoktur; tr satırları iki anahtarda da aynı metni taşır.
static func n(key_one: String, key_other: String, count: int) -> String:
	return t(key_one if count == 1 else key_other)


## Geçerli dil kodu (tr/en/es).
static func language() -> String:
	var code: String = TranslationServer.get_locale().substr(0, 2).to_lower()
	return code if code in LANGUAGES else DEFAULT_UNKNOWN


static func set_language(code: String) -> void:
	TranslationServer.set_locale(code if code in LANGUAGES else DEFAULT_UNKNOWN)


## Cihaz dilinden (OS) desteklenen dili seçer; bilinmeyen dil İngilizce olur.
static func detect_device_language() -> String:
	var code: String = OS.get_locale_language().to_lower()
	return code if code in LANGUAGES else DEFAULT_UNKNOWN


static func _progress() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null(PROGRESS_PATH)


## Kayıtlı dili uygular; ilk açılışta (kayıt yok) cihaz dilini seçip kaydeder.
## İlk ekran kurulmadan ÖNCE çağrılır (Boot), böylece hiçbir ekran yarım çevrilmiş açılmaz.
static func apply_saved() -> void:
	var progress: Node = _progress()
	var saved: String = ""
	if progress != null:
		saved = String(progress.call("module_value", SETTINGS_SECTION, SETTINGS_KEY, ""))
	if saved in LANGUAGES:
		set_language(saved)
		return
	var code: String = detect_device_language()
	set_language(code)
	if progress != null:
		progress.call("set_module_value", SETTINGS_SECTION, SETTINGS_KEY, code)


## Oyuncunun elle seçimi: uygular ve kaydeder (ekranı yeniden kurmak çağırana aittir).
static func choose(code: String) -> void:
	set_language(code)
	var progress: Node = _progress()
	if progress != null:
		progress.call("set_module_value", SETTINGS_SECTION, SETTINGS_KEY, language())


## Araçlar için: komut satırındaki `--lang=tr|en|es` (yoksa kaynak dil tr). Kayda yazmaz.
static func apply_from_args(args: PackedStringArray) -> void:
	var code: String = LANG_TR
	for arg: String in args:
		if arg.begins_with("--lang="):
			code = arg.split("=")[1]
	set_language(code)
