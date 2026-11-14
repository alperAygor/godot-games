class_name KettleFx
extends Appliance

## Su ısıtıcı: su ≈2.5 sn'de ısınır, emzikten buhar yükselir (GPU parçacıkları), anahtar yanar;
## kaynarken gövde çok hafif tıkırdar.

const MODEL: PackedScene = preload("res://assets/models/appliances/kettle.glb")
const STEAM_SHADER: Shader = preload("res://assets/shaders/steam.gdshader")
const NOISE: Texture2D = preload("res://assets/textures/noise_rgba.png")

var _steam: GPUParticles3D
var _led: StandardMaterial3D
var _body: Node3D
var _body_rest: Vector3 = Vector3.ZERO
var _t: float = 0.0


func _init() -> void:
	appliance_id = "kettle"
	default_ramp = 2.5
	if model == null:
		model = MODEL


func _setup() -> void:
	_led = make_indicator(Color(1.0, 0.35, 0.15))
	_body = part("Body")
	if _body != null:
		_body_rest = _body.position
	_steam = make_steam()
	var a: Node3D = part("SteamAnchor")
	if a != null:
		a.add_child(_steam)
	else:
		add_child(_steam)


static func make_steam() -> GPUParticles3D:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.name = "Steam"
	p.amount = 26
	p.lifetime = 2.4
	p.local_coords = false
	p.emitting = false
	p.amount_ratio = 0.0
	p.visibility_aabb = AABB(Vector3(-0.4, -0.1, -0.4), Vector3(0.8, 1.2, 0.8))
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.008
	pm.direction = Vector3(0.0, 1.0, 0.35)
	pm.spread = 14.0
	pm.initial_velocity_min = 0.16
	pm.initial_velocity_max = 0.28
	pm.gravity = Vector3(0.0, 0.05, 0.0)
	pm.damping_min = 0.12
	pm.damping_max = 0.25
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.scale_min = 0.55
	pm.scale_max = 1.0
	var sc: Curve = Curve.new()
	sc.add_point(Vector2(0.0, 0.25))
	sc.add_point(Vector2(0.5, 0.9))
	sc.add_point(Vector2(1.0, 1.6))
	var sct: CurveTexture = CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	grad.add_point(0.12, Color(1, 1, 1, 0.85))
	grad.add_point(0.55, Color(1, 1, 1, 0.45))
	var gt: GradientTexture1D = GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.35
	pm.turbulence_noise_scale = 2.5
	pm.turbulence_influence_min = 0.05
	pm.turbulence_influence_max = 0.15
	p.process_material = pm
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	var sm: ShaderMaterial = ShaderMaterial.new()
	sm.shader = STEAM_SHADER
	sm.set_shader_parameter("noise_tex", NOISE)
	quad.material = sm
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _on_level(level: float) -> void:
	if _led != null:
		_led.emission_energy_multiplier = 5.0 * (1.0 if running else 0.0) * _mains
	if _steam != null:
		var r: float = smoothstep(0.45, 1.0, level)
		_steam.amount_ratio = r
		_steam.emitting = r > 0.01


func _animate(delta: float, level: float) -> void:
	_t += delta
	if _body != null:
		var boil: float = smoothstep(0.8, 1.0, level) * 0.0006
		_body.position = _body_rest + Vector3(boil * sin(_t * 67.0), absf(boil * sin(_t * 43.0)), 0.0)
