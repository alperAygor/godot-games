class_name PrizCatalog
extends RefCounted
## Cihaz kataloğu (data/balance/devices.json): tür kimliği, yük aralığı, uygun odalar,
## olası çalışma dilimleri ve bayraklar (ör. "ground": topraklı priz isteyebilir).
## Üretici türleri buradan seçer; sahne tür kimliğine göre model yükler.

const DEFAULT_PATH: String = "res://data/balance/devices.json"

## Dosyadaki sırayla tür kimlikleri.
var types: Array[String] = []
var _info: Dictionary = {}


static func create_default() -> PrizCatalog:
	return from_file(DEFAULT_PATH)


static func from_file(path: String) -> PrizCatalog:
	var catalog: PrizCatalog = PrizCatalog.new()
	var data: Variant = PrizJson.read_file(path)
	if typeof(data) == TYPE_DICTIONARY:
		catalog._load(data)
	return catalog


func _load(d: Dictionary) -> void:
	for entry: Variant in PrizJson.get_array(d, "devices"):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var info: Dictionary = entry
		var type_id: String = PrizJson.get_str(info, "type")
		if type_id == "" or _info.has(type_id):
			continue
		types.append(type_id)
		_info[type_id] = info


func has_type(type_id: String) -> bool:
	return _info.has(type_id)


func info(type_id: String) -> Dictionary:
	return _info.get(type_id, {})


func load_range(type_id: String) -> Vector2i:
	return PrizJson.get_range(info(type_id), "load", 1, 1)


func rooms_of(type_id: String) -> Array[String]:
	var result: Array[String] = []
	for entry: Variant in PrizJson.get_array(info(type_id), "rooms"):
		result.append(str(entry))
	return result


## Olası dilim maskeleri (en az biri).
func slice_options(type_id: String) -> Array[int]:
	var result: Array[int] = []
	for entry: Variant in PrizJson.get_array(info(type_id), "slices"):
		if typeof(entry) == TYPE_ARRAY:
			var mask: int = PrizSlice.mask_from_ids(entry)
			if mask != 0:
				result.append(mask)
	if result.is_empty():
		result.append(PrizSlice.ALL_MASK)
	return result


func has_flag(type_id: String, flag: String) -> bool:
	return PrizJson.get_bool(info(type_id), flag, false)


## Bu odaya yakışan türler; yoksa tüm türler.
func types_for_room(room: String) -> Array[String]:
	var result: Array[String] = []
	for type_id: String in types:
		if rooms_of(type_id).has(room):
			result.append(type_id)
	if result.is_empty():
		return types.duplicate()
	return result
