extends RefCounted
class_name BalanceData
## Denge verisinin yükleyicisi + doğrulayıcısı (saf; otoyük gerektirmez, testlerden ve simülasyondan da kullanılır).
##
## Veri `data/balance/*.json` dosyalarındadır; her dosya bir ya da birkaç ÜST BÖLÜM taşır ve hepsi tek bir sözlükte
## birleşir (eski tek dosya `data/balance.json` ile aynı şekil). Böylece `GameData.value("waves.max_alive")` gibi yol
## API'si değişmez; yeni düşman, boss ya da sayı eklemek kod değiştirmeden ilgili dosyada yapılır.
##
##   player.json   → player                 (gemi gövdesi, silah tabanı, nova)
##   enemies.json  → enemies, elite         (tür istatistikleri, elit ön eki)
##   bosses.json   → boss, boss_kinds       (temel boss + türe özel üzerine yazmalar)
##   waves.json    → waves, difficulty      (dalga tablosu, dalga başına ölçekleme)
##   scoring.json  → scoring, leveling      (kombo/puan, XP eğrisi, kart sayısı)
##   pickups.json  → pickups                (düşme şansı, ağırlıklar, etkiler)
##   combat.json   → combat                 (eskiden game3d.gd'ye gömülü oynanış sabitleri; bkz. GameTuning)
##
## Bir bölüm iki dosyada birden tanımlanırsa, dosya okunamazsa ya da zorunlu bir alan eksik/yanlış türdeyse
## `errors` dolar; GameData açılışta bunları `push_error` ile tek tek basar (doğrulama kapısının açılış adımı yakalar).

const DIR := "res://data/balance"
const FILES := ["player", "enemies", "bosses", "waves", "scoring", "pickups", "combat"]

## Bölüm → zorunlu sayısal alanlar. Kodda varsayılanı olmayan ya da yanlışsa oyunu bozan alanlar burada.
const REQUIRED := {
	"player": ["max_health", "speed", "accel", "friction", "radius", "fire_interval", "damage", "bullet_speed",
		"dash_speed", "dash_time", "dash_cooldown", "hurt_invuln", "knockback", "nova_cost", "nova_per_kill",
		"nova_radius", "nova_damage", "shield_regen_time", "auto_aim_range"],
	"waves": ["base_count", "growth", "spawn_interval", "interval_decay", "min_interval", "max_alive", "intermission",
		"boss_every", "clear_bonus", "spawn_radius_min", "spawn_radius_max"],
	"difficulty": ["hp_per_wave", "damage_per_wave", "speed_per_wave", "speed_cap"],
	"scoring": ["combo_window", "combo_step", "combo_max"],
	"leveling": ["base_xp", "growth", "cards"],
	"pickups": ["drop_chance", "heal_amount", "overdrive_time", "shield_weight", "overdrive_weight"],
	"elite": ["from_wave", "chance", "chance_per_wave", "chance_max", "hp_mult", "damage_mult", "scale", "points_mult"],
	"boss": ["hp", "speed", "radius", "damage", "points", "phase2_at"],
}
const ENEMY_FIELDS := ["hp", "speed", "radius", "damage", "points", "unlock", "weight"]
const SECTIONS := ["player", "enemies", "elite", "boss", "boss_kinds", "waves", "difficulty", "scoring", "leveling", "pickups", "combat"]

static func load_dir(dir := DIR) -> Dictionary:
	## {"data": birleşik sözlük, "errors": PackedStringArray, "sources": bölüm → dosya}
	var parts: Array = []
	for name in FILES:
		var path: String = dir.path_join(name + ".json")
		if not FileAccess.file_exists(path):
			parts.append([path, null, "denge dosyası yok: " + path])
			continue
		parts.append([path, JSON.parse_string(FileAccess.get_file_as_string(path)), ""])
	return merge(parts)

static func merge(parts: Array) -> Dictionary:
	## Saf birleştirme: `parts` = [[yol, ayrıştırılmış JSON ya da null, okuma hatası], ...] (sıra korunur).
	var data := {}
	var sources := {}
	var errors := PackedStringArray()
	for part in parts:
		var path: String = part[0]
		if str(part[2]) != "":
			errors.append(str(part[2]))
			continue
		if typeof(part[1]) != TYPE_DICTIONARY:
			errors.append("denge dosyası JSON sözlük değil (sözdizimi hatası?): " + path)
			continue
		var parsed: Dictionary = part[1]
		for section in parsed:
			if data.has(section):
				errors.append("bölüm '%s' iki dosyada tanımlı: %s ve %s" % [section, sources[section], path])
				continue
			data[section] = parsed[section]
			sources[section] = path
	if errors.is_empty():
		errors.append_array(validate(data))
	return {"data": data, "errors": errors, "sources": sources}

static func validate(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	for section in SECTIONS:
		if not data.has(section) or typeof(data[section]) != TYPE_DICTIONARY:
			errors.append("denge bölümü eksik ya da sözlük değil: " + section)
	if not errors.is_empty():
		return errors
	for section in REQUIRED:
		_numbers(errors, section, data[section], REQUIRED[section])
	var enemies: Dictionary = data["enemies"]
	if enemies.is_empty():
		errors.append("enemies: en az bir düşman türü gerekli")
	var first_unlock := 1 << 30
	for kind in enemies:
		var stats: Variant = enemies[kind]
		if typeof(stats) != TYPE_DICTIONARY:
			errors.append("enemies.%s sözlük değil" % kind)
			continue
		_numbers(errors, "enemies." + str(kind), stats, ENEMY_FIELDS)
		if not _is_color(stats.get("color", "")):
			errors.append("enemies.%s.color geçersiz renk: %s" % [kind, str(stats.get("color", ""))])
		if _is_num(stats.get("unlock")):
			first_unlock = mini(first_unlock, int(stats["unlock"]))
		for key in ["hp", "speed", "radius"]:
			if _is_num(stats.get(key)) and float(stats[key]) <= 0.0:
				errors.append("enemies.%s.%s pozitif olmalı" % [kind, key])
	if not enemies.has("chaser"):
		errors.append("enemies.chaser gerekli (tank bölünmesi ve yedek tür)")
	if not enemies.is_empty() and first_unlock != 1:
		errors.append("enemies: en az bir tür 1. dalgada açık olmalı (unlock=1)")
	for kind in data["boss_kinds"]:
		if typeof(data["boss_kinds"][kind]) != TYPE_DICTIONARY:
			errors.append("boss_kinds.%s sözlük değil" % kind)
	var waves: Dictionary = data["waves"]
	if _is_num(waves.get("spawn_interval")) and _is_num(waves.get("min_interval")) and float(waves["spawn_interval"]) < float(waves["min_interval"]):
		errors.append("waves.spawn_interval, waves.min_interval'den küçük olamaz")
	if _is_num(waves.get("boss_every")) and int(waves["boss_every"]) < 2:
		errors.append("waves.boss_every en az 2 olmalı")
	if _is_num(waves.get("spawn_radius_min")) and _is_num(waves.get("spawn_radius_max")) and float(waves["spawn_radius_max"]) < float(waves["spawn_radius_min"]):
		errors.append("waves.spawn_radius_max, spawn_radius_min'den küçük olamaz")
	var milestones: Variant = (data["scoring"] as Dictionary).get("milestones", [])
	if typeof(milestones) != TYPE_ARRAY or (milestones as Array).is_empty():
		errors.append("scoring.milestones boş olmayan bir dizi olmalı")
	else:
		var prev := 0
		for m in milestones:
			if not _is_num(m) or int(m) <= prev:
				errors.append("scoring.milestones artan pozitif tam sayılar olmalı")
				break
			prev = int(m)
	errors.append_array(GameTuning.validate(data["combat"]))
	return errors

static func _numbers(errors: PackedStringArray, label: String, section: Dictionary, fields: Array) -> void:
	for field in fields:
		if not section.has(field):
			errors.append("%s.%s eksik" % [label, field])
		elif not _is_num(section[field]):
			errors.append("%s.%s sayı olmalı (gelen: %s)" % [label, field, str(section[field])])

static func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT

static func _is_color(v: Variant) -> bool:
	return typeof(v) == TYPE_STRING and Color.from_string(str(v), Color(0, 0, 0, 0)) != Color(0, 0, 0, 0)
