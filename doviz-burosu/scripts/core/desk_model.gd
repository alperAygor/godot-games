class_name DeskModel
extends RefCounted
## Masadaki tek müşterinin çalışma durumu: banknot kararları (varsayılan kabul = tezgâhta bırak), yazılan ödeme tutarları.
## Arayüz yalnızca bunu okur/yazar; oyuncunun hamlesini (PlayerMove) burası kurar.
##
## Karar -> banknot kaderi sadeleştirmesi (arayüzde ayrıca uğraşmaya gerek kalmasın):
## - Reddet: hepsi iade.  - Polis: kabul edilmiş görünenler iade edilir, el konulanlar kalır.  - Tamamla: olduğu gibi.

var customer: Customer
var fates: Array[String] = []
## Para birimi -> kuruş.
var paid: Dictionary = {}


func _init(for_customer: Customer) -> void:
	customer = for_customer
	for i in customer.notes.size():
		fates.append(Verdict.FATE_ACCEPT)


func set_fate(index: int, fate: String) -> void:
	if index >= 0 and index < fates.size():
		fates[index] = fate


func fate(index: int) -> String:
	return fates[index]


func set_paid(code: String, minor: int) -> void:
	paid[code] = maxi(0, minor)


func paid_minor(code: String) -> int:
	return int(paid.get(code, 0))


## Ödeme satırları: her zaman yerel para; döviz alan müşteri için ayrıca dövizin kendisi.
func payment_codes(local_code: String) -> Array[String]:
	var codes: Array[String] = [local_code]
	if customer.intent == Customer.INTENT_BUY:
		codes.append(customer.currency)
	return codes


func build_move(decision: String, reason := "") -> PlayerMove:
	var move := PlayerMove.new()
	move.decision = decision
	move.reason = reason
	for current in fates:
		match decision:
			Verdict.DECISION_REJECT:
				move.fates.append(Verdict.FATE_RETURN)
			Verdict.DECISION_POLICE:
				move.fates.append(Verdict.FATE_RETURN if current == Verdict.FATE_ACCEPT else current)
			_:
				move.fates.append(current)
	if decision == Verdict.DECISION_COMPLETE:
		for code: String in paid:
			if int(paid[code]) > 0:
				move.paid[code] = int(paid[code])
	return move
