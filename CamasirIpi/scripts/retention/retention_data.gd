class_name RetentionData
extends RefCounted

## Tutundurma katmanının JSON denge tabloları (data/retention_*.json). Neden tek yükleyici:
## her sınıf kendi dosyasını açsaydı yol sabitleri dağılırdı; burada önbellekli ve bozuk
## dosyada boş sözlüğe düşer (oyun çökmesin, sadece o özellik sessiz kalsın).

const MISSIONS_PATH: String = "res://data/retention_missions.json"
const MILESTONES_PATH: String = "res://data/retention_milestones.json"
const WEEKLY_PATH: String = "res://data/retention_weekly.json"
const COMEBACK_PATH: String = "res://data/retention_comeback.json"
const CORE_PATH: String = "res://data/retention_core.json"

static var _cache: Dictionary = {}


static func missions() -> Dictionary:
	return _load(MISSIONS_PATH)


static func milestones() -> Dictionary:
	return _load(MILESTONES_PATH)


static func weekly() -> Dictionary:
	return _load(WEEKLY_PATH)


static func comeback() -> Dictionary:
	return _load(COMEBACK_PATH)


static func core() -> Dictionary:
	return _load(CORE_PATH)


static func _load(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path] as Dictionary
	var result: Dictionary = {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			result = parsed as Dictionary
		else:
			push_warning("RetentionData: %s okunamadı" % path)
	_cache[path] = result
	return result
