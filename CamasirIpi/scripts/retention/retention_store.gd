class_name RetentionStore
extends RefCounted

## Tutundurma durumunun `Progress` modül bölümü ("retention") üstündeki ince sarmalayıcısı.
## `Progress` autoload'una yalnız çalışma anında ve `get_node_or_null` ile bağlanır (UiData gibi):
## -s kipindeki prob/testlerde autoload kimliği derleme anında çözülemez.
## Testler `progress_override` ile kendi Progress örneğini verir; `today_override` ile "bugün" enjekte edilir.

const SECTION: String = "retention"
const PROGRESS_PATH: NodePath = ^"/root/Progress"
const KEY_SEEN_EVENTS: String = "seen_events"
const MAX_SEEN_EVENTS: int = 64

static var progress_override: Node = null
static var today_override: String = ""


static func progress() -> Node:
	if progress_override != null and is_instance_valid(progress_override):
		return progress_override
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	if loop == null:
		return null
	return loop.root.get_node_or_null(PROGRESS_PATH)


static func today() -> String:
	return today_override if not today_override.is_empty() else DailyDate.today_key()


static func level() -> int:
	var node: Node = progress()
	return int(node.call("level")) if node != null else 1


static func balance() -> Dictionary:
	var node: Node = progress()
	return node.call("balance_table") as Dictionary if node != null else {}


static func unlock_levels() -> Dictionary:
	var table: Variant = balance().get("booster_unlock_level", {})
	return table as Dictionary if table is Dictionary else {}


static func fallback_coins() -> int:
	return int(RetentionData.core().get("booster_fallback_coins", 0))


static func get_dict(key: String) -> Dictionary:
	var node: Node = progress()
	if node == null:
		return {}
	var value: Variant = node.call("module_value", SECTION, key, {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func put(key: String, value: Variant) -> void:
	var node: Node = progress()
	if node != null:
		node.call("set_module_value", SECTION, key, value)


static func get_int(key: String, fallback: int = 0) -> int:
	var node: Node = progress()
	return int(node.call("module_value", SECTION, key, fallback)) if node != null else fallback


## Ödülü gerçekten verir (jeton/yıldız/güçlendirici).
static func grant(reward: Dictionary) -> void:
	var node: Node = progress()
	if node == null:
		return
	var coins: int = int(reward.get("coins", 0))
	if coins > 0:
		node.call("add_coins", coins)
	var stars: int = int(reward.get("stars", 0))
	if stars > 0:
		node.call("add_stars", stars)
	var boosters: Variant = reward.get("boosters", {})
	if boosters is Dictionary:
		for id: Variant in (boosters as Dictionary).keys():
			var count: int = int((boosters as Dictionary)[id])
			if count > 0:
				node.call("add_booster", String(id), count)


## Şablonu oyuncunun seviyesine göre somut ödüle çevirir.
static func resolve(template: Dictionary, salt: int) -> Dictionary:
	return RetentionRewards.resolve(template, level(), salt, unlock_levels(), fallback_coins())


## Yayınlanmış (oyunda var olduğu görülmüş) olaylar: isteğe bağlı görevler buna bakar.
static func live_events() -> Dictionary:
	var live: Dictionary = {}
	for id: Variant in RetentionData.missions().get("core_events", []) as Array:
		live[String(id)] = true
	var node: Node = progress()
	if node != null:
		var seen: Variant = node.call("module_value", SECTION, KEY_SEEN_EVENTS, [])
		if seen is Array:
			for id: Variant in seen as Array:
				live[String(id)] = true
	return live


static func mark_event_seen(event_id: String) -> void:
	if event_id.is_empty() or bool(live_events().get(event_id, false)):
		return
	var node: Node = progress()
	if node == null:
		return
	var seen: Array = []
	var stored: Variant = node.call("module_value", SECTION, KEY_SEEN_EVENTS, [])
	if stored is Array:
		seen = (stored as Array).duplicate()
	if seen.size() < MAX_SEEN_EVENTS:
		seen.append(event_id)
		node.call("set_module_value", SECTION, KEY_SEEN_EVENTS, seen)
