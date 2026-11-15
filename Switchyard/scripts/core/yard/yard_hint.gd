class_name YardHint
extends RefCounted
## İpucu: sıradaki doğru eylem (docs/CORE_API.md §2).
## 1) Oyuncu kayıtlı çözüm yolundaysa (sürüşün ortasında bile) çözümün kalanından sıradaki eylem.
## 2) Değilse süre/düğüm sınırlı genişlik araması: çözüme ya da çözüm yoluna giden ilk eylem.
## 3) O da bulamazsa { "t": "rewind", "to": n }: geçmişte çözüm yolunda olunan son an (n eylem tut).
## "Yolda mı" karşılaştırması renk-kanonik ve duran bağlardan bağımsızdır (YardState.canonical_key),
## çünkü aynı renkli vagonlar ve duran dizilerin bağları çözümü değiştirmez (docs/YARD.md §3).
## Geçmiş (history): oyuncunun uyguladığı eylemler, çözüm biçiminde (her sürükleme 1 adımlık drive olabilir).
## Dönüş: eylem sözlüğü; seviye zaten çözülmüşse boş sözlük.

const SEARCH_MS: int = 150
const SEARCH_NODES: int = 30000


static func next_action(level: YardLevel, state: YardState, history: Array[Dictionary]) -> Dictionary:
	if YardRules.is_solved(level, state):
		return {}
	var path: Dictionary = _solution_path(level)
	var on: Dictionary = _from_path(level, state, path)
	if not on.is_empty():
		return on
	var found: Dictionary = _search(level, state, path)
	if not found.is_empty():
		return found
	return {"t": "rewind", "to": _last_on_path(level, history, path)}


## Çözüm yolundaki her etkili adım sonrası kanonik anahtar -> {k, done, br, side}.
## k: sıradaki çözüm eylemi; done: o sürüşte yapılmış adım; br: tüketilen dal kararı; side: devam yanı.
static func _solution_path(level: YardLevel) -> Dictionary:
	var out: Dictionary = {}
	var sol: Array[Dictionary] = level.solution()
	var st: YardState = YardRules.initial_state(level)
	out[st.canonical_key()] = {"k": 0, "done": 0, "br": 0, "side": -1}
	for k: int in sol.size():
		var a: Dictionary = sol[k]
		if str(a.get("t", "")) == "uncouple":
			if not YardRules.apply_action(level, st, a):
				return out
			var key: String = st.canonical_key()
			if not out.has(key):
				out[key] = {"k": k + 1, "done": 0, "br": 0, "side": -1}
			continue
		var side: int = YardRules.side_from_name(str(a.get("side", "")))
		var branches: Array = a.get("branches", []) if a.get("branches", []) is Array else []
		var bi: int = 0
		var steps: int = int(a.get("steps", 0))
		for s: int in steps:
			var pr: YardProbe = YardRules.probe(level, st, side)
			var br: int = 0
			if pr.needs_branch:
				br = int(branches[bi]) if bi < branches.size() else 0
				bi += 1
			var old: int = st.vehicle_cell(level.loco_id)
			if not YardRules.step(level, st, side, br).effective():
				return out
			side = YardRules.continue_side(level, old, st.vehicle_cell(level.loco_id), side)
			var key2: String = st.canonical_key()
			if not out.has(key2):
				if s == steps - 1:
					out[key2] = {"k": k + 1, "done": 0, "br": 0, "side": -1}
				else:
					out[key2] = {"k": k, "done": s + 1, "br": bi, "side": side}
	return out


static func _from_path(level: YardLevel, state: YardState, path: Dictionary) -> Dictionary:
	var key: String = state.canonical_key()
	if not path.has(key):
		return {}
	var info: Dictionary = path[key]
	var sol: Array[Dictionary] = level.solution()
	var k: int = int(info["k"])
	if k >= sol.size():
		return {}
	var action: Dictionary = sol[k].duplicate(true)
	if int(info["done"]) > 0:
		var branches: Array = action.get("branches", []) if action.get("branches", []) is Array else []
		action = {"t": "drive", "side": "a" if int(info["side"]) == YardRules.SIDE_A else "b",
			"steps": int(action["steps"]) - int(info["done"]), "branches": branches.slice(int(info["br"]))}
	# Duran bağlar farklıysa kalan çözüm tutmayabilir: doğrula.
	var rest: Array[Dictionary] = [action]
	for i: int in range(k + 1, sol.size()):
		rest.append(sol[i])
	var work: YardState = state.duplicate_state()
	for a: Dictionary in rest:
		if not YardRules.apply_action(level, work, a):
			return {}
	if not YardRules.is_solved(level, work):
		return {}
	return action


## Genişlik araması (tek adım + katar içi ayırma). Hedef: çözülmüş ya da çözüm yolunda bir durum.
static func _search(level: YardLevel, state: YardState, path: Dictionary) -> Dictionary:
	var t0: int = Time.get_ticks_msec()
	var start_key: String = state.canonical_key()
	var parent: Dictionary = {start_key: null}
	var queue: Array[YardState] = [state.duplicate_state()]
	var head: int = 0
	while head < queue.size():
		if head >= SEARCH_NODES or Time.get_ticks_msec() - t0 > SEARCH_MS:
			break
		var cur: YardState = queue[head]
		head += 1
		var cur_key: String = cur.canonical_key()
		for action: Dictionary in _expand(level, cur):
			var nxt: YardState = cur.duplicate_state()
			if not YardRules.apply_action(level, nxt, action):
				continue
			var nk: String = nxt.canonical_key()
			if parent.has(nk):
				continue
			parent[nk] = [cur_key, action]
			var goal: bool = YardRules.is_solved(level, nxt)
			if not goal and path.has(nk):
				goal = not _from_path(level, nxt, path).is_empty()
			if goal:
				return _first_action(level, state, parent, nk)
			queue.append(nxt)
	return {}


static func _expand(level: YardLevel, st: YardState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for side: int in 2:
		var name: String = "a" if side == YardRules.SIDE_A else "b"
		var pr: YardProbe = YardRules.probe(level, st, side)
		if not pr.possible:
			continue
		if pr.needs_branch:
			for br: int in 2:
				out.append({"t": "drive", "side": name, "steps": 1, "branches": [br]})
		else:
			out.append({"t": "drive", "side": name, "steps": 1, "branches": []})
	var tr: PackedStringArray = st.train()
	for i: int in tr.size() - 1:
		out.append({"t": "uncouple", "between": [tr[i], tr[i + 1]]})
	return out


## Yolu geri izler; baştaki aynı yönlü adımları tek sürüşte birleştirir.
static func _first_action(level: YardLevel, state: YardState, parent: Dictionary, goal_key: String) -> Dictionary:
	var actions: Array[Dictionary] = []
	var key: String = goal_key
	while parent[key] != null:
		var entry: Array = parent[key]
		actions.push_front(entry[1] as Dictionary)
		key = str(entry[0])
	var first: Dictionary = actions[0].duplicate(true)
	if str(first["t"]) != "drive":
		return first
	var work: YardState = state.duplicate_state()
	var cont: int = YardRules.drive_end_side(level, work, first)
	YardRules.apply_action(level, work, first)
	for i: int in range(1, actions.size()):
		var a: Dictionary = actions[i]
		if str(a["t"]) != "drive" or YardRules.side_from_name(str(a["side"])) != cont:
			break
		first["steps"] = int(first["steps"]) + 1
		(first["branches"] as Array).append_array(a["branches"] as Array)
		cont = YardRules.drive_end_side(level, work, a)
		YardRules.apply_action(level, work, a)
	return first


static func _last_on_path(level: YardLevel, history: Array[Dictionary], path: Dictionary) -> int:
	var st: YardState = YardRules.initial_state(level)
	var last: int = 0
	for i: int in history.size():
		if not YardRules.apply_action(level, st, history[i]):
			break
		if path.has(st.canonical_key()) and not _from_path(level, st, path).is_empty():
			last = i + 1
	return last
