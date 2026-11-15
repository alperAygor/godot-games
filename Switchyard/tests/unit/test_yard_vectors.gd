extends TestCase

## Uygunluk vektörleri: Python kural aynasının (tools/yard/rules.py) ürettiği her durum+eylem sonucu oyunun
## GDScript kurallarıyla birebir aynı çıkmalı. Ayrışma çözücünün bulduğu par'ı oyunda geçersiz kılar.

const VECTORS_PATH: String = "res://tests/data/yard_vectors.json"


func _load() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(VECTORS_PATH))
	assert_true(parsed is Dictionary, "vektör dosyası okunmalı")
	return parsed as Dictionary if parsed is Dictionary else {}


func _level_of(data: Dictionary, case_level: Dictionary) -> Dictionary:
	var d: Dictionary = case_level.duplicate(true)
	var lists: Array = data["cell_lists"]
	d["cells"] = lists[int(d["cells_ref"])]
	return d


func _ints(arr: Variant) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	for v: Variant in arr as Array:
		out.append(int(v))
	return out


func _strs(arr: Variant) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for v: Variant in arr as Array:
		out.append(str(v))
	return out


## Beklenen durum ile gerçek durum aynı mı; ilk farkı metin olarak döner ("" = aynı).
func _diff_state(level: YardLevel, st: YardState, exp: Dictionary) -> String:
	var pos: Dictionary = exp["pos"]
	for vid: Variant in pos.keys():
		if st.vehicle_cell(str(vid)) != int(pos[vid]):
			return "konum %s: %d != %d" % [str(vid), st.vehicle_cell(str(vid)), int(pos[vid])]
	var exp_links: Array = exp["links"]
	var got: Array[PackedStringArray] = st.links()
	if got.size() != exp_links.size():
		return "bağ sayısı %d != %d" % [got.size(), exp_links.size()]
	for i: int in got.size():
		var e: PackedStringArray = _strs(exp_links[i])
		if got[i] != e:
			return "bağ %s != %s" % [str(got[i]), str(e)]
	if st.train() != _strs(exp["train"]):
		return "katar %s != %s" % [str(st.train()), str(exp["train"])]
	if YardRules.is_solved(level, st) != bool(exp["solved"]):
		return "çözüldü farklı"
	if st.key() != str(exp["key"]):
		return "anahtar %s != %s" % [st.key(), str(exp["key"])]
	return ""


func test_all_vectors_match_python() -> void:
	var data: Dictionary = _load()
	var cases: Array = data.get("cases", [])
	assert_true(cases.size() >= 2000, "binlerce vektör olmalı")
	var failures: int = 0
	var counts: Dictionary[String, int] = {}
	for ci: int in cases.size():
		var c: Dictionary = cases[ci]
		var lv: YardLevel = YardLevel.from_dict(_level_of(data, c["level"]))
		if lv == null:
			fail("vektör %d: seviye kurulamadı" % ci)
			failures += 1
			continue
		var st: YardState = YardRules.initial_state(lv)
		var op: String = str(c["op"])
		counts[op] = counts.get(op, 0) + 1
		var problem: String = ""
		if op == "step":
			var r: YardStep = YardRules.step(lv, st, int(c["side"]), int(c["branch"]))
			var exp: Dictionary = c["result"]
			if r.moved != bool(exp["moved"]):
				problem = "moved"
			elif r.coupled != _strs(exp["coupled"]):
				problem = "coupled %s != %s" % [str(r.coupled), str(exp["coupled"])]
			elif r.blocked != str(exp["blocked"]):
				problem = "blocked %s != %s" % [r.blocked, str(exp["blocked"])]
			else:
				var em: Dictionary = exp["moves"]
				if em.size() != r.moves.size():
					problem = "moves boyutu"
				for vid: Variant in em.keys():
					if not r.moves.has(str(vid)) or (r.moves[str(vid)] as PackedInt32Array) != _ints(em[vid]):
						problem = "moves %s" % str(vid)
			if problem == "":
				problem = _diff_state(lv, st, c["after"])
		elif op == "probe":
			var p: YardProbe = YardRules.probe(lv, st, int(c["side"]))
			var expp: Dictionary = c["result"]
			if p.possible != bool(expp["possible"]) or p.needs_branch != bool(expp["needs_branch"]) \
					or p.branch_cells != _ints(expp["branch_cells"]):
				problem = "probe %s/%s/%s" % [str(p.possible), str(p.needs_branch), str(p.branch_cells)]
		elif op == "uncouple":
			var between: PackedStringArray = _strs(c["between"])
			var ok: bool = YardRules.uncouple(lv, st, between[0], between[1])
			if ok != bool(c["result"]):
				problem = "uncouple sonucu"
			else:
				problem = _diff_state(lv, st, c["after"])
		elif op == "action":
			var ok2: bool = YardRules.apply_action(lv, st, c["action"] as Dictionary)
			if ok2 != bool(c["result"]):
				problem = "action sonucu %s" % str(ok2)
			else:
				problem = _diff_state(lv, st, c["after"])
		else:
			problem = "bilinmeyen op " + op
		if problem != "":
			failures += 1
			if failures <= 10:
				fail("vektör %d (%s): %s" % [ci, op, problem])
	assert_eq(failures, 0, "ayrışan vektör sayısı")
	assert_true(counts.get("step", 0) > 1000, "adım vektörleri")
	assert_true(counts.get("probe", 0) > 100, "yoklama vektörleri")


func test_invalid_levels_rejected_like_python() -> void:
	var data: Dictionary = _load()
	var inv: Array = data.get("invalid", [])
	assert_true(inv.size() >= 15)
	for item: Variant in inv:
		var d: Dictionary = item
		var err: String = YardLevel.validate(d["level"] as Dictionary)
		assert_eq(err == "", bool(d["valid"]), "doğrulama %s (%s)" % [str(d["name"]), err])
