extends RefCounted
## Testler için elle kurulmuş küçük seviyeler. `preload` ile kullanılır.


static func line(id: String, capacity: int, props: Dictionary = {}) -> Dictionary:
	return {"id": id, "color": "red", "shape": "circle", "capacity": capacity, "props": props}


static func socket(id: String, line_id: String, room: String, seats: int = 1,
		props: Dictionary = {}) -> Dictionary:
	return {"id": id, "line": line_id, "room": room, "anchor": "%s_x" % room, "seats": seats,
		"props": props}


static func device(id: String, blocks: int, room: String, slices: Array = [],
		props: Dictionary = {}) -> Dictionary:
	var s: Array = slices if not slices.is_empty() else ["morning", "noon", "evening", "night"]
	return {"id": id, "type": "lamp", "load": blocks, "room": room, "slices": s, "props": props}


static func level(mode: String, elements: Array, rooms: Array, lines: Array, sockets: Array,
		devices: Array) -> PrizLevel:
	return PrizLevel.from_dict({
		"format": 1, "id": "fixture", "number": 99, "seed": 1, "mode": mode,
		"difficulty": "normal", "band": [1, 1000],
		"fuse_rights": 3 if mode == "day" else 0,
		"elements": elements, "rooms": rooms, "lines": lines, "sockets": sockets,
		"devices": devices, "meta": {},
	})


## Düz kip; oda kısıtı + topraklı priz. Tek çözüm: d0→s0, d1→s1, d2→s2.
static func flat_a() -> PrizLevel:
	return level("flat", ["room_restriction", "grounded_socket"], ["kitchen", "living"],
		[line("L0", 5), line("L1", 3)],
		[socket("s0", "L0", "kitchen"), socket("s1", "L0", "living"),
			socket("s2", "L1", "kitchen", 1, {"grounded": true}), socket("s3", "L1", "living", 2)],
		[device("d0", 3, "kitchen"), device("d1", 2, "living"),
			device("d2", 2, "kitchen", [], {"needs_ground": true})])


## Gün kipi. Güvenli plan: d0→s0, d1→s1, d2→s2. Hatalı plan: d0→s1, d1→s2, d2→s0 (öğlen L1 taşar).
static func day_b() -> PrizLevel:
	return level("day", ["day_cycle"], ["living"],
		[line("L0", 3), line("L1", 2)],
		[socket("s0", "L0", "living"), socket("s1", "L1", "living"), socket("s2", "L1", "living")],
		[device("d0", 2, "living", ["morning", "noon"]), device("d1", 2, "living", ["noon"]),
			device("d2", 1, "living", ["evening", "night"])])


static func plug_all(board: PrizBoard, plan: Dictionary) -> void:
	for device_id: Variant in plan.keys():
		board.plug(str(device_id), str(plan[device_id]))
