class_name RuleSet
extends RefCounted
## data/rules.json: hangi kural hangi günden itibaren geçerli, hangi sahtecilikleri yakalar, sınırları nedir.

const DEFAULT_PATH := "res://data/rules.json"

var _rules: Array[Dictionary] = []
var _by_id := {}


func _init(table: Dictionary = {}) -> void:
	for rule: Variant in table.get("rules", []):
		_rules.append(rule)
		_by_id[str(rule["id"])] = rule


static func load_default() -> RuleSet:
	return RuleSet.new(JsonIO.read_dict(DEFAULT_PATH))


func all() -> Array[Dictionary]:
	return _rules


func has(rule_id: String) -> bool:
	return _by_id.has(rule_id)


func rule(rule_id: String) -> Dictionary:
	return _by_id.get(rule_id, {})


func from_day(rule_id: String) -> int:
	return int(rule(rule_id).get("from_day", 9999))


func is_active(rule_id: String, day: int) -> bool:
	return has(rule_id) and day >= from_day(rule_id)


func active_ids(day: int) -> Array[String]:
	var result: Array[String] = []
	for rule_def in _rules:
		if day >= int(rule_def["from_day"]):
			result.append(str(rule_def["id"]))
	return result


## İşlem değeri (PL, kuruş) bu sınırı AŞARSA kural devreye girer. Sınır yoksa 0.
func limit_minor(rule_id: String) -> int:
	return int(rule(rule_id).get("limit_pl_minor", 0))


## `fake` türünü yakalayan, o gün açık sahtecilik kuralları.
func rules_for_fake(fake: String, day: int) -> Array[String]:
	var result: Array[String] = []
	for rule_def in _rules:
		if int(rule_def["from_day"]) <= day and rule_def.get("check") == "counterfeit" and fake in rule_def.get("fakes", []):
			result.append(str(rule_def["id"]))
	return result


## Kural kimliklerini dosyadaki sıraya göre dizer, tekrarları atar.
func sorted_unique(ids: Array) -> Array[String]:
	var result: Array[String] = []
	for rule_def in _rules:
		var rule_id := str(rule_def["id"])
		if rule_id in ids:
			result.append(rule_id)
	return result
