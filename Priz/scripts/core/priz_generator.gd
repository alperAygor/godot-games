class_name PrizGenerator
extends RefCounted
## Tohumlu, belirlenimci seviye üreticisi: aynı tohum + seviye numarası → bayt-bayt aynı seviye.
##
## Akış (her deneme):
##  1. İskelet: odalar, hatlar, cihazlar (katalogdan), prizler (her odada cihaz sayısı + boş yuva).
##  2. PRE_PLANT öğe kancaları (gün kipi, çoklu priz ...).
##  3. Gizli çözüm: her cihaz kurallara uyan rastgele bir prize yerleştirilir.
##  4. POST_PLANT öğe kancaları (toprak, zamanlayıcı, eski kablo, güneş, komşu, kapalı dilim).
##  5. Sıkılaştırma: her hattın kapasitesi gizli çözümün gerektirdiği en aza + boş kapasiteye
##     ayarlanır; çözücü çözüm sayısını sayar, boş kapasite hedef aralığa girene dek kısılır/açılır.
##     Kapasite hiçbir şeyi kısıtlamıyorsa (her şey her yere sığıyorsa) seviye reddedilir.
##  Başarısız deneme yeni alt tohumla tekrarlanır.

const BASE_SEED: int = 1347570010
const MAX_ATTEMPTS: int = 400
const MAX_TIGHTEN_STEPS: int = 16
const MAX_CAPACITY: int = 14
const LINE_COLORS: Array[String] = ["red", "blue", "yellow", "green"]
const LINE_SHAPES: Array[String] = ["circle", "square", "triangle", "star"]
const ROOM_POOL: Array[String] = ["living", "kitchen", "bedroom", "bath"]

var content: PrizContent
var solver: PrizSolver
## Son üretimde harcanan deneme sayısı (rapor için).
var last_attempts: int = 0


func _init(source: PrizContent) -> void:
	content = source
	solver = PrizSolver.new()


static func default_seed(level_number: int) -> int:
	return BASE_SEED + level_number * 7919


static func _mix(a: int, b: int) -> int:
	return posmod(a * 1000003 + b * 9176 + 12345, 2147483647)


## Seviye numarası için seviye üretir; tohum verilmezse varsayılan tohum. Başarısızsa null.
func generate(level_number: int, level_seed: int = -1) -> PrizLevel:
	var s: int = level_seed if level_seed >= 0 else default_seed(level_number)
	return generate_custom(level_number, s, "level_%03d" % level_number)


func generate_custom(level_number: int, level_seed: int, level_id: String) -> PrizLevel:
	var element_ids: Array[String] = choose_elements(level_number, level_seed)
	var intro_ids: Array[String] = []
	for element: PrizElement in content.registry.introduced_at(level_number):
		if element_ids.has(element.id):
			intro_ids.append(element.id)
	var curve: PrizCurve = PrizCurve.for_level(level_number, not intro_ids.is_empty())
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for attempt: int in MAX_ATTEMPTS:
		rng.seed = _mix(level_seed, attempt + 1)
		var level: PrizLevel = _attempt(level_number, level_seed, level_id, curve, element_ids,
				intro_ids, rng)
		if level != null:
			last_attempts = attempt + 1
			level.meta["attempt"] = attempt + 1
			return level
	last_attempts = MAX_ATTEMPTS
	return null


## Seviyede etkin öğeler: açılmış "always" öğeler + tanıtılan öğe; tanıtım yoksa açılmış
## isteğe bağlı öğelerden şansla en fazla `max_optional` tane. "requires" sağlanmalı.
func choose_elements(level_number: int, level_seed: int) -> Array[String]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _mix(level_seed, 7777)
	var intro: Array[PrizElement] = content.registry.introduced_at(level_number)
	var curve: PrizCurve = PrizCurve.for_level(level_number, not intro.is_empty())
	var chosen: Array[String] = []
	for element: PrizElement in content.registry.unlocked_at(level_number):
		if element.always or element.unlock_level == level_number:
			if _requires_ok(element, chosen):
				chosen.append(element.id)
	if intro.is_empty():
		var optional_count: int = 0
		for element: PrizElement in content.registry.unlocked_at(level_number):
			if element.always or chosen.has(element.id):
				continue
			var roll: float = rng.randf()
			if optional_count < curve.max_optional and roll < element.chance \
					and _requires_ok(element, chosen):
				chosen.append(element.id)
				optional_count += 1
	var ordered: Array[String] = []
	for element: PrizElement in content.registry.elements:
		if chosen.has(element.id):
			ordered.append(element.id)
	return ordered


func _requires_ok(element: PrizElement, chosen: Array[String]) -> bool:
	for req: Variant in PrizJson.get_array(element.raw, "requires"):
		if not chosen.has(str(req)):
			return false
	return true


func _attempt(level_number: int, level_seed: int, level_id: String, curve: PrizCurve,
		element_ids: Array[String], intro_ids: Array[String],
		rng: RandomNumberGenerator) -> PrizLevel:
	var registry: PrizElementRegistry = content.registry
	var catalog: PrizCatalog = content.catalog
	var level: PrizLevel = PrizLevel.new()
	level.id = level_id
	level.number = level_number
	level.level_seed = level_seed
	level.mode = PrizLevel.MODE_FLAT
	level.difficulty = curve.difficulty
	level.band_min = curve.band_min
	level.band_max = curve.band_max
	level.fuse_rights = 0
	level.elements = element_ids.duplicate()
	for i: int in curve.rooms:
		level.rooms.append(ROOM_POOL[i % ROOM_POOL.size()])
	for i: int in curve.lines:
		var line: PrizLine = PrizLine.new()
		line.id = "L%d" % i
		line.color = LINE_COLORS[i % LINE_COLORS.size()]
		line.shape = LINE_SHAPES[i % LINE_SHAPES.size()]
		level.lines.append(line)
	# Cihazlar: ilk cihazlar her odaya birer tane, kalanı rastgele odalara.
	var per_room: Dictionary = {}
	for room: String in level.rooms:
		per_room[room] = 0
	for i: int in curve.devices:
		var room: String = level.rooms[i] if i < level.rooms.size() \
				else level.rooms[rng.randi_range(0, level.rooms.size() - 1)]
		var types: Array[String] = catalog.types_for_room(room)
		if types.is_empty():
			return null
		var device: PrizDevice = PrizDevice.new()
		device.id = "d%d" % i
		device.type = types[rng.randi_range(0, types.size() - 1)]
		var load_range: Vector2i = catalog.load_range(device.type)
		device.blocks = clampi(rng.randi_range(load_range.x, maxi(load_range.x, load_range.y)), 1, 5)
		device.room = room
		device.slices = PrizSlice.ALL_MASK
		level.devices.append(device)
		per_room[room] = int(per_room[room]) + 1
	# Prizler: her odada cihaz sayısı kadar yuva + boş yuvalar.
	for k: int in curve.spare:
		var room: String = level.rooms[rng.randi_range(0, level.rooms.size() - 1)]
		per_room[room] = int(per_room[room]) + 1
	for room: String in level.rooms:
		for j: int in int(per_room[room]):
			var socket: PrizSocket = PrizSocket.new()
			socket.room = room
			socket.line = level.lines[rng.randi_range(0, level.lines.size() - 1)].id
			socket.seats = 1
			level.sockets.append(socket)
	if not _ensure_every_line_has_socket(level, rng):
		return null
	var ctx: PrizGenContext = PrizGenContext.new()
	ctx.level = level
	ctx.registry = registry
	ctx.catalog = catalog
	ctx.rng = rng
	ctx.number = level_number
	var rules: Array[PrizRule] = registry.rules_for(element_ids)
	for rule: PrizRule in rules:
		if rule.gen_stage() == PrizRule.STAGE_PRE_PLANT:
			ctx.intro = intro_ids.has(rule.element_id)
			if not rule.gen_apply(ctx):
				return null
	_assign_socket_ids(level)
	# Gizli çözüm.
	var plan: Dictionary = _plant(level, rules, rng)
	if plan.is_empty():
		return null
	for line: PrizLine in level.lines:
		var used: bool = false
		for device: PrizDevice in level.devices:
			var socket: PrizSocket = level.find_socket(str(plan[device.id]))
			if socket.line == line.id:
				used = true
				break
		if not used:
			return null
	ctx.plan = plan
	for rule: PrizRule in rules:
		if rule.gen_stage() == PrizRule.STAGE_POST_PLANT:
			ctx.intro = intro_ids.has(rule.element_id)
			if not rule.gen_apply(ctx):
				return null
	if not _tighten(level, ctx, curve, rng):
		return null
	return level


func _ensure_every_line_has_socket(level: PrizLevel, rng: RandomNumberGenerator) -> bool:
	for line: PrizLine in level.lines:
		var count: int = 0
		for socket: PrizSocket in level.sockets:
			if socket.line == line.id:
				count += 1
		if count > 0:
			continue
		# En kalabalık hattan bir priz devral.
		var donors: Array[int] = []
		for i: int in level.sockets.size():
			var other: String = level.sockets[i].line
			var n: int = 0
			for socket: PrizSocket in level.sockets:
				if socket.line == other:
					n += 1
			if n >= 2:
				donors.append(i)
		if donors.is_empty():
			return false
		level.sockets[donors[rng.randi_range(0, donors.size() - 1)]].line = line.id
	return true


## Prizleri oda sırasına göre yeniden adlandırır: kimlik s0.., anchor "<oda>_<sıra>".
func _assign_socket_ids(level: PrizLevel) -> void:
	var ordered: Array[PrizSocket] = []
	for room: String in level.rooms:
		var j: int = 0
		for socket: PrizSocket in level.sockets:
			if socket.room == room:
				socket.anchor = "%s_%d" % [room, j]
				j += 1
				ordered.append(socket)
	for i: int in ordered.size():
		ordered[i].id = "s%d" % i
	level.sockets = ordered


func _plant(level: PrizLevel, rules: Array[PrizRule], rng: RandomNumberGenerator) -> Dictionary:
	var plan: Dictionary = {}
	var used: Dictionary = {}
	var order: Array[int] = []
	for i: int in level.devices.size():
		order.append(i)
	for i: int in range(order.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: int = order[i]
		order[i] = order[j]
		order[j] = t
	for d: int in order:
		var device: PrizDevice = level.devices[d]
		var candidates: Array[PrizSocket] = []
		for socket: PrizSocket in level.sockets:
			if int(used.get(socket.id, 0)) >= socket.seats:
				continue
			var ok: bool = true
			for rule: PrizRule in rules:
				if rule.check_plug(level, device, socket) != PrizReason.OK:
					ok = false
					break
			if ok:
				candidates.append(socket)
		if candidates.is_empty():
			return {}
		var pick: PrizSocket = candidates[rng.randi_range(0, candidates.size() - 1)]
		plan[device.id] = pick.id
		used[pick.id] = int(used.get(pick.id, 0)) + 1
	return plan


## Hattın taban kapasitesi b iken dilimdeki etkin kapasitesi.
func _effective(level: PrizLevel, rules: Array[PrizRule], line: PrizLine, slice: int,
		base: int) -> int:
	var cap: int = base
	for rule: PrizRule in rules:
		cap = rule.modify_capacity(level, line, slice, cap)
	return maxi(cap, 0)


func _tighten(level: PrizLevel, ctx: PrizGenContext, curve: PrizCurve,
		rng: RandomNumberGenerator) -> bool:
	var rules: Array[PrizRule] = content.registry.rules_for(level.elements)
	# Gizli çözüm kurallarla uyumlu mu (POST_PLANT kancaları bozmuş olabilir)?
	var c0: PrizCompiled = PrizCompiled.build(level, content.registry)
	var plan_idx: PackedInt32Array = ctx.plan_indices(c0)
	for d: int in c0.n_devices:
		if plan_idx[d] < 0 or c0.compat_of(d, plan_idx[d]) != PrizReason.OK:
			return false
	var loads: PackedInt32Array = c0.line_loads(plan_idx)
	var need: Array[int] = []
	for l: int in level.lines.size():
		var line: PrizLine = level.lines[l]
		var found: int = -1
		for b: int in range(1, MAX_CAPACITY + 1):
			var ok: bool = true
			for s: int in PrizSlice.COUNT:
				if _effective(level, rules, line, s, b) < loads[l * PrizSlice.COUNT + s]:
					ok = false
					break
			if ok:
				found = b
				break
		if found < 0:
			return false
		need.append(found)
	var slack: Array[int] = []
	for l: int in level.lines.size():
		slack.append(curve.slack)
	for step: int in MAX_TIGHTEN_STEPS:
		for l: int in level.lines.size():
			level.lines[l].capacity = mini(need[l] + slack[l], MAX_CAPACITY)
		var c: PrizCompiled = PrizCompiled.build(level, content.registry)
		var res: PrizSolveResult = solver.count_compiled(c, curve.band_max + 1)
		if res.node_limit_hit:
			return false
		var count: int = res.count
		var in_band: bool = count >= curve.band_min and count <= curve.band_max
		var loose: bool = false
		if in_band and not curve.tutorial:
			var free: PrizSolveResult = solver.count_compiled(c, count + 1, true)
			loose = free.count <= count
		if in_band and not loose:
			level.meta = {"solutions": count, "nodes": res.nodes}
			return true
		var candidates: Array[int] = []
		if count > curve.band_max or loose:
			for l: int in slack.size():
				if slack[l] > 0:
					candidates.append(l)
			if candidates.is_empty():
				return false
			slack[candidates[rng.randi_range(0, candidates.size() - 1)]] -= 1
		else:
			for l: int in slack.size():
				if slack[l] < curve.max_slack and need[l] + slack[l] < MAX_CAPACITY:
					candidates.append(l)
			if candidates.is_empty():
				return false
			slack[candidates[rng.randi_range(0, candidates.size() - 1)]] += 1
	return false
