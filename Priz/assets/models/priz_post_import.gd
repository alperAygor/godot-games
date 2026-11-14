@tool
extends EditorScenePostImport

## Priz GLB içe aktarma betiği.
## Blender yalnız malzeme ADINI taşır; burada her yüzey `res://assets/materials/<ad>.tres`
## ile değiştirilir (dokular tek kopya, malzemeler ortak). Eşleşme yoksa uyarı basılır.
## Ayrıca küçük, gölgesi görünmeyecek parçalar ("_noshadow" son ekli düğümler) gölge atmaz.

const MATERIAL_DIR: String = "res://assets/materials/"


func _post_import(scene: Node) -> Object:
	_walk(scene)
	return scene


func _walk(node: Node) -> void:
	var mesh_instance: MeshInstance3D = node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		_remap(mesh_instance)
		if String(mesh_instance.name).ends_with("_noshadow"):
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if String(mesh_instance.name).ends_with("_shadowonly"):
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
			push_warning("priz_post_import: malzeme yok: %s (%s)" % [mat_name, mesh_instance.name])
