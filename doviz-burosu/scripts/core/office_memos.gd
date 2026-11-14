class_name OfficeMemos
extends RefCounted
## Gün içinde pnömatik tüple gelen ofis notları. Plan gün + tuzdan deterministiktir.
## Not = {id, at_served, kind, sender_key, text_key, ...}. `kind`:
## - flavor: yalnızca metin (patron, muhasebe, temizlik...).
## - stolen_add: acil bülten; ÇALINTI bir seri aralığı eklenir. Not okunmasa da aralık bülten listesine girer:
##   okumayan oyuncu o seriyi tanımaz (gerçek bir kural, gerçek bir risk).
## - directive_change: o günün talimatı değişir (`directive_id`).
## - call: telefon; seçenekli (para, aile ruh hali, iyilik). Cevapsız kalan arama akşam ruh halini düşürür.

const SENDERS := ["MEMO_SENDER_REGION", "MEMO_SENDER_RIZA", "MEMO_SENDER_ACCOUNTING", "MEMO_SENDER_CLEANING", "MEMO_SENDER_CENTER"]


## O günün not planı (gün 4'ten itibaren). `ctx`: açık kuralları ve para birimlerini bilmek için.
static func plan(day: int, salt: String, ctx: DayContext) -> Array[Dictionary]:
	var cfg: Dictionary = Directives.config()
	var result: Array[Dictionary] = []
	if day < int(cfg.get("memo_from_day", 4)):
		return result
	var memo_cfg: Dictionary = cfg.get("memos", {})
	var rng := Seed.rng("memos|%s|%d" % [salt, day])
	var count := 1
	if day >= int(memo_cfg.get("second_memo_from_day", 9)) and rng.randi_range(1, 100) <= int(memo_cfg.get("second_memo_percent", 35)):
		count = 2
	var used_flavor: Array[String] = []
	for index in count:
		var kind := _pick_kind(rng, day, memo_cfg, ctx)
		var memo := {"id": "m%d_%d" % [day, index], "kind": kind,
			"at_served": rng.randi_range(int(memo_cfg.get("min_served", 2)), int(memo_cfg.get("max_served", 7)))}
		match kind:
			"flavor":
				var flavors: Array = memo_cfg.get("flavor", [])
				var choice := str(Seed.pick(rng, flavors))
				while choice in used_flavor and used_flavor.size() < flavors.size():
					choice = str(Seed.pick(rng, flavors))
				used_flavor.append(choice)
				memo["text_key"] = "MEMO_%s" % choice
				memo["sender_key"] = str(SENDERS[(flavors.find(choice)) % SENDERS.size()])
			"stolen_add":
				memo["text_key"] = "MEMO_STOLEN"
				memo["sender_key"] = "MEMO_SENDER_CENTER"
			"directive_change":
				memo["text_key"] = "MEMO_CHANGE"
				memo["sender_key"] = "MEMO_SENDER_REGION"
			"call":
				var calls: Array[Dictionary] = _calls_for(day)
				var call_def: Dictionary = Seed.pick(rng, calls)
				memo["call_id"] = call_def["id"]
				memo["text_key"] = call_def["text_key"]
				memo["sender_key"] = call_def["sender_key"]
		result.append(memo)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at_served"]) < int(b["at_served"]))
	return result


static func _pick_kind(rng: RandomNumberGenerator, day: int, memo_cfg: Dictionary, ctx: DayContext) -> String:
	var weights: Dictionary = memo_cfg.get("kind_weights", {"flavor": 1})
	var options: Array[String] = []
	var total := 0
	for kind: Variant in weights.keys():
		if str(kind) == "stolen_add" and (not ctx.rule_active("R_STOLEN") or day < int(memo_cfg.get("stolen_from_day", 7))):
			continue
		if str(kind) == "call" and (day < int(memo_cfg.get("calls_from_day", 4)) or _calls_for(day).is_empty()):
			continue
		options.append(str(kind))
		total += int(weights[kind])
	var roll := rng.randi_range(1, maxi(1, total))
	for kind in options:
		roll -= int(weights[kind])
		if roll <= 0:
			return kind
	return "flavor"


static func _calls_for(day: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for call_def: Dictionary in Directives.config().get("calls", []):
		if int(call_def["from_day"]) <= day:
			result.append(call_def)
	return result


static func call_def(call_id: String) -> Dictionary:
	for def: Dictionary in Directives.config().get("calls", []):
		if str(def["id"]) == call_id:
			return def
	return {}


## Notu vardiyaya uygular (tüp düştüğü an): bülteni/talimatı değiştirir, gösterilecek bilgiyi nota ekler.
static func deliver(memo: Dictionary, shift: Shift, salt: String) -> Dictionary:
	var delivered := memo.duplicate(true)
	match str(memo["kind"]):
		"stolen_add":
			var bulletin := CustomerFactory.make_bulletin(shift.ctx, Seed.rng("memo-stolen|%s|%d|%s" % [salt, shift.ctx.day, memo["id"]]))
			if not bulletin.stolen_ranges.is_empty():
				var range_def: Dictionary = bulletin.stolen_ranges[0]
				shift.ctx.bulletin.add_stolen(str(range_def["currency"]), str(range_def["series_id"]), int(range_def["from"]), int(range_def["to"]))
				delivered["currency"] = range_def["currency"]
				delivered["from_serial"] = shift.ctx.book.make_serial(range_def["currency"], range_def["series_id"], int(range_def["from"]))
				delivered["to_serial"] = shift.ctx.book.make_serial(range_def["currency"], range_def["series_id"], int(range_def["to"]))
		"directive_change":
			var other := Directives.pick_other(shift.ctx.day, salt, str(shift.directive.get("id", "")))
			if not other.is_empty():
				shift.directive = other
				delivered["directive_id"] = other["id"]
		"call":
			delivered["options"] = (call_def(str(memo.get("call_id", ""))).get("options", []) as Array).duplicate(true)
			delivered["answered"] = ""
	delivered["read"] = false
	return delivered
