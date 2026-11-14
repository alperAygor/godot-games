class_name PrizCompiled
extends RefCounted
## Seviyenin kurallar uygulanmış, dizinlenmiş hâli. Tahta ve çözücü aynı derlenmiş veriyi
## kullanır; böylece "tahtada geçerli" ile "çözücüde geçerli" asla ayrışmaz.
## İç kullanım içindir; arayüz PrizBoard üzerinden konuşur.

var level: PrizLevel
var rules: Array[PrizRule] = []
var day_mode: bool = false
var missing_elements: PackedStringArray = PackedStringArray()

var n_lines: int = 0
var n_sockets: int = 0
var n_devices: int = 0
var line_index: Dictionary = {}
var socket_index: Dictionary = {}
var device_index: Dictionary = {}

var socket_line: PackedInt32Array = PackedInt32Array()
var socket_seats: PackedInt32Array = PackedInt32Array()
var socket_class: PackedInt32Array = PackedInt32Array()

## [hat*4 + dilim]
var capacity: PackedInt32Array = PackedInt32Array()
var external: PackedInt32Array = PackedInt32Array()

## [cihaz*n_sockets + priz]
var compat: Array[StringName] = []
var mask: PackedInt32Array = PackedInt32Array()
## [(cihaz*n_sockets + priz)*4 + dilim]
var device_load: PackedInt32Array = PackedInt32Array()

## Eş priz sınıfları (aynı hat, oda ve props).
var n_classes: int = 0
var class_line: PackedInt32Array = PackedInt32Array()
var class_seats: PackedInt32Array = PackedInt32Array()
var class_sockets: Array[PackedInt32Array] = []


static func build(source: PrizLevel, registry: PrizElementRegistry) -> PrizCompiled:
	var c: PrizCompiled = PrizCompiled.new()
	c._build(source, registry)
	return c


func _build(source: PrizLevel, registry: PrizElementRegistry) -> void:
	level = source
	day_mode = source.is_day_mode()
	if registry != null:
		rules = registry.rules_for(source.elements)
		for element_id: String in source.elements:
			if registry.get_element(element_id) == null:
				missing_elements.append(element_id)
	n_lines = source.lines.size()
	n_sockets = source.sockets.size()
	n_devices = source.devices.size()
	for i: int in n_lines:
		line_index[source.lines[i].id] = i
	for i: int in n_sockets:
		socket_index[source.sockets[i].id] = i
	for i: int in n_devices:
		device_index[source.devices[i].id] = i

	capacity.resize(n_lines * PrizSlice.COUNT)
	external.resize(n_lines * PrizSlice.COUNT)
	for l: int in n_lines:
		var line: PrizLine = source.lines[l]
		for s: int in PrizSlice.COUNT:
			var cap: int = line.capacity
			var ext: int = 0
			for rule: PrizRule in rules:
				cap = rule.modify_capacity(source, line, s, cap)
				ext += rule.external_load(source, line, s)
			capacity[l * PrizSlice.COUNT + s] = maxi(cap, 0)
			external[l * PrizSlice.COUNT + s] = maxi(ext, 0)

	socket_line.resize(n_sockets)
	socket_seats.resize(n_sockets)
	socket_class.resize(n_sockets)
	var class_keys: Dictionary = {}
	for i: int in n_sockets:
		var socket: PrizSocket = source.sockets[i]
		socket_line[i] = int(line_index.get(socket.line, 0))
		socket_seats[i] = maxi(socket.seats, 1)
		var key: String = "%s|%s|%s" % [socket.line, socket.room, JSON.stringify(socket.props, "", true)]
		if not class_keys.has(key):
			class_keys[key] = n_classes
			class_line.append(socket_line[i])
			class_seats.append(0)
			class_sockets.append(PackedInt32Array())
			n_classes += 1
		var ci: int = int(class_keys[key])
		socket_class[i] = ci
		class_seats[ci] += socket_seats[i]
		class_sockets[ci].append(i)

	compat.resize(n_devices * n_sockets)
	mask.resize(n_devices * n_sockets)
	device_load.resize(n_devices * n_sockets * PrizSlice.COUNT)
	for d: int in n_devices:
		var device: PrizDevice = source.devices[d]
		for i: int in n_sockets:
			var socket: PrizSocket = source.sockets[i]
			var reason: StringName = PrizReason.OK
			for rule: PrizRule in rules:
				reason = rule.check_plug(source, device, socket)
				if reason != PrizReason.OK:
					break
			compat[d * n_sockets + i] = reason
			var m: int = device.slices if day_mode else PrizSlice.ALL_MASK
			for rule: PrizRule in rules:
				m = rule.modify_mask(source, device, socket, m)
			m &= PrizSlice.ALL_MASK
			mask[d * n_sockets + i] = m
			for s: int in PrizSlice.COUNT:
				var blocks: int = device.blocks if PrizSlice.has(m, s) else 0
				for rule: PrizRule in rules:
					blocks = rule.modify_load(source, device, socket, s, blocks)
				device_load[(d * n_sockets + i) * PrizSlice.COUNT + s] = maxi(blocks, 0)


func load_of(d: int, socket: int, slice: int) -> int:
	return device_load[(d * n_sockets + socket) * PrizSlice.COUNT + slice]


func cap_of(line: int, slice: int) -> int:
	return capacity[line * PrizSlice.COUNT + slice]


func ext_of(line: int, slice: int) -> int:
	return external[line * PrizSlice.COUNT + slice]


func compat_of(d: int, socket: int) -> StringName:
	return compat[d * n_sockets + socket]


func mask_of(d: int, socket: int) -> int:
	return mask[d * n_sockets + socket]


## Yerleşimin (cihaz → priz dizini, -1 boş) her hat ve dilim için yükü (dış yük dahil).
func line_loads(placement: PackedInt32Array) -> PackedInt32Array:
	var loads: PackedInt32Array = external.duplicate()
	for d: int in n_devices:
		var sock: int = placement[d]
		if sock < 0:
			continue
		var l: int = socket_line[sock]
		for s: int in PrizSlice.COUNT:
			loads[l * PrizSlice.COUNT + s] += load_of(d, sock, s)
	return loads


## Tam ve geçerli çözüm mü: her cihaz takılı, uyumlu, yuvalar yetiyor, hiçbir hat taşmıyor.
func is_valid_solution(placement: PackedInt32Array) -> bool:
	if placement.size() != n_devices:
		return false
	var used: PackedInt32Array = PackedInt32Array()
	used.resize(n_sockets)
	used.fill(0)
	for d: int in n_devices:
		var sock: int = placement[d]
		if sock < 0 or sock >= n_sockets:
			return false
		if compat_of(d, sock) != PrizReason.OK:
			return false
		used[sock] += 1
		if used[sock] > socket_seats[sock]:
			return false
	var loads: PackedInt32Array = line_loads(placement)
	for i: int in loads.size():
		if loads[i] > capacity[i]:
			return false
	return true
