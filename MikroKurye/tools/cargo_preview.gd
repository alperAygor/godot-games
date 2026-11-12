extends Node3D
## Sipariş kartı küçük resimleri için kargoyu oyun içi stil A (toon + anahat) ile çizer.
## Kullanım (gerçek pencere): scene_shot.gd ile `--scene=res://tools/cargo_preview.tscn --cargo=<id>`.
## Arka plan sabit macenta (anahtar renk); lider betiği onu saydamlığa çevirir.

const MODELS: Dictionary = {
	"pencil_battery": "res://assets/models/v2/cargo_pencil_battery_v2.glb",
	"sd_card": "res://assets/models/v2/cargo_sd_card_v2.glb",
	"espresso_capsule": "res://assets/models/v2/cargo_espresso_capsule_v2.glb",
}
const VIEW_DIRECTION: Vector3 = Vector3(0.75, 0.62, 1.0)
const FIT_MARGIN: float = 1.12

@onready var _camera: Camera3D = $Camera3D
@onready var _holder: Node3D = $Holder


func _ready() -> void:
	var cargo_id: String = "pencil_battery"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--cargo="):
			cargo_id = arg.split("=")[1]
	var packed: PackedScene = load(String(MODELS.get(cargo_id, MODELS["pencil_battery"]))) as PackedScene
	var model: Node3D = packed.instantiate() as Node3D
	_holder.add_child(model)
	var box: AABB = _combined_aabb(model)
	var center: Vector3 = box.get_center()
	var radius: float = box.size.length() * 0.5 * FIT_MARGIN
	_camera.position = center + VIEW_DIRECTION.normalized() * radius / tan(deg_to_rad(_camera.fov * 0.5))
	_camera.look_at(center)
	# StyleA kardeşlerin alt ağacını `_ready`'de dolaşır; model sonradan eklendiği için
	# düğüm burada, model hazır olunca oluşturulur.
	add_child(StyleA.new())


func _combined_aabb(root: Node3D) -> AABB:
	var result: AABB = AABB()
	var first: bool = true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var mesh: MeshInstance3D = node as MeshInstance3D
		if mesh == null:
			continue
		var box: AABB = mesh.global_transform * mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result
