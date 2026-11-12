class_name AmbientSway
extends Node3D

## Arka plan dekorunun çok hafif sallanması (sinüs, ≤2°). Yalnız görsel huzur verir;
## fizik/prob ölçümlerine dokunmaz (yalnız dönme; konum/ölçek sabit). Değerler isimli
## sabit ve sahneden ayarlanabilir; `data/balance.json` değişmez. Deterministik
## sinüs: rastgelelik yok.

const MAX_AMPLITUDE_DEG: float = 2.0

@export var amplitude_deg: float = 1.2
@export var period_seconds: float = 4.0
@export var axis: Vector3 = Vector3(0.0, 0.0, 1.0)
@export var phase_offset_seconds: float = 0.0

var _base_rotation: Vector3 = Vector3.ZERO
var _axis: Vector3 = Vector3(0.0, 0.0, 1.0)
var _time: float = 0.0


func _ready() -> void:
	_base_rotation = rotation
	amplitude_deg = clampf(amplitude_deg, 0.0, MAX_AMPLITUDE_DEG)
	_axis = axis.normalized() if not axis.is_zero_approx() else Vector3(0.0, 0.0, 1.0)
	_time = fposmod(phase_offset_seconds, maxf(period_seconds, 0.001))


func _process(delta: float) -> void:
	_time += delta
	var angle: float = deg_to_rad(amplitude_deg) \
		* sin(TAU * _time / maxf(period_seconds, 0.001))
	rotation = _base_rotation + _axis * angle
