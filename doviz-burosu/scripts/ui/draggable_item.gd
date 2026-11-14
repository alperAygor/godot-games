class_name DraggableItem
extends PanelContainer
## Masadaki fiziksel nesne (banknot, belge): dokununca `_on_tap`, basılı sürükleyince masada serbestçe taşınır.
## Sürüklerken kalkar (büyür, hafif yatar, üstte durur), bırakılınca `released` ile merkez konumunu bildirir; yerleşmesine masa karar verir.

signal released(item: DraggableItem, global_center: Vector2)

## Tutulabilir mi (inceleme sayfası açıkken ya da işlem bitince kapatılabilir).
var draggable := true
## Masadaki yeri (tepsiden geri dönünce buraya yerleşir).
var home_position := Vector2.ZERO

var _pressed := false
var _dragging := false
var _press_point := Vector2.ZERO
var _grab_offset := Vector2.ZERO


func is_dragging() -> bool:
	return _dragging


func _on_tap() -> void:
	pass


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_dragging = false
			_press_point = event.global_position
			_grab_offset = global_position - event.global_position
		elif _pressed:
			_pressed = false
			if _dragging:
				_end_drag()
			else:
				_on_tap()
		accept_event()
	elif event is InputEventMouseMotion and _pressed and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		if not _dragging and draggable and event.global_position.distance_to(_press_point) > 14.0:
			_begin_drag()
		if _dragging:
			global_position = event.global_position + _grab_offset
			rotation = clampf(event.relative.x * 0.012, -0.12, 0.12)
		accept_event()


func _begin_drag() -> void:
	_dragging = true
	z_index = 12
	pivot_offset = size / 2.0
	scale = Vector2(1.06, 1.06)
	Feel.sfx("paper_slide", 1.1)


func _end_drag() -> void:
	_dragging = false
	z_index = 0
	rotation = 0.0
	if not Feel.instant:
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector2.ONE, 0.08)
	else:
		scale = Vector2.ONE
	released.emit(self, global_position + size / 2.0)
