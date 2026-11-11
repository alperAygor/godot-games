class_name Wallet
extends RefCounted

## Para birimi: Altın (gold) + Hurda (scrap). Negatif bakiye olamaz.
## Sözleşme: ARCHITECTURE.md §4.7.
##
## Güvenlik: negatif girdi 0 sayılır (yalnız ekler). from_dict'te
## eksik/yanlış tip/negatif değer 0 döner.

var _gold: int
var _scrap: int


func _init(gold: int = 0, scrap: int = 0) -> void:
	_gold = maxi(gold, 0)
	_scrap = maxi(scrap, 0)


func gold() -> int:
	return _gold


func scrap() -> int:
	return _scrap


func add(gold: int, scrap: int = 0) -> void:
	# Negatif girdi 0 sayılır (yalnız ekler).
	_gold += maxi(gold, 0)
	_scrap += maxi(scrap, 0)


func can_afford(cost: Dictionary) -> bool:
	# {"gold": int, "scrap": int}; eksik anahtar 0.
	var need_gold: int = int(cost.get("gold", 0))
	var need_scrap: int = int(cost.get("scrap", 0))
	return _gold >= need_gold and _scrap >= need_scrap


func spend(cost: Dictionary) -> bool:
	# Yeterliyse düşer ve true; değilse HİÇBİR ŞEY değişmez ve false.
	if not can_afford(cost):
		return false
	var need_gold: int = int(cost.get("gold", 0))
	var need_scrap: int = int(cost.get("scrap", 0))
	_gold -= need_gold
	_scrap -= need_scrap
	return true


func to_dict() -> Dictionary:
	return {"gold": _gold, "scrap": _scrap}


static func from_dict(d: Dictionary) -> Wallet:
	# Eksik/yanlış tip/negatif/küsuratlı -> 0. JSON'dan gelen küsuratsız float (10.0)
	# tamsayı sayılır: Godot JSON her sayıyı float üretir (GOTCHAS #20).
	var w: Wallet = Wallet.new()
	w._gold = _whole_or_zero(d.get("gold", 0))
	w._scrap = _whole_or_zero(d.get("scrap", 0))
	return w


## Küsuratsız sayıyı (int ya da tam sayı değerli float) int'e çevirir; diğer her şey 0.
static func _whole_or_zero(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return maxi(int(value), 0)
	if typeof(value) == TYPE_FLOAT:
		var f: float = float(value)
		if is_finite(f) and is_equal_approx(f, roundf(f)):
			return maxi(int(roundf(f)), 0)
	return 0
