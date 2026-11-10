extends RefCounted
class_name ModelCache
## .glb modelleri tek bir ArrayMesh'e birleştirir (malzeme başına bir yüzey).
## 11-15 parçalı bir düşman böylece 3-4 çizim çağrısına iner: mobilde belirgin kazanç.

static var _cache: Dictionary = {}
static var _flash: StandardMaterial3D
static var _flash_soft: StandardMaterial3D
static var _elite: StandardMaterial3D

static func mesh(path: String) -> Mesh:
	if _cache.has(path):
		return _cache[path]
	var out: ArrayMesh = null
	if ResourceLoader.exists(path):
		var packed: PackedScene = load(path)
		if packed != null:
			var root: Node = packed.instantiate()
			var tools: Dictionary = {}
			var order: Array = []
			_collect(root, Transform3D.IDENTITY, tools, order)
			out = ArrayMesh.new()
			for mat in order:
				var st: SurfaceTool = tools[mat]
				st.commit(out)
				if mat is Material:
					out.surface_set_material(out.get_surface_count() - 1, mat)
			root.free()
	_cache[path] = out
	return out

static func _collect(node: Node, parent: Transform3D, tools: Dictionary, order: Array) -> void:
	var xform := parent
	if node is Node3D:
		xform = parent * (node as Node3D).transform
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				var mat: Variant = mi.get_active_material(s)
				var key: Variant = mat if mat != null else "none"
				if not tools.has(key):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					tools[key] = st
					order.append(key)
				(tools[key] as SurfaceTool).append_from(mi.mesh, s, xform)
	for child in node.get_children():
		_collect(child, xform, tools, order)

static func instance(path: String, scale_factor := 1.0) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh(path)
	node.scale = Vector3.ONE * scale_factor
	return node

static func flash_material() -> StandardMaterial3D:
	## Vuruş anında modelin üstüne binen beyaz parlama.
	if _flash == null:
		_flash = StandardMaterial3D.new()
		_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flash.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
		_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return _flash

static func flash_material_soft() -> StandardMaterial3D:
	## Sık vurulan boss için: modeli örtmeyen hafif parlama.
	if _flash_soft == null:
		_flash_soft = StandardMaterial3D.new()
		_flash_soft.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_soft.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flash_soft.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_soft.albedo_color = Color(1.0, 1.0, 1.0, 0.28)
	return _flash_soft

static func elite_material() -> StandardMaterial3D:
	## Elit düşmanların altın kenar ışıltısı.
	if _elite == null:
		_elite = StandardMaterial3D.new()
		_elite.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_elite.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_elite.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_elite.albedo_color = Color(1.0, 0.72, 0.18, 0.55)
		_elite.rim_enabled = false
	return _elite
