class_name SeasonCycle
extends RefCounted

## Saf mantık: seviye numarasından mevsim. Mevsimler seviye bantlarıyla değişir
## (kullanıcı kararı): 1-30 yaz, 31-60 sonbahar, 61-90 kış, 91-120 ilkbahar, sonra döngü.
## Mekân döngüsü (LocationCycle, 40 seviyede bir) bundan BAĞIMSIZ ilerler; böylece aynı
## mekân farklı mevsimlerde görülür ve 120 seviye boyunca kombinasyon tekrarlamaz.
## Kural (LevelGenerator/LaundryBoard) ve görsel (GardenBackdrop) tarafı aynı kaynağı okur.

const LEVELS_PER_SEASON: int = 30
const SUMMER: String = "summer"
const AUTUMN: String = "autumn"
const WINTER: String = "winter"
const SPRING: String = "spring"
const ORDER: Array[String] = [SUMMER, AUTUMN, WINTER, SPRING]


## Seviyenin mevsimi ("summer" | "autumn" | "winter" | "spring").
static func season_for(level: int) -> String:
	return ORDER[index_for(level)]


## Mevsimin sırası (0 = yaz ... 3 = ilkbahar).
static func index_for(level: int) -> int:
	return ((maxi(level, 1) - 1) / LEVELS_PER_SEASON) % ORDER.size()


## Yeni mevsimin ilk seviyesi mi (1. seviye sayılmaz: oyun yazla başlar, duyuru gerekmez).
static func is_first_level_of_season(level: int) -> bool:
	return level > 1 and (level - 1) % LEVELS_PER_SEASON == 0


## Mevsimin içindeki konum (0..LEVELS_PER_SEASON-1): olay yoğunluğunu kademelendirmek için.
static func step_in_season(level: int) -> int:
	return (maxi(level, 1) - 1) % LEVELS_PER_SEASON
