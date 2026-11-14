class_name PrizSlice
extends RefCounted
## Gün dilimleri: sabah, öğle, akşam, gece. Bir cihazın çalıştığı dilimler bit maskesiyle
## tutulur (bit 0 = sabah ... bit 3 = gece). Düz kipte tüm cihazlar dört dilimde de çalışır.

const MORNING: int = 0
const NOON: int = 1
const EVENING: int = 2
const NIGHT: int = 3
const COUNT: int = 4
const ALL_MASK: int = 15
const IDS: Array[String] = ["morning", "noon", "evening", "night"]


static func id_of(slice: int) -> String:
	if slice < 0 or slice >= COUNT:
		return ""
	return IDS[slice]


## Bilinmeyen kimlikte -1 döner.
static func from_id(slice_id: String) -> int:
	return IDS.find(slice_id)


static func has(mask: int, slice: int) -> bool:
	return (mask >> slice) & 1 == 1


static func mask_from_ids(ids: Array) -> int:
	var mask: int = 0
	for entry: Variant in ids:
		var index: int = from_id(str(entry))
		if index >= 0:
			mask |= 1 << index
	return mask


## Maske her zaman sabah→gece sırasıyla yazılır (bayt-bayt aynı JSON için).
static func ids_from_mask(mask: int) -> Array[String]:
	var result: Array[String] = []
	for index: int in COUNT:
		if has(mask, index):
			result.append(IDS[index])
	return result


## Maskeyi dilim ekseninde döngüsel olarak ileri kaydırır (gece → sabaha sarar).
static func rotate(mask: int, shift: int) -> int:
	var amount: int = posmod(shift, COUNT)
	if amount == 0:
		return mask & ALL_MASK
	var m: int = mask & ALL_MASK
	return ((m << amount) | (m >> (COUNT - amount))) & ALL_MASK
