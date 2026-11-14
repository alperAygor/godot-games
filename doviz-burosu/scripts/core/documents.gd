class_name Documents
extends RefCounted
## Müşterinin getirdiği belgeler: kimlik ve kaynak beyanı.
## Kimlik numarası 11 haneli: ilk 10 hane rastgele, 11. hane = ilk 10 hanenin toplamı mod 10.
## Sahte kimliğin kontrol hanesi tutmaz; bu ayrıca bir etiket değil, belgeden okunan gerçek farktır.

const PROBLEM_EXPIRED := "id_expired"
const PROBLEM_FORGED := "id_forged"
const PROBLEM_OTHER_PERSON := "id_other_person"


static func check_digit(first_ten: String) -> int:
	var total := 0
	for i in first_ten.length():
		total += first_ten[i].to_int()
	return total % 10


static func make_id_number(generator: RandomNumberGenerator) -> String:
	var digits := str(generator.randi_range(1, 9))
	for i in 9:
		digits += str(generator.randi_range(0, 9))
	return digits + str(check_digit(digits))


static func id_number_ok(number: String) -> bool:
	return number.length() == 11 and number.is_valid_int() and check_digit(number.substr(0, 10)) == number[10].to_int()


class IdCard extends RefCounted:
	var holder_name := ""
	var number := ""
	var face_id := 0
	var signature := ""
	## Son geçerli gün (dahil): expiry_day >= bugün ise geçerli.
	var expiry_day := 0

	## Belgeden okunabilen sorunlar (Documents.PROBLEM_*). `customer_face_id`: önündeki müşterinin yüzü.
	func problems(day: int, customer_face_id: int) -> Array[String]:
		var found: Array[String] = []
		if expiry_day < day:
			found.append(Documents.PROBLEM_EXPIRED)
		if not Documents.id_number_ok(number):
			found.append(Documents.PROBLEM_FORGED)
		if face_id != customer_face_id:
			found.append(Documents.PROBLEM_OTHER_PERSON)
		return found


class SourceDeclaration extends RefCounted:
	var holder_name := ""
	## Beyan edilen tutar (PL, kuruş).
	var amount_minor := 0
	var signature := ""
