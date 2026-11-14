class_name Endings
extends RefCounted
## Oyunun sonunu seçer. data/story/endings.json sırayla taranır, ilk eşleşen kazanır:
## `game_over` (kariyerin bitiş nedeni listede mi) ve `requires` (hikaye bayrakları/sayaçları) birlikte sağlanmalı.
## Oyun içi bitiş (kovuldun, tutuklandın) `career.game_over` ile gelir; 15. gün sonunda kalan sonlar bayraklara bakar.

## Her son kimliği.
static func all_ids(db: StoryDb) -> Array[String]:
	var ids: Array[String] = []
	for entry in db.endings:
		ids.append(str(entry["id"]))
	return ids


## Kariyerin şimdiki sonu: {"id", "title_key", "body_key", "over" (oyun içi bitiş mi)}.
static func resolve(career: Career, db: StoryDb = null) -> Dictionary:
	var source := db if db != null else StoryDb.load_default()
	for entry in source.endings:
		if entry.has("game_over"):
			if career.game_over in entry["game_over"]:
				return _result(entry, true)
			continue
		if not career.game_over.is_empty():
			continue
		if career.story.matches(entry.get("requires", {})):
			return _result(entry, false)
	return {}


static func _result(entry: Dictionary, over: bool) -> Dictionary:
	var key := str(entry["id"]).to_upper()
	return {"id": entry["id"], "title_key": "ENDING_%s_TITLE" % key, "body_key": "ENDING_%s_BODY" % key, "over": over}
