class_name LevelProgression
extends RefCounted

## Saf mantık: level numarasından boy, zorluk ve parça planı üretir (dosya/sahne YOK).
## Sözleşme: PROJECT_SPEC §14. Plan tohumlu ve deterministiktir: aynı (tohum, level,
## kütüphane) her zaman aynı yolu verir; böylece hata ayıklama ve test mümkün olur.

const BASE_LENGTH: float = 60.0
const LENGTH_STEP: float = 12.0
const MAX_LENGTH: float = 240.0
## Zorluk eğrisi bu levelde tavana ulaşır (intensity = 1).
const INTENSITY_FULL_LEVEL: float = 15.0
## Yeni engel türü etiketleri hangi levelde açılır.
const UNLOCKS: Dictionary = {
	"keys": 1,
	"obstacles": 2,
	"pencils": 3,
	"fans": 4,
	"mixed": 6,
}
const MIN_TELEGRAPH_SCALE: float = 0.55
const MIN_CYCLE_SCALE: float = 0.7
const MAX_FAN_SCALE: float = 1.4
const HEAL_FRACTION_EASY: float = 0.35
const HEAL_FRACTION_HARD: float = 0.2
## Teslimatta batarya, level boyuna orantılı dolar (kapasitenin oranı / metre). Enerji
## tüketimi metre başına `speed_drain · hız` olduğundan (balance.json) tam gazla %0.16/m
## harcanır; yenileme %0.1/m: ~5 m/s'de denge, daha hızlıda net düşüş. Hız bir ödünleşmedir
## ve batarya kapasitesi yükseltmesi koşuyu uzatır.
const BATTERY_REFILL_PER_METER: float = 0.001


## Level n'in hedef boyu (metre).
static func length_for(level: int) -> float:
	var n: int = maxi(level, 1)
	return minf(BASE_LENGTH + LENGTH_STEP * float(n - 1), MAX_LENGTH)


## 0..1: yoğunluk/hız eğrisi.
static func intensity(level: int) -> float:
	return clampf(float(maxi(level, 1) - 1) / (INTENSITY_FULL_LEVEL - 1.0), 0.0, 1.0)


## Uyarı süresi çarpanı (1 = başlangıç, küçüldükçe tuzak daha az haber verir).
static func telegraph_scale(level: int) -> float:
	return lerpf(1.0, MIN_TELEGRAPH_SCALE, intensity(level))


## Tuzak döngü süresi çarpanı (küçüldükçe daha sık).
static func cycle_scale(level: int) -> float:
	return lerpf(1.0, MIN_CYCLE_SCALE, intensity(level))


static func fan_strength_scale(level: int) -> float:
	return lerpf(1.0, MAX_FAN_SCALE, intensity(level))


## Parça başına tuzak sayısı üst sınırı (parça şablonunun kendi sınırı ayrıca geçerlidir).
static func hazard_budget(level: int) -> int:
	return clampi(1 + (maxi(level, 1) - 1) / 2, 1, 4)


## Teslimatta hasarın onarılan oranı ve bataryanın dolan oranı (level arttıkça cimrileşir).
static func heal_fraction(level: int) -> float:
	return lerpf(HEAL_FRACTION_EASY, HEAL_FRACTION_HARD, intensity(level))


static func battery_refill(level: int) -> float:
	return clampf(BATTERY_REFILL_PER_METER * length_for(level), 0.0, 1.0)


## Bu levelde açık engel etiketleri.
static func unlocked_tags(level: int) -> Array[String]:
	var tags: Array[String] = []
	for tag: Variant in UNLOCKS.keys():
		if maxi(level, 1) >= int(UNLOCKS[tag]):
			tags.append(String(tag))
	tags.sort()
	return tags


## Parça planı: kütüphane girdisi {id, length, min_level, weight, tags: Array, calm: bool}.
## Girdi uygunsa (min_level yeterli ve tüm etiketleri açık) seçilir; art arda aynı
## parça mümkünse tekrarlanmaz; her level `calm` bir parçayla (varsa) başlar.
## Dönüş: [{id, offset, length}] — toplam boy >= length_for(level).
static func plan(level: int, seed_value: int, library: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var open_tags: Array[String] = unlocked_tags(level)
	var eligible: Array[Dictionary] = []
	for entry_raw: Variant in library:
		if not entry_raw is Dictionary:
			continue
		var entry: Dictionary = entry_raw as Dictionary
		if _is_eligible(entry, level, open_tags):
			eligible.append(entry)
	if eligible.is_empty():
		return result
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([seed_value, maxi(level, 1)])
	var target: float = length_for(level)
	var offset: float = 0.0
	var previous: String = ""
	while offset < target - 0.001:
		var pool: Array[Dictionary] = _pool_for(eligible, previous, result.is_empty())
		var picked: Dictionary = _weighted_pick(pool, rng)
		var length: float = maxf(float(picked.get("length", 0.0)), 1.0)
		result.append({"id": String(picked.get("id", "")), "offset": offset, "length": length})
		offset += length
		previous = String(picked.get("id", ""))
	return result


static func plan_length(plan_list: Array[Dictionary]) -> float:
	if plan_list.is_empty():
		return 0.0
	var last: Dictionary = plan_list[plan_list.size() - 1]
	return float(last.get("offset", 0.0)) + float(last.get("length", 0.0))


static func _is_eligible(entry: Dictionary, level: int, open_tags: Array[String]) -> bool:
	if String(entry.get("id", "")).is_empty() or float(entry.get("length", 0.0)) <= 0.0:
		return false
	if maxi(level, 1) < int(entry.get("min_level", 1)):
		return false
	var tags_raw: Variant = entry.get("tags", [])
	if tags_raw is Array:
		for tag: Variant in tags_raw as Array:
			if not open_tags.has(String(tag)):
				return false
	return true


static func _pool_for(eligible: Array[Dictionary], previous: String, first: bool) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	if first:
		for entry: Dictionary in eligible:
			if bool(entry.get("calm", false)):
				pool.append(entry)
		if not pool.is_empty():
			return pool
	for entry: Dictionary in eligible:
		if String(entry.get("id", "")) != previous or eligible.size() == 1:
			pool.append(entry)
	return pool if not pool.is_empty() else eligible


static func _weighted_pick(pool: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	var total: float = 0.0
	for entry: Dictionary in pool:
		total += maxf(float(entry.get("weight", 1.0)), 0.0)
	if total <= 0.0:
		return pool[rng.randi_range(0, pool.size() - 1)]
	var roll: float = rng.randf() * total
	for entry: Dictionary in pool:
		roll -= maxf(float(entry.get("weight", 1.0)), 0.0)
		if roll <= 0.0:
			return entry
	return pool[pool.size() - 1]
