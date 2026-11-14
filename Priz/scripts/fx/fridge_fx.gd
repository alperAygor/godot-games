class_name FridgeFx
extends Appliance

## Buzdolabı: çalışırken buz mavisi gösterge yanar, gövde kompresör uğultusuyla çok hafif titrer.

const MODEL: PackedScene = preload("res://assets/models/appliances/fridge.glb")

var _led: StandardMaterial3D
var _body: Node3D
var _body_rest: Vector3 = Vector3.ZERO
var _t: float = 0.0


func _init() -> void:
	appliance_id = "fridge"
	default_ramp = 1.0
	if model == null:
		model = MODEL


func _setup() -> void:
	_led = make_indicator(Color(0.45, 0.85, 1.0))
	_body = part("Body")
	if _body != null:
		_body_rest = _body.position


func _on_level(level: float) -> void:
	if _led != null:
		_led.emission_energy_multiplier = 4.0 * level


func _animate(delta: float, level: float) -> void:
	if _body == null:
		return
	_t += delta
	# Uğultu: düşük genlikli, iki frekanslı "nefes"; yalnız çalışırken.
	var hum: float = level * (0.5 + 0.5 * sin(_t * 1.3))
	_body.scale = Vector3(1.0, 1.0 + 0.0012 * hum * sin(_t * 44.0), 1.0)
	_body.position = _body_rest + Vector3(0.00035 * hum * sin(_t * 61.0), 0.0, 0.0)
