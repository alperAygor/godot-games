class_name RunRecords
extends RefCounted

## Saf veri: kullanıcının rekorları (en yüksek level, en uzun mesafe, en yüksek puan).
## Dosya/IO YOK; `ProfileData` içinde taşınır. Kayıt JSON olduğundan sayılar float
## gelebilir: küsuratsız float tamsayı sayılır, bozuk/negatif değer 0 olur.

var _best_level: int = 0
var _best_distance: int = 0
var _best_score: int = 0
var _runs: int = 0


func best_level() -> int:
	return _best_level


func best_distance() -> int:
	return _best_distance


func best_score() -> int:
	return _best_score


func runs() -> int:
	return _runs


## Koşu bitince çağrılır. Dönüş: hangi rekorların kırıldığı. İlk koşu her rekoru kırar.
func submit(level: int, distance_m: float, score: int) -> Dictionary:
	_runs += 1
	var dist: int = int(floor(maxf(distance_m, 0.0))) if is_finite(distance_m) else 0
	var lvl: int = maxi(level, 0)
	var pts: int = maxi(score, 0)
	var result: Dictionary = {
		"new_level": lvl > _best_level,
		"new_distance": dist > _best_distance,
		"new_score": pts > _best_score,
	}
	_best_level = maxi(_best_level, lvl)
	_best_distance = maxi(_best_distance, dist)
	_best_score = maxi(_best_score, pts)
	return result


func to_dict() -> Dictionary:
	return {
		"best_level": _best_level,
		"best_distance": _best_distance,
		"best_score": _best_score,
		"runs": _runs,
	}


static func from_dict(d: Dictionary) -> RunRecords:
	var records: RunRecords = RunRecords.new()
	records._best_level = _whole_or_zero(d.get("best_level", 0))
	records._best_distance = _whole_or_zero(d.get("best_distance", 0))
	records._best_score = _whole_or_zero(d.get("best_score", 0))
	records._runs = _whole_or_zero(d.get("runs", 0))
	return records


static func _whole_or_zero(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return maxi(int(value), 0)
	if typeof(value) == TYPE_FLOAT:
		var number: float = float(value)
		if is_finite(number) and is_equal_approx(number, roundf(number)):
			return maxi(int(roundf(number)), 0)
	return 0
