class_name JsonIO
extends RefCounted
## JSON okuma/yazma yardımcıları. Saf mantık: sahneye ve autoload'lara bağımlı değil, testte doğrudan kullanılır.


## Paketle gelen (değişmez) veri dosyaları için ÖNBELLEKLİ okuma: her çağrıda ayrıştırmaz. Dönen sözlük PAYLAŞIMLIDIR:
## değiştirme (değiştireceksen `read_dict` kullan). Sıcak yollarda (her kare / her tıklama) kullanılır.
static var _shared := {}


static func read_shared(path: String) -> Dictionary:
	if not _shared.has(path):
		_shared[path] = read_dict(path)
	return _shared[path]


## JSON dosyasını okur. Dosya yoksa veya bozuksa `fallback` döner.
static func read_dict(path: String, fallback: Dictionary = {}) -> Dictionary:
	if not FileAccess.file_exists(path):
		return fallback
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_warning("JsonIO: '%s' geçerli bir JSON nesnesi değil." % path)
	return fallback


## Önce geçici dosyaya yazar, yazılanı geri okuyup doğrular, sonra yerine taşır; yazma yarıda kesilirse eski dosya bozulmaz.
## `keep_backup` açıksa, yerine geçmeden önce mevcut GEÇERLİ dosya `<yol>.bak` olarak saklanır (bozuk dosya yedeği ezmez).
static func write_dict(path: String, data: Dictionary, keep_backup := false) -> Error:
	return write_text(path, JSON.stringify(data, "\t"), keep_backup)


## `write_dict` ile aynı atomik yol, ama hazır metni yazar (JSON nesnesi olmalıdır).
static func write_text(path: String, text: String, keep_backup := false) -> Error:
	var tmp_path := path + ".tmp"
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var stored := file.store_string(text)
	file.flush()
	file.close()
	if not stored or not (parse_quiet(FileAccess.get_file_as_string(tmp_path)) is Dictionary):
		DirAccess.remove_absolute(tmp_path)  # disk dolu / yarım yazma: hedefe dokunma
		return ERR_FILE_CANT_WRITE
	if keep_backup and inspect(path)["status"] == READ_OK:
		DirAccess.copy_absolute(path, backup_path(path))
	return DirAccess.rename_absolute(tmp_path, path)


# --- Dosya sağlığı ve kurtarma ------------------------------------------------------------------------------

const READ_OK := "ok"
const READ_MISSING := "missing"
const READ_EMPTY := "empty"
const READ_INVALID := "invalid"
## En çok bu kadar `.corrupt.<ts>` kopyası tutulur (en yeniler); diski şişirmesin.
const MAX_CORRUPT_COPIES := 3


## JSON metnini ayrıştırır; hatada konsola hata basmadan null döner (`JSON.parse_string` bozuk metinde hata basar).
static func parse_quiet(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data


static func backup_path(path: String) -> String:
	return path + ".bak"


## Dosyayı sessizce inceler: {"status": READ_OK|READ_MISSING|READ_EMPTY|READ_INVALID, "data": Dictionary}.
## `push_warning` basmaz (bozuk dosya beklenen bir durumdur).
static func inspect(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"status": READ_MISSING, "data": {}}
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges().is_empty():
		return {"status": READ_EMPTY, "data": {}}
	var parsed: Variant = parse_quiet(text)
	if parsed is Dictionary:
		return {"status": READ_OK, "data": parsed}
	return {"status": READ_INVALID, "data": {}}


## Bozuk dosyayı SİLMEDEN `<ad>.corrupt.<zaman>.<uzantı>` olarak kenara taşır (inceleme/elle kurtarma için) ve yolunu döner.
## Taşınamazsa "" döner. Eski kopyalar `MAX_CORRUPT_COPIES` ile sınırlanır.
static func quarantine(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var base := path.get_basename()
	var extension := path.get_extension()
	var stamp := int(Time.get_unix_time_from_system())
	var target := ""
	var counter := 0
	while true:
		target = "%s.corrupt.%d%s.%s" % [base, stamp, "" if counter == 0 else "_%d" % counter, extension]
		if not FileAccess.file_exists(target):
			break
		counter += 1
	if DirAccess.rename_absolute(path, target) != OK:
		return ""
	_prune_corrupt(path)
	return target


static func corrupt_copies(path: String) -> PackedStringArray:
	var found := PackedStringArray()
	var prefix := path.get_file().get_basename() + ".corrupt."
	var dir_path := path.get_base_dir()
	for file_name in DirAccess.get_files_at(dir_path):
		if file_name.begins_with(prefix):
			found.append(dir_path.path_join(file_name))
	found.sort()
	return found


static func _prune_corrupt(path: String) -> void:
	var copies := corrupt_copies(path)
	# Ada gömülü zaman sayısına göre eskiden yeniye sırala (metin sırası 10/9 gibi basamak farkında yanılır).
	var ordered: Array = Array(copies)
	ordered.sort_custom(func(a: String, b: String) -> bool: return _corrupt_stamp(a) < _corrupt_stamp(b))
	while ordered.size() > MAX_CORRUPT_COPIES:
		DirAccess.remove_absolute(ordered.pop_front())


static func _corrupt_stamp(file_path: String) -> float:
	var parts := file_path.get_file().split(".corrupt.")
	if parts.size() < 2:
		return 0.0
	return float(parts[1].get_basename().replace("_", "."))


# --- Test/araç yalıtımı --------------------------------------------------------------------------------------

## Oyuncunun gerçek kullanıcı dosyaları (kayıt ve ayar, yedekleri ve bozuk kopyaları) bu öneklerle başlar.
const REAL_FILE_PREFIXES: PackedStringArray = ["save.", "settings."]
const SANDBOX_DIR := "user://_sandbox"
## Durum `Engine` meta verisinde tutulur (static değişken GDScript sınıflarını çıkışta "kullanımda" bırakıyordu).
const SANDBOX_META := &"dv_sandbox_state"


## `godot -s <betik>` ile (testler, ekran görüntüsü, ölçüm araçları) çalışırken true: kayıt ve ayarlar gerçek
## `user://save.json` / `settings.cfg` yerine `SANDBOX_DIR` altına yazılır. Ortam değişkeni `DV_REAL_USER_DATA=1` bunu kapatır
## (yalnızca bilinçli elle deneme için). `DV_SANDBOX=1` betiksiz çalıştırmayı da sandbox'a alır (verify.sh içe aktarma/açılış adımları). İlk çağrıda gerçek dosyaların parmak izi alınır ve sandbox boşaltılır.
static func is_sandboxed() -> bool:
	if not Engine.has_meta(SANDBOX_META):
		var args := OS.get_cmdline_args()
		var forced := OS.get_environment("DV_SANDBOX") == "1"  # betiksiz çalıştırmalar için (tools/verify.sh açılış adımı)
		var active: bool = ("-s" in args or "--script" in args or forced) and OS.get_environment("DV_REAL_USER_DATA") != "1"
		var fingerprint := {}
		if active:
			fingerprint = real_files_fingerprint()
			DirAccess.make_dir_recursive_absolute(SANDBOX_DIR)
			for file_name in DirAccess.get_files_at(SANDBOX_DIR):
				DirAccess.remove_absolute(SANDBOX_DIR.path_join(file_name))
		Engine.set_meta(SANDBOX_META, {"active": active, "fingerprint": fingerprint})
	return Engine.get_meta(SANDBOX_META)["active"]


## Kayıt/ayar dosyası için varsayılan yol: sandbox'ta `SANDBOX_DIR/<ad>`, değilse `user://<ad>`.
static func user_file(file_name: String) -> String:
	return SANDBOX_DIR.path_join(file_name) if is_sandboxed() else "user://".path_join(file_name)


## `user://` kökündeki gerçek kayıt/ayar dosyalarının {ad: "değişiklik zamanı:boyut:md5"} özeti.
static func real_files_fingerprint() -> Dictionary:
	var result := {}
	for file_name in DirAccess.get_files_at("user://"):
		for prefix in REAL_FILE_PREFIXES:
			if file_name.begins_with(prefix):
				var path := "user://".path_join(file_name)
				result[file_name] = "%d:%d:%s" % [FileAccess.get_modified_time(path), FileAccess.get_file_as_bytes(path).size(), FileAccess.get_md5(path)]
	return result


## Süreç açılırken alınan parmak izi (sandbox kapalıysa boş).
static func boot_fingerprint() -> Dictionary:
	is_sandboxed()
	return Engine.get_meta(SANDBOX_META)["fingerprint"]


## "player.move_speed" gibi noktalı bir yolla iç içe sözlükten değer okur.
static func get_path_value(data: Dictionary, dotted_path: String, fallback: Variant = null) -> Variant:
	var current: Variant = data
	for key in dotted_path.split("."):
		if current is Dictionary and (current as Dictionary).has(key):
			current = current[key]
		else:
			return fallback
	return current
