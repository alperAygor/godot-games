class_name Missions
extends RefCounted

## Günlük görevler (saf mantık; sahne/Progress/saat yok). Gün ve seviye DIŞARIDAN verilir.
## Durum: {"day": "YYYY-MM-DD", "items": [{id,target,progress,claimed,reward}], "chest": bool}.
## Neden çekilen görevler kayda yazılır: havuz/denge sonradan değişse de oyuncunun bugünkü
## görevleri ve ödülleri sabit kalır; aynı gün yeniden açınca aynı liste gelir.

const KEY_DAY: String = "day"
const KEY_ITEMS: String = "items"
const KEY_CHEST: String = "chest"
const SEED_MULTIPLIER: int = 7919
const SEED_OFFSET: int = 17
const DEFAULT_COUNT: int = 3
const DEFAULT_SCALE_EVERY: int = 10
const MODE_MAX: String = "max"


static func unlock_level(cfg: Dictionary) -> int:
	return int(cfg.get("unlock_level", 5))


static func definition(cfg: Dictionary, id: String) -> Dictionary:
	for def: Variant in cfg.get("pool", []) as Array:
		if String((def as Dictionary).get("id", "")) == id:
			return def as Dictionary
	return {}


## Hedef seviyeyle ılımlı büyür: her `scale_every` seviyede `step` kadar, `cap`i geçmez.
static func target_for(def: Dictionary, level: int, cfg: Dictionary) -> int:
	var every: int = maxi(int(cfg.get("scale_every", DEFAULT_SCALE_EVERY)), 1)
	var base: int = int(def.get("base", 1))
	var grown: int = base + (maxi(level, 0) / every) * int(def.get("step", 0))
	return clampi(grown, base, maxi(int(def.get("cap", base)), base))


## İsteğe bağlı (başka işçilerin özelliğine bağlı) görevler, olay canlı olana dek çekilmez.
static func eligible(def: Dictionary, live: Dictionary) -> bool:
	if not bool(def.get("optional", false)):
		return true
	return bool(live.get(String(def.get("event", "")), false))


## O güne özgü, deterministik 3 görev: ağırlıklı, aynı gruptan en çok bir tane.
static func draw(day_key: String, level: int, cfg: Dictionary, live: Dictionary) -> Array[Dictionary]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = DailyDate.day_index(day_key) * SEED_MULTIPLIER + SEED_OFFSET
	var candidates: Array[Dictionary] = []
	for def: Variant in cfg.get("pool", []) as Array:
		if eligible(def as Dictionary, live):
			candidates.append(def as Dictionary)
	var items: Array[Dictionary] = []
	var used_groups: Array[String] = []
	var wanted: int = int(cfg.get("count", DEFAULT_COUNT))
	while items.size() < wanted and not candidates.is_empty():
		var total: float = 0.0
		for def: Dictionary in candidates:
			total += float(def.get("weight", 1))
		var roll: float = rng.randf() * total
		var picked: int = candidates.size() - 1
		for index: int in range(candidates.size()):
			roll -= float(candidates[index].get("weight", 1))
			if roll < 0.0:
				picked = index
				break
		var chosen: Dictionary = candidates[picked]
		candidates.remove_at(picked)
		var group: String = String(chosen.get("group", chosen.get("id", "")))
		if used_groups.has(group):
			continue
		used_groups.append(group)
		items.append({
			"id": String(chosen["id"]),
			"target": target_for(chosen, level, cfg),
			"progress": 0,
			"claimed": false,
			"reward": (chosen.get("reward", {}) as Dictionary).duplicate(),
		})
	return items


static func new_state(day_key: String, level: int, cfg: Dictionary, live: Dictionary) -> Dictionary:
	return {KEY_DAY: day_key, KEY_ITEMS: draw(day_key, level, cfg, live), KEY_CHEST: false}


static func items(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var raw: Variant = state.get(KEY_ITEMS, [])
	if raw is Array:
		for item: Variant in raw as Array:
			if item is Dictionary:
				result.append(item as Dictionary)
	return result


static func is_done(item: Dictionary) -> bool:
	return int(item.get("progress", 0)) >= int(item.get("target", 1))


static func all_done(state: Dictionary) -> bool:
	var list: Array[Dictionary] = items(state)
	if list.is_empty():
		return false
	for item: Dictionary in list:
		if not is_done(item):
			return false
	return true


static func done_count(state: Dictionary) -> int:
	var total: int = 0
	for item: Dictionary in items(state):
		if is_done(item):
			total += 1
	return total


static func chest_ready(state: Dictionary) -> bool:
	return all_done(state) and not bool(state.get(KEY_CHEST, false))


static func claimable_count(state: Dictionary) -> int:
	var total: int = 1 if chest_ready(state) else 0
	for item: Dictionary in items(state):
		if is_done(item) and not bool(item.get("claimed", false)):
			total += 1
	return total


## Gün değiştiyse yeni görevleri kurar. Dönen "carry": dünden alınmamış TAMAMLANMIŞ görevlerin
## (ve hepsi bittiyse sandığın) ödül şablonları; çağıran otomatik verir (oyuncu kaybetmesin).
static func sync(state: Dictionary, day_key: String, level: int, cfg: Dictionary,
		live: Dictionary) -> Dictionary:
	if String(state.get(KEY_DAY, "")) == day_key and not items(state).is_empty():
		return {"state": state, "carry": [] as Array[Dictionary], "rolled": false}
	var carry: Array[Dictionary] = []
	for item: Dictionary in items(state):
		if is_done(item) and not bool(item.get("claimed", false)):
			carry.append(item.get("reward", {}) as Dictionary)
	if chest_ready(state):
		carry.append(cfg.get("chest", {}) as Dictionary)
	return {"state": new_state(day_key, level, cfg, live), "carry": carry, "rolled": true}


## Olayı işler. Dönen: {"state", "changed"}. Bilinmeyen/eşleşmeyen olay hiçbir şeyi değiştirmez.
static func apply_event(state: Dictionary, event_id: String, amount: int, data: Dictionary,
		cfg: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	var changed: bool = false
	var list: Array = next.get(KEY_ITEMS, []) as Array
	for index: int in range(list.size()):
		var item: Dictionary = list[index] as Dictionary
		if is_done(item) or bool(item.get("claimed", false)):
			continue
		var def: Dictionary = definition(cfg, String(item.get("id", "")))
		if def.is_empty() or not RetentionEvents.accepts(def, event_id, data):
			continue
		var gain: int = RetentionEvents.contribution(def, amount, data)
		if gain <= 0:
			continue
		var before: int = int(item.get("progress", 0))
		var target: int = int(item.get("target", 1))
		var after: int = maxi(before, gain) if String(def.get("mode", "sum")) == MODE_MAX else before + gain
		item["progress"] = mini(after, target)
		if int(item["progress"]) != before:
			changed = true
	return {"state": next, "changed": changed}


## Görev ödülünü alır. Dönen: {"ok", "state", "template"}.
static func claim(state: Dictionary, index: int) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	var list: Array = next.get(KEY_ITEMS, []) as Array
	if index < 0 or index >= list.size():
		return {"ok": false, "state": state, "template": {}}
	var item: Dictionary = list[index] as Dictionary
	if not is_done(item) or bool(item.get("claimed", false)):
		return {"ok": false, "state": state, "template": {}}
	item["claimed"] = true
	return {"ok": true, "state": next, "template": item.get("reward", {})}


static func claim_chest(state: Dictionary, cfg: Dictionary) -> Dictionary:
	if not chest_ready(state):
		return {"ok": false, "state": state, "template": {}}
	var next: Dictionary = state.duplicate(true)
	next[KEY_CHEST] = true
	return {"ok": true, "state": next, "template": cfg.get("chest", {})}
