class_name StarRating
extends RefCounted

## Seviye başına 1-3 yıldız ve ustalık ödülleri (saf mantık; sahne/dosya yok).
##  * 1 yıldız: seviye bitti.
##  * 2 yıldız: askıya giden çamaşır sayısı, seviye boyutundan türeyen eşik ve altında.
##  * 3 yıldız "kusursuz": askı kullanımı küçük bir payı aşmadı VE seviyede "+1 askı ile devam" yok.
## Eşikler `data/balance.json` -> "mastery" bölümündedir. Neden seviye boyutuna oranlı:
## 45 çamaşırlık seviyeyle 6 çamaşırlık seviye aynı mutlak askı payıyla adil ölçülemez.

const MIN_STARS: int = 1
const MAX_STARS: int = 3
const SECTION: String = "mastery"
const FALLBACK_TWO_RATIO: float = 0.25
const FALLBACK_TWO_MIN: int = 2
const FALLBACK_PERFECT_BASE: int = 1
const FALLBACK_PERFECT_PER_ITEM: float = 0.05
const FALLBACK_PERFECT_BONUS: int = 15
const FALLBACK_CHAIN_STEP: int = 2
const FALLBACK_CHAIN_CAP: int = 12
## Bir zincir en az bu uzunlukta olunca bonus başlar (tek sepet zincir sayılmaz).
const CHAIN_BONUS_FROM: int = 2


## `balance` tüm denge tablosudur ("mastery" bölümü içinden okunur); bozuk/eksik değer yedeğe düşer.
static func section(balance: Dictionary) -> Dictionary:
	var raw: Variant = balance.get(SECTION)
	return raw as Dictionary if raw is Dictionary else {}


## 2 yıldız için izin verilen en çok askı yerleştirmesi.
static func two_star_budget(items: int, balance: Dictionary) -> int:
	var cfg: Dictionary = section(balance)
	var ratio: float = _ratio(cfg.get("two_star_rack_ratio"), FALLBACK_TWO_RATIO)
	var floor_value: int = ProgressData.to_count(cfg.get("two_star_rack_min"), FALLBACK_TWO_MIN)
	return maxi(floor_value, ceili(float(maxi(items, 0)) * ratio))


## 3 yıldız (kusursuz) için izin verilen en çok askı yerleştirmesi: küçük sabit pay + boyuta oranlı kısım.
static func perfect_budget(items: int, balance: Dictionary) -> int:
	var cfg: Dictionary = section(balance)
	var base: int = ProgressData.to_count(cfg.get("perfect_rack_base"), FALLBACK_PERFECT_BASE)
	var per_item: float = _ratio(cfg.get("perfect_rack_per_item"), FALLBACK_PERFECT_PER_ITEM)
	return base + floori(float(maxi(items, 0)) * per_item)


## 1-3 yıldız. `rack_total`: askıya giden çamaşır sayısı; `items`: seviyedeki toplam çamaşır.
static func rate(rack_total: int, items: int, revived: bool, balance: Dictionary) -> int:
	if not revived and rack_total <= perfect_budget(items, balance):
		return MAX_STARS
	if rack_total <= two_star_budget(items, balance):
		return MAX_STARS - 1
	return MIN_STARS


static func rate_stats(stats: RunStats, items: int, balance: Dictionary) -> int:
	return rate(stats.rack_total, items, stats.revived, balance)


## 3 yıldızda ek jeton; aksi halde 0.
static func perfect_bonus(stars: int, balance: Dictionary) -> int:
	if stars < MAX_STARS:
		return 0
	return ProgressData.to_count(section(balance).get("perfect_bonus_coins"), FALLBACK_PERFECT_BONUS)


## Zincir bonusu: 1'in üstündeki her adım için sabit jeton, tavanla sınırlı (sonsuz büyümesin).
static func chain_bonus(best_chain: int, balance: Dictionary) -> int:
	if best_chain < CHAIN_BONUS_FROM:
		return 0
	var cfg: Dictionary = section(balance)
	var step: int = ProgressData.to_count(cfg.get("chain_bonus_per_step"), FALLBACK_CHAIN_STEP)
	var cap: int = ProgressData.to_count(cfg.get("chain_bonus_cap"), FALLBACK_CHAIN_CAP)
	return mini(cap, step * (best_chain - 1))


## Ekranın gösterdiği döküm: {"stars","base","perfect","chain","total"}; total = ÖDENEN jeton.
static func breakdown(base_coins: int, stars: int, best_chain: int, balance: Dictionary) -> Dictionary:
	var perfect: int = perfect_bonus(stars, balance)
	var chain: int = chain_bonus(best_chain, balance)
	return {"stars": stars, "base": base_coins, "perfect": perfect, "chain": chain,
		"total": base_coins + perfect + chain, "best_chain": best_chain}


static func _ratio(value: Variant, fallback: float) -> float:
	if value is int or value is float:
		var number: float = float(value)
		if not is_nan(number) and not is_inf(number) and number >= 0.0:
			return number
	return fallback
