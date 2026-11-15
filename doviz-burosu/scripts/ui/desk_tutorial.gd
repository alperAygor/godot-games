class_name DeskTutorial
extends Control
## Gün 1 etkileşimli öğreticisi (masanın üstünde katman, z 45: sayfaların da üstünde). Gerçek masada, ilk uygun müşteriyle
## (döviz satan, doğru cevabı TAMAMLA) adım adım: dokunulacak şeyin çevresinde yanıp sönen halka + tek kısa cümle,
## oyuncunun eylemini bekler, onaylar. Mantık `TutorialFlow`'da (saf, testli); burası yalnızca çizer ve bildirir.
## Katmanın kendisi dokunmayı geçirir (MOUSE_FILTER_IGNORE); yalnızca balon (Tamam / Atla) dokunma alır.
## Bir kez biter; Rehber'deki "Öğreticiyi yeniden oynat" bir sonraki hikaye vardiyasına kurar. Bu iki bayrak cihaz
## düzeyindedir (kayıttan bağımsız, yeni oyunda sıfırlanmaz): `tutorial.cfg` (`JsonIO.user_file`: betikli çalışmada sandbox).
## Öğretici bir şey söylerken vardiya saati durur (`holds_clock`).

const STATE_FILE := "tutorial.cfg"
const RING_COLOR := Color("FFC857")
const RING_PAD := 10.0
const CALLOUT_MARGIN := 16.0
## Sonuç adımında uyarı fişi en az bu kadar açık kalır.
const SLIP_HOLD_SECONDS := 30.0
## Bu başlıklı sayfalar açıkken öğretici görünmez (oyuncu başka bir şeyle meşgul).
const BLOCKING_SHEETS := ["PAUSE_TITLE", "OFFICE_TITLE", "", "DESK_SHIFT_OVER", "MODE_RUN_OVER"]

signal finished(skipped: bool)

var desk: DeskScreen
var flow := TutorialFlow.new()

var _callout: PanelContainer
var _text: Label
var _progress: Label
var _ok_button: Button
var _skip_button: Button
var _shown_step := ""
var _shown_locale := ""
var _target_rect := Rect2()
var _pulse := 0.0
var _sheet_title := ""


## Öğretici bu vardiyada kurulmalı mı: Gün 1 ve henüz bitmedi, ya da Rehber'den yeniden istendi.
static func wanted(day: int) -> bool:
	var state := read_state()
	return bool(state["replay"]) or (day == 1 and not bool(state["done"]))


## {done, replay}; dosya yoksa ya da okunamıyorsa ikisi de false (en kötü durumda öğretici bir kez daha görünür).
static func read_state() -> Dictionary:
	var config := ConfigFile.new()
	var path := JsonIO.user_file(STATE_FILE)
	if not FileAccess.file_exists(path) or config.load(path) != OK:
		return {"done": false, "replay": false}
	return {"done": config.get_value("tutorial", "done", false) == true, "replay": config.get_value("tutorial", "replay", false) == true}


static func write_state(done: bool, replay: bool) -> void:
	var config := ConfigFile.new()
	config.set_value("tutorial", "done", done)
	config.set_value("tutorial", "replay", replay)
	config.save(JsonIO.user_file(STATE_FILE))


## Rehber'deki "yeniden oynat": bir sonraki hikaye vardiyasında öğretici yeniden başlar.
static func request_replay() -> void:
	write_state(bool(read_state()["done"]), true)


func _init(owner_desk: DeskScreen) -> void:
	desk = owner_desk
	name = "Tutorial"
	z_index = 45
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_callout = PanelContainer.new()
	_callout.name = "TutorialCallout"
	_callout.theme_type_variation = &"FloatCard"
	_callout.mouse_filter = Control.MOUSE_FILTER_STOP
	_callout.visible = false
	add_child(_callout)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_callout.add_child(box)
	# Üst satır: ilerleme + küçük "Öğreticiyi geç"; orta: tek cümle; alt: yalnızca onay adımlarında "Anladım".
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	box.add_child(header)
	_progress = UiKit.label("", &"CardDetail", "TutorialProgress")
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_progress)
	_skip_button = UiKit.button(tr("TUT_SKIP"), "TutorialSkip", &"GhostButton", 88.0)
	_skip_button.custom_minimum_size.x = 220.0
	_skip_button.pressed.connect(skip)
	header.add_child(_skip_button)
	_text = UiKit.wrapped("", &"GoalTitle", "TutorialText")
	box.add_child(_text)
	_ok_button = UiKit.button(tr("TUT_OK"), "TutorialNext", &"InkButton", 96.0)
	_ok_button.pressed.connect(_on_ok)
	box.add_child(_ok_button)
	desk.sheets.opened.connect(func(title_key: String) -> void:
		_sheet_title = title_key
		# Dokunma sırası ağaç sırasıdır (z_index değil): balon yeni sayfanın karartmasının altında kalmasın.
		if get_parent() == desk:
			desk.move_child(self, -1)
		sync()
		sync.call_deferred())  # sayfayı kuran kod `pauses` gibi bayrakları açtıktan sonra yeniden bak
	desk.sheets.closed.connect(func() -> void:
		_sheet_title = ""
		sync())


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _text != null:
		_shown_locale = ""  # dil değişti: aynı adımı yeni dilde yeniden yaz
		_render()


## Öğretici bir adım gösterirken (ders müşterisi masadayken ya da sonucu anlatırken) saat durur.
func holds_clock() -> bool:
	return flow.is_active()


## Masa her senkronda çağırır: ders müşterisini yakalar, açık sayfa bağlamını günceller, adımı çizer.
func sync() -> void:
	if flow.is_done():
		return
	var shift := desk.shift
	if not flow.has_lesson() and desk._shown != null and shift != null and shift.current == desk._shown:
		if TutorialFlow.eligible(desk._shown, shift.current_verdict, shift.ctx.book.local_code):
			flow.begin(_lesson_for(desk._shown, shift))
	flow.set_context(_context())
	_render()


func handle(event: String, data: Dictionary) -> void:
	if event == TutorialFlow.EVENT_DECIDED and flow.is_active():
		desk.booth.hold_slip(SLIP_HOLD_SECONDS)
	flow.handle(event, data)
	if event != TutorialFlow.EVENT_DECIDED:  # karar sonrası masa zaten senkronlanır
		sync()


func skip() -> void:
	flow.skip()
	_finish()


func _on_ok() -> void:
	Feel.sfx("page")
	if flow.ack():
		if flow.is_done():
			_finish()
			return
		_render()


func _finish() -> void:
	write_state(true, false)
	_callout.visible = false
	set_process(false)
	queue_redraw()
	Analytics.log_event("tutorial_done", {"skipped": flow.skipped})
	finished.emit(flow.skipped)


func _lesson_for(customer: Customer, shift: Shift) -> Dictionary:
	var local := shift.ctx.book.local_code
	var midday := shift.ctx.use_midday_rates()
	var rates := shift.ctx.rates.rates(customer.currency, shift.ctx.day, midday)
	return {"code": customer.currency, "amount_minor": customer.nominal_minor(customer.currency), "rate": int(rates["buy"]),
		"payout_minor": int(shift.current_verdict.pay_out.get(local, 0)), "local": local}


## Açık sayfa -> akış bağlamı. Duraklatma, ofis, hikaye ve mesai bitti sayfalarında öğretici susar.
func _context() -> String:
	if not desk.sheets.is_open():
		return TutorialFlow.CONTEXT_NONE
	if not desk.sheets.closable or desk.sheets.pauses or _sheet_title in BLOCKING_SHEETS:
		return TutorialFlow.CONTEXT_BLOCKING
	match _sheet_title:
		"DESK_INSPECT_TITLE":
			return TutorialFlow.CONTEXT_INSPECT
		"TOOL_BOOK":
			return TutorialFlow.CONTEXT_INFO
		"DESK_NUMPAD_TITLE":
			return TutorialFlow.CONTEXT_NUMPAD
	return TutorialFlow.CONTEXT_OTHER


## Şu anki adımın metni (o anki dilde, sayılar o dilin biçimiyle).
func text_for_step() -> String:
	var lesson := flow.lesson
	var code := str(lesson.get("code", ""))
	var local := str(lesson.get("local", "PL"))
	var key := flow.text_key()
	var amount := UiKit.money(int(lesson.get("amount_minor", 0)), code)
	var payout := UiKit.money(int(lesson.get("payout_minor", 0)), local)
	match key:
		"TUT_REQUEST":
			return tr(key) % [amount, local]
		"TUT_RATES_CLOSE":
			return tr(key) % [UiKit.rate_text(int(lesson.get("rate", 0))), local, code]
		"TUT_PAY":
			return tr(key) % [amount, UiKit.rate_text(int(lesson.get("rate", 0))), payout]
		"TUT_PAY_FIX", "TUT_PAY_TYPE":
			return tr(key) % payout
		"TUT_RESULT_BAD":
			return tr(key) % int(desk.shift.ctx.balance["shift"]["free_mistakes"])
	return tr(key)


func _render() -> void:
	var step := flow.current()
	var visible_step := step not in [TutorialFlow.STEP_WAITING, TutorialFlow.STEP_HIDDEN, TutorialFlow.STEP_DONE]
	_callout.visible = visible_step
	set_process(visible_step)
	if not visible_step:
		_shown_step = ""  # geri gelince yeniden belirsin
		_target_rect = Rect2()
		queue_redraw()
		return
	# Masa her karede senkronlar: yalnızca değişen şey yazılır; balon yalnızca adım değişince "pop" eder.
	var text := text_for_step()
	if text != _text.text:
		_text.text = text
	var locale := TranslationServer.get_locale()
	if step != _shown_step or locale != _shown_locale:
		var new_step := step != _shown_step
		_shown_step = step
		_shown_locale = locale
		_ok_button.text = tr("TUT_DONE") if step == TutorialFlow.STEP_OUTRO else tr("TUT_OK")
		_skip_button.text = tr("TUT_SKIP")
		_progress.text = tr("TUT_PROGRESS") % [maxi(1, flow.progress()), TutorialFlow.ORDER.size()]
		_ok_button.visible = flow.needs_ack()
		_skip_button.visible = step != TutorialFlow.STEP_OUTRO
		if new_step:
			_pulse = 0.0
			Feel.pop_in(_callout, 0.0, 1.04)
	_place()


## Parlatılacak düğüm (adım hedefi; "@pay"/"@rate" bu müşteriye göre çözülür).
func target_node() -> Control:
	var target := flow.target()
	match target:
		"":
			return null
		"@pay":
			target = "PayButton_%s" % str(flow.lesson.get("local", "PL"))
		"@rate":
			target = "RateRow_%s" % str(flow.lesson.get("code", ""))
	var found := desk.find_child(target, true, false) as Control
	if found != null and found.is_visible_in_tree():
		return found
	return null


func _process(delta: float) -> void:
	_pulse += delta
	_place()


## Halkayı hedefin çevresine koyar; balonu hedefi örtmeyecek bir yere yerleştirir: sayfa açıksa önce sayfanın üstü,
## sonra hedefin karşı tarafı (hedef üst yarıdaysa altı), sonra öbür tarafı, en son güvenli alanın tepesi.
func _place() -> void:
	var node := target_node()
	_target_rect = Rect2()
	if node != null:
		var rect := node.get_global_rect()
		_target_rect = Rect2(rect.position - global_position - Vector2(RING_PAD, RING_PAD), rect.size + Vector2(RING_PAD, RING_PAD) * 2.0)
	var area := get_rect()
	var safe := _safe_rect(area)
	var width := safe.size.x - CALLOUT_MARGIN * 2.0
	_callout.custom_minimum_size.x = width
	_callout.size = Vector2(width, 0.0)
	_callout.reset_size()
	var height := _callout.get_combined_minimum_size().y
	var top := safe.position.y + CALLOUT_MARGIN
	var bottom := safe.end.y - CALLOUT_MARGIN - height
	var candidates: Array[float] = []
	var panel := desk.sheets.panel_rect()
	if panel.has_area():
		candidates.append(panel.position.y - global_position.y - height - CALLOUT_MARGIN)
	if _target_rect.has_area():
		var below := _target_rect.end.y + CALLOUT_MARGIN
		var above := _target_rect.position.y - height - CALLOUT_MARGIN
		if _target_rect.get_center().y < area.size.y * 0.5:
			candidates.append_array([below, above])
		else:
			candidates.append_array([above, below])
	candidates.append(top)
	var y := top
	for candidate in candidates:
		var rect := Rect2(safe.position.x + CALLOUT_MARGIN, candidate, width, height)
		if candidate >= top and candidate <= bottom and not rect.intersects(_target_rect):
			y = candidate
			break
	_callout.position = Vector2(safe.position.x + CALLOUT_MARGIN, y)
	queue_redraw()


## Güvenli alan (çentik/gezinme çubuğu) içinde kal: masanın `SafeAreaContainer` boşlukları.
func _safe_rect(area: Rect2) -> Rect2:
	var safe := desk.safe_area
	if safe == null:
		return area
	var left := float(safe.get_theme_constant("margin_left"))
	var top := float(safe.get_theme_constant("margin_top"))
	var right := float(safe.get_theme_constant("margin_right"))
	var bottom := float(safe.get_theme_constant("margin_bottom"))
	return Rect2(area.position + Vector2(left, top), area.size - Vector2(left + right, top + bottom))


func _draw() -> void:
	if not _target_rect.has_area() or not _callout.visible:
		return
	var glow := 0.55 + 0.45 * sin(_pulse * 5.0)
	var grow := 3.0 * sin(_pulse * 5.0)
	var rect := _target_rect.grow(grow)
	draw_rect(rect.grow(6.0), Color(RING_COLOR, 0.18 * glow), false, 10.0)
	draw_rect(rect, Color(RING_COLOR, 0.95), false, 5.0)
	# Hedefe doğru küçük ok (balonla hedef arasında)
	var callout_rect := Rect2(_callout.position, _callout.size)
	var tip := Vector2(rect.get_center().x, rect.position.y - 4.0)
	var direction := -1.0
	if callout_rect.get_center().y > rect.get_center().y:
		tip = Vector2(rect.get_center().x, rect.end.y + 4.0)
		direction = 1.0
	var base_y := tip.y + direction * 26.0
	draw_colored_polygon(PackedVector2Array([tip, Vector2(tip.x - 18.0, base_y), Vector2(tip.x + 18.0, base_y)]), Color(RING_COLOR, 0.95))
