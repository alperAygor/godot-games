extends TestCase

## MetaStore: Progress ile köprü (yıldız harcama, mekân jetonu, "meta" modülüne kayıt).
## Gerçek kayda dokunmamak için diske yazmayan (persist=false) ayrı bir Progress örneği kullanılır.

var _progress: Node = null
var _catalog: MetaCatalog = null


func before_each() -> void:
	var script: GDScript = load("res://scripts/autoload/Progress.gd") as GDScript
	_progress = script.new()
	_progress.set("persist", false)
	_progress.set("save_path", "user://test_meta_never_written.json")
	_progress.set("balance", ProgressData.load_balance())
	_catalog = MetaCatalog.from_dicts({
		"locations": [
			{"id": "a", "art": true, "completion_coins": 300, "tasks": [{"id": "floor", "cost": 1}, {"id": "wall", "cost": 2}]},
			{"id": "b", "tasks": [{"id": "floor", "cost": 1}]},
		],
	}, {"levels_per_piece": 10, "sets": [{"id": "s", "reward": "pin_x", "pieces": [{}, {}]}]})


func after_each() -> void:
	_progress.free()


func test_renovate_requires_stars() -> void:
	var store: MetaStore = MetaStore.new(_progress, _catalog)
	var result: Dictionary = store.renovate_next()
	assert_false(bool(result["ok"]))
	assert_eq(store.state.next_task(_catalog), 0, "yıldız yokken görev bitmez")


func test_renovate_spends_stars_and_saves_under_meta() -> void:
	_progress.call("add_stars", 5)
	var store: MetaStore = MetaStore.new(_progress, _catalog)
	var result: Dictionary = store.renovate_next()
	assert_true(bool(result["ok"]))
	assert_eq(int(result["task"]), 0)
	assert_eq(int(_progress.call("stars")), 4)
	var saved: Variant = _progress.call("module_value", "meta", "state", {})
	assert_true(saved is Dictionary, "durum 'meta' bölümünde")
	var again: MetaStore = MetaStore.new(_progress, _catalog)
	assert_eq(again.state.done_count(_catalog, 0), 1, "yeniden yüklenince korunur")


func test_completing_location_grants_coins_once() -> void:
	_progress.call("add_stars", 10)
	var coins_before: int = int(_progress.call("coins"))
	var store: MetaStore = MetaStore.new(_progress, _catalog)
	store.renovate_next()
	var last: Dictionary = store.renovate_next()
	assert_eq(int(last["bonus"]), 300)
	assert_eq(int(_progress.call("coins")), coins_before + 300)
	assert_eq(store.state.current_location(_catalog), 1)
	assert_eq(int(_progress.call("stars")), 7)


func test_variant_change_is_free_and_persisted() -> void:
	_progress.call("add_stars", 1)
	var store: MetaStore = MetaStore.new(_progress, _catalog)
	store.renovate_next()
	assert_true(store.set_variant(0, 0, 2))
	assert_eq(int(_progress.call("stars")), 0)
	assert_eq(MetaStore.new(_progress, _catalog).state.variant(_catalog, 0, 0), 2)


func test_collection_sync_records_cosmetic() -> void:
	var data: ProgressData = _progress.get("data") as ProgressData
	data.level = 21
	var store: MetaStore = MetaStore.new(_progress, _catalog)
	assert_eq(store.unseen_pieces(), 2)
	assert_eq(store.sync_collection(), ["pin_x"] as Array[String])
	var cosmetics: Variant = _progress.call("module_value", "meta", "cosmetics", [])
	assert_true(cosmetics is Array and (cosmetics as Array).size() == 1)
	assert_eq(str((cosmetics as Array)[0]), "pin_x")
