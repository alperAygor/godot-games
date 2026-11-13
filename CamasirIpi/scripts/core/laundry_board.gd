class_name LaundryBoard
extends RefCounted

## Saf mantık: Çamaşır İpi tahtası (ipler, bekleme askısı, sepetler, kuyruk).
## Sahneye bağımlı değildir; her hamle animasyon için bir olay listesi döndürür.
##
## Kurallar (PROJECT_SPEC §1): yalnız açık çamaşır alınır; rengi aktif bir sepetle
## eşleşirse sepete, eşleşmezse askıya gider. Sepet 3 parçayla dolunca çıkar, kuyruktan
## yenisi gelir ve askıdaki aynı renkler kendiliğinden yeni sepete geçer. Askı dolunca
## (hiçbir parça sepete geçemiyorsa) seviye kaybedilir.
## Sonradan açılan engeller: çarşaf (iki ipe yayılan tek parça), çorap çifti (eşi hemen
## ardından alınmalı) ve boya akıtan (geri sayım biterse altındakiyle renk takası). Ayrıntılı
## kurallar ilgili bölümlerin başında yazılıdır. Geri al / mandal sökücü güçlendiricileri de
## burada saf mantık olarak durur (`undo`, `force_take`).

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
## Engeller (PROJECT_SPEC §3).
const EVENT_WRING: String = "wring"
const EVENT_LOCKED: String = "locked"
const EVENT_UNLOCK: String = "unlock"
const EVENT_RACK_FULL: String = "rack_full"
## Çorap çifti: ilk çorap alındı, eşi SIRADAKİ alınacak parça olmalı ({id, partner}).
const EVENT_SOCK_WAIT: String = "sock_wait"
## Eşi sırayla alınmadı: askıdaki ilk çorap takıldı, eşi alınana dek sepete geçemez ({id, partner}).
const EVENT_SOCK_STUCK: String = "sock_stuck"
## Eşi alındı: takılı çorap serbest ({id, partner}).
const EVENT_SOCK_FREE: String = "sock_free"
## Boya akıtan: geri sayım bir azaldı ({id, left}).
const EVENT_DYE_TICK: String = "dye_tick"
## Boya aktı: boyalı parça ile altındaki renk değiştirdi ({id, target, color, target_color}).
const EVENT_DYE_BLEED: String = "dye_bleed"
## Mandal sökücü: kapalı/kilitli parça engellere bakılmadan alındı ({id}); ardından normal olaylar.
const EVENT_PIN_REMOVED: String = "pin_removed"
## Boya akıtanın varsayılan geri sayımı (hamle).
const DEFAULT_DYE_MOVES: int = 5

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
## Tamamlanan sepet renkleri: kilitli mandallar bununla açılır.
var _completed: Dictionary = {}
## Eşinin hemen ardından alınmasını bekleyen ilk çorap (yoksa EMPTY).
var _sock_waiting: int = EMPTY
## Askıda takılı kalan çoraplar (eşi alınana dek sepete geçemez).
var _stuck: Dictionary = {}
## Sepet başına içindeki çamaşır kimlikleri: geri al sonrası görünüm yeniden kurulurken gerekir.
## `baskets()` çıktısına KATILMAZ; çözücünün durum anahtarı kimlik ayrıntısıyla şişmesin.
var _basket_ids: Array[Array] = []
## Geri al geçmişi (yalnız oyunda açılır; çözücü binlerce tahta kurar, kopya maliyeti istemez).
var _history: Array[Dictionary] = []
var _history_enabled: bool = false
## Boyalı parça kimlikleri (kurulumda bir kez): her hamlede tüm parçaları taramamak için.
var _dye_ids: Array[int] = []
## Kurallar gereği alanı değişebilen parçalar (ıslak, boyalı, boya hedefi). Geri al anlık
## görüntüsü yalnız bunları kopyalar: çözücü her düğümde anlık görüntü alır, ucuz olmalı.
var _mutable_ids: Array[int] = []

## `level`: {items:[{id,color,blockers,...}], queue:[renk...], active_baskets:int, rack_slots:int}
func _init(level: Dictionary) -> void:
	for entry: Variant in level.get("items", []) as Array:
		var item: Dictionary = (entry as Dictionary).duplicate(true)
		var id: int = int(item.get("id", 0))
		_items[id] = item
		_on_line[id] = true
		if item.has("dye"):
			_dye_ids.append(id)
		if item.has("wet") or item.has("dye"):
			_mutable_ids.append(id)
	_dye_ids.sort()
	for id: int in _dye_ids:
		var target: int = dye_target(id)
		if _items.has(target) and not _mutable_ids.has(target):
			_mutable_ids.append(target)
	_mutable_ids.sort()
	for color: Variant in level.get("queue", []) as Array:
		_queue.append(int(color))
	var slots: int = maxi(int(level.get("rack_slots", DEFAULT_RACK_SLOTS)), 1)
	for _i: int in range(slots):
		_rack.append(EMPTY)
	var active: int = maxi(int(level.get("active_baskets", 2)), 1)
	for _i: int in range(active):
		_baskets.append(_next_basket())
		_basket_ids.append([])


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


## Islak çamaşır: ilk dokunuşta sıkılır, ikincide alınır.
func is_wet(id: int) -> bool:
	return bool((_items.get(id, {}) as Dictionary).get("wet", false))


## Gizemli çamaşır: rengi üstü açılınca belli olur (yalnız görünüm; kural aynı).
func is_mystery(id: int) -> bool:
	return bool((_items.get(id, {}) as Dictionary).get("mystery", false))


## Kilitli mandalın beklediği sepet rengi; kilit yoksa EMPTY.
func lock_color(id: int) -> int:
	return int((_items.get(id, {}) as Dictionary).get("lock", EMPTY))


func is_locked(id: int) -> bool:
	var color: int = lock_color(id)
	return _on_line.has(id) and color != EMPTY and not _completed.has(color)


func wet_ids() -> Array[int]:
	var result: Array[int] = []
	for id: int in item_ids():
		if _on_line.has(id) and is_wet(id):
			result.append(id)
	return result


func completed_colors() -> Array[int]:
	var result: Array[int] = []
	for color: Variant in _completed.keys():
		result.append(int(color))
	result.sort()
	return result


## Şu an alınabilen (açık ve kilitsiz) çamaşırlar.
func open_ids() -> Array[int]:
	var result: Array[int] = []
	for id: int in item_ids():
		if is_open(id) and not is_locked(id):
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
	if is_locked(id):
		events.append({"type": EVENT_LOCKED, "id": id, "color": lock_color(id)})
		return events
	if is_wet(id):
		_record_history()
		var ticking: Array[int] = _open_dyes()
		(_items[id] as Dictionary)["wet"] = false
		_moves += 1
		events.append({"type": EVENT_WRING, "id": id})
		# Sıkmak da bir hamledir: boya sayacı işler. Boya akarsa kayıp denetimi gerekir.
		if _tick_dyes(ticking, events):
			_settle(events)
		return events
	_take(id, events)
	return events


## Parçayı ipten alır (engel/kilit/ıslaklık denetimi çağırana aittir). Askı dolu ve eşleşen
## sepet yoksa alınamaz: EVENT_RACK_FULL eklenir, durum değişmez.
func _take(id: int, events: Array[Dictionary], prefix: Dictionary = {}) -> bool:
	var color: int = color_of(id)
	var basket_index: int = _basket_for(color)
	if basket_index == EMPTY and _free_rack_slot() == EMPTY:
		# Askı dolu ve eşleşen sepet yok: bu parça alınamaz (askı sallanır), oyun sürer.
		events.append({"type": EVENT_RACK_FULL, "id": id})
		return false
	_record_history()
	if not prefix.is_empty():
		events.append(prefix)
	# Sayaç, bu hamleden ÖNCE açık olan boyalılarda işler: hamlenin açtığı boyalı ilk
	# hamlesini kaybetmesin; alınan boyalı da artık ipte olmadığı için sayılmaz.
	var ticking: Array[int] = _open_dyes()
	_on_line.erase(id)
	_moves += 1
	if basket_index != EMPTY:
		_put_in_basket(id, basket_index, EVENT_TO_BASKET, events)
	else:
		var slot: int = _free_rack_slot()
		_rack[slot] = id
		events.append({"type": EVENT_TO_RACK, "id": id, "slot": slot})
	_apply_sock_rule(id, events)
	_tick_dyes(ticking, events)
	_settle(events)
	return true


## Mandal sökücü (güçlendirici): ipteki herhangi bir parçayı engel, kilit ve ıslaklığa
## bakmadan alır. Askı/sepet kuralı aynıdır (yer yoksa alınamaz). Çorap ve boya kuralları
## normal alım gibi işler; böylece güçlendirici kuralları delmez, yalnız erişimi açar.
func force_take(id: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if is_over() or not _on_line.has(id):
		return events
	if is_wet(id):
		(_items[id] as Dictionary)["wet"] = false
	_take(id, events, {"type": EVENT_PIN_REMOVED, "id": id})
	return events


# --- Çarşaf -------------------------------------------------------------------------------
# Çarşaf kuralda sıradan bir parçadır: tek renk, sepette TEK parça sayılır. Farkı yerleşimdedir:
# iki komşu ipe yayılır ve altındaki pek çok parçanın `blockers` listesinde durur; alınınca
# hepsi birden açılır. Bu yüzden ayrı kural/durum gerektirmez.

func is_sheet(id: int) -> bool:
	return bool((_items.get(id, {}) as Dictionary).get("sheet", false))


# --- Çorap çifti ----------------------------------------------------------------------------
# Kural (deterministik):
#  1) Bir çorap ipten alındığında eşi hâlâ ipteyse o çorap "bekleyen" olur.
#  2) Bekleyen varken alınan SIRADAKİ parça eşi ise çift tamamdır, ceza yoktur.
#  3) Sıradaki parça başka bir şeyse ve bekleyen çorap askıdaysa takılır: eşi alınana dek
#     sepete kendiliğinden geçmez (askı slotunu işgal eder). İlk çorap zaten sepete girdiyse
#     ceza yoktur (sepetteki parça geri alınamaz).
#  4) Takılı çorabın eşi alındığı an çorap serbest kalır; `_settle` onu uygun sepete taşır.
# "Alma" yalnız ipten ayrılmaktır: sıkma, engelli/kilitli dokunuş ve askı-dolu reddi sayılmaz.
# Çift 2 parça sayılır; üretici iki çorabı aynı renk grubuna koyar.

func sock_partner(id: int) -> int:
	return int((_items.get(id, {}) as Dictionary).get("sock", EMPTY))


func is_sock_stuck(id: int) -> bool:
	return _stuck.has(id)


func sock_waiting() -> int:
	return _sock_waiting


func stuck_ids() -> Array[int]:
	var result: Array[int] = []
	for id: Variant in _stuck.keys():
		result.append(int(id))
	result.sort()
	return result


func _apply_sock_rule(id: int, events: Array[Dictionary]) -> void:
	var partner: int = sock_partner(id)
	if _sock_waiting != EMPTY:
		var waiting: int = _sock_waiting
		_sock_waiting = EMPTY
		if waiting != partner and _rack.has(waiting):
			_stuck[waiting] = true
			events.append({"type": EVENT_SOCK_STUCK, "id": waiting, "partner": sock_partner(waiting)})
	if partner == EMPTY:
		return
	if _stuck.has(partner):
		_stuck.erase(partner)
		events.append({"type": EVENT_SOCK_FREE, "id": partner, "partner": id})
	elif _on_line.has(partner):
		_sock_waiting = id
		events.append({"type": EVENT_SOCK_WAIT, "id": id, "partner": partner})


# --- Boya akıtan ----------------------------------------------------------------------------
# Kural: `dye` = kalan hamle. Parça AÇIK (üstü boş, kilitsiz) ve ipteyken yapılan her hamlede
# (alma ya da sıkma; boyalının kendisini almak hariç) bir azalır. 0 olunca boya akar:
# boyalı parça ile `dye_target` (hemen altındaki/arkasındaki parça) RENK DEĞİŞTİRİR.
# Neden takas: hedefi yalnızca boyamak renk sayılarını bozar (bir renkte 4, diğerinde 2 parça
# kalır) ve kuyruk 3'ün katıyla eşleşmez -> seviye kesin kazanılamaz olurdu. Takasla her
# rengin parça sayısı aynı kalır; boya akması bir ceza (sıra bozulur), asla çıkmaz yol değildir.
# Akan boya bir kez akar (sayaç 0'da kalır). Askıya alınan boyalı parça sayılmaz (etkisizleşir).

func dye_left(id: int) -> int:
	return int((_items.get(id, {}) as Dictionary).get("dye", 0))


func is_dye(id: int) -> bool:
	return (_items.get(id, {}) as Dictionary).has("dye")


func dye_target(id: int) -> int:
	return int((_items.get(id, {}) as Dictionary).get("dye_target", EMPTY))


## Çözücü anahtarı ve görünüm için: [kimlik, kalan, renk, hedef rengi] dörtlüleri.
func dye_state() -> Array[int]:
	var result: Array[int] = []
	for id: int in _dye_ids:
		result.append_array([id, dye_left(id), color_of(id), color_of(dye_target(id))])
	return result


func _open_dyes() -> Array[int]:
	var result: Array[int] = []
	for id: int in _dye_ids:
		if dye_left(id) > 0 and is_open(id) and not is_locked(id):
			result.append(id)
	return result


## Döndürür: bu hamlede boya aktı mı.
func _tick_dyes(ticking: Array[int], events: Array[Dictionary]) -> bool:
	var bled: bool = false
	for id: int in ticking:
		if not _on_line.has(id):
			continue
		var left: int = dye_left(id) - 1
		(_items[id] as Dictionary)["dye"] = left
		events.append({"type": EVENT_DYE_TICK, "id": id, "left": left})
		if left <= 0:
			bled = _bleed(id, events) or bled
	return bled


func _bleed(id: int, events: Array[Dictionary]) -> bool:
	var target: int = dye_target(id)
	if target == EMPTY or not _on_line.has(target):
		return false
	var own: int = color_of(id)
	var other: int = color_of(target)
	if own == other:
		return false
	(_items[id] as Dictionary)["color"] = other
	(_items[target] as Dictionary)["color"] = own
	events.append({"type": EVENT_DYE_BLEED, "id": id, "target": target, "color": other, "target_color": own})
	return true


# --- Geri al geçmişi ------------------------------------------------------------------------

func enable_history() -> void:
	_history_enabled = true


func can_undo() -> bool:
	return _history_enabled and not _history.is_empty() and not _won


## Son durum değiştiren dokunuşu tümüyle geri alır (ip, askı, sepetler, kuyruk, sayaçlar).
## Askı slot SAYISI korunur: "+1 askı" ödülü/güçlendiricisi geri alınmamalı.
func undo() -> bool:
	if not can_undo():
		return false
	var snap: Dictionary = _history.pop_back()
	var saved: Dictionary = snap["items"] as Dictionary
	for id: Variant in saved.keys():
		_items[id] = (saved[id] as Dictionary).duplicate()
	_on_line = (snap["on_line"] as Dictionary).duplicate()
	var slots: int = _rack.size()
	_rack.assign(snap["rack"] as Array)
	while _rack.size() < slots:
		_rack.append(EMPTY)
	_baskets.assign((snap["baskets"] as Array).duplicate(true))
	_basket_ids.assign((snap["basket_ids"] as Array).duplicate(true))
	_queue.assign(snap["queue"] as Array)
	_won = bool(snap["won"])
	_lost = bool(snap["lost"])
	_moves = int(snap["moves"])
	_completed = (snap["completed"] as Dictionary).duplicate()
	_sock_waiting = int(snap["sock_waiting"])
	_stuck = (snap["stuck"] as Dictionary).duplicate()
	return true


func history_size() -> int:
	return _history.size()


func basket_contents(index: int) -> Array[int]:
	var result: Array[int] = []
	if index >= 0 and index < _basket_ids.size():
		for id: Variant in _basket_ids[index]:
			result.append(int(id))
	return result


func _record_history() -> void:
	if not _history_enabled:
		return
	var saved: Dictionary = {}
	for id: int in _mutable_ids:
		saved[id] = (_items[id] as Dictionary).duplicate()
	_history.append({
		"items": saved, "on_line": _on_line.duplicate(), "rack": _rack.duplicate(),
		"baskets": baskets(), "basket_ids": _basket_ids.duplicate(true), "queue": _queue.duplicate(),
		"won": _won, "lost": _lost, "moves": _moves, "completed": _completed.duplicate(),
		"sock_waiting": _sock_waiting, "stuck": _stuck.duplicate(),
	})


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
			_complete_color(int(basket["color"]), events)
			_baskets[index] = _next_basket()
			_basket_ids[index] = []
			var fresh: Dictionary = _baskets[index]
			if not fresh.is_empty():
				events.append({"type": EVENT_BASKET_NEW, "basket": index, "color": int(fresh["color"])})
			changed = true
		for slot: int in range(_rack.size()):
			var id: int = _rack[slot]
			if id == EMPTY or _stuck.has(id):
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
	elif _free_rack_slot() == EMPTY and not has_basket_move():
		# Askının dolması tek başına kayıp değildir: dört slot da kullanılabilir. Kayıp, askı
		# doluyken sepete gidebilecek hiçbir açık çamaşır kalmadığında olur (hamle yok).
		_lost = true
		events.append({"type": EVENT_LOSE, "remaining": _on_line.size() + rack_count()})


func _complete_color(color: int, events: Array[Dictionary]) -> void:
	if _completed.has(color):
		return
	_completed[color] = true
	for id: int in item_ids():
		if _on_line.has(id) and lock_color(id) == color:
			events.append({"type": EVENT_UNLOCK, "id": id})


## Aktif bir sepete doğrudan gidebilecek açık ve kilitsiz bir çamaşır var mı?
func has_basket_move() -> bool:
	for id: int in open_ids():
		if _basket_for(color_of(id)) != EMPTY:
			return true
	return false


func _put_in_basket(id: int, basket_index: int, event_type: String,
		events: Array[Dictionary], from_slot: int = EMPTY) -> void:
	var basket: Dictionary = _baskets[basket_index]
	var position: int = int(basket["count"])
	basket["count"] = position + 1
	_basket_ids[basket_index].append(id)
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
