class_name DayRun
extends RefCounted
## Gün testinin saf zaman çizelgesi (aşama 3). `PrizBoard.start_day()` olay listesini zamanlı adımlara
## çevirir; sahne her karede `advance(delta)` çağırır ve dönen adımları SIRAYLA canlandırır. Kural kararı
## vermez, olay eklemez/çıkarmaz: yalnız "ne zaman" sorusunu yanıtlar. Sahnesiz, autoload'suz, birim testli.
##
##   var run := DayRun.new(board.start_day())
##   func _process(dt): for step in run.advance(dt): _apply(step)
##   run.fast_forward()   # dokunuş: dilimler hızlanır; sigorta atması hep gerçek hızda
##   run.pause() / run.resume()
##
## Zamanlama (saniye, hız 1): giriş LEAD, her dilim SLICE_SECONDS; dilim içinde susan cihazlar, açılan
## cihazlar (kademeli), hat yükleri, sınır uyarısı, varsa sigorta. Sigortadan sonra BLOW_SECONDS'lık
## karanlık + "neden" sahnesi, sonra plana dönüş ya da kayıp. Dört temiz dilimde gün ~8 sn.

const LEAD: float = 0.75
const SLICE_SECONDS: float = 1.75
const OFF_AT: float = 0.12
const OFF_STEP: float = 0.07
const ON_AT: float = 0.32
const ON_STEP: float = 0.12
const LOAD_AT: float = 0.6
const NEAR_AT: float = 0.85
const BLOW_AT: float = 1.15
## Sigorta "çat" → karanlık → sessizlik → plan ışığında dönüş.
const BLOW_SECONDS: float = 2.7
const SURVIVE_AFTER: float = 0.1
const WIN_AFTER: float = 0.35
const FAST_SPEED: float = 3.0
## Uzun kare (uygulama arka plandan döndü) zaman çizelgesini atlatmasın.
const MAX_STEP: float = 0.1


## Zamanlı adım: olay + çizelgedeki zamanı.
class Step:
	var time: float = 0.0
	var event: PrizEvent
	var index: int = 0

	func _init(t: float, e: PrizEvent, i: int) -> void:
		time = t
		event = e
		index = i


var steps: Array[Step] = []
## Çizelge zamanı (hızlandırma dahil).
var clock: float = 0.0
var speed: float = 1.0
var _next: int = 0
var _paused: bool = false
var _fast: bool = false
## İlk sigorta adımının zamanı (yoksa INF): hızlandırma bu noktada biter.
var _blow_time: float = INF


func _init(events: Array[PrizEvent]) -> void:
	var slice_start: float = 0.0
	var off_i: int = 0
	var on_i: int = 0
	var blow_t: float = -1.0
	for e: PrizEvent in events:
		var t: float = 0.0
		match e.type:
			PrizEvent.DAY_START:
				t = 0.0
			PrizEvent.SLICE_BEGIN:
				slice_start = LEAD + float(e.slice) * SLICE_SECONDS
				off_i = 0
				on_i = 0
				t = slice_start
			PrizEvent.DEVICE_OFF:
				t = slice_start + OFF_AT + OFF_STEP * float(off_i)
				off_i += 1
			PrizEvent.DEVICE_ON:
				t = slice_start + ON_AT + ON_STEP * float(on_i)
				on_i += 1
			PrizEvent.LINE_LOAD:
				t = slice_start + LOAD_AT
			PrizEvent.LINE_NEAR_LIMIT:
				t = slice_start + NEAR_AT
			PrizEvent.FUSE_BLOWN:
				t = slice_start + BLOW_AT
				blow_t = t
				_blow_time = minf(_blow_time, t)
			PrizEvent.BACK_TO_PLANNING, PrizEvent.LOSE:
				t = maxf(blow_t, slice_start + BLOW_AT) + BLOW_SECONDS
			PrizEvent.DAY_SURVIVED:
				t = LEAD + float(PrizSlice.COUNT) * SLICE_SECONDS + SURVIVE_AFTER
			PrizEvent.WIN:
				t = LEAD + float(PrizSlice.COUNT) * SLICE_SECONDS + SURVIVE_AFTER + WIN_AFTER
			_:
				t = slice_start
		# Çizelge olay sırasını asla bozmaz (aynı zamanda gelenler liste sırasıyla).
		if not steps.is_empty():
			t = maxf(t, steps[steps.size() - 1].time)
		steps.append(Step.new(t, e, steps.size()))


## Zamanı ilerletir; zamanı gelmiş adımları sırayla döner. Duraklatılmışsa boş.
func advance(delta: float) -> Array[Step]:
	var due: Array[Step] = []
	if _paused or is_finished():
		return due
	var dt: float = clampf(delta, 0.0, MAX_STEP)
	var target: float = clock + dt * speed
	# Hızlandırma sigortada biter: o andan sonrası gerçek hız (dram ve "neden" okunur).
	if _fast and target >= _blow_time:
		var before: float = maxf(_blow_time - clock, 0.0) / speed
		target = _blow_time + maxf(dt - before, 0.0)
		_fast = false
		speed = 1.0
	clock = target
	while _next < steps.size() and steps[_next].time <= clock + 0.00001:
		due.append(steps[_next])
		_next += 1
	return due


## Dokunuş: kalan dilimler hızlanır (sigortaya kadar). Sigortadan sonra etkisiz.
func fast_forward() -> void:
	if is_finished() or clock >= _blow_time:
		return
	_fast = true
	speed = FAST_SPEED


func is_fast() -> bool:
	return _fast


func pause() -> void:
	_paused = true


func resume() -> void:
	_paused = false


func is_paused() -> bool:
	return _paused


func is_finished() -> bool:
	return _next >= steps.size()


## Toplam süre (hız 1).
func duration() -> float:
	return steps[steps.size() - 1].time if not steps.is_empty() else 0.0


## Sonuç: &"win", &"back_to_planning", &"lose" ya da &"" (boş liste).
func outcome() -> StringName:
	for i: int in range(steps.size() - 1, -1, -1):
		var t: StringName = steps[i].event.type
		if t == PrizEvent.WIN or t == PrizEvent.BACK_TO_PLANNING or t == PrizEvent.LOSE:
			return t
	return &""


## Şu an oynanan dilim (-1 = gün başlamadı / giriş).
func current_slice() -> int:
	var s: int = -1
	for i: int in range(_next):
		if steps[i].event.type == PrizEvent.SLICE_BEGIN:
			s = steps[i].event.slice
	return s


## Sigortanın attığı dilim (-1 = atmadı).
func blow_slice() -> int:
	for step: Step in steps:
		if step.event.type == PrizEvent.FUSE_BLOWN:
			return step.event.slice
	return -1


## Sigortası atan hatların kimlikleri (aynı dilimde birden çok olabilir).
func blown_lines() -> Array[String]:
	var result: Array[String] = []
	for step: Step in steps:
		if step.event.type == PrizEvent.FUSE_BLOWN and not result.has(step.event.line_id):
			result.append(step.event.line_id)
	return result


## Hızlandırma süre katsayısı: sahne geçiş sürelerini buna böler.
func time_scale() -> float:
	return speed
