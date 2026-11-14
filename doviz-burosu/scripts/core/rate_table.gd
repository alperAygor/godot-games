class_name RateTable
extends RefCounted
## Günlük kurlar. Kur = 1 yabancı birimin PL karşılığı x Money.RATE_SCALE (tam sayı).
## - Sabah orta kuru enflasyonla her gün yükselir: önceki gün x (1 + sabit artış + küçük gürültü).
##   Gürültü tohumludur (salt + para birimi + gün), bu yüzden aynı salt aynı kurları verir; gün sırası önemsizdir.
## - Gün ortası (13:00) güncellemesi sabah orta kurdan ayrı, bir kez daha oynar (R_MIDDAY_RATE kuralı).
## - ALIŞ (müşteri bize döviz satar, biz PL öderiz) ortanın altında, SATIŞ (müşteri döviz alır) üstündedir.
## 1. günün orta kuru data/currencies.json'daki `rate`tir (para biriminin açıldığı günden bağımsız).

const DEFAULTS := {
	"payout_round_to": 500,
	"daily_drift_bp": 120,
	"drift_noise_bp": 80,
	"midday_jump_bp": 150,
}
const BP := 10000

var book: CurrencyBook
var salt: String
var payout_round_to: int
var daily_drift_bp: int
var drift_noise_bp: int
var midday_jump_bp: int

var _mids := {}  # code -> Array[int], dizin = gün (0. dizin kullanılmaz)


## `balance`: data/balance.json'un tamamı (eksik alanlar DEFAULTS'tan gelir). `rate_salt`: hikaye için sabit,
## Günün Kuru için tarih gibi bir metin.
func _init(currency_book: CurrencyBook, balance: Dictionary = {}, rate_salt := "story") -> void:
	book = currency_book
	salt = rate_salt
	payout_round_to = int(JsonIO.get_path_value(balance, "money.payout_round_to", DEFAULTS["payout_round_to"]))
	daily_drift_bp = int(JsonIO.get_path_value(balance, "rates.daily_drift_bp", DEFAULTS["daily_drift_bp"]))
	drift_noise_bp = int(JsonIO.get_path_value(balance, "rates.drift_noise_bp", DEFAULTS["drift_noise_bp"]))
	midday_jump_bp = int(JsonIO.get_path_value(balance, "rates.midday_jump_bp", DEFAULTS["midday_jump_bp"]))


## Sabah orta kuru.
func mid_rate(code: String, day: int) -> int:
	var days := maxi(day, 1)
	if not _mids.has(code):
		_mids[code] = [0, book.base_rate(code)]
	var mids: Array = _mids[code]
	while mids.size() <= days:
		var k: int = mids.size()
		var drift := daily_drift_bp
		if not book.is_local(code):
			drift += Seed.rng("rate|%s|%s|%d" % [salt, code, k]).randi_range(-drift_noise_bp, drift_noise_bp)
		else:
			drift = 0
		mids.append(Money.mul_div_floor(int(mids[k - 1]), BP + drift, BP))
	return int(mids[days])


## 13:00 güncellemesinden sonraki orta kur: sabah kurundan en az yarım, en çok tam `midday_jump_bp` kadar sapar.
func midday_mid_rate(code: String, day: int) -> int:
	var morning := mid_rate(code, day)
	if book.is_local(code):
		return morning
	var generator := Seed.rng("midday|%s|%s|%d" % [salt, code, maxi(day, 1)])
	var jump := generator.randi_range(midday_jump_bp / 2, midday_jump_bp)
	if Seed.chance(generator, 50):
		jump = -jump
	return Money.mul_div_floor(morning, BP + jump, BP)


## {"mid", "buy", "sell"} (hepsi x RATE_SCALE). midday = true: 13:00 sonrası kurlar.
func rates(code: String, day: int, midday := false) -> Dictionary:
	var mid := midday_mid_rate(code, day) if midday else mid_rate(code, day)
	var spread := book.spread_bp(code)
	var buy := Money.mul_div_floor(mid, 2 * BP - spread, 2 * BP)
	var sell := Money.mul_div_ceil(mid, 2 * BP + spread, 2 * BP)
	if spread > 0 and sell <= buy:
		sell = buy + 1
	return {"mid": mid, "buy": buy, "sell": sell}


## Sabah orta kurunun bir önceki güne göre değişimi (baz puan, işaretli). 1. gün için 0.
func change_bp(code: String, day: int) -> int:
	if day <= 1:
		return 0
	var previous := mid_rate(code, day - 1)
	var delta := mid_rate(code, day) - previous
	return (delta * BP) / previous if delta >= 0 else -((-delta * BP) / previous)


## Müşteri `foreign_minor` (kuruş) döviz SATARSA ödenecek PL (kuruş): ALIŞ kuruyla, `payout_round_to`nun katına aşağı yuvarlanır.
func buy_payout(code: String, foreign_minor: int, day: int, midday := false) -> int:
	var exact := Money.mul_div_floor(foreign_minor, int(rates(code, day, midday)["buy"]), Money.RATE_SCALE)
	return Money.floor_to(exact, payout_round_to)


## Müşteri `foreign_minor` (kuruş) döviz ALIRSA ödeyeceği PL (kuruş): SATIŞ kuruyla, `payout_round_to`nun katına yukarı yuvarlanır.
func sell_cost(code: String, foreign_minor: int, day: int, midday := false) -> int:
	var exact := Money.mul_div_ceil(foreign_minor, int(rates(code, day, midday)["sell"]), Money.RATE_SCALE)
	return Money.ceil_to(exact, payout_round_to)
