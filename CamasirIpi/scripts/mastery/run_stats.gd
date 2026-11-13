class_name RunStats
extends RefCounted

## Bir seviye denemesinin USTALIK istatistikleri (saf mantık; sahne/ses/dosya yok).
## Tahtanın her dokunuşta verdiği olay listesi `record_tap` ile verilir; sayılar buradan çıkar.
## Neden olay listesinden: kuralları (laundry_board.gd) bilmek zorunda kalmadan, tahtanın
## söylediğini sayarız; kurallar değişse de bu sınıf bozulmaz.
##
## ZİNCİR (chain) tanımı — tek doğruluk kaynağı (ses perdesi, HUD hapı, jeton bonusu bunu okur):
##  * "Etkin dokunuş": reddedilmeyen dokunuş (engelli / kilitli / askı dolu OLMAYAN).
##  * Bir sepet tamamlandığında, önceki tamamlanma en çok `chain_window_taps` etkin dokunuş
##    önce olduysa zincir 1 artar; değilse zincir 1'den yeniden başlar.
##  * Aynı dokunuşta birden çok sepet tamamlanırsa (askıdan otomatik geçiş) aralık 0'dır: zincir sürer.
##  * Pencere, tamamlanmadan SONRAKİ etkin dokunuşlardan sayılır; pencere dolunca ilk aşan
##    dokunuşta zincir kopar (`record_tap` kopan zincirin uzunluğunu döndürür).

const DEFAULT_WINDOW_TAPS: int = 6
## Zincir hapında/bonusta "zincir" sayılmaya başlayan en küçük uzunluk (tek sepet zincir değildir).
const MIN_VISIBLE_CHAIN: int = 2
## Olay sözlüğüne yazılan anahtar: o sepet tamamlanırken zincirin kaçıncı adımı olduğu.
const EVENT_CHAIN_KEY: String = "chain"
## Oyun katmanının zincir kopunca kuyruğa eklediği yapay olay türü.
const EVENT_CHAIN_BREAK: String = "chain_break"

var taps: int = 0
## Askıya giden toplam çamaşır sayısı (aynı çamaşır bir kez sayılır).
var rack_total: int = 0
var rack_max: int = 0
var baskets_done: int = 0
var best_chain: int = 0
var boosters_used: int = 0
var revived: bool = false

var _window_taps: int = DEFAULT_WINDOW_TAPS
var _rack_fill: int = 0
var _chain: int = 0
var _last_done_tap: int = 0


func _init(window_taps: int = DEFAULT_WINDOW_TAPS) -> void:
	_window_taps = maxi(window_taps, 0)


## Denge tablosundan (balance.json -> "mastery" -> chain_window_taps) kurar.
static func from_balance(balance: Dictionary) -> RunStats:
	var window: int = ProgressData.to_count(
		StarRating.section(balance).get("chain_window_taps"), DEFAULT_WINDOW_TAPS)
	return RunStats.new(window)


func reset() -> void:
	taps = 0
	rack_total = 0
	rack_max = 0
	baskets_done = 0
	best_chain = 0
	boosters_used = 0
	revived = false
	_rack_fill = 0
	_chain = 0
	_last_done_tap = 0


## Şu anki (açık) zincir uzunluğu; kopmuşsa 0.
func chain() -> int:
	return _chain


## Bir dokunuşun olaylarını işler. Dönen: bu dokunuşla KOPAN zincirin uzunluğu (kopmadıysa 0).
## Bir sepet tamamlanma olayına `EVENT_CHAIN_KEY` yazılır (animasyon kuyruğu aynı değeri okur).
func record_tap(events: Array[Dictionary]) -> int:
	if events.is_empty() or not _is_effective(events):
		return 0
	taps += 1
	var broken: int = 0
	if _chain > 0 and taps - _last_done_tap > _window_taps:
		broken = _chain
		_chain = 0
	for event: Dictionary in events:
		match String(event.get("type", "")):
			LaundryBoard.EVENT_TO_RACK:
				_rack_fill += 1
				rack_total += 1
				rack_max = maxi(rack_max, _rack_fill)
			LaundryBoard.EVENT_RACK_TO_BASKET:
				_rack_fill = maxi(_rack_fill - 1, 0)
			LaundryBoard.EVENT_BASKET_DONE:
				baskets_done += 1
				_chain += 1
				_last_done_tap = taps
				best_chain = maxi(best_chain, _chain)
				event[EVENT_CHAIN_KEY] = _chain
	return broken


func note_booster() -> void:
	boosters_used += 1


func note_revive() -> void:
	revived = true


## Reddedilen dokunuşlar (engelli, kilitli, askı dolu) hamle sayılmaz; tahta da saymaz.
static func _is_effective(events: Array[Dictionary]) -> bool:
	var first: String = String(events[0].get("type", ""))
	return first != LaundryBoard.EVENT_BLOCKED and first != LaundryBoard.EVENT_LOCKED \
		and first != LaundryBoard.EVENT_RACK_FULL
