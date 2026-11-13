class_name MetaStore
extends RefCounted

## MetaState ile `Progress` autoload'u arasındaki ince köprü: durumu "meta" modülüne yazar,
## yıldız harcar, jeton verir. Sahneler YALNIZ bunu çağırır; kural MetaState'tedir.
## NEDEN `Progress` düğümü enjekte edilir: testler gerçek kaydı ezmeden (persist=false)
## kendi Progress örneğini verir; `-s` kipinde autoload adları derlemede çözülemediği için
## düğüme `/root/Progress` yolundan ve `call()` ile erişilir (UiData ile aynı yaklaşım).

const SECTION: String = "meta"
const KEY_STATE: String = "state"
## Oyunun geri kalanı (ör. ileride ip/mandal kaplaması) açılan kozmetikleri buradan okur.
const KEY_COSMETICS: String = "cosmetics"
const PROGRESS_PATH: NodePath = ^"/root/Progress"
## Progress yokken (araç/önizleme) kullanılan varsayılanlar.
const FALLBACK_LEVEL: int = 1

var catalog: MetaCatalog = null
var state: MetaState = null
var _progress: Node = null


func _init(progress_node: Node = null, meta_catalog: MetaCatalog = null) -> void:
	_progress = progress_node if progress_node != null else find_progress()
	catalog = meta_catalog if meta_catalog != null else MetaCatalog.load_default()
	state = load_state()


static func find_progress() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null(PROGRESS_PATH)


func progress() -> Node:
	return _progress if is_instance_valid(_progress) else null


func load_state() -> MetaState:
	var node: Node = progress()
	if node == null:
		return MetaState.new()
	return MetaState.from_dict(node.call("module_value", SECTION, KEY_STATE, {}))


func save() -> void:
	var node: Node = progress()
	if node == null:
		return
	node.call("set_module_value", SECTION, KEY_COSMETICS, state.cosmetics.duplicate())
	node.call("set_module_value", SECTION, KEY_STATE, state.to_dict())


func stars() -> int:
	var node: Node = progress()
	return maxi(int(node.call("stars")), 0) if node != null else 0


func coins() -> int:
	var node: Node = progress()
	return maxi(int(node.call("coins")), 0) if node != null else 0


func level() -> int:
	var node: Node = progress()
	return maxi(int(node.call("level")), FALLBACK_LEVEL) if node != null else FALLBACK_LEVEL


## Sıradaki tadilat görevini satın alır: yıldızı harcar, görevi bitirir (varyant 0), kaydeder.
## Mekân bu görevle bittiyse tamamlama jetonu verilir ve sıradaki mekâna geçilir.
## Dönen: {"ok": bool, "task": int, "location": int, "bonus": int}
func renovate_next() -> Dictionary:
	var index: int = state.current_location(catalog)
	var result: Dictionary = {"ok": false, "task": -1, "location": index, "bonus": 0}
	var task: int = state.next_task(catalog)
	var node: Node = progress()
	if task < 0 or node == null:
		return result
	if not bool(node.call("spend_stars", state.next_cost(catalog))):
		return result
	state.complete_next(catalog, 0)
	result["ok"] = true
	result["task"] = task
	var bonus: int = state.claim_bonus(catalog) if state.is_location_complete(catalog, index) else 0
	if bonus > 0:
		node.call("add_coins", bonus)
	result["bonus"] = bonus
	save()
	return result


func set_variant(index: int, task: int, value: int) -> bool:
	if not state.set_variant(catalog, index, task, value):
		return false
	save()
	return true


## Koleksiyonu seviyeyle eşitler; yeni açılan kozmetik id'lerini döner (ve kaydeder).
func sync_collection() -> Array[String]:
	var unlocked: Array[String] = state.sync_collection(catalog, level())
	save()
	return unlocked


func unseen_pieces() -> int:
	return state.unseen_pieces(catalog, level())


## Ana ekran rozeti için: tadilata yetecek yıldız var mı (bildirim noktası).
func can_renovate() -> bool:
	return catalog.location_has_art(state.current_location(catalog)) and state.can_afford_next(catalog, stars())


## Oyunun geri kalanı için: açılmış kozmetikler (kaydı açmadan okunur).
static func unlocked_cosmetics() -> Array[String]:
	var result: Array[String] = []
	var node: Node = find_progress()
	if node == null:
		return result
	var raw: Variant = node.call("module_value", SECTION, KEY_COSMETICS, [])
	if raw is Array:
		for entry: Variant in raw as Array:
			result.append(str(entry))
	return result
