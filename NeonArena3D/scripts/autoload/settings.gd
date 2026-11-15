extends Node
## Kalıcı ayarlar + istatistikler + koşu bayrakları. Dokunmatik/masaüstü ayrımı da burada yapılır.
##
## KAYIT BİÇİMİ (ConfigFile metni, dosya adı değişmedi): `user://neon_arena_3d.cfg`
##   v1 (eski): [game] [audio] [video] [score] [meta]; sürüm alanı ve bütünlük işareti yok.
##   v2 (şimdiki): v1 bölümleri + [save] schema_version/counter/written_at, [flags], [entitlements]
##                 ve dosya sonunda [integrity] md5 (gövdenin MD5'i). Eski sürümler v2 dosyasını okuyabilir
##                 (bilmedikleri bölümleri yok sayar); v2 sürümü ise bilmediği bölüm/anahtarları KORUR.
## YAZIM: gövde `.tmp`'ye yazılır → geri okunup doğrulanır → geçerli ana dosya `.bak`'a kopyalanır → `.tmp`
##   ana dosyanın üzerine yeniden adlandırılır (atomik). Yarım kalan yazım asla ana dosyayı bozmaz.
## YÜKLEME: ana dosya, `.tmp` (yazım yeniden adlandırmadan önce kesildiyse) ve `.bak` incelenir; bütünlüğü
##   doğrulanan en yüksek `counter` kazanır. Hiçbiri geçerli değilse varsayılanlar yüklenir ve bozuk dosya
##   `.corrupt` olarak SAKLANIR (üzerine yazılmaz). Gelecekteki sürümden (schema_version > bilinen) dosya
##   okunur, bilinmeyenler korunur ve ilk yazımdan önce `.v<N>.bak` olarak yedeklenir. Eski (v1) dosya da göçten önce
##   aynı şekilde `.v1.bak` olarak bir kez saklanır.
## YALITIM: `--save-path=<yol>` kayıt yolunu değiştirir (testler/araçlar). `--demo` / `--no-save`: diske HİÇ yazılmaz
##   ve gerçek dosya okunmaz (varsayılanlarla başlar). Başsız (headless) modda yalnız `--save-path` ile yazılır.

signal changed(key: String)

const DEFAULT_PATH := "user://neon_arena_3d.cfg"
const SCHEMA_VERSION := 2
const QUALITY_NAMES := ["DÜŞÜK", "ORTA", "YÜKSEK"]
const LANGUAGES := ["tr", "en"]
const INTEGRITY_MARK := "\n[integrity]\n"
const KNOWN_KEYS := {
	"save": ["schema_version", "counter", "written_at", "app_version"],
	"game": ["language", "vibration", "auto_fire", "auto_fire_touch", "shake", "tutorial_done"],
	"audio": ["music", "sfx"],
	"video": ["show_fps", "quality"],
	"score": ["best", "best_wave", "kills", "runs"],
	"meta": ["state"],
	"flags": ["state"],
	"entitlements": ["state"],
}
const DEFAULT_FLAGS := {
	"ads_removed": false, "tutorial_done": false, "daily_bonus_date": "", "run_counter": 0,
	"last_transition_time": 0, "last_seen_unix": 0,
}
const MAX_COUNT := 2000000000
const CLOCK_TOLERANCE := 300

var save_path := DEFAULT_PATH
var touch := false
var persist := true
var language := "tr"
var music := 0.7
var sfx := 0.9
var vibration := true
var auto_fire := true
var quality := 2
var shake := true
var show_fps := false

var best := 0
var best_wave := 0
var total_kills := 0
var runs := 0
var meta: MetaProgress
## Koşu/mağaza bayrakları (kayıtlı): ads_removed, tutorial_done, daily_bonus_date ("YYYY-MM-DD"),
## run_counter (kayıtlı koşu sayacı; reklam aralığı için), last_transition_time (unix), last_seen_unix (saat yüksek-su işareti).
var flags: Dictionary = DEFAULT_FLAGS.duplicate(true)
## Satın alma hakları: {kimlik: true}. Örn. "remove_ads". (A2 doldurur.)
var entitlements: Dictionary = {}
## Son yükleme raporu: source (main|tmp|bak|none), version, recovered, problems[], legacy_migrated.
var load_report: Dictionary = {"source": "none", "version": 0, "recovered": false, "problems": [], "legacy_migrated": false}
var last_save_error := ""
var clock_rollback := false
## Testler için: >= 0 ise "şimdi" bu unix zamanıdır.
var clock_override := -1
var tutorial_done: bool:
	get:
		return bool(flags.get("tutorial_done", false))
	set(value):
		flags["tutorial_done"] = value

var _welcome := 0
var _save_counter := 0
var _file_version := SCHEMA_VERSION
var _future_backup_done := false
var _auto_fire_alt := false
var _extra: Dictionary = {}
var _explicit_path := false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--save-path="):
			save_path = arg.get_slice("=", 1)
			_explicit_path = true
	# Demo / test koşuları oyuncunun kayıtlarını kirletmesin (ve ona bağımlı olmasın).
	persist = _explicit_path or not ("--demo" in args or "--no-save" in args)
	touch = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or "--touch" in args
	if "--no-touch" in args:
		touch = false
	auto_fire = touch
	_auto_fire_alt = not touch
	quality = 1 if OS.has_feature("mobile") else 2
	language = "tr" if OS.get_locale_language() == "tr" else "en"
	meta = MetaProgress.new(GameData.upgrades, GameData.ships)
	if persist:
		_load()
	for arg in args:
		if arg.begins_with("--lang="):
			language = arg.get_slice("=", 1)
		if arg.begins_with("--quality="):
			quality = clampi(int(arg.get_slice("=", 1)), 0, 2)
	if touch and not OS.has_feature("mobile"):
		# Masaüstünde --touch ile deneme: fare dokunuş gibi davransın.
		Input.emulate_touch_from_mouse = true

# --- Saat / tarih -----------------------------------------------------------------
func now_unix() -> int:
	return clock_override if clock_override >= 0 else int(Time.get_unix_time_from_system())

func trusted_now() -> int:
	## Saat geri alınmışsa en son görülen zamanı döndürür (günlük ödül sömürüsünü önler).
	return maxi(now_unix(), int(flags.get("last_seen_unix", 0)))

func today_key() -> String:
	## Güvenilir "bugün" (UTC) — "YYYY-MM-DD".
	return Time.get_date_string_from_unix_time(trusted_now())

func touch_clock() -> void:
	## Saati okur, yüksek-su işaretini ilerletir, geri alma tespit eder.
	var now := now_unix()
	var last := int(flags.get("last_seen_unix", 0))
	clock_rollback = last > 0 and now + CLOCK_TOLERANCE < last
	if now > last:
		flags["last_seen_unix"] = now

func mark_transition() -> void:
	## Son geçiş (ara reklam/sahne geçişi) zamanını kaydeder.
	touch_clock()
	flags["last_transition_time"] = trusted_now()
	save()

# --- Bayraklar / haklar -------------------------------------------------------------
func get_flag(key: String, fallback: Variant = null) -> Variant:
	return flags.get(key, fallback)

func set_flag(key: String, value: Variant) -> void:
	flags[key] = value
	save()
	changed.emit(key)

func has_entitlement(id: String) -> bool:
	return bool(entitlements.get(id, false))

func grant_entitlement(id: String, value := true) -> void:
	entitlements[id] = value
	if id == "remove_ads":
		flags["ads_removed"] = value
	save()
	changed.emit(id)

# --- Doğrulama yardımcıları (bozuk değer → varsayılan) ----------------------------------
static func _is_num(v: Variant) -> bool:
	return (typeof(v) == TYPE_INT) or (typeof(v) == TYPE_FLOAT and is_finite(float(v)))

static func _num(v: Variant, fallback: float, lo: float, hi: float) -> float:
	return clampf(float(v), lo, hi) if _is_num(v) else fallback

static func _int(v: Variant, fallback: int, lo: int, hi: int) -> int:
	return clampi(int(v), lo, hi) if _is_num(v) else fallback

static func _bool(v: Variant, fallback: bool) -> bool:
	if typeof(v) == TYPE_BOOL:
		return v
	if typeof(v) == TYPE_INT and (int(v) == 0 or int(v) == 1):
		return int(v) == 1
	return fallback

static func _simple(v: Variant) -> bool:
	return typeof(v) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING] and (not (typeof(v) == TYPE_FLOAT) or is_finite(float(v)))

# --- Belge (bölüm → anahtar → değer) ------------------------------------------------
func to_document(counter: int) -> Dictionary:
	var doc: Dictionary = {}
	doc["save"] = {
		"schema_version": maxi(SCHEMA_VERSION, _file_version), "counter": counter,
		"written_at": now_unix(), "app_version": str(ProjectSettings.get_setting("application/config/version", "")),
	}
	doc["game"] = {
		"language": language, "vibration": vibration,
		"auto_fire": auto_fire if not touch else _auto_fire_alt,
		"auto_fire_touch": auto_fire if touch else _auto_fire_alt,
		"shake": shake,
		"tutorial_done": tutorial_done,  # eski sürümler için yansıma; doğruluk kaynağı flags
	}
	doc["audio"] = {"music": music, "sfx": sfx}
	doc["video"] = {"show_fps": show_fps, "quality": quality}
	doc["score"] = {"best": best, "best_wave": best_wave, "kills": total_kills, "runs": runs}
	doc["meta"] = {"state": meta.to_dict()}
	doc["flags"] = {"state": flags.duplicate(true)}
	doc["entitlements"] = {"state": entitlements.duplicate(true)}
	for section in _extra:
		if not doc.has(section):
			doc[section] = {}
		for key in _extra[section]:
			if not (doc[section] as Dictionary).has(key):
				doc[section][key] = _extra[section][key]
	return doc

static func encode(doc: Dictionary) -> String:
	var cf := ConfigFile.new()
	for section in doc:
		for key in doc[section]:
			cf.set_value(str(section), str(key), doc[section][key])
	var body := cf.encode_to_text()
	return body + INTEGRITY_MARK + "md5=\"%s\"\n" % body.md5_text()

static func decode(text: String) -> Dictionary:
	## Metni doğrular ve belgeye çevirir. {ok, doc, version, checked, problem}
	var fail := func(reason: String) -> Dictionary:
		return {"ok": false, "doc": {}, "version": 0, "checked": false, "problem": reason}
	if text.strip_edges().is_empty():
		return fail.call("boş dosya")
	var body := text
	var checked := false
	var idx := text.rfind(INTEGRITY_MARK)
	if idx >= 0:
		body = text.substr(0, idx)
		var tail := text.substr(idx + INTEGRITY_MARK.length()).strip_edges()
		if not (tail.begins_with("md5=\"") and tail.ends_with("\"") and tail.length() == 38):
			return fail.call("bütünlük işareti okunamadı (kesik dosya)")
		if tail.substr(5, 32) != body.md5_text():
			return fail.call("bütünlük özeti uyuşmuyor (kesik ya da bozuk dosya)")
		checked = true
	if not checked and body.strip_edges().begins_with("[save]"):
		return fail.call("v2 dosyası bütünlük işaretsiz (kesik dosya)")  # ayrıştırmadan ele: motor günlüğünü kirletmez
	if not body.strip_edges().begins_with("["):
		return fail.call("bölüm başlığıyla başlamıyor")
	var cf := ConfigFile.new()
	if cf.parse(body) != OK:
		return fail.call("ayrıştırma hatası")
	var doc: Dictionary = {}
	for section in cf.get_sections():
		doc[section] = {}
		for key in cf.get_section_keys(section):
			doc[section][key] = cf.get_value(section, key)
	var version := 1
	if doc.has("save"):
		version = _int(doc["save"].get("schema_version", 1), 1, 1, 1000000)
	elif checked:
		return fail.call("bütünlük işaretli ama [save] bölümü yok")
	if version >= 2 and not checked:
		return fail.call("v2 dosyası bütünlük işaretsiz (kesik dosya)")
	var known := false
	for section in ["game", "audio", "video", "score", "meta"]:
		if doc.has(section):
			known = true
	if not known:
		return fail.call("tanınan bölüm yok")
	return {"ok": true, "doc": doc, "version": version, "checked": checked, "problem": ""}

# --- Göç (eski sürümden yeniye) ----------------------------------------------------------
static func migrate_document(doc: Dictionary, from_version: int) -> Dictionary:
	## Sürümden SCHEMA_VERSION'a zincirleme göç eder. Saf fonksiyon; yeni sürümler buraya `_migrate_N_to_M` ekler.
	var out := doc.duplicate(true)
	var v := from_version
	while v < SCHEMA_VERSION:
		match v:
			1:
				out = _migrate_1_to_2(out)
			_:
				break
		v += 1
	return out

static func _migrate_1_to_2(doc: Dictionary) -> Dictionary:
	## v1 (sürümsüz, bütünlüksüz) → v2: bayraklar [flags]'a taşınır, koşu sayacı mevcut koşulardan başlar.
	var out := doc.duplicate(true)
	var game: Dictionary = out.get("game", {})
	var score: Dictionary = out.get("score", {})
	var flags_state: Dictionary = DEFAULT_FLAGS.duplicate(true)
	flags_state["tutorial_done"] = _bool(game.get("tutorial_done", false), false)
	flags_state["run_counter"] = _int(score.get("runs", 0), 0, 0, MAX_COUNT)
	out["flags"] = {"state": flags_state}
	out["entitlements"] = {"state": {}}
	# Atölye yoksa ama oyuncu oynamışsa bir kerelik hoş geldin çekirdeği (eski davranış korunur).
	if not out.has("meta") and (_int(score.get("runs", 0), 0, 0, MAX_COUNT) > 0 or _int(score.get("best", 0), 0, 0, MAX_COUNT) > 0):
		out["_welcome"] = 150 + _int(score.get("kills", 0), 0, 0, MAX_COUNT) / 4
	return out

# --- Belgeyi belleğe uygula (her değer doğrulanır) ----------------------------------------
func apply_document(doc: Dictionary, version: int) -> void:
	var migrated := version < SCHEMA_VERSION
	if migrated:
		doc = migrate_document(doc, version)
	_file_version = maxi(version, SCHEMA_VERSION)
	var game: Dictionary = doc.get("game", {}) if typeof(doc.get("game", {})) == TYPE_DICTIONARY else {}
	var audio: Dictionary = doc.get("audio", {}) if typeof(doc.get("audio", {})) == TYPE_DICTIONARY else {}
	var video: Dictionary = doc.get("video", {}) if typeof(doc.get("video", {})) == TYPE_DICTIONARY else {}
	var score: Dictionary = doc.get("score", {}) if typeof(doc.get("score", {})) == TYPE_DICTIONARY else {}
	var lang: Variant = game.get("language", language)
	language = str(lang) if typeof(lang) == TYPE_STRING and str(lang) in LANGUAGES else language
	music = _num(audio.get("music", music), music, 0.0, 1.0)
	sfx = _num(audio.get("sfx", sfx), sfx, 0.0, 1.0)
	vibration = _bool(game.get("vibration", vibration), vibration)
	shake = _bool(game.get("shake", shake), shake)
	show_fps = _bool(video.get("show_fps", show_fps), show_fps)
	quality = _int(video.get("quality", quality), quality, 0, 2)
	var af_desktop := _bool(game.get("auto_fire", false), false)
	var af_touch := _bool(game.get("auto_fire_touch", true), true)
	if game.has("auto_fire") or game.has("auto_fire_touch"):
		auto_fire = af_touch if touch else af_desktop
		_auto_fire_alt = af_desktop if touch else af_touch
	best = _int(score.get("best", 0), 0, 0, MAX_COUNT)
	best_wave = _int(score.get("best_wave", 0), 0, 0, MAX_COUNT)
	total_kills = _int(score.get("kills", 0), 0, 0, MAX_COUNT)
	runs = _int(score.get("runs", 0), 0, 0, MAX_COUNT)
	# Bayraklar: bilinen anahtarlar tipine göre, bilinmeyenler yalnız basit türdeyse korunur.
	flags = DEFAULT_FLAGS.duplicate(true)
	var raw_flags: Variant = (doc.get("flags", {}) as Dictionary).get("state", {}) if typeof(doc.get("flags", {})) == TYPE_DICTIONARY else {}
	if typeof(raw_flags) == TYPE_DICTIONARY:
		for key in raw_flags:
			var value: Variant = raw_flags[key]
			if typeof(key) != TYPE_STRING or str(key).length() > 48:
				continue
			match str(key):
				"ads_removed", "tutorial_done":
					flags[key] = _bool(value, bool(DEFAULT_FLAGS[key]))
				"run_counter", "last_transition_time", "last_seen_unix":
					flags[key] = _int(value, 0, 0, 1 << 40)
				"daily_bonus_date":
					flags[key] = str(value) if typeof(value) == TYPE_STRING and str(value).length() <= 10 else ""
				_:
					if _simple(value):
						flags[key] = value
	entitlements = {}
	var raw_ent: Variant = (doc.get("entitlements", {}) as Dictionary).get("state", {}) if typeof(doc.get("entitlements", {})) == TYPE_DICTIONARY else {}
	if typeof(raw_ent) == TYPE_DICTIONARY:
		for key in raw_ent:
			if typeof(key) == TYPE_STRING and str(key).length() <= 48 and typeof(raw_ent[key]) == TYPE_BOOL:
				entitlements[key] = raw_ent[key]
	if doc.has("meta"):
		var raw_meta: Variant = (doc["meta"] as Dictionary).get("state", {}) if typeof(doc["meta"]) == TYPE_DICTIONARY else {}
		meta.from_dict(raw_meta if typeof(raw_meta) == TYPE_DICTIONARY else {})
	elif doc.has("_welcome"):
		_welcome = int(doc["_welcome"])
		meta.earn(_welcome)
	_save_counter = _int((doc.get("save", {}) as Dictionary).get("counter", 0), 0, 0, MAX_COUNT) if doc.has("save") else 0
	# Bilinmeyen bölüm/anahtarlar (gelecek sürüm ya da el eklemesi) olduğu gibi korunur.
	_extra = {}
	for section in doc:
		if str(section).begins_with("_") or typeof(doc[section]) != TYPE_DICTIONARY:
			continue
		var known: Array = KNOWN_KEYS.get(section, [])
		for key in doc[section]:
			if not (key in known):
				if not _extra.has(section):
					_extra[section] = {}
				_extra[section][key] = doc[section][key]
	load_report["legacy_migrated"] = migrated and version == 1
	touch_clock()

# --- Yükleme -----------------------------------------------------------------------
func _read_candidate(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "ok": false}
	var text := FileAccess.get_file_as_string(path)
	var res := decode(text)
	res["exists"] = true
	return res

func read_best(path: String) -> Dictionary:
	## Ana dosya, .tmp ve .bak'ı inceler; geçerli olanlar arasından en yüksek counter'ı seçer. Diske YAZMAZ.
	var names := {"main": path, "tmp": path + ".tmp", "bak": path + ".bak"}
	var problems: Array = []
	var best_name := ""
	var best_res: Dictionary = {}
	var best_counter := -1
	var any_existed := false
	for name in ["main", "tmp", "bak"]:
		var res := _read_candidate(names[name])
		if not res["exists"]:
			continue
		any_existed = true
		if not res["ok"]:
			problems.append("%s: %s" % [name, res["problem"]])
			continue
		var counter := _int((res["doc"].get("save", {}) as Dictionary).get("counter", 0), 0, 0, MAX_COUNT) if res["doc"].has("save") else 0
		if counter > best_counter:
			best_counter = counter
			best_name = name
			best_res = res
	return {"source": best_name if best_name != "" else "none", "res": best_res, "problems": problems, "any_existed": any_existed}

func _quarantine(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var dest := path + ".corrupt"
	if FileAccess.file_exists(dest):
		DirAccess.remove_absolute(dest)
	DirAccess.rename_absolute(path, dest)

func load_from(path: String, write_recovery := true) -> Dictionary:
	## Kayıt yükler. `write_recovery`: bozuk dosyayı .corrupt'a taşıma / gelecek sürüm yedeği gibi disk işlemlerine izin.
	var found := read_best(path)
	load_report = {"source": found["source"], "version": 0, "recovered": false, "problems": found["problems"], "legacy_migrated": false}
	if found["source"] == "none":
		if found["any_existed"] and write_recovery:
			_quarantine(path)
			_quarantine(path + ".bak")
			_quarantine(path + ".tmp")
		load_report["recovered"] = found["any_existed"]  # kayıt vardı ama okunamadı → varsayılanlara düşüldü
		return load_report
	var res: Dictionary = found["res"]
	load_report["version"] = res["version"]
	load_report["recovered"] = found["source"] != "main" or not (found["problems"] as Array).is_empty()
	if int(res["version"]) != SCHEMA_VERSION:
		# Gelecek sürüm dosyası YA DA göç edilecek eski dosya: ilk yazımdan önce birebir kopyası `.v<N>.bak` olarak saklanır
		# (bir kez; üzerine yazılmaz). Böylece sonraki yazımlar .bak'ı döndürse bile özgün dosya kaybolmaz.
		load_report["future"] = int(res["version"]) > SCHEMA_VERSION
		if write_recovery and found["source"] == "main" and not _future_backup_done:
			var vb := "%s.v%d.bak" % [path, int(res["version"])]
			if not FileAccess.file_exists(vb):
				DirAccess.copy_absolute(path, vb)
			_future_backup_done = true
	apply_document(res["doc"], int(res["version"]))
	return load_report

func _load() -> void:
	load_from(save_path, _can_write())

# --- Kaydetme ----------------------------------------------------------------------
func _can_write() -> bool:
	if not persist:
		return false
	return _explicit_path or DisplayServer.get_name() != "headless"

func save() -> bool:
	if not _can_write():
		return false
	return write_to(save_path)

func write_to(path: String) -> bool:
	## Atomik yazım: .tmp → doğrula → (.bak ← ana) → .tmp'yi ana dosyanın üstüne taşı. Başarıyı döndürür; hata `last_save_error`'a yazılır.
	last_save_error = ""
	var counter := _save_counter + 1
	var text := encode(to_document(counter))
	var tmp := path + ".tmp"
	var bak := path + ".bak"
	var base_dir := path.get_base_dir()
	if base_dir != "" and not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		last_save_error = "geçici dosya açılamadı (hata %d)" % FileAccess.get_open_error()
		return false
	f.store_string(text)
	f.flush()
	var write_err := f.get_error()
	f.close()
	if write_err != OK:
		last_save_error = "yazım hatası (%d) — disk dolu olabilir" % write_err
		DirAccess.remove_absolute(tmp)
		return false
	var check := decode(FileAccess.get_file_as_string(tmp))
	if not check["ok"] or FileAccess.get_file_as_string(tmp) != text:
		last_save_error = "geri okuma doğrulaması başarısız: " + str(check["problem"])
		DirAccess.remove_absolute(tmp)
		return false
	if FileAccess.file_exists(path):
		if _read_candidate(path)["ok"]:
			DirAccess.copy_absolute(path, bak)  # yalnız GEÇERLİ ana dosya yedeğe girer
		else:
			_quarantine(path)  # bozuk dosyayı yedeğin üzerine yazma; ayrı sakla
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)  # yeniden adlandırma üzerine yazmayı desteklemeyen platformlar
		err = DirAccess.rename_absolute(tmp, path)
	if err != OK:
		last_save_error = "yeniden adlandırma başarısız (%d); yeni sürüm .tmp'de duruyor" % err
		return false
	_save_counter = counter
	return true

func set_value(key: String, value: Variant) -> void:
	set(key, value)
	save()
	changed.emit(key)

func record_run(score: int, wave: int, kills: int, cores_earned := 0) -> bool:
	## Koşu sonucunu işler; yeni rekor ise true döner.
	var is_record := score > best and score > 0
	best = maxi(best, score)
	best_wave = maxi(best_wave, wave)
	total_kills += kills
	runs += 1
	flags["run_counter"] = int(flags.get("run_counter", 0)) + 1
	meta.earn(cores_earned)
	touch_clock()
	save()
	return is_record

func take_welcome() -> int:
	## Hoş geldin bonusu verildiyse miktarını bir kez döndürür (menüde duyurmak için).
	var out := _welcome
	_welcome = 0
	if out > 0:
		save()
	return out

func ui_scale() -> float:
	return 1.3 if touch else 1.0
