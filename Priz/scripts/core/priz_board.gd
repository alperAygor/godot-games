class_name PrizBoard
extends RefCounted
## Kural motoru: bir seviyenin oynanış durumu (yerleşim, sigorta hakları, kazanma/kaybetme).
## Sahneden bağımsızdır; arayüz yalnız bu sınıfın yöntemleriyle konuşur. Tüm yük ve
## kapasiteler blok sayısı ya da doluluk oranı olarak döner; ekranda rakam gösterilmez.
##
##   var board := PrizBoard.new(level, content.registry)
##   if board.can_plug("d0", "s1") == PrizReason.OK: board.plug("d0", "s1")
##   var events: Array[PrizEvent] = board.start_day()

enum State { PLANNING, WON, LOST }

## Bu doluluğa ulaşan (ama taşmayan) hat "sınıra yakın" sayılır (lambalar titrer).
const NEAR_LIMIT_FILL: float = 0.8

var level: PrizLevel

var _c: PrizCompiled
var _placement: PackedInt32Array = PackedInt32Array()
var _occupancy: PackedInt32Array = PackedInt32Array()
## Takılı cihazların hat yükü [hat*4 + dilim] (dış yük hariç).
var _device_load: PackedInt32Array = PackedInt32Array()
var _state: State = State.PLANNING
var _rights: int = 0
var _days_run: int = 0


func _init(source: PrizLevel, registry: PrizElementRegistry) -> void:
	level = source
	_c = PrizCompiled.build(source, registry)
	_placement.resize(_c.n_devices)
	_placement.fill(-1)
	_occupancy.resize(_c.n_sockets)
	_occupancy.fill(0)
	_device_load.resize(_c.n_lines * PrizSlice.COUNT)
	_device_load.fill(0)
	_rights = source.fuse_rights if source.is_day_mode() else 0


func compiled() -> PrizCompiled:
	return _c


# --- durum -------------------------------------------------------------------

func state() -> State:
	return _state


func is_planning() -> bool:
	return _state == State.PLANNING


func is_won() -> bool:
	return _state == State.WON


func is_lost() -> bool:
	return _state == State.LOST


func is_day_mode() -> bool:
	return _c.day_mode


func fuse_rights() -> int:
	return _rights


## Kaç kez "günü başlat" denendi.
func days_run() -> int:
	return _days_run


## Ödüllü reklam: +1 sigorta hakkı. Kaybedilmişse plana geri döner (plan korunur).
func grant_extra_right() -> void:
	if not _c.day_mode or _state == State.WON:
		return
	_rights += 1
	if _state == State.LOST:
		_state = State.PLANNING


# --- yerleşim ----------------------------------------------------------------

func can_plug(device_id: String, socket_id: String) -> StringName:
	var d: int = int(_c.device_index.get(device_id, -1))
	var sock: int = int(_c.socket_index.get(socket_id, -1))
	if d < 0 or sock < 0:
		return PrizReason.UNKNOWN
	return _can_plug_index(d, sock)


func _can_plug_index(d: int, sock: int) -> StringName:
	if _state != State.PLANNING:
		return PrizReason.NOT_PLANNING
	if _placement[d] == sock:
		return PrizReason.OK
	var reason: StringName = _c.compat_of(d, sock)
	if reason != PrizReason.OK:
		return reason
	if _occupancy[sock] >= _c.socket_seats[sock]:
		return PrizReason.SOCKET_FULL
	if not _c.day_mode:
		var l: int = _c.socket_line[sock]
		var current: int = _placement[d]
		for s: int in PrizSlice.COUNT:
			var blocks: int = _device_load[l * PrizSlice.COUNT + s] + _c.ext_of(l, s)
			if current >= 0 and _c.socket_line[current] == l:
				blocks -= _c.load_of(d, current, s)
			if blocks + _c.load_of(d, sock, s) > _c.cap_of(l, s):
				return PrizReason.WOULD_OVERFLOW
	return PrizReason.OK


## Takılıysa cihazı yeni prize taşır. Başarıda OK, aksi hâlde ret kodu (durum değişmez).
## Düz kipte son cihaz da oturunca seviye kazanılır.
func plug(device_id: String, socket_id: String) -> StringName:
	var d: int = int(_c.device_index.get(device_id, -1))
	var sock: int = int(_c.socket_index.get(socket_id, -1))
	if d < 0 or sock < 0:
		return PrizReason.UNKNOWN
	var reason: StringName = _can_plug_index(d, sock)
	if reason != PrizReason.OK:
		return reason
	if _placement[d] == sock:
		return PrizReason.OK
	if _placement[d] >= 0:
		_remove(d)
	_add(d, sock)
	if not _c.day_mode and is_all_plugged():
		_state = State.WON
	return PrizReason.OK


## Cihazı tepsiye döndürür. Takılı değilse ya da planlama bittiyse false.
func unplug(device_id: String) -> bool:
	var d: int = int(_c.device_index.get(device_id, -1))
	if d < 0 or _state != State.PLANNING or _placement[d] < 0:
		return false
	_remove(d)
	return true


## Tüm cihazları tepsiye döndürür (planlamada).
func clear() -> void:
	if _state != State.PLANNING:
		return
	for d: int in _c.n_devices:
		if _placement[d] >= 0:
			_remove(d)


func _add(d: int, sock: int) -> void:
	_placement[d] = sock
	_occupancy[sock] += 1
	var l: int = _c.socket_line[sock]
	for s: int in PrizSlice.COUNT:
		_device_load[l * PrizSlice.COUNT + s] += _c.load_of(d, sock, s)


func _remove(d: int) -> void:
	var sock: int = _placement[d]
	_placement[d] = -1
	_occupancy[sock] -= 1
	var l: int = _c.socket_line[sock]
	for s: int in PrizSlice.COUNT:
		_device_load[l * PrizSlice.COUNT + s] -= _c.load_of(d, sock, s)


## Cihazın prizi; takılı değilse "".
func socket_of(device_id: String) -> String:
	var d: int = int(_c.device_index.get(device_id, -1))
	if d < 0 or _placement[d] < 0:
		return ""
	return level.sockets[_placement[d]].id


func devices_in(socket_id: String) -> Array[String]:
	var result: Array[String] = []
	var sock: int = int(_c.socket_index.get(socket_id, -1))
	for d: int in _c.n_devices:
		if sock >= 0 and _placement[d] == sock:
			result.append(level.devices[d].id)
	return result


func free_seats(socket_id: String) -> int:
	var sock: int = int(_c.socket_index.get(socket_id, -1))
	if sock < 0:
		return 0
	return _c.socket_seats[sock] - _occupancy[sock]


func is_all_plugged() -> bool:
	for d: int in _c.n_devices:
		if _placement[d] < 0:
			return false
	return true


func unplugged_devices() -> Array[String]:
	var result: Array[String] = []
	for d: int in _c.n_devices:
		if _placement[d] < 0:
			result.append(level.devices[d].id)
	return result


## Yerleşim kopyası: cihaz kimliği → priz kimliği (yalnız takılılar).
func placement() -> Dictionary:
	var result: Dictionary = {}
	for d: int in _c.n_devices:
		if _placement[d] >= 0:
			result[level.devices[d].id] = level.sockets[_placement[d]].id
	return result


## Kayıtlı bir planı geri yükler (planlamada). Kurala uymayan girdiler atlanır;
## yerleştirilemeyenlerin kimlikleri döner.
func apply_placement(plan: Dictionary) -> Array[String]:
	var rejected: Array[String] = []
	clear()
	for device: PrizDevice in level.devices:
		if not plan.has(device.id):
			continue
		if plug(device.id, str(plan[device.id])) != PrizReason.OK:
			rejected.append(device.id)
	return rejected


## Dizin biçiminde yerleşim (çözücü için).
func placement_indices() -> PackedInt32Array:
	return _placement.duplicate()


# --- vurgu sorguları ----------------------------------------------------------

## Tutulan cihazın şu an takılabileceği prizler (parlayanlar); diğerleri solar.
func sockets_accepting(device_id: String) -> Array[String]:
	var result: Array[String] = []
	var d: int = int(_c.device_index.get(device_id, -1))
	if d < 0:
		return result
	for sock: int in _c.n_sockets:
		if _can_plug_index(d, sock) == PrizReason.OK:
			result.append(level.sockets[sock].id)
	return result


## Her prizin ret kodu: priz kimliği → PrizReason (sürüklerken neden soluk olduğunu göstermek için).
func plug_reasons(device_id: String) -> Dictionary:
	var result: Dictionary = {}
	for socket: PrizSocket in level.sockets:
		result[socket.id] = can_plug(device_id, socket.id)
	return result


func line_of_socket(socket_id: String) -> String:
	var socket: PrizSocket = level.find_socket(socket_id)
	return socket.line if socket != null else ""


func line_of_device(device_id: String) -> String:
	var sock_id: String = socket_of(device_id)
	return line_of_socket(sock_id) if sock_id != "" else ""


## Hattın tüm prizleri (bir prize dokununca hepsi birlikte parlar).
func line_sockets(line_id: String) -> Array[String]:
	var result: Array[String] = []
	for socket: PrizSocket in level.sockets:
		if socket.line == line_id:
			result.append(socket.id)
	return result


## Hatta takılı cihazlar.
func line_devices(line_id: String) -> Array[String]:
	var result: Array[String] = []
	var l: int = int(_c.line_index.get(line_id, -1))
	for d: int in _c.n_devices:
		var sock: int = _placement[d]
		if l >= 0 and sock >= 0 and _c.socket_line[sock] == l:
			result.append(level.devices[d].id)
	return result


# --- yük sorguları (blok cinsinden; ekranda rakam değil görsel olarak çizilir) ----------

## Hattın dilimdeki toplam yükü: takılı cihazlar + dış yük (komşu hattı).
func line_load(line_id: String, slice: int) -> int:
	var l: int = int(_c.line_index.get(line_id, -1))
	if l < 0 or slice < 0 or slice >= PrizSlice.COUNT:
		return 0
	return _device_load[l * PrizSlice.COUNT + slice] + _c.ext_of(l, slice)


## Yalnız cihazlardan gelen yük.
func line_device_load(line_id: String, slice: int) -> int:
	var l: int = int(_c.line_index.get(line_id, -1))
	if l < 0 or slice < 0 or slice >= PrizSlice.COUNT:
		return 0
	return _device_load[l * PrizSlice.COUNT + slice]


## Dış yük (komşu hattı vb.).
func line_external_load(line_id: String, slice: int) -> int:
	var l: int = int(_c.line_index.get(line_id, -1))
	if l < 0 or slice < 0 or slice >= PrizSlice.COUNT:
		return 0
	return _c.ext_of(l, slice)


## Etkin kapasite (öğeler uygulanmış: eski kablo, güneş paneli, kapalı dilim ...).
func line_capacity(line_id: String, slice: int) -> int:
	var l: int = int(_c.line_index.get(line_id, -1))
	if l < 0 or slice < 0 or slice >= PrizSlice.COUNT:
		return 0
	return _c.cap_of(l, slice)


## Hattın dosyadaki taban kapasitesi (öğeler uygulanmadan).
func line_base_capacity(line_id: String) -> int:
	var line: PrizLine = level.find_line(line_id)
	return line.capacity if line != null else 0


## Doluluk oranı: yük / kapasite (1'i aşarsa taşma). Kapasite 0 iken yük varsa 2.0.
func line_fill(line_id: String, slice: int) -> float:
	return _fill(line_load(line_id, slice), line_capacity(line_id, slice))


static func _fill(blocks: int, cap: int) -> float:
	if cap <= 0:
		return 0.0 if blocks <= 0 else 2.0
	return float(blocks) / float(cap)


## Düz kipte tek "an" vardır; en dolu dilimin oranı döner. Gün kipinde en kötü dilim.
func line_peak_fill(line_id: String) -> float:
	var best: float = 0.0
	for s: int in PrizSlice.COUNT:
		best = maxf(best, line_fill(line_id, s))
	return best


## Planın taşan (hat, dilim) çiftleri: [{"line": id, "slice": s}]. Gün önizlemesi için.
func overflows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for l: int in _c.n_lines:
		for s: int in PrizSlice.COUNT:
			var blocks: int = _device_load[l * PrizSlice.COUNT + s] + _c.ext_of(l, s)
			if blocks > _c.cap_of(l, s):
				result.append({"line": level.lines[l].id, "slice": s})
	return result


## Cihaz bu dilimde çalışıyor mu? Takılıysa prizin etkisi (zamanlayıcı) dahildir.
func is_device_active(device_id: String, slice: int) -> bool:
	return PrizSlice.has(device_slices(device_id), slice)


## Cihazın etkin dilim maskesi (takılı değilse kendi dilimleri; düz kipte hepsi).
func device_slices(device_id: String) -> int:
	var d: int = int(_c.device_index.get(device_id, -1))
	if d < 0:
		return 0
	if _placement[d] >= 0:
		return _c.mask_of(d, _placement[d])
	if not _c.day_mode:
		return PrizSlice.ALL_MASK
	return level.devices[d].slices


## Bu prize takılsaydı cihazın etkin dilim maskesi (zamanlayıcılı prizi önizlemek için).
func device_slices_at(device_id: String, socket_id: String) -> int:
	var d: int = int(_c.device_index.get(device_id, -1))
	var sock: int = int(_c.socket_index.get(socket_id, -1))
	if d < 0 or sock < 0:
		return 0
	return _c.mask_of(d, sock)


## Cihazın bu prizde, bu dilimde bindireceği yük (blok).
func device_load_at(device_id: String, socket_id: String, slice: int) -> int:
	var d: int = int(_c.device_index.get(device_id, -1))
	var sock: int = int(_c.socket_index.get(socket_id, -1))
	if d < 0 or sock < 0 or slice < 0 or slice >= PrizSlice.COUNT:
		return 0
	return _c.load_of(d, sock, slice)


# --- gün benzetimi -------------------------------------------------------------

## "Günü başlat" etkin mi: gün kipi, planlama ve tüm cihazlar takılı.
func can_start_day() -> bool:
	return _c.day_mode and _state == State.PLANNING and is_all_plugged()


## Dört dilimi sırayla benzetir ve sahnenin canlandıracağı olay listesini döner.
## İlk taşan dilimde: taşan her hat için FUSE_BLOWN (tek hak düşer), sonra
## BACK_TO_PLANNING ya da LOSE. Plan hiçbir durumda silinmez.
## Başlatılamıyorsa boş liste döner.
func start_day() -> Array[PrizEvent]:
	var events: Array[PrizEvent] = []
	if not can_start_day():
		return events
	_days_run += 1
	events.append(PrizEvent.make(PrizEvent.DAY_START))
	var previous: PackedInt32Array = PackedInt32Array()
	previous.resize(_c.n_devices)
	previous.fill(0)
	for s: int in PrizSlice.COUNT:
		events.append(PrizEvent.make(PrizEvent.SLICE_BEGIN, s))
		var active: PackedInt32Array = PackedInt32Array()
		active.resize(_c.n_devices)
		for d: int in _c.n_devices:
			active[d] = 1 if PrizSlice.has(_c.mask_of(d, _placement[d]), s) else 0
		for d: int in _c.n_devices:
			if previous[d] == 1 and active[d] == 0:
				var off: PrizEvent = PrizEvent.make(PrizEvent.DEVICE_OFF, s)
				off.device_id = level.devices[d].id
				events.append(off)
		for d: int in _c.n_devices:
			if previous[d] == 0 and active[d] == 1:
				var on: PrizEvent = PrizEvent.make(PrizEvent.DEVICE_ON, s)
				on.device_id = level.devices[d].id
				events.append(on)
		previous = active
		var blown: Array[int] = []
		var near: Array[int] = []
		for l: int in _c.n_lines:
			var blocks: int = _device_load[l * PrizSlice.COUNT + s] + _c.ext_of(l, s)
			var cap: int = _c.cap_of(l, s)
			var e: PrizEvent = PrizEvent.make(PrizEvent.LINE_LOAD, s)
			e.line_id = level.lines[l].id
			e.blocks = blocks
			e.capacity = cap
			e.fill = _fill(blocks, cap)
			events.append(e)
			if blocks > cap:
				blown.append(l)
			elif blocks > 0 and e.fill >= NEAR_LIMIT_FILL:
				near.append(l)
		for l: int in near:
			var n: PrizEvent = PrizEvent.make(PrizEvent.LINE_NEAR_LIMIT, s)
			n.line_id = level.lines[l].id
			n.blocks = line_load(n.line_id, s)
			n.capacity = _c.cap_of(l, s)
			n.fill = _fill(n.blocks, n.capacity)
			events.append(n)
		if not blown.is_empty():
			_rights = maxi(_rights - 1, 0)
			for l: int in blown:
				var f: PrizEvent = PrizEvent.make(PrizEvent.FUSE_BLOWN, s)
				f.line_id = level.lines[l].id
				f.blocks = line_load(f.line_id, s)
				f.capacity = _c.cap_of(l, s)
				f.fill = _fill(f.blocks, f.capacity)
				f.rights = _rights
				events.append(f)
			if _rights <= 0:
				_state = State.LOST
				var lose: PrizEvent = PrizEvent.make(PrizEvent.LOSE, s)
				lose.rights = 0
				events.append(lose)
			else:
				var back: PrizEvent = PrizEvent.make(PrizEvent.BACK_TO_PLANNING, s)
				back.rights = _rights
				events.append(back)
			return events
	events.append(PrizEvent.make(PrizEvent.DAY_SURVIVED))
	events.append(PrizEvent.make(PrizEvent.WIN))
	_state = State.WON
	return events
