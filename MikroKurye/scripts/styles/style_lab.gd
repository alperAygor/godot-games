class_name StyleLab
extends Node3D
## Aynı geometriyi korumak, stil seçimini kamera/yerleşim farkından ayırır.

enum Style { TOON, CLAY, FLAT }

const MODEL_ROOT: String = "res://assets/models/"
const STYLE_ARGUMENTS: Array[String] = ["a", "b", "c"]
const SHADER_ROOT: String = "res://assets/shaders/style_lab/"
const STYLE_NAMES: Array[String] = ["TOON + OUTLINE", "SOFT CLAY", "BOLD FLAT"]
const STYLE_SHADERS: Array[String] = ["toon", "clay", "flat"]
const STYLE_SHADOWS: Array[Color] = [Color("44446b"), Color("9a829b"), Color("43368c")]
const STYLE_BACKGROUNDS: Array[Color] = [Color("bfe3f2"), Color("e9d9da"), Color("88bfe8")]
const STYLE_WOOD: Array[Color] = [Color("e4a35f"), Color("dcb9a0"), Color("f3b34d")]
const STYLE_ENERGY: Array[float] = [0.85, 0.8, 0.9]
const STYLE_AMBIENT: Array[float] = [0.25, 0.38, 0.12]
const ROBOT_POSITION: Vector3 = Vector3(0.0, 0.0, -0.85)
const WHEEL_X: float = 0.285
const WHEEL_Z: float = 0.245
const BASKET_POSITION: Vector3 = Vector3(0.0, 0.52, 0.225)
const CARGO_SCALE: float = 1.7
const ESPRESSO_POSITION: Vector3 = Vector3(-0.09, 0.75, 0.20)
const BATTERY_POSITION: Vector3 = Vector3(0.075, 0.75, 0.25)
const BATTERY_ROTATION: Vector3 = Vector3(0.0, 20.0, -42.0)
const SD_CARD_POSITION: Vector3 = Vector3(0.08, 0.75, 0.13)
const SD_CARD_ROTATION: Vector3 = Vector3(-66.0, -15.0, 0.0)
const KEYBOARD_FRONT_POSITION: Vector3 = Vector3(0.95, 0.0, 1.0)
const KEYBOARD_BACK_POSITION: Vector3 = Vector3(0.95, 0.0, 2.02)
const MUG_POSITION: Vector3 = Vector3(-1.75, 0.0, 1.3)
const MUG_YAW: float = -40.0
const BOOK_POSITION: Vector3 = Vector3(-2.05, 0.0, -1.20)
const BOOK_SCALE: float = 0.32
const BOOK_YAW: float = -12.0
const PENCIL_POSITION: Vector3 = Vector3(1.65, 0.0, -0.9)
const PENCIL_SCALE: float = 0.28
const PENCIL_YAW: float = -18.0
const TABLE_SIZE: Vector3 = Vector3(7.2, 0.22, 6.8)
const TABLE_CENTER: Vector3 = Vector3(0.0, -0.11, 0.0)
const WALL_SIZE: Vector3 = Vector3(18.0, 9.0, 0.18)
const WALL_CENTER: Vector3 = Vector3(0.0, 3.0, 4.4)
const WINDOW_SIZE: Vector3 = Vector3(2.5, 2.6, 0.05)
const WINDOW_CENTER: Vector3 = Vector3(-2.1, 2.3, 4.27)
const WINDOW_BAR_WIDTH: float = 0.075
const WINDOW_VERTICAL_OFFSET: Vector3 = Vector3(0.0, 0.0, -0.05)
const WINDOW_HORIZONTAL_OFFSET: Vector3 = Vector3(0.0, 0.0, -0.06)
const WINDOW_LIGHT_COLOR: Color = Color("fff1cd")
const WINDOW_BAR_COLOR: Color = Color("faf0dd")
const WIDE_TARGET: Vector3 = Vector3(0.0, 0.65, 0.0)
const CLOSE_TARGET: Vector3 = Vector3(0.0, 0.40, -0.80)
const CAMERA_OFFSET: Vector3 = Vector3(4.6, 5.6, -8.2)
const WIDE_SIZE: float = 10.4
const CLOSE_SIZE: float = 2.05
const LIGHT_ROTATION: Vector3 = Vector3(-48.0, -145.0, 0.0)
const LIGHT_COLOR: Color = Color("fff0d3")
const AMBIENT_COLOR: Color = Color("d3e5f5")
const LIGHT_SHADOW_DISTANCE: float = 24.0
const LIGHT_SOFT_BLUR: float = 3.0
const LIGHT_HARD_BLUR: float = 0.2
const BLOOM_INTENSITY: float = 0.06
const BLOOM_THRESHOLD: float = 1.1
const OUTLINE_WIDTH: float = 0.003
const INK_COLOR: Color = Color("20283e")
const SOFT_BLEND: float = 0.20
const SOFT_PAPER: Color = Color("f3dfd4")
const FLAT_SATURATION: float = 1.18
const FLAT_VALUE: float = 1.02
const BLOB_HEIGHT: float = 0.008
const ROBOT_BLOB_SIZE: Vector2 = Vector2(0.95, 1.1)
const MUG_BLOB_SIZE: Vector2 = Vector2(2.0, 1.7)
const KEYBOARD_BLOB_SIZE: Vector2 = Vector2(2.6, 1.0)
const UI_PANEL_OFFSET: Vector2 = Vector2(24.0, 24.0)
const UI_PANEL_SIZE: Vector2 = Vector2(960.0, 155.0)
const UI_PANEL_COLOR: Color = Color("fff0dfe8")
const UI_MARGIN: float = 48.0
const UI_TITLE_SIZE: int = 52
const UI_BODY_SIZE: int = 22
const UI_INK: Color = Color("23334c")
const UI_SUBTITLE_GAP: float = 72.0
const UI_ALPHABET_START: int = 65

@export_enum("A: Toon + Outline", "B: Soft Clay", "C: Bold Flat") var style_index: int = Style.TOON
@export var close_frame: bool = false
var _materials: Dictionary[String, ShaderMaterial] = {}
var _outline: ShaderMaterial

func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--style="):
			style_index = clampi(STYLE_ARGUMENTS.find(argument.trim_prefix("--style=")), Style.TOON, Style.FLAT)
		elif argument == "--frame=close":
			close_frame = true
	if style_index == Style.TOON:
		_outline = ShaderMaterial.new()
		_outline.shader = load(SHADER_ROOT + "outline.gdshader") as Shader
		_outline.set_shader_parameter("width", OUTLINE_WIDTH)
		_outline.set_shader_parameter("ink_color", INK_COLOR)
	_build_environment()
	_build_composition()
	_build_camera()
	_build_caption()

func _build_composition() -> void:
	_box("Desk", TABLE_SIZE, TABLE_CENTER, STYLE_WOOD[style_index])
	_box("RoomWall", WALL_SIZE, WALL_CENTER, STYLE_BACKGROUNDS[style_index])
	_box("WindowLight", WINDOW_SIZE, WINDOW_CENTER, WINDOW_LIGHT_COLOR)
	_box("WindowVertical", Vector3(WINDOW_BAR_WIDTH, WINDOW_SIZE.y, WINDOW_SIZE.z), WINDOW_CENTER + WINDOW_VERTICAL_OFFSET, WINDOW_BAR_COLOR)
	_box("WindowHorizontal", Vector3(WINDOW_SIZE.x, WINDOW_BAR_WIDTH, WINDOW_SIZE.z), WINDOW_CENTER + WINDOW_HORIZONTAL_OFFSET, WINDOW_BAR_COLOR)
	var robot: Node3D = Node3D.new()
	robot.name = "RobotDisplay"
	robot.position = ROBOT_POSITION
	add_child(robot)
	_model("robot_body", Vector3.ZERO, robot)
	for x: float in [-WHEEL_X, WHEEL_X]:
		for z: float in [-WHEEL_Z, WHEEL_Z]:
			_model("robot_wheel", Vector3(x, 0.0, z), robot)
	_model("cargo_basket", BASKET_POSITION, robot)
	var cargo: Node3D = _model("cargo_espresso_capsule", ESPRESSO_POSITION, robot)
	cargo.scale = Vector3.ONE * CARGO_SCALE
	cargo = _model("cargo_pencil_battery", BATTERY_POSITION, robot)
	cargo.scale = Vector3.ONE * CARGO_SCALE
	cargo.rotation_degrees = BATTERY_ROTATION
	cargo = _model("cargo_sd_card", SD_CARD_POSITION, robot)
	cargo.scale = Vector3.ONE * CARGO_SCALE
	cargo.rotation_degrees = SD_CARD_ROTATION
	_model("prop_keyboard_row", KEYBOARD_FRONT_POSITION, self)
	_model("prop_keyboard_row", KEYBOARD_BACK_POSITION, self)
	var mug: Node3D = _model("prop_mug", MUG_POSITION, self)
	mug.rotation_degrees.y = MUG_YAW
	var book: Node3D = _model("prop_book", BOOK_POSITION, self)
	book.scale = Vector3.ONE * BOOK_SCALE
	book.rotation_degrees.y = BOOK_YAW
	var pencil: Node3D = _model("prop_pencil", PENCIL_POSITION, self)
	pencil.scale = Vector3.ONE * PENCIL_SCALE
	pencil.rotation_degrees.y = PENCIL_YAW
	if style_index == Style.CLAY:
		_blob(ROBOT_POSITION, ROBOT_BLOB_SIZE)
		_blob(MUG_POSITION, MUG_BLOB_SIZE)
		_blob(KEYBOARD_FRONT_POSITION, KEYBOARD_BLOB_SIZE)
		_blob(KEYBOARD_BACK_POSITION, KEYBOARD_BLOB_SIZE)

func _model(asset: String, location: Vector3, parent_node: Node3D) -> Node3D:
	var packed: PackedScene = load(MODEL_ROOT + asset + ".glb") as PackedScene
	var instance: Node3D = packed.instantiate() as Node3D
	parent_node.add_child(instance)
	instance.position = location
	_restyle(instance)
	return instance

func _restyle(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_node: MeshInstance3D = node as MeshInstance3D
		for surface: int in range(mesh_node.mesh.get_surface_count()):
			var source: StandardMaterial3D = mesh_node.mesh.surface_get_material(surface) as StandardMaterial3D
			if source != null:
				mesh_node.set_surface_override_material(surface, _material(source.albedo_color))
	for child: Node in node.get_children():
		_restyle(child)

func _material(original: Color) -> ShaderMaterial:
	var color: Color = original
	if style_index == Style.CLAY:
		color = color.lerp(SOFT_PAPER, SOFT_BLEND)
	elif style_index == Style.FLAT:
		color = Color.from_hsv(color.h, minf(color.s * FLAT_SATURATION, 1.0), minf(color.v * FLAT_VALUE, 1.0))
	var key: String = color.to_html()
	if _materials.has(key):
		return _materials[key]
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(SHADER_ROOT + STYLE_SHADERS[style_index] + ".gdshader") as Shader
	material.set_shader_parameter("base_color", color)
	material.set_shader_parameter("shadow_color", STYLE_SHADOWS[style_index])
	if style_index == Style.TOON:
		material.next_pass = _outline
	_materials[key] = material
	return material

func _box(node_name: String, size: Vector3, location: Vector3, color: Color) -> void:
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	mesh_node.mesh = box
	mesh_node.name = node_name
	mesh_node.position = location
	mesh_node.material_override = _material(color)
	# Oda ipucu ışığı engelleyen bir kutuya dönüşmemeli.
	if node_name != "Desk":
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var backdrop: StandardMaterial3D = StandardMaterial3D.new()
		backdrop.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		backdrop.albedo_color = color
		mesh_node.material_override = backdrop
	add_child(mesh_node)

func _blob(location: Vector3, size: Vector2) -> void:
	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = size
	mesh_node.mesh = plane
	mesh_node.position = location + Vector3.UP * BLOB_HEIGHT
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = load(SHADER_ROOT + "blob.gdshader") as Shader
	mesh_node.material_override = material
	add_child(mesh_node)

func _build_environment() -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = STYLE_BACKGROUNDS[style_index]
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = AMBIENT_COLOR
	environment.ambient_light_energy = STYLE_AMBIENT[style_index]
	environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# LUT ve ekran örneklemesi yok; bloom kapansa bile kil malzemesi okunur kalır.
	environment.glow_enabled = style_index == Style.CLAY
	environment.glow_intensity = BLOOM_INTENSITY
	environment.glow_hdr_threshold = BLOOM_THRESHOLD
	world.environment = environment
	add_child(world)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = LIGHT_ROTATION
	light.light_color = LIGHT_COLOR
	light.light_energy = STYLE_ENERGY[style_index]
	light.shadow_enabled = true
	light.shadow_blur = LIGHT_SOFT_BLUR if style_index == Style.CLAY else LIGHT_HARD_BLUR
	light.directional_shadow_max_distance = LIGHT_SHADOW_DISTANCE
	add_child(light)

func _build_camera() -> void:
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = CLOSE_SIZE if close_frame else WIDE_SIZE
	var target: Vector3 = CLOSE_TARGET if close_frame else WIDE_TARGET
	camera.position = target + CAMERA_OFFSET
	add_child(camera)
	camera.look_at(target)
	camera.current = true

func _build_caption() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	# Yakın karede kupanın koyu gölgesi başlığı okunmaz hale getirmesin.
	var panel: ColorRect = ColorRect.new()
	panel.position = UI_PANEL_OFFSET
	panel.size = UI_PANEL_SIZE
	panel.color = UI_PANEL_COLOR
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var title: Label = Label.new()
	title.text = "%s / %s" % [String.chr(UI_ALPHABET_START + style_index), STYLE_NAMES[style_index]]
	title.position = Vector2(UI_MARGIN, UI_MARGIN)
	title.add_theme_font_size_override("font_size", UI_TITLE_SIZE)
	title.add_theme_color_override("font_color", UI_INK)
	layer.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.text = "MICRO COURIER   /   STYLE LAB 01   /   " + ("DETAIL" if close_frame else "DESK DIORAMA")
	subtitle.position = Vector2(UI_MARGIN, UI_MARGIN + UI_SUBTITLE_GAP)
	subtitle.add_theme_font_size_override("font_size", UI_BODY_SIZE)
	subtitle.add_theme_color_override("font_color", UI_INK)
	layer.add_child(subtitle)
