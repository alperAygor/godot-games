extends Node
## Sahne geçişleri, geçmiş ve Android geri tuşu.
##   goto(path)  geçmişi temizleyip sahneye geçer (ör. ana menüye dönüş)
##   push(path)  geri dönülebilir şekilde açar (ör. ayarlar)
##   back()      bir adım geri
## Geri tuşu (Android geri / masaüstünde Esc) sırası:
##   1) aktif sahnede handle_back() varsa ve true dönerse orada biter (ör. açık bir popup'ı kapatmak)
##   2) geçmiş varsa önceki sahneye dönülür
##   3) en alttaysa root_back_requested yayınlanır; dinleyen yoksa uygulama kapanır

signal scene_changed(path: String)
signal root_back_requested

const BACK_ACTION := &"back"

## Testlerde 0 yapılabilir.
var transition_time := 0.15

var _history: PackedStringArray = []
var _busy := false
var _overlay: ColorRect
var _pixel_filter: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().quit_on_go_back = false
	_ensure_back_action()

	_build_pixel_filter()
	var layer := CanvasLayer.new()
	layer.layer = 128
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.modulate.a = 0.0
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_overlay)


## Piksel görünümü: ekranın en üstünde (geçiş karartmasının altında) tam ekran gölgelendirici. Ayardan açılıp kapanır; ekransızda yok.
func _build_pixel_filter() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var filter_layer := CanvasLayer.new()
	filter_layer.layer = 100
	add_child(filter_layer)
	_pixel_filter = ColorRect.new()
	_pixel_filter.name = "PixelFilter"
	_pixel_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pixel_filter.set_anchors_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/pixel_filter.gdshader")
	_pixel_filter.material = material
	filter_layer.add_child(_pixel_filter)
	_apply_pixel_filter()
	SettingsManager.setting_changed.connect(func(section: String, key: String, _value: Variant) -> void:
		if section == "game" and key == "pixel_filter":
			_apply_pixel_filter())


func _apply_pixel_filter() -> void:
	_pixel_filter.visible = bool(SettingsManager.get_value("game", "pixel_filter"))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Bildirim tüm ağaca yayılırken sahne değiştirilemez; kare sonuna ertele.
		back.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(BACK_ACTION):
		get_viewport().set_input_as_handled()
		back()


func current_path() -> String:
	var scene := get_tree().current_scene
	return scene.scene_file_path if scene else ""


func history_size() -> int:
	return _history.size()


func is_busy() -> bool:
	return _busy


func goto(path: String) -> void:
	if _busy:
		return
	_history.clear()
	await _change(path)


func push(path: String) -> void:
	if _busy:
		return
	var current := current_path()
	if not current.is_empty():
		_history.append(current)
	await _change(path)


func back() -> void:
	if _busy:
		return
	var scene := get_tree().current_scene
	if scene and scene.has_method("handle_back") and scene.handle_back():
		return
	if _history.is_empty():
		if root_back_requested.get_connections().is_empty():
			get_tree().quit()
		else:
			root_back_requested.emit()
		return
	var previous := _history[_history.size() - 1]
	_history.remove_at(_history.size() - 1)
	await _change(previous)


func _change(path: String) -> void:
	_busy = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # geçiş sırasında dokunmaları yut
	if transition_time > 0.0:
		await _fade_to(1.0)
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneManager: '%s' açılamadı (hata %d)." % [path, err])
	await get_tree().process_frame  # yeni sahne kare sonunda ağaca eklenir
	await get_tree().process_frame
	if transition_time > 0.0:
		await _fade_to(0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	scene_changed.emit(path)


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_overlay, "modulate:a", alpha, transition_time)
	await tween.finished


func _ensure_back_action() -> void:
	if InputMap.has_action(BACK_ACTION):
		return
	InputMap.add_action(BACK_ACTION)
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	InputMap.action_add_event(BACK_ACTION, escape)
