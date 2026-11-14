extends TestCase

## Priz kuralı: ekranda rakam yok. Çeviri tablosundaki hiçbir değer rakam içermez (üç dilde).
## Çalışma anındaki ekran denetimi `tools/digit_probe.gd`dedir (verify.sh çalıştırır).

const CSV_PATH: String = "res://data/i18n/strings.csv"


func _has_digit(text: String) -> bool:
	for index: int in range(text.length()):
		var code: int = text.unicode_at(index)
		# ASCII rakamlar ve Arapça-Hint / tam genişlik rakam blokları.
		if (code >= 0x30 and code <= 0x39) or (code >= 0x660 and code <= 0x669) or (code >= 0xFF10 and code <= 0xFF19):
			return true
	return false


func test_no_translation_value_contains_a_digit() -> void:
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	assert_true(file != null, "strings.csv açılmalı")
	if file == null:
		return
	var header: PackedStringArray = file.get_csv_line()
	var checked: int = 0
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		if row.size() < 2 or row[0].is_empty():
			continue
		for column: int in range(1, row.size()):
			checked += 1
			assert_false(_has_digit(row[column]), "rakam var: %s [%s]" % [row[0], header[column] if column < header.size() else "?"])
	assert_true(checked > 30, "tablo okunmalı")


func test_no_format_placeholders_that_would_print_numbers() -> void:
	var file: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	file.get_csv_line()
	while not file.eof_reached():
		var row: PackedStringArray = file.get_csv_line()
		for column: int in range(1, row.size()):
			assert_false(row[column].contains("%d") or row[column].contains("%s") or row[column].contains("%f"),
				"%s: sayı yer tutucusu yok" % row[0])


func test_digit_detector_works() -> void:
	assert_true(_has_digit("a1"))
	assert_true(_has_digit("x２"))
	assert_false(_has_digit("Seviye"))
