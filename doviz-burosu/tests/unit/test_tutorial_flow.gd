extends "res://tests/engine_case.gd"
## Gün 1 öğreticisinin durum makinesi (saf mantık): her adım, atlama, sıra dışı hamle, duraklatma ve dil değişimi.

const LESSON := {"code": "FED", "amount_minor": 4000, "rate": 2970, "payout_minor": 118500, "local": "PL"}

var flow: TutorialFlow


func before_each() -> void:
	super.before_each()
	flow = TutorialFlow.new()


func _ok_result() -> Dictionary:
	return {"result": {"correct": true}, "decision": Verdict.DECISION_COMPLETE}


## Bir sayfayı "aç" (bağlam) — arayüz gerçek sayfa açılınca aynısını yapar.
func _open(context: String) -> void:
	flow.set_context(context)


func _close() -> void:
	flow.set_context(TutorialFlow.CONTEXT_NONE)


func test_nothing_is_shown_until_a_lesson_customer_arrives() -> void:
	assert_eq(flow.current(), TutorialFlow.STEP_WAITING)
	assert_false(flow.is_active(), "müşteri yokken saat durmaz")
	flow.handle(TutorialFlow.EVENT_INSPECT)
	assert_eq(flow.current(), TutorialFlow.STEP_WAITING, "dersten önceki olaylar sayılmaz")
	flow.begin(LESSON)
	assert_true(flow.is_active())
	assert_eq(flow.current(), TutorialFlow.STEP_REQUEST)


func test_every_step_in_order() -> void:
	flow.begin(LESSON)
	var seen: Array[String] = []
	seen.append(flow.current())  # request
	assert_true(flow.needs_ack())
	assert_eq(flow.target(), "CustomerSpeech")
	assert_true(flow.ack())
	seen.append(flow.current())  # inspect
	assert_eq(flow.target(), "NoteTile0")
	assert_false(flow.ack(), "eylem adımı Tamam'la geçilmez")
	flow.handle(TutorialFlow.EVENT_INSPECT, {"index": 0})
	_open(TutorialFlow.CONTEXT_INSPECT)
	seen.append(flow.current())  # inspect_close
	_close()
	seen.append(flow.current())  # rates
	assert_eq(flow.target(), "ToolBookButton")
	flow.handle(TutorialFlow.EVENT_RATES)
	_open(TutorialFlow.CONTEXT_INFO)
	seen.append(flow.current())  # rates_close
	assert_eq(flow.target(), "@rate")
	_close()
	seen.append(flow.current())  # pay
	assert_eq(flow.target(), "@pay")
	assert_eq(flow.text_key(), "TUT_PAY")
	flow.handle(TutorialFlow.EVENT_NUMPAD, {"code": "PL"})
	_open(TutorialFlow.CONTEXT_NUMPAD)
	seen.append(flow.current())  # pay_type
	flow.handle(TutorialFlow.EVENT_PAID, {"code": "PL", "minor": 118500})
	_close()
	seen.append(flow.current())  # stamp
	assert_eq(flow.target(), "CompleteButton")
	flow.handle(TutorialFlow.EVENT_DECIDED, _ok_result())
	seen.append(flow.current())  # result
	assert_eq(flow.text_key(), "TUT_RESULT_OK")
	assert_true(flow.ack())
	seen.append(flow.current())  # outro
	assert_true(flow.ack())
	assert_eq(flow.current(), TutorialFlow.STEP_DONE)
	assert_true(flow.is_done())
	assert_false(flow.skipped)
	assert_eq(seen, TutorialFlow.ORDER, "adımlar ilerleme sırasıyla aynı")
	for i in seen.size():
		assert_ne(TutorialFlow.STEPS[seen[i]]["key"], "", seen[i])


func test_progress_counts_up_through_the_order() -> void:
	flow.begin(LESSON)
	assert_eq(flow.progress(), 1)
	flow.ack()
	assert_eq(flow.progress(), 2)
	flow.skip()
	assert_eq(flow.progress(), 0, "bitti: gösterge yok")


func test_skip_ends_at_any_step_and_ignores_later_events() -> void:
	flow.begin(LESSON)
	flow.ack()
	flow.skip()
	assert_true(flow.is_done())
	assert_true(flow.skipped)
	assert_false(flow.is_active(), "atlanınca saat yine işler")
	flow.handle(TutorialFlow.EVENT_DECIDED, _ok_result())
	assert_eq(flow.current(), TutorialFlow.STEP_DONE)
	assert_false(flow.ack())


func test_skip_before_the_customer_also_counts() -> void:
	flow.skip()
	assert_true(flow.is_done())
	flow.begin(LESSON)
	assert_false(flow.has_lesson(), "bitmiş öğretici yeniden başlamaz")


func test_doing_things_early_skips_their_steps() -> void:
	flow.begin(LESSON)
	# İsteği okumadan önce ödeme yazıldı: istek adımı düşer, ödeme hatırlanır.
	flow.handle(TutorialFlow.EVENT_PAID, {"code": "PL", "minor": 118500})
	assert_eq(flow.current(), TutorialFlow.STEP_INSPECT)
	flow.handle(TutorialFlow.EVENT_RATES)
	assert_eq(flow.current(), TutorialFlow.STEP_INSPECT, "sırası gelmeyen adım için sıradaki eksik gösterilir")
	flow.handle(TutorialFlow.EVENT_INSPECT)
	assert_eq(flow.current(), TutorialFlow.STEP_STAMP, "kur ve ödeme zaten yapıldı")


func test_stamping_at_any_time_jumps_to_the_result() -> void:
	flow.begin(LESSON)
	flow.handle(TutorialFlow.EVENT_DECIDED, {"result": {"correct": false}, "decision": Verdict.DECISION_COMPLETE})
	assert_eq(flow.current(), TutorialFlow.STEP_RESULT)
	assert_eq(flow.text_key(), "TUT_RESULT_BAD", "hatanın bedeli anlatılır")
	assert_eq(flow.target(), "Slip")
	flow.handle(TutorialFlow.EVENT_DECIDED, _ok_result())
	assert_eq(flow.text_key(), "TUT_RESULT_BAD", "ilk karar sayılır")
	flow.handle(TutorialFlow.EVENT_INSPECT)
	assert_eq(flow.current(), TutorialFlow.STEP_RESULT, "sonradan gelen olaylar sonucu bozmaz")


func test_a_wrong_amount_asks_to_fix_it() -> void:
	flow.begin(LESSON)
	flow.handle(TutorialFlow.EVENT_INSPECT)
	flow.handle(TutorialFlow.EVENT_RATES)
	flow.handle(TutorialFlow.EVENT_PAID, {"code": "PL", "minor": 100000})
	assert_eq(flow.current(), TutorialFlow.STEP_PAY)
	assert_true(flow.paid_wrong())
	assert_eq(flow.text_key(), "TUT_PAY_FIX")
	flow.handle(TutorialFlow.EVENT_PAID, {"code": "FED", "minor": 118500})
	assert_eq(flow.current(), TutorialFlow.STEP_PAY, "başka para biriminin satırı sayılmaz")
	flow.handle(TutorialFlow.EVENT_PAID, {"code": "PL", "minor": 118500})
	assert_eq(flow.current(), TutorialFlow.STEP_STAMP)


func test_another_open_page_asks_to_close_it_first() -> void:
	flow.begin(LESSON)
	_open(TutorialFlow.CONTEXT_OTHER)
	assert_eq(flow.current(), TutorialFlow.STEP_CLOSE_OTHER, "hesap makinesi açıkken önce kapat")
	assert_eq(flow.target(), "CloseSheetButton")
	_close()
	assert_eq(flow.current(), TutorialFlow.STEP_REQUEST)


func test_pause_hides_the_lesson_and_resume_returns_to_the_same_step() -> void:
	flow.begin(LESSON)
	flow.ack()
	flow.handle(TutorialFlow.EVENT_INSPECT)
	assert_eq(flow.current(), TutorialFlow.STEP_RATES)
	_open(TutorialFlow.CONTEXT_BLOCKING)  # uygulama arka plana gitti: duraklatma sayfası
	assert_eq(flow.current(), TutorialFlow.STEP_HIDDEN)
	assert_true(flow.is_active(), "duraklatmada da ders sürüyor (saat zaten durur)")
	_close()
	assert_eq(flow.current(), TutorialFlow.STEP_RATES)


func test_state_survives_a_round_trip_through_a_dictionary() -> void:
	flow.begin(LESSON)
	flow.ack()
	flow.handle(TutorialFlow.EVENT_INSPECT)
	flow.handle(TutorialFlow.EVENT_PAID, {"code": "PL", "minor": 5})
	var copy := TutorialFlow.from_dict(JSON.parse_string(JSON.stringify(flow.to_dict())))
	assert_eq(copy.current(), flow.current())
	assert_eq(copy.text_key(), flow.text_key())
	assert_true(copy.paid_wrong())
	assert_eq(int(copy.lesson["payout_minor"]), 118500)


func test_texts_are_keys_so_a_language_switch_keeps_the_step() -> void:
	flow.begin(LESSON)
	flow.ack()
	var before := flow.current()
	var key := flow.text_key()
	for locale in ["en", "tr"]:
		TranslationServer.set_locale(locale)
		assert_eq(flow.current(), before, "dil adımı değiştirmez")
		assert_eq(flow.text_key(), key)
		assert_ne(str(TranslationServer.translate(key)), key, "%s çevirisi var" % locale)
	TranslationServer.set_locale("tr")


func test_every_tutorial_text_exists_in_both_languages_with_the_same_placeholders() -> void:
	var keys: Array[String] = ["TUT_RESULT_BAD", "TUT_PAY_FIX", "TUT_OK", "TUT_DONE", "TUT_SKIP", "TUT_PROGRESS", "TUT_REPLAY",
		"TUT_REPLAY_SET", "TUT_WELCOME_T", "TUT_WELCOME_B", "TUT_MORNING_NEW", "TUT_MORNING_NOTHING", "TUT_MORNING_FIRST"]
	for step: String in TutorialFlow.STEPS:
		keys.append(str(TutorialFlow.STEPS[step]["key"]))
	var placeholder := RegEx.create_from_string("%[sd]")
	for key in keys:
		var counts := []
		for locale in ["en", "tr"]:
			TranslationServer.set_locale(locale)
			var text := str(TranslationServer.translate(key))
			assert_ne(text, key, "%s (%s) çevrilmeli" % [key, locale])
			assert_true(key == "TUT_WELCOME_B" or text.length() <= 110, "%s (%s) tek kısa cümle olmalı: %d" % [key, locale, text.length()])
			var found: PackedStringArray = []
			for m in placeholder.search_all(text):
				found.append(m.get_string())
			counts.append(found)
		assert_eq(counts[0], counts[1], "%s yer tutucuları iki dilde aynı" % key)
	TranslationServer.set_locale("tr")


func test_only_clean_sellers_are_lesson_customers() -> void:
	var ctx := make_ctx(1)
	var clean := seller("FED", [20, 10], 1)
	assert_true(TutorialFlow.eligible(clean, evaluate(clean, ctx), "PL"))
	var buying := buyer("FED", 10, make_ctx(4))
	assert_false(TutorialFlow.eligible(buying, evaluate(buying, make_ctx(4)), "PL"), "döviz alan müşteri ders değil")
	var faked := seller("FED", [20], 3)
	faked.notes.append(fake_note("FED", 20, 3, [Banknote.FAKE_UV_MISSING]))
	assert_false(TutorialFlow.eligible(faked, evaluate(faked, make_ctx(3)), "PL"), "polis gerektiren müşteri ders değil")
	assert_false(TutorialFlow.eligible(null, null, "PL"))
