class_name StoryDb
extends RefCounted
## Hikaye verisi: karakterler, gün dosyaları (data/story/day_NN.json) ve sonlar (data/story/endings.json).
## Saf veri okuyucu; durum StoryState'te, sahneyi yöneten StoryDirector'dadır.

const DIR := "res://data/story"
const FIRST_DAY := 1
const LAST_DAY := 15

var characters: Dictionary = {}
var endings: Array[Dictionary] = []
var _days: Dictionary = {}


static func load_default() -> StoryDb:
	var db := StoryDb.new()
	db.characters = JsonIO.read_dict(DIR.path_join("characters.json")).get("characters", {})
	for entry: Variant in JsonIO.read_dict(DIR.path_join("endings.json")).get("endings", []):
		db.endings.append(entry)
	for day in range(FIRST_DAY, LAST_DAY + 1):
		db._days[day] = JsonIO.read_dict(DIR.path_join("day_%02d.json" % day), {"day": day, "beats": [], "letters": []})
	return db


## O günün tanımı: {"day", "beats": [...], "letters": [...]}. Dosyası olmayan gün için boş tanım.
func day_def(day: int) -> Dictionary:
	return _days.get(day, {"day": day, "beats": [], "letters": []})


func character(character_id: String) -> Dictionary:
	return characters.get(character_id, {})


func ending(ending_id: String) -> Dictionary:
	for entry in endings:
		if entry["id"] == ending_id:
			return entry
	return {}


## Akşam mektubunun metin anahtarı: günün ilk koşulu sağlanan mektubu (yoksa boş).
func letter_key(day: int, story: StoryState) -> String:
	for entry: Dictionary in day_def(day).get("letters", []):
		if story.matches(entry.get("requires", {})):
			return str(entry["key"])
	return ""
