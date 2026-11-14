extends "res://tests/test_case.gd"
## Örnek birim testi: saf mantık (scripts/core) sahne olmadan test edilir.

const TMP_PATH := "user://test_json_io.json"


func test_write_then_read_roundtrip() -> void:
	var original := {"coins": 42, "name": "oyuncu", "flags": [true, false]}
	assert_eq(JsonIO.write_dict(TMP_PATH, original), OK, "yazma başarılı olmalı")
	var loaded := JsonIO.read_dict(TMP_PATH)
	assert_eq(loaded.get("coins"), 42)
	assert_eq(loaded.get("name"), "oyuncu")


func test_missing_file_returns_fallback() -> void:
	var loaded := JsonIO.read_dict("user://bu_dosya_yok.json", {"default": true})
	assert_true(loaded.get("default", false))


func test_dotted_path_lookup() -> void:
	var data := {"player": {"stats": {"speed": 3.5}}}
	assert_almost_eq(JsonIO.get_path_value(data, "player.stats.speed"), 3.5)
	assert_eq(JsonIO.get_path_value(data, "player.yok", -1), -1)
