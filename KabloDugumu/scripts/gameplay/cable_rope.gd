class_name CableRope
extends Node3D

## PBD/verlet halat + 6 kenarli yumusak tupe mesh.
##
## Koordinat sozlesmesi: noktalar bu dugumun YEREL uzayinda tutulur. CableNode
## kimlik donusumde (pano uzayinda) yasar; setup()/segments()/begin_drag()
## pano (global) uzayi ile yerel uzay arasindaki donusumu kendisi yapar.
## Yercekimi -Y'dir; halat panonun onunde asili kalir (z >= board_surface_z + r*0.9).
##
## Animasyonlar (snap / birakma inisi / yanlis priz sekmasi) step() icinde zaman
## tabanli ilerler: boylece hem duraklatmada hem de birim testlerinde (kare
## islemeden) deterministik calisir.

signal snap_finished()

enum Phase { HELD, DRAGGING, SETTLING, SNAPPING, BOUNCING, FROZEN }

## Halat nokta sayisi. 3.5 m'lik uzun bolumlerde segment ~0.135 m kalsin diye
## 18 yerine 26 secildi (7 kablo * 26 nokta * 8 iterasyon ~ 1500 kisit/kare).
const POINT_COUNT: int = 26
## Mesh icin Catmull-Rom alt ornekleme: 26 nokta -> 76 halka (~0.045 m aralik).
const MESH_SUBDIVISIONS: int = 3
## Tupe uclari kilitleyici ve fis govdesinin icine bu kadar uzatilir (bosluk olmasin).
const MESH_END_EXTENSION: float = 0.02
## PBD kisit iterasyonu (60 Hz'de yeterli sertlik).
const CONSTRAINT_ITERATIONS: int = 8
## Verlet hiz sonumu — sallanma kalmasin, titreme olmasin.
const VELOCITY_DAMPING: float = 0.96
const GRAVITY: float = 9.8
## Tupe kesiti: 6 kenar (mobilde pahali, low-poly).
const TUBE_SIDES: int = 6
## segments() ornek sayisi (temas taramasi icin).
const SEGMENT_SAMPLES: int = 10
const DEFAULT_RADIUS: float = 0.035
## Kablo merkezi panoya bu kadar yaricap yakinlasabilir.
const BOARD_RADIUS_MARGIN: float = 0.9
const DEFAULT_BOARD_SURFACE_Z: float = 0.055
## Fis panoya oturmusken ucu bu kadar onde durur (board_surface_z + bu).
const TIP_BOARD_OFFSET: float = 0.02
const SETTLE_SECONDS: float = 0.12
const SNAP_SECONDS: float = 0.15
const BOUNCE_SECONDS: float = 0.36
## Fis capadan en fazla length*REACH_FACTOR uzaga cekilebilir (fiş uzatilamaz).
const REACH_FACTOR: float = 0.97
const MAX_DELTA: float = 1.0 / 30.0
## Bosta duran kablo mesh'i iki karede bir guncellenir (mobil butce).
const IDLE_MESH_INTERVAL: int = 2
const MESH_EPSILON: float = 0.0005
## Idle'da halka sayisi duser: 26 nokta * 2 = 51 halka (harekette 76).
## Mesh tepe sayisi testi kurulumda TAM kaliteyi (MESH_SUBDIVISIONS) dogrular.
const MESH_IDLE_SUBDIVISIONS: int = 2
## Bu kadar kare boyunca hicbir nokta degismezse PBD uykuya gecer (mobil butce).
const SLEEP_REST_FRAMES: int = 30
## Gorsel salinim: noktalar/fizik DEGISMEZ (temas uretmez); yalniz mesh dugumu
## milimetrik kayar. Kablo "nefes aliyor" gibi okunur (ASMR §16).
const SWAY_AMPLITUDE_X: float = 0.0016
const SWAY_AMPLITUDE_Z: float = 0.0038
const SWAY_SPEED: float = 0.55
const SWAY_DRAG_SCALE: float = 0.25
const EMISSION_ENERGY: float = 0.35
const SHIELDED_EMISSION_ENERGY: float = 0.55
const SHIELD_COLOR: Color = Color(0.3, 0.95, 1.0)
const TUBE_ROUGHNESS: float = 0.35
const SETUP_MIN_LENGTH: float = 0.2
const EPSILON: float = 0.000001

var radius: float = DEFAULT_RADIUS
var board_surface_z: float = DEFAULT_BOARD_SURFACE_Z

var _points: PackedVector3Array = PackedVector3Array()
var _previous: PackedVector3Array = PackedVector3Array()
var _total_length: float = 1.0
var _rest_length: float = 0.1
var _min_z: float = DEFAULT_BOARD_SURFACE_Z
var _tip_min_z: float = DEFAULT_BOARD_SURFACE_Z + TIP_BOARD_OFFSET
var _color: Color = Color.WHITE
var _voltage: int = 0

var _phase: int = Phase.HELD
var _tip_target: Vector3 = Vector3.ZERO
var _animation_time: float = 0.0
var _animation_start: Vector3 = Vector3.ZERO
var _animation_target: Vector3 = Vector3.ZERO
var _bounce_distance: float = 0.0

var _mesh_instance: MeshInstance3D = null
var _material: StandardMaterial3D = null
var _mesh_built_points: PackedVector3Array = PackedVector3Array()
var _step_count: int = 0
var _setup_done: bool = false
var _shielded: bool = false
var _shield_tween: Tween = null
## Yeniden kullanilan mesh tamponlari (SurfaceTool yerine PackedArray'ler):
## her karede yeni mesh/tampon ayirmadan ayni ArrayMesh'e yazilir.
var _array_mesh: ArrayMesh = null
var _mesh_vertices: PackedVector3Array = PackedVector3Array()
var _mesh_normals: PackedVector3Array = PackedVector3Array()
var _mesh_indices: PackedInt32Array = PackedInt32Array()
var _rings: PackedVector3Array = PackedVector3Array()
var _tangents: PackedVector3Array = PackedVector3Array()
var _sides: PackedVector3Array = PackedVector3Array()
var _mesh_subdiv: int = 0
## Uyku: dinlenen halat fizigi islemez (step erken doner).
var _sleeping: bool = false
var _rest_frames: int = 0
## segments() cache: nokta/transform degismedikce yeniden hesaplanmaz.
var _points_version: int = 0
var _segments_version: int = -1
var _segments_xform: Transform3D = Transform3D.IDENTITY
var _segments_toggle: int = 0
var _segments_buffers: Array[PackedVector3Array] = [
	PackedVector3Array(), PackedVector3Array()
]
var _segments_resampled: PackedVector3Array = PackedVector3Array()
## Gorsel salinim fazi (her kablo farkli fazda nefes alir).
var _sway_time: float = 0.0
var _sway_phase: float = 0.0


func _physics_process(delta: float) -> void:
	step(delta)


## Gorsel salinim: mesh node'u milimetrik kayar; fizik noktalarina DOKUNMAZ,
## bu yuzden temas taramasi (segments()) etkilenmez.
func _process(delta: float) -> void:
	if _mesh_instance == null:
		return
	_sway_time += delta
	var scale: float = SWAY_DRAG_SCALE if _phase == Phase.DRAGGING else 1.0
	_mesh_instance.position = Vector3(
		sin(_sway_time * SWAY_SPEED + _sway_phase) * SWAY_AMPLITUDE_X,
		sin(_sway_time * SWAY_SPEED * 0.61 + _sway_phase * 1.7) * SWAY_AMPLITUDE_X * 0.5,
		sin(_sway_time * SWAY_SPEED * 0.83 + _sway_phase) * SWAY_AMPLITUDE_Z) * scale


## Uyuyan halati uyandirir: her durum degisikliginde cagrilir.
func _wake() -> void:
	_sleeping = false
	_rest_frames = 0


## Fizigi ilerletir. Normalde _physics_process cagirir; testler dogrudan cagirir.
func step(delta: float) -> void:
	if not _setup_done:
		return
	var dt: float = clampf(delta, 0.0, MAX_DELTA)
	if dt <= 0.0:
		return
	_step_count += 1
	if _phase == Phase.FROZEN:
		return
	if _sleeping:
		return
	_animate_tip(dt)
	_integrate(dt)
	for _iteration: int in CONSTRAINT_ITERATIONS:
		_solve_constraints()
	_apply_bounds()
	_update_mesh()


## Noktalari, toplam uzunlugu length'e esitlenmis sekilde kurar.
## points'in polyline uzunlugu length'ten farkliysa uclar sabit tutulup ara
## noktalar olceklenir; boylece nivel basinda gorsel "pop" olmaz.
func setup(points: PackedVector3Array, length: float, color: Color, voltage: int) -> void:
	radius = _resolve_radius()
	board_surface_z = _resolve_board_surface_z()
	_min_z = board_surface_z + radius * BOARD_RADIUS_MARGIN
	_tip_min_z = board_surface_z + TIP_BOARD_OFFSET
	_total_length = maxf(length, SETUP_MIN_LENGTH)
	_color = color
	_voltage = voltage
	_shielded = false
	if _shield_tween != null and _shield_tween.is_valid():
		_shield_tween.kill()
	_ensure_visuals()
	_apply_material_color()
	var local_points: PackedVector3Array = _to_local_points(points)
	_points = _normalize_points(local_points, _total_length)
	# KRITIK: segment rest uzunlugu spec.length'ten turetIlir; sabit 0.1 kalirsa
	# uzun bolumlerde halat fiziksel olarak 1.7 m'ye kisilir ve fis prize ulasamaz.
	_rest_length = _total_length / float(maxi(1, _points.size() - 1))
	_phase = Phase.HELD
	_animation_time = 0.0
	_settle_setup_geometry()
	_previous = _points.duplicate()
	_tip_target = _points[_points.size() - 1]
	_setup_done = true
	_step_count = 0
	_points_version += 1
	_wake()
	if _sway_phase == 0.0:
		_sway_phase = float(get_instance_id() % 628) * 0.01
	_rebuild_mesh()


## Ayni uzunluk/renkle halati yeniden sekillendirir (bolum yeniden baslatma).
func reset_shape(points: PackedVector3Array) -> void:
	if not _setup_done:
		setup(points, maxf(_total_length, SETUP_MIN_LENGTH), _color, _voltage)
		return
	_points = _normalize_points(_to_local_points(points), _total_length)
	_rest_length = _total_length / float(maxi(1, _points.size() - 1))
	_phase = Phase.HELD
	_animation_time = 0.0
	_settle_setup_geometry()
	_previous = _points.duplicate()
	_tip_target = _points[_points.size() - 1]
	_step_count = 0
	_points_version += 1
	_wake()
	_rebuild_mesh()


## Son noktayi kinematik yapar ve hedefe tasir. Hedef, capa etrafindaki
## length*REACH_FACTOR kuresine kirpilir (fis uzatilamaz).
func begin_drag(target: Vector3) -> void:
	if not _setup_done or _phase == Phase.FROZEN:
		return
	var local_target: Vector3 = _clamp_to_reach(_to_local_point(target))
	local_target.z = maxf(local_target.z, _tip_min_z)
	_phase = Phase.DRAGGING
	_animation_time = 0.0
	_wake()
	_set_tip(local_target)
	_rebuild_mesh()


## Surukleme hedefini gunceller (ayni kirpma kurallari).
func update_drag(target: Vector3) -> void:
	if not _setup_done or _phase == Phase.FROZEN:
		return
	if _phase != Phase.DRAGGING:
		_phase = Phase.DRAGGING
		_animation_time = 0.0
		_wake()
	var local_target: Vector3 = _clamp_to_reach(_to_local_point(target))
	local_target.z = maxf(local_target.z, _tip_min_z)
	_set_tip(local_target)


## locked=false: fis bulundugu yerde panonun onunde "miknatisla" asili kalir,
## dibe dogru yumusak iner. locked=true: cagiran snap_to() ile prize oturtur.
func end_drag(locked: bool) -> void:
	if _phase != Phase.DRAGGING:
		return
	if locked:
		_phase = Phase.HELD
		_tip_target = _points[_points.size() - 1]
		return
	_animation_start = _points[_points.size() - 1]
	_animation_target = Vector3(_animation_start.x, _animation_start.y, _tip_min_z)
	_animation_time = 0.0
	_phase = Phase.SETTLING
	_wake()


## Fis (son nokta) yumusak bir yayla target'a girer; bitince noktalar donar.
func snap_to(target: Vector3) -> void:
	if not _setup_done:
		return
	var local_target: Vector3 = _to_local_point(target)
	_animation_start = _points[_points.size() - 1]
	_animation_target = local_target
	_animation_time = 0.0
	_tip_target = _animation_start
	_phase = Phase.SNAPPING
	_wake()


## Yanlis priz: fis distance kadar yukari sekip panoya geri oturur.
func bounce_tip_up(distance: float) -> void:
	if not _setup_done or _phase == Phase.FROZEN:
		return
	_animation_start = _points[_points.size() - 1]
	_animation_target = Vector3(_animation_start.x, _animation_start.y, _tip_min_z)
	_bounce_distance = maxf(distance, 0.0)
	_animation_time = 0.0
	_phase = Phase.BOUNCING
	_wake()


## Sureli animasyonu beklemeden sonuna atlar (test/QA ve snap aninda bitirme).
func finish_animations() -> void:
	if not _setup_done:
		return
	_wake()
	match _phase:
		Phase.SETTLING, Phase.BOUNCING:
			_set_tip(_animation_target)
			_phase = Phase.HELD
			_rebuild_mesh()
		Phase.SNAPPING:
			_set_tip(_animation_target)
			_finish_snap()


func is_dragging() -> bool:
	return _phase == Phase.DRAGGING


## Kalkan gorunumu: emission rengi/enerjisi cyan'a kayar.
func set_shielded(active: bool) -> void:
	_shielded = active
	if _material == null:
		return
	var target_color: Color = SHIELD_COLOR if active else _color
	var target_energy: float = SHIELDED_EMISSION_ENERGY if active else EMISSION_ENERGY
	if _shield_tween != null and _shield_tween.is_valid():
		_shield_tween.kill()
	if not is_inside_tree():
		_material.emission = target_color
		_material.emission_energy_multiplier = target_energy
		return
	_shield_tween = create_tween()
	_shield_tween.set_parallel(true)
	_shield_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_shield_tween.tween_property(_material, "emission", target_color, 0.18)
	_shield_tween.tween_property(_material, "emission_energy_multiplier", target_energy, 0.18)


func is_shielded() -> bool:
	return _shielded


## Temas taramasi icin dunya (pano) uzayinda 10 ornek nokta.
## Nokta/transform degismediyse cache'ten doner (uyuyan kabloda sifir is).
## Donen dizi SALT OKUNUR kabul edilmelidir; iki tampon arasinda ping-pong yapilir
## ki onceki cagrinin dizisi sonradan degismesin.
func segments() -> PackedVector3Array:
	if _points.size() < 2:
		return PackedVector3Array()
	var xform: Transform3D = Transform3D.IDENTITY
	if is_inside_tree():
		xform = global_transform
	if _segments_version == _points_version and _segments_xform.is_equal_approx(xform):
		return _segments_buffers[_segments_toggle]
	_segments_resampled = CableMath.resample(_points, SEGMENT_SAMPLES)
	_segments_toggle = 1 - _segments_toggle
	var target: PackedVector3Array = _segments_buffers[_segments_toggle]
	target.resize(_segments_resampled.size())
	for i: int in _segments_resampled.size():
		target[i] = xform * _segments_resampled[i]
	_segments_buffers[_segments_toggle] = target
	_segments_version = _points_version
	_segments_xform = xform
	return target


## Mevcut uzunluk / toplam uzunluk (0..1) — gerilme gostergesi.
func taut_ratio() -> float:
	if _total_length <= EPSILON:
		return 0.0
	return clampf(CableMath.polyline_length(_points) / _total_length, 0.0, 1.0)


func tip_position() -> Vector3:
	if _points.is_empty():
		return Vector3.ZERO
	return _points[_points.size() - 1]


func tip_world_position() -> Vector3:
	return _to_world_point(tip_position())


func point_positions() -> PackedVector3Array:
	return _points.duplicate()


func point_count() -> int:
	return _points.size()


func rest_length() -> float:
	return _rest_length


func total_length() -> float:
	return _total_length


func voltage() -> int:
	return _voltage


func is_frozen() -> bool:
	return _phase == Phase.FROZEN


## QA/gorsel dogrulama: tupe mesh'ini tasiyan dugum.
func mesh_instance() -> MeshInstance3D:
	return _mesh_instance


func shape_phase() -> int:
	return _phase


# --- fizik ---------------------------------------------------------------

func _animate_tip(dt: float) -> void:
	match _phase:
		Phase.SETTLING:
			_animation_time += dt
			var progress: float = clampf(_animation_time / SETTLE_SECONDS, 0.0, 1.0)
			var eased: float = progress * progress * (3.0 - 2.0 * progress)
			_set_tip(_animation_start.lerp(_animation_target, eased))
			if progress >= 1.0:
				_set_tip(_animation_target)
				_phase = Phase.HELD
		Phase.SNAPPING:
			_animation_time += dt
			var progress: float = clampf(_animation_time / SNAP_SECONDS, 0.0, 1.0)
			_set_tip(_animation_start.lerp(_animation_target, _ease_out_back(progress)))
			if progress >= 1.0:
				_set_tip(_animation_target)
				_finish_snap()
		Phase.BOUNCING:
			_animation_time += dt
			var progress: float = clampf(_animation_time / BOUNCE_SECONDS, 0.0, 1.0)
			var base: Vector3 = _animation_start.lerp(_animation_target, progress)
			_set_tip(base + Vector3.UP * (_bounce_distance * sin(PI * progress)))
			if progress >= 1.0:
				_set_tip(_animation_target)
				_phase = Phase.HELD
		_:
			pass


func _integrate(dt: float) -> void:
	_points_version += 1
	var gravity: Vector3 = _local_gravity() * dt * dt
	var last: int = _points.size() - 1
	for i: int in range(1, _points.size()):
		if i == last:
			_points[i] = _tip_target
			_previous[i] = _tip_target
			continue
		var velocity: Vector3 = (_points[i] - _previous[i]) * VELOCITY_DAMPING
		_previous[i] = _points[i]
		_points[i] = _points[i] + velocity + gravity


func _solve_constraints() -> void:
	var last: int = _points.size() - 1
	for i: int in last:
		var delta: Vector3 = _points[i + 1] - _points[i]
		var distance: float = delta.length()
		if distance < EPSILON:
			continue
		var difference: float = (distance - _rest_length) / distance
		var inverse_a: float = 0.0 if i == 0 else 1.0
		var inverse_b: float = 0.0 if i + 1 == last else 1.0
		var inverse_total: float = inverse_a + inverse_b
		if inverse_total <= 0.0:
			continue
		_points[i] += delta * (difference * inverse_a / inverse_total)
		_points[i + 1] -= delta * (difference * inverse_b / inverse_total)


func _apply_bounds() -> void:
	var last: int = _points.size() - 1
	for i: int in range(1, _points.size()):
		if i == last:
			# Snap/priz oturmasinda fis panoya gomulebilir; diger durumlarda onunde kalir.
			if _phase != Phase.SNAPPING and _phase != Phase.FROZEN:
				_points[i].z = maxf(_points[i].z, _tip_min_z)
		else:
			_points[i].z = maxf(_points[i].z, _min_z)


## Semtin ilk kurulumunda da kisitlari cozer: boylece segment uzunluklari
## dogrudan rest uzunlugunda baslar (test: ortalama uzunluk ±%10).
func _settle_setup_geometry() -> void:
	for _iteration: int in CONSTRAINT_ITERATIONS:
		_solve_constraints()
	_apply_bounds()


# --- sinir/kisit yardimcilari --------------------------------------------

func _set_tip(position: Vector3) -> void:
	if _points.is_empty():
		return
	var last: int = _points.size() - 1
	_tip_target = position
	_points[last] = position
	_previous[last] = position
	_points_version += 1


func _clamp_to_reach(target: Vector3) -> Vector3:
	if _points.is_empty():
		return target
	var anchor: Vector3 = _points[0]
	var max_reach: float = _total_length * REACH_FACTOR
	var offset: Vector3 = target - anchor
	var distance: float = offset.length()
	if distance <= max_reach or distance < EPSILON:
		return target
	return anchor + offset * (max_reach / distance)


func _finish_snap() -> void:
	var last: int = _points.size() - 1
	_points[last] = _animation_target
	_previous[last] = _animation_target
	_tip_target = _animation_target
	_phase = Phase.FROZEN
	_rebuild_mesh()
	snap_finished.emit()


func _ease_out_back(progress: float) -> float:
	var shifted: float = progress - 1.0
	return 1.0 + 2.70158 * shifted * shifted * shifted + 1.70158 * shifted * shifted


func _local_gravity() -> Vector3:
	if is_inside_tree():
		var basis: Basis = global_transform.basis
		if not basis.is_equal_approx(Basis.IDENTITY):
			return (basis.inverse() * Vector3.DOWN * GRAVITY)
	return Vector3.DOWN * GRAVITY


# --- nokta normalizasyonu ------------------------------------------------

func _normalize_points(points: PackedVector3Array, target_length: float) -> PackedVector3Array:
	var resampled: PackedVector3Array = CableMath.resample(points, POINT_COUNT)
	if resampled.size() < POINT_COUNT:
		# Dejenere girdi (0-1 nokta): panonun onunde duz bir hat kur.
		var origin: Vector3 = Vector3.ZERO
		var direction: Vector3 = Vector3.DOWN
		if points.size() > 0:
			origin = points[0]
		if points.size() > 1:
			var span: Vector3 = points[points.size() - 1] - points[0]
			if span.length_squared() > EPSILON:
				direction = span.normalized()
		resampled = PackedVector3Array()
		for i: int in POINT_COUNT:
			resampled.append(origin + direction * (target_length * float(i) / float(POINT_COUNT - 1)))
	var start: Vector3 = resampled[0]
	var end: Vector3 = resampled[resampled.size() - 1]
	var chord: float = start.distance_to(end)
	var best: PackedVector3Array = _scale_deviations(resampled, 1.0, start, end)
	if chord < target_length * 0.999:
		var best_error: float = absf(CableMath.polyline_length(best) - target_length)
		var low: float = 0.0
		var high: float = 20.0
		for _iteration: int in 28:
			var middle: float = (low + high) * 0.5
			var candidate: PackedVector3Array = _scale_deviations(resampled, middle, start, end)
			var candidate_error: float = absf(CableMath.polyline_length(candidate) - target_length)
			if candidate_error < best_error:
				best_error = candidate_error
				best = candidate
			if CableMath.polyline_length(candidate) < target_length:
				low = middle
			else:
				high = middle
	# Panonun onunde kalma kurali (uc fis oldugu icin daha yakin durabilir).
	for i: int in best.size():
		if i == best.size() - 1:
			best[i].z = maxf(best[i].z, _tip_min_z)
		else:
			best[i].z = maxf(best[i].z, _min_z)
	return best


func _scale_deviations(base_points: PackedVector3Array, scale: float,
		start: Vector3, end: Vector3) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	var count: int = base_points.size()
	for i: int in count:
		var t: float = float(i) / float(count - 1)
		var chord_point: Vector3 = start.lerp(end, t)
		var deviation: Vector3 = base_points[i] - chord_point
		result.append(chord_point + deviation * scale)
	return result


# --- mesh ----------------------------------------------------------------

func _ensure_visuals() -> void:
	if _mesh_instance != null:
		return
	_material = StandardMaterial3D.new()
	_material.albedo_color = _color
	_material.roughness = TUBE_ROUGHNESS
	_material.metallic = 0.05
	_material.emission_enabled = true
	_material.emission = _color
	_material.emission_energy_multiplier = EMISSION_ENERGY
	# Kure ince ve cift tarafli gorunur olsun diye culling kapali (108 tepe, mobilde ucuz).
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "RopeMesh"
	_mesh_instance.material_override = _material
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)
	_array_mesh = ArrayMesh.new()
	_mesh_instance.mesh = _array_mesh
	set_process(true)


func _apply_material_color() -> void:
	if _material == null:
		return
	_material.albedo_color = _color
	if _shielded:
		_material.emission = SHIELD_COLOR
		_material.emission_energy_multiplier = SHIELDED_EMISSION_ENERGY
	else:
		_material.emission = _color
		_material.emission_energy_multiplier = EMISSION_ENERGY


## Olay-tabanli mesh tazeleme: noktalar degismediyse mesh'e dokunulmaz;
## hareketli halat kare basina en fazla 1 kez, sabit halat 30 Hz'de bir kurulur.
## Hic degismeyen halat SLEEP_REST_FRAMES sonra uyur (fizik de durur).
func _update_mesh() -> void:
	if _mesh_instance == null:
		return
	var active: bool = _phase != Phase.HELD
	var desired_subdiv: int = MESH_SUBDIVISIONS if active else MESH_IDLE_SUBDIVISIONS
	if not _points_changed():
		if _phase == Phase.HELD:
			if _mesh_subdiv != desired_subdiv:
				# Animasyon bitti: tek seferlik alt orneklemeye gec (mobil butce).
				_rebuild_mesh(desired_subdiv)
				return
			_rest_frames += 1
			if _rest_frames >= SLEEP_REST_FRAMES:
				_sleeping = true
		return
	_rest_frames = 0
	if not active and (_step_count % IDLE_MESH_INTERVAL) != 0:
		return
	_rebuild_mesh(desired_subdiv)


func _points_changed() -> bool:
	if _mesh_built_points.size() != _points.size():
		return true
	for i: int in _points.size():
		if _points[i].distance_squared_to(_mesh_built_points[i]) > MESH_EPSILON * MESH_EPSILON:
			return true
	return false


## Tupe mesh'ini yeniden kullanilabilir PackedArray tamponlarina yazar.
## SurfaceTool'un tepe-basina metod cagrisi ve her karede yeni ArrayMesh
## ayirmasi yerine tek bir ArrayMesh'in yuzeyi tazelenir (mobil GC baskisi yok).
func _rebuild_mesh(subdiv: int = MESH_SUBDIVISIONS) -> void:
	if _mesh_instance == null or _array_mesh == null or _points.size() < 2:
		return
	var subdivisions: int = maxi(1, subdiv)
	_build_smoothed_rings(subdivisions)
	var ring_count: int = _rings.size()
	if ring_count < 2:
		return
	_compute_ring_tangents()
	_parallel_transport_sides()
	var vertex_count: int = ring_count * TUBE_SIDES + 2
	_mesh_vertices.resize(vertex_count)
	_mesh_normals.resize(vertex_count)
	_mesh_indices.resize(ring_count * TUBE_SIDES * 6)
	var cursor: int = 0
	for i: int in ring_count:
		var tangent: Vector3 = _tangents[i]
		var side: Vector3 = _sides[i]
		# up her halkada tegete gore yeniden kurulur; global sabit eksen yok.
		var up: Vector3 = tangent.cross(side).normalized()
		for side_index: int in TUBE_SIDES:
			var angle: float = TAU * float(side_index) / float(TUBE_SIDES)
			var normal: Vector3 = side * cos(angle) + up * sin(angle)
			_mesh_normals[cursor] = normal
			_mesh_vertices[cursor] = _rings[i] + normal * radius
			cursor += 1
	var center_start: int = ring_count * TUBE_SIDES
	var center_end: int = center_start + 1
	_mesh_normals[center_start] = -_tangents[0]
	_mesh_vertices[center_start] = _rings[0]
	_mesh_normals[center_end] = _tangents[ring_count - 1]
	_mesh_vertices[center_end] = _rings[ring_count - 1]
	var index_cursor: int = 0
	for i: int in ring_count - 1:
		for side_index: int in TUBE_SIDES:
			var next_side: int = (side_index + 1) % TUBE_SIDES
			var a: int = i * TUBE_SIDES + side_index
			var b: int = i * TUBE_SIDES + next_side
			var c: int = (i + 1) * TUBE_SIDES + side_index
			var d: int = (i + 1) * TUBE_SIDES + next_side
			_mesh_indices[index_cursor] = a
			_mesh_indices[index_cursor + 1] = c
			_mesh_indices[index_cursor + 2] = b
			_mesh_indices[index_cursor + 3] = b
			_mesh_indices[index_cursor + 4] = c
			_mesh_indices[index_cursor + 5] = d
			index_cursor += 6
	var last_ring: int = (ring_count - 1) * TUBE_SIDES
	for side_index: int in TUBE_SIDES:
		var next_side: int = (side_index + 1) % TUBE_SIDES
		_mesh_indices[index_cursor] = center_start
		_mesh_indices[index_cursor + 1] = side_index
		_mesh_indices[index_cursor + 2] = next_side
		_mesh_indices[index_cursor + 3] = center_end
		_mesh_indices[index_cursor + 4] = last_ring + next_side
		_mesh_indices[index_cursor + 5] = last_ring + side_index
		index_cursor += 6
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _mesh_vertices
	arrays[Mesh.ARRAY_NORMAL] = _mesh_normals
	arrays[Mesh.ARRAY_INDEX] = _mesh_indices
	_array_mesh.clear_surfaces()
	_array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_subdiv = subdivisions
	_mesh_built_points = _points.duplicate()


## 26 kontrol noktasini Catmull-Rom ile subdivisions katina cikarir (yerinde).
## Iki ucu kilitleyici/fis govdesinin icine uzatir: tupe ucu boslukta kalmaz.
func _build_smoothed_rings(subdivisions: int) -> void:
	var count: int = _points.size()
	var ring_count: int = (count - 1) * subdivisions + 1
	_rings.resize(ring_count)
	if count < 2:
		return
	var cursor: int = 0
	for i: int in count - 1:
		var p0: Vector3 = _points[maxi(i - 1, 0)]
		var p1: Vector3 = _points[i]
		var p2: Vector3 = _points[i + 1]
		var p3: Vector3 = _points[mini(i + 2, count - 1)]
		for step: int in subdivisions:
			var t: float = float(step) / float(subdivisions)
			_rings[cursor] = _catmull_rom(p0, p1, p2, p3, t)
			cursor += 1
	_rings[ring_count - 1] = _points[count - 1]
	var first_tangent: Vector3 = (_rings[1] - _rings[0]).normalized()
	_rings[0] = _rings[0] - first_tangent * MESH_END_EXTENSION
	var last_index: int = ring_count - 1
	var last_tangent: Vector3 = (_rings[last_index] - _rings[last_index - 1]).normalized()
	_rings[last_index] = _rings[last_index] + last_tangent * MESH_END_EXTENSION


func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2: float = t * t
	var t3: float = t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


## Halka tegetlerini yeniden kullanilan tampona yazar.
func _compute_ring_tangents() -> void:
	var count: int = _rings.size()
	_tangents.resize(count)
	if count < 2:
		return
	for i: int in count:
		var tangent: Vector3 = Vector3.ZERO
		if i == 0:
			tangent = _rings[1] - _rings[0]
		elif i == count - 1:
			tangent = _rings[count - 1] - _rings[count - 2]
		else:
			tangent = _rings[i + 1] - _rings[i - 1]
		if tangent.length_squared() < EPSILON:
			tangent = Vector3.DOWN
		_tangents[i] = tangent.normalized()


## Halka cercevelerini paralel tasima ile kurar: her normal bir onceki normalin
## tegete izdusumu cikarilip normalize edilir. Global up vektor YOK; boylece
## silüette 180 derece donme / serit gorunumu olusmaz.
## Halka cercevelerini paralel tasima ile yeniden kullanilan tampona yazar:
## her normal bir onceki normalin tegete izdusumu cikarilip normalize edilir.
## Global up vektor YOK; boylece silüette 180 derece donme olusmaz.
func _parallel_transport_sides() -> void:
	var count: int = _tangents.size()
	_sides.resize(count)
	if count == 0:
		return
	var reference: Vector3 = Vector3(0.0, 1.0, 0.0)
	if absf(_tangents[0].dot(reference)) > 0.9:
		reference = Vector3(1.0, 0.0, 0.0)
	var side: Vector3 = _tangents[0].cross(reference).normalized()
	_sides[0] = side
	for i: int in range(1, count):
		var tangent: Vector3 = _tangents[i]
		var transported: Vector3 = side - tangent * side.dot(tangent)
		if transported.length_squared() < 0.000001:
			var fallback_reference: Vector3 = Vector3(1.0, 0.0, 0.0)
			if absf(tangent.dot(fallback_reference)) > 0.9:
				fallback_reference = Vector3(0.0, 1.0, 0.0)
			transported = tangent.cross(fallback_reference)
		side = transported.normalized()
		_sides[i] = side


# --- uzay donusumleri ----------------------------------------------------

func _to_local_point(point: Vector3) -> Vector3:
	if is_inside_tree():
		return global_transform.affine_inverse() * point
	return point


func _to_local_points(points: PackedVector3Array) -> PackedVector3Array:
	var result: PackedVector3Array = PackedVector3Array()
	if not is_inside_tree():
		return points.duplicate()
	var inverse: Transform3D = global_transform.affine_inverse()
	for point: Vector3 in points:
		result.append(inverse * point)
	return result


func _to_world_point(point: Vector3) -> Vector3:
	if is_inside_tree():
		return global_transform * point
	return point


# --- denge tablosu -------------------------------------------------------

func _resolve_radius() -> float:
	var raw: Variant = _board_setting("cable_radius", DEFAULT_RADIUS)
	if raw is float or raw is int:
		return maxf(0.005, float(raw))
	return DEFAULT_RADIUS


func _resolve_board_surface_z() -> float:
	var raw: Variant = _board_setting("board_surface_z", DEFAULT_BOARD_SURFACE_Z)
	if raw is float or raw is int:
		return float(raw)
	return DEFAULT_BOARD_SURFACE_Z


func _board_setting(key: String, fallback: Variant) -> Variant:
	var balance: Dictionary = GameData.table("balance")
	var raw_board: Variant = balance.get("board", {})
	if raw_board is Dictionary:
		return (raw_board as Dictionary).get(key, fallback)
	return fallback
