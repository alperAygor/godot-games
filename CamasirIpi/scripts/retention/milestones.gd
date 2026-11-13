class_name Milestones
extends RefCounted

## Seviye kilometre taşı yolu (saf mantık). "Tamamlanan seviye" = Progress.level() - 1.
## Durum: {"claimed": [5, 10, ...]}. Liste veri dosyasındadır; son girişten sonra
## `repeat` kuralıyla (her 10 seviye, her 50'de büyük sandık) sonsuza uzar.

const KEY_CLAIMED: String = "claimed"
const STATUS_CLAIMED: int = 0
const STATUS_CLAIMABLE: int = 1
const STATUS_NEXT: int = 2
const STATUS_LOCKED: int = 3
const DEFAULT_VISIBLE: int = 5
## Seviye sayısından türetilen üst sınır: sonsuz döngüye karşı emniyet.
const MAX_GENERATED: int = 200


static func cleared_levels(current_level: int) -> int:
	return maxi(current_level - 1, 0)


## Verilen seviyeye (dahil) kadar tüm kilometre taşları, artan sırayla: {level, reward}.
static func entries_through(cfg: Dictionary, last_level: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var highest: int = 0
	for entry: Variant in cfg.get("list", []) as Array:
		var level: int = int((entry as Dictionary).get("level", 0))
		if level > last_level:
			break
		result.append({"level": level, "reward": (entry as Dictionary).get("reward", {})})
		highest = maxi(highest, level)
	var repeat: Variant = cfg.get("repeat", {})
	if repeat is Dictionary:
		var rule: Dictionary = repeat as Dictionary
		var every: int = maxi(int(rule.get("every", 10)), 1)
		var level: int = maxi(int(rule.get("from", highest + every)), highest + 1)
		var count: int = 0
		while level <= last_level and count < MAX_GENERATED:
			var big_every: int = int(rule.get("big_every", 0))
			var is_big: bool = big_every > 0 and level % big_every == 0
			result.append({"level": level,
				"reward": rule.get("big_reward" if is_big else "reward", {})})
			level += every
			count += 1
	return result


static func claimed_levels(state: Dictionary) -> Array[int]:
	var result: Array[int] = []
	var raw: Variant = state.get(KEY_CLAIMED, [])
	if raw is Array:
		for value: Variant in raw as Array:
			result.append(int(value))
	return result


static func is_claimed(state: Dictionary, level: int) -> bool:
	return claimed_levels(state).has(level)


## Alınmayı bekleyen (ulaşılmış, alınmamış) kilometre taşı seviyeleri.
static func claimable(state: Dictionary, current_level: int, cfg: Dictionary) -> Array[int]:
	var cleared: int = cleared_levels(current_level)
	var result: Array[int] = []
	for entry: Dictionary in entries_through(cfg, cleared):
		if not is_claimed(state, int(entry["level"])):
			result.append(int(entry["level"]))
	return result


## Henüz ulaşılmamış ilk kilometre taşı seviyesi.
static func next_level(current_level: int, cfg: Dictionary) -> int:
	var cleared: int = cleared_levels(current_level)
	var list: Array[Dictionary] = entries_through(cfg, cleared + MAX_GENERATED)
	for entry: Dictionary in list:
		if int(entry["level"]) > cleared:
			return int(entry["level"])
	return cleared + 1


static func levels_to_go(current_level: int, cfg: Dictionary) -> int:
	return next_level(current_level, cfg) - cleared_levels(current_level)


## Bir önceki kilometre taşından sonrakine ilerleme oranı (0..1).
static func progress_fraction(current_level: int, cfg: Dictionary) -> float:
	var cleared: int = cleared_levels(current_level)
	var upcoming: int = next_level(current_level, cfg)
	var previous: int = 0
	for entry: Dictionary in entries_through(cfg, cleared):
		previous = int(entry["level"])
	var span: int = maxi(upcoming - previous, 1)
	return clampf(float(cleared - previous) / float(span), 0.0, 1.0)


## Sayfada görünen pencere: [{level, reward, status}]. Alınmamışların ilkinden bir öncesi
## bağlam olarak gösterilir; oyuncu hep "şimdi neredeyim"i görür.
static func window(state: Dictionary, current_level: int, cfg: Dictionary, size: int) -> Array[Dictionary]:
	var cleared: int = cleared_levels(current_level)
	var all: Array[Dictionary] = entries_through(cfg, cleared + MAX_GENERATED)
	var first_open: int = all.size() - 1
	for index: int in range(all.size()):
		if not is_claimed(state, int(all[index]["level"])):
			first_open = index
			break
	var start: int = maxi(first_open - 1, 0)
	var result: Array[Dictionary] = []
	var next_marked: bool = false
	for index: int in range(start, mini(start + size, all.size())):
		var entry: Dictionary = (all[index] as Dictionary).duplicate()
		var level: int = int(entry["level"])
		if is_claimed(state, level):
			entry["status"] = STATUS_CLAIMED
		elif level <= cleared:
			entry["status"] = STATUS_CLAIMABLE
		elif not next_marked:
			entry["status"] = STATUS_NEXT
			next_marked = true
		else:
			entry["status"] = STATUS_LOCKED
		result.append(entry)
	return result


static func reward_for(cfg: Dictionary, level: int) -> Dictionary:
	for entry: Dictionary in entries_through(cfg, level):
		if int(entry["level"]) == level:
			return entry.get("reward", {}) as Dictionary
	return {}


## Dönen: {"ok", "state", "template"}. Ulaşılmamış ya da alınmış kilometre taşı reddedilir.
static func claim(state: Dictionary, level: int, current_level: int, cfg: Dictionary) -> Dictionary:
	var refused: Dictionary = {"ok": false, "state": state, "template": {}}
	if is_claimed(state, level) or level > cleared_levels(current_level):
		return refused
	var template: Dictionary = reward_for(cfg, level)
	if template.is_empty():
		return refused
	var next: Dictionary = state.duplicate(true)
	var list: Array = []
	for value: int in claimed_levels(state):
		list.append(value)
	list.append(level)
	next[KEY_CLAIMED] = list
	return {"ok": true, "state": next, "template": template}
