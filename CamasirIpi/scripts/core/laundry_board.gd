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
## Kural çeşitlemeleri (derinleşme 2): joker sepet, büyük sepet, lekeli çamaşır, zincirli mandal,
## rüzgâr; seviye hedefi kipleri: hamle sınırı, kısa askı, sipariş, iki ekranlı patron seviyesi.
## Her birinin kuralı dosyanın sonundaki kendi bölümündedir.

const BASKET_CAPACITY: int = 3
## Büyük sepet 5 parça ister: renk grubunun sayısı da üreticide buna göre 5 olur.
const BIG_BASKET_CAPACITY: int = 5
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
## Joker sepet rengini aldı ({basket, color, swap, swap_color}); swap = kuyrukta rengi değişen
## sepetin sırası (yoksa EMPTY).
const EVENT_JOKER_FIX: String = "joker_fix"
## Lekeli çamaşır askıda kurumaya başladı ({id}) / kurudu, artık normal ({id}).
const EVENT_STAIN_WAIT: String = "stain_wait"
const EVENT_STAIN_DRY: String = "stain_dry"
## Zincirli mandal: alınan parçanın eşi askıya düştü ({id: düşen, by: alınan}); ardından TO_RACK.
const EVENT_CHAIN_DROP: String = "chain_drop"
## Rüzgâr sayacı bir azaldı ({left, id: sıradaki savrulan}) / esti ({id, target, effective, left}).
const EVENT_WIND_TICK: String = "wind_tick"
const EVENT_WIND: String = "wind"
## Sürgülü ip: sayaç tık atar; sıfırlanınca üst sıra bir yana kayar (örtme ilişkileri değişir).
const EVENT_SLIDE_TICK: String = "slide_tick"
const EVENT_SLIDE: String = "slide"
## Sipariş: sıradaki sipariş tamamlandı ({index, color}) / sıra bozuldu ({index}).
const EVENT_ORDER_DONE: String = "order_done"
const EVENT_ORDER_BROKEN: String = "order_broken"
## Patron seviyesi: ilk ekran bitti, ikinci ekran kayarak gelir ({screen}).
const EVENT_SCREEN: String = "screen"
## Boya akıtanın varsayılan geri sayımı (hamle).
const DEFAULT_DYE_MOVES: int = 5
## Durum anahtarında boş (kuyruğu bitmiş) sepet işareti; renkler 0+ olduğundan çakışmaz.
const BASKET_KEY_EMPTY: int = -9

## Seviye hedefi kipleri (`level["mode"]`; bir seviyede en fazla bir kip).
const MODE_NONE: String = ""
const MODE_MOVES: String = "moves"
const MODE_SHORT_RACK: String = "short_rack"
const MODE_ORDERS: String = "orders"
const MODE_BOSS: String = "boss"
## Kayıp nedenleri (`lose_reason`): askı dolu, hamle bitti, (yalnız üretici doğrulamasında) sipariş.
const LOSE_RACK: String = "rack"
const LOSE_MOVES: String = "moves"
const LOSE_ORDER: String = "order"
## Hamle bitince "devam" (+1 askı ödülü) bu kadar hamle de ekler: yalnız askı eklemek
## hamlesi bitmiş oyuncuya hiçbir şey kazandırmazdı.
const MOVE_REVIVE_BONUS: int = 5
## Kuyruk girdisi türleri (`queue_kinds`).
const KIND_NORMAL: int = 0
const KIND_JOKER: int = 1
const KIND_BIG: int = 2

## Çamaşır kimliği -> {color:int, blockers:Array[int], ...yerleşim alanları}.
var _items: Dictionary = {}
## Hâlâ ipte olan çamaşır kimlikleri.
var _on_line: Dictionary = {}
## Askı slotları: çamaşır kimliği ya da EMPTY.
var _rack: Array[int] = []
## Aktif sepetler: {color:int, count:int[, cap, joker, ref]} ya da boş sözlük (kuyruk bitti).
var _baskets: Array[Dictionary] = []
## Sıradaki sepet renkleri ve türleri (aynı hizada).
var _queue: Array[int] = []
var _queue_kinds: Array[int] = []
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
## Kurallar gereği alanı değişebilen parçalar (ıslak, boyalı, boya hedefi, lekeli). Geri al anlık
## görüntüsü yalnız bunları kopyalar: çözücü her düğümde anlık görüntü alır, ucuz olmalı.
var _mutable_ids: Array[int] = []
## Sıralı tüm kimlikler (kurulumda bir kez): çözücü her düğümde parçaları tarar; her seferinde
## sözlük anahtarlarını sıralamak üretimin en pahalı kısmıydı.
var _ids: Array[int] = []
## Kimlik -> sabit kapatanlar (kurulumda bir kez, tipli dizi): sorgularda geçici dizi üretilmez.
var _blockers: Dictionary = {}
## Islak olabilen (başta ıslak) ve kilitli parçalar: sıcak döngüler yalnız bunları tarar.
var _wet_pool: Array[int] = []
var _lock_of: Dictionary = {}
## Askıda kuruyan lekeli parçalar (sonraki hamlede kurur).
var _drying: Dictionary = {}
## Rüzgâr: her `_wind_every` hamlede bir adım; adım = [savrulan, örtülen].
var _wind_every: int = 0
var _wind_steps: Array[Vector2i] = []
var _wind_done: int = 0
var _wind_left: int = 0
## Örtülen kimlik -> [Vector2i(adım, savrulan)]: açıklık sorgusu yalnız bunlara bakar.
var _wind_by_target: Dictionary = {}
## Döngü yaratacağı için boşa esen adımlar (adım -> true); geri alda geri yüklenir.
var _wind_void: Dictionary = {}
## Sürgülü ip: bir ipin üst sırası her `_slide_every` hamlede iki konum arasında gidip gelir.
## Her konum (faz) için "alt parça -> onu örten kayan parçalar" tablosu üretici tarafından verilir;
## kayanların örtmesi sabit `blockers` içinde DEĞİL, yalnız o anki fazda geçerlidir.
var _slide_every: int = 0
var _slide_phases: Array[Dictionary] = []
var _slide_ids: Array[int] = []
var _slide_phase: int = 0
var _slide_left: int = 0
var _has_chains: bool = false
## Kip alanları.
var _mode: String = MODE_NONE
var _move_limit: int = 0
var _orders: Array[int] = []
var _orders_strict: bool = false
var _order_progress: int = 0
var _order_broken: bool = false
var _lose_reason: String = ""
## Patron seviyesi: ikinci ekrandaki parçalar (kimlik -> ekran), görünen ekran.
var _screen_of: Dictionary = {}
var _max_screen: int = 0
var _screen: int = 0

## `level`: {items:[{id,color,blockers,...}], queue:[renk...], active_baskets:int, rack_slots:int}
## İsteğe bağlı: jokers/big (kuyruk sıraları), wind {every, steps}, mode, move_limit, orders.
func _init(level: Dictionary) -> void:
	for entry: Variant in level.get("items", []) as Array:
		var item: Dictionary = (entry as Dictionary).duplicate(true)
		var id: int = int(item.get("id", 0))
		_items[id] = item
		_on_line[id] = true
		var blockers: Array[int] = []
		for blocker: Variant in item.get("blockers", []) as Array:
			blockers.append(int(blocker))
		_blockers[id] = blockers
		if item.has("dye"):
			_dye_ids.append(id)
		if item.has("wet"):
			_wet_pool.append(id)
		if item.has("lock") and int(item["lock"]) != EMPTY:
			_lock_of[id] = int(item["lock"])
		if item.has("wet") or item.has("dye") or item.has("stain"):
			_mutable_ids.append(id)
		if item.has("chain"):
			_has_chains = true
		var screen: int = int(item.get("screen", 0))
		if screen > 0:
			_screen_of[id] = screen
			_max_screen = maxi(_max_screen, screen)
	_dye_ids.sort()
	_wet_pool.sort()
	for id: Variant in _items.keys():
		_ids.append(int(id))
	_ids.sort()
	for id: int in _dye_ids:
		var target: int = dye_target(id)
		if _items.has(target) and not _mutable_ids.has(target):
			_mutable_ids.append(target)
	_mutable_ids.sort()
	var kinds: Dictionary = {}
	for index: Variant in level.get("big", []) as Array:
		kinds[int(index)] = KIND_BIG
	for index: Variant in level.get("jokers", []) as Array:
		kinds[int(index)] = KIND_JOKER
	var position: int = 0
	for color: Variant in level.get("queue", []) as Array:
		_queue.append(int(color))
		_queue_kinds.append(int(kinds.get(position, KIND_NORMAL)))
		position += 1
	_setup_wind(level.get("wind", {}) as Dictionary)
	_setup_slide(level.get("slide", {}) as Dictionary)
	_setup_mode(level)
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
	var entry: Variant = _items.get(id)
	return {} if entry == null else (entry as Dictionary).duplicate(true)


func item_ids() -> Array[int]:
	return _ids.duplicate()


## Parça alanı okuyucu. Neden `get(id)` + null: `get(id, {})` her çağrıda yeni sözlük üretir;
## çözücü bunu düğüm başına yüzlerce kez çağırır.
func _field(id: int, key: String, fallback: Variant) -> Variant:
	var entry: Variant = _items.get(id)
	if entry == null:
		return fallback
	return (entry as Dictionary).get(key, fallback)


func color_of(id: int) -> int:
	return int(_field(id, "color", EMPTY))


func is_on_line(id: int) -> bool:
	return _on_line.has(id)


## Çamaşırı hâlâ kapatan (ipte duran) çamaşırlar; rüzgârla eklenen örtmeler dahil.
func blockers_of(id: int) -> Array[int]:
	var result: Array[int] = []
	var fixed: Variant = _blockers.get(id)
	if fixed != null:
		for blocker: int in fixed as Array[int]:
			if _on_line.has(blocker):
				result.append(blocker)
	if _wind_by_target.has(id):
		for gust: Vector2i in _wind_by_target[id] as Array[Vector2i]:
			if gust.x < _wind_done and not _wind_void.has(gust.x) and _on_line.has(gust.y) \
					and not result.has(gust.y):
				result.append(gust.y)
	if not _slide_phases.is_empty():
		var sliding: Variant = _slide_phases[_slide_phase].get(id)
		if sliding != null:
			for slider: int in sliding as Array[int]:
				if _on_line.has(slider) and not result.has(slider):
					result.append(slider)
	return result


func is_open(id: int) -> bool:
	if not _on_line.has(id):
		return false
	if _max_screen > 0 and int(_screen_of.get(id, 0)) > _screen:
		return false
	# Dizi üretmeden tarama: çözücünün en sık çağırdığı sorgu.
	for blocker: int in _blockers[id] as Array[int]:
		if _on_line.has(blocker):
			return false
	if _wind_by_target.has(id):
		for gust: Vector2i in _wind_by_target[id] as Array[Vector2i]:
			if gust.x < _wind_done and not _wind_void.has(gust.x) and _on_line.has(gust.y):
				return false
	if not _slide_phases.is_empty():
		var sliding: Variant = _slide_phases[_slide_phase].get(id)
		if sliding != null:
			for slider: int in sliding as Array[int]:
				if _on_line.has(slider):
					return false
	return true


## Islak çamaşır: ilk dokunuşta sıkılır, ikincide alınır.
func is_wet(id: int) -> bool:
	return bool(_field(id, "wet", false))


## Gizemli çamaşır: rengi üstü açılınca belli olur (yalnız görünüm; kural aynı).
func is_mystery(id: int) -> bool:
	return bool(_field(id, "mystery", false))


## Kilitli mandalın beklediği sepet rengi; kilit yoksa EMPTY.
func lock_color(id: int) -> int:
	return int(_field(id, "lock", EMPTY))


func is_locked(id: int) -> bool:
	if not _on_line.has(id):
		return false
	var color: int = lock_color(id)
	return color != EMPTY and not _completed.has(color)


func wet_ids() -> Array[int]:
	var result: Array[int] = []
	for id: int in _wet_pool:
		if _on_line.has(id) and bool((_items[id] as Dictionary).get("wet", false)):
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
	# `is_open` + `is_locked` satır içi: GDScript'te işlev çağrısı pahalı, çözücü bunu her düğümde çağırır.
	var result: Array[int] = []
	var screened: bool = _max_screen > 0
	var windy: bool = not _wind_by_target.is_empty()
	for id: int in _ids:
		if not _on_line.has(id):
			continue
		var open: bool = true
		for blocker: int in _blockers[id] as Array[int]:
			if _on_line.has(blocker):
				open = false
				break
		if not open:
			continue
		if _lock_of.has(id) and not _completed.has(_lock_of[id]):
			continue
		if (screened or windy) and not is_open(id):
			continue
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


## Kuyruğun `index`. sepetinin türü; görünüm her karede çizerken dizi kopyası üretmesin diye.
func queue_kind(index: int) -> int:
	return _queue_kinds[index] if index >= 0 and index < _queue_kinds.size() else KIND_NORMAL


## Kuyruktaki sepetlerin türleri (`queue()` ile aynı hizada): KIND_NORMAL / KIND_JOKER / KIND_BIG.
func queue_kinds() -> Array[int]:
	return _queue_kinds.duplicate()


## Kaybedilen seviyede "+1 askı ile devam": yeni boş slot ekler, oyun sürer. Hamle bittiği için
## kaybedildiyse ek hamle de verilir (yalnız askı eklemek o oyuncuyu kurtarmaz).
func add_rack_slot() -> void:
	_rack.append(EMPTY)
	if _lost and _lose_reason == LOSE_MOVES:
		_move_limit = maxi(_move_limit, _moves) + MOVE_REVIVE_BONUS
	_lost = false
	_lose_reason = ""


## Açık çamaşıra dokunuş. Dönen olay listesi sırayla canlandırılır.
func tap(id: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if is_over() or not _on_line.has(id) or is_hidden(id):
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
		var drying_before: Array = [] if _drying.is_empty() else _drying.keys()
		(_items[id] as Dictionary)["wet"] = false
		_moves += 1
		events.append({"type": EVENT_WRING, "id": id})
		# Sıkmak da bir hamledir: boya sayacı, kuruma ve rüzgâr işler. Durum değişirse (boya aktı,
		# leke kurudu, rüzgâr esti) yerleşme ve kayıp denetimi gerekir.
		var changed: bool = _tick_dyes(ticking, events)
		changed = _dry_stains(drying_before, events) or changed
		changed = _wind_tick(events) or changed
		changed = _slide_tick(events) or changed
		if changed:
			_settle(events)
		else:
			_check_move_limit(events)
		return events
	_take(id, events)
	return events


## Parçayı ipten alır (engel/kilit/ıslaklık denetimi çağırana aittir). Askı dolu ve eşleşen
## sepet yoksa alınamaz: EVENT_RACK_FULL eklenir, durum değişmez. Lekeli parça her zaman askıya,
## zincir eşi de askıya düştüğünden gereken boş slot sayısı önceden hesaplanır.
func _take(id: int, events: Array[Dictionary], prefix: Dictionary = {}) -> bool:
	var color: int = color_of(id)
	var stained: bool = is_stained(id)
	var basket_index: int = EMPTY if stained else _basket_for(color)
	var partner: int = chain_partner(id)
	if partner != EMPTY and not _on_line.has(partner):
		partner = EMPTY
	var needed: int = (1 if basket_index == EMPTY else 0) + (1 if partner != EMPTY else 0)
	if needed > 0 and _free_slot_count() < needed:
		# Askıda yer yok: bu parça alınamaz (askı sallanır), oyun sürer.
		events.append({"type": EVENT_RACK_FULL, "id": id})
		return false
	_record_history()
	if not prefix.is_empty():
		events.append(prefix)
	# Sayaç, bu hamleden ÖNCE açık olan boyalılarda işler: hamlenin açtığı boyalı ilk
	# hamlesini kaybetmesin; alınan boyalı da artık ipte olmadığı için sayılmaz.
	var ticking: Array[int] = _open_dyes()
	# Yalnız bu hamleden önce askıda olan lekeliler kurur ("en az bir sonraki hamle").
	var drying_before: Array = [] if _drying.is_empty() else _drying.keys()
	_on_line.erase(id)
	_moves += 1
	if basket_index != EMPTY:
		_put_in_basket(id, basket_index, EVENT_TO_BASKET, events)
	else:
		_hang(id, events)
	if partner != EMPTY:
		_on_line.erase(partner)
		events.append({"type": EVENT_CHAIN_DROP, "id": partner, "by": id})
		_hang(partner, events)
	_apply_sock_rule(id, events)
	_tick_dyes(ticking, events)
	_dry_stains(drying_before, events)
	_wind_tick(events)
	_slide_tick(events)
	_settle(events)
	return true


## Askıya asar; lekeliyse kurumaya başlar.
func _hang(id: int, events: Array[Dictionary]) -> void:
	var slot: int = _free_rack_slot()
	_rack[slot] = id
	events.append({"type": EVENT_TO_RACK, "id": id, "slot": slot})
	if is_stained(id):
		_drying[id] = true
		events.append({"type": EVENT_STAIN_WAIT, "id": id})


## Mandal sökücü (güçlendirici): ipteki herhangi bir parçayı engel, kilit ve ıslaklığa
## bakmadan alır. Askı/sepet kuralı aynıdır (yer yoksa alınamaz). Çorap ve boya kuralları
## normal alım gibi işler; böylece güçlendirici kuralları delmez, yalnız erişimi açar.
func force_take(id: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if is_over() or not _on_line.has(id) or is_hidden(id):
		return events
	var was_wet: bool = is_wet(id)
	if was_wet:
		(_items[id] as Dictionary)["wet"] = false
	if not _take(id, events, {"type": EVENT_PIN_REMOVED, "id": id}) and was_wet:
		(_items[id] as Dictionary)["wet"] = true
	return events


# --- Çarşaf -------------------------------------------------------------------------------
# Çarşaf kuralda sıradan bir parçadır: tek renk, sepette TEK parça sayılır. Farkı yerleşimdedir:
# iki komşu ipe yayılır ve altındaki pek çok parçanın `blockers` listesinde durur; alınınca
# hepsi birden açılır. Bu yüzden ayrı kural/durum gerektirmez.

func is_sheet(id: int) -> bool:
	return bool(_field(id, "sheet", false))


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
	return int(_field(id, "sock", EMPTY))


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
	return int(_field(id, "dye", 0))


func is_dye(id: int) -> bool:
	return _field(id, "dye", null) != null


func dye_target(id: int) -> int:
	return int(_field(id, "dye_target", EMPTY))


## Çözücü anahtarı ve görünüm için: [kimlik, kalan, renk, hedef rengi] dörtlüleri.
func dye_state() -> Array[int]:
	var result: Array[int] = []
	for id: int in _dye_ids:
		result.append_array([id, dye_left(id), color_of(id), color_of(dye_target(id))])
	return result


func _open_dyes() -> Array[int]:
	var result: Array[int] = []
	if _dye_ids.is_empty():
		return result
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
	# Anlık görüntü yığından çıktı, başka kimse tutmuyor: kopyalamadan sahiplenilir (çözücü her
	# düğümde geri alır; çift kopya üretimi belirgin yavaşlatıyordu).
	var snap: Dictionary = _history.pop_back()
	var saved: Dictionary = snap["items"] as Dictionary
	for id: Variant in saved.keys():
		_items[id] = saved[id]
	_on_line = snap["on_line"] as Dictionary
	var slots: int = _rack.size()
	_rack.assign(snap["rack"] as Array)
	while _rack.size() < slots:
		_rack.append(EMPTY)
	_baskets.assign(snap["baskets"] as Array)
	_basket_ids.assign(snap["basket_ids"] as Array)
	_queue.assign(snap["queue"] as Array)
	_queue_kinds.assign(snap["queue_kinds"] as Array)
	_won = bool(snap["won"])
	_lost = bool(snap["lost"])
	_lose_reason = String(snap["lose_reason"])
	_moves = int(snap["moves"])
	_completed = snap["completed"] as Dictionary
	_sock_waiting = int(snap["sock_waiting"])
	_stuck = snap["stuck"] as Dictionary
	_drying = snap["drying"] as Dictionary
	_wind_done = int(snap["wind_done"])
	_wind_left = int(snap["wind_left"])
	_wind_void = snap["wind_void"] as Dictionary
	_slide_phase = int(snap["slide_phase"])
	_slide_left = int(snap["slide_left"])
	_order_progress = int(snap["order_progress"])
	_order_broken = bool(snap["order_broken"])
	_screen = int(snap["screen"])
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
		"queue_kinds": _queue_kinds.duplicate(),
		"won": _won, "lost": _lost, "lose_reason": _lose_reason, "moves": _moves,
		"completed": _completed.duplicate(),
		"sock_waiting": _sock_waiting, "stuck": _stuck.duplicate(), "drying": _drying.duplicate(),
		"wind_done": _wind_done, "wind_left": _wind_left, "wind_void": _wind_void.duplicate(),
		"slide_phase": _slide_phase, "slide_left": _slide_left,
		"order_progress": _order_progress, "order_broken": _order_broken, "screen": _screen,
	})


func _settle(events: Array[Dictionary]) -> void:
	# Dolan sepetler çıkar, yenileri gelir, askıdakiler kendiliğinden geçer; zincirleme sürer.
	var changed: bool = true
	while changed:
		changed = false
		for index: int in range(_baskets.size()):
			var basket: Dictionary = _baskets[index]
			if basket.is_empty() or int(basket["count"]) < _cap(basket):
				continue
			events.append({"type": EVENT_BASKET_DONE, "basket": index, "color": int(basket["color"])})
			_complete_color(int(basket["color"]), events)
			_track_order(int(basket["color"]), events)
			_baskets[index] = _next_basket()
			_basket_ids[index] = []
			var fresh: Dictionary = _baskets[index]
			if not fresh.is_empty():
				var arrival: Dictionary = {"type": EVENT_BASKET_NEW, "basket": index, "color": int(fresh["color"])}
				if _cap(fresh) != BASKET_CAPACITY:
					arrival["cap"] = _cap(fresh)
				if bool(fresh.get("joker", false)):
					arrival["joker"] = true
				events.append(arrival)
			changed = true
		for slot: int in range(_rack.size()):
			var id: int = _rack[slot]
			if id == EMPTY or _stuck.has(id) or _drying.has(id):
				continue
			var target: int = _basket_for(color_of(id))
			if target == EMPTY:
				continue
			_rack[slot] = EMPTY
			_put_in_basket(id, target, EVENT_RACK_TO_BASKET, events, slot)
			changed = true
		# İp boşaldıysa kuruyan lekeliler hemen kurur (artık "sonraki hamle" yok; yoksa son parça
		# lekeliyse seviye ne kazanılır ne kaybedilirdi). Patron seviyesinde ekran geçişi.
		if _on_line.is_empty() and not _drying.is_empty():
			_dry_stains(_drying.keys(), events)
			changed = true
		if _max_screen > 0 and _advance_screen(events):
			changed = true
	if _lost:
		return
	if _on_line.is_empty() and rack_count() == 0:
		_won = true
		events.append({"type": EVENT_WIN})
	elif _free_rack_slot() == EMPTY and not has_basket_move():
		# Askının dolması tek başına kayıp değildir: dört slot da kullanılabilir. Kayıp, askı
		# doluyken sepete gidebilecek hiçbir açık çamaşır kalmadığında olur (hamle yok).
		_lose(LOSE_RACK, events)
	elif _has_chains and _free_slot_count() < 2 and not _any_legal_move():
		# Zincirli parça iki slot isteyebilir: askıda yer olsa bile hiçbir dokunuş işlemeyebilir
		# (en az iki boş slot varsa her açık parça alınabilir; pahalı tarama atlanır).
		_lose(LOSE_RACK, events)
	else:
		_check_move_limit(events)


func _lose(reason: String, events: Array[Dictionary]) -> void:
	_lost = true
	_lose_reason = reason
	events.append({"type": EVENT_LOSE, "remaining": _on_line.size() + rack_count(), "reason": reason})


func _complete_color(color: int, events: Array[Dictionary]) -> void:
	if _completed.has(color):
		return
	_completed[color] = true
	for id: int in _ids:
		if _on_line.has(id) and lock_color(id) == color:
			events.append({"type": EVENT_UNLOCK, "id": id})


## Aktif bir sepete doğrudan gidebilecek açık ve kilitsiz bir çamaşır var mı? (Askı doluyken
## sorulur: lekeli ve ipte eşi duran zincirli parça askı ister, sayılmaz.)
func has_basket_move() -> bool:
	for id: int in open_ids():
		if is_stained(id) or _on_line.has(chain_partner(id)):
			continue
		if _basket_for(color_of(id)) != EMPTY:
			return true
	return false


func _put_in_basket(id: int, basket_index: int, event_type: String,
		events: Array[Dictionary], from_slot: int = EMPTY) -> void:
	var basket: Dictionary = _baskets[basket_index]
	if bool(basket.get("joker", false)) and int(basket["color"]) == EMPTY:
		_fix_joker(basket_index, color_of(id), events)
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
		if int(basket["color"]) == color and int(basket["count"]) < _cap(basket):
			return index
	# Renkli sepet yoksa rengini henüz almamış joker (önce renkli sepet: joker son çaredir).
	for index: int in range(_baskets.size()):
		var basket: Dictionary = _baskets[index]
		if not basket.is_empty() and bool(basket.get("joker", false)) and int(basket["color"]) == EMPTY \
				and joker_accepts(basket, color):
			return index
	return EMPTY


## Bu renkte bir parçayı şu an kabul eden aktif sepet var mı (çözücü sıralaması için).
func accepts(color: int) -> bool:
	return _basket_for(color) != EMPTY


func _cap(basket: Dictionary) -> int:
	return int(basket.get("cap", BASKET_CAPACITY))


func basket_capacity(index: int) -> int:
	if index < 0 or index >= _baskets.size() or _baskets[index].is_empty():
		return BASKET_CAPACITY
	return _cap(_baskets[index])


func _free_rack_slot() -> int:
	for slot: int in range(_rack.size()):
		if _rack[slot] == EMPTY:
			return slot
	return EMPTY


func _free_slot_count() -> int:
	var free: int = 0
	for slot: int in _rack:
		if slot == EMPTY:
			free += 1
	return free


func _next_basket() -> Dictionary:
	if _queue.is_empty():
		return {}
	var color: int = _queue.pop_front()
	var kind: int = _queue_kinds.pop_front()
	match kind:
		KIND_BIG:
			return {"color": color, "count": 0, "cap": BIG_BASKET_CAPACITY}
		KIND_JOKER:
			# `ref`: kuyruktaki asıl renk (üreticinin çözüm yolunda alacağı renk). Joker başka renk
			# alırsa renk sayıları bununla dengelenir (bkz. joker bölümü).
			return {"color": EMPTY, "count": 0, "joker": true, "ref": color}
	return {"color": color, "count": 0}


## Çözücünün "görülen durum" anahtarı: aynı geleceği taşıyan her durum aynı anahtarı üretir.
## Neden paketli tamsayı dizisi: metin biçimlendirme düğüm başına en pahalı işti; sözlük paketli
## diziyi içeriğe göre karşılaştırır. Bölümler uzunlukla ya da ayraçla (BASKET_KEY_EMPTY; kimlik ve
## renkler 0+ olduğundan içerikle çakışmaz) ayrılır -> kodlama birebirdir.
func state_key() -> PackedInt32Array:
	var key: PackedInt32Array = PackedInt32Array()
	key.append(_on_line.size())
	for id: int in _ids:
		if _on_line.has(id):
			key.append(id)
	var rack_colors: Array[int] = []
	for id: int in _rack:
		if id != EMPTY:
			rack_colors.append(int((_items[id] as Dictionary)["color"]))
	rack_colors.sort()
	key.append(rack_colors.size())
	for color: int in rack_colors:
		key.append(color)
	key.append(_baskets.size())
	for basket: Dictionary in _baskets:
		_append_basket_key(key, basket)
	# Kuyruk içeriği: joker başka renk alınca kuyruktaki bir sepetin rengi değişir.
	key.append(_queue.size())
	for color: int in _queue:
		key.append(color)
	key.append(BASKET_KEY_EMPTY)
	for id: int in _wet_pool:
		if _on_line.has(id) and bool((_items[id] as Dictionary).get("wet", false)):
			key.append(id)
	key.append(BASKET_KEY_EMPTY)
	if not _completed.is_empty():
		key.append_array(PackedInt32Array(completed_colors()))
	key.append(BASKET_KEY_EMPTY)
	key.append(_sock_waiting)
	if not _stuck.is_empty():
		key.append_array(PackedInt32Array(stuck_ids()))
	key.append(BASKET_KEY_EMPTY)
	if not _dye_ids.is_empty():
		key.append_array(PackedInt32Array(dye_state()))
	key.append(BASKET_KEY_EMPTY)
	if not _drying.is_empty():
		key.append_array(PackedInt32Array(drying_ids()))
	key.append(BASKET_KEY_EMPTY)
	key.append(_wind_done)
	key.append(_wind_left)
	key.append(_slide_phase)
	key.append(_slide_left)
	key.append(_wind_void.size())
	for step: Variant in _wind_void.keys():
		key.append(int(step))
	key.append(_order_progress)
	key.append(1 if _order_broken else 0)
	key.append(_screen)
	# Hamle sınırlı seviyede aynı dizilim farklı kalan hamleyle farklı gelecektir.
	key.append(_moves if _move_limit > 0 else 0)
	return key


func _append_basket_key(key: PackedInt32Array, basket: Dictionary) -> void:
	if basket.is_empty():
		key.append(BASKET_KEY_EMPTY)
		return
	key.append(int(basket["color"]))
	key.append(int(basket["count"]))
	key.append(_cap(basket))
	key.append(int(basket.get("ref", EMPTY)) if bool(basket.get("joker", false)) else BASKET_KEY_EMPTY)


# --- Joker sepet ----------------------------------------------------------------------------
# Kural: kuyruktan gelen gökkuşağı sepet rengini ilk konan parçadan alır, sonra o renkle
# tamamlanır. Neden kısıt + takas: renk sayıları sabittir (her renk tam sepet sayısı kadar parça).
# Joker `ref` rengi yerine c rengini alırsa c'de bir sepet fazla, ref'te bir sepet eksik kalır ve
# seviye kesin kazanılamazdı. Bu yüzden:
#  - Joker c rengini yalnız c == ref ise ya da kuyrukta bekleyen NORMAL (3'lük) bir c sepeti
#    varsa kabul eder; c'yi alınca kuyruktaki İLK normal c sepeti ref rengine döner (görünür).
#    Böylece her rengin sepet kapasitesi parça sayısına eşit kalır; joker hiçbir zaman çıkmaz yol açmaz.
#  - Önce renkli sepet aranır; joker yalnız eşleşen renkli sepet yoksa devreye girer. Askıdaki
#    parçalar da (slot sırasıyla) jokere kendiliğinden geçebilir: davranış deterministiktir.

func joker_accepts(basket: Dictionary, color: int) -> bool:
	if color == EMPTY:
		return false
	if color == int(basket.get("ref", EMPTY)):
		return true
	for index: int in range(_queue.size()):
		if _queue[index] == color and _queue_kinds[index] == KIND_NORMAL:
			return true
	return false


func is_joker_basket(index: int) -> bool:
	return index >= 0 and index < _baskets.size() and bool(_baskets[index].get("joker", false))


func _fix_joker(index: int, color: int, events: Array[Dictionary]) -> void:
	var basket: Dictionary = _baskets[index]
	var ref: int = int(basket.get("ref", EMPTY))
	basket["color"] = color
	var swap: int = EMPTY
	if color != ref:
		for position: int in range(_queue.size()):
			if _queue[position] == color and _queue_kinds[position] == KIND_NORMAL:
				_queue[position] = ref
				swap = position
				break
	events.append({"type": EVENT_JOKER_FIX, "basket": index, "color": color, "swap": swap, "swap_color": ref})


# --- Lekeli çamaşır -------------------------------------------------------------------------
# Kural: lekeli parça sepete DOĞRUDAN gidemez; alınınca (renk eşleşse bile) askıya asılır ve
# kurumaya başlar. Kendisinden SONRAKİ ilk hamlenin (alma ya da sıkma) sonunda kurur, artık
# sıradan bir parçadır ve uygun sepet varsa kendiliğinden geçer. Askıda yer yoksa alınamaz
# (askı dolu reddi). İpte başka parça kalmadıysa beklenecek hamle olmadığından hemen kurur.

func is_stained(id: int) -> bool:
	return bool(_field(id, "stain", false))


func is_drying(id: int) -> bool:
	return _drying.has(id)


func drying_ids() -> Array[int]:
	var result: Array[int] = []
	for id: Variant in _drying.keys():
		result.append(int(id))
	result.sort()
	return result


## Döndürür: en az bir parça kurudu mu.
func _dry_stains(ids: Array, events: Array[Dictionary]) -> bool:
	var dried: bool = false
	for entry: Variant in ids:
		var id: int = int(entry)
		if not _drying.has(id):
			continue
		_drying.erase(id)
		(_items[id] as Dictionary)["stain"] = false
		events.append({"type": EVENT_STAIN_DRY, "id": id})
		dried = true
	return dried


# --- Zincirli mandal ------------------------------------------------------------------------
# Kural: iki komşu parça tek mandalı paylaşır (`chain` = eşin kimliği, karşılıklı). Biri ipten
# alındığı an diğeri de (üstü kapalı olsa bile) askıya düşer; askıda yer gerekir. Gereken yer
# yoksa dokunuş askı-dolu gibi reddedilir. Düşen parça askıdaki her parça gibi uygun sepete
# kendiliğinden geçer. Dokunulan parça sepete gidebiliyorsa 1, askıya gidecekse 2 slot gerekir.

func chain_partner(id: int) -> int:
	return int(_field(id, "chain", EMPTY))


## Herhangi bir dokunuş durum değiştirebilir mi (zincirli seviyelerde kayıp denetimi).
func _any_legal_move() -> bool:
	var free: int = _free_slot_count()
	for id: int in open_ids():
		if is_wet(id):
			return true
		var needed: int = 1 if is_stained(id) or _basket_for(color_of(id)) == EMPTY else 0
		if _on_line.has(chain_partner(id)):
			needed += 1
		if needed <= free:
			return true
	return false


# --- Rüzgâr ---------------------------------------------------------------------------------
# Kural: görünür bir sayaç her hamlede (alma/sıkma) bir azalır. 0 olunca sıradaki adımın
# "savrulan" parçası komşusunun üstüne kapanır: komşu artık onun tarafından örtülür (yeni bir
# kapatma ilişkisi). Sonra sayaç sonraki adım için yeniden başlar ya da biter. Savrulan ya da
# örtülecek parça o an ipte değilse rüzgâr boşa eser. Döngü (iki parça birbirini örtmesi) asla
# kurulmaz: örtülecek parça savrulanı zaten (dolaylı) örtüyorsa rüzgâr boşa eser. Adımlar ve
# sayaç seviye verisindedir; oyuncu hangi parçanın neyi örteceğini önceden görür.

func _setup_wind(wind: Dictionary) -> void:
	if wind.is_empty():
		return
	_wind_every = maxi(int(wind.get("every", 0)), 1)
	for entry: Variant in wind.get("steps", []) as Array:
		var pair: Array = entry as Array
		if pair.size() < 2:
			continue
		var step: Vector2i = Vector2i(int(pair[0]), int(pair[1]))
		if not _items.has(step.x) or not _items.has(step.y) or step.x == step.y:
			continue
		var index: int = _wind_steps.size()
		_wind_steps.append(step)
		if not _wind_by_target.has(step.y):
			_wind_by_target[step.y] = [] as Array[Vector2i]
		(_wind_by_target[step.y] as Array[Vector2i]).append(Vector2i(index, step.x))
	if not _wind_steps.is_empty():
		_wind_left = _wind_every


## Kalan rüzgâr hamlesi (rüzgâr yoksa/bittiyse -1).
func wind_left() -> int:
	return _wind_left if _wind_done < _wind_steps.size() else -1


## Sıradaki rüzgâr adımı: (savrulan, örtülen); yoksa (-1, -1).
func wind_next() -> Vector2i:
	if _wind_done < _wind_steps.size():
		return _wind_steps[_wind_done]
	return Vector2i(EMPTY, EMPTY)


func wind_steps() -> Array[Vector2i]:
	return _wind_steps.duplicate()


func wind_done() -> int:
	return _wind_done


func wind_every() -> int:
	return _wind_every


## Adım esti ve etkili oldu mu (boşa esmediyse): görünüm yeniden kurulurken savrulmuş çizilir.
func wind_applied(step: int) -> bool:
	return step < _wind_done and not _wind_void.has(step)


func _setup_slide(slide: Dictionary) -> void:
	var phases: Array = slide.get("phases", []) as Array
	if phases.size() < 2:
		return
	_slide_every = maxi(int(slide.get("every", 0)), 1)
	for raw: Variant in phases:
		var phase: Dictionary = {}
		for key: Variant in (raw as Dictionary).keys():
			var covering: Array[int] = []
			for slider: Variant in (raw as Dictionary)[key] as Array:
				covering.append(int(slider))
			# JSON'dan gelen anahtar metin olabilir; kimlikler tamsayıya çevrilir.
			phase[int(key)] = covering
		_slide_phases.append(phase)
	for slider: Variant in slide.get("sliders", []) as Array:
		_slide_ids.append(int(slider))
	_slide_left = _slide_every


## Kaymaya kalan hamle; sürgülü ip yoksa ya da kayan parça kalmadıysa -1.
func slide_left() -> int:
	return _slide_left if _slide_active() else -1


func slide_phase() -> int:
	return _slide_phase


func slide_ids() -> Array[int]:
	return _slide_ids.duplicate()


func _slide_active() -> bool:
	if _slide_phases.is_empty():
		return false
	for slider: int in _slide_ids:
		if _on_line.has(slider):
			return true
	return false


## Döndürür: üst sıra bu hamlede kaydı mı. İki faz arasında gidip gelir (0,1,0,1...).
func _slide_tick(events: Array[Dictionary]) -> bool:
	if not _slide_active():
		return false
	_slide_left -= 1
	if _slide_left > 0:
		events.append({"type": EVENT_SLIDE_TICK, "left": _slide_left})
		return false
	_slide_phase = (_slide_phase + 1) % _slide_phases.size()
	_slide_left = _slide_every
	events.append({"type": EVENT_SLIDE, "phase": _slide_phase, "left": slide_left()})
	return true


## Döndürür: rüzgâr bu hamlede esti mi.
func _wind_tick(events: Array[Dictionary]) -> bool:
	if _wind_done >= _wind_steps.size():
		return false
	_wind_left -= 1
	if _wind_left > 0:
		events.append({"type": EVENT_WIND_TICK, "left": _wind_left, "id": _wind_steps[_wind_done].x})
		return false
	var step: Vector2i = _wind_steps[_wind_done]
	var effective: bool = _on_line.has(step.x) and _on_line.has(step.y) and not _covers(step.y, step.x)
	if not effective:
		# Boşa esen adım kalıcı ilişki kurmasın (sonradan döngü yaratmasın).
		_wind_void[_wind_done] = true
	_wind_done += 1
	_wind_left = _wind_every if _wind_done < _wind_steps.size() else 0
	events.append({"type": EVENT_WIND, "id": step.x, "target": step.y, "effective": effective,
		"left": wind_left()})
	return true


## `top` parçası `bottom`u (dolaylı da olsa) örtüyor mu: ipteki kapatma zinciri taranır.
func _covers(top: int, bottom: int) -> bool:
	var stack: Array[int] = [bottom]
	var seen: Dictionary = {}
	while not stack.is_empty():
		var current: int = stack.pop_back()
		if seen.has(current):
			continue
		seen[current] = true
		for blocker: int in blockers_of(current):
			if blocker == top:
				return true
			stack.append(blocker)
	return false


# --- Seviye hedefi kipleri ------------------------------------------------------------------
# Hamle sınırı: `move_limit` hamlede bitmeli; son hamle kazandırmadıysa "hamle bitti" kaybıdır
# (sayaç sürekli görünür, kayıp sürpriz değildir). Kısa askı: yalnız `rack_slots` (2-3) farklıdır.
# Sipariş: `orders` kuyruk sıralarını gösterir; renkleri kurulumda kuyruktan okunur (günlük
# bulmacanın renk eşlemesi de böylece bozulmaz). İlk tamamlanan sepetler bu renk sırasını
# izlerse bonus kazanılır; sıra bozulursa yalnız bonus kaybolur (kayıp DEĞİL). Üretici kendi
# doğrulamasında `orders_strict` ile bozulmayı kayıp sayar: siparişin yapılabilir olduğu kanıtlanır.
# Patron: parçaların `screen` alanı vardır; ilk ekran ipten tümüyle boşalınca ikinci ekran açılır.
# Askı ve sepetler aynen devam eder.

func _setup_mode(level: Dictionary) -> void:
	_mode = String(level.get("mode", MODE_NONE))
	_move_limit = maxi(int(level.get("move_limit", 0)), 0)
	_orders_strict = bool(level.get("orders_strict", false))
	var queue_colors: Array = level.get("queue", []) as Array
	for index: Variant in level.get("orders", []) as Array:
		var at: int = int(index)
		if at >= 0 and at < queue_colors.size():
			_orders.append(int(queue_colors[at]))


func mode() -> String:
	return _mode


## Kalan hamle; hamle sınırı yoksa -1.
func moves_left() -> int:
	if _move_limit <= 0:
		return -1
	return maxi(_move_limit - _moves, 0)


func move_limit() -> int:
	return _move_limit


func lose_reason() -> String:
	return _lose_reason


func _check_move_limit(events: Array[Dictionary]) -> void:
	if _move_limit > 0 and not _won and not _lost and _moves >= _move_limit:
		_lose(LOSE_MOVES, events)


## Siparişin renk sırası.
func orders() -> Array[int]:
	return _orders.duplicate()


func order_progress() -> int:
	return _order_progress


func order_broken() -> bool:
	return _order_broken


## Puanlama için: bütün siparişler sırasıyla tamamlandı mı.
func order_bonus_earned() -> bool:
	return not _orders.is_empty() and not _order_broken and _order_progress >= _orders.size()


func _track_order(color: int, events: Array[Dictionary]) -> void:
	if _orders.is_empty() or _order_broken or _order_progress >= _orders.size():
		return
	if color == _orders[_order_progress]:
		events.append({"type": EVENT_ORDER_DONE, "index": _order_progress, "color": color})
		_order_progress += 1
		return
	_order_broken = true
	events.append({"type": EVENT_ORDER_BROKEN, "index": _order_progress})
	if _orders_strict:
		_lose(LOSE_ORDER, events)


func screen_of(id: int) -> int:
	return int(_screen_of.get(id, 0))


func current_screen() -> int:
	return _screen


func screen_count() -> int:
	return _max_screen + 1


## Henüz gelmemiş ekrandaki parça: görünmez, dokunulamaz, sökülemez.
func is_hidden(id: int) -> bool:
	return _max_screen > 0 and int(_screen_of.get(id, 0)) > _screen


func _advance_screen(events: Array[Dictionary]) -> bool:
	if _screen >= _max_screen:
		return false
	for id: Variant in _on_line.keys():
		if int(_screen_of.get(id, 0)) <= _screen:
			return false
	_screen += 1
	events.append({"type": EVENT_SCREEN, "screen": _screen})
	return true


## Kazanma sonucunda puanlama sisteminin okuyacağı alanlar (UI'dan bağımsız).
func result_summary() -> Dictionary:
	return {
		"mode": _mode, "moves": _moves, "move_limit": _move_limit, "moves_left": moves_left(),
		"orders_total": _orders.size(), "orders_done": _order_progress,
		"order_bonus_earned": order_bonus_earned(), "boss": _mode == MODE_BOSS,
		"screens": screen_count(), "won": _won, "lose_reason": _lose_reason,
	}
