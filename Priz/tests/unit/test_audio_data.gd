extends TestCase

## data/sounds.json: her kayıt var olan bir akışa gider; gereken ses kimlikleri tabloda.

const REQUIRED: Array[String] = [
	"plug_pickup", "plug_magnet", "plug_seat_1", "plug_seat_2", "plug_seat_3", "plug_unplug", "plug_reject",
	"socket_tick", "breaker_flip", "start_day", "fuse_blow", "power_down", "lamp_flicker", "slice_transition",
	"window_light", "ui_soft", "coin", "lose",
	"loop_fridge", "loop_oven", "loop_kettle", "loop_washer", "loop_tv", "loop_fan", "loop_toaster", "loop_lamp",
	"hum_mains", "ambience_morning", "ambience_noon", "ambience_evening", "ambience_night",
	"music_win", "music_plan",
]


func test_every_required_sound_is_registered_and_loadable() -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/sounds.json")) as Dictionary
	for sound_name: String in REQUIRED:
		assert_true(table.has(sound_name), "tabloda var: %s" % sound_name)
		if not table.has(sound_name):
			continue
		var path: String = String(table[sound_name])
		assert_true(ResourceLoader.exists(path), "dosya var: %s" % path)
		assert_not_null(load(path) as AudioStream, "akış yüklenir: %s" % sound_name)


func test_loops_are_longer_than_one_shots_and_in_range() -> void:
	for sound_name: String in ["loop_fridge", "loop_fan", "hum_mains"]:
		var stream: AudioStream = load("res://assets/audio/loops/%s.wav" % sound_name) as AudioStream
		assert_not_null(stream)
		assert_true(stream.get_length() >= 3.0 and stream.get_length() <= 7.0, "%s 3-7 sn" % sound_name)
	var click: AudioStream = load("res://assets/audio/sfx/plug_seat_1.wav") as AudioStream
	assert_true(click.get_length() < 1.0, "tık kısa")


func test_plug_seat_variants_are_all_registered_for_play_variant() -> void:
	var audio: Node = autoload_node("AudioService")
	for i: int in range(1, 4):
		assert_true(bool(audio.call("has_sound", "plug_seat_%d" % i)))
	audio.call("play_variant", "plug_seat", 3, 1.0, 0.0)  # çökmez
