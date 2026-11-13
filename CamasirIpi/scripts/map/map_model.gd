class_name MapModel
extends RefCounted

## Seviye haritasının SAF mantığı (sahne yok, test edilir): dünya koordinatı, özel seviye türü,
## bölge sınırları (mekân/mevsim), sandık seviyeleri. Üretici çağrıları ucuzdur (`params_for` /
## `mode_for` yalnız aritmetik); tam seviye ÜRETİLMEZ (ana iş parçacığını yormaz).
## Dünya: 1. seviye y=0, sonrakiler YUKARI (y azalır). Ekran = dünya - kaydırma.

const STEP: float = 230.0
const CENTER_X: float = 540.0
const AMPLITUDE: float = 245.0
const WAVE_LEVELS: float = 8.0
const SECOND_AMPLITUDE: float = 46.0
const SECOND_FREQUENCY: float = 2.3
const SECOND_PHASE: float = 1.1
## Oyuncunun gelecekte görebileceği seviye sayısı ve harita asgari uzunluğu.
const FUTURE_LEVELS: int = 40
const MIN_LEVELS: int = 60
## Bölge rengi için gün evresi (2 = öğle: en nötr gökyüzü).
const TINT_PHASE: int = 2
const TINT_SEASON_MIX: float = 0.7
const SEASON_TINTS: Dictionary = {
	SeasonCycle.SUMMER: Color("f3e3a0"),
	SeasonCycle.AUTUMN: Color("efb98a"),
	SeasonCycle.WINTER: Color("b9d4ee"),
	SeasonCycle.SPRING: Color("f2bfd2"),
}
## Mevsim adı -> çeviri anahtarı (tabloda "kullanılmayan anahtar" denetimi için kodda düz yazılı).
const SEASON_KEYS: Dictionary = {
	SeasonCycle.SUMMER: "MAP_SEASON_SUMMER",
	SeasonCycle.AUTUMN: "MAP_SEASON_AUTUMN",
	SeasonCycle.WINTER: "MAP_SEASON_WINTER",
	SeasonCycle.SPRING: "MAP_SEASON_SPRING",
}

enum Kind { NORMAL, HARD, BOSS, MOVES, SHORT_RACK, ORDERS }
## `kind_for` önbelleği için "henüz hesaplanmadı" işareti.
const KIND_UNKNOWN: int = 255


static func total_levels(current_level: int) -> int:
	return maxi(current_level + FUTURE_LEVELS, MIN_LEVELS)


static func world_y(level: float) -> float:
	return -(level - 1.0) * STEP


static func level_at(y: float) -> float:
	return 1.0 - y / STEP


## Sicim eğrisinin x'i: iki sinüs (organik kıvrım). Düğümler eğrinin tam üstündedir.
static func world_x(level: float) -> float:
	var t: float = TAU * (level - 1.0) / WAVE_LEVELS
	return CENTER_X + AMPLITUDE * sin(t) + SECOND_AMPLITUDE * sin(t * SECOND_FREQUENCY + SECOND_PHASE)


## Seviyenin özel türü. Önce patron/kip, sonra "zor"; hiçbiri değilse normal.
static func kind_for(level: int) -> int:
	var mode: String = LevelGenerator.mode_for(level)
	match mode:
		LaundryBoard.MODE_BOSS:
			return Kind.BOSS
		LaundryBoard.MODE_MOVES:
			return Kind.MOVES
		LaundryBoard.MODE_SHORT_RACK:
			return Kind.SHORT_RACK
		LaundryBoard.MODE_ORDERS:
			return Kind.ORDERS
	if bool(LevelGenerator.params_for(level).get("hard", false)):
		return Kind.HARD
	return Kind.NORMAL


## Bölge (mekân ya da mevsim) başlangıç seviyeleri, artan. 1. seviye her zaman başlangıçtır.
static func dividers(max_level: int) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	for level: int in range(1, max_level + 1):
		if is_divider(level):
			result.append(level)
	return result


static func is_divider(level: int) -> bool:
	return level == 1 or LocationCycle.is_first_level_of_location(level) \
		or SeasonCycle.is_first_level_of_season(level)


## Ayraç yazısı: yeni mekân adı ve/veya yeni mevsim adı ("Sahil · Sonbahar").
static func divider_label(level: int) -> String:
	var parts: Array[String] = []
	if level == 1 or LocationCycle.is_first_level_of_location(level):
		parts.append(Loc.t(LocationCycle.name_key(LocationCycle.location_for(level))))
	if level == 1 or SeasonCycle.is_first_level_of_season(level):
		parts.append(Loc.t(String(SEASON_KEYS[SeasonCycle.season_for(level)])))
	if parts.size() == 2:
		return Loc.f("MAP_DIVIDER_JOIN", parts)
	return parts[0] if not parts.is_empty() else ""


## Bölgenin zemin rengi: mekânın gökyüzü + mevsim tonu (küçük "önizleme").
static func tint_for(level: int) -> Color:
	var sky: Color = LocationCycle.look_for(TINT_PHASE, LocationCycle.location_for(level)).sky_top
	var season: Color = SEASON_TINTS[SeasonCycle.season_for(level)] as Color
	return sky.lerp(season, TINT_SEASON_MIX)


## Sandık (kilometre taşı) seviyeleri: Milestones verisinden, salt okunur. {seviye: true}.
static func chest_levels(max_level: int) -> Dictionary[int, bool]:
	var result: Dictionary[int, bool] = {}
	for entry: Dictionary in Milestones.entries_through(RetentionData.milestones(), max_level):
		result[int(entry["level"])] = true
	return result


## Görünür seviye aralığı [ilk, son] (ekran penceresi dünya y'si `top_y`..`bottom_y`); kenar payıyla.
static func visible_range(top_y: float, bottom_y: float, max_level: int, margin: int) -> Vector2i:
	var first: int = int(floor(level_at(bottom_y))) - margin
	var last: int = int(ceil(level_at(top_y))) + margin
	return Vector2i(clampi(first, 1, max_level), clampi(last, 1, max_level))
