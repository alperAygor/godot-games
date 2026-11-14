class_name Slip
extends RefCounted
## Uyarı fişinin satırları (Papers, Please'teki "ihlal fişi"). Metni arayüz çevirir:
## her satır {"key": çeviri anahtarı, "args": [...]}; arg "@ANAHTAR" ise o da çevrilir,
## {"money": [kuruş, para_birimi]} ise para olarak biçimlenir, diğerleri olduğu gibi kullanılır.


static func lines(mistakes: Array[Dictionary], verdict: Verdict) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mistake in mistakes:
		match mistake["type"]:
			Verdict.MISTAKE_DECISION:
				result.append({"key": "SLIP_WRONG_DECISION", "args": ["@DECISION_%s" % str(mistake["expected"]).to_upper()]})
			Verdict.MISTAKE_NOTE:
				result.append({"key": "SLIP_WRONG_NOTE", "args": [int(mistake["note"]) + 1, "@FATE_%s" % str(mistake["expected"]).to_upper()]})
			Verdict.MISTAKE_REASON:
				result.append({"key": "SLIP_WRONG_REASON", "args": []})
			Verdict.MISTAKE_OVERPAID:
				result.append({"key": "SLIP_OVERPAID", "args": [{"money": [absi(int(mistake["delta"])), mistake["code"]]}]})
			Verdict.MISTAKE_UNDERPAID:
				result.append({"key": "SLIP_UNDERPAID", "args": [{"money": [absi(int(mistake["delta"])), mistake["code"]]}]})
			Shift.MISTAKE_TILL_SHORT:
				result.append({"key": "SLIP_TILL_SHORT", "args": []})
	if not mistakes.is_empty():
		var seen := {}
		for detail in verdict.details:
			if not seen.has(detail["rule"]) and seen.size() < 3:
				seen[detail["rule"]] = true
				result.append({"key": "SLIP_RULE", "args": ["@RULE_%s" % detail["rule"]]})
	return result
