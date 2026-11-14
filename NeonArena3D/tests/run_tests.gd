extends SceneTree
## Tüm testleri çalıştırır: godot --headless --path . -s res://tests/run_tests.gd

func _initialize() -> void:
	var failed := 0
	var passed := 0
	var total_assertions := 0
	var dir := DirAccess.open("res://tests/unit")
	if dir == null:
		print("tests/unit açılamadı")
		quit(1)
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".gd") and not file.ends_with(".uid"):
			var path := "res://tests/unit/" + file
			var script: GDScript = load(path)
			var instance = script.new()
			print("\n▸ " + file)
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
		file = dir.get_next()
	dir.list_dir_end()
	print("\n%d test geçti, %d başarısız, %d doğrulama." % [passed, failed, total_assertions])
	quit(0 if failed == 0 else 1)
