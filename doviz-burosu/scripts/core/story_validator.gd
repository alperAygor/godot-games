class_name StoryValidator
extends RefCounted
## Hikaye içeriği denetçisi (tools/validate_content.gd ve testler kullanır). Döndürdüğü her metin bir hatadır; boş liste = içerik sağlam.
## Denetlenenler: gün dosyalarının yapısı, karakter ve metin anahtarları (TR+EN dolu), geçerli senaryo adları, etkilerin/koşulların
## bilinen bayrak ve sayaçlara başvurması, her senaryolu müşterinin o gün motorla birebir kurulabilmesi (beklenen hükümle).

const TEXT_TABLES := ["res://assets/translations/strings.csv", "res://assets/translations/story.csv"]
const EFFECT_KEYS := ["flags", "counters", "cash_pl", "savings", "mood"]
const REQUIRE_KEYS := ["flags", "counters_min", "counters_max", "savings_min"]
const DECISIONS := ["complete", "reject", "police"]
const MAX_AFTER := 5
const SALTS := ["story", "sim-1", "sim-2", "sim-3", "sim-4"]


## Metin tablolarındaki anahtarlar: anahtar -> true (TR ve EN çevirisi dolu olanlar).
static func text_keys() -> Dictionary:
	var keys := {}
	for path in TEXT_TABLES:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		file.get_csv_line()  # başlık
		while not file.eof_reached():
			var row := file.get_csv_line()
			if row.size() >= 3 and not row[0].is_empty() and not row[1].strip_edges().is_empty() and not row[2].strip_edges().is_empty():
				keys[row[0]] = true
	return keys


static func validate(db: StoryDb = null) -> Array[String]:
	var story := db if db != null else StoryDb.load_default()
	var errors: Array[String] = []
	var keys := text_keys()
	var written := _written_ids(story)
	for day in range(StoryDb.FIRST_DAY, StoryDb.LAST_DAY + 1):
		var def := story.day_def(day)
		if int(def.get("day", -1)) != day:
			errors.append("day_%02d.json: 'day' alanı %d olmalı" % [day, day])
		_check_beats(story, def, day, keys, written, errors)
		_check_letters(def, day, keys, written, errors)
	_check_characters(story, keys, errors)
	_check_endings(story, keys, written, errors)
	return errors


## Hikayede yazılabilen bayrak ve sayaç kimlikleri (etkilerde geçenler + motorun kendi yazdıkları).
static func _written_ids(story: StoryDb) -> Dictionary:
	var ids := {"skim_count": true, "skim_accepted": true}
	for day in range(StoryDb.FIRST_DAY, StoryDb.LAST_DAY + 1):
		for beat: Dictionary in story.day_def(day).get("beats", []):
			_collect_effects(beat.get("effects", {}), ids)
			for decision: Variant in beat.get("on_decision", {}).keys():
				_collect_effects(beat["on_decision"][decision], ids)
			for option: Dictionary in beat.get("choice", {}).get("options", []):
				_collect_effects(option.get("effects", {}), ids)
	return ids


static func _collect_effects(effects: Dictionary, ids: Dictionary) -> void:
	for id: Variant in effects.get("flags", {}).keys():
		ids[str(id)] = true
	for id: Variant in effects.get("counters", {}).keys():
		ids[str(id)] = true


static func _check_beats(story: StoryDb, def: Dictionary, day: int, keys: Dictionary, written: Dictionary, errors: Array[String]) -> void:
	var seen := {}
	for beat: Dictionary in def.get("beats", []):
		var bid := str(beat.get("id", ""))
		var where := "day_%02d/%s" % [day, bid]
		if not bid.begins_with("d%02d_" % day) or seen.has(bid):
			errors.append("%s: olay kimliği 'd%02d_' ile başlamalı ve benzersiz olmalı" % [where, day])
		seen[bid] = true
		if int(beat.get("after", -1)) < 0 or int(beat.get("after", -1)) > MAX_AFTER:
			errors.append("%s: 'after' 0..%d olmalı (yavaş oyuncu da olayı görebilsin)" % [where, MAX_AFTER])
		if story.character(str(beat.get("character", ""))).is_empty():
			errors.append("%s: bilinmeyen karakter '%s'" % [where, beat.get("character", "")])
		if (beat.get("lines", []) as Array).is_empty():
			errors.append("%s: söylenecek satır yok" % where)
		for key: Variant in beat.get("lines", []):
			if not keys.has(str(key)):
				errors.append("%s: metin anahtarı yok/eksik çeviri: %s" % [where, key])
		_check_requires(beat.get("requires", {}), where, written, errors)
		_check_effects(beat.get("effects", {}), where, errors)
		for decision: Variant in beat.get("on_decision", {}).keys():
			if not (str(decision) in DECISIONS):
				errors.append("%s: on_decision anahtarı complete/reject/police olmalı: %s" % [where, decision])
			_check_effects(beat["on_decision"][decision], where, errors)
		_check_choice(beat, where, keys, written, errors)
		if beat.has("customer"):
			_check_customer(story, beat, day, where, errors)


static func _check_choice(beat: Dictionary, where: String, keys: Dictionary, written: Dictionary, errors: Array[String]) -> void:
	var option_ids := {}
	var options: Array = beat.get("choice", {}).get("options", [])
	if beat.has("choice") and options.size() < 2:
		errors.append("%s: seçim için en az iki seçenek gerekir" % where)
	var has_unconditional := false
	for option: Dictionary in options:
		var option_id := str(option.get("id", ""))
		if option_id.is_empty() or option_ids.has(option_id):
			errors.append("%s: seçenek kimliği boş ya da yinelenmiş" % where)
		option_ids[option_id] = true
		if not keys.has(str(option.get("text", ""))):
			errors.append("%s/%s: seçenek metni yok/eksik çeviri" % [where, option_id])
		_check_requires(option.get("requires", {}), "%s/%s" % [where, option_id], written, errors)
		_check_effects(option.get("effects", {}), "%s/%s" % [where, option_id], errors)
		if not option.has("requires"):
			has_unconditional = true
	if beat.has("choice") and not has_unconditional:
		errors.append("%s: koşulsuz bir seçenek olmalı (oyuncu kilitli kalmasın)" % where)


static func _check_requires(requires: Dictionary, where: String, written: Dictionary, errors: Array[String]) -> void:
	for key: Variant in requires.keys():
		if not (str(key) in REQUIRE_KEYS):
			errors.append("%s: bilinmeyen koşul anahtarı '%s'" % [where, key])
	for group in ["flags", "counters_min", "counters_max"]:
		for id: Variant in requires.get(group, {}).keys():
			if not written.has(str(id)):
				errors.append("%s: koşuldaki '%s' hiçbir yerde yazılmıyor" % [where, id])


static func _check_effects(effects: Dictionary, where: String, errors: Array[String]) -> void:
	for key: Variant in effects.keys():
		if not (str(key) in EFFECT_KEYS):
			errors.append("%s: bilinmeyen etki anahtarı '%s'" % [where, key])


static func _check_customer(story: StoryDb, beat: Dictionary, day: int, where: String, errors: Array[String]) -> void:
	var spec: Dictionary = beat["customer"]
	if not (str(spec.get("scenario", "")) in CustomerFactory.SCENARIOS):
		errors.append("%s: bilinmeyen senaryo '%s'" % [where, spec.get("scenario", "")])
		return
	for salt in SALTS:
		var career := Career.load_default(salt)
		career.day = day
		career.story.set_flag("skim_accepted", false)
		var ctx := career.make_context()
		var director := StoryDirector.new(career, story)
		var customer := director.build_customer(beat, ctx)
		if customer == null:
			errors.append("%s: '%s' senaryosu %d. günde (tuz %s) %s hükmüyle kurulamadı" % [where, spec["scenario"], day, salt, spec.get("expect", "?")])
			continue
		var verdict := RuleEngine.new(ctx).evaluate(customer)
		if verdict.decision != str(customer.truth["decision"]):
			errors.append("%s: motor (%s) senaryonun doğrusundan (%s) ayrışıyor (tuz %s)" % [where, verdict.decision, customer.truth["decision"], salt])


static func _check_letters(def: Dictionary, day: int, keys: Dictionary, written: Dictionary, errors: Array[String]) -> void:
	var letters: Array = def.get("letters", [])
	if letters.is_empty():
		errors.append("day_%02d: akşam mektubu yok" % day)
		return
	if (letters[-1] as Dictionary).has("requires"):
		errors.append("day_%02d: son mektup koşulsuz olmalı (her duruma bir mektup düşsün)" % day)
	for entry: Dictionary in letters:
		if not keys.has(str(entry.get("key", ""))):
			errors.append("day_%02d: mektup metni yok/eksik çeviri: %s" % [day, entry.get("key", "")])
		_check_requires(entry.get("requires", {}), "day_%02d letter" % day, written, errors)


static func _check_characters(story: StoryDb, keys: Dictionary, errors: Array[String]) -> void:
	for character_id: Variant in story.characters.keys():
		var entry: Dictionary = story.characters[character_id]
		if not keys.has(str(entry.get("name_key", ""))):
			errors.append("karakter %s: ad anahtarı yok/eksik çeviri" % character_id)
		if int(entry.get("face_id", 0)) < 400:
			errors.append("karakter %s: face_id 400 havuzunun dışında olmalı" % character_id)


static func _check_endings(story: StoryDb, keys: Dictionary, written: Dictionary, errors: Array[String]) -> void:
	if story.endings.is_empty() or (story.endings[-1] as Dictionary).has("requires") or (story.endings[-1] as Dictionary).has("game_over"):
		errors.append("endings.json: son kayıt koşulsuz bir yedek son olmalı")
	for entry in story.endings:
		var key := str(entry["id"]).to_upper()
		for suffix in ["TITLE", "BODY"]:
			if not keys.has("ENDING_%s_%s" % [key, suffix]):
				errors.append("son %s: ENDING_%s_%s yok/eksik çeviri" % [entry["id"], key, suffix])
		_check_requires(entry.get("requires", {}), "son %s" % entry["id"], written, errors)
