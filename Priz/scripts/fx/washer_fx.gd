class_name WasherFx
extends Appliance

## Çamaşır makinesi: tambur camın arkasında döner (ileri, durak, geri), çamaşırlar onunla
## birlikte yuvarlanır; gövde hafifçe titrer; program düğmesi döner.

const MODEL: PackedScene = preload("res://assets/models/appliances/washer.glb")
const MAX_SPEED: float = 5.5  # rad/sn

var _drum: Node3D
var _body: Node3D
var _body_rest: Vector3 = Vector3.ZERO
var _led: StandardMaterial3D
var _phase: float = 0.0
var _t: float = 0.0


func _init() -> void:
	appliance_id = "washer"
	default_ramp = 1.2
	if model == null:
		model = MODEL


func _setup() -> void:
	_drum = part("Drum")
	_body = part("Body")
	if _body != null:
		_body_rest = _body.position
	_led = make_indicator(Color(0.4, 1.0, 0.55))


func _on_switch(on: bool) -> void:
	var dial: Node3D = part("Dial")
	if dial != null:
		var t: Tween = create_tween()
		t.tween_property(dial, "rotation:z", deg_to_rad(-120.0) if on else 0.0, 0.25).set_trans(Tween.TRANS_BACK)


func _on_level(level: float) -> void:
	if _led != null:
		_led.emission_energy_multiplier = 4.0 * (1.0 if running else 0.0) * _mains


func _animate(delta: float, level: float) -> void:
	if _drum == null:
		return
	_t += delta * level
	# Yön deseni: ~7 sn bir yöne, kısa durak, sonra ters yön (yumuşak geçişli).
	var dir: float = clampf(sin(_t * TAU / 14.0) * 3.0, -1.0, 1.0)
	_phase += delta * MAX_SPEED * level * dir
	_drum.rotation.z = _phase
	if _body != null:
		var shake: float = level * absf(dir) * 0.0006
		_body.position = _body_rest + Vector3(shake * sin(_t * 53.0), shake * 0.5 * sin(_t * 71.0), 0.0)
