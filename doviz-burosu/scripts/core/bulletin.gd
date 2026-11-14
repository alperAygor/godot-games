class_name Bulletin
extends RefCounted
## Günün bülteni: çalıntı seri aralıkları ve aranan yüzler.

## Her kayıt: {"currency", "series_id", "from", "to"} (seri numarası aralığı, uçlar dahil).
var stolen_ranges: Array[Dictionary] = []
## Aranan kişilerin yüz kimlikleri (Customer.face_id).
var wanted_faces: Array[int] = []


func add_stolen(currency: String, series_id: String, from_number: int, to_number: int) -> void:
	stolen_ranges.append({"currency": currency, "series_id": series_id, "from": from_number, "to": to_number})


func is_stolen_number(currency: String, series_id: String, number: int) -> bool:
	for range_def in stolen_ranges:
		if range_def["currency"] == currency and range_def["series_id"] == series_id \
				and number >= int(range_def["from"]) and number <= int(range_def["to"]):
			return true
	return false


func is_stolen(note: Banknote, book: CurrencyBook) -> bool:
	var prefix := book.series_prefix(note.currency, note.series_id)
	if prefix.is_empty() or not note.serial.begins_with(prefix):
		return false
	return is_stolen_number(note.currency, note.series_id, note.serial.substr(prefix.length()).to_int())


func is_wanted(face_id: int) -> bool:
	return face_id in wanted_faces
