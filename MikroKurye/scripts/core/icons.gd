class_name Icons
extends RefCounted

## `data/icons.json` tablosundan ikon yukler ve onbellege alir.
## Lucide ikonlari BEYAZ uretilir; renk Button.modulate veya tema rengiyle verilir.

const TABLE_PATH: String = "res://data/icons.json"

static var _table: Dictionary = {}
static var _cache: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(TABLE_PATH):
		push_warning("Icons: %s yok (tools/icons.py fetch-lucide)" % TABLE_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
	if parsed is Dictionary:
		_table = parsed as Dictionary


static func has_icon(name: String) -> bool:
	_ensure_loaded()
	return _table.has(name)


static func names() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for key: Variant in _table.keys():
		result.append(String(key))
	result.sort()
	return result


static func texture(name: String) -> Texture2D:
	_ensure_loaded()
	if _cache.has(name):
		return _cache[name] as Texture2D
	if not _table.has(name):
		push_warning("Icons: '%s' tabloda yok" % name)
		return null
	var texture2d: Texture2D = load(String(_table[name])) as Texture2D
	_cache[name] = texture2d
	return texture2d


## Butona ikon + renk uygular. Hover/pressed durumlari da ayni renge cekilir.
static func apply(button: Button, name: String, color: Color = Color.WHITE,
		icon_size: int = 0) -> void:
	var texture2d: Texture2D = texture(name)
	if texture2d == null:
		return
	button.icon = texture2d
	button.add_theme_color_override("icon_normal_color", color)
	button.add_theme_color_override("icon_hover_color", color)
	button.add_theme_color_override("icon_pressed_color", color)
	if icon_size > 0:
		button.add_theme_constant_override("icon_max_width", icon_size)
