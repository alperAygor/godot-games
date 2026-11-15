class_name DioramaCamera
extends Node3D

## Dikey (portre) diorama kamerası: odak noktası etrafında yörünge, minyatür hissi için dar
## görüş açısı + alan derinliği, parmakla paralaks ve kazanma anında geri çekilme.
##
## Kamu arayüzü:
##   set_parallax(v: Vector2)  — v ∈ [-1, 1]²; dioramayı birkaç derece döndürür (yumuşatılmış)
##   pull_back(duration)       — kazanma: kamera yavaşça geri çekilir ve hafif yükselir
##   finish_pull_back()        — geri çekilmeyi anında bitir
##   reset_view()              — başlangıç kadrajına dön
##   frame_focus(point, dist)  — yakın plan (görünüm aracı için)
## Paralaks dioramayı değil kamerayı odak etrafında döndürür: ekranda aynı görünür, gölgeler
## güneşe göre sabit kalır (dönen gölge "titreme" gibi görünmesin diye).

@export var focus: Vector3 = Vector3(2.55, 0.95, 2.0)
@export var yaw_deg: float = 42.0
@export var pitch_deg: float = 31.0
@export var distance: float = 13.2
## Yatay görüş açısı (KEEP_WIDTH: farklı en-boy oranlarında yatay kadraj sabit kalır).
@export var fov_deg: float = 30.5
## Kadraj kaydırma: diorama ekranın üst ~2/3'ünde dursun diye kamera aşağı kaydırılır.
@export var screen_offset: Vector2 = Vector2(0.0, -1.55)
@export var parallax_yaw_deg: float = 4.0
@export var parallax_pitch_deg: float = 2.5
@export var parallax_smooth: float = 6.0

var camera: Camera3D
var attributes: CameraAttributesPractical

var _parallax_target: Vector2 = Vector2.ZERO
var _parallax: Vector2 = Vector2.ZERO
var _pull: float = 0.0
var _pull_tween: Tween
var _focus_override: Vector3 = Vector3.ZERO
var _distance_override: float = 0.0
var _dof_far: bool = true
var _dof_near: bool = true
# --- p2-slice: fiş oturunca küçük kamera sarsıntısı ---
var _shake: float = 0.0
var _shake_time: float = 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = fov_deg
	camera.near = 0.5
	camera.far = 60.0
	attributes = CameraAttributesPractical.new()
	camera.attributes = attributes
	add_child(camera)
	camera.make_current()
	_update_camera()


func set_parallax(v: Vector2) -> void:
	_parallax_target = v.clamp(Vector2(-1, -1), Vector2(1, 1))


func pull_back(duration: float = 3.5) -> void:
	if _pull_tween != null and _pull_tween.is_valid():
		_pull_tween.kill()
	_pull_tween = create_tween()
	_pull_tween.tween_property(self, "_pull", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func finish_pull_back() -> void:
	if _pull_tween != null and _pull_tween.is_valid():
		_pull_tween.kill()
	_pull = 1.0
	_update_camera()


func reset_view() -> void:
	if _pull_tween != null and _pull_tween.is_valid():
		_pull_tween.kill()
	_pull = 0.0
	_focus_override = Vector3.ZERO
	_distance_override = 0.0
	_update_camera()


## Görünüm aracı için yakın plan: odak noktası ve uzaklık (0 = varsayılan).
func frame_focus(point: Vector3, dist: float, yaw: float = NAN, pitch: float = NAN) -> void:
	_focus_override = point
	_distance_override = dist
	if not is_nan(yaw):
		yaw_deg = yaw
	if not is_nan(pitch):
		pitch_deg = pitch
	_update_camera()


## p2-slice: kısa, sönümlü kadraj sarsıntısı (fiş oturması). `amount` ≈ 0..1 (1 ≈ 3 cm görüntü kayması).
func shake(amount: float) -> void:
	_shake = maxf(_shake, clampf(amount, 0.0, 1.5))


## Kalite kademesi alan derinliğini açıp kapatır.
func set_dof(far_on: bool, near_on: bool) -> void:
	_dof_far = far_on
	_dof_near = near_on
	_update_camera()


func _process(delta: float) -> void:
	var k: float = 1.0 - exp(-parallax_smooth * delta)
	var prev: Vector2 = _parallax
	_parallax = _parallax.lerp(_parallax_target, k)
	var shaking: bool = _shake > 0.0
	if shaking:
		_shake = maxf(0.0, _shake - delta * 4.5)
		_shake_time += delta
	if shaking or prev.distance_to(_parallax) > 0.00001 or (_pull_tween != null and _pull_tween.is_running()):
		_update_camera()


func _update_camera() -> void:
	if camera == null:
		return
	var close_up: bool = _distance_override > 0.0
	var f: Vector3 = _focus_override if close_up else focus
	var dist: float = _distance_override if close_up else distance * (1.0 + 0.28 * _pull)
	var yaw: float = deg_to_rad(yaw_deg + _parallax.x * parallax_yaw_deg + 6.0 * _pull)
	var pitch: float = deg_to_rad(pitch_deg + _parallax.y * parallax_pitch_deg + 4.0 * _pull)
	var dir: Vector3 = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	camera.global_position = f + dir * dist
	camera.look_at(f, Vector3.UP)
	camera.fov = fov_deg if not close_up else 26.0
	camera.v_offset = 0.0 if close_up else screen_offset.y * (dist / distance)
	camera.h_offset = 0.0 if close_up else screen_offset.x
	if _shake > 0.0:
		var a: float = _shake * _shake * 0.03
		camera.h_offset += sin(_shake_time * 71.0) * a
		camera.v_offset += cos(_shake_time * 53.0) * a
	if attributes != null:
		# Eğik kaydırma (tilt-shift) hissi: odak düzleminin önü ve arkası hafif bulanık.
		var span: float = 1.4 if not close_up else 0.35
		attributes.dof_blur_far_enabled = _dof_far
		attributes.dof_blur_far_distance = dist + span
		attributes.dof_blur_far_transition = span * 2.5
		attributes.dof_blur_near_enabled = _dof_near
		attributes.dof_blur_near_distance = maxf(0.6, dist - span * 1.2)
		attributes.dof_blur_near_transition = span * 1.6
		attributes.dof_blur_amount = 0.11 if not close_up else 0.06
