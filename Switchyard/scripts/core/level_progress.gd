class_name LevelProgress
extends RefCounted

## Seviye ilerlemesinin SAF mantığı: en iyi hamle, yıldız, çözüldü, atlandı, kilit. Sahne/dosya yok.
## Kayıt `Progress` modül verisidir: bölüm "levels", anahtar seviye kimliği, değer
## { "best": int, "stars": int, "solved": bool, "skipped": bool }. Kimlikle tutulur (sıra değişse bozulmaz).
##
## Yıldız: çözmek = 1; hamle <= ceil(par x 1,5) = 2; hamle <= par + `three_star_slack` = 3
## (slack `data/balance.json`, varsayılan 0). Kilit: n+1. seviye, n çözülünce ya da atlanınca açılır.
## "Tamamlandı" = çözüldü ya da atlandı. Atlanan seviye sonradan çözülürse çözülmüş sayılır.

const SECTION: String = "levels"
const PROGRESS_PATH: NodePath = ^"/root/Progress"
const MAX_STARS: int = 3

## kimlik -> { best, stars, solved, skipped }
var _records: Dictionary = {}


## Yıldız hesabı (saf). `moves` <= 0 ya da `par` <= 0 bozuk veridir: yine de çözülmüş sayılır (1).
static func stars_for(moves: int, par: int, three_star_slack: int) -> int:
	if moves <= 0 or par <= 0:
		return 1
	if moves <= par + maxi(three_star_slack, 0):
		return MAX_STARS
	# hamle <= ceil(par x 1,5)  <=>  2 x hamle <= 3 x par + 1 (tamsayı; kayan nokta hatası ve bölme yok).
	if moves * 2 <= par * 3 + 1:
		return 2
	return 1


static func ids_of(entries: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in entries:
		ids.append(str(entry.get("id", "")))
	return ids


## Kayıt sözlüğünden (bölüm içeriği) kurar; bozuk girdiler atılır.
static func from_section(section: Dictionary) -> LevelProgress:
	var result: LevelProgress = LevelProgress.new()
	for key: Variant in section.keys():
		var raw: Variant = section[key]
		if key is String and raw is Dictionary and not (key as String).is_empty():
			result._records[key] = _clean(raw as Dictionary)
	return result


## `Progress` autoload'undan okur (yoksa boş). Autoload'a düğüm yoluyla erişilir: `-s` araçlarında güvenli.
static func load_saved() -> LevelProgress:
	var progress: Node = _progress()
	if progress == null:
		return LevelProgress.new()
	return from_section(progress.call("module_section", SECTION) as Dictionary)


## Tek seviyenin kaydını diske yazar (`Progress` yoksa sessizce atlar).
func save(level_id: String) -> void:
	var progress: Node = _progress()
	if progress != null and _records.has(level_id):
		progress.call("set_module_value", SECTION, level_id, (_records[level_id] as Dictionary).duplicate())


static func _progress() -> Node:
	var loop: SceneTree = Engine.get_main_loop() as SceneTree
	return loop.root.get_node_or_null(PROGRESS_PATH) if loop != null else null


static func _clean(raw: Dictionary) -> Dictionary:
	var best: int = ProgressData.to_count(raw.get("best"))
	var solved: bool = bool(raw.get("solved", false)) and best > 0
	var stars: int = clampi(ProgressData.to_count(raw.get("stars")), 1, MAX_STARS) if solved else 0
	return {"best": best if solved else 0, "stars": stars, "solved": solved,
		"skipped": bool(raw.get("skipped", false)) and not solved}


func is_solved(level_id: String) -> bool:
	return bool(_record(level_id).get("solved", false))


func is_skipped(level_id: String) -> bool:
	return bool(_record(level_id).get("skipped", false))


func is_completed(level_id: String) -> bool:
	return is_solved(level_id) or is_skipped(level_id)


func stars(level_id: String) -> int:
	return int(_record(level_id).get("stars", 0))


## En iyi hamle sayısı; çözülmediyse 0.
func best_moves(level_id: String) -> int:
	return int(_record(level_id).get("best", 0))


func total_stars(ids: Array[String]) -> int:
	var total: int = 0
	for level_id: String in ids:
		total += stars(level_id)
	return total


func solved_count(ids: Array[String]) -> int:
	var total: int = 0
	for level_id: String in ids:
		if is_solved(level_id):
			total += 1
	return total


## Çözüm kaydı. Dönen: { "stars", "best", "new_best", "first_completion", "better_stars" }.
## `first_completion`: seviye daha önce ne çözülmüş ne atlanmıştı (reklam sırası yalnız bunu sayar).
func record_solve(level_id: String, moves: int, par: int, three_star_slack: int) -> Dictionary:
	var old: Dictionary = _record(level_id)
	var first: bool = not (bool(old.get("solved", false)) or bool(old.get("skipped", false)))
	var old_best: int = int(old.get("best", 0))
	var old_stars: int = int(old.get("stars", 0))
	var earned: int = stars_for(moves, par, three_star_slack)
	var new_best: bool = old_best == 0 or moves < old_best
	var best: int = moves if new_best else old_best
	var stars_now: int = maxi(old_stars, earned)
	_records[level_id] = {"best": best, "stars": stars_now, "solved": true, "skipped": false}
	return {"stars": earned, "best": best, "new_best": new_best and old_best > 0,
		"first_completion": first, "better_stars": earned > old_stars}


## Atlama kaydı. Zaten çözülmüş ya da atlanmışsa değişmez ve false döner.
func record_skip(level_id: String) -> bool:
	if is_completed(level_id):
		return false
	_records[level_id] = {"best": 0, "stars": 0, "solved": false, "skipped": true}
	return true


## `ids` sırasında `index`. seviye oynanabilir mi: ilki hep açık; ötekiler bir öncekiyle açılır.
func is_unlocked(ids: Array[String], index: int) -> bool:
	if index < 0 or index >= ids.size():
		return false
	return index == 0 or is_completed(ids[index - 1])


## "Devam" hedefi: tamamlanmamış (ne çözülmüş ne atlanmış) ilk seviye. Hepsi bitmişse sonuncu.
## Atlanan seviyeye otomatik dönülmez; oyuncu haritadan seçer.
func frontier(ids: Array[String]) -> int:
	for index: int in ids.size():
		if not is_completed(ids[index]):
			return index
	return maxi(ids.size() - 1, 0)


func all_completed(ids: Array[String]) -> bool:
	for level_id: String in ids:
		if not is_completed(level_id):
			return false
	return not ids.is_empty()


func _record(level_id: String) -> Dictionary:
	var found: Variant = _records.get(level_id)
	return found as Dictionary if found is Dictionary else {}
