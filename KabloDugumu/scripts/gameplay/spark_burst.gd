class_name SparkBurst
extends Node3D

## Kisa devre / yanlis priz kivilcimi: 4'lu GPUParticles3D havuzu + OmniLight3D
## flasi + genisleyen halka mesh. Dugumler onceden kurulur; burst() yeniden baslatir.

const POOL_SIZE: int = 4
const PARTICLE_AMOUNT: int = 26
const PARTICLE_LIFETIME: float = 0.45
## Quad kucuk, particle scale 2-5 ile buyutulur; yesil kivilcim noktalari gorunur olsun.
const QUAD_SIZE: float = 0.018
const BASE_VELOCITY_MIN: float = 1.5
const BASE_VELOCITY_MAX: float = 3.5
## ASMR (§16): sert flaş yok — ışık daha kısık, halka daha yumuşak büyür.
const FLASH_SECONDS: float = 0.26
const RING_SECONDS: float = 0.38
const BASE_LIGHT_ENERGY: float = 1.5
const RING_SCALE_START: float = 0.35
const RING_SCALE_GROWTH: float = 0.85
const MIN_STRENGTH: float = 0.2
const MAX_STRENGTH: float = 3.0

var _particles: Array[GPUParticles3D] = []
var _particle_materials: Array[ParticleProcessMaterial] = []
var _lights: Array[OmniLight3D] = []
var _rings: Array[MeshInstance3D] = []
var _ring_materials: Array[StandardMaterial3D] = []
var _tweens: Array[Tween] = []
var _next_index: int = 0
var _pool_ready: bool = false
## İlk gerçek patlama drag sırasında 80-120 ms'lik shader/buffer stall'ı
## yapıyordu (ölçüldü: /tmp/hitch_probe.gd). Bu yüzden havuz, sahne hazır olur
## olmaz görünmez bir kez "ısıtılır": pipeline derlenir, GPU tamponları ayrılır.
var _warmed: bool = false


func _ready() -> void:
	_ensure_pool()
	_warmup_deferred()


## Sahne ağaca girdikten sonra (kamera hazırken) tek karelik görünmez ısıtma.
func _warmup_deferred() -> void:
	if not is_inside_tree():
		return
	_warm_up()


## Görünmez ısıtma: partikül rengi/ring alpha 0 olsa da draw çağrısı oluşur,
## böylece shader pipeline ilk kısa devrede değil, bölüm yüklenirken derlenir.
func _warm_up() -> void:
	if _warmed or _particles.is_empty():
		return
	_warmed = true
	for i: int in _particles.size():
		var particles: GPUParticles3D = _particles[i]
		var process_material: ParticleProcessMaterial = _particle_materials[i]
		process_material.color = Color(1.0, 1.0, 1.0, 0.0)
		particles.emitting = true
		particles.restart()
		var ring: MeshInstance3D = _rings[i]
		var ring_material: StandardMaterial3D = _ring_materials[i]
		ring.global_position = Vector3(0.0, 0.0, 0.2)
		ring.scale = Vector3.ONE
		ring.visible = true
		ring_material.albedo_color = Color(1.0, 1.0, 1.0, 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	if _next_index > 0:
		return  # ısıtma sırasında gerçek bir patlama başladıysa ona dokunma
	for i: int in _particles.size():
		var particles: GPUParticles3D = _particles[i]
		particles.emitting = false
		particles.restart()
		(_particle_materials[i] as ParticleProcessMaterial).color = Color.WHITE
		var ring: MeshInstance3D = _rings[i]
		ring.visible = false
		ring.global_position = Vector3.ZERO
		(_ring_materials[i] as StandardMaterial3D).albedo_color = Color(1.0, 1.0, 1.0, 1.0)


## Kivilcim patlatir. Ayni havuz yuvasi yeniden kullanilir; onceki tween iptal edilir.
func burst(world_position: Vector3, color: Color, strength: float) -> void:
	_ensure_pool()
	if _particles.is_empty():
		return
	var power: float = clampf(strength, MIN_STRENGTH, MAX_STRENGTH)
	var slot: int = _next_index % POOL_SIZE
	_next_index += 1
	_kill_tween(slot)
	var particles: GPUParticles3D = _particles[slot]
	particles.global_position = world_position
	var process_material: ParticleProcessMaterial = _particle_materials[slot]
	process_material.color = color
	process_material.initial_velocity_min = BASE_VELOCITY_MIN * power
	process_material.initial_velocity_max = BASE_VELOCITY_MAX * power
	particles.restart()
	particles.emitting = true

	var ring: MeshInstance3D = _rings[slot]
	var ring_material: StandardMaterial3D = _ring_materials[slot]
	ring.global_position = world_position + Vector3(0.0, 0.0, 0.02)
	ring.scale = Vector3.ONE * RING_SCALE_START
	ring.visible = true
	ring_material.albedo_color = color

	var light: OmniLight3D = _lights[slot]
	light.global_position = world_position + Vector3(0.0, 0.0, 0.12)
	light.light_color = color
	light.light_energy = BASE_LIGHT_ENERGY * power
	if not is_inside_tree():
		ring.visible = false
		light.light_energy = 0.0
		return
	var tween: Tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(light, "light_energy", 0.0, FLASH_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale",
		Vector3.ONE * (RING_SCALE_GROWTH + power * 0.8), RING_SECONDS) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_fade_ring.bind(slot), 1.0, 0.0, RING_SECONDS)
	tween.chain().tween_callback(_hide_ring.bind(slot))
	_tweens[slot] = tween


func _ensure_pool() -> void:
	if _pool_ready:
		return
	_pool_ready = true
	for _i: int in POOL_SIZE:
		_create_slot()


func _create_slot() -> void:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.name = "Sparks"
	particles.amount = PARTICLE_AMOUNT
	particles.lifetime = PARTICLE_LIFETIME
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.local_coords = false
	particles.emitting = false
	particles.visibility_aabb = AABB(Vector3(-1.0, -1.0, -1.0), Vector3(2.0, 2.0, 2.0))
	var process_material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process_material.direction = Vector3(0.0, 0.4, 1.0)
	process_material.spread = 70.0
	process_material.initial_velocity_min = BASE_VELOCITY_MIN
	process_material.initial_velocity_max = BASE_VELOCITY_MAX
	process_material.gravity = Vector3(0.0, -4.0, 0.0)
	process_material.scale_min = 2.0
	process_material.scale_max = 5.0
	process_material.damping_min = 0.4
	process_material.damping_max = 1.2
	process_material.color = Color.WHITE
	particles.process_material = process_material
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(QUAD_SIZE, QUAD_SIZE)
	var spark_material: StandardMaterial3D = StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.vertex_color_use_as_albedo = true
	spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spark_material.albedo_color = Color.WHITE
	quad.material = spark_material
	particles.draw_pass_1 = quad
	add_child(particles)
	_particles.append(particles)
	_particle_materials.append(process_material)

	var light: OmniLight3D = OmniLight3D.new()
	light.name = "Flash"
	light.light_color = Color.WHITE
	light.light_energy = 0.0
	light.omni_range = 1.2
	light.shadow_enabled = false
	add_child(light)
	_lights.append(light)

	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "Ring"
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.03
	torus.outer_radius = 0.045
	torus.rings = 16
	torus.ring_segments = 6
	ring.mesh = torus
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	ring.visible = false
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_material: StandardMaterial3D = StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_material.albedo_color = Color.WHITE
	ring.material_override = ring_material
	add_child(ring)
	_rings.append(ring)
	_ring_materials.append(ring_material)
	_tweens.append(null)


func _kill_tween(slot: int) -> void:
	var previous: Tween = _tweens[slot]
	if previous != null and previous.is_valid():
		previous.kill()
	_tweens[slot] = null


func _fade_ring(value: float, slot: int) -> void:
	var material: StandardMaterial3D = _ring_materials[slot]
	var color: Color = material.albedo_color
	color.a = value
	material.albedo_color = color


func _hide_ring(slot: int) -> void:
	_rings[slot].visible = false
