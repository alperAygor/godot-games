class_name MugSteam
extends CPUParticles3D

## Kupa üstünde hafif buhar: az parçacık, yavaş yükseliş, yumuşak saydam.
## Yalnız görsel; çarpışma/ölçüm yok. Parçacık sayısı düşük tutulur (performans
## bütçesi); ömür boyunca alfa `color_ramp` ile doğar-kaybolur.

const PARTICLE_AMOUNT: int = 12
const LIFETIME_SECONDS: float = 2.6
const EMISSION_RADIUS: float = 0.35
const UP_SPEED_MIN: float = 0.15
const UP_SPEED_MAX: float = 0.5
const SPREAD_DEG: float = 14.0

@export var steam_amount: int = PARTICLE_AMOUNT


func _ready() -> void:
	amount = maxi(steam_amount, 1)
	lifetime = LIFETIME_SECONDS
	lifetime_randomness = 0.4
	preprocess = LIFETIME_SECONDS
	emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = EMISSION_RADIUS
	direction = Vector3.UP
	spread = SPREAD_DEG
	gravity = Vector3.ZERO
	initial_velocity_min = UP_SPEED_MIN
	initial_velocity_max = UP_SPEED_MAX
	scale_amount_min = 0.6
	scale_amount_max = 1.6
	mesh = _steam_mesh()
	color_ramp = _steam_ramp()
	emitting = true


## Küçük yumuşak küre; saydam alfa malzemesi. Renk/alfa ömür rampasından gelir.
func _steam_mesh() -> SphereMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	sphere.radial_segments = 3
	sphere.rings = 2
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	sphere.material = material
	return sphere


## Ömür rampası: buhar görünür doğar, yumuşakça kaybolur (alfa 0 -> 0.3 -> 0).
func _steam_ramp() -> Gradient:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.6, 1.0])
	ramp.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 0.0),
		Color(1.0, 1.0, 1.0, 0.30),
		Color(1.0, 1.0, 1.0, 0.22),
		Color(1.0, 1.0, 1.0, 0.0),
	])
	return ramp
