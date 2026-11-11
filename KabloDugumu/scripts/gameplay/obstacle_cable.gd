class_name ObstacleCable
extends CableNode

## v0.2 "sway" modifier: panoya iki ucu da sabitlenmis, yavasca salinan CANLI
## (ciplak) hat. Oyuncu bunu tutamaz; temas kisa devre sayilir (ContactMonitor).
##
## CableNode'dan turuyor ki temas tarayicisi (Array[CableNode] + segments())
## degismeden calissin; CableRope kullanilmaz cunku halat modelinde iki ucu
## sabit salinim modu yok. Gorsel (ince emissive tube) burada uretilir ve
## yalnizca salinim degistiginde yeniden kurulur (perf butcesi).

## Plan/gorsel sabitleri (denge degerleri data/balance.json -> modifiers.sway).
const SEGMENT_COUNT: int = 13
const TUBE_RADIUS: float = 0.016
const TUBE_SIDES: int = 6
const LIVE_COLOR_ID: StringName = &"live"
const MIN_PERIOD_SECONDS: float = 2.5
const RENDER_INTERVAL: float = 1.0 / 30.0
const PLATE_SIZE: float = 0.05
## Belirgin tehlike telegraph'i: nefes alan amber/camgobegi emission (0.8-1.4).
const GLOW_MIN: float = 0.8
const GLOW_MAX: float = 1.4
## Kucuk, cok yavas elektrik arkı partikulleri (ARCHITECTURE §16: sakin).
const SPARK_AMOUNT: int = 8
const SPARK_LIFETIME: float = 1.6
const SPARK_QUAD_SIZE: float = 0.008

var live_color: Color = Color(1.0, 0.72, 0.28)
var top_anchor: Vector3 = Vector3.ZERO
var bottom_anchor: Vector3 = Vector3.ZERO
var period_seconds: float = 3.6
var amplitude: float = 0.1
var phase: float = 0.0

var _segments_world: PackedVector3Array = PackedVector3Array()
var _mesh_instance: MeshInstance3D = null
var _material: StandardMaterial3D = null
var _time: float = 0.0
var _render_accum: float = RENDER_INTERVAL
var _spark_particles: GPUParticles3D = null


## Tohumlu plan: her canli hat icin ust/alt capa, salinim periyodu (>=2.5 sn),
## genlik ve faz. Saf fonksiyon (dugum yok) -> birim testli.
static func plan_obstacles(seed_value: int, count: int, board: Dictionary,
		config: Dictionary) -> Array[Dictionary]:
	var plans: Array[Dictionary] = []
	var safe_count: int = maxi(0, count)
	if safe_count == 0:
		return plans
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value * 2654435761 + 1013904223
	var width: float = float(board.get("width", 1.7))
	var surface_z: float = float(board.get("board_surface_z", 0.055))
	var top_y: float = float(config.get("top_y", 0.46))
	var bottom_y: float = float(config.get("bottom_y", -0.30))
	var z: float = surface_z + float(config.get("z_offset", 0.05))
	var period_min: float = maxf(MIN_PERIOD_SECONDS,
		float(config.get("min_period_seconds", 3.2)))
	var period_max: float = maxf(period_min,
		float(config.get("max_period_seconds", 4.6)))
	var amp_min: float = float(config.get("min_amplitude", 0.09))
	var amp_max: float = maxf(amp_min, float(config.get("max_amplitude", 0.13)))
	# Canli hatlar dugum bolgesinin iki yaninda asili durur: naif "duz cizgi"
	# surukleme surtunur (tehlike), planli oynayis ortadan/kenardan gecer.
	var x_limit: float = width * 0.5 - 0.13
	var slots: Array[float] = []
	for i: int in safe_count:
		if safe_count == 1:
			var side: float = 1.0 if rng.randf() < 0.5 else -1.0
			slots.append(side * rng.randf_range(0.26, 0.34))
		else:
			var side2: float = 1.0 if i == 0 else -1.0
			slots.append(side2 * rng.randf_range(0.40, 0.46)
				+ rng.randf_range(-0.02, 0.02))
	for i: int in safe_count:
		var x: float = clampf(slots[i], -x_limit, x_limit)
		var amps: float = rng.randf_range(amp_min, amp_max)
		var plan: Dictionary = {
			"top": Vector3(x, top_y, z),
			"bottom": Vector3(x, bottom_y, z),
			"period": maxf(MIN_PERIOD_SECONDS, rng.randf_range(period_min, period_max)),
			"amplitude": maxf(0.0, minf(amps, x_limit - absf(x))),
			"phase": rng.randf_range(0.0, TAU),
			"color": String(config.get("color", "#FFB347")),
		}
		plans.append(plan)
	return plans


## Planlanan canli hatti sahneye kurar (agacta cagrilmali).
func setup_obstacle(plan: Dictionary, color: Color) -> void:
	index = 0
	spec = null
	state = State.IDLE
	grabbable = false
	live_color = color
	top_anchor = plan.get("top", Vector3.ZERO) as Vector3
	bottom_anchor = plan.get("bottom", Vector3.ZERO) as Vector3
	period_seconds = maxf(MIN_PERIOD_SECONDS, float(plan.get("period", 3.6)))
	amplitude = maxf(0.0, float(plan.get("amplitude", 0.1)))
	phase = float(plan.get("phase", 0.0))
	_build_anchors()
	_build_mesh()
	_build_spark_particles()
	_rebuild_segments()


func set_live_color(color: Color) -> void:
	live_color = color
	if _material != null:
		_material.albedo_color = color.darkened(0.35)
		_material.emission = color


## Canli hat tutulamaz (LevelController hic teklif etmez; yine de kapi kapali).
func is_grabbable() -> bool:
	return false


func set_grabbable(_on: bool) -> void:
	pass


func is_dragging() -> bool:
	return false


## Temas tarayicisi icin dunya uzayinda ornekli halat noktalari (>= 2).
func segments() -> PackedVector3Array:
	return _segments_world


func _process(delta: float) -> void:
	_time += delta
	_render_accum += delta
	if _render_accum < RENDER_INTERVAL:
		return
	_render_accum = 0.0
	_rebuild_segments()
	_rebuild_mesh()
	if _material != null:
		var glow: float = (GLOW_MAX - GLOW_MIN) * (0.5 + 0.5 * sin(_time * 1.3 + phase))
		_material.emission_energy_multiplier = GLOW_MIN + glow
	if _spark_particles != null:
		_spark_particles.position = Vector3(
			lerpf(top_anchor.x, bottom_anchor.x, 0.5),
			lerpf(top_anchor.y, bottom_anchor.y, 0.5), top_anchor.z)


## Konum: her iki ucu sabit, orta bolge yatayda sinus ile salinir (period >= 2.5 sn).
func _rebuild_segments() -> void:
	_segments_world = PackedVector3Array()
	var sway: float = sin(TAU * _time / period_seconds + phase)
	for i: int in SEGMENT_COUNT:
		var s: float = float(i) / float(SEGMENT_COUNT - 1)
		var bulge: float = sin(PI * s)
		var x: float = lerpf(top_anchor.x, bottom_anchor.x, s) + amplitude * bulge * sway
		var y: float = lerpf(top_anchor.y, bottom_anchor.y, s)
		var z: float = lerpf(top_anchor.z, bottom_anchor.z, s)
		var local: Vector3 = Vector3(x, y, z)
		_segments_world.append(global_transform * local)


func _build_mesh() -> void:
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "LiveWire"
		_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_mesh_instance)
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_material.albedo_color = live_color.darkened(0.35)
		_material.emission_enabled = true
		_material.emission = live_color
		_material.emission_energy_multiplier = 1.1
		_mesh_instance.material_override = _material


## Her iki uctaki capa plakalari (sabit uclar okunsun).
## Kucuk, cok yavas elektrik arkı partikulleri: hattin tehlikeli oldugunu okutur.
func _build_spark_particles() -> void:
	if _spark_particles != null:
		return
	_spark_particles = GPUParticles3D.new()
	_spark_particles.name = "Sparks"
	_spark_particles.amount = SPARK_AMOUNT
	_spark_particles.lifetime = SPARK_LIFETIME
	_spark_particles.emitting = true
	_spark_particles.local_coords = true
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.24
	process.gravity = Vector3.ZERO
	process.initial_velocity_min = 0.01
	process.initial_velocity_max = 0.035
	process.scale_min = 0.4
	process.scale_max = 1.1
	process.color = live_color
	_spark_particles.process_material = process
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(SPARK_QUAD_SIZE, SPARK_QUAD_SIZE)
	var spark_material: StandardMaterial3D = StandardMaterial3D.new()
	spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	spark_material.albedo_color = live_color
	spark_material.emission_enabled = true
	spark_material.emission = live_color
	spark_material.emission_energy_multiplier = 1.8
	spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = spark_material
	_spark_particles.draw_pass_1 = quad
	_spark_particles.visibility_aabb = AABB(Vector3(-0.6, -0.6, -0.2), Vector3(1.2, 1.2, 0.4))
	add_child(_spark_particles)


func _build_anchors() -> void:
	for anchor: Vector3 in [top_anchor, bottom_anchor]:
		var plate: MeshInstance3D = MeshInstance3D.new()
		plate.name = "Anchor"
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(PLATE_SIZE, PLATE_SIZE, 0.012)
		plate.mesh = box
		plate.position = anchor + Vector3(0.0, 0.0, -0.01)
		var plate_material: StandardMaterial3D = StandardMaterial3D.new()
		plate_material.albedo_color = Color(0.06, 0.07, 0.08)
		plate_material.metallic = 0.7
		plate_material.roughness = 0.4
		plate.material_override = plate_material
		plate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(plate)
		var ring: MeshInstance3D = MeshInstance3D.new()
		ring.name = "AnchorClamp"
		var torus: TorusMesh = TorusMesh.new()
		torus.inner_radius = 0.016
		torus.outer_radius = 0.027
		torus.rings = 16
		torus.ring_segments = 6
		ring.mesh = torus
		ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		ring.position = anchor + Vector3(0.0, 0.0, 0.006)
		var ring_material: StandardMaterial3D = StandardMaterial3D.new()
		ring_material.albedo_color = live_color.darkened(0.2)
		ring_material.emission_enabled = true
		ring_material.emission = live_color
		ring_material.emission_energy_multiplier = 1.35
		ring.material_override = ring_material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)


## Salinan hattin tube mesh'ini yeniden kurar (yalnizca yon degistiginde).
func _rebuild_mesh() -> void:
	if _mesh_instance == null or _segments_world.size() < 2:
		return
	var points: PackedVector3Array = PackedVector3Array()
	for world_point: Vector3 in _segments_world:
		points.append(to_local(world_point))
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in points.size():
		var previous: Vector3 = points[maxi(i - 1, 0)]
		var next: Vector3 = points[mini(i + 1, points.size() - 1)]
		var tangent: Vector3 = (next - previous).normalized()
		var side: Vector3 = tangent.cross(Vector3.BACK)
		if side.length_squared() < 0.000001:
			side = Vector3.RIGHT
		side = side.normalized()
		var normal: Vector3 = Vector3.BACK
		for ring: int in TUBE_SIDES:
			var angle: float = TAU * float(ring) / float(TUBE_SIDES)
			var direction: Vector3 = side * cos(angle) + normal * sin(angle)
			surface.set_normal(direction)
			surface.add_vertex(points[i] + direction * TUBE_RADIUS)
	for i: int in points.size() - 1:
		for ring: int in TUBE_SIDES:
			var a: int = i * TUBE_SIDES + ring
			var b: int = i * TUBE_SIDES + (ring + 1) % TUBE_SIDES
			var c: int = (i + 1) * TUBE_SIDES + ring
			var d: int = (i + 1) * TUBE_SIDES + (ring + 1) % TUBE_SIDES
			surface.add_index(a)
			surface.add_index(b)
			surface.add_index(c)
			surface.add_index(b)
			surface.add_index(d)
			surface.add_index(c)
	_mesh_instance.mesh = surface.commit() as ArrayMesh
