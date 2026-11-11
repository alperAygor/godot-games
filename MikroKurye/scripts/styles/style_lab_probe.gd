class_name StyleLabProbe
extends SceneTree
## Görsel değerlendirmeye ek olarak kamera/yerleşim eşitliğini otomatik korur.

const KEY_FRAME: PackedScene = preload("res://scenes/styles/_key_frame.tscn")
const STYLE_COUNT: int = 3
const EXPECTED_MODELS: int = 14
const EXPECTED_WHEELS: int = 4
const EXPECTED_CARGO: int = 3
const WIDE_SIZE: float = 10.4
const CLOSE_SIZE: float = 2.05
var _failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var reference_transforms: Array[Transform3D] = []
	var reference_cameras: Array[Transform3D] = []
	for style: int in range(STYLE_COUNT):
		for close: bool in [false, true]:
			var fixture: Node3D = KEY_FRAME.instantiate() as Node3D
			fixture.set("style_index", style)
			fixture.set("close_frame", close)
			root.add_child(fixture)
			await process_frame
			var cameras: Array[Node] = fixture.find_children("*", "Camera3D", true, false)
			_check(cameras.size() == 1, "Exactly one camera")
			var camera: Camera3D = cameras[0] as Camera3D
			_check(is_equal_approx(camera.size, CLOSE_SIZE if close else WIDE_SIZE), "Fixed orthographic framing")
			if style == 0:
				reference_cameras.append(camera.global_transform)
			else:
				_check(camera.global_transform == reference_cameras[1 if close else 0], "Identical camera transform across styles")
			var models: Array[Node] = fixture.find_children("*", "MeshInstance3D", true, false)
			var transforms: Array[Transform3D] = []
			var model_count: int = 0
			var wheels: int = 0
			var cargo: int = 0
			for node: Node in models:
				var mesh_node: MeshInstance3D = node as MeshInstance3D
				if mesh_node.mesh is ArrayMesh:
					transforms.append(mesh_node.global_transform)
					model_count += 1
					var model_parent: String = mesh_node.get_parent().scene_file_path.get_file().get_basename()
					if model_parent.begins_with("robot_wheel"):
						wheels += 1
					if model_parent.begins_with("cargo_") and not model_parent.begins_with("cargo_basket"):
						cargo += 1
					for surface: int in range(mesh_node.mesh.get_surface_count()):
						var material: ShaderMaterial = mesh_node.get_surface_override_material(surface) as ShaderMaterial
						_check(material != null, "Every imported surface restyled")
						if material != null:
							_check((material.next_pass != null) == (style == 0), "Outline restricted to A")
			_check(model_count == EXPECTED_MODELS, "All existing model instances present")
			_check(wheels == EXPECTED_WHEELS, "Four wheels")
			_check(cargo == EXPECTED_CARGO, "Three cargo types")
			if reference_transforms.is_empty():
				reference_transforms = transforms
			else:
				_check(reference_transforms == transforms, "All six fixtures have identical model transforms")
			fixture.free()
	if not _failed:
		push_warning("STYLE LAB PROBE PASS: six fixtures; same transforms/cameras, 14 models, 4 wheels, 3 cargo types, per-style materials")
	quit(1 if _failed else 0)

func _check(condition: bool, description: String) -> void:
	if not condition:
		_failed = true
		push_error("STYLE LAB PROBE FAIL: " + description)
