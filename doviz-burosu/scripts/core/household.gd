class_name Household
extends RefCounted
## Oyuncunun evi: nakit (PL), döviz birikimi, giderler ve aile ruh hali.
## - Giderler data/household.json'da; fiyatlar cost_inflation_bp ile her gün bileşik artar (maaş sabit kalır).
## - Ödenmeyen gider ruh halini düşürür; kira 2 kez ödenmezse evden atılırsın, ruh hali 0'a inerse aile köye gider.
## - Birikimi PL'de tutabilir ya da SATIŞ kuruyla dövize çevirip enflasyondan korunabilirsin (bozdururken ALIŞ kuru).

const DEFAULT_PATH := "res://data/household.json"
const INFLATION_SCALE := 10000

var cash_minor := 0
## Döviz birikimi: para birimi -> kuruş.
var savings: Dictionary = {}
var mood := 100
var rent_missed := 0
var flags: Dictionary = {}

var _expenses: Array[Dictionary] = []
var _inflation_bp := 150
var _mood_recovery := 5
var _evict_after := 2
var _mood_start := 100


func _init(table: Dictionary = {}) -> void:
	for expense: Variant in table.get("expenses", []):
		_expenses.append(expense)
	_inflation_bp = int(table.get("cost_inflation_bp", 150))
	_mood_recovery = int(table.get("mood_recovery", 5))
	_evict_after = int(table.get("evict_after_missed_rents", 2))
	_mood_start = int(table.get("mood_start", 100))
	mood = _mood_start
	cash_minor = Money.units(int(table.get("start_cash_pl", 0)))


static func load_default() -> Household:
	return Household.new(JsonIO.read_dict(DEFAULT_PATH))


## Gider fiyat endeksi (x10000): 1. gün 10000, sonra her gün bileşik artar.
func inflation_index(day: int) -> int:
	var index := INFLATION_SCALE
	for d in range(2, day + 1):
		index = Money.mul_div_floor(index, INFLATION_SCALE + _inflation_bp, INFLATION_SCALE)
	return index


func expense_def(expense_id: String) -> Dictionary:
	for expense in _expenses:
		if expense["id"] == expense_id:
			return expense
	return {}


## O günkü tutar (kuruş): 1. gün fiyatı x endeks, 5 PL'ye yukarı yuvarlanır.
func amount_minor(expense_id: String, day: int) -> int:
	var raw := Money.mul_div_ceil(Money.units(int(expense_def(expense_id)["base_pl"])), inflation_index(day), INFLATION_SCALE)
	return Money.ceil_to(raw, 500)


## O gün ödenmesi gereken giderler: [{id, amount_minor, priority}] (öncelik büyükten küçüğe).
func due_expenses(day: int) -> Array[Dictionary]:
	var due: Array[Dictionary] = []
	for expense in _expenses:
		var first := int(expense["first_day"])
		if day < first or (day - first) % int(expense["every_days"]) != 0:
			continue
		if expense.has("requires_flag") and not bool(flags.get(expense["requires_flag"], false)):
			continue
		due.append({"id": expense["id"], "amount_minor": amount_minor(expense["id"], day), "priority": int(expense.get("priority", 0))})
	due.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["priority"] > b["priority"])
	return due


## Akşam: `paid_ids` sırasıyla ödenir (nakit yetmeyen atlanır). Ödenmeyen her gider cezasını işler.
## Dönen rapor: {day, paid, unpaid, spent_minor, mood_before, mood_after, cash_after, rent_missed, over}.
func settle_day(day: int, paid_ids: Array) -> Dictionary:
	var due := due_expenses(day)
	var due_by_id := {}
	for expense in due:
		due_by_id[expense["id"]] = expense
	var report := {"day": day, "paid": [], "unpaid": [], "spent_minor": 0, "mood_before": mood}
	for expense_id: Variant in paid_ids:
		if not due_by_id.has(expense_id) or expense_id in report["paid"]:
			continue
		var cost := int(due_by_id[expense_id]["amount_minor"])
		if cost <= cash_minor:
			cash_minor -= cost
			report["spent_minor"] += cost
			report["paid"].append(expense_id)
	for expense in due:
		if expense["id"] in report["paid"]:
			continue
		report["unpaid"].append(expense["id"])
		var def := expense_def(expense["id"])
		mood -= int(def.get("mood_penalty", 0))
		if def.get("counts_as_rent", false):
			rent_missed += 1
	if report["unpaid"].is_empty():
		mood += _mood_recovery
	mood = clampi(mood, 0, _mood_start)
	report["mood_after"] = mood
	report["cash_after"] = cash_minor
	report["rent_missed"] = rent_missed
	report["over"] = game_over_reason()
	return report


## "" | "evicted" (kira çok kez ödenmedi) | "family_left" (ruh hali bitti).
func game_over_reason() -> String:
	if rent_missed >= _evict_after:
		return "evicted"
	if mood <= 0:
		return "family_left"
	return ""


## `pl_minor` nakdi SATIŞ kuruyla dövize çevirir; kasaya gelen döviz tutarını (kuruş) döndürür. Nakit yetmezse 0.
func convert_to_foreign(code: String, pl_minor: int, rates: RateTable, day: int) -> int:
	if pl_minor <= 0 or pl_minor > cash_minor:
		return 0
	var foreign := Money.mul_div_floor(pl_minor, Money.RATE_SCALE, int(rates.rates(code, day)["sell"]))
	cash_minor -= pl_minor
	savings[code] = int(savings.get(code, 0)) + foreign
	return foreign


## `foreign_minor` döviz birikimini ALIŞ kuruyla PL'ye çevirir; nakde eklenen tutarı döndürür. Birikim yetmezse 0.
func convert_to_local(code: String, foreign_minor: int, rates: RateTable, day: int) -> int:
	if foreign_minor <= 0 or foreign_minor > int(savings.get(code, 0)):
		return 0
	var local := Money.mul_div_floor(foreign_minor, int(rates.rates(code, day)["buy"]), Money.RATE_SCALE)
	savings[code] = int(savings[code]) - foreign_minor
	cash_minor += local
	return local


## Nakit + dövizlerin ALIŞ kuruyla PL değeri (kuruş).
func net_worth_minor(rates: RateTable, day: int) -> int:
	var total := cash_minor
	for code: String in savings:
		total += Money.mul_div_floor(int(savings[code]), int(rates.rates(code, day)["buy"]), Money.RATE_SCALE)
	return total


func to_dict() -> Dictionary:
	return {"cash_minor": cash_minor, "savings": savings.duplicate(), "mood": mood, "rent_missed": rent_missed, "flags": flags.duplicate()}


func load_dict(data: Dictionary) -> void:
	cash_minor = int(data.get("cash_minor", 0))
	savings = {}
	for code: Variant in (data.get("savings", {}) as Dictionary).keys():
		savings[code] = int(data["savings"][code])
	mood = int(data.get("mood", _mood_start))
	rent_missed = int(data.get("rent_missed", 0))
	flags = (data.get("flags", {}) as Dictionary).duplicate()
