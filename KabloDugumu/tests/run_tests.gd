extends SceneTree

## Test koşucusu. Çıkış kodu: 0 hepsi geçti, 1 başarısız, 2 test bulunamadı.
##   godot --headless --path . -s res://tests/run_tests.gd
##   godot --headless --path . -s res://tests/run_tests.gd -- --filter=glass
##
## İş `_process` içinde yapılır: bir test beklenmedik şekilde hata verirse
## `_initialize` askıda kalmasın, süreç her hâlükârda çıksın.

const TESTS_DIR: String = "res://tests/unit"

var _started: bool = false
var _exit_code: int = 1


func _initialize() -> void:
	pass


func _process(_delta: float) -> bool:
	if _started:
		return true
	_started = true
	_run_all()
	quit(_exit_code)
	return true


func _run_all() -> void:
	var filter: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			filter = arg.split("=")[1]

	var files: PackedStringArray = _collect_files()
	if files.is_empty():
		print("TEST BULUNAMADI (%s)" % TESTS_DIR)
		_exit_code = 2
		return

	var test_count: int = 0
	var failed_count: int = 0
	var assert_count: int = 0
	var load_errors: int = 0

	for path: String in files:
		var script: GDScript = load(path) as GDScript
		if script == null or not script.can_instantiate():
			print("YÜKLENEMEDİ  %s" % path)
			load_errors += 1
			continue
		var test_object: Object = script.new()
		if test_object == null:
			print("ÖRNEKLENEMEDİ %s" % path)
			load_errors += 1
			continue
		test_object.set("tree", self)
		for method_name: String in _test_methods(test_object):
			if filter != "" and not method_name.contains(filter):
				continue
			test_object.call("reset_state")
			test_object.call("before_each")
			test_object.call(method_name)
			test_object.call("after_each")
			test_count += 1
			assert_count += int(test_object.call("assertion_count"))
			var fails: Array = test_object.call("failures")
			if fails.is_empty():
				print("PASS  %s::%s" % [path.get_file().get_basename(), method_name])
			else:
				failed_count += 1
				print("FAIL  %s::%s" % [path.get_file().get_basename(), method_name])
				for entry: Variant in fails:
					print("        - %s" % str(entry))

	print("")
	print("%d test, %d doğrulama — %d başarısız, %d dosya hatası"
		% [test_count, assert_count, failed_count, load_errors])
	if test_count == 0:
		_exit_code = 2
	elif failed_count == 0 and load_errors == 0:
		_exit_code = 0
	else:
		_exit_code = 1


func _collect_files() -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(TESTS_DIR)
	if dir == null:
		return result
	var names: PackedStringArray = dir.get_files()
	names.sort()
	for file_name: String in names:
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			result.append(TESTS_DIR.path_join(file_name))
	return result


func _test_methods(test_object: Object) -> Array[String]:
	var found: Array[String] = []
	for method: Dictionary in test_object.get_method_list():
		var method_name: String = String(method["name"])
		if method_name.begins_with("test_") and not found.has(method_name):
			found.append(method_name)
	found.sort()
	return found
