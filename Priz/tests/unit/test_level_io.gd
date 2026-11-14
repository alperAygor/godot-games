extends TestCase
## JSON gidiş-dönüşü kayıpsız olmalı.

const F: GDScript = preload("res://tests/data/priz_fixtures.gd")


func test_fixture_round_trip() -> void:
	var level: PrizLevel = F.level("day", ["day_cycle", "neighbour_line", "line_off"], ["living"],
		[F.line("L0", 4, {"neighbour": [0, 2, 1, 0], "off_slice": "night"})],
		[F.socket("s0", "L0", "living", 3, {"timer": 2, "grounded": true})],
		[F.device("d0", 5, "living", ["noon", "night"], {"needs_ground": true})])
	var text: String = level.to_json()
	var back: PrizLevel = PrizLevel.from_json(text)
	assert_not_null(back)
	assert_eq(back.to_json(), text)
	assert_eq(back.sockets[0].seats, 3)
	assert_eq(back.sockets[0].props["timer"], 2)
	assert_eq(typeof(back.sockets[0].props["timer"]), TYPE_INT, "sayılar tam sayı kalır")
	assert_eq(back.lines[0].props["neighbour"], [0, 2, 1, 0])
	assert_eq(back.devices[0].slices, 10)
	assert_eq(back.devices[0].blocks, 5)
	assert_eq(back.fuse_rights, 3)
	assert_eq(back.elements, ["day_cycle", "neighbour_line", "line_off"] as Array[String])


func test_copy_is_deep() -> void:
	var level: PrizLevel = F.flat_a()
	var other: PrizLevel = level.copy()
	other.lines[0].props["old_cable"] = 1
	other.sockets[0].seats = 4
	assert_false(level.lines[0].props.has("old_cable"))
	assert_eq(level.sockets[0].seats, 1)
	assert_eq(level.copy().to_json(), level.to_json())


func test_file_round_trip() -> void:
	var level: PrizLevel = F.day_b()
	var path: String = "user://priz_io_test.json"
	assert_true(level.save_file(path))
	var back: PrizLevel = PrizLevel.load_file(path)
	assert_not_null(back)
	assert_eq(back.to_json(), level.to_json())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_bad_json_returns_null() -> void:
	assert_eq(PrizLevel.from_json("{bozuk"), null)
	assert_eq(PrizLevel.from_json("[1, 2]"), null)
	assert_eq(PrizLevel.load_file("res://data/levels/yok.json"), null)


func test_every_shipped_file_round_trips_byte_identical() -> void:
	var files: PackedStringArray = PrizLevel.shipped_files()
	assert_true(files.size() > 0)
	for path: String in files:
		var text: String = FileAccess.get_file_as_string(path)
		var level: PrizLevel = PrizLevel.from_json(text)
		assert_not_null(level, path)
		if level != null:
			assert_true(level.to_json() == text, "bayt farkı: %s" % path)


func test_validate_catches_errors() -> void:
	var content: PrizContent = PrizContent.load_default()
	assert_true(F.flat_a().validate(content.registry).is_empty())
	var bad: PrizLevel = F.flat_a()
	bad.sockets[0].line = "LX"
	bad.devices[0].blocks = 9
	bad.elements.append("yok_boyle_oge")
	assert_eq(bad.validate(content.registry).size(), 3)
