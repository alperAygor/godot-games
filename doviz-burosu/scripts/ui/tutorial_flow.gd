class_name TutorialFlow
extends RefCounted
## Gün 1 etkileşimli öğreticisinin durum makinesi: saf mantık (düğüm yok, `tr` yok; testlenir). Arayüz (`DeskTutorial`)
## olayları bildirir (`handle`), açık sayfayı söyler (`set_context`) ve `current()` adımını çizer: hangi düğüm
## parlatılacak, hangi tek cümle yazılacak, "Tamam" düğmesi var mı.
##
## Akış (tek müşteri, gerçek masa): istek → banknotu incele → sayfayı kapat → kılavuzda kur → kapat → ödeme fişi →
## tutarı yaz → TAMAMLA damgası → sonuç (doğru / hata ve bedeli) → kapanış. Sıra dışı hamleler bozmaz: yapılan iş
## hatırlanır ve o adım atlanır; karar ne zaman verilirse verilsin sonuç adımına geçilir. Başka bir sayfa açıksa
## "önce bunu kapat" adımı, duraklatma/hikaye sayfasında hiçbir şey gösterilmez (adım korunur).
## Metinler anahtar olarak döner; sayı/para argümanları ham değerdir, arayüz o anki dilde biçimler (dil değişince yeniden çizer).

const EVENT_CUSTOMER := "customer"
const EVENT_INSPECT := "inspect"
const EVENT_RATES := "rates"
const EVENT_NUMPAD := "numpad"
const EVENT_PAID := "paid"
const EVENT_DECIDED := "decided"

## Açık sayfa bağlamı (arayüz bildirir).
const CONTEXT_NONE := ""
const CONTEXT_INSPECT := "inspect"
const CONTEXT_INFO := "info"
const CONTEXT_NUMPAD := "numpad"
const CONTEXT_OTHER := "other"      # kapatılabilir başka bir sayfa (hesap makinesi, katalog...)
const CONTEXT_BLOCKING := "blocking" # duraklatma, hikaye, mesai bitti: öğretici susar

const STEP_WAITING := "waiting"       # uygun müşteri bekleniyor (görünmez)
const STEP_REQUEST := "request"
const STEP_INSPECT := "inspect"
const STEP_INSPECT_CLOSE := "inspect_close"
const STEP_RATES := "rates"
const STEP_RATES_CLOSE := "rates_close"
const STEP_PAY := "pay"
const STEP_PAY_TYPE := "pay_type"
const STEP_STAMP := "stamp"
const STEP_CLOSE_OTHER := "close_other"
const STEP_RESULT := "result"
const STEP_OUTRO := "outro"
const STEP_DONE := "done"
const STEP_HIDDEN := "hidden"         # bağlam engelliyor (duraklatma vb.)

## Sıradaki adımların sabit sırası (ilerleme göstergesi için; "close_other" ve geçici adımlar sayılmaz).
const ORDER := [STEP_REQUEST, STEP_INSPECT, STEP_INSPECT_CLOSE, STEP_RATES, STEP_RATES_CLOSE, STEP_PAY, STEP_PAY_TYPE,
	STEP_STAMP, STEP_RESULT, STEP_OUTRO]

## Adım -> parlatılacak düğüm adı ("" = yok; "@pay" = ödeme düğmesi, "@rate" = kur satırı, arayüz çözer) ve metin anahtarı.
const STEPS := {
	STEP_REQUEST: {"target": "CustomerSpeech", "key": "TUT_REQUEST", "ack": true},
	STEP_INSPECT: {"target": "NoteTile0", "key": "TUT_INSPECT", "ack": false},
	STEP_INSPECT_CLOSE: {"target": "CloseSheetButton", "key": "TUT_INSPECT_CLOSE", "ack": false},
	STEP_RATES: {"target": "ToolBookButton", "key": "TUT_RATES", "ack": false},
	STEP_RATES_CLOSE: {"target": "@rate", "key": "TUT_RATES_CLOSE", "ack": false},
	STEP_PAY: {"target": "@pay", "key": "TUT_PAY", "ack": false},
	STEP_PAY_TYPE: {"target": "NumpadOk", "key": "TUT_PAY_TYPE", "ack": false},
	STEP_STAMP: {"target": "CompleteButton", "key": "TUT_STAMP", "ack": false},
	STEP_CLOSE_OTHER: {"target": "CloseSheetButton", "key": "TUT_CLOSE_OTHER", "ack": false},
	STEP_RESULT: {"target": "Slip", "key": "TUT_RESULT_OK", "ack": true},
	STEP_OUTRO: {"target": "Stamps", "key": "TUT_OUTRO", "ack": true},
}

## Öğretilen müşterinin verileri (arayüz `begin` ile verir): code, amount_minor (müşterinin getirdiği döviz),
## rate (ALIŞ kuru x100), payout_minor (doğru PL ödemesi), local (yerel para kodu).
var lesson := {}
var context := CONTEXT_NONE
var skipped := false

var _acked := {}       # adım -> true ("Tamam"a basıldı)
var _inspected := false
var _rates_seen := false
var _paid_minor := -1  # son yazılan yerel para tutarı (-1 = hiç)
var _decided := false
var _correct := false
var _done := false


## Bu müşteriyle ders verilebilir mi: döviz satan, doğru cevabı TAMAMLA ve yerel para ödemesi olan müşteri.
static func eligible(customer: Customer, verdict: Verdict, local_code: String) -> bool:
	if customer == null or verdict == null:
		return false
	return customer.intent == Customer.INTENT_SELL and verdict.decision == Verdict.DECISION_COMPLETE \
		and int(verdict.pay_out.get(local_code, 0)) > 0 and not customer.notes.is_empty()


func has_lesson() -> bool:
	return not lesson.is_empty()


## Ders müşterisi geldi (bir kez; ikinci çağrı yok sayılır).
func begin(data: Dictionary) -> void:
	if has_lesson() or _done:
		return
	lesson = data.duplicate()


func set_context(value: String) -> void:
	context = value


func is_done() -> bool:
	return _done


## Öğretici ekranda bir şey söylüyor mu (saat bu sürede durur).
func is_active() -> bool:
	return has_lesson() and not _done


func handle(event: String, data := {}) -> void:
	if _done or not has_lesson():
		return
	match event:
		EVENT_INSPECT:
			_inspected = true
		EVENT_RATES:
			_rates_seen = true
		EVENT_PAID:
			if str(data.get("code", "")) == str(lesson.get("local", "")):
				_paid_minor = int(data.get("minor", 0))
		EVENT_DECIDED:
			if not _decided:
				_decided = true
				_correct = bool((data.get("result", {}) as Dictionary).get("correct", false))


## "Tamam" (ya da "Devam"): yalnızca onay adımlarında ilerletir; döner: bir şey değişti mi.
func ack() -> bool:
	var step := current()
	if not bool(STEPS.get(step, {}).get("ack", false)):
		return false
	_acked[step] = true
	if step == STEP_OUTRO:
		_done = true
	return true


func skip() -> void:
	skipped = true
	_done = true


func paid_correctly() -> bool:
	return _paid_minor == int(lesson.get("payout_minor", -2))


func paid_wrong() -> bool:
	return _paid_minor >= 0 and not paid_correctly()


func decided_correctly() -> bool:
	return _decided and _correct


## Şu anki adım (yukarıdaki STEP_* değerlerinden biri).
func current() -> String:
	if _done:
		return STEP_DONE
	if not has_lesson():
		return STEP_WAITING
	if context == CONTEXT_BLOCKING:
		return STEP_HIDDEN
	if _decided:
		if not _acked.has(STEP_RESULT):
			return STEP_RESULT
		return STEP_OUTRO
	var any_action := _inspected or _rates_seen or _paid_minor >= 0
	if not _acked.has(STEP_REQUEST) and not any_action and context == CONTEXT_NONE:
		return STEP_REQUEST
	match context:
		CONTEXT_INSPECT:
			return STEP_INSPECT_CLOSE
		CONTEXT_INFO:
			return STEP_RATES_CLOSE
		CONTEXT_NUMPAD:
			return STEP_PAY_TYPE
		CONTEXT_OTHER:
			return STEP_CLOSE_OTHER
	if not _inspected:
		return STEP_INSPECT
	if not _rates_seen:
		return STEP_RATES
	if not paid_correctly():
		return STEP_PAY
	return STEP_STAMP


## Adımın metin anahtarı: sonuç adımı doğru/yanlışa, ödeme adımı yanlış yazılmışsa "düzelt" metnine döner.
func text_key(step := "") -> String:
	if step.is_empty():
		step = current()
	match step:
		STEP_RESULT:
			return "TUT_RESULT_OK" if _correct else "TUT_RESULT_BAD"
		STEP_PAY:
			return "TUT_PAY_FIX" if paid_wrong() else "TUT_PAY"
	return str(STEPS.get(step, {}).get("key", ""))


func target(step := "") -> String:
	if step.is_empty():
		step = current()
	return str(STEPS.get(step, {}).get("target", ""))


func needs_ack(step := "") -> bool:
	if step.is_empty():
		step = current()
	return bool(STEPS.get(step, {}).get("ack", false))


## İlerleme (1-tabanlı, ORDER içinde); görünmez adımlarda 0.
func progress() -> int:
	return ORDER.find(current()) + 1


## Yeniden başlama (uygulama kapanıp açıldı) ya da kayıt için.
func to_dict() -> Dictionary:
	return {"lesson": lesson.duplicate(), "acked": _acked.keys(), "inspected": _inspected, "rates_seen": _rates_seen,
		"paid_minor": _paid_minor, "decided": _decided, "correct": _correct, "done": _done, "skipped": skipped}


static func from_dict(data: Dictionary) -> TutorialFlow:
	var flow := TutorialFlow.new()
	flow.lesson = (data.get("lesson", {}) as Dictionary).duplicate()
	for step: Variant in data.get("acked", []):
		flow._acked[str(step)] = true
	flow._inspected = bool(data.get("inspected", false))
	flow._rates_seen = bool(data.get("rates_seen", false))
	flow._paid_minor = int(data.get("paid_minor", -1))
	flow._decided = bool(data.get("decided", false))
	flow._correct = bool(data.get("correct", false))
	flow._done = bool(data.get("done", false))
	flow.skipped = bool(data.get("skipped", false))
	return flow
