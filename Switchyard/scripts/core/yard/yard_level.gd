class_name YardLevel
extends RefCounted
## Doğrulanmış, değişmez seviye (docs/CORE_API.md §1). Python aynası: tools/yard/rules.py `Level`.
## Doğrulama bozuk dosyanın oyunda sessizce saçma davranmasını önler; hata metni `validate()` ile alınır.

const CELL_KINDS: PackedStringArray = ["plain", "spring", "gate", "plate"]
## Araç türleri: yeni mekanik buraya eklenir (deneyde "fragile" elendi, docs/YARD.md §6).
const VEHICLE_KINDS: PackedStringArray = ["plain"]
const COLORS: PackedStringArray = ["red", "blue", "yellow", "green", "purple", "orange"]

var id: String = ""
var world: int = 1
var par: int = 0
## Lokomotifin çekiş gücü (en çok kaç vagon); 0 = sınırsız.
var power: int = 0
var loco_id: String = ""

var _a: Array[PackedInt32Array] = []
var _b: Array[PackedInt32Array] = []
var _pos: PackedVector2Array = PackedVector2Array()
var _kind: PackedStringArray = PackedStringArray()
var _spring: PackedInt32Array = PackedInt32Array()
var _side_of: Dictionary[int, int] = {}
var _targets: Array[Dictionary] = []
var _solution: Array[Dictionary] = []
var _metrics: Dictionary = {}
var _vehicle_ids: PackedStringArray = PackedStringArray()
var _vtype: Dictionary[String, String] = {}
var _vcolor: Dictionary[String, String] = {}
var _vkind: Dictionary[String, String] = {}
var _start_pos: Dictionary[String, int] = {}
var _start_links: Array[PackedStringArray] = []
var _has_gate: bool = false
var _err: String = ""


## Doğrular; hatada null + push_error.
static func from_dict(data: Dictionary) -> YardLevel:
	var lv: YardLevel = YardLevel.new()
	if not lv._parse(data):
		push_error("YardLevel %s: %s" % [str(data.get("id", "?")), lv._err])
		return null
	return lv


## Hata metni ("" = geçerli). push_error basmaz (testler ve araçlar için).
static func validate(data: Dictionary) -> String:
	var lv: YardLevel = YardLevel.new()
	if lv._parse(data):
		return ""
	return lv._err


func cell_count() -> int:
	return _a.size()


func cell_pos(cell: int) -> Vector2:
	return _pos[cell]


func neighbors(cell: int, side: int) -> PackedInt32Array:
	return _a[cell] if side == 0 else _b[cell]


func cell_kind(cell: int) -> String:
	return _kind[cell]


## Yaylı makasın zorunlu dalı; yaylı değilse -1.
func spring_branch(cell: int) -> int:
	return _spring[cell]


func has_gate() -> bool:
	return _has_gate


func targets() -> Array[Dictionary]:
	return _targets.duplicate(true)


func solution() -> Array[Dictionary]:
	return _solution.duplicate(true)


func metrics() -> Dictionary:
	return _metrics.duplicate(true)


## p hücresinin q'ya bakan yanı; komşu değilse -1.
func side_of(p: int, q: int) -> int:
	return _side_of.get(p * 65536 + q, -1)


func adjacent(p: int, q: int) -> bool:
	return _side_of.has(p * 65536 + q)


func vehicle_ids() -> PackedStringArray:
	return _vehicle_ids.duplicate()


func vehicle_type(vid: String) -> String:
	return _vtype.get(vid, "")


func vehicle_color(vid: String) -> String:
	return _vcolor.get(vid, "")


func vehicle_kind(vid: String) -> String:
	return _vkind.get(vid, "")


func start_cell(vid: String) -> int:
	return _start_pos.get(vid, -1)


func start_links() -> Array[PackedStringArray]:
	return _start_links.duplicate()


# --- ayrıştırma ---

func _fail(msg: String) -> bool:
	_err = msg
	return false


## JSON sayıları float gelir (GOTCHAS 20); küsuratsız float tamsayı kabul edilir.
static func _is_int(v: Variant) -> bool:
	if v is int:
		return true
	if v is float:
		var f: float = v
		return is_equal_approx(f, roundf(f))
	return false


func _parse(data: Dictionary) -> bool:
	id = str(data.get("id", ""))
	if data.has("world"):
		if not _is_int(data["world"]):
			return _fail("world tamsayı değil")
		world = int(data["world"])
	if data.has("par"):
		if not _is_int(data["par"]):
			return _fail("par tamsayı değil")
		par = int(data["par"])
	var raw_cells: Variant = data.get("cells")
	if not (raw_cells is Array) or (raw_cells as Array).is_empty():
		return _fail("cells boş olamaz")
	var cells: Array = raw_cells
	var n: int = cells.size()
	for i: int in n:
		if not (cells[i] is Dictionary):
			return _fail("hücre %d sözlük değil" % i)
		var c: Dictionary = cells[i]
		var sides: Array[PackedInt32Array] = []
		for key: String in ["a", "b"]:
			var lst: Variant = c.get(key, [])
			if not (lst is Array) or (lst as Array).size() > 2:
				return _fail("hücre %d yan %s: 0-2 komşu olmalı" % [i, key])
			var vals: PackedInt32Array = PackedInt32Array()
			for v: Variant in lst as Array:
				if not _is_int(v):
					return _fail("hücre %d komşu tamsayı değil" % i)
				var q: int = int(v)
				if q < 0 or q >= n:
					return _fail("hücre %d: komşu aralık dışı (%d)" % [i, q])
				if q == i:
					return _fail("hücre %d kendine komşu" % i)
				vals.append(q)
			sides.append(vals)
		var seen: Dictionary[int, bool] = {}
		for s: int in 2:
			for q: int in sides[s]:
				if seen.has(q):
					return _fail("hücre %d: aynı komşu iki kez" % i)
				seen[q] = true
		_a.append(sides[0])
		_b.append(sides[1])
		var x: Variant = c.get("x", 0)
		var y: Variant = c.get("y", 0)
		if not (x is int or x is float) or not (y is int or y is float):
			return _fail("hücre %d: x/y sayı olmalı" % i)
		_pos.append(Vector2(float(x), float(y)))
		var kind: String = str(c.get("kind", "plain"))
		if not CELL_KINDS.has(kind):
			return _fail("hücre %d: bilinmeyen tür %s" % [i, kind])
		_kind.append(kind)
		var spring: int = -1
		if kind == "spring":
			var sv: Variant = c.get("spring", 0)
			if not _is_int(sv):
				return _fail("spring tamsayı değil")
			spring = int(sv)
			var branching: int = 0
			for s: int in 2:
				if sides[s].size() == 2:
					branching += 1
			if branching != 1 or (spring != 0 and spring != 1):
				return _fail("hücre %d: yaylı makas tam bir dallanan yan ister" % i)
		_spring.append(spring)
		if kind == "gate":
			_has_gate = true
	for p: int in n:
		for s: int in 2:
			for q: int in neighbors(p, s):
				_side_of[p * 65536 + q] = s
	for k: int in _side_of.keys():
		var p2: int = k / 65536
		var q2: int = k % 65536
		if not _side_of.has(q2 * 65536 + p2):
			return _fail("komşuluk simetrik değil: %d -> %d" % [p2, q2])
	# Araçlar
	var raw_v: Variant = data.get("vehicles")
	if not (raw_v is Array) or (raw_v as Array).is_empty():
		return _fail("vehicles boş olamaz")
	var used: Dictionary[int, bool] = {}
	for item: Variant in raw_v as Array:
		if not (item is Dictionary):
			return _fail("araç sözlük değil")
		var v: Dictionary = item
		var vid: String = str(v.get("id", ""))
		if vid == "" or _vtype.has(vid):
			return _fail("araç kimliği boş ya da yinelenmiş: %s" % vid)
		var vt: String = str(v.get("type", ""))
		if vt != "loco" and vt != "wagon":
			return _fail("araç %s: tür %s" % [vid, vt])
		var color: String = str(v.get("color", "loco" if vt == "loco" else ""))
		if vt == "wagon" and not COLORS.has(color):
			return _fail("vagon %s: renk %s" % [vid, color])
		if vt == "loco":
			if loco_id != "":
				return _fail("birden çok lokomotif")
			loco_id = vid
			color = "loco"
			var pw: Variant = v.get("power", 0)
			if not _is_int(pw) or int(pw) < 0:
				return _fail("power geçersiz")
			power = int(pw)
		var vk: String = str(v.get("kind", "plain"))
		if not VEHICLE_KINDS.has(vk) or (vt == "loco" and vk != "plain"):
			return _fail("araç %s: tür %s" % [vid, vk])
		var cv: Variant = v.get("cell", -1)
		if not _is_int(cv):
			return _fail("araç %s: hücre tamsayı değil" % vid)
		var cell: int = int(cv)
		if cell < 0 or cell >= n:
			return _fail("araç %s: hücre aralık dışı" % vid)
		if used.has(cell):
			return _fail("iki araç aynı hücrede (%d)" % cell)
		used[cell] = true
		_vehicle_ids.append(vid)
		_vtype[vid] = vt
		_vcolor[vid] = color
		_vkind[vid] = vk
		_start_pos[vid] = cell
	if loco_id == "":
		return _fail("lokomotif yok")
	# Bağlar
	var raw_l: Variant = data.get("links", [])
	if not (raw_l is Array):
		return _fail("links liste olmalı")
	var link_keys: Dictionary[String, bool] = {}
	var per_side: Dictionary[String, String] = {}
	var parent: Dictionary[String, String] = {}
	for pair_v: Variant in raw_l as Array:
		if not (pair_v is Array) or (pair_v as Array).size() != 2:
			return _fail("bağ iki kimlik olmalı")
		var pair: Array = pair_v
		var la: String = str(pair[0])
		var lb: String = str(pair[1])
		if not _vtype.has(la) or not _vtype.has(lb) or la == lb:
			return _fail("bağ geçersiz: %s-%s" % [la, lb])
		if not adjacent(_start_pos[la], _start_pos[lb]):
			return _fail("bağlı araçlar komşu değil: %s-%s" % [la, lb])
		var lk: String = link_key(la, lb)
		if link_keys.has(lk):
			return _fail("bağ yinelenmiş: %s" % lk)
		link_keys[lk] = true
		for dir: int in 2:
			var x1: String = la if dir == 0 else lb
			var y1: String = lb if dir == 0 else la
			var s1: int = side_of(_start_pos[x1], _start_pos[y1])
			var ps: String = "%s#%d" % [x1, s1]
			if per_side.has(ps):
				return _fail("araç %s: bir yanda iki bağ" % x1)
			per_side[ps] = y1
		var ra: String = _find(parent, la)
		var rb: String = _find(parent, lb)
		if ra == rb:
			return _fail("bağlar halka oluşturuyor")
		parent[ra] = rb
		_start_links.append(PackedStringArray([la, lb]))
	# Hedefler
	var raw_t: Variant = data.get("targets")
	if not (raw_t is Array) or (raw_t as Array).is_empty():
		return _fail("targets boş olamaz")
	var tcells: Dictionary[int, bool] = {}
	for tv: Variant in raw_t as Array:
		if not (tv is Dictionary):
			return _fail("hedef sözlük değil")
		var t: Dictionary = tv
		var tc: Variant = t.get("cell", -1)
		if not _is_int(tc):
			return _fail("hedef hücresi tamsayı değil")
		var c2: int = int(tc)
		var col: String = str(t.get("color", ""))
		if c2 < 0 or c2 >= n or tcells.has(c2):
			return _fail("hedef hücresi geçersiz/yinelenmiş: %d" % c2)
		if not COLORS.has(col) and col != "loco":
			return _fail("hedef rengi: %s" % col)
		tcells[c2] = true
		_targets.append({"cell": c2, "color": col})
	var raw_s: Variant = data.get("solution", [])
	if raw_s is Array:
		for a: Variant in raw_s as Array:
			if a is Dictionary:
				_solution.append(a as Dictionary)
	var raw_m: Variant = data.get("metrics", {})
	if raw_m is Dictionary:
		_metrics = raw_m as Dictionary
	return true


static func _find(parent: Dictionary[String, String], x: String) -> String:
	var cur: String = x
	while parent.has(cur) and parent[cur] != cur:
		cur = parent[cur]
	return cur


## İki aracın bağ anahtarı (sıralı, "a-b").
static func link_key(a: String, b: String) -> String:
	return "%s-%s" % [a, b] if a < b else "%s-%s" % [b, a]
