class_name SkinStore
extends RefCounted

## SkinCatalog ile `Progress` arasındaki ince köprü (MetaStore ile aynı desen): alınan kaplamalar
## ve seçimler modül "skins" altında tutulur; koleksiyondan açılanlar modül "meta" -> "cosmetics"tir.
## `Progress` düğümü enjekte edilebilir (testler gerçek kaydı ezmez; `-s` kipinde autoload adı
## derlemede çözülmediği için düğüme yol + `call()` ile erişilir).

const SECTION: String = "skins"
const KEY_OWNED: String = "owned"
const KEY_PIN: String = "pin"
const KEY_ROPE: String = "rope"
const META_SECTION: String = "meta"
const META_COSMETICS: String = "cosmetics"
const PROGRESS_PATH: NodePath = ^"/root/Progress"

var catalog: SkinCatalog = null
var _progress: Node = null


func _init(progress_node: Node = null, skin_catalog: SkinCatalog = null) -> void:
	_progress = progress_node if progress_node != null else _find_progress()
	catalog = skin_catalog if skin_catalog != null else SkinCatalog.load_default()


static func _find_progress() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null(PROGRESS_PATH)


func purchased() -> Array:
	var raw: Variant = _value(SECTION, KEY_OWNED, [])
	return (raw as Array).duplicate() if raw is Array else []


func cosmetics() -> Array:
	var raw: Variant = _value(META_SECTION, META_COSMETICS, [])
	return (raw as Array).duplicate() if raw is Array else []


func is_available(id: String) -> bool:
	return catalog.is_available(id, purchased(), cosmetics())


func selected(kind: String) -> String:
	var key: String = KEY_PIN if kind == SkinCatalog.KIND_PIN else KEY_ROPE
	return catalog.resolve_selected(kind, String(_value(SECTION, key, "")), purchased(), cosmetics())


## Seçer; sahip olunmayan kaplama seçilemez.
func select(id: String) -> bool:
	if not is_available(id) or _progress == null:
		return false
	var kind: String = catalog.kind_of(id)
	_progress.call("set_module_value", SECTION, KEY_PIN if kind == SkinCatalog.KIND_PIN else KEY_ROPE, id)
	return true


func can_buy(id: String) -> bool:
	return catalog.source_type(id) == SkinCatalog.SOURCE_COINS and not is_available(id) \
		and _coins() >= catalog.price(id)


## Jetonla alır (tek kayıtta jeton düşer + sahiplik yazılır) ve seçer.
func buy(id: String) -> bool:
	if _progress == null or catalog.source_type(id) != SkinCatalog.SOURCE_COINS or is_available(id):
		return false
	var owned: Array = purchased()
	owned.append(id)
	if not bool(_progress.call("purchase_module_value", catalog.price(id), SECTION, KEY_OWNED, owned)):
		return false
	select(id)
	return true


func _coins() -> int:
	return int(_progress.call("coins")) if _progress != null else 0


func _value(section: String, key: String, fallback: Variant) -> Variant:
	if _progress == null:
		return fallback
	return _progress.call("module_value", section, key, fallback)
