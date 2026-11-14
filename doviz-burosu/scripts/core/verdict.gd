class_name Verdict
extends RefCounted
## RuleEngine'in bir müşteri için ürettiği kesin doğru cevap ve oyuncunun hamlesiyle karşılaştırma.

const DECISION_COMPLETE := "complete"
const DECISION_REJECT := "reject"
const DECISION_POLICE := "police"

const FATE_ACCEPT := "accept"
const FATE_RETURN := "return"
const FATE_CONFISCATE := "confiscate"

const MISTAKE_DECISION := "wrong_decision"
const MISTAKE_REASON := "wrong_reason"
const MISTAKE_NOTE := "wrong_note_fate"
const MISTAKE_OVERPAID := "overpaid"
const MISTAKE_UNDERPAID := "underpaid"

var decision := ""
## customer.notes ile aynı sırada banknot kaderleri.
var fates: Array[String] = []
## Kararı doğuran kural kimlikleri (dosya sırasıyla). Tamamla'da boş.
var reasons: Array[String] = []
## Büronun müşteriye ödeyeceği tutarlar: para birimi -> kuruş. Yalnızca Tamamla'da dolu.
var pay_out: Dictionary = {}
## Açıklama kayıtları (uyarı fişi için): {"rule", "kind", "note" (indeks, -1 = işlem geneli)}.
var details: Array[Dictionary] = []


func accepted_notes(customer: Customer) -> Array[Banknote]:
	var result: Array[Banknote] = []
	for i in customer.notes.size():
		if fates[i] == FATE_ACCEPT:
			result.append(customer.notes[i])
	return result


## Oyuncunun hamlesindeki hataları döndürür (boş = hatasız).
## - Karar yanlışsa tek hata döner (kalanı anlamsızdır).
## - Karar doğruysa: banknot kaderleri, neden (yalnızca Reddet'te zorunlu) ve ödeme tutarları karşılaştırılır.
static func compare(expected: Verdict, move: PlayerMove) -> Array[Dictionary]:
	var mistakes: Array[Dictionary] = []
	if move.decision != expected.decision:
		mistakes.append({"type": MISTAKE_DECISION, "expected": expected.decision, "got": move.decision})
		return mistakes
	for i in expected.fates.size():
		var got := move.fates[i] if i < move.fates.size() else ""
		if got != expected.fates[i]:
			mistakes.append({"type": MISTAKE_NOTE, "note": i, "expected": expected.fates[i], "got": got})
	if expected.decision == DECISION_REJECT and not (move.reason in expected.reasons):
		mistakes.append({"type": MISTAKE_REASON, "expected": expected.reasons, "got": move.reason})
	elif expected.decision == DECISION_POLICE and not move.reason.is_empty() and not (move.reason in expected.reasons):
		mistakes.append({"type": MISTAKE_REASON, "expected": expected.reasons, "got": move.reason})
	if expected.decision == DECISION_COMPLETE:
		var codes := {}
		for code: Variant in expected.pay_out.keys():
			codes[code] = true
		for code: Variant in move.paid.keys():
			codes[code] = true
		for code: String in codes:
			var delta := int(move.paid.get(code, 0)) - int(expected.pay_out.get(code, 0))
			if delta != 0:
				mistakes.append({"type": MISTAKE_OVERPAID if delta > 0 else MISTAKE_UNDERPAID, "code": code, "delta": delta})
	return mistakes
