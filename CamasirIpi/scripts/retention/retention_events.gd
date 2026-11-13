class_name RetentionEvents
extends RefCounted

## Küçük, statik olay yolu. Oyun (game.gd kancaları) ve başka işçilerin özellikleri
## `RetentionEvents.emit("bird_shooed")` gibi çağırır; görev/haftalık sistemleri bunu dinler.
## Neden autoload değil: project.godot'a dokunmadan çalışmalı; yol statiktir, durum `Progress`tadır.
##
## Bilinen olay kimlikleri (başkaları yenisini serbestçe yayınlayabilir; tanınmayan olay
## hiçbir göreve işlemez ve zararsızdır):
##   level_started     {level, daily}
##   level_won         {level, stars, rack_total, rack_max, best_chain, boosters_used, daily}
##   basket_completed  {color, count, chain}          (amount = 1; count = sepetteki çamaşır)
##   daily_won         {}
##   booster_used      (amount = kullanılan sayı)
##   bird_shooed, cat_petted  (başka işçilerin özellikleri)

const LEVEL_STARTED: String = "level_started"
const LEVEL_WON: String = "level_won"
const BASKET_COMPLETED: String = "basket_completed"
const DAILY_WON: String = "daily_won"
const BOOSTER_USED: String = "booster_used"

## Ek dinleyiciler (testler / ileride başka sistemler): f(event_id, amount, data).
static var _listeners: Array[Callable] = []


static func emit(event_id: String, amount: int = 1, data: Dictionary = {}) -> void:
	if event_id.is_empty() or amount <= 0:
		return
	RetentionFlow.handle(event_id, amount, data, RetentionStore.today())
	for listener: Callable in _listeners:
		if listener.is_valid():
			listener.call(event_id, amount, data)


static func add_listener(listener: Callable) -> void:
	if not _listeners.has(listener):
		_listeners.append(listener)


static func clear_listeners() -> void:
	_listeners.clear()


## Bir özellik, olayı daha hiç yayınlamadan "bu olay oyunda var" diyebilir (isteğe bağlı görevler
## ancak olay canlıysa çekilir; ölü bir görev oyuncunun ekranında takılı kalmasın).
static func declare_live(event_id: String) -> void:
	RetentionStore.mark_event_seen(event_id)


## Koşul eşleşmesi (saf): where = {"min": {k: v}, "max": {k: v}, "equals": {k: v}}.
## Veride olmayan anahtar koşulu SAĞLAMAZ (ör. yıldız bilgisi gelmediyse "3 yıldız" sayılmaz).
static func matches(where: Dictionary, data: Dictionary) -> bool:
	var lower: Variant = where.get("min", {})
	if lower is Dictionary:
		for key: Variant in (lower as Dictionary).keys():
			if not data.has(key) or float(data[key]) < float((lower as Dictionary)[key]):
				return false
	var upper: Variant = where.get("max", {})
	if upper is Dictionary:
		for key: Variant in (upper as Dictionary).keys():
			if not data.has(key) or float(data[key]) > float((upper as Dictionary)[key]):
				return false
	var exact: Variant = where.get("equals", {})
	if exact is Dictionary:
		for key: Variant in (exact as Dictionary).keys():
			if not data.has(key) or int(data[key]) != int((exact as Dictionary)[key]):
				return false
	return true


## Bir olayın bir göreve/haftalık temaya kattığı miktar: `amount_key` varsa veriden, yoksa amount.
static func contribution(def: Dictionary, amount: int, data: Dictionary) -> int:
	var key: String = String(def.get("amount_key", ""))
	if key.is_empty():
		return amount
	return maxi(int(data.get(key, 0)), 0)


## Tanım bu olayı dinliyor mu ve koşulu sağlıyor mu.
static func accepts(def: Dictionary, event_id: String, data: Dictionary) -> bool:
	if String(def.get("event", "")) != event_id:
		return false
	var where: Variant = def.get("where", {})
	return matches(where as Dictionary, data) if where is Dictionary else true
