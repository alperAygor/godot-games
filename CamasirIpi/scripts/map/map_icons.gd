class_name MapIcons
extends RefCounted

## Harita/zen/ağ özelliğinin kendi küçük ikonları (assets/icons/q_map). Neden ayrı: ortak ikon
## tablosu (data/icons.json) başka işçinin; burada yalnız bu özelliğin ikonları yaşar. "lucide/..."
## adları ortak tabloya devredilir, böylece tek çağrıyla her ikon alınır. İkonlar beyaz üretilir;
## renk `modulate` ile verilir.

const FOLDER: String = "res://assets/icons/q_map/%s.svg"
const SHARED_PREFIX: String = "lucide/"

static var _cache: Dictionary[String, Texture2D] = {}


static func texture(name: String) -> Texture2D:
	if name.begins_with(SHARED_PREFIX):
		return Icons.texture(name)
	if _cache.has(name):
		return _cache[name]
	var loaded: Texture2D = load(FOLDER % name) as Texture2D
	if loaded == null:
		push_warning("MapIcons: '%s' ikonu yok" % name)
		return null
	_cache[name] = loaded
	return loaded


static func rect(name: String, pixels: float, color: Color) -> TextureRect:
	var node: TextureRect = TextureRect.new()
	node.texture = texture(name)
	node.custom_minimum_size = Vector2(pixels, pixels)
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.modulate = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return node
