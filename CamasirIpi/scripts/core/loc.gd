class_name Loc
extends RefCounted

## Yerelleştirme yardımcısı: Godot'nun çeviri sunucusunun üstünde ince, statik bir katman.
## NEDEN statik sarmalayıcı: metin tutucu sınıflar (UiStrings vb.) RefCounted'dır; `tr()` ise
## bir Object örneği ister. Anahtarlar `data/i18n/strings.csv` içindedir (tr/en/es/pt/de/ja/ko).

const LANG_TR: String = "tr"
const LANG_EN: String = "en"
const LANG_ES: String = "es"
const LANG_PT: String = "pt"
const LANG_DE: String = "de"
const LANG_JA: String = "ja"
const LANG_KO: String = "ko"
## Seçicideki sıra: kaynak dil, İngilizce, sonra pazar sırasıyla diğerleri.
const LANGUAGES: Array[String] = [LANG_TR, LANG_EN, LANG_ES, LANG_PT, LANG_DE, LANG_JA, LANG_KO]
## Her dil kendi adıyla gösterilir (seçici hangi dilde açıksa açık olsun okunur).
const NATIVE_NAMES: Dictionary[String, String] = {
	LANG_TR: "Türkçe", LANG_EN: "English", LANG_ES: "Español", LANG_PT: "Português",
	LANG_DE: "Deutsch", LANG_JA: "日本語", LANG_KO: "한국어",
}
## Eksik anahtar için bakılan diller (sırayla). Kaynak doğruluk tr'dir ama yabancı oyuncu için İngilizce
## daha iyi yedektir; tr en sona kalır.
const KEY_FALLBACK: Array[String] = [LANG_EN, LANG_TR]
const HANGUL_FIRST: int = 0xAC00
const HANGUL_LAST: int = 0xD7A3
const WORD_JOINER: String = "\u2060"
static var _ko_cache: Dictionary[String, String] = {}
## Cihaz dili desteklenmiyorsa düşülen dil.
const DEFAULT_UNKNOWN: String = LANG_EN
const SETTINGS_SECTION: String = "settings"
const SETTINGS_KEY: String = "language"
const PROGRESS_PATH: NodePath = ^"/root/Progress"


## Anahtarın geçerli dildeki karşılığı. Geçerli dilde yoksa sırayla en, tr denenir; hiçbirinde yoksa
## anahtarın kendisi döner.
static func t(key: String) -> String:
	var text: String = String(TranslationServer.translate(key))
	if text == key or text.is_empty():
		text = _fallback_text(key)
	return _keep_hangul_words(text) if language() == LANG_KO else text


static func _fallback_text(key: String) -> String:
	for code: String in KEY_FALLBACK:
		var table: Translation = TranslationServer.get_translation_object(code)
		if table != null:
			var found: String = String(table.get_message(key))
			if not found.is_empty():
				return found
	return key


## Korece satır kırma: Godot hece arasında da kırar ("옷걸이/와"). Kelimeyi bölmemek için Hangul heceleri arasına
## görünmez WORD JOINER (U+2060) konur (CSS `word-break: keep-all` karşılığı); kırılma yalnız boşlukta olur.
## Sonuç bellekte tutulur (her çağrıda yeniden hesaplanmaz).
static func _keep_hangul_words(text: String) -> String:
	if _ko_cache.has(text):
		return _ko_cache[text]
	var joined: String = ""
	var previous_hangul: bool = false
	for index: int in text.length():
		var code: int = text.unicode_at(index)
		var is_hangul: bool = code >= HANGUL_FIRST and code <= HANGUL_LAST
		if is_hangul and previous_hangul:
			joined += WORD_JOINER
		joined += text[index]
		previous_hangul = is_hangul
	_ko_cache[text] = joined
	return joined


## Biçimli metin: `args` sırasıyla %d/%s yerlerine konur.
static func f(key: String, args: Array) -> String:
	return t(key) % args


## Çoğul duyarlı seçim: 1 ise `key_one`, değilse `key_other`. tr/ja/ko'da sayıdan sonra çoğul
## biçimi yoktur; o dillerin satırları iki anahtarda da aynı metni taşır. en/es/pt/de için kural "tam 1 = tekil"
## (CLDR pt'de 0'ı da tekil sayar; oyunda 0'lı çoğul cümle yok, bu yüzden basit kural yeter).
static func n(key_one: String, key_other: String, count: int) -> String:
	return t(key_one if count == 1 else key_other)


## Geçerli dil kodu (LANGUAGES içinden).
static func language() -> String:
	var code: String = TranslationServer.get_locale().substr(0, 2).to_lower()
	return code if code in LANGUAGES else DEFAULT_UNKNOWN


static func set_language(code: String) -> void:
	var applied: String = code if code in LANGUAGES else DEFAULT_UNKNOWN
	TranslationServer.set_locale(applied)
	LocFonts.apply(applied)


## Yerel ayar dizgesini ("pt_BR", "pt-PT", "de_AT", "ja_JP", "ko-KR", "zh_Hans_CN"...) desteklenen dile
## eşler: yalnız dil kısmı bakılır (bölge/yazı farkı yok). Bilinmeyen -> DEFAULT_UNKNOWN (İngilizce).
static func language_for_locale(locale: String) -> String:
	var head: String = locale.strip_edges().to_lower().replace("-", "_").split("_")[0]
	return head if head in LANGUAGES else DEFAULT_UNKNOWN


## Cihaz dilinden (OS) desteklenen dili seçer; bilinmeyen dil İngilizce olur.
static func detect_device_language() -> String:
	return language_for_locale(OS.get_locale())


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


## Araçlar için: komut satırındaki `--lang=tr|en|es|pt|de|ja|ko` (yoksa kaynak dil tr). Kayda yazmaz.
static func apply_from_args(args: PackedStringArray) -> void:
	var code: String = LANG_TR
	for arg: String in args:
		if arg.begins_with("--lang="):
			code = arg.split("=")[1]
	set_language(code)
