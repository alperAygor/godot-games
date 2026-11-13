class_name MachineRules
extends RefCounted

## Saf mantık: makine yükseltme tablosu (`data/machines.json`). Sahneye ve kayda bağlı değildir;
## kayıt/jeton işleri `MachineUpgrades` içindedir. Yükseltmeler yalnız oyuncunun tahtasını
## kolaylaştırır (daha çok yuva, daha az bekleme): üretici çözülebilirliği seviye 0 ile kanıtlar.

const TABLE_PATH: String = "res://data/machines.json"
const WASHER: String = "washer"
const DRYER: String = "dryer"
const MACHINES: Array[String] = [WASHER, DRYER]
const CAPACITY: String = "capacity"
const MOVES: String = "moves"
const TRACKS: Array[String] = [CAPACITY, MOVES]
const COST_SUFFIX: String = "_cost"
## Bedel yok (en üst seviye) işareti.
const MAXED: int = -1

static var _cached: Dictionary = {}


## Tablo bir kez okunur; yoksa yerleşik yedek (tahta seviye-0 değerleriyle aynı).
static func table() -> Dictionary:
	if _cached.is_empty() and FileAccess.file_exists(TABLE_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
		if parsed is Dictionary:
			_cached = parsed as Dictionary
	if _cached.is_empty():
		_cached = {
			WASHER: {CAPACITY: [LaundryBoard.WASHER_CAPACITY], MOVES: [LaundryBoard.WASHER_MOVES]},
			DRYER: {CAPACITY: [LaundryBoard.DRYER_CAPACITY], MOVES: [LaundryBoard.DRYER_MOVES]},
		}
	return _cached


static func _track(machine: String, track: String) -> Array:
	return ((table().get(machine, {}) as Dictionary).get(track, []) as Array)


## Kaç yükseltme var (seviye 0 dahil değil).
static func max_level(machine: String, track: String) -> int:
	return maxi(_track(machine, track).size() - 1, 0)


## Yükseltme seviyesindeki değer (kapasite = parça, hız = hamle).
static func value(machine: String, track: String, level: int) -> int:
	var values: Array = _track(machine, track)
	if values.is_empty():
		return 0
	return int(values[clampi(level, 0, values.size() - 1)])


## `level`'dan bir sonrakine geçiş bedeli; en üstteyse MAXED.
static func cost(machine: String, track: String, level: int) -> int:
	var costs: Array = ((table().get(machine, {}) as Dictionary).get(track + COST_SUFFIX, []) as Array)
	if level < 0 or level >= costs.size() or level >= max_level(machine, track):
		return MAXED
	return int(costs[level])


## Kayıt anahtarı (Progress modülü "machines") ve tahta yükseltme anahtarı aynıdır: "washer_capacity".
static func key(machine: String, track: String) -> String:
	return "%s_%s" % [machine, track]


## Seviyelerden (anahtar -> seviye) tahtaya verilecek değerler (anahtar -> değer).
static func board_params(levels: Dictionary) -> Dictionary:
	var params: Dictionary = {}
	for machine: String in MACHINES:
		for track: String in TRACKS:
			var name: String = key(machine, track)
			params[name] = value(machine, track, int(levels.get(name, 0)))
	return params


## Makinenin açıldığı oyun seviyesi (üreticiyle aynı takvim).
static func unlock_level(machine: String) -> int:
	return LevelGenerator.DRYER_FROM_LEVEL if machine == DRYER else LevelGenerator.WASHER_FROM_LEVEL
