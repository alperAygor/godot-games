class_name DayLight
extends Node

## Dört gün dilimi ışık atmosferi ve geçişleri (sabah, öğle, akşam, gece).
##
## Kamu arayüzü (oyun işçisi bunları çağırır):
##   set_slice(slice: int, duration: float)   — 0 sabah, 1 öğle, 2 akşam, 3 gece; duration 0 = anında
##   flicker(strength: float, duration: float) — hat sınıra yaklaşınca iç lambalar titrer (0..1)
##   blackout(recover_after: float)            — sigorta attı: anlık karanlık, sonra toparlanma
##   play_win(duration: float)                 — kazanma: gece, ışıklar tek tek yanar, kamera geri çekilir
##   skip_win()                                — kazanma sahnesini sona atla (dokununca)
## Sinyaller: slice_changed(slice), blackout_finished, win_finished
##
## Işık düğümleri RoomView tarafından `setup()` ile verilir. Cihazlar "priz_mains" grubundaysa
## `set_mains(factor: float)` çağrısıyla şebeke gücü (karartma) iletilir.

signal slice_changed(slice: int)
signal blackout_finished
signal win_finished

enum Slice { MORNING, NOON, EVENING, NIGHT }

const SLICE_COUNT: int = 4


## Bir dilimin tüm ışık değerleri. Geçişte iki ön ayar arasında doğrusal karışım yapılır.
class Preset:
	var sun_dir: Vector3 = Vector3(0.0, -1.0, 1.0)
	var sun_color: Color = Color.WHITE
	var sun_energy: float = 1.0
	var fill_color: Color = Color.WHITE
	var fill_energy: float = 0.3
	var ambient_color: Color = Color(0.5, 0.5, 0.5)
	var ambient_energy: float = 0.5
	var bg_color: Color = Color(0.2, 0.2, 0.2)
	var bg_top: Color = Color(0.4, 0.4, 0.4)
	var sky_top: Color = Color(0.4, 0.6, 0.9)
	var sky_horizon: Color = Color(0.9, 0.9, 0.9)
	var far_color: Color = Color(0.6, 0.6, 0.7)
	var near_color: Color = Color(0.5, 0.5, 0.55)
	var tree_color: Color = Color(0.25, 0.35, 0.25)
	var window_sun_color: Color = Color(1.0, 0.95, 0.85)
	var window_sun_pos: Vector2 = Vector2(0.3, 0.3)
	var window_lights: float = 0.0
	var stars: float = 0.0
	var sky_brightness: float = 1.0
	var interior: float = 0.0
	var shaft_color: Color = Color(1.0, 0.9, 0.7)
	var shaft_intensity: float = 0.0
	var exposure: float = 1.0
	var glow: float = 0.6

	func lerp_to(b: Preset, t: float) -> Preset:
		var r: Preset = Preset.new()
		r.sun_dir = sun_dir.slerp(b.sun_dir, t).normalized()
		r.sun_color = sun_color.lerp(b.sun_color, t)
		r.sun_energy = lerpf(sun_energy, b.sun_energy, t)
		r.fill_color = fill_color.lerp(b.fill_color, t)
		r.fill_energy = lerpf(fill_energy, b.fill_energy, t)
		r.ambient_color = ambient_color.lerp(b.ambient_color, t)
		r.ambient_energy = lerpf(ambient_energy, b.ambient_energy, t)
		r.bg_color = bg_color.lerp(b.bg_color, t)
		r.bg_top = bg_top.lerp(b.bg_top, t)
		r.sky_top = sky_top.lerp(b.sky_top, t)
		r.sky_horizon = sky_horizon.lerp(b.sky_horizon, t)
		r.far_color = far_color.lerp(b.far_color, t)
		r.near_color = near_color.lerp(b.near_color, t)
		r.tree_color = tree_color.lerp(b.tree_color, t)
		r.window_sun_color = window_sun_color.lerp(b.window_sun_color, t)
		r.window_sun_pos = window_sun_pos.lerp(b.window_sun_pos, t)
		r.window_lights = lerpf(window_lights, b.window_lights, t)
		r.stars = lerpf(stars, b.stars, t)
		r.sky_brightness = lerpf(sky_brightness, b.sky_brightness, t)
		r.interior = lerpf(interior, b.interior, t)
		r.shaft_color = shaft_color.lerp(b.shaft_color, t)
		r.shaft_intensity = lerpf(shaft_intensity, b.shaft_intensity, t)
		r.exposure = lerpf(exposure, b.exposure, t)
		r.glow = lerpf(glow, b.glow, t)
		return r


## İç mekân ışığı: düğüm + o ışığın tam enerjisi (gece değeri).
class InteriorLight:
	var light: Light3D
	var full_energy: float
	var gate: float = 1.0  # kazanma sahnesinde tek tek açmak için 0..1

	func _init(l: Light3D, e: float) -> void:
		light = l
		full_energy = e


var sun: DirectionalLight3D
var fill: DirectionalLight3D
var environment: Environment
var sky_material: ShaderMaterial
## Arka fon gökyüzü malzemesi (RoomView verir).
var backdrop: ShaderMaterial
var shafts: LightShafts
## Güneş lekesinden sekme (ucuz tek sekmeli GI taklidi değil, ışık kaynağı: lekenin üstünde gölgesiz yumuşak nokta ışık).
var bounce: OmniLight3D
## Pencere iç yüz merkezi (oda yerel) — sekme ışığının leke hesabı için.
var window_center: Vector3 = Vector3(4.3, 1.6, 0.0)
var camera_rig: DioramaCamera
var interior_lights: Array[InteriorLight] = []
## Emisyonu iç ışıkla birlikte açılan malzemeler (raf şeridi vb.) ve tam enerjileri.
var interior_emissives: Array[StandardMaterial3D] = []
var interior_emissive_energy: Array[float] = []

var current_slice: int = Slice.NOON
var _presets: Array[Preset] = []
var _state: Preset
var _from: Preset
var _to: Preset
var _blend_tween: Tween
var _mains: float = 1.0
var _flicker_amount: float = 0.0
var _flicker_time_left: float = 0.0
var _flicker_phase: float = 0.0
var _win_tween: Tween
var _win_active: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	_presets = _make_presets()
	_state = _presets[current_slice]


## RoomView kurulumdan sonra çağırır.
func setup(p_sun: DirectionalLight3D, p_fill: DirectionalLight3D, p_env: Environment, p_sky: ShaderMaterial,
		p_shafts: LightShafts, p_camera: DioramaCamera) -> void:
	sun = p_sun
	fill = p_fill
	environment = p_env
	sky_material = p_sky
	shafts = p_shafts
	camera_rig = p_camera
	_apply(_state)


func add_interior_light(light: Light3D, full_energy: float) -> void:
	interior_lights.append(InteriorLight.new(light, full_energy))
	_apply(_state)


func add_interior_emissive(mat: StandardMaterial3D, full_energy: float) -> void:
	interior_emissives.append(mat)
	interior_emissive_energy.append(full_energy)
	_apply(_state)


## Dilimi değiştirir. duration saniye içinde yumuşak geçiş (0 = anında).
func set_slice(slice: int, duration: float = 1.6) -> void:
	slice = clampi(slice, 0, SLICE_COUNT - 1)
	current_slice = slice
	if _blend_tween != null and _blend_tween.is_valid():
		_blend_tween.kill()
	_from = _state
	_to = _presets[slice]
	if duration <= 0.0 or not is_inside_tree():
		_state = _to
		_apply(_state)
	else:
		_blend_tween = create_tween()
		_blend_tween.tween_method(_blend_step, 0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	slice_changed.emit(slice)


func get_slice() -> int:
	return current_slice


## Sınıra yaklaşan hat: iç lambalar `duration` saniye titrer. strength 0..1.
func flicker(strength: float, duration: float = 1.2) -> void:
	_flicker_amount = clampf(strength, 0.0, 1.0)
	_flicker_time_left = maxf(duration, _flicker_time_left)


## Sigorta attı: anlık karartma; recover_after saniye sonra lambalar titreyerek geri gelir.
func blackout(recover_after: float = 1.4) -> void:
	_set_mains(0.0)
	var t: Tween = create_tween()
	t.tween_interval(recover_after)
	t.tween_callback(func() -> void: _set_mains(0.35))
	t.tween_interval(0.07)
	t.tween_callback(func() -> void: _set_mains(0.0))
	t.tween_interval(0.12)
	t.tween_method(_set_mains, 0.2, 1.0, 0.6).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void: blackout_finished.emit())


## Kazanma: gece dilimine geçer, ışıklar tek tek yanar, kamera yavaşça geri çekilir.
func play_win(duration: float = 3.6) -> void:
	_win_active = true
	set_slice(Slice.NIGHT, minf(1.0, duration * 0.3))
	for il: InteriorLight in interior_lights:
		il.gate = 0.0
	if sky_material != null:
		sky_material.set_shader_parameter("window_lights", 0.0)
	_win_tween = create_tween()
	_win_tween.tween_interval(duration * 0.15)
	var step: float = (duration * 0.6) / maxf(1.0, float(interior_lights.size() + 1))
	for il: InteriorLight in interior_lights:
		_win_tween.tween_method(func(v: float) -> void: _set_gate(il, v), 0.0, 1.0, step * 1.4)
		_win_tween.tween_interval(step * 0.2)
	_win_tween.tween_method(_set_window_lights_override, 0.0, 1.0, step * 2.0)
	if camera_rig != null:
		camera_rig.pull_back(duration)
	_win_tween.tween_interval(maxf(0.0, duration * 0.2))
	_win_tween.tween_callback(_finish_win)


func skip_win() -> void:
	if not _win_active:
		return
	if _win_tween != null and _win_tween.is_valid():
		_win_tween.kill()
	if _blend_tween != null and _blend_tween.is_valid():
		_blend_tween.kill()
	_state = _presets[Slice.NIGHT]
	for il: InteriorLight in interior_lights:
		il.gate = 1.0
	_apply(_state)
	if camera_rig != null:
		camera_rig.finish_pull_back()
	_finish_win()


func is_win_playing() -> bool:
	return _win_active


func _finish_win() -> void:
	if not _win_active:
		return
	_win_active = false
	_apply(_state)
	win_finished.emit()


func _set_gate(il: InteriorLight, v: float) -> void:
	il.gate = v
	_apply(_state)


func _set_window_lights_override(v: float) -> void:
	if sky_material != null:
		sky_material.set_shader_parameter("window_lights", _state.window_lights * v)


func _set_mains(v: float) -> void:
	_mains = v
	get_tree().call_group("priz_mains", "set_mains", v)
	_apply(_state)


func _blend_step(t: float) -> void:
	_state = _from.lerp_to(_to, t)
	_apply(_state)


func _process(delta: float) -> void:
	if _flicker_time_left > 0.0:
		_flicker_time_left -= delta
		_flicker_phase += delta
		_apply(_state)
		if _flicker_time_left <= 0.0:
			_flicker_amount = 0.0
			_apply(_state)


func _flicker_factor() -> float:
	if _flicker_amount <= 0.0:
		return 1.0
	# Düzensiz titreme: iki sinüs + ara sıra anlık düşüş
	var f: float = 0.5 + 0.25 * sin(_flicker_phase * 23.0) + 0.25 * sin(_flicker_phase * 37.0 + 1.3)
	var dip: float = 1.0 if _rng.randf() > 0.08 * _flicker_amount else 0.35
	return clampf(1.0 - _flicker_amount * (1.0 - f) * 0.7, 0.0, 1.0) * lerpf(1.0, dip, _flicker_amount)


func _apply(p: Preset) -> void:
	if sun == null:
		return
	var origin: Vector3 = sun.global_position if sun.is_inside_tree() else sun.position
	if p.sun_dir.length() > 0.001:
		var up: Vector3 = Vector3.UP if absf(p.sun_dir.normalized().y) < 0.99 else Vector3.FORWARD
		if sun.is_inside_tree():
			sun.look_at(origin + p.sun_dir, up)
		else:
			sun.basis = Basis.looking_at(p.sun_dir, up)
	sun.light_color = p.sun_color
	sun.light_energy = p.sun_energy
	if fill != null:
		fill.light_color = p.fill_color
		fill.light_energy = p.fill_energy
	if environment != null:
		environment.background_color = p.bg_color
	if backdrop != null:
		backdrop.set_shader_parameter("bottom_color", p.bg_color)
		backdrop.set_shader_parameter("top_color", p.bg_top)
		backdrop.set_shader_parameter("halo_color", p.shaft_color.lerp(p.bg_top, 0.5))
	if environment != null:
		environment.ambient_light_color = p.ambient_color
		environment.ambient_light_energy = p.ambient_energy * lerpf(0.35, 1.0, _mains)
		environment.tonemap_exposure = p.exposure
		environment.glow_intensity = p.glow
	if sky_material != null:
		sky_material.set_shader_parameter("sky_top", p.sky_top)
		sky_material.set_shader_parameter("sky_horizon", p.sky_horizon)
		sky_material.set_shader_parameter("far_color", p.far_color)
		sky_material.set_shader_parameter("near_color", p.near_color)
		sky_material.set_shader_parameter("tree_color", p.tree_color)
		sky_material.set_shader_parameter("sun_color", p.window_sun_color)
		sky_material.set_shader_parameter("sun_pos", p.window_sun_pos)
		sky_material.set_shader_parameter("stars", p.stars)
		sky_material.set_shader_parameter("brightness", p.sky_brightness)
		if not _win_active:
			sky_material.set_shader_parameter("window_lights", p.window_lights)
	if shafts != null:
		shafts.set_sun(p.sun_dir, p.shaft_color, p.shaft_intensity)
	if bounce != null:
		var d: Vector3 = p.sun_dir.normalized()
		var hit: Vector3 = window_center
		if d.y < -0.01:
			hit = window_center + d * (window_center.y / -d.y)
		hit.x = clampf(hit.x, 0.3, 5.1)
		hit.z = clampf(hit.z, 0.3, 3.9)
		bounce.position = hit + Vector3(0.0, 0.7, 0.0)
		bounce.light_color = p.sun_color.lerp(Color(1.0, 0.8, 0.6), 0.35)
		bounce.light_energy = p.sun_energy * 0.09 * (1.0 - smoothstep(0.75, 1.0, p.interior))
		bounce.visible = bounce.light_energy > 0.01
	var interior: float = p.interior * _mains * _flicker_factor()
	for il: InteriorLight in interior_lights:
		il.light.light_energy = il.full_energy * interior * il.gate
		il.light.visible = il.light.light_energy > 0.001
	for i: int in range(interior_emissives.size()):
		var gate: float = 1.0
		if _win_active and interior_lights.size() > 0:
			gate = interior_lights[0].gate
		interior_emissives[i].emission_energy_multiplier = interior_emissive_energy[i] * interior * gate


func _make_presets() -> Array[Preset]:
	var list: Array[Preset] = []
	# Sabah: serin gün ışığı, alçak güneş sağ arkadan; uzun yumuşak hüzmeler.
	var m: Preset = Preset.new()
	m.sun_dir = Vector3(-0.42, -0.36, 1.0).normalized()
	m.sun_color = Color(0.86, 0.93, 1.0)
	m.sun_energy = 5.2
	m.fill_color = Color(0.72, 0.82, 1.0)
	m.fill_energy = 0.26
	m.ambient_color = Color(0.62, 0.7, 0.86)
	m.ambient_energy = 0.42
	m.bg_color = Color(0.3, 0.36, 0.45)
	m.bg_top = Color(0.74, 0.8, 0.86)
	m.sky_top = Color(0.52, 0.68, 0.9)
	m.sky_horizon = Color(0.93, 0.9, 0.86)
	m.far_color = Color(0.68, 0.74, 0.84)
	m.near_color = Color(0.56, 0.62, 0.72)
	m.tree_color = Color(0.32, 0.42, 0.4)
	m.window_sun_color = Color(1.0, 0.92, 0.8)
	m.window_sun_pos = Vector2(0.72, 0.42)
	m.sky_brightness = 1.05
	m.interior = 0.0
	m.shaft_color = Color(0.85, 0.92, 1.0)
	m.shaft_intensity = 0.075
	m.exposure = 1.1
	m.glow = 0.55
	list.append(m)
	# Öğle: parlak, nötr; güneş yüksek, pencere altında kısa leke.
	var n: Preset = Preset.new()
	n.sun_dir = Vector3(-0.36, -0.78, 1.0).normalized()
	n.sun_color = Color(1.0, 0.97, 0.92)
	n.sun_energy = 6.2
	n.fill_color = Color(0.95, 0.95, 1.0)
	n.fill_energy = 0.26
	n.ambient_color = Color(0.78, 0.8, 0.84)
	n.ambient_energy = 0.46
	n.bg_color = Color(0.42, 0.4, 0.37)
	n.bg_top = Color(0.86, 0.84, 0.79)
	n.sky_top = Color(0.38, 0.6, 0.92)
	n.sky_horizon = Color(0.86, 0.92, 0.98)
	n.far_color = Color(0.7, 0.76, 0.84)
	n.near_color = Color(0.82, 0.8, 0.76)
	n.tree_color = Color(0.3, 0.46, 0.3)
	n.window_sun_color = Color(1.0, 1.0, 0.95)
	n.window_sun_pos = Vector2(0.5, -0.1)
	n.sky_brightness = 1.12
	n.interior = 0.0
	n.shaft_color = Color(1.0, 0.97, 0.9)
	n.shaft_intensity = 0.045
	n.exposure = 1.08
	n.glow = 0.5
	list.append(n)
	# Akşam: altın sarısı, alçak güneş sol arkadan; uzun sıcak gölgeler.
	var e: Preset = Preset.new()
	e.sun_dir = Vector3(0.1, -0.3, 1.0).normalized()
	e.sun_color = Color(1.0, 0.66, 0.36)
	e.sun_energy = 5.0
	e.fill_color = Color(0.85, 0.6, 0.62)
	e.fill_energy = 0.3
	e.ambient_color = Color(0.72, 0.56, 0.52)
	e.ambient_energy = 0.48
	e.bg_color = Color(0.36, 0.25, 0.28)
	e.bg_top = Color(0.86, 0.6, 0.48)
	e.sky_top = Color(0.42, 0.42, 0.66)
	e.sky_horizon = Color(1.0, 0.68, 0.42)
	e.far_color = Color(0.62, 0.48, 0.56)
	e.near_color = Color(0.42, 0.33, 0.4)
	e.tree_color = Color(0.22, 0.2, 0.22)
	e.window_sun_color = Color(1.0, 0.62, 0.3)
	e.window_sun_pos = Vector2(0.28, 0.5)
	e.window_lights = 0.35
	e.sky_brightness = 1.0
	e.interior = 0.35
	e.shaft_color = Color(1.0, 0.68, 0.38)
	e.shaft_intensity = 0.1
	e.exposure = 1.0
	e.glow = 0.75
	list.append(e)
	# Gece: dışarısı koyu mavi, içeride sıcak lambalar ve ışık havuzları.
	var g: Preset = Preset.new()
	g.sun_dir = Vector3(0.2, -0.9, 1.0).normalized()
	g.sun_color = Color(0.5, 0.62, 1.0)
	g.sun_energy = 0.45
	g.fill_color = Color(0.38, 0.45, 0.8)
	g.fill_energy = 0.12
	g.ambient_color = Color(0.22, 0.26, 0.42)
	g.ambient_energy = 0.42
	g.bg_color = Color(0.03, 0.04, 0.09)
	g.bg_top = Color(0.11, 0.14, 0.27)
	g.sky_top = Color(0.03, 0.05, 0.13)
	g.sky_horizon = Color(0.12, 0.16, 0.3)
	g.far_color = Color(0.08, 0.1, 0.18)
	g.near_color = Color(0.05, 0.06, 0.11)
	g.tree_color = Color(0.03, 0.04, 0.06)
	g.window_sun_color = Color(0.85, 0.9, 1.0)
	g.window_sun_pos = Vector2(0.7, 0.22)
	g.window_lights = 1.0
	g.stars = 1.0
	g.sky_brightness = 1.0
	g.interior = 1.0
	g.shaft_color = Color(0.5, 0.6, 1.0)
	g.shaft_intensity = 0.0
	g.exposure = 1.05
	g.glow = 0.9
	list.append(g)
	return list
