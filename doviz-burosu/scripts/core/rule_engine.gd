class_name RuleEngine
extends RefCounted
## Bir müşteri için kesin doğru cevabı üretir (Verdict). Sadece o gün AÇIK kurallar uygulanır.
##
## Öncelik: el koyma > iade > kabul (banknot bazında); polis > reddet > tamamla (işlem bazında).
## - Polis: sahte para, çalıntı seri, aranan yüz, sahte kimlik, kaynak beyanı uyuşmazlığı. Ödeme yok;
##   sahte/çalıntı banknotlara el konur, kalanlar iade edilir.
## - Reddet: kimlik eksik/süresi geçmiş/başkasının, kaynak beyanı yok, kasada yok, kabul edilebilir banknot yok. Her şey iade.
## - Tamamla: kabul edilen banknotlar üzerinden ödeme; iade kaderli banknotlar müşteriye geri verilir.

var ctx: DayContext


func _init(context: DayContext) -> void:
	ctx = context


func evaluate(customer: Customer) -> Verdict:
	var verdict := Verdict.new()
	var police: Array[String] = []
	var reject: Array[String] = []
	var returned_rules: Array[String] = []
	var fates: Array[String] = []

	for i in customer.notes.size():
		var note := customer.notes[i]
		var confiscate_rules: Array[String] = []
		var return_rules: Array[String] = []
		for fake in note.discrepancies(ctx.book):
			for rule_id in ctx.rules.rules_for_fake(fake, ctx.day):
				confiscate_rules.append(rule_id)
				_detail(verdict, rule_id, fake, i)
		if ctx.rule_active("R_STOLEN") and ctx.bulletin.is_stolen(note, ctx.book):
			confiscate_rules.append("R_STOLEN")
			_detail(verdict, "R_STOLEN", "stolen_serial", i)
		if ctx.rule_active("R_SERIES") and not ctx.book.series_valid_on(note.currency, note.series_id, ctx.day):
			return_rules.append("R_SERIES")
			_detail(verdict, "R_SERIES", "old_series", i)
		if ctx.rule_active("R_TORN") and note.is_unfit(ctx.min_remaining_percent()):
			return_rules.append("R_TORN")
			_detail(verdict, "R_TORN", "torn", i)
		if not confiscate_rules.is_empty():
			fates.append(Verdict.FATE_CONFISCATE)
			police.append_array(confiscate_rules)
		elif not return_rules.is_empty():
			fates.append(Verdict.FATE_RETURN)
			returned_rules.append_array(return_rules)
		else:
			fates.append(Verdict.FATE_ACCEPT)

	var value := customer.transaction_value_pl(ctx.rates, ctx.day, ctx.use_midday_rates())
	_check_wanted(verdict, customer, police)
	_check_id(verdict, customer, value, police, reject)
	_check_declaration(verdict, customer, value, police, reject)

	verdict.fates = fates
	if not police.is_empty():
		return _finish_police(verdict, customer, police)

	var accepted: Array[Banknote] = []
	for i in customer.notes.size():
		if fates[i] == Verdict.FATE_ACCEPT:
			accepted.append(customer.notes[i])
	var pay_out := _payout(customer, accepted, reject, returned_rules, verdict)
	if reject.is_empty() and ctx.rule_active("R_SELL_FOREIGN") and not _till_can_pay(accepted, pay_out):
		reject.append("R_SELL_FOREIGN")
		_detail(verdict, "R_SELL_FOREIGN", "no_stock", -1)
	if not reject.is_empty():
		return _finish_reject(verdict, customer, reject)

	verdict.decision = Verdict.DECISION_COMPLETE
	verdict.pay_out = pay_out
	return verdict


func _check_wanted(verdict: Verdict, customer: Customer, police: Array[String]) -> void:
	if ctx.rule_active("R_WANTED") and ctx.bulletin.is_wanted(customer.face_id):
		police.append("R_WANTED")
		_detail(verdict, "R_WANTED", "wanted_face", -1)


func _check_id(verdict: Verdict, customer: Customer, value: int, police: Array[String], reject: Array[String]) -> void:
	if not ctx.rule_active("R_ID_LIMIT") or value <= ctx.rules.limit_minor("R_ID_LIMIT"):
		return
	if customer.id_card == null:
		reject.append("R_ID_LIMIT")
		_detail(verdict, "R_ID_LIMIT", "id_missing", -1)
		return
	var problems := customer.id_card.problems(ctx.day, customer.face_id)
	if Documents.PROBLEM_FORGED in problems:
		police.append("R_ID_LIMIT")
		_detail(verdict, "R_ID_LIMIT", Documents.PROBLEM_FORGED, -1)
	elif Documents.PROBLEM_EXPIRED in problems or Documents.PROBLEM_OTHER_PERSON in problems:
		reject.append("R_ID_LIMIT")
		_detail(verdict, "R_ID_LIMIT", Documents.PROBLEM_EXPIRED if Documents.PROBLEM_EXPIRED in problems else Documents.PROBLEM_OTHER_PERSON, -1)


func _check_declaration(verdict: Verdict, customer: Customer, value: int, police: Array[String], reject: Array[String]) -> void:
	if not ctx.rule_active("R_SOURCE") or value <= ctx.rules.limit_minor("R_SOURCE"):
		return
	var declaration := customer.declaration
	if declaration == null:
		reject.append("R_SOURCE")
		_detail(verdict, "R_SOURCE", "declaration_missing", -1)
		return
	var signature_ok := customer.id_card == null or declaration.signature == customer.id_card.signature
	if declaration.amount_minor != value or not signature_ok or declaration.holder_name != customer.holder_name:
		police.append("R_SOURCE")
		_detail(verdict, "R_SOURCE", "declaration_mismatch", -1)


## Kabul edilen banknotlara göre ödeme tutarlarını hesaplar. Ödeme yapılamıyorsa (kabul edilebilir banknot yok /
## alıcı müşteri için tutar yetmiyor) `reject`e iade nedenlerini ekler.
func _payout(customer: Customer, accepted: Array[Banknote], reject: Array[String], returned_rules: Array[String], verdict: Verdict) -> Dictionary:
	var pay_out := {}
	var midday := ctx.use_midday_rates()
	if customer.intent == Customer.INTENT_SELL:
		var nominal := {}
		for note in accepted:
			nominal[note.currency] = int(nominal.get(note.currency, 0)) + note.value_minor()
		if nominal.is_empty():
			_reject_for_unusable_notes(reject, returned_rules)
			return pay_out
		var local := ctx.book.local_code
		pay_out[local] = 0
		for code: String in nominal:
			pay_out[local] = int(pay_out[local]) + ctx.rates.buy_payout(code, int(nominal[code]), ctx.day, midday)
		return pay_out
	var paid_pl := 0
	for note in accepted:
		if note.currency == ctx.book.local_code:
			paid_pl += note.value_minor()
	var cost := ctx.rates.sell_cost(customer.currency, customer.requested_foreign_minor, ctx.day, midday)
	if paid_pl < cost:
		_reject_for_unusable_notes(reject, returned_rules)
		return pay_out
	pay_out[customer.currency] = customer.requested_foreign_minor
	if paid_pl > cost:
		pay_out[ctx.book.local_code] = paid_pl - cost
	return pay_out


func _reject_for_unusable_notes(reject: Array[String], returned_rules: Array[String]) -> void:
	if returned_rules.is_empty():
		reject.append("R_EXCHANGE")
	else:
		reject.append_array(returned_rules)


## Kabul edilen banknotlar kasaya girdikten sonra tüm ödemeler tam tutarla yapılabiliyor mu?
func _till_can_pay(accepted: Array[Banknote], pay_out: Dictionary) -> bool:
	var simulated := ctx.till.duplicate_till()
	simulated.deposit_all(accepted)
	for code: String in pay_out:
		var plan := simulated.pay_plan(code, int(pay_out[code]))
		if not plan["ok"] or not simulated.take(code, plan["notes"]):
			return false
	return true


func _finish_police(verdict: Verdict, customer: Customer, police: Array[String]) -> Verdict:
	verdict.decision = Verdict.DECISION_POLICE
	verdict.reasons = ctx.rules.sorted_unique(police)
	for i in customer.notes.size():
		if verdict.fates[i] != Verdict.FATE_CONFISCATE:
			verdict.fates[i] = Verdict.FATE_RETURN
	return verdict


func _finish_reject(verdict: Verdict, customer: Customer, reject: Array[String]) -> Verdict:
	verdict.decision = Verdict.DECISION_REJECT
	verdict.reasons = ctx.rules.sorted_unique(reject)
	verdict.fates.clear()
	for i in customer.notes.size():
		verdict.fates.append(Verdict.FATE_RETURN)
	return verdict


func _detail(verdict: Verdict, rule_id: String, kind: String, note_index: int) -> void:
	verdict.details.append({"rule": rule_id, "kind": kind, "note": note_index})
