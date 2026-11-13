class_name TutorialGlow
extends Node2D

## Bir bölgeyi (askı, sepet kuyruğu) yumuşakça aydınlatan nabız. Girdi tutmaz.

const GLOW_COLOR: Color = Color("2ec4a6")
const LAYERS: int = 3
const GROW_STEP: float = 14.0
const PEAK_ALPHA: float = 0.38
const LAYER_FALLOFF: float = 0.32
const CORNER_RADIUS: int = 48
const PULSE_IN_SECONDS: float = 0.55
const PULSE_OUT_SECONDS: float = 0.7
const GLOW_Z: int = 150

var strength: float = 0.0:
	set(value):
		strength = value
		queue_redraw()

var _rect: Rect2 = Rect2()
var _tween: Tween = null
var _box: StyleBoxFlat = StyleBoxFlat.new()


func _init() -> void:
	z_index = GLOW_Z
	visible = false
	_box.set_corner_radius_all(CORNER_RADIUS)
	_box.anti_aliasing = true


func pulse(rect: Rect2, pulses: int) -> void:
	_rect = rect
	visible = true
	strength = 0.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	for _i: int in range(maxi(pulses, 1)):
		_tween.tween_property(self, "strength", 1.0, PULSE_IN_SECONDS)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_tween.tween_property(self, "strength", 0.0, PULSE_OUT_SECONDS)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(hide_now)


func hide_now() -> void:
	if _tween != null:
		_tween.kill()
	visible = false
	strength = 0.0


func _draw() -> void:
	for layer: int in range(LAYERS):
		var alpha: float = PEAK_ALPHA * strength * (1.0 - LAYER_FALLOFF * float(LAYERS - 1 - layer))
		_box.bg_color = Color(GLOW_COLOR, alpha)
		draw_style_box(_box, _rect.grow(GROW_STEP * float(LAYERS - 1 - layer)))
