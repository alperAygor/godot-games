class_name SliceState
extends RefCounted
## Tahta (PrizBoard) ile sahne arasındaki saf çevirmen: seviye kimliklerini odadaki düğümlere
## (Socket_0N, kablo hattı 1..3) eşler ve sahnenin çizeceği her şeyi blok/oran olarak verir.
## Kural kararı VERMEZ: takılabilirlik, yük ve kazanma hep `PrizBoard`dan gelir. Sahnesiz; birim testli.
##
##   var st := SliceState.new(level, content.registry, SliceData.load_default())
##   st.preview("d0", "Socket_02")   # {"line", "before", "after", "capacity", "fits", "reason"}
##   st.fill(1)                      # oda hattı 1'in doluluk oranı

## Düz kipte tek "an" vardır; dilim sorguları için sabah kullanılır (CORE_API: slice = 0).
const FLAT_SLICE: int = PrizSlice.MORNING

var board: PrizBoard
var level: PrizLevel
var data: SliceData

var _room_socket: Dictionary = {}   # seviye priz kimliği -> oda düğümü
var _level_socket: Dictionary = {}  # oda düğümü -> seviye priz kimliği
var _room_line: Dictionary = {}     # seviye hat kimliği -> oda hattı
var _level_line: Dictionary = {}    # oda hattı -> seviye hat kimliği


func _init(p_level: PrizLevel, registry: PrizElementRegistry, p_data: SliceData) -> void:
	level = p_level
	data = p_data
	board = PrizBoard.new(level, registry)
	for line: PrizLine in level.lines:
		var room_line: int = data.room_line_of_color(line.color)
		_room_line[line.id] = room_line
		_level_line[room_line] = line.id
	for socket: PrizSocket in level.sockets:
		var node_name: String = data.room_socket(socket.anchor)
		_room_socket[socket.id] = node_name
		_level_socket[node_name] = socket.id


# --- eşleme --------------------------------------------------------------------

func room_socket_of(socket_id: String) -> String:
	return str(_room_socket.get(socket_id, ""))


## Oda düğümündeki seviye prizi ("" = bu seviyede kullanılmıyor).
func level_socket_at(room_socket: String) -> String:
	return str(_level_socket.get(room_socket, ""))


func room_line_of(line_id: String) -> int:
	return int(_room_line.get(line_id, 0))


func level_line_at(room_line: int) -> String:
	return str(_level_line.get(room_line, ""))


## Seviyenin kullandığı oda hatları, küçükten büyüğe.
func room_lines() -> Array[int]:
	var result: Array[int] = []
	for key: Variant in _level_line.keys():
		result.append(int(key))
	result.sort()
	return result


## Seviyede kullanılan oda prizleri.
func room_sockets() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for key: Variant in _level_socket.keys():
		result.append(str(key))
	result.sort()
	return result


func room_line_of_room_socket(room_socket: String) -> int:
	var sid: String = level_socket_at(room_socket)
	return room_line_of(board.line_of_socket(sid)) if sid != "" else 0


# --- cihazlar ------------------------------------------------------------------

func device_ids() -> Array[String]:
	var result: Array[String] = []
	for device: PrizDevice in level.devices:
		result.append(device.id)
	return result


func device_type(device_id: String) -> String:
	var device: PrizDevice = level.find_device(device_id)
	return device.type if device != null else ""


func device_blocks(device_id: String) -> int:
	var device: PrizDevice = level.find_device(device_id)
	return device.blocks if device != null else 0


## Cihazın takılı olduğu oda prizi ("" = tepside).
func plugged_room_socket(device_id: String) -> String:
	var sid: String = board.socket_of(device_id)
	return room_socket_of(sid) if sid != "" else ""


## Oda prizine takılı ilk cihaz ("" = boş).
func device_at_room_socket(room_socket: String) -> String:
	var sid: String = level_socket_at(room_socket)
	if sid == "":
		return ""
	var devs: Array[String] = board.devices_in(sid)
	return devs[0] if not devs.is_empty() else ""


## Tutulan cihazın şu an takılabileceği oda prizleri.
func accepting_room_sockets(device_id: String) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for sid: String in board.sockets_accepting(device_id):
		result.append(room_socket_of(sid))
	result.sort()
	return result


func can_plug_room(device_id: String, room_socket: String) -> StringName:
	var sid: String = level_socket_at(room_socket)
	if sid == "":
		return PrizReason.UNKNOWN
	return board.can_plug(device_id, sid)


func plug_room(device_id: String, room_socket: String) -> StringName:
	var sid: String = level_socket_at(room_socket)
	if sid == "":
		return PrizReason.UNKNOWN
	return board.plug(device_id, sid)


# --- yük (blok) ------------------------------------------------------------------

func capacity(room_line: int) -> int:
	var lid: String = level_line_at(room_line)
	return board.line_capacity(lid, FLAT_SLICE) if lid != "" else 0


func load_blocks(room_line: int) -> int:
	var lid: String = level_line_at(room_line)
	return board.line_load(lid, FLAT_SLICE) if lid != "" else 0


func fill(room_line: int) -> float:
	var lid: String = level_line_at(room_line)
	return board.line_peak_fill(lid) if lid != "" else 0.0


## Sürüklenen cihaz bu prize bırakılırsa hattın göstergesi ne olur. `before` cihaz zaten o hattaysa
## onu saymaz (taşıma). `fits` tahtanın kararıdır (yalnız taşma değil, tüm kurallar).
func preview(device_id: String, room_socket: String) -> Dictionary:
	var room_line: int = room_line_of_room_socket(room_socket)
	var before: int = load_blocks(room_line)
	if room_line > 0 and room_line_of(board.line_of_device(device_id)) == room_line:
		before -= device_blocks(device_id)
	var reason: StringName = can_plug_room(device_id, room_socket)
	return {
		"line": room_line,
		"before": before,
		"after": before + device_blocks(device_id),
		"capacity": capacity(room_line),
		"fits": reason == PrizReason.OK,
		"reason": reason,
	}


## Elektrik gerilimi: en dolu hattın oranı (0..1+). Uğultu perdesi buna bağlanır.
func tension() -> float:
	var best: float = 0.0
	for room_line: int in room_lines():
		best = maxf(best, fill(room_line))
	return best


## Sınıra yakın (≥ NEAR_LIMIT_FILL, taşmayan, boş olmayan) hatlar: lambalar titrer.
func near_limit_lines() -> Array[int]:
	var result: Array[int] = []
	for room_line: int in room_lines():
		var f: float = fill(room_line)
		if load_blocks(room_line) > 0 and f >= PrizBoard.NEAR_LIMIT_FILL and f <= 1.0:
			result.append(room_line)
	return result


## Duvar kablosu parlaklığı (RoomView.set_line_glow): boş 0, akım 1, sınıra yaklaştıkça 2.5'e.
func glow_for(room_line: int) -> float:
	if load_blocks(room_line) <= 0:
		return 0.0
	return 1.0 + 1.5 * smoothstep(0.75, 1.0, fill(room_line))


# --- gün kipi (aşama 3): dilim başına yük ------------------------------------------

func is_day_mode() -> bool:
	return board.is_day_mode()


## Hattın dilimdeki yükü (blok).
func load_at(room_line: int, slice: int) -> int:
	var lid: String = level_line_at(room_line)
	return board.line_load(lid, slice) if lid != "" else 0


## Hattın dilimdeki etkin kapasitesi (blok).
func capacity_at(room_line: int, slice: int) -> int:
	var lid: String = level_line_at(room_line)
	return board.line_capacity(lid, slice) if lid != "" else 0


## Dört dilimin yükü (x sabah, y öğle, z akşam, w gece) — gösterge tek seferde alır.
func slice_loads(room_line: int) -> Vector4:
	return Vector4(load_at(room_line, 0), load_at(room_line, 1), load_at(room_line, 2), load_at(room_line, 3))


## Taşan dilimlerin bit maskesi (bit 0 sabah).
func overflow_mask(room_line: int) -> int:
	var mask: int = 0
	for s: int in PrizSlice.COUNT:
		if load_at(room_line, s) > capacity_at(room_line, s):
			mask |= 1 << s
	return mask


## En büyük kapasite (göstergenin sabit yuva sayısı bundan türetilir).
func max_capacity() -> int:
	var best: int = 0
	for room_line: int in room_lines():
		for s: int in PrizSlice.COUNT:
			best = maxi(best, capacity_at(room_line, s))
	return best


## Cihazın çalıştığı dilimler (takılıysa prizine göre, değilse kendi maskesi).
func device_mask(device_id: String) -> int:
	return board.device_slices(device_id)


## Cihaz bu oda prizine takılırsa çalışacağı dilimler (zamanlayıcılı priz önizlemesi dahil).
func device_mask_at(device_id: String, room_socket: String) -> int:
	var sid: String = level_socket_at(room_socket)
	if sid == "":
		return device_mask(device_id)
	return board.device_slices_at(device_id, sid)


## Cihazın dilimlerdeki yükü (çalışmadığı dilimde 0) — tepsi rozeti ve hayalet bloklar için.
func device_loads(device_id: String, room_socket: String = "") -> Vector4:
	var sid: String = level_socket_at(room_socket) if room_socket != "" else board.socket_of(device_id)
	var mask: int = board.device_slices_at(device_id, sid) if sid != "" else device_mask(device_id)
	var v: Vector4 = Vector4.ZERO
	for s: int in PrizSlice.COUNT:
		if PrizSlice.has(mask, s):
			v[s] = float(board.device_load_at(device_id, sid, s)) if sid != "" else float(device_blocks(device_id))
	return v


## Gün kipi önizlemesi: cihaz bu prize bırakılırsa hattın dilim yükleri (cihaz zaten o hattaysa sayılmaz).
## {"line", "before": Vector4, "ghost": Vector4, "overflow_mask", "fits"(kurallar), "reason"}
func day_preview(device_id: String, room_socket: String) -> Dictionary:
	var room_line: int = room_line_of_room_socket(room_socket)
	var before: Vector4 = slice_loads(room_line)
	if room_line > 0 and room_line_of(board.line_of_device(device_id)) == room_line:
		before -= device_loads(device_id)
	var ghost: Vector4 = device_loads(device_id, room_socket)
	var over: int = 0
	for s: int in PrizSlice.COUNT:
		if before[s] + ghost[s] > float(capacity_at(room_line, s)):
			over |= 1 << s
	var reason: StringName = can_plug_room(device_id, room_socket)
	return {"line": room_line, "before": before, "ghost": ghost, "overflow_mask": over,
		"fits": reason == PrizReason.OK, "reason": reason}


## Dilimde çalışan, bu hattaki takılı cihazlar (sigorta atınca "neden"i göstermek için).
func devices_on_line_at(room_line: int, slice: int) -> Array[String]:
	var result: Array[String] = []
	var lid: String = level_line_at(room_line)
	if lid == "":
		return result
	for d: String in board.line_devices(lid):
		if board.is_device_active(d, slice):
			result.append(d)
	return result


## Dilimdeki gerilim: o dilimde en dolu hattın oranı (uğultu perdesi).
func tension_at(slice: int) -> float:
	var best: float = 0.0
	for room_line: int in room_lines():
		var lid: String = level_line_at(room_line)
		best = maxf(best, board.line_fill(lid, slice))
	return best
