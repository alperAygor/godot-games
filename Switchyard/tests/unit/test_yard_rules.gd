extends TestCase

## YardRules elle yazılmış durumlar: vektörlerin yanında kural metninin (DESIGN §2, YARD.md §2) okunur kanıtı.


## 0..n-1 düz hat (x=0), a yanı küçük kimliğe bakar.
func _line(n: int) -> Array:
	var cells: Array = []
	for i: int in n:
		cells.append({"x": 0, "y": i, "a": [i - 1] if i > 0 else [], "b": [i + 1] if i < n - 1 else []})
	return cells


func _level(cells: Array, vehicles: Array, links: Array = [], targets: Array = [{"cell": 0, "color": "red"}]) -> YardLevel:
	var lv: YardLevel = YardLevel.from_dict({"id": "t", "world": 1, "cells": cells, "vehicles": vehicles,
		"links": links, "targets": targets})
	assert_not_null(lv, "seviye geçerli olmalı")
	return lv


## Makas: 0(3,1)-1(3,2)-2(3,3); 2'nin b yanında 3 (3,4, düz) ve 4 (4,4, sapan); 5 (3,5), 6 (4,5).
func _switch_cells() -> Array:
	return [
		{"x": 3, "y": 1, "a": [], "b": [1]},
		{"x": 3, "y": 2, "a": [0], "b": [2]},
		{"x": 3, "y": 3, "a": [1], "b": [3, 4]},
		{"x": 3, "y": 4, "a": [2], "b": [5]},
		{"x": 4, "y": 4, "a": [2], "b": [6]},
		{"x": 3, "y": 5, "a": [3], "b": []},
		{"x": 4, "y": 5, "a": [4], "b": []},
	]


func test_push_couples_chain() -> void:
	var lv: YardLevel = _level(_line(5), [{"id": "L", "type": "loco", "cell": 0},
		{"id": "r1", "type": "wagon", "color": "red", "cell": 1},
		{"id": "b1", "type": "wagon", "color": "blue", "cell": 2}])
	var st: YardState = YardRules.initial_state(lv)
	var r: YardStep = YardRules.step(lv, st, YardRules.SIDE_B, 0)
	assert_true(r.moved)
	assert_eq(r.coupled, PackedStringArray(["r1", "b1"]))
	assert_eq(st.vehicle_cell("b1"), 3)
	assert_eq(st.train(), PackedStringArray(["L", "r1", "b1"]))


func test_couple_at_buffer_then_pull() -> void:
	var lv: YardLevel = _level(_line(4), [{"id": "L", "type": "loco", "cell": 1},
		{"id": "r1", "type": "wagon", "color": "red", "cell": 2},
		{"id": "b1", "type": "wagon", "color": "blue", "cell": 3}])
	var st: YardState = YardRules.initial_state(lv)
	var r: YardStep = YardRules.step(lv, st, YardRules.SIDE_B, 0)
	assert_false(r.moved)
	assert_eq(r.blocked, "buffer")
	assert_true(r.effective(), "bağlanma etkili adımdır")
	r = YardRules.step(lv, st, YardRules.SIDE_A, 0)
	assert_true(r.moved)
	assert_eq(st.vehicle_cell("b1"), 2)


func test_pull_leaves_unlinked_and_uncouple() -> void:
	var lv: YardLevel = _level(_line(5), [{"id": "L", "type": "loco", "cell": 2},
		{"id": "r1", "type": "wagon", "color": "red", "cell": 1}], [["L", "r1"]])
	var st: YardState = YardRules.initial_state(lv)
	assert_true(YardRules.uncouple(lv, st, "r1", "L"))
	assert_false(YardRules.uncouple(lv, st, "r1", "L"))
	YardRules.step(lv, st, YardRules.SIDE_B, 0)
	assert_eq(st.vehicle_cell("r1"), 1)
	assert_eq(st.vehicle_cell("L"), 3)


func test_branch_probe_and_coupling_stop() -> void:
	var lv: YardLevel = _level(_switch_cells(), [{"id": "L", "type": "loco", "cell": 1},
		{"id": "r1", "type": "wagon", "color": "red", "cell": 2}])
	var st: YardState = YardRules.initial_state(lv)
	var r: YardStep = YardRules.step(lv, st, YardRules.SIDE_B, 0)
	assert_false(r.moved)
	assert_eq(r.coupled, PackedStringArray(["r1"]))
	assert_eq(r.blocked, "", "bağlanma sonrası dal kararı adımı bitirir")
	var p: YardProbe = YardRules.probe(lv, st, YardRules.SIDE_B)
	assert_true(p.needs_branch)
	assert_eq(p.branch_cells, PackedInt32Array([3, 4]))
	r = YardRules.step(lv, st, YardRules.SIDE_B, 1)
	assert_true(r.moved)
	assert_eq(st.vehicle_cell("r1"), 4)


func test_foul_blocks() -> void:
	var lv: YardLevel = _level(_switch_cells(), [{"id": "L", "type": "loco", "cell": 5},
		{"id": "r1", "type": "wagon", "color": "red", "cell": 2},
		{"id": "b1", "type": "wagon", "color": "blue", "cell": 4}], [["r1", "b1"]])
	var st: YardState = YardRules.initial_state(lv)
	assert_true(YardRules.step(lv, st, YardRules.SIDE_A, 0).moved)
	var r: YardStep = YardRules.step(lv, st, YardRules.SIDE_A, 0)
	assert_eq(r.blocked, "foul")
	assert_false(r.effective())


func test_mechanics() -> void:
	var lv: YardLevel = _level(_line(6), [{"id": "L", "type": "loco", "cell": 0, "power": 1},
		{"id": "r1", "type": "wagon", "color": "red", "cell": 1},
		{"id": "b1", "type": "wagon", "color": "blue", "cell": 2}])
	var st: YardState = YardRules.initial_state(lv)
	assert_eq(YardRules.step(lv, st, YardRules.SIDE_B, 0).blocked, "traction")
	var cells: Array = _switch_cells()
	(cells[2] as Dictionary)["kind"] = "spring"
	(cells[2] as Dictionary)["spring"] = 1
	var lv3: YardLevel = _level(cells, [{"id": "L", "type": "loco", "cell": 1},
		{"id": "r1", "type": "wagon", "color": "red", "cell": 0}])
	var st3: YardState = YardRules.initial_state(lv3)
	YardRules.step(lv3, st3, YardRules.SIDE_B, 0)
	assert_false(YardRules.probe(lv3, st3, YardRules.SIDE_B).needs_branch)
	YardRules.step(lv3, st3, YardRules.SIDE_B, 0)
	assert_eq(st3.vehicle_cell("L"), 4, "yaylı makas hep aynı dala verir")
	var gc: Array = _line(5)
	(gc[3] as Dictionary)["kind"] = "gate"
	(gc[0] as Dictionary)["kind"] = "plate"
	var lv4: YardLevel = _level(gc, [{"id": "L", "type": "loco", "cell": 1},
		{"id": "r1", "type": "wagon", "color": "red", "cell": 4}], [], [{"cell": 4, "color": "red"}])
	var st4: YardState = YardRules.initial_state(lv4)
	YardRules.step(lv4, st4, YardRules.SIDE_B, 0)
	assert_eq(YardRules.step(lv4, st4, YardRules.SIDE_B, 0).blocked, "gate", "plaka boşken kapı kapalı")


func test_count_moves_rule() -> void:
	var lv: YardLevel = _level(_line(6), [{"id": "L", "type": "loco", "cell": 0},
		{"id": "r1", "type": "wagon", "color": "red", "cell": 2}], [], [{"cell": 5, "color": "red"}])
	var split: Array[Dictionary] = [{"t": "drive", "side": "b", "steps": 2}, {"t": "drive", "side": "b", "steps": 2}]
	assert_eq(YardRules.count_moves(lv, split), 1, "aynı yönde kesintisiz = 1 hamle")
	var cut: Array[Dictionary] = [{"t": "drive", "side": "b", "steps": 2},
		{"t": "uncouple", "between": ["L", "r1"]}, {"t": "drive", "side": "b", "steps": 2}]
	assert_eq(YardRules.count_moves(lv, cut), 2, "ayırma yeni hamle başlatır")
	var st: YardState = YardRules.initial_state(lv)
	assert_false(YardRules.apply_action(lv, st, {"t": "drive", "side": "b", "steps": 9}))
	assert_eq(st.vehicle_cell("L"), 0, "başarısız eylem durumu değiştirmez")


func test_validate_messages() -> void:
	var bad: Dictionary = {"id": "x", "cells": _line(3), "vehicles": [{"id": "L", "type": "loco", "cell": 0},
		{"id": "r1", "type": "wagon", "color": "red", "cell": 0}], "targets": [{"cell": 1, "color": "red"}]}
	assert_true(YardLevel.validate(bad) != "", "iki araç bir hücrede reddedilir")
	var cells: Array = _line(3)
	(cells[1] as Dictionary)["b"] = []
	var bad2: Dictionary = {"id": "x", "cells": cells, "vehicles": [{"id": "L", "type": "loco", "cell": 0}],
		"targets": [{"cell": 1, "color": "red"}]}
	assert_true(YardLevel.validate(bad2) != "", "asimetrik komşuluk reddedilir")
