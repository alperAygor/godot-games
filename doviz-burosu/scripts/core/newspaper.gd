class_name Newspaper
extends RefCounted
## Sabah gazetesinin içeriği (veri; ekran sadece çizer): manşet, kurlar, yeni kural, bülten, aile, nakit.
## Manşet metinleri strings.csv'de NEWS_<gün>_HEAD / _BODY (15. günden sonrası 15. günü kullanır).

const LAST_NEWS_DAY := 15

## Aile ruh hali eşikleri (altı = kötü / orta).
const MOOD_GOOD := 80
const MOOD_OK := 50


## Kariyerin ŞİMDİKİ gününün gazetesi. Kurlar ve bülten vardiyayla aynı tohumdan gelir.
static func build(career: Career) -> Dictionary:
	var ctx := career.make_context()
	var day := career.day
	var news_day := clampi(day, 1, LAST_NEWS_DAY)
	var rates: Array[Dictionary] = []
	for code in ctx.book.foreign_codes(day):
		var today := ctx.rates.rates(code, day)
		rates.append({"code": code, "buy": int(today["buy"]), "sell": int(today["sell"]), "change_bp": ctx.rates.change_bp(code, day)})
	var new_rules: Array[String] = []
	for rule_def in ctx.rules.all():
		if int(rule_def["from_day"]) == day:
			new_rules.append(str(rule_def["id"]))
	var new_tools: Array[String] = []
	for tool_def in JsonIO.read_dict("res://data/tools.json").get("tools", []):
		if tool_def.has("free_on_day") and int(tool_def["free_on_day"]) == day:
			new_tools.append(str(tool_def["id"]))
	var stolen: Array[Dictionary] = []
	for range_def in ctx.bulletin.stolen_ranges:
		stolen.append({
			"currency": range_def["currency"], "series_id": range_def["series_id"],
			"from_serial": ctx.book.make_serial(range_def["currency"], range_def["series_id"], int(range_def["from"])),
			"to_serial": ctx.book.make_serial(range_def["currency"], range_def["series_id"], int(range_def["to"])),
		})
	var rent_today := 0
	for expense in career.household.due_expenses(day):
		if expense["id"] == "rent":
			rent_today = int(expense["amount_minor"])
	return {
		"day": day,
		"head_key": "NEWS_%02d_HEAD" % news_day,
		"body_key": "NEWS_%02d_BODY" % news_day,
		"rates": rates,
		"new_rules": new_rules,
		"new_tools": new_tools,
		"stolen": stolen,
		"directive": career.todays_directive(),
		"wanted_faces": ctx.bulletin.wanted_faces.duplicate(),
		"family_key": family_key(career.household.mood),
		"mood": career.household.mood,
		"rent_today_minor": rent_today,
		"cash_minor": career.household.cash_minor,
		"last_unpaid": last_unpaid(career),
	}


static func family_key(mood: int) -> String:
	if mood >= MOOD_GOOD:
		return "NEWS_FAMILY_GOOD"
	if mood >= MOOD_OK:
		return "NEWS_FAMILY_WORRIED"
	return "NEWS_FAMILY_BAD"


## Dün ödenmeyen giderlerin kimlikleri (ilk gün ya da hepsi ödendiyse boş).
static func last_unpaid(career: Career) -> Array[String]:
	var result: Array[String] = []
	if career.history.is_empty():
		return result
	for expense_id: Variant in career.history[-1]["household"]["unpaid"]:
		result.append(str(expense_id))
	return result
