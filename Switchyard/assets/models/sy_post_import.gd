@tool
extends EditorScenePostImport

## Switchyard GLB içe aktarma betiği (sanat kiti).
## Blender yalnız malzeme ADINI taşır; her yüzey `res://assets/materials/<ad>.tres` ile değiştirilir (dokular ve
## malzemeler tek kopya, bütün araçlar aynı malzemeleri paylaşır). Düğüm adı son ekleri:
## "_noshadow" gölge atmaz, "_shadowonly" yalnız gölge atar.

const MATERIAL_DIR: String = "res://assets/materials/"


func _post_import(scene: Node) -> Object:
	_walk(scene)
	return scene


func _walk(node: Node) -> void:
	var mesh_instance: MeshInstance3D = node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		_remap(mesh_instance)
		var node_name: String = String(mesh_instance.name)
		if node_name.ends_with("_noshadow"):
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif node_name.ends_with("_shadowonly"):
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	for child: Node in node.get_children():
		_walk(child)


func _remap(mesh_instance: MeshInstance3D) -> void:
	var mesh: Mesh = mesh_instance.mesh
	for i: int in range(mesh.get_surface_count()):
		var current: Material = mesh.surface_get_material(i)
		if current == null:
			continue
		var mat_name: String = current.resource_name
		var path: String = MATERIAL_DIR + mat_name + ".tres"
		if ResourceLoader.exists(path):
			mesh.surface_set_material(i, load(path) as Material)
		else:
			push_warning("sy_post_import: malzeme yok: %s (%s)" % [mat_name, mesh_instance.name])
