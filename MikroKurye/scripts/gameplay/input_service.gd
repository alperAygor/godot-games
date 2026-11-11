class_name InputService
extends Control

const DEFAULT_JOYSTICK_RADIUS: float = 130.0
const DEFAULT_JOYSTICK_DEADZONE: float = 0.12
const LOWER_SCREEN_FRACTION: float = 0.5
const KNOB_RADIUS_FRACTION: float = 0.32
const BASE_COLOR: Color = Color(0.12, 0.18, 0.24, 0.45)
const KNOB_COLOR: Color = Color(0.65, 0.85, 1.0, 0.8)
const NO_POINTER: int = -1
const MOUSE_POINTER: int = -2

@export var robot_path: NodePath

var _robot: RobotController = null
var _pointer_id: int = NO_POINTER
var _pointer_origin: Vector2 = Vector2.ZERO
var _pointer_position: Vector2 = Vector2.ZERO
var _joystick_input: Vector2 = Vector2.ZERO
var _radius: float = DEFAULT_JOYSTICK_RADIUS
var _deadzone: float = DEFAULT_JOYSTICK_DEADZONE
var _was_user_active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_robot = get_node_or_null(robot_path) as RobotController
	_radius = maxf(1.0, _balance_value("joystick_radius", DEFAULT_JOYSTICK_RADIUS))
	_deadzone = clampf(_balance_value("joystick_deadzone", DEFAULT_JOYSTICK_DEADZONE), 0.0, 0.99)
	if _robot == null:
		push_warning("InputService: robot_path must point to a RobotController.")


func _physics_process(_delta: float) -> void:
	var left: bool = Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	var right: bool = Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
	var forward: bool = Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)
	var backward: bool = Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)
	var keyboard_active: bool = left or right or forward or backward
	var user_active: bool = keyboard_active or _pointer_id != NO_POINTER
	var move_input: Vector2 = _joystick_input
	if keyboard_active:
		move_input = Vector2(
			(1.0 if right else 0.0) - (1.0 if left else 0.0),
			(1.0 if forward else 0.0) - (1.0 if backward else 0.0)
		)
	# The headless probe owns input unless a player actually takes control.
	if is_instance_valid(_robot) and (user_active or _was_user_active):
		_robot.set_move_input(move_input.limit_length(1.0) if user_active else Vector2.ZERO)
	_was_user_active = user_active


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		if touch.pressed and not touch.canceled:
			_begin_pointer(touch.index, touch.position)
		elif touch.index == _pointer_id:
			_release_pointer()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event as InputEventScreenDrag
		if drag.index == _pointer_id:
			_update_pointer(drag.position)
	elif event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_begin_pointer(MOUSE_POINTER, button.position)
			elif _pointer_id == MOUSE_POINTER:
				_release_pointer()
	elif event is InputEventMouseMotion and _pointer_id == MOUSE_POINTER:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		_update_pointer(motion.position)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_release_pointer()


func _begin_pointer(pointer_id: int, position: Vector2) -> void:
	if _pointer_id != NO_POINTER:
		return
	if position.y < get_viewport_rect().size.y * LOWER_SCREEN_FRACTION:
		return
	_pointer_id = pointer_id
	_pointer_origin = position
	_update_pointer(position)


func _update_pointer(position: Vector2) -> void:
	_pointer_position = position
	var displacement: Vector2 = ((position - _pointer_origin) / _radius).limit_length(1.0)
	var magnitude: float = displacement.length()
	_joystick_input = Vector2.ZERO
	if magnitude > _deadzone:
		var strength: float = (magnitude - _deadzone) / (1.0 - _deadzone)
		_joystick_input = Vector2(displacement.x, -displacement.y).normalized() * strength
	queue_redraw()


func _release_pointer() -> void:
	_pointer_id = NO_POINTER
	_joystick_input = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	if _pointer_id == NO_POINTER:
		return
	var to_local: Transform2D = get_global_transform_with_canvas().affine_inverse()
	var center: Vector2 = to_local * _pointer_origin
	var offset: Vector2 = (_pointer_position - _pointer_origin).limit_length(_radius)
	draw_circle(center, _radius, BASE_COLOR)
	draw_circle(to_local * (_pointer_origin + offset), _radius * KNOB_RADIUS_FRACTION, KNOB_COLOR)


func _balance_value(key: String, fallback: float) -> float:
	var game_data: Node = get_node_or_null("/root/GameData")
	if game_data == null:
		return fallback
	var physics: Variant = game_data.call("value", "balance", "physics", null)
	if physics is Dictionary:
		var result: Variant = physics.get(key, fallback)
		if result is float or result is int:
			return float(result)
	return fallback
