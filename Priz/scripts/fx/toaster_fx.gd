class_name ToasterFx
extends Appliance

## Ekmek kızartma makinesi: kol iner, ekmekler yuvaya gömülür, teller kızarır (≈1.6 sn);
## kapanınca ekmekler yaylanarak fırlar.

const MODEL: PackedScene = preload("res://assets/models/appliances/toaster.glb")
const DROP: float = 0.065

var _coils: MeshInstance3D
var _glow: OmniLight3D
var _toast_y: float = 0.0
var _lever_y: float = 0.0


func _init() -> void:
	appliance_id = "toaster"
	default_ramp = 1.6
	if model == null:
		model = MODEL


func _setup() -> void:
	_coils = mesh_part("Coils")
	var toast: Node3D = part("Toast")
	var lever: Node3D = part("Lever")
	if toast != null:
		_toast_y = toast.position.y
	if lever != null:
		_lever_y = lever.position.y
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.45, 0.15)
	_glow.omni_range = 0.45
	_glow.shadow_enabled = false
	_glow.position = Vector3(0.0, 0.24, 0.0)
	_glow.visible = false
	add_child(_glow)


func _on_switch(on: bool) -> void:
	var toast: Node3D = part("Toast")
	var lever: Node3D = part("Lever")
	var t: Tween = create_tween().set_parallel(true)
	if on:
		if lever != null:
			t.tween_property(lever, "position:y", _lever_y - 0.08, 0.14).set_ease(Tween.EASE_IN)
		if toast != null:
			t.tween_property(toast, "position:y", _toast_y - DROP, 0.16).set_ease(Tween.EASE_IN)
	else:
		if lever != null:
			t.tween_property(lever, "position:y", _lever_y, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if toast != null:
			t.tween_property(toast, "position:y", _toast_y, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_level(level: float) -> void:
	if _coils != null:
		_coils.set_instance_shader_parameter("heat", level)
	set_light(_glow, 0.5 * level)
