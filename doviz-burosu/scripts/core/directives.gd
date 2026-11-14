class_name Directives
extends RefCounted
## Merkez talimatları: günün hedefi (örn. "en az 13 müşteri", "en çok 2 ret"). Yerine getirilirse prim, getirilmezse kesinti
## maaşa işler. Talimat kurala değil teşvike bağlıdır: doğru karar hep aynıdır, talimat onu yanlışa itmeye çalışabilir.
## Tanımlar data/office.json `directives`; seçim gün + tuzdan deterministiktir.

## Talimat türü -> Shift.stats anahtarı; "at_least" türleri hedefe ULAŞINCA, "at_most" türleri AŞILMAYINCA sağlanır.
const STAT_OF := {
	"min_served": "served", "max_rejects": "rejects", "min_police": "polices",
	"max_police": "polices", "max_mistakes": "mistake_transactions", "min_complete": "completes",
}


static func config() -> Dictionary:
	return JsonIO.read_dict("res://data/office.json")


static func by_id(id: String) -> Dictionary:
	for def: Dictionary in config().get("directives", []):
		if str(def["id"]) == id:
			return def.duplicate()
	return {}


## O günün talimatı; boş sözlük = talimat yok (eğitim günleri). Müfettiş günü sabittir.
static func pick(day: int, salt: String) -> Dictionary:
	var cfg := config()
	if day < int(cfg.get("directive_from_day", 3)):
		return {}
	if day == int(JsonIO.get_path_value(JsonIO.read_dict("res://data/balance.json"), "story.inspector_day", 14)):
		return by_id(str(cfg.get("inspector_day_directive", "clean")))
	var pool: Array[Dictionary] = []
	var total := 0
	for def: Dictionary in cfg.get("directives", []):
		if int(def["from_day"]) <= day:
			pool.append(def)
			total += int(def["weight"])
	if pool.is_empty():
		return {}
	var roll := Seed.rng("directive|%s|%d" % [salt, day]).randi_range(1, total)
	for def in pool:
		roll -= int(def["weight"])
		if roll <= 0:
			return def.duplicate()
	return pool[-1].duplicate()


## Bugünkü talimattan farklı rastgele bir talimat (tüple gelen "talimat değişti" notu için).
static func pick_other(day: int, salt: String, current_id: String) -> Dictionary:
	var rng := Seed.rng("directive-change|%s|%d" % [salt, day])
	var options: Array[Dictionary] = []
	for def: Dictionary in config().get("directives", []):
		if int(def["from_day"]) <= day and str(def["id"]) != current_id:
			options.append(def)
	return {} if options.is_empty() else (Seed.pick(rng, options) as Dictionary).duplicate()


static func is_at_least(def: Dictionary) -> bool:
	return str(def.get("type", "")).begins_with("min_")


## Anlık durum: {progress, target, at_least, met (şu an sağlanıyor), failed (artık sağlanamaz)}.
static func status(def: Dictionary, stats: Dictionary) -> Dictionary:
	if def.is_empty():
		return {}
	var progress := int(stats.get(STAT_OF[str(def["type"])], 0))
	var target := int(def["value"])
	var at_least := is_at_least(def)
	return {
		"progress": progress, "target": target, "at_least": at_least,
		"met": progress >= target if at_least else progress <= target,
		"failed": false if at_least else progress > target,
	}


## Vardiya bitince maaşa işleyen tutar (kuruş): sağlandıysa +prim, değilse -kesinti.
static func result_minor(def: Dictionary, stats: Dictionary) -> int:
	if def.is_empty():
		return 0
	if bool(status(def, stats)["met"]):
		return Money.units(int(def["reward_pl"]))
	return -Money.units(int(def["penalty_pl"]))
