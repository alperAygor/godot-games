extends TestCase

## GardenBackdrop doku önbelleği sahneler arası SINIRLI kalmalı: önceki sahnenin (ör. haritadan tekrar
## oynanan eski seviye) mekân dokuları yeni arka plan kurulunca atılır; oyuncunun kayıtlı seviyesinin
## mekânı ise kalır (ana ekran <-> oyun geçişi dokuları diskten yeniden yüklemesin).

const VIEW: Vector2 = Vector2(1080.0, 1920.0)
const RACK_Y: float = 1130.0
## Kayıtlı seviye (yaz, ilk mekân) ve başka mekân + mevsimdeki tekrar seviyesi.
const SAVED_LEVEL: int = 5
const OTHER_LEVEL: int = 100

var _progress: Node = null
var _persist_before: bool = true
var _level_before: int = 1


func before_each() -> void:
	_progress = autoload_node("Progress")
	_persist_before = bool(_progress.get("persist"))
	_progress.set("persist", false)
	var data: ProgressData = _progress.get("data") as ProgressData
	_level_before = data.level
	data.level = SAVED_LEVEL


func after_each() -> void:
	(_progress.get("data") as ProgressData).level = _level_before
	_progress.set("persist", _persist_before)


func test_previous_scene_place_is_released() -> void:
	assert_true(LocationCycle.location_for(OTHER_LEVEL) != LocationCycle.location_for(SAVED_LEVEL),
		"sınama seviyeleri farklı mekânda olmalı")
	var replay: GardenBackdrop = _backdrop()
	replay.set_level(OTHER_LEVEL)
	var other_paths: Array[String] = GardenBackdrop._all_paths(LocationCycle.location_for(OTHER_LEVEL),
		SeasonLook.season_for_level(OTHER_LEVEL))
	var saved_paths: Array[String] = GardenBackdrop._all_paths(LocationCycle.location_for(SAVED_LEVEL),
		SeasonLook.season_for_level(SAVED_LEVEL))
	assert_true(_cached(other_paths) > 0, "tekrar seviyesinin dokuları yüklü olmalı")
	_free(replay)
	var home: GardenBackdrop = _backdrop()
	for path: String in other_paths:
		if not saved_paths.has(path):
			assert_false(GardenBackdrop._textures.has(path), "önceki sahnenin dokusu atılmalı: %s" % path)
	# Kimlikler (referans değil) saklanır: doku serbest kalıp diskten yeniden yüklenirse kimlik değişir.
	var ids: Dictionary[String, int] = {}
	for path: String in home._active.paths:
		ids[path] = GardenBackdrop._textures[path].get_instance_id()
	_free(home)
	var game: GardenBackdrop = _backdrop()
	assert_greater(float(ids.size()), 0.0, "ana ekran mekânı doku kullanmalı")
	for path: String in ids.keys():
		assert_eq(game._active.paths.has(path) and GardenBackdrop._textures[path].get_instance_id() == ids[path], true,
			"ana ekran -> oyun: aynı mekânın dokusu yeniden yüklenmemeli: %s" % path)
	_free(game)


func _backdrop() -> GardenBackdrop:
	var backdrop: GardenBackdrop = GardenBackdrop.new()
	add_node(backdrop)
	backdrop.setup(VIEW, RACK_Y)
	return backdrop


func _free(backdrop: GardenBackdrop) -> void:
	backdrop.get_parent().remove_child(backdrop)
	backdrop.free()


func _cached(paths: Array[String]) -> int:
	var count: int = 0
	for path: String in paths:
		if GardenBackdrop._textures.has(path):
			count += 1
	return count

