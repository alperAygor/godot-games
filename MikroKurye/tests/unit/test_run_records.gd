extends TestCase

## RunRecords: rekor takibi ve kayıt dayanıklılığı; ProfileData ile gidiş-dönüş.


func test_first_run_breaks_every_record() -> void:
	var records: RunRecords = RunRecords.new()
	var flags: Dictionary = records.submit(3, 140.7, 210)
	assert_true(bool(flags["new_level"]))
	assert_true(bool(flags["new_distance"]))
	assert_true(bool(flags["new_score"]))
	assert_eq(records.best_level(), 3)
	assert_eq(records.best_distance(), 140)
	assert_eq(records.best_score(), 210)
	assert_eq(records.runs(), 1)


func test_worse_run_keeps_records_and_counts_run() -> void:
	var records: RunRecords = RunRecords.new()
	records.submit(5, 300.0, 400)
	var flags: Dictionary = records.submit(2, 90.0, 120)
	assert_false(bool(flags["new_level"]))
	assert_false(bool(flags["new_distance"]))
	assert_false(bool(flags["new_score"]))
	assert_eq(records.best_level(), 5)
	assert_eq(records.runs(), 2)


func test_each_record_is_independent() -> void:
	var records: RunRecords = RunRecords.new()
	records.submit(5, 300.0, 400)
	var flags: Dictionary = records.submit(4, 350.0, 380)
	assert_false(bool(flags["new_level"]))
	assert_true(bool(flags["new_distance"]))
	assert_false(bool(flags["new_score"]))


func test_bad_input_is_clamped() -> void:
	var records: RunRecords = RunRecords.new()
	records.submit(-3, -10.0, -5)
	assert_eq(records.best_level(), 0)
	assert_eq(records.best_distance(), 0)
	assert_eq(records.best_score(), 0)
	records.submit(1, NAN, 0)
	assert_eq(records.best_distance(), 0)


func test_roundtrip_and_float_tolerance() -> void:
	var records: RunRecords = RunRecords.new()
	records.submit(7, 512.0, 900)
	var copy: RunRecords = RunRecords.from_dict(records.to_dict())
	assert_eq(copy.best_level(), 7)
	assert_eq(copy.best_distance(), 512)
	assert_eq(copy.best_score(), 900)
	# JSON'dan sayılar float gelir (GOTCHAS #20).
	var parsed: RunRecords = RunRecords.from_dict({"best_level": 4.0, "best_distance": 99.0, "best_score": 12.0, "runs": 3.0})
	assert_eq(parsed.best_level(), 4)
	assert_eq(parsed.runs(), 3)


func test_corrupt_values_become_zero() -> void:
	var parsed: RunRecords = RunRecords.from_dict({"best_level": "x", "best_distance": -4, "best_score": 1.5, "runs": null})
	assert_eq(parsed.best_level(), 0)
	assert_eq(parsed.best_distance(), 0)
	assert_eq(parsed.best_score(), 0)
	assert_eq(parsed.runs(), 0)


func test_profile_persists_records_and_old_saves_load() -> void:
	var profile: ProfileData = ProfileData.new()
	profile.records().submit(6, 400.0, 500)
	var loaded: ProfileData = ProfileData.from_dict(profile.to_dict())
	assert_eq(loaded.records().best_level(), 6)
	assert_eq(loaded.records().best_distance(), 400)
	# `records` anahtarı olmayan eski kayıt sıfır rekorla açılır.
	var legacy: ProfileData = ProfileData.from_dict({"wallet": {"gold": 10, "scrap": 1}})
	assert_eq(legacy.records().best_level(), 0)
	assert_eq(legacy.records().runs(), 0)
