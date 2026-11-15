extends TestCase

## Her yayın seviyesi oyunun KENDİ kurallarıyla yeniden oynatılır: kayıtlı çözüm tam `par` hamlede çözmeli
## (CLAUDE.md §0.8: çözülemeyen seviye yayına girmez). Ana ekran çözümü eylem eylem oynattığı için her eylem
## tek tek geçerli olmalı.


func _levels() -> Array[Dictionary]:
	LevelCatalog.reload()
	return LevelCatalog.entries()


func test_index_has_milestone_levels() -> void:
	var list: Array[Dictionary] = _levels()
	assert_eq(list.size(), 40, "kilometre taşı 1: 40 seviye")
	var ids: Dictionary[String, bool] = {}
	for e: Dictionary in list:
		assert_false(ids.has(str(e["id"])), "yinelenen kimlik")
		ids[str(e["id"])] = true
		var d: int = int(e["difficulty"])
		assert_true(d >= 1 and d <= 10, "zorluk 1-10: %s" % str(e["id"]))


func test_every_solution_replays_at_par() -> void:
	for e: Dictionary in _levels():
		var lid: String = str(e["id"])
		var data: Dictionary = LevelCatalog.load_level(lid)
		var lv: YardLevel = YardLevel.from_dict(data)
		assert_not_null(lv, "seviye geçerli: " + lid)
		if lv == null:
			continue
		assert_eq(lv.id, lid)
		assert_eq(lv.par, int(e["par"]), "dizin parı = dosya parı: " + lid)
		var st: YardState = YardRules.initial_state(lv)
		assert_false(YardRules.is_solved(lv, st), "başta çözülmüş olmamalı: " + lid)
		var sol: Array[Dictionary] = lv.solution()
		var drives: int = 0
		var ok: bool = true
		for i: int in sol.size():
			if str(sol[i].get("t", "")) == "drive":
				drives += 1
			if not YardRules.apply_action(lv, st, sol[i]):
				fail("%s: eylem %d uygulanamadı" % [lid, i])
				ok = false
				break
		if not ok:
			continue
		assert_true(YardRules.is_solved(lv, st), "çözüm çözmeli: " + lid)
		assert_eq(YardRules.count_moves(lv, sol), lv.par, "hamle sayısı = par: " + lid)
		assert_eq(drives, lv.par, "her sürüş ayrı hamle (birleşebilen sürüş yok): " + lid)
