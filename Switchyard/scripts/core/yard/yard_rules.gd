class_name YardRules
extends RefCounted
## Oyunun kuralları (saf, durumsuz). Python aynası: tools/yard/rules.py; ikisi uygunluk vektörleriyle
## (tests/data/yard_vectors.json) birebir eşit tutulur. Kural metni docs/DESIGN.md §2, belirsizlikler docs/YARD.md §2.

const SIDE_A: int = 0
const SIDE_B: int = 1

const BLOCK_BUFFER: String = "buffer"
const BLOCK_SELF: String = "self"
const BLOCK_FOUL: String = "foul"
const BLOCK_GATE: String = "gate"
const BLOCK_TRACTION: String = "traction"


static func initial_state(level: YardLevel) -> YardState:
	var positions: Dictionary[String, int] = {}
	for vid: String in level.vehicle_ids():
		positions[vid] = level.start_cell(vid)
	return YardState.create(level, positions, level.start_links())


## vid'in hücresinin `side` yanında bağlı olduğu araç ("" = yok).
static func linked_neighbor(level: YardLevel, state: YardState, vid: String, side: int) -> String:
	var c: int = state.vehicle_cell(vid)
	for q: int in level.neighbors(c, side):
		var u: String = state.vehicle_at(q)
		if u != "" and state.is_linked(vid, u):
			return u
	return ""


## vid'den `side` yönünde bağlar boyunca uzaklaşan araçlar (vid hariç).
static func walk(level: YardLevel, state: YardState, vid: String, side: int) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var cur: String = vid
	var s: int = side
	while true:
		var nxt: String = linked_neighbor(level, state, cur, s)
		if nxt == "":
			break
		out.append(nxt)
		s = 1 - level.side_of(state.vehicle_cell(nxt), state.vehicle_cell(cur))
		cur = nxt
	return out


static func gates_open(level: YardLevel, state: YardState) -> bool:
	if not level.has_gate():
		return true
	for c: int in level.cell_count():
		if level.cell_kind(c) == "plate" and state.vehicle_at(c) != "":
			return true
	return false


## Bir hücre sürüş; durumu yerinde değiştirir. `branch`: baş dallanan yana bakıyorsa dal numarası.
## Engellenen adımda o ana kadarki bağlanmalar kalır. Bir adımda tek dal kararı: bağlanma sonrası yeni baş
## (yaysız) makasın dal yanına bakıyorsa adım bağlanmayla biter.
static func step(level: YardLevel, state: YardState, side: int, branch: int) -> YardStep:
	var res: YardStep = YardStep.new()
	if side != SIDE_A and side != SIDE_B:
		res.blocked = BLOCK_BUFFER
		return res
	var open_gates: bool = gates_open(level, state)
	var loco: String = level.loco_id
	var ahead: PackedStringArray = walk(level, state, loco, side)
	var head: String = loco
	var free: int = side
	if not ahead.is_empty():
		head = ahead[ahead.size() - 1]
		var prev0: String = ahead[ahead.size() - 2] if ahead.size() > 1 else loco
		free = 1 - level.side_of(state.vehicle_cell(head), state.vehicle_cell(prev0))
	var in_train: Dictionary[String, bool] = {}
	for vid: String in state.train():
		in_train[vid] = true
	var first: bool = true
	var t: int = -1
	while true:
		var hc: int = state.vehicle_cell(head)
		var nb: PackedInt32Array = level.neighbors(hc, free)
		if nb.is_empty():
			res.blocked = BLOCK_BUFFER
			return res
		if nb.size() == 2:
			if level.cell_kind(hc) == "spring":
				t = nb[level.spring_branch(hc)]
			elif not first:
				return res
			else:
				t = nb[branch] if (branch == 0 or branch == 1) else nb[0]
		else:
			t = nb[0]
		first = false
		var v: String = state.vehicle_at(t)
		if v == "":
			break
		if in_train.has(v):
			res.blocked = BLOCK_SELF
			return res
		var s_v: int = level.side_of(t, hc)
		if linked_neighbor(level, state, v, s_v) != "":
			res.blocked = BLOCK_FOUL
			return res
		var chain: PackedStringArray = PackedStringArray([v])
		chain.append_array(walk(level, state, v, 1 - s_v))
		state.add_link(head, v)
		for u: String in chain:
			in_train[u] = true
			res.coupled.append(u)
		var prev: String = chain[chain.size() - 2] if chain.size() > 1 else head
		head = chain[chain.size() - 1]
		free = 1 - level.side_of(state.vehicle_cell(head), state.vehicle_cell(prev))
	if level.cell_kind(t) == "gate" and not open_gates:
		res.blocked = BLOCK_GATE
		return res
	var tr: PackedStringArray = state.train()
	# order: kuyruk ... baş (sürüş yönünde)
	var order: PackedStringArray = PackedStringArray()
	if side == SIDE_A:
		for i: int in range(tr.size() - 1, -1, -1):
			order.append(tr[i])
	else:
		order = tr
	if level.power > 0 and order.size() - 1 > level.power:
		res.blocked = BLOCK_TRACTION
		return res
	var new_cells: Dictionary[String, int] = {}
	for i: int in order.size():
		var old_c: int = state.vehicle_cell(order[i])
		var new_c: int = t if i == order.size() - 1 else state.vehicle_cell(order[i + 1])
		new_cells[order[i]] = new_c
		res.moves[order[i]] = PackedInt32Array([old_c, new_c])
	state.relocate(new_cells)
	res.moved = true
	return res


static func probe(level: YardLevel, state: YardState, side: int) -> YardProbe:
	var p: YardProbe = YardProbe.new()
	if side != SIDE_A and side != SIDE_B:
		return p
	var loco: String = level.loco_id
	var ahead: PackedStringArray = walk(level, state, loco, side)
	var head: String = loco
	var free: int = side
	if not ahead.is_empty():
		head = ahead[ahead.size() - 1]
		var prev: String = ahead[ahead.size() - 2] if ahead.size() > 1 else loco
		free = 1 - level.side_of(state.vehicle_cell(head), state.vehicle_cell(prev))
	var hc: int = state.vehicle_cell(head)
	var nb: PackedInt32Array = level.neighbors(hc, free)
	if nb.size() == 2 and level.cell_kind(hc) != "spring":
		p.needs_branch = true
		p.branch_cells = nb.duplicate()
		for br: int in 2:
			if step(level, state.duplicate_state(), side, br).effective():
				p.possible = true
	else:
		p.possible = step(level, state.duplicate_state(), side, 0).effective()
	return p


static func uncouple(_level: YardLevel, state: YardState, id_a: String, id_b: String) -> bool:
	return state.remove_link(id_a, id_b)


static func is_solved(level: YardLevel, state: YardState) -> bool:
	for t: Dictionary in level.targets():
		var v: String = state.vehicle_at(int(t["cell"]))
		if v == "":
			return false
		var col: String = str(t["color"])
		if col == "loco":
			if level.vehicle_type(v) != "loco":
				return false
		elif level.vehicle_type(v) != "wagon" or level.vehicle_color(v) != col:
			return false
	return true


## Lokomotif old_cell'den new_cell'e geçtiyse aynı yönü sürdüren yan; geçmediyse `side`.
static func continue_side(level: YardLevel, old_cell: int, new_cell: int, side: int) -> int:
	if old_cell == new_cell:
		return side
	return 1 - level.side_of(new_cell, old_cell)


static func side_from_name(name: String) -> int:
	if name == "a":
		return SIDE_A
	if name == "b":
		return SIDE_B
	return -1


## Çözüm eylemini atomik uygular: başarısızsa durum değişmez.
static func apply_action(level: YardLevel, state: YardState, action: Dictionary) -> bool:
	var work: YardState = state.duplicate_state()
	var kind: String = str(action.get("t", ""))
	if kind == "uncouple":
		var between: Variant = action.get("between", [])
		if not (between is Array) or (between as Array).size() != 2:
			return false
		var arr: Array = between
		if not uncouple(level, work, str(arr[0]), str(arr[1])):
			return false
	elif kind == "drive":
		var side: int = side_from_name(str(action.get("side", "")))
		if side < 0:
			return false
		var steps: int = int(action.get("steps", 0))
		if steps < 1:
			return false
		var branches: Array = action.get("branches", []) if action.get("branches", []) is Array else []
		var bi: int = 0
		for _i: int in steps:
			var pr: YardProbe = probe(level, work, side)
			var br: int = 0
			if pr.needs_branch:
				br = int(branches[bi]) if bi < branches.size() else 0
				bi += 1
			var old: int = work.vehicle_cell(level.loco_id)
			var r: YardStep = step(level, work, side, br)
			if not r.effective():
				return false
			side = continue_side(level, old, work.vehicle_cell(level.loco_id), side)
	else:
		return false
	state.assign_from(work)
	return true


## Sürüşün bitişinde aynı yönü sürdüren lokomotif yanı (hamle sayımı). Durumu değiştirmez.
static func drive_end_side(level: YardLevel, state: YardState, action: Dictionary) -> int:
	var work: YardState = state.duplicate_state()
	var side: int = side_from_name(str(action.get("side", "")))
	var branches: Array = action.get("branches", []) if action.get("branches", []) is Array else []
	var bi: int = 0
	for _i: int in int(action.get("steps", 0)):
		var pr: YardProbe = probe(level, work, side)
		var br: int = 0
		if pr.needs_branch:
			br = int(branches[bi]) if bi < branches.size() else 0
			bi += 1
		var old: int = work.vehicle_cell(level.loco_id)
		step(level, work, side, br)
		side = continue_side(level, old, work.vehicle_cell(level.loco_id), side)
	return side


## Sayım kuralı (DESIGN §2): aynı yönde kesintisiz sürüş tek hamle; yön değişimi ya da ayırma yeni hamle.
## Geçersiz eylemde -1.
static func count_moves(level: YardLevel, actions: Array[Dictionary]) -> int:
	var st: YardState = initial_state(level)
	var moves: int = 0
	var cont: int = -1
	for a: Dictionary in actions:
		if str(a.get("t", "")) == "drive":
			var side: int = side_from_name(str(a.get("side", "")))
			if cont < 0 or side != cont:
				moves += 1
			cont = drive_end_side(level, st, a)
			if not apply_action(level, st, a):
				return -1
		else:
			if not apply_action(level, st, a):
				return -1
			cont = -1
	return moves
