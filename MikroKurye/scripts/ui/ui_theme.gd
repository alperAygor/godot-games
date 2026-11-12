class_name UiTheme
extends RefCounted

## Tema token'larına tek erişim noktası. Renk/ölçü `data/theme.json` içinde durur;
## UI kodu renk sabiti taşımaz (F7.6b). Kaynak, `tools/build_theme.py`'nin ürettiği
## `ui_theme.tres` ile AYNI dosyadır; böylece sabit değer iki yerde yaşamaz.
##
## `GameData` autoload'ı kimlikle değil `/root` yoluyla okunur (`-s` probunda
## derleme sırası farklıdır; GOTCHAS.md #2).

const THEME_TABLE: String = "theme"


static func color(key: String, alpha: float = 1.0) -> Color:
	var raw: Variant = palette().get(key, "#FFFFFF")
	return _hex(str(raw), alpha)


## Ölçü token'ı; yoksa verilen varsayılan döner (kırık temada çökme olmasın).
static func metric(key: String, fallback: float) -> float:
	var raw: Variant = metrics().get(key, fallback)
	if typeof(raw) == TYPE_INT:
		return float(int(raw))
	if typeof(raw) == TYPE_FLOAT:
		return float(raw)
	return fallback


static func palette() -> Dictionary:
	var theme: Dictionary = _theme()
	var found: Variant = theme.get("palette", {})
	return found as Dictionary if found is Dictionary else {}


## Sık kullanılan stil kutusu: kart/cip/pill. Renkler token'dan gelir; UI kodu
## renk sabiti taşımaz (F7.6b). `border_alpha <= 0` ise çizgi çizilmez.
static func stylebox(bg_key: String, border_key: String, radius: int,
		bg_alpha: float = 1.0, border_alpha: float = 0.0,
		shadow: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color(bg_key, bg_alpha)
	sb.border_color = color(border_key, border_alpha)
	if border_alpha > 0.0:
		sb.set_border_width_all(int(metric("border", 1.0)))
	sb.set_corner_radius_all(radius)
	if shadow:
		sb.shadow_color = color("text", metric("shadow_opacity", 0.1))
		sb.shadow_size = int(metric("shadow_size", 24.0))
		sb.shadow_offset = Vector2(0.0, metric("shadow_offset_y", 8.0))
	return sb


static func metrics() -> Dictionary:
	var theme: Dictionary = _theme()
	var found: Variant = theme.get("metrics", {})
	return found as Dictionary if found is Dictionary else {}


static func _theme() -> Dictionary:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null:
		return {}
	var tree: SceneTree = loop as SceneTree
	if tree == null or tree.root == null:
		return {}
	var data: Node = tree.root.get_node_or_null("/root/GameData")
	if data != null and data.has_method("table"):
		var table: Variant = data.call("table", THEME_TABLE)
		return table as Dictionary if table is Dictionary else {}
	return {}


static func _hex(value: String, alpha: float) -> Color:
	var clean: String = value.trim_prefix("#")
	if clean.length() != 6:
		return Color(1.0, 1.0, 1.0, alpha)
	if not clean.is_valid_hex_number():
		return Color(1.0, 1.0, 1.0, alpha)
	var num: int = clean.hex_to_int()
	var r: float = float((num >> 16) & 0xFF) / 255.0
	var g: float = float((num >> 8) & 0xFF) / 255.0
	var b: float = float(num & 0xFF) / 255.0
	return Color(r, g, b, alpha)
