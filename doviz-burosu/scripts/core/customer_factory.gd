class_name CustomerFactory
extends RefCounted
## Müşteri üretir. Her müşteri bir SENARYO ile kurulur ve senaryonun doğru cevabı (`customer.truth`) RuleEngine'den
## bağımsız olarak burada hesaplanır; böylece motor kendi kendine doğrulanır (test_customer_factory.gd).
## Yalnızca o gün AÇIK kuralların senaryoları üretilir. Aynı tohum aynı müşterileri verir.
##
## Senaryolar: clean, taped, counterfeit, old_series, torn, stolen, stolen_torn, id_missing, id_expired, id_other,
## id_forged, decl_missing, decl_amount, decl_signature, wanted, no_stock.

const SCENARIOS: Array[String] = [
	"clean", "taped", "counterfeit", "old_series", "torn", "stolen", "stolen_torn", "id_missing", "id_expired",
	"id_other", "id_forged", "decl_missing", "decl_amount", "decl_signature", "wanted", "no_stock",
]
const NO_MAX := 1 << 60

var ctx: DayContext
var rng: RandomNumberGenerator
var params: Dictionary
var notes: NoteFactory
## Hikaye müşterisi için sabit kimlik: {"holder_name", "face_id"}. Boşsa ad ve yüz rastgele.
var identity: Dictionary = {}

var _next_id := 0


## `customer_params`: data/customers.json (boşsa dosyadan okunur).
func _init(context: DayContext, generator: RandomNumberGenerator, customer_params: Dictionary = {}) -> void:
	ctx = context
	rng = generator
	params = customer_params if not customer_params.is_empty() else JsonIO.read_dict("res://data/customers.json")
	notes = NoteFactory.new(ctx.book, rng, JsonIO.get_path_value(ctx.balance, "notes", {}))


## Günün bülteni: çalıntı seri aralıkları (R_STOLEN açıksa) ve aranan yüzler (R_WANTED açıksa).
static func make_bulletin(context: DayContext, generator: RandomNumberGenerator, customer_params: Dictionary = {}) -> Bulletin:
	var cfg: Dictionary = customer_params if not customer_params.is_empty() else JsonIO.read_dict("res://data/customers.json")
	var bulletin := Bulletin.new()
	var section: Dictionary = cfg.get("bulletin", {})
	if context.rule_active("R_STOLEN"):
		var codes: Array[String] = [context.book.local_code]
		codes.append_array(context.book.foreign_codes(context.day))
		var width := int(section.get("stolen_range_width", 2000))
		for i in int(section.get("stolen_ranges_per_day", 3)):
			var code := str(Seed.pick(generator, codes))
			var series_id := str(Seed.pick(generator, context.book.valid_series(code, context.day)))
			var highest := int(pow(10, context.book.serial_digits(code))) - 1
			var from_number := generator.randi_range(0, highest - width)
			bulletin.add_stolen(code, series_id, from_number, from_number + width - 1)
	if context.rule_active("R_WANTED"):
		var pool := int(cfg.get("face_pool", 400))
		while bulletin.wanted_faces.size() < int(section.get("wanted_per_day", 2)):
			var face := generator.randi_range(0, pool - 1)
			if not bulletin.is_wanted(face):
				bulletin.wanted_faces.append(face)
	return bulletin


## Bugün üretilebilecek senaryolar (kural açık ve ön koşullar var).
func available_scenarios() -> Array[String]:
	var result: Array[String] = []
	for scenario in SCENARIOS:
		if float(params.get("scenario_weights", {}).get(scenario, 0)) > 0 and _possible(scenario):
			result.append(scenario)
	return result


## Ağırlıklara göre rastgele bir senaryoyla müşteri üretir (kurulamazsa temiz müşteri).
func make_random() -> Customer:
	var weights: Dictionary = params.get("scenario_weights", {})
	var available := available_scenarios()
	var total := 0.0
	for scenario in available:
		total += float(weights[scenario])
	var pick := rng.randf() * total
	var chosen := "clean"
	for scenario in available:
		pick -= float(weights[scenario])
		if pick <= 0.0:
			chosen = scenario
			break
	var customer := make_scenario(chosen)
	return customer if customer != null else make_scenario("clean")


## Belirli bir senaryoyla müşteri üretir; o gün kurulamıyorsa null.
func make_scenario(scenario: String) -> Customer:
	var customer: Customer = null
	match scenario:
		"clean":
			customer = _clean_customer()
		"taped":
			customer = _taped()
		"counterfeit":
			customer = _counterfeit()
		"old_series":
			customer = _old_series()
		"torn":
			customer = _torn()
		"stolen":
			customer = _stolen(false)
		"stolen_torn":
			customer = _stolen(true)
		"id_missing", "id_expired", "id_other", "id_forged":
			customer = _id_problem(scenario)
		"decl_missing", "decl_amount", "decl_signature":
			customer = _declaration_problem(scenario)
		"wanted":
			customer = _wanted()
		"no_stock":
			customer = _no_stock()
	if customer != null:
		customer.scenario = scenario
	return customer


# --- Senaryolar --------------------------------------------------------------

func _clean_customer() -> Customer:
	var customer := _base()
	_finish(customer)
	customer.truth = _truth(Verdict.DECISION_COMPLETE, [])
	return customer


func _taped() -> Customer:
	if not ctx.rule_active("R_TORN"):
		return null
	var customer := _base()
	var index := rng.randi_range(0, customer.notes.size() - 1)
	var old := customer.notes[index]
	customer.notes[index] = _genuine(old.currency, old.denom, {"taped": true})
	_finish(customer)
	customer.truth = _truth(Verdict.DECISION_COMPLETE, [])
	return customer


func _counterfeit() -> Customer:
	var fakes := _detectable_fakes()
	if fakes.is_empty():
		return null
	var customer := _base()
	var chosen: Array[String] = [str(Seed.pick(rng, fakes))]
	if Seed.chance(rng, int(params.get("counterfeit_multi_percent", 20))):
		chosen.append(str(Seed.pick(rng, fakes)))
	var index := rng.randi_range(0, customer.notes.size() - 1)
	var old := customer.notes[index]
	customer.notes[index] = _genuine(old.currency, old.denom, {}, chosen)
	var reasons: Array[String] = []
	for fake in chosen:
		reasons.append_array(ctx.rules.rules_for_fake(fake, ctx.day))
	_finish(customer)
	customer.truth = _truth(Verdict.DECISION_POLICE, reasons)
	return customer


func _old_series() -> Customer:
	if not ctx.rule_active("R_SERIES"):
		return null
	var codes: Array[String] = []
	for code in ctx.book.foreign_codes(ctx.day):
		if not ctx.book.expired_series(code, ctx.day).is_empty():
			codes.append(code)
	if codes.is_empty():
		return null
	var code := str(Seed.pick(rng, codes))
	var customer := _new_customer(Customer.INTENT_SELL, code)
	var affordable := _affordable_denoms(code, _clean_cap() / 3)
	var valid_count := rng.randi_range(0, 2)
	for i in valid_count:
		customer.notes.append(_genuine(code, int(Seed.pick(rng, affordable))))
	var old_series := str(Seed.pick(rng, ctx.book.expired_series(code, ctx.day)))
	var old_note := notes.make_genuine(code, int(Seed.pick(rng, affordable)), ctx.day, {"series_id": old_series})
	customer.notes.insert(rng.randi_range(0, customer.notes.size()), old_note)
	_finish(customer)
	customer.truth = _truth(Verdict.DECISION_COMPLETE if valid_count > 0 else Verdict.DECISION_REJECT, [] if valid_count > 0 else ["R_SERIES"])
	return customer


func _torn() -> Customer:
	if not ctx.rule_active("R_TORN"):
		return null
	var customer := _base()
	var index := rng.randi_range(0, customer.notes.size() - 1)
	var old := customer.notes[index]
	customer.notes[index] = _genuine(old.currency, old.denom, {"torn": true})
	_finish(customer)
	var others := customer.notes.size() - 1
	var usable := customer.intent == Customer.INTENT_SELL and others > 0
	customer.truth = _truth(Verdict.DECISION_COMPLETE if usable else Verdict.DECISION_REJECT, [] if usable else ["R_TORN"])
	return customer


func _stolen(also_torn: bool) -> Customer:
	if not ctx.rule_active("R_STOLEN") or ctx.bulletin.stolen_ranges.is_empty() or (also_torn and not ctx.rule_active("R_TORN")):
		return null
	var range_def: Dictionary = Seed.pick(rng, ctx.bulletin.stolen_ranges)
	var code: String = range_def["currency"]
	var customer: Customer
	if ctx.book.is_local(code):
		customer = _buy_customer()
	else:
		customer = _sell_customer(0, _clean_cap(), 1, int(params.get("max_notes_clean", 4)), code)
	if customer == null:
		return null
	var candidates: Array[int] = []
	for i in customer.notes.size():
		if customer.notes[i].currency == code:
			candidates.append(i)
	if candidates.is_empty():
		return null
	var index: int = candidates[rng.randi_range(0, candidates.size() - 1)]
	var options := {"series_id": range_def["series_id"], "serial_number": rng.randi_range(int(range_def["from"]), int(range_def["to"]))}
	if also_torn:
		options["torn"] = true
	customer.notes[index] = _genuine(code, customer.notes[index].denom, options)
	_finish(customer)
	customer.truth = _truth(Verdict.DECISION_POLICE, ["R_STOLEN"])
	return customer


func _id_problem(scenario: String) -> Customer:
	if not ctx.rule_active("R_ID_LIMIT"):
		return null
	var low := ctx.rules.limit_minor("R_ID_LIMIT") + 1
	var high := ctx.rules.limit_minor("R_SOURCE") - 1 if ctx.rule_active("R_SOURCE") else NO_MAX
	var customer := _sell_customer(low, high, 1, int(params.get("max_notes_clean", 4)))
	if customer == null:
		return null
	_finish(customer)
	var decision := Verdict.DECISION_REJECT
	match scenario:
		"id_missing":
			customer.id_card = null
		"id_expired":
			customer.id_card.expiry_day = ctx.day - rng.randi_range(1, 20)
		"id_other":
			customer.id_card.face_id = (customer.face_id + rng.randi_range(1, 50)) % int(params.get("face_pool", 400))
		"id_forged":
			customer.id_card.number = _broken_number(customer.id_card.number)
			decision = Verdict.DECISION_POLICE
	customer.truth = _truth(decision, ["R_ID_LIMIT"])
	return customer


func _declaration_problem(scenario: String) -> Customer:
	if not ctx.rule_active("R_SOURCE") or (scenario == "decl_signature" and not ctx.rule_active("R_ID_LIMIT")):
		return null
	var low := ctx.rules.limit_minor("R_SOURCE") + 1
	var high := int(params.get("big_value_cap_pl_minor", 1500000))
	var customer := _sell_customer(low, high, 1, int(params.get("max_notes_big", 12)))
	if customer == null:
		return null
	_finish(customer)
	var decision := Verdict.DECISION_POLICE
	match scenario:
		"decl_missing":
			customer.declaration = null
			decision = Verdict.DECISION_REJECT
		"decl_amount":
			customer.declaration.amount_minor += rng.randi_range(1, 100) * 500 * (1 if Seed.chance(rng, 50) else -1)
		"decl_signature":
			customer.declaration.signature = "sig-%d" % rng.randi_range(10000, 99999)
	customer.truth = _truth(decision, ["R_SOURCE"])
	return customer


func _wanted() -> Customer:
	if not ctx.rule_active("R_WANTED") or ctx.bulletin.wanted_faces.is_empty():
		return null
	var customer := _base()
	customer.face_id = int(Seed.pick(rng, ctx.bulletin.wanted_faces))
	_finish(customer)
	customer.truth = _truth(Verdict.DECISION_POLICE, ["R_WANTED"])
	return customer


func _no_stock() -> Customer:
	if not ctx.rule_active("R_SELL_FOREIGN"):
		return null
	var code := str(Seed.pick(rng, ctx.book.foreign_codes(ctx.day)))
	var smallest: int = ctx.book.denominations(code)[0]
	var requested := ctx.till.total_minor(code) + Money.units(smallest) * rng.randi_range(1, 3)
	var customer := _new_customer(Customer.INTENT_BUY, code)
	customer.requested_foreign_minor = requested
	var cost := ctx.rates.sell_cost(code, requested, ctx.day, ctx.use_midday_rates())
	customer.notes = _pl_notes_for(cost)
	_finish(customer)
	customer.truth = _truth(Verdict.DECISION_REJECT, ["R_SELL_FOREIGN"])
	return customer


# --- Kurma yardımcıları -----------------------------------------------------------

func _possible(scenario: String) -> bool:
	match scenario:
		"clean":
			return true
		"taped", "torn":
			return ctx.rule_active("R_TORN")
		"counterfeit":
			return not _detectable_fakes().is_empty()
		"old_series":
			return ctx.rule_active("R_SERIES") and _has_expired_series()
		"stolen":
			return ctx.rule_active("R_STOLEN") and not ctx.bulletin.stolen_ranges.is_empty()
		"stolen_torn":
			return ctx.rule_active("R_STOLEN") and ctx.rule_active("R_TORN") and not ctx.bulletin.stolen_ranges.is_empty()
		"id_missing", "id_expired", "id_other", "id_forged":
			return ctx.rule_active("R_ID_LIMIT")
		"decl_missing", "decl_amount":
			return ctx.rule_active("R_SOURCE")
		"decl_signature":
			return ctx.rule_active("R_SOURCE") and ctx.rule_active("R_ID_LIMIT")
		"wanted":
			return ctx.rule_active("R_WANTED") and not ctx.bulletin.wanted_faces.is_empty()
		"no_stock":
			return ctx.rule_active("R_SELL_FOREIGN")
	return false


## Tek banknotu PL karşılığı `max_value`yu aşmayan kupürler (en az en küçük kupür).
func _affordable_denoms(code: String, max_value: int) -> Array[int]:
	var result: Array[int] = []
	var denoms := ctx.book.denominations(code)
	for denom in denoms:
		if ctx.rates.buy_payout(code, Money.units(denom), ctx.day, ctx.use_midday_rates()) <= max_value:
			result.append(denom)
	if result.is_empty():
		result.append(denoms[0])
	return result


func _has_expired_series() -> bool:
	for code in ctx.book.foreign_codes(ctx.day):
		if not ctx.book.expired_series(code, ctx.day).is_empty():
			return true
	return false


## O gün açık kurallardan en az biri tarafından yakalanan sahtecilik türleri.
func _detectable_fakes() -> Array[String]:
	var result: Array[String] = []
	for fake in Banknote.FAKE_TYPES:
		if not ctx.rules.rules_for_fake(fake, ctx.day).is_empty():
			result.append(fake)
	return result


func _truth(decision: String, reasons: Array) -> Dictionary:
	return {"decision": decision, "reasons": ctx.rules.sorted_unique(reasons)}


func _new_customer(intent: String, code: String) -> Customer:
	var customer := Customer.new()
	customer.id = _next_id
	_next_id += 1
	var names: Dictionary = params.get("names", {})
	customer.holder_name = "%s %s" % [Seed.pick(rng, names.get("first", ["Ali"])), Seed.pick(rng, names.get("last", ["Veli"]))]
	customer.face_id = _random_face()
	if not identity.is_empty():
		customer.holder_name = str(identity.get("holder_name", customer.holder_name))
		customer.face_id = int(identity.get("face_id", customer.face_id))
	customer.intent = intent
	customer.currency = code
	return customer


func _random_face() -> int:
	var pool := int(params.get("face_pool", 400))
	var face := rng.randi_range(0, pool - 1)
	while ctx.bulletin.is_wanted(face):
		face = rng.randi_range(0, pool - 1)
	return face


## Rastgele (bazen döviz alan) kusursuz müşteri; kağıtları henüz yok.
func _base() -> Customer:
	if ctx.rule_active("R_SELL_FOREIGN") and Seed.chance(rng, int(params.get("buy_foreign_percent", 30))):
		var buyer := _buy_customer()
		if buyer != null:
			return buyer
	return _sell_customer(0, _clean_cap(), 1, int(params.get("max_notes_clean", 4)))


func _clean_cap() -> int:
	return int(params.get("clean_value_cap_pl_minor", NO_MAX))


## Döviz satan müşteri; işlem değeri [min_value, max_value] (PL, kuruş) aralığında. Kurulamazsa null.
func _sell_customer(min_value: int, max_value: int, min_notes: int, max_notes: int, only_code := "") -> Customer:
	var codes: Array[String] = []
	if only_code.is_empty():
		codes.assign(ctx.book.foreign_codes(ctx.day))
	else:
		codes.append(only_code)
	var start := rng.randi_range(0, codes.size() - 1)
	for offset in codes.size():
		var code := codes[(start + offset) % codes.size()]
		if ctx.book.is_local(code):
			continue
		var list := _build_sell(code, min_value, max_value, min_notes, max_notes)
		if not list.is_empty():
			var customer := _new_customer(Customer.INTENT_SELL, code)
			customer.notes = list
			return customer
	return null


func _build_sell(code: String, min_value: int, max_value: int, min_notes: int, max_notes: int) -> Array[Banknote]:
	var denoms := ctx.book.denominations(code)
	var midday := ctx.use_midday_rates()
	for attempt in 40:
		var picked: Array[int] = []
		var nominal := 0
		var value := 0
		var target := rng.randi_range(min_notes, max_notes)
		while picked.size() < max_notes:
			var fits: Array[int] = []
			for denom in denoms:
				if ctx.rates.buy_payout(code, nominal + Money.units(denom), ctx.day, midday) <= max_value:
					fits.append(denom)
			if fits.is_empty():
				break
			var choice: int = fits.max() if (value < min_value and picked.size() >= target - 1) else int(Seed.pick(rng, fits))
			picked.append(choice)
			nominal += Money.units(choice)
			value = ctx.rates.buy_payout(code, nominal, ctx.day, midday)
			if picked.size() >= target and value >= min_value:
				break
		if picked.size() >= min_notes and value >= min_value and value <= max_value:
			var list: Array[Banknote] = []
			for denom in picked:
				list.append(_genuine(code, denom))
			return list
	return []


## Döviz alan müşteri: kasanın tam ödeyebileceği bir tutar ister ve tam bedelini PL banknotuyla getirir.
func _buy_customer() -> Customer:
	var codes := ctx.book.foreign_codes(ctx.day)
	if codes.is_empty():
		return null
	var code := str(Seed.pick(rng, codes))
	var denoms := ctx.book.denominations(code)
	for attempt in 20:
		var units := 0
		for i in rng.randi_range(1, 3):
			units += int(Seed.pick(rng, denoms))
		var requested := Money.units(units)
		if not ctx.till.can_pay(code, requested):
			continue
		var cost := ctx.rates.sell_cost(code, requested, ctx.day, ctx.use_midday_rates())
		var customer := _new_customer(Customer.INTENT_BUY, code)
		customer.requested_foreign_minor = requested
		customer.notes = _pl_notes_for(cost)
		return customer
	return null


## `amount` PL (kuruş, 5 PL'nin katı) tutarını tam olarak PL banknotlarına böler; büyük kupürleri tercih eder.
func _pl_notes_for(amount: int) -> Array[Banknote]:
	var list: Array[Banknote] = []
	var denoms := ctx.book.denominations(ctx.book.local_code)
	var remaining := amount
	while remaining > 0:
		var fits: Array[int] = []
		for denom in denoms:
			if Money.units(denom) <= remaining:
				fits.append(denom)
		var choice: int = fits.max() if Seed.chance(rng, 55) else int(Seed.pick(rng, fits))
		list.append(_genuine(ctx.book.local_code, choice))
		remaining -= Money.units(choice)
	return list


## Gerçek (ya da `fakes` ile sahte) banknot; bültendeki çalıntı aralıklara denk gelmez (seri zorlanmadıkça).
func _genuine(code: String, denom: int, options: Dictionary = {}, fakes: Array = []) -> Banknote:
	var note: Banknote = null
	for attempt in 50:
		note = notes.make(code, denom, ctx.day, fakes, options)
		if options.has("serial_number") or not ctx.bulletin.is_stolen(note, ctx.book):
			break
	return note


## İşlem değerine göre gerekli (ve bazen gereksiz) geçerli kâğıtları ekler.
func _finish(customer: Customer) -> void:
	var value := customer.transaction_value_pl(ctx.rates, ctx.day, ctx.use_midday_rates())
	var need_id := ctx.rule_active("R_ID_LIMIT") and value > ctx.rules.limit_minor("R_ID_LIMIT")
	var need_declaration := ctx.rule_active("R_SOURCE") and value > ctx.rules.limit_minor("R_SOURCE")
	var optional_id := ctx.rule_active("R_ID_LIMIT") and Seed.chance(rng, int(params.get("optional_id_percent", 25)))
	if need_id or need_declaration or optional_id:
		var card := Documents.IdCard.new()
		card.holder_name = customer.holder_name
		card.number = Documents.make_id_number(rng)
		card.face_id = customer.face_id
		card.signature = "sig-%d" % rng.randi_range(10000, 99999)
		card.expiry_day = ctx.day + rng.randi_range(1, 30)
		customer.id_card = card
	if need_declaration:
		var declaration := Documents.SourceDeclaration.new()
		declaration.holder_name = customer.holder_name
		declaration.amount_minor = value
		declaration.signature = customer.id_card.signature
		customer.declaration = declaration


func _broken_number(number: String) -> String:
	return number.substr(0, 10) + str((number[10].to_int() + rng.randi_range(1, 9)) % 10)
