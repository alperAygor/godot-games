class_name StyleA
extends Node
## Stil A (toon + outline) görsel uygulayıcısı — yalnız görsel, fiziğe dokunmaz.
##
## Sahne kökünün son çocuğu olarak eklenir; `_ready` sırasında kardeşlerin
## (GLB instance'ları dahil) alt ağacı hazır olduğundan tüm MeshInstance3D'leri
## güvenle dolaşır. Standart yüzey malzemesini aynı albedo renginde, paylaşılan
## toon malzemesiyle değiştirir; anahatı yalnız etkileşimli nesnelere ekler.
## `assets/materials/*.tres` ile değiştirilen yüzeyler (ShaderMaterial) atlanır.

const TOON_SHADER_PATH: String = "res://assets/shaders/toon.gdshader"
const OUTLINE_SHADER_PATH: String = "res://assets/shaders/outline.gdshader"
const SHADOW_COLOR: Color = Color("44446b")
## Kalibrasyon: stil laboratuvarı referansı 0.003'tü; oyun kamera mesafesinde
## (6 m) okunmayacak kadar inceydi. 0.008 kabul aralığının (0.003–0.008) üst
## sınırında; düz normalli mesh'lerde köşe dikişini bozmadan silüeti okunur kılar.
const OUTLINE_WIDTH: float = 0.008
const INK_COLOR: Color = Color("20283e")

## V1 GLB yüzey adları → son palet (PROJECT_SPEC §13). İçe aktarılan malzeme
## renkleri `.godot` önbelleğinde elle düzeltilmişti; reimport'ta kaybolmasın diye
## eşleme kodda sabitlenir. V1 gövde kabuğu ("Dark") neredeyse siyahtı; gövde
## doygun turkuaz olmalı (yalnız gölge tarafı koyulaşır).
const PALETTE: Dictionary[String, Color] = {
	"MK_Robot_Turquoise": Color("2ee6c5"),
	"MK_Robot_Dark": Color("2ee6c5"),
	"MK_Robot_Yellow": Color("ffc83d"),
	"MK_Wheel_Tire": Color("2b2f3a"),
	"MK_Wheel_Rim": Color("b8c0cc"),
	"MK_Wheel_Hub": Color("ffc83d"),
	"MK_Basket_Yellow": Color("ffc83d"),
	"MK_Basket_Orange": Color("ef8b2c"),
}

## Anahat yalnızca elle etkileşime giren nesnelerde (F7.3 kabul listesi); fan
## bir rüzgar bölgesi olduğu için bu listede değildir.
const INTERACTIVE_GROUPS: Array[String] = [
	"robot", "cargo", "keyboard_key", "rolling_pencil", "golden_box",
]

var _toon_shader: Shader = null
var _outline_material: ShaderMaterial = null
var _cache: Dictionary[String, ShaderMaterial] = {}


func _ready() -> void:
	_apply(get_parent())


func _apply(root: Node) -> void:
	if root == null:
		return
	_toon_shader = load(TOON_SHADER_PATH) as Shader
	_outline_material = _build_outline()
	_restyle(root)


func _build_outline() -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(OUTLINE_SHADER_PATH) as Shader
	material.set_shader_parameter("width", OUTLINE_WIDTH)
	material.set_shader_parameter("ink_color", INK_COLOR)
	return material


func _restyle(node: Node) -> void:
	if node is MeshInstance3D:
		_restyle_mesh(node as MeshInstance3D)
	for child: Node in node.get_children():
		_restyle(child)


func _restyle_mesh(mesh_instance: MeshInstance3D) -> void:
	var mesh: Mesh = mesh_instance.mesh
	if mesh == null:
		return
	# KeyboardKey kendi toon yüzeylerini ve telegraph rengini yönetir; burada
	# ezilirse renk animasyonu kopar. Anahatı da kendisi ekler.
	if _is_in_group(mesh_instance, "keyboard_key"):
		return
	var interactive: bool = _is_interactive(mesh_instance)
	# KeyboardKey gibi düğümler dinamik `material_override` taşır (telegraph rengi her
	# kare `base_color` parametresiyle değişir; KeyboardKey zaten toon ShaderMaterial'dir).
	# Yüzeyi ezmek yerine yalnız anahat eklenir; renk animasyonu parametre üzerinden korunur.
	if mesh_instance.material_override != null:
		if interactive:
			_add_outline(mesh_instance.material_override)
		return
	for surface: int in range(mesh.get_surface_count()):
		var material: Material = mesh.surface_get_material(surface)
		if material is ShaderMaterial:
			# Zaten .tres ile stil verilmiş yüzey; eksikse yalnız anahat eklenir.
			if interactive:
				_add_outline(material)
			continue
		if material is StandardMaterial3D:
			var std: StandardMaterial3D = material as StandardMaterial3D
			var base: Color = _palette_color(String(std.resource_name), std.albedo_color)
			mesh_instance.set_surface_override_material(surface, _toon_material(base, interactive))


## İçe aktarılan yüzey adı palet eşlemesinde varsa onu, yoksa orijinal albedoyu verir.
func _palette_color(resource_name: String, fallback: Color) -> Color:
	return PALETTE.get(resource_name, fallback)


func _toon_material(base: Color, interactive: bool) -> ShaderMaterial:
	# Renk + anahat bayrağına göre önbellek: aynı renk yüzeyler aynı malzemeyi paylaşır.
	var key: String = base.to_html(false) + ("_o" if interactive else "")
	if _cache.has(key):
		return _cache[key]
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _toon_shader
	material.set_shader_parameter("base_color", base)
	material.set_shader_parameter("shadow_color", SHADOW_COLOR)
	if interactive:
		material.next_pass = _outline_material
	_cache[key] = material
	return material


func _add_outline(material: Material) -> void:
	if material != null and material.next_pass == null:
		material.next_pass = _outline_material


func _is_interactive(node: Node) -> bool:
	var current: Node = node
	while current != null:
		for group: String in INTERACTIVE_GROUPS:
			if current.is_in_group(group):
				return true
		current = current.get_parent()
	return false


## Düğümün kendisi ya da bir atası verilen gruptaysa doğru döner.
func _is_in_group(node: Node, group: String) -> bool:
	var current: Node = node
	while current != null:
		if current.is_in_group(group):
			return true
		current = current.get_parent()
	return false
