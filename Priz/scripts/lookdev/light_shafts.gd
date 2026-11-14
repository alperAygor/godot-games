class_name LightShafts
extends MeshInstance3D

## Pencereden giren güneş hüzmesi. Pencere dikdörtgeninden güneş yönünde uzanan, kenarları
## yumuşak, toz zerrecikli bir prizma kabuğu (Mobile çizicide hacimsel sis olmadığı için).
## Kalite "low" kademesinde tümüyle kapatılır (ucuz taklit yerine hiç yok).

const SHADER: Shader = preload("res://assets/shaders/light_shaft.gdshader")
const NOISE: Texture2D = preload("res://assets/textures/noise_rgba.png")

## Pencere iç yüz dikdörtgeni (oda yerel koordinatı, Godot): sol-alt ve sağ-üst köşe.
@export var window_min: Vector3 = Vector3(3.82, 1.0, 0.0)
@export var window_max: Vector3 = Vector3(4.78, 2.2, 0.0)
@export var length: float = 5.5
## Odanın açık kenarları (hüzme bunların dışına taşmaz).
@export var room_max: Vector3 = Vector3(5.4, 2.7, 4.15)

var _material: ShaderMaterial
var _dir: Vector3 = Vector3.ZERO
var _enabled: bool = true


func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("noise_tex", NOISE)
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED


func set_enabled(on: bool) -> void:
	_enabled = on
	visible = on and _material != null and float(_material.get_shader_parameter("intensity")) > 0.001


## dir: güneşin ışık yayılım yönü (dünya = oda yerel kabul edilir).
func set_sun(dir: Vector3, color: Color, intensity: float) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("shaft_color", color)
	_material.set_shader_parameter("intensity", intensity)
	visible = _enabled and intensity > 0.001 and dir.z > 0.05
	if visible and dir.normalized().distance_to(_dir) > 0.002:
		_dir = dir.normalized()
		_rebuild()


func _rebuild() -> void:
	var c: Array[Vector3] = [
		Vector3(window_min.x, window_min.y, window_min.z),
		Vector3(window_max.x, window_min.y, window_min.z),
		Vector3(window_max.x, window_max.y, window_min.z),
		Vector3(window_min.x, window_max.y, window_min.z),
	]
	# Her köşe ışını zemine (y=0) ya da odanın açık kenarına (x=room_max.x, z=room_max.z) kadar.
	var ends: Array[Vector3] = []
	for p: Vector3 in c:
		var t: float = length
		if _dir.y < -0.001:
			t = minf(t, -p.y / _dir.y)
		if _dir.z > 0.001:
			t = minf(t, (room_max.z - p.z) / _dir.z)
		if _dir.x > 0.001:
			t = minf(t, (room_max.x - p.x) / _dir.x)
		elif _dir.x < -0.001:
			t = minf(t, (0.0 - p.x) / _dir.x)
		ends.append(p + _dir * maxf(t, 0.05))
	var verts: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var normals: PackedVector3Array = PackedVector3Array()
	for i: int in range(4):
		var j: int = (i + 1) % 4
		var a: Vector3 = c[i]
		var b: Vector3 = c[j]
		var n: Vector3 = (b - a).cross(_dir).normalized()
		var quad: Array[Vector3] = [a, b, ends[j], a, ends[j], ends[i]]
		var quv: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]
		for k: int in range(6):
			verts.append(quad[k])
			uvs.append(quv[k])
			normals.append(n)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	var am: ArrayMesh = ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = am
