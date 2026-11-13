class_name MetaUi
extends RefCounted

## Meta ekranlarının ortak küçük parçaları: üst çubuk (geri + yıldız), yuvarlak maske,
## yüzen alt kart. Düz, çizgisiz, az metin — ana ekranla aynı dil (UiKit/UiChip/UiIconButton).

const LAYER: int = 40
const CARD_SIDE_GAP: float = 32.0
const ICON_LOCK_PATH: String = "res://assets/sprites/meta/icon_lock.svg"
## Küçük resimler için yumuşak kenarlı daire maskesi (kenar ~%2 yumuşatılır: tırtıksız).
const CIRCLE_MASK_CODE: String = """
shader_type canvas_item;
uniform float softness = 0.02;
void fragment() {
	float d = distance(UV, vec2(0.5));
	COLOR = texture(TEXTURE, UV) * COLOR;
	COLOR.a *= 1.0 - smoothstep(0.5 - softness, 0.5, d);
}
"""

## Dokunun yalnız bir BÖLGESİNİ daire içinde gösterir (kare kesit). NEDEN shader: GPU-sıkıştırmalı
## (ASTC/BPTC) oda katmanını CPU'da açıp kırpmak bozuk/gürültülü görüntü veriyordu; burada doku olduğu
## gibi GPU'da örneklenir, kopya/çözme yok. `region`: UV uzayında (x, y, genişlik, yükseklik).
const REGION_MASK_CODE: String = """
shader_type canvas_item;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
uniform float softness = 0.02;
void fragment() {
	float d = distance(UV, vec2(0.5));
	vec4 sampled = texture(TEXTURE, region.xy + UV * region.zw);
	COLOR = sampled * COLOR;
	COLOR.a *= 1.0 - smoothstep(0.5 - softness, 0.5, d);
}
"""

static var _mask_shader: Shader = null
static var _region_shader: Shader = null


## Sol üstte geri düğmesi (dokunma alanı 126 px, görsel disk 88 px).
static func back_button(view: Vector2, insets: Vector4) -> UiIconButton:
	var button: UiIconButton = UiIconButton.new()
	button.setup("lucide/arrow-left")
	button.position = Vector2(insets.x + UiKit.SIDE_MARGIN - (UiKit.MIN_TOUCH - UiIconButton.DISC_DIAMETER) * 0.5,
		insets.y)
	button.size = Vector2(UiKit.MIN_TOUCH, UiKit.MIN_TOUCH)
	return button


## Sağ üstte sayaç hapı; konum, hap boyutu belli olduktan sonra `place_right` ile verilir.
static func counter_chip(icon: String, color: Color) -> UiChip:
	var chip: UiChip = UiChip.new()
	chip.setup(icon, color)
	return chip


static func place_right(chip: Control, view: Vector2, insets: Vector4) -> void:
	var chip_size: Vector2 = chip.get_combined_minimum_size()
	chip.size = chip_size
	chip.position = Vector2(view.x - insets.z - UiKit.SIDE_MARGIN - chip_size.x,
		insets.y + (UiKit.MIN_TOUCH - chip_size.y) * 0.5)


static func circle_mask() -> ShaderMaterial:
	if _mask_shader == null:
		_mask_shader = Shader.new()
		_mask_shader.code = CIRCLE_MASK_CODE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _mask_shader
	return material


static func circle_region_mask(region: Rect2) -> ShaderMaterial:
	if _region_shader == null:
		_region_shader = Shader.new()
		_region_shader.code = REGION_MASK_CODE
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _region_shader
	material.set_shader_parameter("region", Vector4(region.position.x, region.position.y, region.size.x, region.size.y))
	return material


## Düz renkli daire (çizgisiz) — küçük resim zemini, renk örneği, ikon diski.
static func disc(diameter: float, color: Color) -> Panel:
	var panel: Panel = Panel.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(diameter * 0.5))
	box.anti_aliasing = true
	panel.add_theme_stylebox_override("panel", box)
	panel.custom_minimum_size = Vector2(diameter, diameter)
	panel.size = Vector2(diameter, diameter)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


## Düz yuvarlatılmış yüzey (kart içi karo).
static func tile_style(color: Color, radius: int, pad_x: int, pad_y: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	box.content_margin_left = pad_x
	box.content_margin_right = pad_x
	box.content_margin_top = pad_y
	box.content_margin_bottom = pad_y
	return box


static func lock_icon(pixels: float, color: Color) -> TextureRect:
	var node: TextureRect = TextureRect.new()
	node.texture = load(ICON_LOCK_PATH) as Texture2D
	node.custom_minimum_size = Vector2(pixels, pixels)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.modulate = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node


## Autoload ses servisi varsa çalar (araç/önizleme ortamında yoksa sessizce geçer).
static func play_sound(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return
	var audio: Node = loop.root.get_node_or_null("AudioService")
	if audio != null and audio.has_method("play_pitched"):
		audio.call("play_pitched", sound, pitch, volume_db)


## Geri tuşu sinyaline bağlanır (GameManager varsa).
static func connect_back(callable: Callable) -> void:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return
	var manager: Node = loop.root.get_node_or_null("GameManager")
	if manager != null and manager.has_signal("back_requested") and not manager.is_connected("back_requested", callable):
		manager.connect("back_requested", callable)
