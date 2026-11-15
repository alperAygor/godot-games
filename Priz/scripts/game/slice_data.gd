class_name SliceData
extends RefCounted
## Dikey kesitin veri tabloları (sahnesiz, saf): seviye listesi (`data/slice/levels.json`), cihaz
## fabrikası (`data/slice/appliances.json`: tür → Fx betiği, oda yeri, döngü sesi, tepsi ölçeği) ve
## oda eşlemesi (`data/slice/room.json`: seviye `anchor` → odadaki `Socket_0N` düğümü, hat rengi →
## odanın kablo hattı 1..3). Autoload'a dokunmaz; birim testleri doğrudan kullanır.

const LEVELS_PATH: String = "res://data/slice/levels.json"
const APPLIANCES_PATH: String = "res://data/slice/appliances.json"
const ROOM_PATH: String = "res://data/slice/room.json"

## Seviye kaydı: {"file", "time", "tutorial"}.
var levels: Array[Dictionary] = []
var levels_dir: String = "res://data/levels_slice"
## Cihaz türü → {"fx", "anchor", "loop", "tray_fit"}.
var appliances: Dictionary = {}
## Seviye priz `anchor`ı ("living_0") → oda düğümü ("Socket_01").
var anchors: Dictionary = {}
## Oda düğümü → oda hattı (1..3).
var socket_lines: Dictionary = {}
## Hat rengi ("red") → oda hattı (1..3).
var line_colors: Dictionary = {}
var room_id: String = "living"


static func load_default() -> SliceData:
	var data: SliceData = SliceData.new()
	var lv: Dictionary = _read(LEVELS_PATH)
	data.levels_dir = str(lv.get("dir", data.levels_dir))
	for entry: Variant in lv.get("levels", []) as Array:
		if entry is Dictionary:
			data.levels.append(entry as Dictionary)
	data.appliances = _read(APPLIANCES_PATH)
	var room: Dictionary = _read(ROOM_PATH)
	data.room_id = str(room.get("room", data.room_id))
	data.anchors = room.get("anchors", {}) as Dictionary
	for key: Variant in (room.get("socket_lines", {}) as Dictionary).keys():
		data.socket_lines[str(key)] = int((room["socket_lines"] as Dictionary)[key])
	for key: Variant in (room.get("line_colors", {}) as Dictionary).keys():
		data.line_colors[str(key)] = int((room["line_colors"] as Dictionary)[key])
	return data


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("SliceData: dosya yok %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func level_count() -> int:
	return levels.size()


## Oyuncu seviyesi (1 tabanlı, `Progress.level()`) → kesit seviyesi dizini. Kesit bitince başa sarar.
func index_for_progress(progress_level: int) -> int:
	if levels.is_empty():
		return 0
	return posmod(maxi(progress_level, 1) - 1, levels.size())


func level_path(index: int) -> String:
	if index < 0 or index >= levels.size():
		return ""
	return levels_dir.path_join(str(levels[index].get("file", "")))


func load_level(index: int) -> PrizLevel:
	return PrizLevel.load_file(level_path(index))


## Seviyenin başladığı gün dilimi (PrizSlice); bilinmiyorsa sabah.
func level_time(index: int) -> int:
	if index < 0 or index >= levels.size():
		return PrizSlice.MORNING
	return maxi(PrizSlice.from_id(str(levels[index].get("time", "morning"))), 0)


## Öğretim türü: "drag" (hayalet el), "pulse" (kısa vurgu), "" (yok).
func level_tutorial(index: int) -> String:
	if index < 0 or index >= levels.size():
		return ""
	return str(levels[index].get("tutorial", ""))


func has_appliance(type: String) -> bool:
	return appliances.has(type)


func appliance(type: String) -> Dictionary:
	return appliances.get(type, {}) as Dictionary


func appliance_types() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in appliances.keys():
		result.append(str(key))
	result.sort()
	return result


## Seviye prizinin oda düğümü ("" = eşleme yok).
func room_socket(anchor: String) -> String:
	return str(anchors.get(anchor, ""))


## Oda düğümünün kablo hattı (1..3; 0 = bilinmiyor).
func room_line_of_socket(room_socket_name: String) -> int:
	return int(socket_lines.get(room_socket_name, 0))


## Hat renginin oda hattı (1..3; 0 = bilinmiyor).
func room_line_of_color(color: String) -> int:
	return int(line_colors.get(color, 0))


func room_socket_names() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in socket_lines.keys():
		result.append(str(key))
	result.sort()
	return result
