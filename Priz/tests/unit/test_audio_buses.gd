extends TestCase

## Bus düzeni, başlık payı (limiter) ve duck yardımcısı.

func test_buses_exist_and_route_to_master() -> void:
	autoload_node("AudioService")
	for bus_name: StringName in [&"SFX", &"Loops", &"Ambience", &"Music"]:
		var idx: int = AudioServer.get_bus_index(bus_name)
		assert_true(idx >= 0, "bus var: %s" % bus_name)
		assert_eq(AudioServer.get_bus_send(idx), &"Master", "Master'a gider: %s" % bus_name)


func test_default_levels_leave_headroom() -> void:
	var loops: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Loops"))
	var sfx: float = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"SFX"))
	assert_true(loops < sfx, "döngüler efektlerin altında")
	assert_true(AudioServer.get_bus_volume_db(0) <= 0.0, "Master 0 dB üstüne çıkmaz")


func test_master_has_limiter_once() -> void:
	var count: int = 0
	for i: int in AudioServer.get_bus_effect_count(0):
		var effect: AudioEffect = AudioServer.get_bus_effect(0, i)
		if effect is AudioEffectHardLimiter or effect is AudioEffectLimiter:
			count += 1
	assert_eq(count, 1, "Master'da tek limiter")
	# Tekrar kurulum yinelenen bus ya da efekt üretmez.
	var buses_before: int = AudioServer.bus_count
	autoload_node("AudioService").call("_ensure_buses")
	assert_eq(AudioServer.bus_count, buses_before, "bus çoğalmadı")
	var again: int = 0
	for i: int in AudioServer.get_bus_effect_count(0):
		var effect: AudioEffect = AudioServer.get_bus_effect(0, i)
		if effect is AudioEffectHardLimiter or effect is AudioEffectLimiter:
			again += 1
	assert_eq(again, 1, "limiter çoğalmadı")


func test_duck_dips_loops_music_ambience_not_sfx() -> void:
	var audio: Node = autoload_node("AudioService")
	var sfx_idx: int = AudioServer.get_bus_index(&"SFX")
	var loops_idx: int = AudioServer.get_bus_index(&"Loops")
	var sfx_before: float = AudioServer.get_bus_volume_db(sfx_idx)
	var loops_before: float = AudioServer.get_bus_volume_db(loops_idx)
	audio.call("_apply_duck", -12.0)
	assert_almost_eq(AudioServer.get_bus_volume_db(loops_idx), loops_before - 12.0, 0.001, "Loops kısıldı")
	assert_almost_eq(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(&"Music")), -5.0 - 12.0, 0.001, "Music kısıldı")
	assert_almost_eq(AudioServer.get_bus_volume_db(sfx_idx), sfx_before, 0.001, "SFX kısılmadı")
	assert_almost_eq(float(audio.call("duck_offset_db")), -12.0, 0.001)
	audio.call("_apply_duck", 0.0)
	assert_almost_eq(AudioServer.get_bus_volume_db(loops_idx), loops_before, 0.001, "geri açıldı")


func test_duck_call_is_safe_and_repeatable() -> void:
	var audio: Node = autoload_node("AudioService")
	audio.call("duck", 0.5, -14.0)
	audio.call("duck", 0.5, 14.0)  # pozitif de kabul edilir (kısma yönü sabit)
	audio.call("duck", 0.0)
	assert_true(float(audio.call("duck_offset_db")) <= 0.0)
	audio.call("_apply_duck", 0.0)
