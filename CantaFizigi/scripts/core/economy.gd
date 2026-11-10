class_name Economy
extends RefCounted

## Yukseltme fiyat/limit matematigi. Tablo `data/upgrades.json`'dan gelir; burasi saf.

const INVALID: int = -1


static func row(table: Dictionary, upgrade_id: String) -> Dictionary:
	var found: Variant = table.get(upgrade_id)
	if found is Dictionary:
		return found as Dictionary
	return {}


static func max_level(table: Dictionary, upgrade_id: String) -> int:
	return maxi(0, int(row(table, upgrade_id).get("max_level", 0)))


## Bir sonraki seviyenin fiyati. Seviye limitteyse INVALID (-1) doner.
static func cost(table: Dictionary, upgrade_id: String, current_level: int) -> int:
	var data: Dictionary = row(table, upgrade_id)
	if data.is_empty():
		return INVALID
	if current_level >= max_level(table, upgrade_id):
		return INVALID
	var base_cost: float = float(data.get("base_cost", 0))
	var growth: float = float(data.get("cost_growth", 1.0))
	return int(round(base_cost * pow(growth, float(current_level))))


static func can_buy(table: Dictionary, upgrade_id: String, current_level: int,
		currency: int) -> bool:
	var price: int = cost(table, upgrade_id, current_level)
	return price != INVALID and currency >= price
