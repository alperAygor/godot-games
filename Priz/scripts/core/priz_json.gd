class_name PrizJson
extends RefCounted
## JSON yardımcıları. Seviye dosyalarında ondalık sayı yoktur; JSON çözücüsü sayıları
## float verdiği için tüm sayılar tam sayıya çevrilir. Yazım anahtar sıralı ve iki boşluk
## girintilidir, böylece aynı veri her zaman bayt-bayt aynı metni üretir.


static func normalize(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			var f: float = value
			if is_equal_approx(f, roundf(f)):
				return int(roundf(f))
			return f
		TYPE_ARRAY:
			var source: Array = value
			var out: Array = []
			for item: Variant in source:
				out.append(normalize(item))
			return out
		TYPE_DICTIONARY:
			var dict: Dictionary = value
			var result: Dictionary = {}
			for key: Variant in dict.keys():
				result[str(key)] = normalize(dict[key])
			return result
		TYPE_STRING_NAME:
			return str(value)
	return value


static func stringify(data: Variant) -> String:
	return JSON.stringify(data, "  ", true) + "\n"


## Hatalıysa null döner.
static func parse(text: String) -> Variant:
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return null
	return normalize(json.data)


static func read_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text: String = FileAccess.get_file_as_string(path)
	if text == "":
		return null
	return parse(text)


static func write_file(path: String, data: Variant) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(stringify(data))
	file.close()
	return true


## Sözlükten tipli okuma yardımcıları.
static func get_int(d: Dictionary, key: String, fallback: int = 0) -> int:
	var v: Variant = d.get(key, fallback)
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v)
	return fallback


static func get_str(d: Dictionary, key: String, fallback: String = "") -> String:
	var v: Variant = d.get(key, fallback)
	if v == null:
		return fallback
	return str(v)


static func get_bool(d: Dictionary, key: String, fallback: bool = false) -> bool:
	var v: Variant = d.get(key, fallback)
	if typeof(v) == TYPE_BOOL:
		return v
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v) != 0
	return fallback


static func get_dict(d: Dictionary, key: String) -> Dictionary:
	var v: Variant = d.get(key, {})
	if typeof(v) == TYPE_DICTIONARY:
		return v
	return {}


static func get_array(d: Dictionary, key: String) -> Array:
	var v: Variant = d.get(key, [])
	if typeof(v) == TYPE_ARRAY:
		return v
	return []


## [min, max] biçimli aralık; tek sayı da kabul edilir.
static func get_range(d: Dictionary, key: String, lo: int, hi: int) -> Vector2i:
	var v: Variant = d.get(key, null)
	if typeof(v) == TYPE_ARRAY:
		var arr: Array = v
		if arr.size() >= 2:
			return Vector2i(int(arr[0]), int(arr[1]))
		if arr.size() == 1:
			return Vector2i(int(arr[0]), int(arr[0]))
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return Vector2i(int(v), int(v))
	return Vector2i(lo, hi)
