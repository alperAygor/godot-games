class_name Till
extends RefCounted
## Kasa çekmecesi: para birimi -> kupür -> adet. Ödeme yalnızca eldeki kupürlerle TAM tutarı verebiliyorsa mümkündür
## (ör. 3 FED isteyen müşteriye 1'lik banknot yoksa ödenemez).

var _stock := {}  # code -> {denom (int): count (int)}


## Gün başı kasa: balance.till.start_counts içinden, o gün dolaşımdaki para birimleri için.
static func from_balance(book: CurrencyBook, balance: Dictionary, day: int) -> Till:
	var till := Till.new()
	var start: Dictionary = JsonIO.get_path_value(balance, "till.start_counts", {})
	for code: Variant in start.keys():
		var code_text := str(code)
		if not book.has(code_text) or (not book.is_local(code_text) and book.from_day(code_text) > day):
			continue
		for denom: Variant in start[code].keys():
			till.add(code_text, int(denom), int(start[code][denom]))
	return till


func duplicate_till() -> Till:
	var copy := Till.new()
	copy._stock = _stock.duplicate(true)
	return copy


func count(code: String, denom: int) -> int:
	return int((_stock.get(code, {}) as Dictionary).get(denom, 0))


func add(code: String, denom: int, amount := 1) -> void:
	if not _stock.has(code):
		_stock[code] = {}
	_stock[code][denom] = count(code, denom) + amount


## Kasada `code` cinsinden toplam tutar (kuruş).
func total_minor(code: String) -> int:
	var total := 0
	for denom: int in (_stock.get(code, {}) as Dictionary).keys():
		total += denom * Money.UNIT * count(code, denom)
	return total


func deposit(note: Banknote) -> void:
	add(note.currency, note.denom, 1)


func deposit_all(notes: Array) -> void:
	for note: Banknote in notes:
		deposit(note)


## `amount_minor`u eldeki kupürlerle tam olarak ödeme planı: {"ok": bool, "notes": {denom: adet}}.
## Tutar 0 ise ok = true ve notes boş. Mümkün değilse ok = false.
func pay_plan(code: String, amount_minor: int) -> Dictionary:
	if amount_minor == 0:
		return {"ok": true, "notes": {}}
	if amount_minor < 0 or amount_minor % Money.UNIT != 0 or not _stock.has(code):
		return {"ok": false, "notes": {}}
	var denoms: Array[int] = []
	for denom: int in (_stock[code] as Dictionary).keys():
		if count(code, denom) > 0:
			denoms.append(denom)
	denoms.sort()
	denoms.reverse()
	var counts: Array[int] = []
	for denom in denoms:
		counts.append(count(code, denom))
	var picks: Array[int] = []
	picks.resize(denoms.size())
	picks.fill(0)
	if not _search(denoms, counts, 0, amount_minor / Money.UNIT, {}, picks):
		return {"ok": false, "notes": {}}
	var plan := {}
	for i in denoms.size():
		if picks[i] > 0:
			plan[denoms[i]] = picks[i]
	return {"ok": true, "notes": plan}


func can_pay(code: String, amount_minor: int) -> bool:
	return pay_plan(code, amount_minor)["ok"]


## Planı kasadan düşer. Plan bu kasadan yapılmış olmalı; değilse false döner ve hiçbir şey değişmez.
func take(code: String, plan: Dictionary) -> bool:
	for denom: Variant in plan.keys():
		if count(code, int(denom)) < int(plan[denom]):
			return false
	for denom: Variant in plan.keys():
		_stock[code][int(denom)] = count(code, int(denom)) - int(plan[denom])
	return true


## Tamamlanan işlemi kasaya işler: kabul edilen banknotlar girer, ödemeler çıkar. Ödenemiyorsa false (hiçbir şey değişmez).
func settle(customer: Customer, verdict: Verdict) -> bool:
	if verdict.decision != Verdict.DECISION_COMPLETE:
		return true
	var after := duplicate_till()
	after.deposit_all(verdict.accepted_notes(customer))
	for code: String in verdict.pay_out:
		var plan := after.pay_plan(code, int(verdict.pay_out[code]))
		if not plan["ok"] or not after.take(code, plan["notes"]):
			return false
	_stock = after._stock
	return true


## Oyuncunun GERÇEK hamlesini kasaya işler (beklenen hükmü değil): "Tamamla" ise kabul ettiği banknotlar girer ve
## `move.paid` kadar ödeme çıkar. Ödeme eldeki kupürlerle yapılamıyorsa false döner ve hiçbir şey değişmez.
## Reddet/polis hamlesinde kasa değişmez.
func apply_move(customer: Customer, move: PlayerMove) -> bool:
	if move.decision != Verdict.DECISION_COMPLETE:
		return true
	var after := duplicate_till()
	for i in customer.notes.size():
		if i < move.fates.size() and move.fates[i] == Verdict.FATE_ACCEPT:
			after.deposit(customer.notes[i])
	for code: String in move.paid:
		var plan := after.pay_plan(code, int(move.paid[code]))
		if not plan["ok"] or not after.take(code, plan["notes"]):
			return false
	_stock = after._stock
	return true


func to_dict() -> Dictionary:
	var data := {}
	for code: String in _stock:
		var counts := {}
		for denom: int in (_stock[code] as Dictionary).keys():
			counts[str(denom)] = count(code, denom)
		data[code] = counts
	return data


static func from_dict(data: Dictionary) -> Till:
	var till := Till.new()
	for code: String in data:
		for denom: Variant in (data[code] as Dictionary).keys():
			till.add(code, int(denom), int(data[code][denom]))
	return till


## Üstten aşağı kupür denemesi; başarısız (indeks, kalan) çiftleri `memo`da tutulur.
func _search(denoms: Array[int], counts: Array[int], index: int, remaining: int, memo: Dictionary, picks: Array[int]) -> bool:
	if remaining == 0:
		return true
	if index >= denoms.size():
		return false
	var key := index * 100000000 + remaining
	if memo.has(key):
		return false
	var denom := denoms[index]
	for k in range(mini(counts[index], remaining / denom), -1, -1):
		picks[index] = k
		if _search(denoms, counts, index + 1, remaining - k * denom, memo, picks):
			return true
	picks[index] = 0
	memo[key] = true
	return false
