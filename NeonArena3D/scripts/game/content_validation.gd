extends RefCounted
class_name ContentValidation
## İçerik verisinin (kartlar, gemiler, atölye, haritalar) açılış doğrulaması (saf). Yeni kart/gemi/harita ekleyen
## yazım hatasını oyunda değil açılışta görür: bilinmeyen etki anahtarı, eksik alan, tanımsız sinerji gereksinimi,
## denge verisinde olmayan boss türü… GameData bunu açılışta çağırır ve her hatayı `push_error` ile basar.

const CARD_FIELDS := ["id", "name", "desc", "tier", "effect"]
const SHIP_FIELDS := ["id", "name", "color", "cost", "weapon", "model"]
const UPGRADE_FIELDS := ["id", "name", "costs", "effect"]
const MAP_FIELDS := ["id", "name", "floor_base", "floor_line", "light_a", "props", "boss", "boss_name", "boss_color"]
const WEAPON_TYPES := ["blaster", "scatter", "rail", "rocket"]

static func validate(cards: Array, ships: Array, upgrades: Array, maps: Array, balance: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var mods: Dictionary = Loadout._defaults()
	var card_ids := {}
	for card in cards:
		if typeof(card) != TYPE_DICTIONARY:
			errors.append("cards.json: kart sözlük değil")
			continue
		var id := str(card.get("id", "?"))
		_fields(errors, "kart " + id, card, CARD_FIELDS)
		if card_ids.has(id):
			errors.append("kart kimliği tekrar ediyor: " + id)
		card_ids[id] = true
		if card.has("tier") and not Loadout.TIER_WEIGHT.has(str(card["tier"])):
			errors.append("kart %s: bilinmeyen tier '%s' (%s)" % [id, str(card["tier"]), ", ".join(PackedStringArray(Loadout.TIER_WEIGHT.keys()))])
		_effects(errors, "kart " + id, card.get("effect", {}), mods)
	for card in cards:
		if typeof(card) != TYPE_DICTIONARY:
			continue
		var reqs: Variant = card.get("requires", [])
		if str(card.get("tier", "")) == "synergy" and (typeof(reqs) != TYPE_ARRAY or (reqs as Array).is_empty()):
			errors.append("sinerji kartı %s: 'requires' listesi gerekli" % str(card.get("id", "?")))
		if typeof(reqs) == TYPE_ARRAY:
			for r in reqs:
				if not card_ids.has(str(r)):
					errors.append("kart %s: gereken kart tanımsız: %s" % [str(card.get("id", "?")), str(r)])
	var ship_ids := {}
	for ship in ships:
		if typeof(ship) != TYPE_DICTIONARY:
			errors.append("ships.json: gemi sözlük değil")
			continue
		var id := str(ship.get("id", "?"))
		_fields(errors, "gemi " + id, ship, SHIP_FIELDS)
		if ship_ids.has(id):
			errors.append("gemi kimliği tekrar ediyor: " + id)
		ship_ids[id] = true
		var weapon: Variant = ship.get("weapon", {})
		if typeof(weapon) != TYPE_DICTIONARY or not (str((weapon as Dictionary).get("type", "")) in WEAPON_TYPES):
			errors.append("gemi %s: weapon.type şunlardan biri olmalı: %s" % [id, ", ".join(PackedStringArray(WEAPON_TYPES))])
		_effects(errors, "gemi " + id, ship.get("effect", {}), mods)
	if not ships.is_empty() and not ship_ids.has(MetaProgress.DEFAULT_SHIP):
		errors.append("varsayılan gemi tanımlı değil: " + MetaProgress.DEFAULT_SHIP)
	for def in upgrades:
		if typeof(def) != TYPE_DICTIONARY:
			errors.append("upgrades.json: yükseltme sözlük değil")
			continue
		var id := str(def.get("id", "?"))
		_fields(errors, "yükseltme " + id, def, UPGRADE_FIELDS)
		var costs: Variant = def.get("costs", [])
		if typeof(costs) != TYPE_ARRAY or (costs as Array).is_empty():
			errors.append("yükseltme %s: costs boş olmayan bir dizi olmalı" % id)
		else:
			for c in costs:
				if not BalanceData._is_num(c) or int(c) <= 0:
					errors.append("yükseltme %s: costs pozitif sayılar olmalı" % id)
					break
		_effects(errors, "yükseltme " + id, def.get("effect", {}), mods)
	var boss_kinds: Dictionary = balance.get("boss_kinds", {})
	for theme in maps:
		if typeof(theme) != TYPE_DICTIONARY:
			errors.append("maps.json: harita sözlük değil")
			continue
		var id := str(theme.get("id", "?"))
		_fields(errors, "harita " + id, theme, MAP_FIELDS)
		if theme.has("boss") and not boss_kinds.has(str(theme["boss"])):
			errors.append("harita %s: boss türü '%s' data/balance/bosses.json → boss_kinds içinde yok" % [id, str(theme["boss"])])
	if maps.is_empty():
		errors.append("maps.json: en az bir harita gerekli")
	return errors

static func _fields(errors: PackedStringArray, label: String, def: Dictionary, fields: Array) -> void:
	for field in fields:
		if not def.has(field):
			errors.append("%s: '%s' alanı eksik" % [label, field])

static func _effects(errors: PackedStringArray, label: String, effect: Variant, mods: Dictionary) -> void:
	if typeof(effect) != TYPE_DICTIONARY:
		errors.append("%s: effect sözlük olmalı" % label)
		return
	for key in effect:
		if not mods.has(key):
			errors.append("%s: bilinmeyen etki '%s' (Loadout._defaults() anahtarlarından biri olmalı)" % [label, key])
		elif not BalanceData._is_num(effect[key]):
			errors.append("%s: etki '%s' sayı olmalı" % [label, key])
