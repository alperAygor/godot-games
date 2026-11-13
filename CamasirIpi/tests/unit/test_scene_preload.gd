extends TestCase

## GameManager sahne ön yüklemesi: arka planda istenen sahne `scene_resource`/`goto_scene` ile alınır,
## istek kaydı temizlenir; bilinmeyen anahtar sessizce yok sayılır. (Sahne değiştirilmez: koşucu ağacı.)

func test_preloaded_scene_is_taken_once() -> void:
	var manager: Node = autoload_node("GameManager")
	manager.call("preload_scene", &"result")
	var packed: PackedScene = manager.call("scene_resource", &"result") as PackedScene
	assert_not_null(packed, "ön yüklenen sahne alınabilmeli")
	assert_eq(packed.resource_path, "res://scenes/Result.tscn")
	assert_eq((manager.get("_preloading") as Dictionary).size(), 0, "alınan istek kayıttan düşmeli")
	# Zaten bellekte: yeni iş parçacığı isteği açılmaz.
	manager.call("preload_scene", &"result")
	assert_eq((manager.get("_preloading") as Dictionary).size(), 0, "bellekteki sahne yeniden istenmemeli")


func test_unknown_scene_key_is_ignored() -> void:
	var manager: Node = autoload_node("GameManager")
	manager.call("preload_scene", &"yok")
	assert_eq((manager.get("_preloading") as Dictionary).size(), 0)
	assert_eq(manager.call("scene_resource", &"yok"), null)
