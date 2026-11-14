class_name PrizLevel
extends RefCounted
## Bir seviyenin tüm verisi. `data/levels/level_NNN.json` dosyalarına kayıpsız yazılır ve
## okunur: `PrizLevel.from_json(level.to_json()).to_json() == level.to_json()`.

const FORMAT: int = 1
const MODE_FLAT: String = "flat"
const MODE_DAY: String = "day"
const DIFF_NORMAL: String = "normal"
const DIFF_HARD: String = "hard"
const LEVELS_DIR: String = "res://data/levels"

var id: String = ""
var number: int = 0
var level_seed: int = 0
## "flat" (seviye 1-14) ya da "day" (15+).
var mode: String = MODE_FLAT
## "normal" ya da "hard" (her 5. seviye).
var difficulty: String = DIFF_NORMAL
## Çözücünün saydığı ayrık çözüm sayısının kabul aralığı (dahil).
var band_min: int = 1
var band_max: int = 1
## Gün kipinde başlangıç sigorta hakkı (3); düz kipte 0.
var fuse_rights: int = 0
## Bu seviyede etkin içerik öğelerinin kimlikleri (data/elements/*.json).
var elements: Array[String] = []
## Kullanımda olmayan bilgi alanları (çözüm sayısı, düğüm sayısı ...). Oyun mantığı okumaz.
var meta: Dictionary = {}
var rooms: Array[String] = []
var lines: Array[PrizLine] = []
var sockets: Array[PrizSocket] = []
var devices: Array[PrizDevice] = []


func is_day_mode() -> bool:
	return mode == MODE_DAY


func is_hard() -> bool:
	return difficulty == DIFF_HARD


func has_element(element_id: String) -> bool:
	return elements.has(element_id)


func find_line(line_id: String) -> PrizLine:
	for line: PrizLine in lines:
		if line.id == line_id:
			return line
	return null


func find_socket(socket_id: String) -> PrizSocket:
	for socket: PrizSocket in sockets:
		if socket.id == socket_id:
			return socket
	return null


func find_device(device_id: String) -> PrizDevice:
	for device: PrizDevice in devices:
		if device.id == device_id:
			return device
	return null


func to_dict() -> Dictionary:
	var line_list: Array = []
	for line: PrizLine in lines:
		line_list.append(line.to_dict())
	var socket_list: Array = []
	for socket: PrizSocket in sockets:
		socket_list.append(socket.to_dict())
	var device_list: Array = []
	for device: PrizDevice in devices:
		device_list.append(device.to_dict())
	return {
		"format": FORMAT,
		"id": id,
		"number": number,
		"seed": level_seed,
		"mode": mode,
		"difficulty": difficulty,
		"band": [band_min, band_max],
		"fuse_rights": fuse_rights,
		"elements": elements.duplicate(),
		"rooms": rooms.duplicate(),
		"lines": line_list,
		"sockets": socket_list,
		"devices": device_list,
		"meta": meta.duplicate(true),
	}


func to_json() -> String:
	return PrizJson.stringify(to_dict())


## Derin kopya (üretici ve testler için).
func copy() -> PrizLevel:
	return PrizLevel.from_dict(PrizJson.normalize(to_dict()))


static func from_dict(d: Dictionary) -> PrizLevel:
	var level: PrizLevel = PrizLevel.new()
	level.id = PrizJson.get_str(d, "id")
	level.number = PrizJson.get_int(d, "number")
	level.level_seed = PrizJson.get_int(d, "seed")
	level.mode = PrizJson.get_str(d, "mode", MODE_FLAT)
	level.difficulty = PrizJson.get_str(d, "difficulty", DIFF_NORMAL)
	var band: Vector2i = PrizJson.get_range(d, "band", 1, 1)
	level.band_min = band.x
	level.band_max = band.y
	level.fuse_rights = PrizJson.get_int(d, "fuse_rights")
	for entry: Variant in PrizJson.get_array(d, "elements"):
		level.elements.append(str(entry))
	for entry: Variant in PrizJson.get_array(d, "rooms"):
		level.rooms.append(str(entry))
	for entry: Variant in PrizJson.get_array(d, "lines"):
		if typeof(entry) == TYPE_DICTIONARY:
			level.lines.append(PrizLine.from_dict(entry))
	for entry: Variant in PrizJson.get_array(d, "sockets"):
		if typeof(entry) == TYPE_DICTIONARY:
			level.sockets.append(PrizSocket.from_dict(entry))
	for entry: Variant in PrizJson.get_array(d, "devices"):
		if typeof(entry) == TYPE_DICTIONARY:
			level.devices.append(PrizDevice.from_dict(entry))
	level.meta = PrizJson.normalize(PrizJson.get_dict(d, "meta"))
	return level


## Hatalı metinde null döner.
static func from_json(text: String) -> PrizLevel:
	var data: Variant = PrizJson.parse(text)
	if typeof(data) != TYPE_DICTIONARY:
		return null
	return from_dict(data)


static func load_file(path: String) -> PrizLevel:
	if not FileAccess.file_exists(path):
		return null
	return from_json(FileAccess.get_file_as_string(path))


func save_file(path: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(to_json())
	file.close()
	return true


## Gönderilen seviyenin dosya yolu (1 tabanlı numara).
static func shipped_path(level_number: int) -> String:
	return LEVELS_DIR.path_join("level_%03d.json" % level_number)


static func load_shipped(level_number: int) -> PrizLevel:
	return load_file(shipped_path(level_number))


## data/levels altındaki tüm seviye dosyaları, ad sırasıyla.
static func shipped_files() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(LEVELS_DIR)
	if dir == null:
		return result
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for file_name: String in names:
		if file_name.ends_with(".json"):
			result.append(LEVELS_DIR.path_join(file_name))
	return result


## Yapısal tutarlılık denetimi; boş dizi = geçerli.
func validate(registry: PrizElementRegistry) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if mode != MODE_FLAT and mode != MODE_DAY:
		errors.append("bilinmeyen kip: %s" % mode)
	if lines.size() < 1:
		errors.append("hat yok")
	if band_min > band_max or band_min < 1:
		errors.append("geçersiz zorluk aralığı")
	var seen: Dictionary = {}
	for line: PrizLine in lines:
		if seen.has(line.id):
			errors.append("yinelenen kimlik: %s" % line.id)
		seen[line.id] = true
		if line.capacity < 0:
			errors.append("negatif kapasite: %s" % line.id)
	for socket: PrizSocket in sockets:
		if seen.has(socket.id):
			errors.append("yinelenen kimlik: %s" % socket.id)
		seen[socket.id] = true
		if find_line(socket.line) == null:
			errors.append("priz hatta bağlı değil: %s" % socket.id)
		if not rooms.has(socket.room):
			errors.append("prizin odası yok: %s" % socket.id)
		if socket.seats < 1:
			errors.append("yuvasız priz: %s" % socket.id)
	for device: PrizDevice in devices:
		if seen.has(device.id):
			errors.append("yinelenen kimlik: %s" % device.id)
		seen[device.id] = true
		if device.blocks < 1 or device.blocks > 5:
			errors.append("yük 1-5 dışında: %s" % device.id)
		if not rooms.has(device.room):
			errors.append("cihazın odası yok: %s" % device.id)
		if device.slices == 0:
			errors.append("cihaz hiçbir dilimde çalışmıyor: %s" % device.id)
	if registry != null:
		for element_id: String in elements:
			if registry.get_element(element_id) == null:
				errors.append("bilinmeyen öğe: %s" % element_id)
	return errors
