class_name CameraRig
extends Node3D

## Portrait kompozisyon kamerası: pano tamamen görünür, kamera panoya bakar.
## - intro: hafif geriden ve yüksekten yaklaşarak zoom-in
## - shake: kısa devre / sigorta için sönümlü sarsıntı
## - parallax: fiş sürüklerken kamera 1-2 cm kayar (parmağı takip eder)

signal intro_finished()

## Kompozisyon: pano ekran genişliğinin ~%70'ini doldurur (5.76 m / fov 45).
## Üst HUD (başlık + aşırı yük barı) ve alt butonların arasında tam ayrık kalır.
const BASE_POSITION: Vector3 = Vector3(0.0, 0.16, 5.76)
const BASE_FOV: float = 45.0
## Intro yalnızca hafif dolly: ilk kare neredeyse son kompozisyon (ekran görüntüsü/QA).
const INTRO_PULLBACK: Vector3 = Vector3(0.0, 0.05, 0.32)
const INTRO_SECONDS: float = 0.9
const PARALLAX_LIMIT: Vector2 = Vector2(0.02, 0.02)
const SHAKE_LIMIT: float = 0.055

## 0 = intro başlangıcı, 1 = oturmuş kompozisyon. Tween tarafından sürülür.
var intro_progress: float = 1.0:
	set(value):
		intro_progress = clampf(value, 0.0, 1.0)

var _camera: Camera3D = null
var _shake: float = 0.0
var _shake_time: float = 0.0
var _parallax_target: Vector2 = Vector2.ZERO
var _parallax_current: Vector2 = Vector2.ZERO
var _intro_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	_camera = get_node_or_null("Camera3D") as Camera3D
	reset_to_base()


func _process(delta: float) -> void:
	_parallax_current = _parallax_current.lerp(_parallax_target,
		clampf(delta * 6.0, 0.0, 1.0))

	var shake_offset: Vector3 = Vector3.ZERO
	if _shake > 0.0001:
		_shake = maxf(0.0, _shake - delta * 2.8)
		_shake_time += delta
		var amount: float = _shake * SHAKE_LIMIT
		# deterministik, iki frekanslı sarsıntı (randf titreşimi daha "çıtırtılı" olur)
		shake_offset = Vector3(
			sin(_shake_time * 67.0) * amount,
			sin(_shake_time * 89.0 + 1.7) * amount * 0.7,
			0.0)
		rotation.z = sin(_shake_time * 73.0) * _shake * 0.010
	else:
		_shake_time = 0.0
		rotation.z = lerpf(rotation.z, 0.0, clampf(delta * 8.0, 0.0, 1.0))

	var intro_offset: Vector3 = INTRO_PULLBACK * (1.0 - intro_progress)
	position = BASE_POSITION + intro_offset \
		+ Vector3(_parallax_current.x, _parallax_current.y, 0.0) + shake_offset
	if _camera != null:
		_camera.fov = BASE_FOV


## Pano yüklenirken yumuşak zoom-in; bitince intro_finished yayılır.
func play_intro() -> void:
	_kill_intro()
	intro_progress = 0.0
	position = BASE_POSITION + INTRO_PULLBACK
	if _camera != null:
		_camera.fov = BASE_FOV
	_intro_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_intro_tween.tween_property(self, "intro_progress", 1.0, INTRO_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_callback(_on_intro_finished)


func is_intro_playing() -> bool:
	return intro_progress < 0.999


## Kısa devre/sigorta sarsıntısı: intensity 0..1.
func shake(intensity: float) -> void:
	_shake = maxf(_shake, clampf(intensity, 0.0, 1.0))


## Sürükleme paralaksı: normalized bileşenler [-1, 1]; ±2 cm kamera kayması.
func set_parallax(normalized: Vector2) -> void:
	_parallax_target = Vector2(
		clampf(normalized.x, -1.0, 1.0) * PARALLAX_LIMIT.x,
		clampf(normalized.y, -1.0, 1.0) * PARALLAX_LIMIT.y)


func reset_parallax() -> void:
	_parallax_target = Vector2.ZERO


## Kompozisyonu başlangıç durumuna döndürür (retry/QA).
func reset_to_base() -> void:
	_kill_intro()
	intro_progress = 1.0
	_shake = 0.0
	_shake_time = 0.0
	_parallax_target = Vector2.ZERO
	_parallax_current = Vector2.ZERO
	position = BASE_POSITION
	rotation = Vector3.ZERO
	if _camera != null:
		_camera.fov = BASE_FOV


func _on_intro_finished() -> void:
	intro_progress = 1.0
	intro_finished.emit()


func _kill_intro() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = null
