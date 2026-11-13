class_name DailyDate
extends RefCounted

## Saf takvim yardımcıları. Neden kendi hesabımız: "bugün" dışarıdan enjekte edilir (testler
## saate bağlı kalmasın) ve gün farkı Time sınıfının saat dilimi tuzaklarından bağımsız olmalı.
## Tarih anahtarı "YYYY-MM-DD" metnidir; kayıtta okunaklı ve karşılaştırması kolay.

const KEY_FORMAT: String = "%04d-%02d-%02d"
const DAYS_PER_ERA: int = 146097
const DAYS_PER_YEAR_APPROX: int = 365
const ERA_YEARS: int = 400
## Hesap dönemini 1 Mart'a çeviren sabit (Mart başlangıçlı yıl: artık gün yılın sonunda olur).
const MARCH_SHIFT: int = 3
const EPOCH_OFFSET: int = 719468
const NO_DATE: int = -1


## Yerel saate göre bugünün anahtarı (UTC değil: oyuncu için "gün" duvar saatidir).
static func today_key() -> String:
	var now: Dictionary = Time.get_date_dict_from_system(false)
	return KEY_FORMAT % [int(now["year"]), int(now["month"]), int(now["day"])]


static func is_valid(key: String) -> bool:
	var parts: PackedStringArray = key.split("-")
	if parts.size() != 3 or not (parts[0].is_valid_int() and parts[1].is_valid_int() and parts[2].is_valid_int()):
		return false
	var month: int = parts[1].to_int()
	var day: int = parts[2].to_int()
	return month >= 1 and month <= 12 and day >= 1 and day <= 31


## 1970-01-01'den beri gün sayısı; geçersiz anahtar için NO_DATE.
static func day_index(key: String) -> int:
	if not is_valid(key):
		return NO_DATE
	var parts: PackedStringArray = key.split("-")
	var year: int = parts[0].to_int()
	var month: int = parts[1].to_int()
	var day: int = parts[2].to_int()
	if month <= MARCH_SHIFT - 1:
		year -= 1
	var era: int = floori(float(year) / float(ERA_YEARS))
	var year_of_era: int = year - era * ERA_YEARS
	var shifted: int = month + 9 if month <= MARCH_SHIFT - 1 else month - MARCH_SHIFT
	var day_of_year: int = (153 * shifted + 2) / 5 + day - 1
	var day_of_era: int = year_of_era * DAYS_PER_YEAR_APPROX + year_of_era / 4 \
		- year_of_era / 100 + day_of_year
	return era * DAYS_PER_ERA + day_of_era - EPOCH_OFFSET


static func key_from_index(index: int) -> String:
	var shifted_days: int = index + EPOCH_OFFSET
	var era: int = floori(float(shifted_days) / float(DAYS_PER_ERA))
	var day_of_era: int = shifted_days - era * DAYS_PER_ERA
	var year_of_era: int = (day_of_era - day_of_era / 1460 + day_of_era / 36524 \
		- day_of_era / 146096) / DAYS_PER_YEAR_APPROX
	var year: int = year_of_era + era * ERA_YEARS
	var day_of_year: int = day_of_era - (DAYS_PER_YEAR_APPROX * year_of_era \
		+ year_of_era / 4 - year_of_era / 100)
	var mp: int = (5 * day_of_year + 2) / 153
	var day: int = day_of_year - (153 * mp + 2) / 5 + 1
	var month: int = mp + MARCH_SHIFT if mp < 10 else mp - 9
	if month <= MARCH_SHIFT - 1:
		year += 1
	return KEY_FORMAT % [year, month, day]


## `later` ile `earlier` arası gün farkı (aynı gün 0, ertesi gün 1). Geçersizse NO_DATE.
static func days_between(earlier: String, later: String) -> int:
	var a: int = day_index(earlier)
	var b: int = day_index(later)
	if a == NO_DATE or b == NO_DATE:
		return NO_DATE
	return b - a


static func add_days(key: String, count: int) -> String:
	return key_from_index(day_index(key) + count)
