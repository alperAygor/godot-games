class_name Customer
extends RefCounted
## Gişeye gelen bir müşteri: ne istiyor, ne getiriyor, hangi belgeleri gösteriyor.
## `scenario` ve `truth` üreticinin bilinçli olarak kurduğu "doğru cevap"tır (kendi kendini doğrulama testi
## bunu RuleEngine'in kararıyla karşılaştırır). Oyun mantığı bunlara bakmaz; yalnızca RuleEngine karar verir.

const INTENT_SELL := "sell_foreign"  ## Müşteri döviz SATAR (bizim ALIŞ kurumuz), PL alır.
const INTENT_BUY := "buy_foreign"    ## Müşteri PL verip döviz ALIR (bizim SATIŞ kurumuz).

var id := 0
var holder_name := ""
var face_id := 0
var intent := INTENT_SELL
## İşlemin yabancı para birimi.
var currency := ""
## INTENT_BUY: istenen döviz tutarı (kuruş).
var requested_foreign_minor := 0
var notes: Array[Banknote] = []
var id_card: Documents.IdCard = null
var declaration: Documents.SourceDeclaration = null

var scenario := ""
## Hikaye müşterisi: karakter kimliği ve onu getiren olay kimliği (rastgele müşteride boş).
var character := ""
var beat_id := ""
## {"decision": Verdict.DECISION_*, "reasons": Array[String] (kural kimlikleri)}
var truth: Dictionary = {}


## `code` para biriminden masadaki banknotların toplam değeri (kuruş).
func nominal_minor(code: String) -> int:
	var total := 0
	for note in notes:
		if note.currency == code:
			total += note.value_minor()
	return total


## İşlem değeri (PL, kuruş): eşik kurallarının (kimlik, kaynak beyanı) baktığı tutar.
func transaction_value_pl(rates: RateTable, day: int, midday: bool) -> int:
	if intent == INTENT_BUY:
		return rates.sell_cost(currency, requested_foreign_minor, day, midday)
	var total := 0
	var seen := {}
	for note in notes:
		if note.currency != rates.book.local_code and not seen.has(note.currency):
			seen[note.currency] = true
			total += rates.buy_payout(note.currency, nominal_minor(note.currency), day, midday)
	return total
