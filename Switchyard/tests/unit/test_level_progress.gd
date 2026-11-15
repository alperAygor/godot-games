extends TestCase

## LevelProgress: yıldız eşikleri, en iyi hamle, çözüm/atlama kaydı, kilit, "devam" hedefi, bozuk kayıt.

const IDS: Array[String] = ["a", "b", "c", "d"]


func test_stars_thresholds_with_default_slack() -> void:
	# par 4: 3 yıldız <= 4, 2 yıldız <= ceil(6) = 6, ötesi 1.
	assert_eq(LevelProgress.stars_for(3, 4, 0), 3, "par'dan iyi")
	assert_eq(LevelProgress.stars_for(4, 4, 0), 3)
	assert_eq(LevelProgress.stars_for(5, 4, 0), 2)
	assert_eq(LevelProgress.stars_for(6, 4, 0), 2)
	assert_eq(LevelProgress.stars_for(7, 4, 0), 1)
	assert_eq(LevelProgress.stars_for(99, 4, 0), 1)


func test_two_star_limit_is_ceil_of_one_and_a_half_par() -> void:
	# par 3: ceil(4.5) = 5; par 5: ceil(7.5) = 8; par 1: ceil(1.5) = 2; par 2: 3.
	assert_eq(LevelProgress.stars_for(5, 3, 0), 2)
	assert_eq(LevelProgress.stars_for(6, 3, 0), 1)
	assert_eq(LevelProgress.stars_for(8, 5, 0), 2)
	assert_eq(LevelProgress.stars_for(9, 5, 0), 1)
	assert_eq(LevelProgress.stars_for(2, 1, 0), 2)
	assert_eq(LevelProgress.stars_for(3, 1, 0), 1)
	assert_eq(LevelProgress.stars_for(3, 2, 0), 2)
	assert_eq(LevelProgress.stars_for(4, 2, 0), 1)


func test_slack_widens_the_three_star_band() -> void:
	assert_eq(LevelProgress.stars_for(5, 4, 1), 3)
	assert_eq(LevelProgress.stars_for(6, 4, 1), 2)
	assert_eq(LevelProgress.stars_for(6, 4, 2), 3)
	assert_eq(LevelProgress.stars_for(5, 4, -3), 2, "negatif slack yok sayılır")


func test_broken_numbers_still_count_as_solved() -> void:
	assert_eq(LevelProgress.stars_for(0, 4, 0), 1)
	assert_eq(LevelProgress.stars_for(5, 0, 0), 1)


func test_solve_records_best_and_never_loses_stars() -> void:
	var progress: LevelProgress = LevelProgress.new()
	var first: Dictionary = progress.record_solve("a", 9, 4, 0)
	assert_eq(int(first["stars"]), 1)
	assert_true(bool(first["first_completion"]))
	assert_false(bool(first["new_best"]), "ilk çözüm 'yeni rekor' sayılmaz")
	var better: Dictionary = progress.record_solve("a", 5, 4, 0)
	assert_eq(int(better["stars"]), 2)
	assert_true(bool(better["new_best"]))
	assert_true(bool(better["better_stars"]))
	assert_false(bool(better["first_completion"]))
	var worse: Dictionary = progress.record_solve("a", 12, 4, 0)
	assert_false(bool(worse["new_best"]))
	assert_eq(progress.best_moves("a"), 5, "en iyi hamle kötüsüyle ezilmez")
	assert_eq(progress.stars("a"), 2, "kazanılan yıldız geri alınmaz")
	assert_true(progress.is_solved("a"))


func test_skip_marks_level_without_stars_and_unlocks_next() -> void:
	var progress: LevelProgress = LevelProgress.new()
	assert_true(progress.record_skip("a"))
	assert_true(progress.is_skipped("a"))
	assert_false(progress.is_solved("a"))
	assert_eq(progress.stars("a"), 0)
	assert_true(progress.is_completed("a"))
	assert_true(progress.is_unlocked(IDS, 1), "atlanan seviye sıradakini açar")
	assert_false(progress.record_skip("a"), "ikinci atlama değişiklik yapmaz")


func test_solving_a_skipped_level_later_is_not_a_first_completion() -> void:
	var progress: LevelProgress = LevelProgress.new()
	progress.record_skip("a")
	var info: Dictionary = progress.record_solve("a", 4, 4, 0)
	assert_false(bool(info["first_completion"]), "atlarken zaten sayıldı: reklam sırası ilerlemez")
	assert_true(progress.is_solved("a"))
	assert_false(progress.is_skipped("a"), "çözülünce atlandı işareti kalkar")
	assert_eq(progress.stars("a"), 3)


func test_cannot_skip_a_solved_level() -> void:
	var progress: LevelProgress = LevelProgress.new()
	progress.record_solve("a", 4, 4, 0)
	assert_false(progress.record_skip("a"))
	assert_true(progress.is_solved("a"))


func test_unlock_chain() -> void:
	var progress: LevelProgress = LevelProgress.new()
	assert_true(progress.is_unlocked(IDS, 0), "ilk seviye hep açık")
	assert_false(progress.is_unlocked(IDS, 1))
	progress.record_solve("a", 4, 4, 0)
	assert_true(progress.is_unlocked(IDS, 1))
	assert_false(progress.is_unlocked(IDS, 2), "bir atlama zinciri uzatmaz")
	progress.record_skip("b")
	assert_true(progress.is_unlocked(IDS, 2))
	assert_false(progress.is_unlocked(IDS, 3))
	assert_false(progress.is_unlocked(IDS, -1))
	assert_false(progress.is_unlocked(IDS, 4))


func test_frontier_is_first_incomplete_level() -> void:
	var progress: LevelProgress = LevelProgress.new()
	assert_eq(progress.frontier(IDS), 0)
	progress.record_solve("a", 4, 4, 0)
	assert_eq(progress.frontier(IDS), 1)
	progress.record_skip("b")
	assert_eq(progress.frontier(IDS), 2, "atlanan seviyeye otomatik dönülmez")
	progress.record_solve("c", 4, 4, 0)
	progress.record_solve("d", 4, 4, 0)
	assert_eq(progress.frontier(IDS), 3, "hepsi bitince sonuncu")
	assert_true(progress.all_completed(IDS))
	assert_eq(progress.frontier([] as Array[String]), 0)


func test_totals() -> void:
	var progress: LevelProgress = LevelProgress.new()
	progress.record_solve("a", 4, 4, 0)
	progress.record_solve("b", 6, 4, 0)
	progress.record_skip("c")
	assert_eq(progress.total_stars(IDS), 5)
	assert_eq(progress.solved_count(IDS), 2)


func test_section_round_trip_and_corrupt_entries() -> void:
	var progress: LevelProgress = LevelProgress.from_section({
		"a": {"best": 5, "stars": 2, "solved": true, "skipped": false},
		"b": {"best": 0, "stars": 0, "solved": false, "skipped": true},
		"c": {"best": "x", "stars": 9, "solved": true},
		"d": 7,
		"": {"best": 1, "solved": true},
	})
	assert_eq(progress.stars("a"), 2)
	assert_true(progress.is_skipped("b"))
	assert_false(progress.is_solved("c"), "bozuk 'best' ile çözüldü sayılmaz")
	assert_false(progress.is_completed("d"))
	assert_false(progress.is_completed(""))
	var clamped: LevelProgress = LevelProgress.from_section({"x": {"best": 3, "stars": 9, "solved": true}})
	assert_eq(clamped.stars("x"), 3, "yıldız 3'e kırpılır")


func test_save_and_load_through_progress_autoload() -> void:
	var node: Node = autoload_node("Progress")
	var old_persist: bool = bool(node.get("persist"))
	node.set("persist", false)
	node.call("reset_state")
	var progress: LevelProgress = LevelProgress.new()
	progress.record_solve("w1-001", 5, 4, 0)
	progress.save("w1-001")
	progress.record_skip("w1-002")
	progress.save("w1-002")
	var loaded: LevelProgress = LevelProgress.load_saved()
	assert_eq(loaded.stars("w1-001"), 2)
	assert_eq(loaded.best_moves("w1-001"), 5)
	assert_true(loaded.is_skipped("w1-002"))
	node.call("reset_state")
	node.set("persist", old_persist)


func test_ids_of_catalog_entries() -> void:
	var entries: Array[Dictionary] = [{"id": "x"}, {"id": "y"}]
	assert_eq(LevelProgress.ids_of(entries), ["x", "y"] as Array[String])
