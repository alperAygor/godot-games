extends SceneTree
## Dil değişimini menü açıkken tetikler; ekran opaklığını ve düğüm sayısını raporlar.

func _initialize() -> void:
	_run.call_deferred()

func _report(scene, label: String) -> void:
	var m = scene.menus
	var parts: Array = []
	for child in m.get_children():
		if child is Control:
			parts.append("%s(v=%s a=%.2f)" % [child.get_class(), str(child.visible), child.modulate.a])
	print(label, " ekran=", m.current, " çocuklar=", parts.size(), " ", ", ".join(parts))

func _run() -> void:
	var scene = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	for i in 5:
		await process_frame
	scene.menus.open_sub("settings", "main")
	for i in 20:
		await process_frame
	root.get_node("I18n").set_language("en")
	for i in 20:
		await process_frame
	_report(scene, "değişim sonrası")
	scene.menus._back()
	for i in 40:
		await process_frame
	_report(scene, "geri sonrası")
	root.get_node("I18n").set_language("tr")
	quit(0)
