class_name RetentionRewards
extends RefCounted

## Ödül sözlüğü: {"coins": int, "stars": int, "boosters": {id: adet}}. Şablon ise
## {"coins","stars","booster": "any"|id,"count"} biçimindedir ve `resolve` ile somutlaşır.
## Neden "any": oyuncu henüz açmadığı güçlendiriciyi kazanmasın; seviyesine uygun biri seçilir,
## hiçbiri açık değilse eşdeğer jetona çevrilir (boş el sallamak yerine).

const BOOSTER_ANY: String = "any"


static func empty() -> Dictionary:
	return {"coins": 0, "stars": 0, "boosters": {}}


static func is_empty(reward: Dictionary) -> bool:
	return int(reward.get("coins", 0)) <= 0 and int(reward.get("stars", 0)) <= 0 \
		and (reward.get("boosters", {}) as Dictionary).is_empty()


## `unlock_levels`: {booster_id: açılış seviyesi} (balance.json "booster_unlock_level").
static func pick_booster(want: String, level: int, salt: int, unlock_levels: Dictionary) -> String:
	var open: Array[String] = []
	for id: String in ProgressData.BOOSTER_IDS:
		if level >= int(unlock_levels.get(id, 1)):
			open.append(id)
	if want == BOOSTER_ANY:
		return "" if open.is_empty() else open[absi(salt) % open.size()]
	return want if open.has(want) else ""


static func resolve(template: Dictionary, level: int, salt: int, unlock_levels: Dictionary,
		fallback_coins: int) -> Dictionary:
	var reward: Dictionary = empty()
	var coins: int = int(template.get("coins", 0))
	var want: String = String(template.get("booster", ""))
	var count: int = int(template.get("count", 0))
	if not want.is_empty() and count > 0:
		var picked: String = pick_booster(want, level, salt, unlock_levels)
		if picked.is_empty():
			coins += fallback_coins * count
		else:
			(reward["boosters"] as Dictionary)[picked] = count
	reward["coins"] = coins
	reward["stars"] = int(template.get("stars", 0))
	return reward


static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var result: Dictionary = empty()
	result["coins"] = int(a.get("coins", 0)) + int(b.get("coins", 0))
	result["stars"] = int(a.get("stars", 0)) + int(b.get("stars", 0))
	var boosters: Dictionary = {}
	for source: Dictionary in [a, b]:
		var map: Variant = source.get("boosters", {})
		if map is Dictionary:
			for id: Variant in (map as Dictionary).keys():
				boosters[String(id)] = int(boosters.get(String(id), 0)) + int((map as Dictionary)[id])
	result["boosters"] = boosters
	return result


## Diske/JSON'a gidip gelen ödülü (sayılar float olabilir) temiz tiplere çevirir.
static func normalize(raw: Variant) -> Dictionary:
	if not (raw is Dictionary):
		return empty()
	return merge(raw as Dictionary, empty())
