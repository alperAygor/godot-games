extends SceneTree
## Headless test çalıştırıcı.
##
## Kullanım (proje kökünden):
##   godot --headless --path . -s res://tests/run_tests.gd
##   godot --headless --path . -s res://tests/run_tests.gd -- --filter=save
##
## tests/unit/ içindeki test_*.gd dosyalarını bulur, "test_" ile başlayan metotları çalıştırır.
## Çıkış kodu: 0 = hepsi geçti, 1 = en az bir test başarısız, 2 = test bulunamadı / yüklenemedi.

const TEST_DIR := "res://tests/unit"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Autoload'ların _ready() çağrılarının bitmesi için bir kare bekle.
	await process_frame

	var filter := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.trim_prefix("--filter=")

	var files := Array(DirAccess.get_files_at(TEST_DIR)).filter(
		func(f: String) -> bool: return f.begins_with("test_") and f.ends_with(".gd"))
	files.sort()

	var passed := 0
	var failed := 0
	var load_errors := 0
	var started := Time.get_ticks_msec()

	for file_name: String in files:
		var path := TEST_DIR.path_join(file_name)
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			printerr("YÜKLENEMEDİ  %s (parse hatası?)" % path)
			load_errors += 1
			continue

		for method in script.get_script_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			var full_name := "%s::%s" % [file_name.get_basename(), method_name]
			if not filter.is_empty() and not full_name.contains(filter):
				continue

			var test: RefCounted = script.new()
			test.tree = self
			await test.before_each()
			await test.call(method_name)
			await test.after_each()

			if test._failures.is_empty():
				passed += 1
				print("  GEÇTİ  %s" % full_name)
			else:
				failed += 1
				printerr("  KALDI  %s" % full_name)
				for failure in test._failures:
					printerr("         - %s" % failure)

	var elapsed := (Time.get_ticks_msec() - started) / 1000.0
	print("\nSonuç: %d geçti, %d kaldı, %d yüklenemedi (%.2f sn)" % [passed, failed, load_errors, elapsed])

	# Testlerde çalan sesler kapanışta "kaynak hâlâ kullanımda" uyarısı vermesin.
	var audio := root.get_node_or_null("AudioManager")
	if audio and audio.has_method("stop_all"):
		audio.stop_all()
		await process_frame
		await process_frame

	if load_errors > 0 or passed + failed == 0:
		quit(2)
	elif failed > 0:
		quit(1)
	else:
		quit(0)
