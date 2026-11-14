extends "res://tests/session_case.gd"
## Performans ve bellek önlemleri: paylaşımlı veri önbelleği, ses önbelleği, ışık dokusu, Android yaşam döngüsü, kare süresi kelepçesi.


func test_shared_json_is_parsed_once_and_returns_the_same_data() -> void:
	var first := JsonIO.read_shared("res://data/ads.json")
	var second := JsonIO.read_shared("res://data/ads.json")
	assert_true(is_same(first, second), "aynı nesne (yeniden ayrıştırılmaz)")
	assert_true(first.has("rewarded"))
	assert_true(JsonIO.read_shared("res://data/nonexistent.json").is_empty())


func test_read_dict_still_returns_independent_copies() -> void:
	var a := JsonIO.read_dict("res://data/ads.json")
	a["rewarded"] = {}
	assert_false(JsonIO.read_dict("res://data/ads.json")["rewarded"].is_empty(), "read_dict her çağrıda yeni sözlük verir")


func test_ad_policy_reads_through_the_cache() -> void:
	assert_true(AdPolicy.rewarded_within_limit("double_pay", 0))
	assert_eq(AdPolicy.rewarded_config("overtime"), JsonIO.read_shared("res://data/ads.json")["rewarded"]["overtime"])


func test_sound_streams_are_cached_and_released_with_the_audio_manager() -> void:
	var audio := tree.root.get_node("AudioManager")
	var first: AudioStream = audio.sfx_stream("stamp")
	assert_true(first != null)
	assert_true(first == audio.sfx_stream("stamp"), "ikinci istek önbellekten gelir")
	assert_true(audio.sfx_stream("no_such_sound") == null)
	var low: AudioStream = audio.blip_stream(0.0)
	assert_true(low == audio.blip_stream(0.05), "aynı tizlik kademesi aynı akış")
	assert_true(low != audio.blip_stream(0.95), "farklı kademe farklı akış")
	audio.stop_all()
	assert_true(audio._sfx_cache.is_empty() and audio._blip_cache.is_empty(), "çıkışta önbellek boşalır")


func test_glow_texture_is_a_single_small_radial_gradient() -> void:
	var glow := Glow.texture(Color(1, 0.8, 0.4), 0.2)
	assert_eq(glow.fill, GradientTexture2D.FILL_RADIAL)
	assert_eq(glow.width, 128)
	assert_almost_eq(glow.gradient.get_color(0).a, 0.2, 0.001)
	assert_almost_eq(glow.gradient.get_color(2).a, 0.0, 0.001, "kenarda tam saydam")


func test_the_frame_rate_is_capped_for_battery() -> void:
	assert_eq(int(ProjectSettings.get_setting("application/run/max_fps")), 60, "90/120 Hz ekranlarda boşuna iki kat çizilmez")


func test_a_compatibility_renderer_is_used_for_this_2d_game() -> void:
	assert_eq(str(ProjectSettings.get_setting("rendering/renderer/rendering_method")), "gl_compatibility")
	assert_eq(str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile")), "gl_compatibility", "Android'de de aynı (mobile ezme kuralı yok)")


func test_backgrounding_the_app_pauses_the_shift() -> void:
	var career := Career.load_default("lifecycle")
	await scenes.goto(Scenes.DESK)
	var desk := tree.current_scene
	desk.set_process(false)
	desk.play(career)
	await tree.process_frame
	assert_true(node("PauseTitle") == null)
	desk.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	await tree.process_frame
	assert_true(node("ResumeButton") != null, "arka plana gidince duraklatma sayfası açılır")
	var clock_before: float = desk.shift.elapsed
	desk.tick(5.0)
	assert_eq(desk.shift.elapsed, clock_before, "duraklatılmışken saat işlemez")
	desk.notification(Node.NOTIFICATION_APPLICATION_PAUSED)  # tekrar gelen bildirim ikinci sayfa açmaz
	assert_eq(desk.find_children("ResumeButton", "Button", true, false).size(), 1)


func test_a_huge_frame_delta_is_clamped_in_real_frames() -> void:
	var script: Script = load("res://scripts/ui/desk_screen.gd")
	assert_eq(script.get_script_constant_map()["MAX_FRAME_DELTA"], 0.25)
