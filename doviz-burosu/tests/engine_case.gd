extends "res://tests/test_case.gd"
## RuleEngine testleri için ortak yardımcılar (test_rules_*.gd bunu extend eder; kendi başına test içermez).

var book: CurrencyBook
var factory: NoteFactory
var rng: RandomNumberGenerator


func before_each() -> void:
	book = CurrencyBook.load_default()
	rng = Seed.rng("engine-case")
	factory = NoteFactory.new(book, rng)


func make_ctx(day: int, options: Dictionary = {}) -> DayContext:
	return DayContext.for_day(day, options)


## Yalnızca verilen kuralları açık, sınırları verilen değerlerde olan özel kural kümesi.
func custom_rules(rule_defs: Array) -> RuleSet:
	return RuleSet.new({"rules": rule_defs})


func new_customer(intent := Customer.INTENT_SELL, code := "FED", face := 1) -> Customer:
	var customer := Customer.new()
	customer.holder_name = "Test Müşteri"
	customer.face_id = face
	customer.intent = intent
	customer.currency = code
	return customer


## `code` cinsinden verilen kupürlerle döviz SATAN müşteri (banknotlar o günün geçerli serisinden, gerçek).
func seller(code: String, denoms: Array, day: int, face := 1) -> Customer:
	var customer := new_customer(Customer.INTENT_SELL, code, face)
	for denom: int in denoms:
		customer.notes.append(factory.make_genuine(code, denom, day))
	return customer


## `foreign_units` döviz ALAN müşteri; ödemeyi tam tutarda PL banknotuyla (büyük kupürden) getirir. extra_pl: fazla verilen PL.
func buyer(code: String, foreign_units: int, ctx: DayContext, extra_pl := 0, face := 1) -> Customer:
	var customer := new_customer(Customer.INTENT_BUY, code, face)
	customer.requested_foreign_minor = Money.units(foreign_units)
	var cost := ctx.rates.sell_cost(code, customer.requested_foreign_minor, ctx.day, ctx.use_midday_rates())
	var remaining := cost + Money.units(extra_pl)
	var denoms := book.denominations("PL")
	denoms.reverse()
	for denom in denoms:
		while remaining >= Money.units(denom):
			customer.notes.append(factory.make_genuine("PL", denom, ctx.day))
			remaining -= Money.units(denom)
	assert_eq(remaining, 0, "PL banknotlarıyla tam tutar kurulabilmeli")
	return customer


func give_id(customer: Customer, ctx: DayContext, expiry_offset := 10) -> Documents.IdCard:
	var card := Documents.IdCard.new()
	card.holder_name = customer.holder_name
	card.number = Documents.make_id_number(rng)
	card.face_id = customer.face_id
	card.signature = "sig-%d" % rng.randi_range(1000, 9999)
	card.expiry_day = ctx.day + expiry_offset
	customer.id_card = card
	return card


func give_declaration(customer: Customer, ctx: DayContext) -> Documents.SourceDeclaration:
	var declaration := Documents.SourceDeclaration.new()
	declaration.holder_name = customer.holder_name
	declaration.amount_minor = customer.transaction_value_pl(ctx.rates, ctx.day, ctx.use_midday_rates())
	declaration.signature = customer.id_card.signature if customer.id_card != null else "sig-0"
	customer.declaration = declaration
	return declaration


func evaluate(customer: Customer, ctx: DayContext) -> Verdict:
	return RuleEngine.new(ctx).evaluate(customer)


func fake_note(code: String, denom: int, day: int, fakes: Array, options: Dictionary = {}) -> Banknote:
	return factory.make(code, denom, day, fakes, options)
