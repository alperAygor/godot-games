class_name PrizElement
extends RefCounted
## Bir içerik öğesi (data/elements/<id>.json). Biçim için docs/CORE_API.md.

const RULES_DIR: String = "res://scripts/core/rules"

var id: String = ""
var unlock_level: int = 1
## Tanıtım kartı kimlikleri (görsel ve dil dosyası anahtarları; metin değil).
var intro_art: String = ""
var intro_title: String = ""
var intro_body: String = ""
## Açıldıktan sonra her seviyede var mı (oda kısıtı, gün döngüsü)?
var always: bool = false
## always değilse, açıldıktan sonraki bir seviyede seçilme olasılığı (0-1).
var chance: float = 0.0
var rules: Array[PrizRule] = []
var source_path: String = ""
var raw: Dictionary = {}


## Hatalıysa null döner; hata metni `errors` dizisine eklenir.
static func from_dict(d: Dictionary, source: String, errors: PackedStringArray) -> PrizElement:
	var element: PrizElement = PrizElement.new()
	element.raw = d
	element.source_path = source
	element.id = PrizJson.get_str(d, "id")
	if element.id == "":
		errors.append("%s: id yok" % source)
		return null
	element.unlock_level = PrizJson.get_int(d, "unlock_level", 1)
	var intro: Dictionary = PrizJson.get_dict(d, "intro")
	element.intro_art = PrizJson.get_str(intro, "art")
	element.intro_title = PrizJson.get_str(intro, "title")
	element.intro_body = PrizJson.get_str(intro, "body")
	var generator: Dictionary = PrizJson.get_dict(d, "generator")
	element.always = PrizJson.get_bool(generator, "always", false)
	element.chance = float(generator.get("chance", 0.0))
	for entry: Variant in PrizJson.get_array(d, "rules"):
		if typeof(entry) != TYPE_DICTIONARY:
			errors.append("%s: kural sözlük değil" % source)
			return null
		var rule_def: Dictionary = entry
		var rule: PrizRule = _make_rule(rule_def, source, errors)
		if rule == null:
			return null
		rule.setup(element.id, PrizJson.get_dict(rule_def, "params"),
				PrizJson.get_dict(rule_def, "gen"), PrizJson.get_int(rule_def, "order", -1))
		element.rules.append(rule)
	return element


## Kural betiği: "script" verilmişse o yol, yoksa scripts/core/rules/rule_<kind>.gd.
## Göreli "script" yolu öğe dosyasının klasörüne göredir.
static func _make_rule(rule_def: Dictionary, source: String,
		errors: PackedStringArray) -> PrizRule:
	var path: String = PrizJson.get_str(rule_def, "script")
	if path == "":
		var kind: String = PrizJson.get_str(rule_def, "kind")
		if kind == "":
			errors.append("%s: kural türü yok" % source)
			return null
		path = RULES_DIR.path_join("rule_%s.gd" % kind)
	elif not path.begins_with("res://"):
		path = source.get_base_dir().path_join(path)
	if not ResourceLoader.exists(path):
		errors.append("%s: kural betiği yok: %s" % [source, path])
		return null
	var script: GDScript = load(path) as GDScript
	if script == null or not script.can_instantiate():
		errors.append("%s: kural betiği yüklenemedi: %s" % [source, path])
		return null
	var instance: Object = script.new()
	var rule: PrizRule = instance as PrizRule
	if rule == null:
		errors.append("%s: betik PrizRule değil: %s" % [source, path])
		return null
	return rule
