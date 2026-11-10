class_name ShakeSimulator
extends Node

## "Teslimata Başla" ile çantaya sinüs tabanlı sarsıntı uygular.
## Sarsıntı tek bir `Node3D` (ShakeRoot) üzerine biner; çanta ve paketler onun
## çocuğu olduğu için hepsi birlikte sallanır — paketlerin tween'leri bozulmaz.
##
## Genlik zarfı: rampa-in -> ritmik tümsekler -> rampa-out. Böylece 5 saniyelik
## sarsıntı "düz bir titreşim" değil, tekerlek tümseklerinden geçme gibi okunur.

signal shake_started()
signal shake_step(intensity: float, delta: float)
signal shake_finished()

@export var target_path: NodePath = ^"../ShakeRoot"
@export var duration: float = 5.0
@export var amplitude: float = 0.032
@export var rotation_amplitude: float = 2.4
@export var frequency: float = 6.0
@export var ramp_in: float = 0.35
@export var ramp_out: float = 0.7

var running: bool = false
var intensity: float = 0.0

var _target: Node3D = null
var _base_position: Vector3 = Vector3.ZERO
var _base_rotation: Vector3 = Vector3.ZERO
var _elapsed: float = 0.0


func _ready() -> void:
	_resolve_target()


func start() -> void:
	_resolve_target()
	if _target == null:
		push_error("ShakeSimulator: hedef düğüm bulunamadı (%s)" % target_path)
		return
	_base_position = _target.position
	_base_rotation = _target.rotation
	_elapsed = 0.0
	running = true
	shake_started.emit()


## Kaldığı yerden devam eder (revive sonrası): ilerleme korunur.
func resume() -> void:
	if _target == null or running:
		return
	running = true
	shake_started.emit()


## Sarsıntıyı durdurur ama ilerlemeyi saklar; `resume()` ile sürer.
func stop() -> void:
	if not running:
		return
	running = false
	intensity = 0.0
	_reset_target()


func progress_ratio() -> float:
	return clampf(_elapsed / maxf(duration, 0.001), 0.0, 1.0)


func _process(delta: float) -> void:
	if not running or _target == null:
		return
	_elapsed += delta

	# zarf: yumuşak başla, bitişe doğru sön
	var envelope: float = 1.0
	if _elapsed < ramp_in:
		envelope = _elapsed / ramp_in
	elif _elapsed > duration - ramp_out:
		envelope = maxf(0.0, (duration - _elapsed) / ramp_out)

	# tümsek ritmi: iki farklı frekansın çarpımı düzensiz sarsıntı hissi verir
	var pulse: float = 0.6 + 0.4 * absf(sin(_elapsed * PI * 1.75))
	intensity = clampf(envelope * pulse, 0.0, 1.0)

	var w: float = _elapsed * TAU * frequency
	var offset: Vector3 = Vector3(
		sin(w) * amplitude,
		sin(w * 1.37 + 1.1) * amplitude * 0.75,
		sin(w * 0.71 + 2.0) * amplitude * 0.45) * intensity
	var tilt: Vector3 = Vector3(
		sin(w * 0.93) * rotation_amplitude,
		0.0,
		sin(w * 1.23 + 0.6) * rotation_amplitude * 0.8) * intensity

	_target.position = _base_position + offset
	_target.rotation = _base_rotation + Vector3(deg_to_rad(tilt.x), 0.0, deg_to_rad(tilt.z))

	shake_step.emit(intensity, delta)

	if _elapsed >= duration:
		running = false
		intensity = 0.0
		_reset_target()
		shake_finished.emit()


func _resolve_target() -> void:
	if _target != null:
		return
	_target = get_node_or_null(target_path) as Node3D


func _reset_target() -> void:
	if _target == null:
		return
	_target.position = _base_position
	_target.rotation = _base_rotation
