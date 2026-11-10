class_name PlayerProfile
extends RefCounted

## Kalici oyuncu kaydi: bolum yildizlari ve en iyi sureler.
## Atomik yazim: once <path>.tmp, sonra rename. Bozuk/eksik kayit oyunu kilitlemez;
## yalnizca iyilestirmeler yazilir. Testler save_path alanini degistirir.

const SAVE_PATH: String = "user://profile.save"
const SAVE_VERSION: int = 1
const MAX_LEVEL: int = 12
const MAX_STARS: int = 3

## Kayit dosyasi. Test izolasyonu icin degistirilebilir (varsayilan SAVE_PATH).
var save_path: String = SAVE_PATH
var best_stars: Dictionary = {}
var best_times: Dictionary = {}


func load_save() -> void:
	best_stars = {}
	best_times = {}
	if not FileAccess.file_exists(save_path):
		return
	var text: String = FileAccess.get_file_as_string(save_path)
	if text.is_empty():
		return
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		push_warning("PlayerProfile: kayit cozulemedi, sifirlandi")
		return
	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		push_warning("PlayerProfile: kayit sozluk degil, sifirlandi")
		return
	var data: Dictionary = parsed as Dictionary
	_read_stars(data.get("best_stars", {}))
	_read_times(data.get("best_times", {}))


func save() -> void:
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"best_stars": best_stars,
		"best_times": best_times,
	}
	var tmp_path: String = save_path + ".tmp"
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("PlayerProfile: kayit yazilamadi: %s" % tmp_path)
		return
	file.store_string(JSON.stringify(payload))
	file.close()
	var directory: String = save_path.get_base_dir()
	var dir: DirAccess = DirAccess.open(directory)
	if dir == null:
		push_error("PlayerProfile: kayit dizini acilamadi: %s" % directory)
		return
	var source_name: String = tmp_path.get_file()
	var target_name: String = save_path.get_file()
	var error: Error = dir.rename(source_name, target_name)
	if error != OK:
		# Bazi platformlarda rename hedef varsa basarisiz olur; once silip tekrar dene.
		dir.remove(target_name)
		error = dir.rename(source_name, target_name)
	if error != OK:
		push_error("PlayerProfile: atomik yazim basarisiz (%s)" % error_string(error))


func stars(level: int) -> int:
	return int(best_stars.get(str(level), 0))


func best_time(level: int) -> float:
	return float(best_times.get(str(level), 0.0))


## Yalnizca daha iyi sonucu yazar (yildiz artmali, sure azalmali).
func record(level: int, earned_stars: int, elapsed: float) -> void:
	if level < 1 or level > MAX_LEVEL:
		return
	var key: String = str(level)
	var safe_stars: int = clampi(earned_stars, 0, MAX_STARS)
	if safe_stars > int(best_stars.get(key, 0)):
		best_stars[key] = safe_stars
	if not is_finite(elapsed) or elapsed <= 0.0:
		return
	var previous: float = float(best_times.get(key, 0.0))
	if previous <= 0.0 or elapsed < previous:
		best_times[key] = elapsed


## Bolum acik mi: 1 her zaman acik; N, N-1 tamamlaninca (sirayla) acilir.
func is_unlocked(level: int) -> bool:
	if level < 1 or level > MAX_LEVEL:
		return false
	return level <= highest_unlocked()


func highest_unlocked() -> int:
	var level: int = 1
	while level <= MAX_LEVEL and stars(level) > 0:
		level += 1
	return clampi(level, 1, MAX_LEVEL)


func total_stars() -> int:
	var total: int = 0
	for key: Variant in best_stars.keys():
		total += clampi(int(best_stars[key]), 0, MAX_STARS)
	return total


# --- kayit temizleme -------------------------------------------------------

func _read_stars(raw: Variant) -> void:
	if not (raw is Dictionary):
		return
	var data: Dictionary = raw as Dictionary
	for key: Variant in data.keys():
		var level: int = _valid_level(key)
		if level < 0:
			continue
		var value: Variant = data[key]
		if not (value is int or value is float):
			continue
		var earned: int = clampi(int(value), 0, MAX_STARS)
		if earned > 0:
			best_stars[str(level)] = earned


func _read_times(raw: Variant) -> void:
	if not (raw is Dictionary):
		return
	var data: Dictionary = raw as Dictionary
	for key: Variant in data.keys():
		var level: int = _valid_level(key)
		if level < 0:
			continue
		var value: Variant = data[key]
		if not (value is int or value is float):
			continue
		var elapsed: float = float(value)
		if is_finite(elapsed) and elapsed > 0.0:
			best_times[str(level)] = elapsed


func _valid_level(key: Variant) -> int:
	var level: int = -1
	if key is int or key is float:
		level = int(key)
	elif key is String:
		var text: String = key as String
		if text.is_valid_int():
			level = text.to_int()
	if level < 1 or level > MAX_LEVEL:
		return -1
	return level
