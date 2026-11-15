extends TestCase

## GameManager sahne ön yüklemesi: arka planda istenen sahne `scene_resource`/`goto_scene` ile alınır,
## istek kaydı temizlenir; bilinmeyen anahtar sessizce yok sayılır. (Sahne değiştirilmez: koşucu ağacı.)

func test_preloaded_scene_is_taken_once() -> void:
	var manager: Node = autoload_node("GameManager")
	manager.call("preload_scene", &"home")
	var packed: PackedScene = manager.call("scene_resource", &"home") as PackedScene
	assert_not_null(packed, "ön yüklenen sahne alınabilmeli")
	assert_eq(packed.resource_path, "res://scenes/Home.tscn")
	assert_eq((manager.get("_preloading") as Dictionary).size(), 0, "alınan istek kayıttan düşmeli")
	# Zaten bellekte: yeni iş parçacığı isteği açılmaz.
	manager.call("preload_scene", &"home")
	assert_eq((manager.get("_preloading") as Dictionary).size(), 0, "bellekteki sahne yeniden istenmemeli")


func test_unknown_scene_key_is_ignored() -> void:
	var manager: Node = autoload_node("GameManager")
	manager.call("preload_scene", &"yok")
	assert_eq((manager.get("_preloading") as Dictionary).size(), 0)
	assert_eq(manager.call("scene_resource", &"yok"), null)


func test_every_registered_scene_file_exists() -> void:
	var manager: Node = autoload_node("GameManager")
	for key: Variant in (manager.get("SCENES") as Dictionary).keys():
		var path: String = String((manager.get("SCENES") as Dictionary)[key])
		assert_true(ResourceLoader.exists(path), "sahne yok: %s" % path)


func test_finish_run_stores_result_and_sets_phase() -> void:
	var manager: Node = autoload_node("GameManager")
	var seen: Array[int] = [0]
	manager.connect("phase_changed", func(_from: int, _to: int) -> void: seen[0] += 1)
	manager.call("finish_run", {"won": true})
	assert_eq((manager.get("last_result") as Dictionary)["won"], true)
	assert_eq(int(manager.get("phase")), int(manager.get("Phase")["RESULT"]))
	assert_true(seen[0] >= 1)
