extends SceneTree
## Hikaye içeriğini denetler: godot --headless --path . -s res://tools/validate_content.gd
## Çıkış kodu 0 = sağlam, 1 = hata var (hatalar yazdırılır).


func _init() -> void:
	var errors := StoryValidator.validate()
	if errors.is_empty():
		print("İçerik sağlam: 15 gün, %d karakter, %d son." % [StoryDb.load_default().characters.size(), StoryDb.load_default().endings.size()])
		quit(0)
		return
	for error in errors:
		printerr("✗ " + error)
	printerr("%d hata" % errors.size())
	quit(1)
