class_name PlayerMove
extends RefCounted
## Oyuncunun bir müşteri için yaptığı hamle (arayüz bunu doldurur; Verdict.compare beklenenle karşılaştırır).

var decision := ""
## customer.notes ile aynı sırada Verdict.FATE_* değerleri.
var fates: Array[String] = []
## Reddet / polis için seçilen neden (kural kimliği), seçilmediyse boş.
var reason := ""
## Oyuncunun müşteriye ödediği tutarlar: para birimi -> kuruş (yalnızca Tamamla'da anlamlı).
var paid: Dictionary = {}
