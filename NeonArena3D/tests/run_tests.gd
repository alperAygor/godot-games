extends SceneTree
## Tüm testleri çalıştırır: godot --headless --path . -s res://tests/run_tests.gd [-- --only=alt_dize]
## tests/unit/ ve tests/sim/ altındaki test_*.gd dosyaları taranır. Kayıt koruması: çalışma boyunca oyuncunun GERÇEK
## user:// kayıt dosyalarının değişmediği doğrulanır (önce/sonra değiştirilme zamanı + boyut + MD5 yazdırılır).

const SUITE_DIRS := ["res://tests/unit", "res://tests/sim"]
const PROTECTED := ["user://neon_arena_3d.cfg", "user://neon_arena_3d.cfg.bak", "user://neon_arena_3d.cfg.tmp", "user://neon_arena_3d.cfg.corrupt"]

func _snapshot() -> Dictionary:
	var out := {}
	for path in PROTECTED:
		if FileAccess.file_exists(path):
			out[path] = "mtime=%d size=%d md5=%s" % [FileAccess.get_modified_time(path), FileAccess.open(path, FileAccess.READ).get_length(), FileAccess.get_md5(path)]
		else:
			out[path] = "yok"
	return out

func _initialize() -> void:
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.get_slice("=", 1)
	var before := _snapshot()
	var failed := 0
	var passed := 0
	var total_assertions := 0
	var files: Array = []
	for dir_path in SUITE_DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			print("%s açılamadı" % dir_path)
			failed += 1
			continue
		dir.list_dir_begin()
		var file := dir.get_next()
		while file != "":
			if file.begins_with("test_") and file.ends_with(".gd"):
				files.append(dir_path + "/" + file)
			file = dir.get_next()
		dir.list_dir_end()
	files.sort()
	for path in files:
		if only != "" and only not in path:
			continue
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			print("\n▸ " + path)
			print("  ✗ YÜKLENEMEDİ (betik hatası)")
			failed += 1
			continue
		var instance = script.new()
		print("\n▸ " + path.get_file())
		for method in instance.get_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			instance.call(name)
			var fails: PackedStringArray = instance.failures
			if fails.is_empty():
				passed += 1
				print("  ✓ " + name)
			else:
				failed += 1
				print("  ✗ " + name)
				for f in fails:
					print("      " + f)
				instance.failures = PackedStringArray()
		total_assertions += instance.assertions
	var after := _snapshot()
	print("\n▸ kayıt koruması (gerçek user:// dosyaları)")
	var guard_ok := true
	for path in PROTECTED:
		var same: bool = before[path] == after[path]
		print("  %s %s\n      önce : %s\n      sonra: %s" % ["✓" if same else "✗", path, before[path], after[path]])
		if not same:
			guard_ok = false
	if not guard_ok:
		failed += 1
		print("  ✗ testler oyuncunun gerçek kayıt dosyasını DEĞİŞTİRDİ")
	print("\n%d test geçti, %d başarısız, %d doğrulama." % [passed, failed, total_assertions])
	quit(0 if failed == 0 else 1)
