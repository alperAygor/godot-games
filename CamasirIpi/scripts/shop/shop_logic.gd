class_name ShopLogic
extends RefCounted

## Mağaza fiyat/paket kuralları — SAF (sahne/kayıt yok). Değerler data/balance.json "shop" ve
## "booster_cost" bloklarındadır; burada sabit sayı yoktur (denge dosyadan ayarlanır).

const DEFAULT_PACKS: Array[int] = [1, 3, 5]


## Seçilebilir paket adetleri (x1/x3/x5); bozuk/boş veri varsayılana düşer.
static func pack_sizes(balance: Dictionary) -> Array[int]:
	var result: Array[int] = []
	var raw: Variant = (balance.get("shop", {}) as Dictionary).get("pack_sizes")
	if raw is Array:
		for entry: Variant in raw as Array:
			var size: int = ProgressData.to_count(entry)
			if size > 0 and not result.has(size):
				result.append(size)
	return result if not result.is_empty() else DEFAULT_PACKS.duplicate()


## Pakete uygulanan indirim yüzdesi (0-90 arası kısılır: bedava/negatif fiyat olmasın).
static func discount_percent(balance: Dictionary, quantity: int) -> int:
	var table: Variant = (balance.get("shop", {}) as Dictionary).get("pack_discount_percent")
	if table is Dictionary:
		return clampi(ProgressData.to_count((table as Dictionary).get(str(quantity))), 0, 90)
	return 0


static func unit_price(balance: Dictionary, booster_id: String) -> int:
	return ProgressData.to_count((balance.get("booster_cost", {}) as Dictionary).get(booster_id))


## Paket fiyatı: tekil fiyat x adet, indirim düşülmüş, tam sayıya yuvarlanmış (en az 1 jeton).
static func pack_price(balance: Dictionary, booster_id: String, quantity: int) -> int:
	var base: int = unit_price(balance, booster_id) * maxi(quantity, 1)
	var discounted: float = float(base) * float(100 - discount_percent(balance, quantity)) / 100.0
	return maxi(roundi(discounted), 1) if base > 0 else 0


static func can_afford(coins: int, price: int) -> bool:
	return price > 0 and coins >= price
