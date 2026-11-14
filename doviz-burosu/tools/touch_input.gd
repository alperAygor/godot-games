extends RefCounted
## Dokunma simülasyonu: gerçek telefondaki gibi InputEventScreenTouch / ScreenDrag olayları üretir.
## Koordinatlar tasarım (viewport) biriminde: 720x1280 ekranda (0,0) sol üst köşe.
## Godot "emulate_mouse_from_touch" ile dokunmayı fareye de çevirdiği için Button vb. arayüz öğeleri tepki verir.
## Kullanım (preload ile; tools/ export'a girmez):
##   const TouchInput := preload("res://tools/touch_input.gd")
##   await TouchInput.tap(get_tree(), Vector2(360, 640))
##   await TouchInput.tap_node(get_tree(), "SettingsButton")


## Tasarım koordinatını pencere pikseline çevirir (Input olayları pencere pikseli bekler).
static func to_window(tree: SceneTree, design_pos: Vector2) -> Vector2:
	return tree.root.get_final_transform() * design_pos


## Control'ün tasarım koordinatındaki merkezi.
static func center_of(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


## Aktif sahnede adı verilen düğümü bulur (önce %UniqueName, sonra derin arama).
static func find_control(tree: SceneTree, node_name: String) -> Control:
	var scene := tree.current_scene
	if scene == null:
		return null
	var node := scene.get_node_or_null("%" + node_name)
	if node == null:
		node = scene.find_child(node_name, true, false)
	return node as Control


static func tap(tree: SceneTree, design_pos: Vector2, hold_seconds := 0.05) -> void:
	var pos := to_window(tree, design_pos)
	_touch(pos, true)
	await tree.create_timer(hold_seconds, true, false, true).timeout
	_touch(pos, false)
	await tree.process_frame
	await tree.process_frame


## Düğümün ortasına dokunur. Bulamazsa false döner.
static func tap_node(tree: SceneTree, node_name: String) -> bool:
	var control := find_control(tree, node_name)
	if control == null or not control.is_visible_in_tree():
		return false
	await tap(tree, center_of(control))
	return true


static func swipe(tree: SceneTree, from: Vector2, to: Vector2, duration := 0.3, steps := 12) -> void:
	var start := to_window(tree, from)
	var end := to_window(tree, to)
	var step_time := duration / steps
	_touch(start, true)
	var previous := start
	for i in range(1, steps + 1):
		await tree.create_timer(step_time, true, false, true).timeout
		var pos := start.lerp(end, float(i) / steps)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = pos
		drag.relative = pos - previous
		drag.velocity = (pos - previous) / step_time
		Input.parse_input_event(drag)
		previous = pos
	_touch(end, false)
	await tree.process_frame


## Android geri tuşu: işletim sisteminin gönderdiği bildirimin aynısı.
static func back(tree: SceneTree) -> void:
	tree.root.propagate_notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await tree.process_frame


static func _touch(pos: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = pos
	event.pressed = pressed
	Input.parse_input_event(event)
