class_name TutorialFeatures
extends RefCounted

## Saf mantık: bir seviyede hangi yeni mekanik/güçlendirici var? Sahneye bağımlı değil, test edilir.
## Hangi alanın hangi mekaniği gösterdiği `data/tutorials.json` içindedir; böylece başka dalda
## eklenen (sheet/pair/dye) alanlar kod değişmeden çalışır.

const TABLE_PATH: String = "res://data/tutorials.json"

static var _cached: Dictionary = {}


## Tablo bir kez okunur. Yoksa boş sözlük: öğretici sessizce kapanır, oyun etkilenmez.
static func table() -> Dictionary:
	if _cached.is_empty() and FileAccess.file_exists(TABLE_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
		if parsed is Dictionary:
			_cached = parsed as Dictionary
	return _cached


## Seviyede bulunan özelliklerin kimlikleri, tablodaki `card_order` sırasıyla.
static func detect(level: Dictionary, data: Dictionary = {}) -> Array[String]:
	var source: Dictionary = data if not data.is_empty() else table()
	var found: Array[String] = []
	var cards: Dictionary = source.get("cards", {}) as Dictionary
	for entry: Variant in source.get("card_order", []) as Array:
		var feature: String = String(entry)
		var spec: Dictionary = cards.get(feature, {}) as Dictionary
		if _level_has(level, spec):
			found.append(feature)
	return found


static func _level_has(level: Dictionary, spec: Dictionary) -> bool:
	if spec.has("unlock_level"):
		return int(level.get("level", 1)) >= int(spec["unlock_level"])
	var key: String = String(spec.get("item_key", ""))
	if key.is_empty():
		return false
	for item: Variant in level.get("items", []) as Array:
		var dict: Dictionary = item as Dictionary
		if dict.has(key) and _present(dict[key]):
			return true
	return false


## Alan "var" sayılır: false/null hariç her değer (kilit rengi 0 ya da çift kimliği 0 olabilir;
## bool'a çevirmek onları yanlışlıkla "yok" yapardı).
static func _present(value: Variant) -> bool:
	if value == null:
		return false
	if value is bool:
		return bool(value)
	return true
