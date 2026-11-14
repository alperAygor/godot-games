class_name EndlessRun
extends ModeRun
## Sonsuz: 3 kuralla başlar, her 5 müşteride rastgele bir kural eklenir; 3 can (hatalı işlem = can kaybı); puan = hizmet verilen müşteri.
## Süre sınırı yoktur. Kurallar çalışırken değişir: aktif küme yeni bir RuleSet olarak ctx'e konur (kural günü sabit, kural başına 1/99999).

var run_seed := ""
var lives := 3
var served := 0
var active_rules: Array[String] = []
## Eklenen kuralların sırası (sonuç ekranı ve testler için).
var added_rules: Array[String] = []
var continues_used := 0
var ctx: DayContext
var _cfg: Dictionary
var _rng: RandomNumberGenerator
var _pool: Array[String] = []


func _init(seed_key: String, config: Dictionary = {}) -> void:
	kind = ModeRun.KIND_ENDLESS
	run_seed = seed_key
	_cfg = config if not config.is_empty() else JsonIO.read_dict("res://data/modes.json")["endless"]
	_rng = Seed.rng("endless-rules|" + seed_key)
	lives = int(_cfg["lives"])
	for rule_id: Variant in _cfg["start_rules"]:
		active_rules.append(str(rule_id))
	for rule_id: Variant in _cfg["rule_pool"]:
		_pool.append(str(rule_id))
	career = ModeRun.make_career("endless-" + seed_key, int(_cfg["rules_day"]))
	career.shift_provider = _build_shift
	shift = _build_shift()


func _build_shift() -> Shift:
	ctx = career.make_context()
	ctx.till = ModeRun.scaled_till(ctx, int(_cfg["till_multiplier"]))
	_apply_rules()
	var factory := CustomerFactory.new(ctx, Seed.rng("endless-customers|" + run_seed))
	var built := Shift.new(ctx, factory)
	built.shift_seconds = 1000000.0
	shift = built
	return built


## Aktif kural kümesini bağlama koyar; çalıntı/aranan kuralları açıldıysa bülteni (yeniden) üretir.
func _apply_rules() -> void:
	var table := JsonIO.read_dict(RuleSet.DEFAULT_PATH)
	for rule: Dictionary in table["rules"]:
		rule["from_day"] = 1 if str(rule["id"]) in active_rules else 99999
	ctx.rules = RuleSet.new(table)
	ctx.bulletin = CustomerFactory.make_bulletin(ctx, Seed.rng("endless-bulletin|%s|%d" % [run_seed, active_rules.size()]))


func hud() -> Dictionary:
	return {"title_key": "MODE_ENDLESS_TITLE", "status_key": "MODE_ENDLESS_STATUS", "status_arg": lives, "score": served}


func score_value() -> int:
	return served


func is_over() -> bool:
	return lives <= 0


## Bir işlem bitti: can/kural güncellenir. Dönen: {"life_lost", "rule_added" ("" olabilir), "over"}.
func on_submit(result: Dictionary) -> Dictionary:
	served += 1
	var outcome := {"life_lost": false, "rule_added": "", "over": false}
	if not bool(result["correct"]):
		lives -= 1
		outcome["life_lost"] = true
	if lives <= 0:
		finished = true
		outcome["over"] = true
		shift.end_now()
		return outcome
	if served % int(_cfg["customers_per_rule"]) == 0 and not _pool.is_empty():
		var rule_id: String = _pool.pop_at(_rng.randi_range(0, _pool.size() - 1))
		active_rules.append(rule_id)
		added_rules.append(rule_id)
		_apply_rules()
		outcome["rule_added"] = rule_id
	return outcome


## `endless_continue` ödüllü reklamı: canlar bittiyse +1 can ile devam (koşu başına bir kez). Başarılıysa true.
func continue_with_life() -> bool:
	if lives > 0 or continues_used >= 1:
		return false
	continues_used += 1
	lives = int(_cfg["continue_lives"])
	finished = false
	shift.resume_open()
	return true
