class_name Shift
extends RefCounted
## Bir günlük vardiya durum makinesi (arayüzsüz; zaman dışarıdan `advance(saniye)` ile ilerler).
##
## Akış: start() -> müşteri gelir (current/current_verdict) -> oyuncu submit(move) -> kısa bekleme -> sonraki müşteri...
## Süre dolunca ekrandaki müşteri bitirilir (CLOSING), yeni müşteri gelmez (CLOSED).
## Oyun saati open_minute..close_minute arasında, shift_seconds gerçek saniyede akar. Saat 13:00'ü geçince kurlar güncellenir
## (R_MIDDAY_RATE açıksa); müşterinin hükmü GELDİĞİ andaki kurla hesaplanır.
## Hata sayımı İŞLEM başınadır: ilk free_mistakes hatalı işlem uyarıdır, sonrakilerde ceza kesilir.

const PHASE_NOT_STARTED := "not_started"
const PHASE_OPEN := "open"
const PHASE_CLOSING := "closing"
const PHASE_CLOSED := "closed"

const MISTAKE_TILL_SHORT := "till_short"

var ctx: DayContext
var customers: CustomerFactory
var engine: RuleEngine
var phase := PHASE_NOT_STARTED
var elapsed := 0.0
var current: Customer = null
var current_verdict: Verdict = null
## Patronun işlem başı kesinti önerisi kabul edildiyse bu tutar (kuruş), aksi halde 0.
var skim_minor := 0
## Hikaye yönetmeni (yoksa hikaye olayı çıkmaz). Career.new_shift hikaye açıksa doldurur.
var director: StoryDirector = null
## Oyuncuya gösterilmeyi bekleyen hikaye olayı (boşsa yok). Çözülene dek zaman ilerlemez.
var pending_beat: Dictionary = {}
## Sabit müşteri sırası (Günün Kuru): `use_queue` açıkken müşteriler sırayla buradan gelir, sıra bitince vardiya kapanır.
var queue: Array[Customer] = []
var use_queue := false

## Merkez talimatı (boşsa yok) ve gün içinde tüple gelecek notların planı; gelenler `memos_delivered`ta (okundu bayrağıyla).
var directive: Dictionary = {}
var memo_plan: Array[Dictionary] = []
var memos_delivered: Array[Dictionary] = []
var memo_salt := "story"
## Vardiya başındaki çalıntı aralığı sayısı; sonrakiler tüple gelen acil bültenlerdir (kılavuzda "YENİ" işaretlenir).
var initial_stolen_count := 0

var shift_seconds := 270.0
var stats := {
	"rejects": 0, "polices": 0, "completes": 0, "call_mood": 0, "call_kind": 0,
	"served": 0, "correct": 0, "mistake_transactions": 0, "free_used": 0, "fined": 0,
	"fines_minor": 0, "bonus_minor": 0, "skim_minor": 0, "skim_count": 0, "overtime_seconds": 0, "story_minor": 0,
}
var entries: Array[Dictionary] = []

var _wait := 0.0


func _init(context: DayContext, customer_factory: CustomerFactory) -> void:
	ctx = context
	customers = customer_factory
	engine = RuleEngine.new(context)
	shift_seconds = float(_cfg("shift_seconds", 270))
	initial_stolen_count = ctx.bulletin.stolen_ranges.size()


func _cfg(key: String, fallback: Variant) -> Variant:
	return JsonIO.get_path_value(ctx.balance, "shift.%s" % key, fallback)


func start() -> void:
	phase = PHASE_OPEN
	elapsed = 0.0
	_update_clock()
	_spawn()


## Sırası gelen notları teslim eder (tüp düşer): bülten/talimat o anda değişir.
func _deliver_due_memos() -> void:
	while not memo_plan.is_empty() and int(memo_plan[0]["at_served"]) <= int(stats["served"]):
		memos_delivered.append(OfficeMemos.deliver(memo_plan.pop_front(), self, memo_salt))


## Okunmamış not sayısı.
func unread_memos() -> int:
	var count := 0
	for memo in memos_delivered:
		if not bool(memo["read"]):
			count += 1
	return count


## Telefon notuna cevap verir (seçenek: para, aile ruh hali, iyilik). Dönen: uygulandı mı (zaten cevaplanmışsa false).
func answer_call(memo_id: String, option_id: String) -> bool:
	for memo in memos_delivered:
		if str(memo["id"]) != memo_id or str(memo["kind"]) != "call" or not str(memo["answered"]).is_empty():
			continue
		for option: Dictionary in memo["options"]:
			if str(option["id"]) == option_id:
				stats["story_minor"] += Money.units(int(option["cash_pl"]))
				stats["call_mood"] += int(option["mood"])
				stats["call_kind"] += int(option["kind"])
				memo["answered"] = option_id
				memo["read"] = true
				return true
	return false


func missed_calls() -> int:
	var count := 0
	for memo in memos_delivered:
		if str(memo["kind"]) == "call" and str(memo["answered"]).is_empty():
			count += 1
	return count


func mark_memo_read(memo_id: String) -> void:
	for memo in memos_delivered:
		if str(memo["id"]) == memo_id:
			memo["read"] = true


func is_closed() -> bool:
	return phase == PHASE_CLOSED


## Oyun saati (dakika, gün başından): 09:00 = 540.
func clock_minutes() -> int:
	var open_minute := int(_cfg("open_minute", 540))
	var close_minute := int(_cfg("close_minute", 1020))
	var span := close_minute - open_minute
	return open_minute + mini(span, int(elapsed / shift_seconds * span))


func clock_text() -> String:
	var minutes := clock_minutes()
	return "%02d:%02d" % [minutes / 60, minutes % 60]


## Kalan gerçek süre (sn); 0'ın altına inmez.
func seconds_left() -> float:
	return maxf(0.0, shift_seconds - elapsed)


## Vardiyayı hemen bitirir (Sonsuz'da canlar tükenince).
func end_now() -> void:
	current = null
	current_verdict = null
	pending_beat = {}
	phase = PHASE_CLOSED


## end_now sonrası vardiyayı yeniden açar (Sonsuz'da "devam et" ödülü); sıradaki müşteri hemen gelir.
func resume_open() -> void:
	if phase == PHASE_CLOSED:
		phase = PHASE_OPEN
		_wait = 0.0


## Ödüllü reklamla mesai uzatma (plan 2.6 `overtime`).
func extend_time(seconds: float) -> void:
	shift_seconds += seconds
	stats["overtime_seconds"] += int(seconds)
	if phase == PHASE_CLOSING:
		phase = PHASE_OPEN
	elif phase == PHASE_CLOSED and current == null:
		phase = PHASE_OPEN
		_wait = 0.0


func advance(seconds: float) -> void:
	if phase == PHASE_NOT_STARTED or phase == PHASE_CLOSED or not pending_beat.is_empty():
		return
	elapsed += seconds
	_update_clock()
	if current != null:
		if elapsed >= shift_seconds:
			phase = PHASE_CLOSING
		return
	if elapsed >= shift_seconds:
		phase = PHASE_CLOSED
		return
	_wait -= seconds
	if _wait <= 0.0:
		_spawn()


## Oyuncunun hamlesini işler. Dönen sözlük: {ok, correct, mistakes, fined, fine_minor, bonus_minor, skimmed_minor}.
func submit(move: PlayerMove) -> Dictionary:
	if current == null:
		return {"ok": false, "error": "no_customer"}
	if not pending_beat.is_empty():
		resolve_beat(director.pick_option(pending_beat, []))
	var mistakes := Verdict.compare(current_verdict, move)
	var skimmed := _skimmed_amount(mistakes, move)
	if skimmed > 0:
		mistakes.clear()
	if not ctx.till.apply_move(current, move):
		mistakes.append({"type": MISTAKE_TILL_SHORT})
	stats["served"] += 1
	match move.decision:
		Verdict.DECISION_REJECT:
			stats["rejects"] += 1
		Verdict.DECISION_POLICE:
			stats["polices"] += 1
		Verdict.DECISION_COMPLETE:
			stats["completes"] += 1
	var result := {"ok": true, "correct": mistakes.is_empty(), "mistakes": mistakes, "fined": false,
		"fine_minor": 0, "bonus_minor": 0, "skimmed_minor": skimmed}
	if skimmed > 0:
		stats["skim_minor"] += skimmed
		stats["skim_count"] += 1
	if mistakes.is_empty():
		stats["correct"] += 1
		result["bonus_minor"] = Money.units(int(_cfg("bonus_pl", 15)))
		stats["bonus_minor"] += int(result["bonus_minor"])
	else:
		stats["mistake_transactions"] += 1
		if int(stats["mistake_transactions"]) > int(_cfg("free_mistakes", 2)):
			result["fined"] = true
			result["fine_minor"] = Money.units(int(_cfg("fine_pl", 30)))
			stats["fined"] += 1
			stats["fines_minor"] += int(result["fine_minor"])
		else:
			stats["free_used"] += 1
	if director != null and not current.beat_id.is_empty():
		stats["story_minor"] += director.on_decision(current.beat_id, move.decision)
	entries.append({"customer": current.id, "scenario": current.scenario, "expected": current_verdict.decision,
		"got": move.decision, "mistakes": mistakes.duplicate(), "fined": result["fined"]})
	current = null
	current_verdict = null
	_wait = float(_cfg("arrival_gap_seconds", 2))
	if elapsed >= shift_seconds or (use_queue and queue.is_empty()):
		phase = PHASE_CLOSED
	return result


## Günün özeti (akşam ekranı ve maaş hesabı bunu kullanır).
func report() -> Dictionary:
	var base := Money.units(int(_cfg("base_salary_pl", 380)))
	var directive_minor := Directives.result_minor(directive, stats) if is_closed() else 0
	var net := maxi(0, base + int(stats["bonus_minor"]) - int(stats["fines_minor"]) + directive_minor)
	var data := stats.duplicate()
	data["calls_missed"] = missed_calls()
	data["directive_minor"] = directive_minor
	data["directive_id"] = str(directive.get("id", ""))
	data["directive_met"] = not directive.is_empty() and bool(Directives.status(directive, stats)["met"])
	data["base_minor"] = base
	data["net_minor"] = net
	data["elapsed"] = elapsed
	return data


func _spawn() -> void:
	pending_beat = {}
	current = null
	_deliver_due_memos()
	if use_queue:
		if queue.is_empty():
			current_verdict = null
			phase = PHASE_CLOSED
			return
		current = queue.pop_front()
		current_verdict = engine.evaluate(current)
		return
	if director != null:
		var beat := director.next_beat(int(stats["served"]))
		if not beat.is_empty():
			pending_beat = beat
			current = director.build_customer(beat, ctx)
	if current == null:
		current = customers.make_random()
	current_verdict = engine.evaluate(current)


## Bekleyen hikaye olayını çözer: seçim varsa `option_id` uygulanır (uygun değilse false ve olay bekler),
## yoksa olayın kendi etkileri işler. Dönen: çözüldü mü.
func resolve_beat(option_id := "") -> bool:
	if pending_beat.is_empty() or director == null:
		return false
	var beat := pending_beat
	if director.has_choice(beat):
		var outcome := director.choose(beat, option_id)
		if not bool(outcome["ok"]):
			return false
		stats["story_minor"] += int(outcome["story_minor"])
	else:
		stats["story_minor"] += director.resolve_plain(beat)
	pending_beat = {}
	skim_minor = maxi(skim_minor, director.skim_minor())
	if not beat.has("customer"):  # müşterisiz olay (radyo, patron): aynı müşteriden önce sıradaki olay da konuşabilir
		var chained := director.next_beat(int(stats["served"]))
		if not chained.is_empty():
			pending_beat = chained
			var scripted := director.build_customer(chained, ctx)
			if scripted != null:
				current = scripted
				current_verdict = engine.evaluate(current)
	return true


func _update_clock() -> void:
	ctx.midday = clock_minutes() >= 13 * 60


## Hatalar yalnızca "PL'yi tam kesinti kadar eksik ödedi" ise (ve kesinti açıksa) gizli kâr sayılır.
func _skimmed_amount(mistakes: Array[Dictionary], move: PlayerMove) -> int:
	if skim_minor <= 0 or mistakes.size() != 1 or current_verdict.decision != Verdict.DECISION_COMPLETE:
		return 0
	var mistake := mistakes[0]
	if mistake["type"] == Verdict.MISTAKE_UNDERPAID and mistake["code"] == ctx.book.local_code and int(mistake["delta"]) == -skim_minor:
		return skim_minor
	return 0
