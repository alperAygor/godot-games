class_name Money
extends RefCounted
## Para hesabı: tüm tutarlar tam sayı "kuruş"tur (1 birim = 100). Kurlar RATE_SCALE ile çarpılmış tam sayıdır.
## Asla float kullanılmaz: "doğru ödeme" tek ve kesin bir sayı olmak zorunda.

const UNIT := 100
const RATE_SCALE := 10000


## Tam birimleri kuruşa çevirir: Money.units(5) == 500.
static func units(whole: int) -> int:
	return whole * UNIT


## a * b / c, aşağı yuvarlanır (negatif olmayan sayılar için).
static func mul_div_floor(a: int, b: int, c: int) -> int:
	assert(c > 0 and a >= 0 and b >= 0)
	return (a * b) / c


## a * b / c, yukarı yuvarlanır (negatif olmayan sayılar için).
static func mul_div_ceil(a: int, b: int, c: int) -> int:
	assert(c > 0 and a >= 0 and b >= 0)
	return (a * b + c - 1) / c


## `step`in katına aşağı yuvarlar: floor_to(1234, 500) == 1000.
static func floor_to(amount: int, step: int) -> int:
	if step <= 1:
		return amount
	return amount - amount % step


## `step`in katına yukarı yuvarlar: ceil_to(1001, 500) == 1500.
static func ceil_to(amount: int, step: int) -> int:
	if step <= 1:
		return amount
	var rest := amount % step
	return amount if rest == 0 else amount + step - rest


## Ekranda gösterim: format(125050, "PL") == "1,250.50 PL"; tam sayıysa kuruş yazılmaz.
## locale "tr" ise nokta ve virgül yer değiştirir: "1.250,50 PL".
static func format(amount: int, code := "", locale := "en") -> String:
	var group_sep := "." if locale == "tr" else ","
	var decimal_sep := "," if locale == "tr" else "."
	var negative := amount < 0
	var absolute := absi(amount)
	var whole := str(absolute / UNIT)
	var grouped := ""
	for i in whole.length():
		if i > 0 and (whole.length() - i) % 3 == 0:
			grouped += group_sep
		grouped += whole[i]
	var text := grouped
	if absolute % UNIT != 0:
		text += "%s%02d" % [decimal_sep, absolute % UNIT]
	if negative:
		text = "-" + text
	return text if code.is_empty() else "%s %s" % [text, code]
