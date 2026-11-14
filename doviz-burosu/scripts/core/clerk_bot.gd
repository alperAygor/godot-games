class_name ClerkBot
extends RefCounted
## Test botu: bir memur gibi vardiya oynar. Denge ölçmek ve tüm oyunu arayüzsüz sınamak için kullanılır.
## Profiller:
## - perfect:  her müşteride beklenen hükmü birebir uygular.
## - careless: müşterilerin error_percent kadarında rastgele bir hata yapar (yanlış karar / banknot kaderi / neden / ödeme).
## - cheater:  kusursuz oynar, ama patronun önerisini kabul eder ve her "PL ödeyen" işlemde skim kadar eksik öder.
## Hikaye profilleri (Career.story_enabled açıkken; hamleleri hep kusursuz, seçimleri etiketle yapar):
## - ally:     Deniz'e yardım eder, kanıt verir (Muhbir sonu).
## - escaper:  Tilki'nin zarflarını alır, FED biriktirir, pasaportu satın alır (Kaçış sonu).
## - merciful: kendi cebinden yardım eder, kuralı çiğnemez (Merhametli Memur sonu).
## - helper:   Zarfları alır, Tilki'ye ve Hayri Amca'ya kuralı eğip yardım eder (müfettiş riski).
## `story_tags`: seçim etiketi tercihi (sırayla); `help`: kuralı eğilen karakterler; `save_fed`: artan nakdi FED'e çevirir.

const PROFILES := {
	"perfect": {"think_seconds": 20.0, "error_percent": 0, "skim": false, "buys_tools": true},
	"careless": {"think_seconds": 17.0, "error_percent": 15, "skim": false, "buys_tools": false},
	"cheater": {"think_seconds": 20.0, "error_percent": 0, "skim": true, "buys_tools": false, "story_tags": ["skim"]},
	"ally": {"think_seconds": 20.0, "error_percent": 0, "skim": false, "buys_tools": true, "story_tags": ["ally", "evidence"]},
	"escaper": {"think_seconds": 20.0, "error_percent": 0, "skim": false, "buys_tools": false, "story_tags": ["bribe", "escape"], "save_fed": true},
	"merciful": {"think_seconds": 20.0, "error_percent": 0, "skim": false, "buys_tools": false, "story_tags": ["kind"]},
	"helper": {"think_seconds": 20.0, "error_percent": 0, "skim": false, "buys_tools": false, "story_tags": ["bribe"], "help": ["tilki", "hayri"]},
}

var profile_name: String
var profile: Dictionary
var rng: RandomNumberGenerator

var _rule_ids: Array[String] = []


func _init(profile_id: String, seed_key: String) -> void:
	profile_name = profile_id
	profile = PROFILES[profile_id]
	rng = Seed.rng("bot|%s|%s" % [profile_id, seed_key])


## Bir müşteri için hamle. `skim_minor` > 0 ise ve profil hilekârsa PL ödemesinden bu kadar keser.
func move_for(customer: Customer, verdict: Verdict, skim_minor := 0) -> PlayerMove:
	var move := PlayerMove.new()
	if customer.character in profile.get("help", []):
		move.decision = Verdict.DECISION_COMPLETE  # kuralı eğer: her şeyi kabul edip işlemi tamamlar
		for i in customer.notes.size():
			move.fates.append(Verdict.FATE_ACCEPT)
		return move
	move.decision = verdict.decision
	move.fates = verdict.fates.duplicate()
	move.paid = verdict.pay_out.duplicate()
	move.reason = "" if verdict.reasons.is_empty() else verdict.reasons[0]
	if skim_minor > 0 and profile["skim"] and verdict.decision == Verdict.DECISION_COMPLETE \
			and customer.intent == Customer.INTENT_SELL and int(move.paid.get("PL", 0)) > skim_minor:
		move.paid["PL"] = int(move.paid["PL"]) - skim_minor
	if Seed.chance(rng, int(profile["error_percent"])):
		_make_mistake(move, verdict, customer)
	return move


## Müşteri başına düşünme süresi (sn), ±%30 oynar.
func think_seconds() -> float:
	return float(profile["think_seconds"]) * rng.randf_range(0.7, 1.3)


## Bir vardiyayı baştan sona oynar (shift.start() çağırır).
func play_shift(shift: Shift) -> void:
	shift.start()
	var guard := 0
	while not shift.is_closed() and guard < 10000:
		guard += 1
		resolve_story(shift)
		if shift.current == null:
			shift.advance(1.0)
			continue
		shift.advance(think_seconds())
		shift.submit(move_for(shift.current, shift.current_verdict, shift.skim_minor))


## Bekleyen hikaye olayı varsa profilin etiket tercihiyle çözer.
func resolve_story(shift: Shift) -> void:
	if shift.pending_beat.is_empty():
		return
	shift.resolve_beat(shift.director.pick_option(shift.pending_beat, profile.get("story_tags", [])))


## Akşam: nakit (bugünkü maaş dahil) yettiği kadar giderleri öncelik sırasıyla öder.
func choose_paid_ids(career: Career, shift: Shift) -> Array:
	return career.affordable_expense_ids(shift)


## Akşam dükkanı: bugünkü giderleri ve bir günlük yedeği karşıladıktan sonra artan nakitle araç alır.
func buy_tools(career: Career) -> void:
	var due_total := 0
	for expense in career.household.due_expenses(career.day):
		due_total += int(expense["amount_minor"])
	var reserve := Money.units(int(profile.get("tool_reserve_pl", 250)))
	for tool_id in career.buyable_tool_ids():
		if career.household.cash_minor - career.tool_price_minor(tool_id) >= due_total + reserve:
			career.buy_tool(tool_id)


## Pasaport için FED biriktirir: 14. akşam, ertesi günün giderine yetecek nakdi bırakıp `fed_target_minor` kadar FED alır
## (ertesi günün maaşı ~330 PL sayılır). Nakit yetmiyorsa hiçbir şey yapmaz.
func save_fed(career: Career, shift: Shift, paid_ids: Array) -> void:
	if career.day < int(profile.get("fed_from_day", 14)):
		return
	var need := int(profile.get("fed_target_minor", 1000)) - int(career.household.savings.get("FED", 0))
	if need <= 0:
		return
	var spare := career.household.cash_minor
	for expense in career.household.due_expenses(career.day):
		if expense["id"] in paid_ids:
			spare -= int(expense["amount_minor"])
	var next_due := 0
	for expense in career.household.due_expenses(career.day + 1):
		next_due += int(expense["amount_minor"])
	spare -= maxi(0, next_due - Money.units(330)) + Money.units(50)
	var sell := int(shift.ctx.rates.rates("FED", career.day)["sell"])
	var cost := Money.mul_div_ceil(need, sell, Money.RATE_SCALE) + 500
	if spare >= cost:
		career.household.convert_to_foreign("FED", cost, shift.ctx.rates, career.day)


## `days` gün (ya da oyun bitene kadar) oynar; günlük raporları döndürür.
func play_career(career: Career, days: int) -> Array[Dictionary]:
	var reports: Array[Dictionary] = []
	for i in days:
		if career.is_over():
			break
		if profile["skim"] and career.day >= int(JsonIO.get_path_value(career._balance, "story.skim_offer_day", 8)):
			career.accept_skim()
		var shift := career.new_shift()
		play_shift(shift)
		career.begin_evening(shift)
		if profile["buys_tools"]:
			buy_tools(career)
		var paid_ids := choose_paid_ids(career, shift)
		if profile.get("save_fed", false):
			save_fed(career, shift, paid_ids)
		reports.append(career.settle_evening(paid_ids))
	return reports


func _make_mistake(move: PlayerMove, verdict: Verdict, customer: Customer) -> void:
	var options: Array[String] = ["decision"]
	if not move.fates.is_empty():
		options.append("fate")
	if verdict.decision == Verdict.DECISION_COMPLETE and not move.paid.is_empty():
		options.append("payment")
	if verdict.decision == Verdict.DECISION_REJECT and not verdict.reasons.is_empty():
		options.append("reason")
	match str(Seed.pick(rng, options)):
		"decision":
			var others: Array[String] = []
			for decision: String in [Verdict.DECISION_COMPLETE, Verdict.DECISION_REJECT, Verdict.DECISION_POLICE]:
				if decision != verdict.decision:
					others.append(decision)
			move.decision = str(Seed.pick(rng, others))
			move.paid = {}
		"fate":
			var index := rng.randi_range(0, move.fates.size() - 1)
			var fates: Array[String] = [Verdict.FATE_ACCEPT, Verdict.FATE_RETURN, Verdict.FATE_CONFISCATE]
			fates.erase(move.fates[index])
			move.fates[index] = str(Seed.pick(rng, fates))
		"payment":
			var code := str(Seed.pick(rng, move.paid.keys()))
			var delta := 500 * rng.randi_range(1, 4) * (1 if Seed.chance(rng, 50) else -1)
			move.paid[code] = maxi(0, int(move.paid[code]) + delta)
			if move.paid[code] == int(verdict.pay_out[code]):
				move.paid[code] = int(move.paid[code]) + 500
		"reason":
			var wrong: Array[String] = []
			if _rule_ids.is_empty():
				_rule_ids = RuleSet.load_default().active_ids(99)
			for rule_id in _rule_ids:
				if not (rule_id in verdict.reasons):
					wrong.append(rule_id)
			move.reason = str(Seed.pick(rng, wrong)) if not wrong.is_empty() else ""

