class_name LevelCache
extends RefCounted

## Testler arası paylaşılan üretilmiş seviye ve çözüm önbelleği. Neden: aynı 1..120 seviyeyi
## birkaç test dosyası ayrı ayrı üretip çözünce test adımı doğrulama zaman aşımını aşıyordu.
## Üretici deterministik olduğundan önbellek sonucu değiştirmez. Testler seviyeyi DEĞİŞTİRMEMELİ.

const SOLVE_LIMIT: int = 200000

static var _levels: Dictionary = {}
static var _paths: Dictionary = {}
## Seviye -> üretim süresi (µs), ilk üretimde ölçülür (rapor için).
static var gen_usec: Dictionary = {}
static var solve_usec: Dictionary = {}


static func level(number: int) -> Dictionary:
	if not _levels.has(number):
		var start: int = Time.get_ticks_usec()
		_levels[number] = LevelGenerator.generate(number)
		gen_usec[number] = Time.get_ticks_usec() - start
	return _levels[number] as Dictionary


static func path(number: int) -> Array[int]:
	if not _paths.has(number):
		var data: Dictionary = level(number)
		var start: int = Time.get_ticks_usec()
		_paths[number] = LevelSolver.solve(data, SOLVE_LIMIT)
		solve_usec[number] = Time.get_ticks_usec() - start
	return _paths[number] as Array[int]
