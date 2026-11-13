class_name LaundryBoard
extends RefCounted

## Saf mantık: Çamaşır İpi tahtası (ipler, bekleme askısı, sepetler, kuyruk).
## Sahneye bağımlı değildir; her hamle animasyon için bir olay listesi döndürür.
##
## Kurallar (PROJECT_SPEC §1): yalnız açık çamaşır alınır; rengi aktif bir sepetle
## eşleşirse sepete, eşleşmezse askıya gider. Sepet 3 parçayla dolunca çıkar, kuyruktan
## yenisi gelir ve askıdaki aynı renkler kendiliğinden yeni sepete geçer. Askı dolunca
## (hiçbir parça sepete geçemiyorsa) seviye kaybedilir.

const BASKET_CAPACITY: int = 3
const DEFAULT_RACK_SLOTS: int = 4
const EMPTY: int = -1

const EVENT_BLOCKED: String = "blocked"
const EVENT_TO_BASKET: String = "to_basket"
const EVENT_TO_RACK: String = "to_rack"
const EVENT_RACK_TO_BASKET: String = "rack_to_basket"
const EVENT_BASKET_DONE: String = "basket_done"
const EVENT_BASKET_NEW: String = "basket_new"
const EVENT_WIN: String = "win"
const EVENT_LOSE: String = "lose"

## Çamaşır kimliği -> {color:int, blockers:Array[int], ...yerleşim alanları}.
var _items: Dictionary = {}
## Hâlâ ipte olan çamaşır kimlikleri.
var _on_line: Dictionary = {}
## Askı slotları: çamaşır kimliği ya da EMPTY.
var _rack: Array[int] = []
## Aktif sepetler: {color:int, count:int} ya da boş sözlük (kuyruk bitti).
var _baskets: Array[Dictionary] = []
## Sıradaki sepet renkleri.
var _queue: Array[int] = []
var _won: bool = false
var _lost: bool = false
var _moves: int = 0


## `level`: {items:[{id,color,blockers,...}], queue:[renk...], active_baskets:int, rack_slots:int}
func _init(level: Dictionary) -> void:
	for entry: Variant in level.get("items", []) as Array:
		var item: Dictionary = (entry as Dictionary).duplicate(true)
		var id: int = int(item.get("id", 0))
		_items[id] = item
		_on_line[id] = true
	for color: Variant in level.get("queue", []) as Array:
		_queue.append(int(color))
	var slots: int = maxi(int(level.get("rack_slots", DEFAULT_RACK_SLOTS)), 1)
	for _i: int in range(slots):
		_rack.append(EMPTY)
	var active: int = maxi(int(level.get("active_baskets", 2)), 1)
	for _i: int in range(active):
		_baskets.append(_next_basket())


func is_won() -> bool:
	return _won


func is_lost() -> bool:
	return _lost


func is_over() -> bool:
	return _won or _lost


func moves() -> int:
	return _moves


func item(id: int) -> Dictionary:
	return (_items.get(id, {}) as Dictionary).duplicate(true)


func item_ids() -> Array[int]:
	var ids: Array[int] = []
	for id: Variant in _items.keys():
		ids.append(int(id))
	ids.sort()
	return ids


func color_of(id: int) -> int:
	return int((_items.get(id, {}) as Dictionary).get("color", EMPTY))


func is_on_line(id: int) -> bool:
	return _on_line.has(id)


## Çamaşırı hâlâ kapatan (ipte duran) çamaşırlar.
func blockers_of(id: int) -> Array[int]:
	var result: Array[int] = []
	for blocker: Variant in (_items.get(id, {}) as Dictionary).get("blockers", []) as Array:
		if _on_line.has(int(blocker)):
			result.append(int(blocker))
	return result


func is_open(id: int) -> bool:
	return _on_line.has(id) and blockers_of(id).is_empty()


func open_ids() -> Array[int]:
	var result: Array[int] = []
	for id: int in item_ids():
		if is_open(id):
			result.append(id)
	return result


func remaining_on_line() -> int:
	return _on_line.size()


func rack() -> Array[int]:
	return _rack.duplicate()


func rack_count() -> int:
	var count: int = 0
	for slot: int in _rack:
		if slot != EMPTY:
			count += 1
	return count


func rack_slots() -> int:
	return _rack.size()


func baskets() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for basket: Dictionary in _baskets:
		copy.append(basket.duplicate())
	return copy


func queue() -> Array[int]:
	return _queue.duplicate()


## Kaybedilen seviyede "+1 askı ile devam": yeni boş slot ekler, oyun sürer.
func add_rack_slot() -> void:
	_rack.append(EMPTY)
	_lost = false


## Açık çamaşıra dokunuş. Dönen olay listesi sırayla canlandırılır.
func tap(id: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if is_over() or not _on_line.has(id):
		return events
	var blockers: Array[int] = blockers_of(id)
	if not blockers.is_empty():
		events.append({"type": EVENT_BLOCKED, "id": id, "by": blockers})
		return events
	var color: int = color_of(id)
	var basket_index: int = _basket_for(color)
	if basket_index == EMPTY and _free_rack_slot() == EMPTY:
		# Askı dolu ve eşleşen sepet yok: hamle yapılamaz (zaten kayıp durumu).
		return events
	_on_line.erase(id)
	_moves += 1
	if basket_index != EMPTY:
		_put_in_basket(id, basket_index, EVENT_TO_BASKET, events)
	else:
		var slot: int = _free_rack_slot()
		_rack[slot] = id
		events.append({"type": EVENT_TO_RACK, "id": id, "slot": slot})
	_settle(events)
	return events


func _settle(events: Array[Dictionary]) -> void:
	# Dolan sepetler çıkar, yenileri gelir, askıdakiler kendiliğinden geçer; zincirleme sürer.
	var changed: bool = true
	while changed:
		changed = false
		for index: int in range(_baskets.size()):
			var basket: Dictionary = _baskets[index]
			if basket.is_empty() or int(basket["count"]) < BASKET_CAPACITY:
				continue
			events.append({"type": EVENT_BASKET_DONE, "basket": index, "color": int(basket["color"])})
			_baskets[index] = _next_basket()
			var fresh: Dictionary = _baskets[index]
			if not fresh.is_empty():
				events.append({"type": EVENT_BASKET_NEW, "basket": index, "color": int(fresh["color"])})
			changed = true
		for slot: int in range(_rack.size()):
			var id: int = _rack[slot]
			if id == EMPTY:
				continue
			var target: int = _basket_for(color_of(id))
			if target == EMPTY:
				continue
			_rack[slot] = EMPTY
			_put_in_basket(id, target, EVENT_RACK_TO_BASKET, events, slot)
			changed = true
	if _on_line.is_empty() and rack_count() == 0:
		_won = true
		events.append({"type": EVENT_WIN})
	elif _free_rack_slot() == EMPTY:
		_lost = true
		events.append({"type": EVENT_LOSE, "remaining": _on_line.size() + rack_count()})


func _put_in_basket(id: int, basket_index: int, event_type: String,
		events: Array[Dictionary], from_slot: int = EMPTY) -> void:
	var basket: Dictionary = _baskets[basket_index]
	var position: int = int(basket["count"])
	basket["count"] = position + 1
	var event: Dictionary = {"type": event_type, "id": id, "basket": basket_index, "index": position}
	if from_slot != EMPTY:
		event["slot"] = from_slot
	events.append(event)


func _basket_for(color: int) -> int:
	for index: int in range(_baskets.size()):
		var basket: Dictionary = _baskets[index]
		if basket.is_empty():
			continue
		if int(basket["color"]) == color and int(basket["count"]) < BASKET_CAPACITY:
			return index
	return EMPTY


func _free_rack_slot() -> int:
	for slot: int in range(_rack.size()):
		if _rack[slot] == EMPTY:
			return slot
	return EMPTY


func _next_basket() -> Dictionary:
	if _queue.is_empty():
		return {}
	var color: int = _queue.pop_front()
	return {"color": color, "count": 0}
