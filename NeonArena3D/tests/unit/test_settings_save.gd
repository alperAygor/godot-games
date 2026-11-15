extends TestCase
## Kayıt sağlamlaştırma: atomik yazım, .bak/.tmp kurtarma, sürümlü şema + göç, bozuk değerler, gelecek sürüm, yalıtım.
## HİÇBİR test oyuncunun gerçek user:// dosyalarına dokunmaz: her test OS temp dizininde kendi klasörünü kullanır.

const SettingsScript = preload("res://scripts/autoload/settings.gd")

# Gerçek (v1) kayıt dosyasının birebir biçimi: [meta] YOK, sürüm YOK, bütünlük YOK.
const LEGACY_V1 := "[score]\n\nbest=34040\nbest_wave=20\nkills=516\nruns=2\n\n[audio]\n\nmusic=0.7\nsfx=0.9\n\n[game]\n\nvibration=true\nauto_fire=false\nshake=true\ntutorial_done=true\n\n[video]\n\nshow_fps=false\nquality=2\n"

var _dirs: Array[String] = []

func _dir() -> String:
	var d := OS.get_temp_dir().path_join("na3d_savetest_%d_%d" % [OS.get_process_id(), _dirs.size()])
	DirAccess.make_dir_recursive_absolute(d)
	_dirs.append(d)
	return d

func _path() -> String:
	return _dir().path_join("neon_arena_3d.cfg")

func _cleanup() -> void:
	for d in _dirs:
		var da := DirAccess.open(d)
		if da != null:
			for f in da.get_files():
				DirAccess.remove_absolute(d.path_join(f))
		DirAccess.remove_absolute(d)
	_dirs.clear()

func _settings() -> Node:
	var ups: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/upgrades.json"))
	var ships: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/ships.json"))
	var s: Node = SettingsScript.new()
	s.meta = MetaProgress.new(ups, ships)
	s.clock_override = 1800000000
	return s

func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func _exists(path: String) -> bool:
	return FileAccess.file_exists(path)

func _progress(s: Node) -> String:
	return "%d/%d/%d/%d cores=%d lv=%s ship=%s" % [s.best, s.best_wave, s.total_kills, s.runs, s.meta.cores, str(s.meta.levels), s.meta.ship]

func _filled() -> Node:
	var s := _settings()
	s.best = 5000
	s.best_wave = 9
	s.total_kills = 321
	s.runs = 12
	s.music = 0.4
	s.language = "en"
	s.meta.earn(900)
	s.meta.buy("zirh")
	s.meta.buy_ship("kasirga")
	s.meta.select_ship("kasirga")
	s.flags["daily_bonus_date"] = "2026-11-14"
	s.flags["run_counter"] = 12
	s.entitlements["remove_ads"] = true
	return s

# --- Yuvarlak yol -----------------------------------------------------------------
func test_round_trip_keeps_everything() -> void:
	var path := _path()
	var a := _filled()
	check(a.write_to(path), "yazım başarılı olmalı: " + str(a.last_save_error))
	var b := _settings()
	var rep: Dictionary = b.load_from(path)
	eq(rep["source"], "main", "ana dosyadan yüklenmeli")
	eq(rep["version"], 2, "şema sürümü 2 olmalı")
	eq(_progress(b), _progress(a), "ilerleme birebir korunmalı")
	eq(b.language, "en", "dil korunmalı")
	near(b.music, 0.4, 0.0001, "müzik korunmalı")
	eq(b.flags["daily_bonus_date"], "2026-11-14", "günlük ödül tarihi korunmalı")
	eq(b.flags["run_counter"], 12, "koşu sayacı korunmalı")
	check(b.has_entitlement("remove_ads"), "hak korunmalı")
	a.free()
	b.free()
	_cleanup()

func test_atomic_write_leaves_no_tmp_and_rotates_backup() -> void:
	var path := _path()
	var s := _filled()
	check(s.write_to(path), "ilk yazım")
	check(not _exists(path + ".tmp"), "başarılı yazımdan sonra .tmp kalmamalı")
	check(not _exists(path + ".bak"), "ilk yazımda yedek olmamalı")
	var first := _read(path)
	s.best = 9999
	check(s.write_to(path), "ikinci yazım")
	check(_exists(path + ".bak"), "ikinci yazımda .bak oluşmalı")
	eq(_read(path + ".bak"), first, ".bak bir önceki geçerli sürümün aynısı olmalı")
	check(not _exists(path + ".tmp"), "ikinci yazımdan sonra da .tmp kalmamalı")
	s.free()
	_cleanup()

func test_save_counter_increases() -> void:
	var path := _path()
	var s := _filled()
	s.write_to(path)
	s.write_to(path)
	var d: Dictionary = SettingsScript.decode(_read(path))
	eq(int(d["doc"]["save"]["counter"]), 2, "her yazım sayacı artırmalı")
	s.free()
	_cleanup()

# --- Bozuk dosya senaryoları ----------------------------------------------------------
func test_truncated_main_recovers_from_backup() -> void:
	var path := _path()
	var s := _filled()
	s.write_to(path)
	var good := _progress(s)
	s.best += 1
	s.write_to(path)
	var full := _read(path)
	_write(path, full.substr(0, full.length() / 2))  # yarım yazılmış dosya
	var b := _settings()
	var rep: Dictionary = b.load_from(path)
	eq(rep["source"], "bak", "yedekten yüklenmeli")
	check(rep["recovered"], "kurtarma işaretlenmeli")
	check(not (rep["problems"] as Array).is_empty(), "sorun raporlanmalı")
	eq(b.meta.level("zirh"), 1, "atölye seviyesi kaybolmamalı")
	eq(b.best, 5000, "yedekteki rekor korunmalı (son yazımdan bir önceki)")
	eq(_progress(b), good, "yedek, önceki geçerli ilerlemeyi vermeli")
	s.free()
	b.free()
	_cleanup()

func test_truncation_at_any_length_never_crashes_or_loses_backup() -> void:
	var path := _path()
	var s := _filled()
	s.write_to(path)
	s.write_to(path)
	var full := _read(path)
	var step := maxi(1, full.length() / 40)
	var n := 0
	var cut := 0
	while cut < full.length():
		_write(path, full.substr(0, cut))
		var b := _settings()
		var rep: Dictionary = b.load_from(path, false)
		check(rep["source"] != "main", "kesik dosya (uzunluk %d) ana dosya olarak kabul edilmemeli" % cut)
		eq(b.meta.level("zirh"), 1, "kesik dosyada (%d) ilerleme yedekten gelmeli" % cut)
		b.free()
		cut += step
		n += 1
	gt(float(n), 20.0, "yeterince kesim noktası denenmeli")
	s.free()
	_cleanup()

func test_empty_main_recovers_from_backup() -> void:
	var path := _path()
	var s := _filled()
	s.write_to(path)
	s.write_to(path)
	_write(path, "")
	var b := _settings()
	var rep: Dictionary = b.load_from(path)
	eq(rep["source"], "bak", "boş ana dosyada yedeğe düşmeli")
	eq(b.meta.level("zirh"), 1, "ilerleme korunmalı")
	s.free()
	b.free()
	_cleanup()

func test_garbage_main_without_backup_uses_defaults_and_keeps_corrupt_copy() -> void:
	var path := _path()
	_write(path, "bu bir kayıt değil {{{[[")
	var b := _settings()
	var rep: Dictionary = b.load_from(path)
	eq(rep["source"], "none", "geçerli kaynak yok")
	check(rep["recovered"], "varsayılanlara düşüldüğü bildirilmeli")
	eq(b.best, 0, "varsayılan rekor")
	eq(b.meta.cores, 0, "varsayılan çekirdek")
	check(_exists(path + ".corrupt"), "bozuk dosya .corrupt olarak SAKLANMALI")
	check(not _exists(path), "bozuk ana dosya yoldan kalkmalı (üzerine yazılmasın)")
	check(b.write_to(path), "sonraki kayıt sorunsuz çalışmalı")
	var c := _settings()
	eq(c.load_from(path)["source"], "main", "yeniden yüklenebilmeli")
	b.free()
	c.free()
	_cleanup()

func test_both_main_and_backup_corrupt() -> void:
	var path := _path()
	_write(path, "[score]\nbest=")
	_write(path + ".bak", "")
	var b := _settings()
	var rep: Dictionary = b.load_from(path)
	eq(rep["source"], "none", "ikisi de bozuksa varsayılan")
	eq(b.runs, 0, "çökme olmamalı, varsayılan değerler")
	check(_exists(path + ".corrupt"), "ana bozuk dosya saklanmalı")
	b.free()
	_cleanup()

func test_single_flipped_byte_is_detected() -> void:
	var path := _path()
	var s := _filled()
	s.write_to(path)
	s.write_to(path)
	var text := _read(path)
	var at := text.find("best=5000")
	_write(path, text.substr(0, at) + "best=9000" + text.substr(at + 9))  # bütünlük özetiyle uyuşmaz
	var b := _settings()
	eq(b.load_from(path)["source"], "bak", "tek değerin değiştirilmesi bütünlük kontrolüne takılmalı")
	eq(b.best, 5000, "yedekteki değer gelmeli")
	s.free()
	b.free()
	_cleanup()

func test_crash_between_tmp_and_rename_uses_newer_tmp() -> void:
	var path := _path()
	var s := _filled()
	s.write_to(path)  # counter 1
	var older := _read(path)
	s.best = 77777
	var tmp_text: String = SettingsScript.encode(s.to_document(2))
	_write(path + ".tmp", tmp_text)  # yazım tamamlandı, yeniden adlandırma öncesi çökme
	_write(path, older)
	var b := _settings()
	var rep: Dictionary = b.load_from(path)
	eq(rep["source"], "tmp", "daha yeni geçerli .tmp seçilmeli")
	eq(b.best, 77777, "son yazılan ilerleme kaybolmamalı")
	s.free()
	b.free()
	_cleanup()

func test_half_written_tmp_is_ignored() -> void:
	var path := _path()
	var s := _filled()
	s.write_to(path)
	var tmp_text: String = SettingsScript.encode(s.to_document(2))
	_write(path + ".tmp", tmp_text.substr(0, tmp_text.length() / 3))
	var b := _settings()
	var rep: Dictionary = b.load_from(path)
	eq(rep["source"], "main", "yarım .tmp yok sayılmalı")
	eq(b.best, 5000, "ana dosyanın değeri")
	s.free()
	b.free()
	_cleanup()

func test_write_failure_keeps_old_file_and_memory() -> void:
	var path := _path()
	var s := _filled()
	s.write_to(path)
	var before := _read(path)
	# Hedef bir DİZİN olunca .tmp dosyası açılamaz ya da yeniden adlandırma başarısız olur → yazım hatası, çökme yok.
	var blocked := _dir().path_join("blocked.cfg")
	DirAccess.make_dir_recursive_absolute(blocked + ".tmp")
	check(not s.write_to(blocked), "yazılamayan hedefte false dönmeli")
	check(str(s.last_save_error) != "", "hata nedeni kaydedilmeli")
	eq(_read(path), before, "diğer dosya etkilenmemeli")
	eq(s.best, 5000, "bellekteki durum bozulmamalı")
	DirAccess.remove_absolute(blocked + ".tmp")
	s.free()
	_cleanup()

# --- Bozuk değerler ------------------------------------------------------------------
func test_bad_values_are_sanitized() -> void:
	var doc := {
		"save": {"schema_version": 2, "counter": 1},
		"game": {"language": "xx", "vibration": "evet", "shake": 5, "auto_fire": [1], "tutorial_done": "yes"},
		"audio": {"music": 9.0, "sfx": "yüksek"},
		"video": {"quality": 77, "show_fps": null},
		"score": {"best": -50, "best_wave": "abc", "kills": 1e30, "runs": {"a": 1}},
		"meta": {"state": "bozuk"},
		"flags": {"state": {"run_counter": -5, "ads_removed": "x", "daily_bonus_date": 12345, "evil": [1, 2], "ok_extra": 7}},
		"entitlements": {"state": {"remove_ads": "true", "x": true}},
	}
	var path := _path()
	_write(path, SettingsScript.encode(doc))
	var s := _settings()
	var rep: Dictionary = s.load_from(path)
	eq(rep["source"], "main", "yapısal olarak geçerli dosya yüklenmeli")
	eq(s.language, "tr", "bilinmeyen dil varsayılana dönmeli")
	check(s.vibration == true, "bozuk bool varsayılan kalmalı")
	near(s.music, 1.0, 0.0001, "müzik [0,1]'e kırpılmalı")
	near(s.sfx, 0.9, 0.0001, "metin sfx varsayılan kalmalı")
	eq(s.quality, 2, "kalite [0,2]'ye kırpılmalı")
	eq(s.best, 0, "negatif rekor 0")
	eq(s.best_wave, 0, "metin dalga 0")
	check(s.total_kills <= SettingsScript.MAX_COUNT, "devasa sayı kırpılmalı")
	eq(s.runs, 0, "sözlük koşu sayısı 0")
	eq(s.meta.cores, 0, "bozuk meta varsayılan")
	eq(s.flags["run_counter"], 0, "negatif sayaç 0")
	check(s.flags["ads_removed"] == false, "bozuk bayrak varsayılan")
	eq(s.flags["daily_bonus_date"], "", "tarih metin değilse boş")
	check(not s.flags.has("evil"), "dizi bayrağı atılmalı")
	eq(s.flags["ok_extra"], 7, "bilinmeyen basit bayrak korunmalı")
	check(not s.has_entitlement("remove_ads"), "metin 'true' hak sayılmaz")
	check(s.has_entitlement("x"), "geçerli hak korunmalı")
	s.free()
	_cleanup()

func test_nan_and_inf_do_not_poison_state() -> void:
	var path := _path()
	_write(path, "[save]\n\nschema_version=1\n\n[audio]\n\nmusic=nan\nsfx=inf\n\n[score]\n\nbest=nan\nruns=inf\n")
	var s := _settings()
	s.load_from(path)
	near(s.music, 0.7, 0.0001, "NaN müzik varsayılan")
	near(s.sfx, 0.9, 0.0001, "inf sfx varsayılan")
	eq(s.best, 0, "NaN rekor 0")
	s.free()
	_cleanup()

# --- Sürüm göçü -------------------------------------------------------------------------
func test_legacy_v1_file_migrates_without_losing_progress() -> void:
	var path := _path()
	_write(path, LEGACY_V1)
	var s := _settings()
	var rep: Dictionary = s.load_from(path)
	eq(rep["source"], "main", "eski dosya yüklenebilmeli")
	eq(rep["version"], 1, "eski dosya v1 sayılmalı")
	check(rep["legacy_migrated"], "göç işaretlenmeli")
	eq(s.best, 34040, "rekor korunmalı")
	eq(s.best_wave, 20, "en iyi dalga korunmalı")
	eq(s.total_kills, 516, "öldürme korunmalı")
	eq(s.runs, 2, "koşu sayısı korunmalı")
	check(s.tutorial_done, "öğretici bayrağı flags'e taşınmalı")
	eq(s.flags["run_counter"], 2, "koşu sayacı mevcut koşulardan başlamalı")
	check(s.auto_fire == false, "masaüstü otomatik ateş korunmalı")
	check(s.vibration and s.shake, "eski ayarlar korunmalı")
	eq(s.meta.cores, 150 + 516 / 4, "meta bölümü yoksa bir kerelik hoş geldin çekirdeği (eski davranış)")
	eq(s.take_welcome(), 150 + 516 / 4, "hoş geldin miktarı bir kez bildirilmeli")
	eq(s.take_welcome(), 0, "ikinci kez 0")
	check(s.write_to(path), "göç sonrası yazım")
	check(_exists(path + ".bak"), "ilk v2 yazımı eski v1 dosyasını .bak olarak saklamalı")
	eq(_read(path + ".bak"), LEGACY_V1, ".bak eski dosyanın birebir aynısı olmalı")
	eq(_read(path + ".v1.bak"), LEGACY_V1, "özgün v1 dosyası .v1.bak olarak saklanmalı")
	var again := _settings()
	var rep2: Dictionary = again.load_from(path)
	eq(rep2["version"], 2, "yeniden yüklemede v2")
	check(not rep2["legacy_migrated"], "ikinci yüklemede göç tekrarlanmamalı")
	eq(again.meta.cores, 150 + 516 / 4, "hoş geldin çekirdeği tekrar verilmemeli, kaybolmamalı")
	eq(again.best, 34040, "rekor v2'de de aynı")
	again.write_to(path)
	again.write_to(path)
	eq(_read(path + ".v1.bak"), LEGACY_V1, "özgün v1 dosyası sonraki yazımlardan sonra da durmalı")
	s.free()
	again.free()
	_cleanup()

func test_legacy_v1_with_meta_state_migrates() -> void:
	var path := _path()
	var text := LEGACY_V1 + "\n[meta]\n\nstate={\n\"cores\": 321,\n\"levels\": {\n\"zirh\": 2\n},\n\"lifetime\": 900,\n\"ship\": \"mizrak\",\n\"ships\": [\"vektor\", \"mizrak\"]\n}\n"
	_write(path, text)
	var s := _settings()
	s.load_from(path)
	eq(s.meta.cores, 321, "çekirdek korunmalı")
	eq(s.meta.level("zirh"), 2, "yükseltme korunmalı")
	eq(s.meta.ship, "mizrak", "gemi korunmalı")
	eq(s.meta.lifetime_cores, 900, "toplam çekirdek korunmalı")
	s.free()
	_cleanup()

func test_unknown_legacy_keys_survive_migration() -> void:
	var path := _path()
	_write(path, LEGACY_V1 + "\n[kontroller]\n\nsol_el=true\n")
	var s := _settings()
	s.load_from(path)
	s.write_to(path)
	check("sol_el=true" in _read(path), "bilinmeyen anahtar yeniden yazımda korunmalı")
	s.free()
	_cleanup()

func test_future_version_is_read_preserved_and_backed_up() -> void:
	var path := _path()
	var doc := {
		"save": {"schema_version": 9, "counter": 40},
		"game": {"language": "en"}, "score": {"best": 777, "best_wave": 4, "kills": 10, "runs": 3},
		"meta": {"state": {"cores": 55, "levels": {"zirh": 1}, "ships": ["vektor"], "ship": "vektor", "lifetime": 55}},
		"gelecek": {"yeni_alan": 42}, "flags": {"state": {"gelecek_bayrak": true}},
	}
	_write(path, SettingsScript.encode(doc))
	var original := _read(path)
	var s := _settings()
	var rep: Dictionary = s.load_from(path)
	eq(rep["version"], 9, "gelecek sürüm raporlanmalı")
	check(rep.get("future", false), "gelecek bayrağı")
	eq(s.best, 777, "bilinen alanlar okunmalı")
	eq(s.meta.cores, 55, "meta okunmalı")
	check(_exists(path + ".v9.bak"), "gelecek dosya ilk yazımdan önce yedeklenmeli")
	eq(_read(path + ".v9.bak"), original, "yedek birebir aynı olmalı")
	s.best = 800
	check(s.write_to(path), "yazım")
	var out: Dictionary = SettingsScript.decode(_read(path))
	eq(int(out["doc"]["save"]["schema_version"]), 9, "sürüm numarası düşürülmemeli")
	eq(int(out["doc"]["gelecek"]["yeni_alan"]), 42, "bilinmeyen bölüm korunmalı")
	check(out["doc"]["flags"]["state"].has("gelecek_bayrak"), "bilinmeyen basit bayrak korunmalı")
	s.free()
	_cleanup()

func test_migration_chain_is_pure_and_idempotent() -> void:
	var v1 := {"score": {"runs": 5, "best": 10, "kills": 40}, "game": {"tutorial_done": true}, "meta": {"state": {}}}
	var m1: Dictionary = SettingsScript.migrate_document(v1, 1)
	var m2: Dictionary = SettingsScript.migrate_document(m1, 2)  # zaten güncel: değişmemeli
	eq(JSON.stringify(m1, "", true), JSON.stringify(m2, "", true), "güncel belgede göç etkisiz olmalı")
	eq(m1["flags"]["state"]["run_counter"], 5, "sayaç taşınmalı")
	check(v1.has("meta") and not v1.has("flags"), "girdi belge değiştirilmemeli")

# --- Bayraklar / saat -----------------------------------------------------------------
func test_flags_defaults_and_clock() -> void:
	var s := _settings()
	for key in SettingsScript.DEFAULT_FLAGS:
		check(s.flags.has(key), "varsayılan bayrak: " + key)
	eq(s.today_key(), "2027-01-15", "bugün anahtarı UTC YYYY-MM-DD olmalı")
	s.touch_clock()
	check(not s.clock_rollback, "ilk okumada geri alma yok")
	eq(s.flags["last_seen_unix"], 1800000000, "yüksek-su işareti kaydedilmeli")
	s.clock_override = 1800000000 - 86400  # saat bir gün geri alındı
	s.touch_clock()
	check(s.clock_rollback, "geri alınan saat tespit edilmeli")
	eq(s.today_key(), "2027-01-15", "güvenilir gün geri gitmemeli")
	s.clock_override = 1800000000 + 86400
	s.touch_clock()
	check(not s.clock_rollback, "ileri saat normal")
	eq(s.today_key(), "2027-01-16", "gün ilerlemeli")
	s.free()

func test_record_run_counts_and_persists_flags() -> void:
	var path := _path()
	var s := _settings()
	s.record_run(1000, 4, 20, 10)
	s.record_run(500, 3, 10, 5)
	eq(s.runs, 2, "runs")
	eq(s.flags["run_counter"], 2, "run_counter")
	s.mark_transition()
	eq(s.flags["last_transition_time"], 1800000000, "son geçiş zamanı")
	s.entitlements["remove_ads"] = true
	s.write_to(path)
	var b := _settings()
	b.load_from(path)
	eq(b.flags["run_counter"], 2, "sayaç kalıcı")
	eq(b.flags["last_transition_time"], 1800000000, "geçiş zamanı kalıcı")
	s.free()
	b.free()
	_cleanup()

# --- Yalıtım ---------------------------------------------------------------------------
func test_no_persist_mode_never_writes() -> void:
	var path := _path()
	var s := _settings()
	s.persist = false
	s.save_path = path
	check(not s.save(), "persist=false iken save() yazmamalı")
	check(not _exists(path) and not _exists(path + ".tmp"), "hiçbir dosya oluşmamalı")
	s.set_value("music", 0.1)
	s.record_run(10, 1, 1, 1)
	check(not _exists(path), "set_value/record_run da yazmamalı")
	s.free()
	_cleanup()

func test_load_without_recovery_flag_does_not_touch_disk() -> void:
	var path := _path()
	_write(path, "bozuk {{")
	var s := _settings()
	s.load_from(path, false)
	check(_exists(path), "write_recovery=false iken bozuk dosya taşınmamalı")
	check(not _exists(path + ".corrupt"), ".corrupt oluşmamalı")
	eq(_read(path), "bozuk {{", "içerik değişmemeli")
	s.free()
	_cleanup()

func test_real_save_files_untouched_by_this_suite() -> void:
	# Bu dosyadaki tüm testler yalnız temp dizini kullanır; gerçek yola yazılmadığını burada da doğrularız.
	var real := ["user://neon_arena_3d.cfg", "user://neon_arena_3d.cfg.bak", "user://neon_arena_3d.cfg.tmp", "user://neon_arena_3d.cfg.corrupt"]
	var before := {}
	for p in real:
		before[p] = "%d:%s" % [FileAccess.get_modified_time(p), FileAccess.get_md5(p)] if FileAccess.file_exists(p) else "yok"
	var path := _path()
	var s := _filled()
	s.write_to(path)
	s.write_to(path)
	_write(path, "bozuk")
	s.load_from(path)
	s.free()
	for p in real:
		var now: String = "%d:%s" % [FileAccess.get_modified_time(p), FileAccess.get_md5(p)] if FileAccess.file_exists(p) else "yok"
		eq(now, before[p], "gerçek kayıt dosyası değişmemeli: " + p)
	check(not str(path).begins_with("user://"), "test yolu user:// altında olmamalı")
	_cleanup()
