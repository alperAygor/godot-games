class_name DayContext
extends RefCounted
## Bir günün (ve anın) tüm girdileri: kurlar, açık kurallar, kasa, bülten. RuleEngine bunun üzerinden karar verir.

var day := 1
## Saat 13:00'ü geçti mi? Kur güncellemesi yalnızca R_MIDDAY_RATE açıksa işler.
var midday := false
var book: CurrencyBook
var rules: RuleSet
var rates: RateTable
var till: Till
var bulletin: Bulletin
var balance: Dictionary


## Veri dosyalarından bir bağlam kurar. options: salt (kur tuzu), midday (bool), bulletin (Bulletin), till (Till).
static func for_day(day_number: int, options: Dictionary = {}) -> DayContext:
	var ctx := DayContext.new()
	ctx.day = day_number
	ctx.midday = bool(options.get("midday", false))
	ctx.book = CurrencyBook.load_default()
	ctx.rules = options.get("rules", RuleSet.load_default())
	ctx.balance = JsonIO.read_dict("res://data/balance.json")
	ctx.rates = RateTable.new(ctx.book, ctx.balance, str(options.get("salt", "story")))
	ctx.till = options.get("till", Till.from_balance(ctx.book, ctx.balance, day_number))
	ctx.bulletin = options.get("bulletin", Bulletin.new())
	return ctx


func rule_active(rule_id: String) -> bool:
	return rules.is_active(rule_id, day)


## İşlemde gerçekten hangi kur geçerli: gün ortası güncellemesi yalnızca kural açıksa uygulanır.
func use_midday_rates() -> bool:
	return midday and rule_active("R_MIDDAY_RATE")


func min_remaining_percent() -> int:
	return int(JsonIO.get_path_value(balance, "notes.min_remaining_percent", 50))
