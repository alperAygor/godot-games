class_name EveningPlan
extends RefCounted
## Akşam ekranının mantığı: hangi giderler ödenecek, birikim dövize çevrilsin mi. Ekran sadece gösterir.
## Nakit yetmeyen gider seçilemez (Papers, Please gibi); döviz alınca nakit azalırsa en düşük öncelikli seçimler düşer.

## Birikim için kullanılan döviz (enflasyondan korunma).
const SAVINGS_CODE := "FED"

var career: Career
var shift: Shift
var report: Dictionary
## Seçili gider kimlikleri, öncelik sırasıyla.
var selected: Array[String] = []


func _init(for_career: Career, finished_shift: Shift) -> void:
	career = for_career
	shift = finished_shift
	report = career.begin_evening(finished_shift)
	for expense_id in career.affordable_expense_ids(finished_shift):
		selected.append(str(expense_id))


func cash_minor() -> int:
	return career.household.cash_minor


func due() -> Array[Dictionary]:
	return career.household.due_expenses(career.day)


func selected_total() -> int:
	var total := 0
	for expense in due():
		if expense["id"] in selected:
			total += int(expense["amount_minor"])
	return total


## Giderler seçildikten sonra kalacak nakit.
func remaining_cash() -> int:
	return cash_minor() - selected_total()


func is_selected(expense_id: String) -> bool:
	return expense_id in selected


func amount_of(expense_id: String) -> int:
	for expense in due():
		if expense["id"] == expense_id:
			return int(expense["amount_minor"])
	return 0


## Seçili değilse ve kalan nakit yetiyorsa seçilebilir; seçiliyse her zaman kaldırılabilir.
func can_toggle(expense_id: String) -> bool:
	return is_selected(expense_id) or amount_of(expense_id) <= remaining_cash()


## Seçimi değiştirir. Dönen değer: işlemden sonra seçili mi.
func toggle(expense_id: String) -> bool:
	if is_selected(expense_id):
		selected.erase(expense_id)
		return false
	if amount_of(expense_id) > 0 and amount_of(expense_id) <= remaining_cash():
		selected.append(expense_id)
		_sort_selected()
		return true
	return false


## Bugünün (akşam) kurları: {mid, buy, sell}.
func rates() -> Dictionary:
	return shift.ctx.rates.rates(SAVINGS_CODE, career.day, shift.ctx.use_midday_rates())


func savings_minor() -> int:
	return int(career.household.savings.get(SAVINGS_CODE, 0))


## Döviz birikiminin ALIŞ kuruyla PL değeri.
func savings_value_minor() -> int:
	return Money.mul_div_floor(savings_minor(), int(rates()["buy"]), Money.RATE_SCALE)


## `pl_minor` nakdi dövize çevirir (SATIŞ kuru). Dönen: alınan döviz (kuruş), olmadıysa 0.
func buy_savings(pl_minor: int) -> int:
	var got := career.household.convert_to_foreign(SAVINGS_CODE, pl_minor, shift.ctx.rates, career.day)
	_trim_selection()
	return got


## `foreign_minor` döviz birikimini bozdurur (ALIŞ kuru). Dönen: eklenen nakit (kuruş), olmadıysa 0.
func sell_savings(foreign_minor: int) -> int:
	return career.household.convert_to_local(SAVINGS_CODE, foreign_minor, shift.ctx.rates, career.day)


## Akşam dükkanı: bugün alınabilecek araçlar ve fiyatları [{id, price_minor}].
func shop() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for tool_id in career.buyable_tool_ids():
		items.append({"id": tool_id, "price_minor": career.tool_price_minor(tool_id)})
	return items


## Araç satın alır (nakit yetiyorsa); nakit azaldığı için en düşük öncelikli gider seçimleri düşebilir.
func buy_tool(tool_id: String) -> bool:
	var bought := career.buy_tool(tool_id)
	if bought:
		_trim_selection()
	return bought


## "Eve git": seçilen giderler ödenir, gün biter. Dönen: Career.settle_evening raporu.
func finish() -> Dictionary:
	return career.settle_evening(selected)


func _sort_selected() -> void:
	var order: Array[String] = []
	for expense in due():
		order.append(str(expense["id"]))
	selected.sort_custom(func(a: String, b: String) -> bool: return order.find(a) < order.find(b))


## Nakit azaldıysa en düşük öncelikli (listenin sonundaki) seçimleri bırak.
func _trim_selection() -> void:
	while not selected.is_empty() and remaining_cash() < 0:
		selected.pop_back()
