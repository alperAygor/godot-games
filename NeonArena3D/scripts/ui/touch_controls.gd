extends Control
## Dokunmatik kontroller: solda hareket çubuğu, sağda nişan çubuğu (yüzen),
## ATILMA / NOVA düğmeleri ve duraklat. Çoklu dokunuş desteklenir.

signal pause_pressed

const KIT = preload("res://scripts/ui/ui_kit.gd")
const STICK_RADIUS := 78.0
const KNOB_RADIUS := 34.0
const DEADZONE := 0.16

var enabled := false
var move := Vector2.ZERO
var aim := Vector2.ZERO
var aiming := false
var dash_ratio := 1.0
var nova_ratio := 0.0
var auto_fire := true

var _margin := Vector4(28, 20, 28, 20)
var _move_id := -1
var _move_base := Vector2.ZERO
var _move_knob := Vector2.ZERO
var _aim_id := -1
var _aim_base := Vector2.ZERO
var _aim_knob := Vector2.ZERO
var _dash_queued := false
var _nova_queued := false
var _dash_flash := 0.0
var _nova_flash := 0.0
var _time := 0.0
var _button_ids: Dictionary = {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_PAUSABLE

func set_margins(m: Vector4) -> void:
	_margin = m

func set_enabled(on: bool) -> void:
	enabled = on
	visible = on
	if not on:
		release_all()

func release_all() -> void:
	_move_id = -1
	_aim_id = -1
	move = Vector2.ZERO
	aim = Vector2.ZERO
	aiming = false
	_dash_queued = false
	_nova_queued = false
	_button_ids.clear()

func take_dash() -> bool:
	var out := _dash_queued
	_dash_queued = false
	return out

func take_nova() -> bool:
	var out := _nova_queued
	_nova_queued = false
	return out

# --- Yerleşim -------------------------------------------------------------------
func _vp() -> Vector2:
	return get_viewport_rect().size

func _move_rest() -> Vector2:
	var vp := _vp()
	return Vector2(_margin.x + 150.0, vp.y - _margin.w - 150.0)

func _aim_rest() -> Vector2:
	var vp := _vp()
	return Vector2(vp.x - _margin.z - 150.0, vp.y - _margin.w - 150.0)

func _dash_center() -> Vector2:
	var vp := _vp()
	return Vector2(vp.x - _margin.z - 330.0, vp.y - _margin.w - 92.0)

func _nova_center() -> Vector2:
	var vp := _vp()
	return Vector2(vp.x - _margin.z - 96.0, vp.y - _margin.w - 330.0)

func _pause_center() -> Vector2:
	var vp := _vp()
	return Vector2(vp.x - _margin.z - 34.0, _margin.y + 34.0)

const DASH_R := 60.0
const NOVA_R := 52.0
const PAUSE_R := 30.0

# --- Girdi ----------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press(touch.index, touch.position)
		else:
			_release(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_drag(drag.index, drag.position)

func _press(id: int, pos: Vector2) -> void:
	var vp := _vp()
	if pos.distance_to(_pause_center()) < PAUSE_R + 16.0:
		pause_pressed.emit()
		return
	if pos.distance_to(_dash_center()) < DASH_R + 14.0:
		_dash_queued = true
		_dash_flash = 1.0
		_button_ids[id] = "dash"
		return
	if pos.distance_to(_nova_center()) < NOVA_R + 14.0:
		_nova_queued = true
		_nova_flash = 1.0
		_button_ids[id] = "nova"
		return
	if pos.x < vp.x * 0.5:
		if _move_id == -1:
			_move_id = id
			_move_base = _clamp_base(pos)
			_move_knob = pos
			_update_move()
	else:
		if _aim_id == -1:
			_aim_id = id
			_aim_base = _clamp_base(pos)
			_aim_knob = pos
			_update_aim()

func _clamp_base(pos: Vector2) -> Vector2:
	var vp := _vp()
	return Vector2(clampf(pos.x, STICK_RADIUS + 8.0, vp.x - STICK_RADIUS - 8.0), clampf(pos.y, STICK_RADIUS + 8.0, vp.y - STICK_RADIUS - 8.0))

func _drag(id: int, pos: Vector2) -> void:
	if id == _move_id:
		_move_knob = pos
		_update_move()
	elif id == _aim_id:
		_aim_knob = pos
		_update_aim()

func _release(id: int) -> void:
	if id == _move_id:
		_move_id = -1
		move = Vector2.ZERO
	elif id == _aim_id:
		_aim_id = -1
		aim = Vector2.ZERO
		aiming = false
	_button_ids.erase(id)

func _stick_value(base: Vector2, knob: Vector2) -> Vector2:
	var v := (knob - base) / STICK_RADIUS
	var length := v.length()
	if length < DEADZONE:
		return Vector2.ZERO
	return v / length * clampf((length - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)

func _update_move() -> void:
	# Parmak çemberin dışına taşarsa taban parmağı izler: çubuk hiç "kopmaz".
	var off := _move_knob - _move_base
	if off.length() > STICK_RADIUS * 1.25:
		_move_base = _move_knob - off.normalized() * STICK_RADIUS * 1.25
	move = _stick_value(_move_base, _move_knob)

func _update_aim() -> void:
	var off := _aim_knob - _aim_base
	if off.length() > STICK_RADIUS * 1.25:
		_aim_base = _aim_knob - off.normalized() * STICK_RADIUS * 1.25
	var v := _stick_value(_aim_base, _aim_knob)
	aiming = v.length() > 0.05
	if aiming:
		aim = v.normalized()

func _process(delta: float) -> void:
	_time += delta
	_dash_flash = maxf(0.0, _dash_flash - delta * 4.0)
	_nova_flash = maxf(0.0, _nova_flash - delta * 3.0)
	if enabled:
		queue_redraw()

# --- Çizim ----------------------------------------------------------------------
func _draw() -> void:
	if not enabled:
		return
	_draw_stick(_move_base if _move_id != -1 else _move_rest(), _move_knob if _move_id != -1 else _move_rest(), _move_id != -1, KIT.CYAN, "")
	var aim_label := "" if _aim_id != -1 else (tr("OTOMATİK") if auto_fire else tr("NİŞAN"))
	_draw_stick(_aim_base if _aim_id != -1 else _aim_rest(), _aim_knob if _aim_id != -1 else _aim_rest(), _aim_id != -1, KIT.MAGENTA, aim_label)
	_draw_button(_dash_center(), DASH_R, dash_ratio, "dash", tr("ATIL"), KIT.CYAN, _dash_flash)
	_draw_button(_nova_center(), NOVA_R, nova_ratio, "nova", "NOVA", KIT.MAGENTA, _nova_flash)
	var pc := _pause_center()
	draw_circle(pc, PAUSE_R, Color(0.03, 0.06, 0.11, 0.6))
	draw_arc(pc, PAUSE_R, 0.0, TAU, 32, Color(KIT.CYAN, 0.5), 2.0, true)
	KIT.icon(self, "pause", pc, 13.0, Color(KIT.TEXT, 0.9))

func _draw_stick(base: Vector2, knob: Vector2, held: bool, color: Color, label: String) -> void:
	var alpha := 0.9 if held else 0.38
	draw_circle(base, STICK_RADIUS, Color(color.r * 0.12, color.g * 0.12, color.b * 0.12, 0.34 * alpha + 0.08))
	draw_arc(base, STICK_RADIUS, 0.0, TAU, 48, Color(color, 0.55 * alpha), 2.5, true)
	for i in 4:
		var d := Vector2.from_angle(TAU * float(i) / 4.0)
		var side := Vector2(-d.y, d.x)
		var tip := base + d * (STICK_RADIUS - 9.0)
		draw_colored_polygon(PackedVector2Array([tip, tip - d * 9.0 + side * 6.0, tip - d * 9.0 - side * 6.0]), Color(color, 0.45 * alpha))
	var off := knob - base
	if off.length() > STICK_RADIUS:
		off = off.normalized() * STICK_RADIUS
	var kp := base + off
	draw_circle(kp, KNOB_RADIUS, Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 0.5 * alpha + 0.12))
	draw_arc(kp, KNOB_RADIUS, 0.0, TAU, 32, Color(color, alpha), 3.0, true)
	if label != "":
		draw_string(KIT.bold(), Vector2(base.x - 80.0, base.y + 5.0), label, HORIZONTAL_ALIGNMENT_CENTER, 160, 12, Color(KIT.TEXT, 0.6))

func _draw_button(center: Vector2, r: float, ratio: float, kind: String, label: String, color: Color, flash: float) -> void:
	var ready := ratio >= 0.999
	var scale_k := 1.0 - 0.08 * flash
	var rr := r * scale_k
	draw_circle(center, rr, Color(color.r * 0.14, color.g * 0.14, color.b * 0.14, 0.62))
	if ready:
		draw_circle(center, rr - 4.0, Color(color, 0.16 + 0.1 * sin(_time * 5.0) + 0.3 * flash))
	draw_arc(center, rr, 0.0, TAU, 48, Color(color, 0.28), 3.0, true)
	draw_arc(center, rr, -PI * 0.5, -PI * 0.5 + TAU * clampf(ratio, 0.0, 1.0), 48, Color(color, 0.95 if ready else 0.7), 4.5, true)
	var tint := Color(1, 1, 1, 0.95) if ready else Color(KIT.DIM, 0.6)
	KIT.icon(self, kind, center + Vector2(0, -7.0), rr * 0.4, Color(color.lerp(Color(1, 1, 1), 0.5), tint.a))
	draw_string(KIT.bold(), Vector2(center.x - 60.0, center.y + rr * 0.62), label, HORIZONTAL_ALIGNMENT_CENTER, 120, 13, tint)
