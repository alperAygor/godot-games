class_name DeskScreen
extends Control
## Gişe masası (`scenes/desk.tscn`). Sadece gösterir ve oyuncunun girdisini DeskModel/Shift'e iletir; kural ve hesap burada yok.
## Bu dosya vardiya akışını yönetir (başlat, saat, müşteri gelişi/gidişi, karar, ödüllü reklam teklifleri); ekranın
## parçaları kendi sınıflarındadır:
##   `DeskHud` üst çubuk · `DeskBooth` gişe sahnesi + uyarı fişi + duyuru · `DeskOffice` ofis düğmesi/sayfası ·
##   `DeskCounter` tezgâh (kâğıtlar, tepsiler, ödeme fişi) · `DeskToolbar` araç çubuğu + damgalar ·
##   `DeskSheets` sayfa yuvası; içerikler `DeskNoteSheets` / `DeskToolSheets` / `DeskFlowSheets` ·
##   `DeskFeedback` karar hissi · `DeskTutorial` Gün 1 etkileşimli öğreticisi (mantığı `TutorialFlow`).
## Yerleşim (dikey): üst çubuk, (mesai uzatma teklifi), gişe, tezgâh, araç çubuğu, damgalar (başparmak erişiminde en altta).
## Düğüm adları TouchInput testleri için sabittir (`CompleteButton`, `PayButton_<PARA>`, `NoteTile<i>`, `Zone_<kader>`...).

const MAX_FRAME_DELTA := 0.25
## Vardiyanın bu kadar saniyesi kalınca müzik gergin parçaya geçer.
const TENSION_SECONDS := 70.0

## Boşsa varsayılan hikaye kariyeri kurulur; testler play() ile verir.
var career: Career
var shift: Shift
var model: DeskModel
var uv_lamp := false
var magnifier := false
var backlight := false

var hud := DeskHud.new()
var booth := DeskBooth.new(self)
var office := DeskOffice.new(self)
var counter := DeskCounter.new(self)
var toolbar := DeskToolbar.new(self)
var sheets := DeskSheets.new(self)
var note_sheets := DeskNoteSheets.new(self)
var tool_sheets := DeskToolSheets.new(self)
var flow_sheets := DeskFlowSheets.new(self)
## Öğretici katmanı (yalnızca hikaye vardiyasında kurulur; yoksa null).
var tutorial: DeskTutorial = null
## Ekranın güvenli alan kabı (öğretici balonu bunun içinde kalır).
var safe_area: MarginContainer

var _running := false
var _shown: Customer = null
var _overtime_button: Button
var _tick_sound_left := 0.0
var _midday_announced := false
## Hikaye sayfası şu olay için açıldı (boşsa değil); aynı olay için iki kez açılmasın.
var _story_sheet_for := ""


## Sahne açıldıktan sonra belirli bir kariyerle (yeniden) başlatır (testler ve ileride "Devam" için).
func play(for_career: Career) -> void:
	career = for_career
	GameSession.career = for_career
	_close_sheet()
	_start_shift()


func _ready() -> void:
	if career == null:
		if GameSession.career == null and not GameSession.continue_game():
			GameSession.new_game()
		career = GameSession.career
	_build_ui()
	_start_shift()
	Feel.start_ambience()
	print("[Desk] hazır")


func _process(delta: float) -> void:
	# Arka plandan dönünce ya da takılınca dev bir delta gelebilir; vardiya saati haksız yere ilerlemesin.
	tick(minf(delta, MAX_FRAME_DELTA))


## Android yaşam döngüsü: uygulama arka plana gidince/odak kaybolunca vardiya duraklatılır (saat işlemez, kayıt zaten arka planda yazılır).
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _running and not sheets.is_open() and shift != null:
			_open_pause_sheet()


## Zamanı ilerletir (testlerde elle çağrılır). Öğretici bir adım gösterirken saat durur.
func tick(delta: float) -> void:
	if not _running or sheets.pauses:
		return
	if tutorial != null and tutorial.holds_clock():
		_sync()
		return
	shift.advance(delta)
	if shift.seconds_left() < TENSION_SECONDS and not shift.is_closed():  # son dakikalarda duvar saati duyulur
		_tick_sound_left -= delta
		if _tick_sound_left <= 0.0:
			_tick_sound_left = 2.0
			Feel.sfx("clock_tick", 1.0)
	booth.tick(delta)
	_sync()


## Android geri tuşu: açık sayfa varsa kapatır (duraklatma sayfasını kapatmak vardiyayı sürdürür); sayfa yoksa
## vardiyayı duraklatır. Mesai bitti sayfası kapanmaz.
func handle_back() -> bool:
	if sheets.is_open():
		if sheets.closable:
			_close_sheet()
		return true
	if _running:
		_open_pause_sheet()
	return true


# --- Kurulum -------------------------------------------------------------------

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("14110E")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var safe := MarginContainer.new()
	safe.set_script(load("res://scripts/ui/safe_area_container.gd"))
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(safe)
	safe_area = safe
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	safe.add_child(column)

	column.add_child(hud.build())
	_overtime_button = UiKit.icon_button("ad", "", "OvertimeButton", true, true, 68.0)
	_overtime_button.visible = false
	_overtime_button.pressed.connect(_request_overtime)
	column.add_child(_overtime_button)
	var booth_view := booth.build()
	office.build(booth_view.overlay)
	tool_sheets.build_pins(booth_view.overlay)
	column.add_child(booth_view)
	column.add_child(counter.build())
	column.add_child(toolbar.build_tools())
	column.add_child(toolbar.build_decisions())
	add_child(Atmosphere.new())


# --- Vardiya akışı ---------------------------------------------------------------

func _start_shift() -> void:
	shift = career.new_shift()
	shift.start()
	_running = true
	_shown = null
	model = null
	_midday_announced = false
	_story_sheet_for = ""
	booth.reset()
	toolbar.refresh_tools()
	hud.set_day(career)
	_setup_tutorial()
	_clear_customer()
	_sync()


## Öğretici yalnızca hikaye vardiyasında ve gerekiyorsa (Gün 1'de henüz görülmediyse ya da Rehber'den yeniden istendiyse) kurulur.
func _setup_tutorial() -> void:
	if tutorial != null:
		tutorial.queue_free()
		remove_child(tutorial)
		tutorial = null
	if GameSession.mode != null or not DeskTutorial.wanted(career.day):
		return
	tutorial = DeskTutorial.new(self)
	add_child(tutorial)


func _sync() -> void:
	office.sync()
	AudioManager.set_tension(shift.seconds_left() < TENSION_SECONDS)
	# Hikaye olayı çözülene dek müşteri gösterilmez (olay müşterinin ÖNCESİNDE oynanır).
	var visible_customer: Customer = shift.current if shift.pending_beat.is_empty() else null
	if visible_customer != _shown:
		_shown = visible_customer
		_show_customer()
	if not shift.pending_beat.is_empty() and _story_sheet_for != str(shift.pending_beat["id"]):
		_story_sheet_for = str(shift.pending_beat["id"])
		flow_sheets.open_story(shift.pending_beat)
	hud.sync(shift)
	_refresh_overtime()
	if shift.ctx.use_midday_rates() and not _midday_announced:
		_midday_announced = true
		booth.announce()
	if _running and shift.is_closed() and shift.current == null:
		_running = false
		flow_sheets.open_day_end()
	if tutorial != null:
		tutorial.sync()


func _show_customer() -> void:
	_clear_customer()
	if _shown == null:
		return
	model = DeskModel.new(_shown)
	booth.face.setup(_shown.face_id, _shown.holder_name, CustomerFigure.HEAD)
	booth.view.bring_customer(_shown.face_id, _shown.holder_name, _speech(_shown))
	counter.show_customer(_shown)
	toolbar.set_decisions_enabled(true)
	counter.layout_items()
	tutorial_event(TutorialFlow.EVENT_CUSTOMER, {})


func _clear_customer(leaving := false) -> void:
	counter.clear(leaving)
	if leaving:
		booth.view.send_customer_away()
	else:
		booth.view.clear_customer()
	booth.bubble_label.text = tr("DESK_WAITING")
	toolbar.set_decisions_enabled(false)


func _speech(customer: Customer) -> String:
	var amount := customer.nominal_minor(customer.currency) if customer.intent == Customer.INTENT_SELL else customer.requested_foreign_minor
	var key := "DESK_SELL_SAY" if customer.intent == Customer.INTENT_SELL else "DESK_BUY_SAY"
	return tr(key) % [Money.format(amount, "", UiKit.locale()), customer.currency]


func _decide(decision: String, reason: String) -> void:
	if shift == null or shift.current == null or model == null:
		return
	_close_sheet()
	var verdict := shift.current_verdict
	var result := shift.submit(model.build_move(decision, reason))
	booth.show_slip(result, verdict)
	DeskFeedback.play(self, decision, result)
	if not bool(result["correct"]):
		Analytics.log_event("mistake", {"decision": decision, "reasons": verdict.reasons})
	if GameSession.mode != null:
		_on_mode_submit(GameSession.mode.on_submit(result))
	_shown = null
	model = null
	_clear_customer(true)
	tutorial_event(TutorialFlow.EVENT_DECIDED, {"decision": decision, "result": result})
	_sync()


## Masanın parçalarından öğreticiye giden olaylar (banknot incelendi, kurlar açıldı, ödeme yazıldı, karar verildi...).
func tutorial_event(event: String, data: Dictionary) -> void:
	if tutorial != null:
		tutorial.handle(event, data)


# --- Ödüllü reklamlar: mesai uzatma ve Sonsuz'da devam -----------------------------------------

## Son 60 saniyede (ve mesai bitince) "+45 sn mesai" teklifi; günde 1, yalnızca hikaye vardiyasında.
func _overtime_offer() -> Dictionary:
	if GameSession.mode != null or shift == null:
		return {"visible": false, "enabled": false}
	return Monetization.rewarded_offer("overtime", career.ad_uses("overtime"))


func _refresh_overtime() -> void:
	# Her karede çalışır: önce ucuz koşul (süre bitmeye yakın mı?), teklif hesabı yalnızca gerekirse.
	var last_seconds := float(AdPolicy.rewarded_config("overtime").get("last_seconds", 60))
	var near_end := not shift.is_closed() and shift.seconds_left() <= last_seconds
	if not near_end and not _overtime_button.visible and not sheets.is_open():
		return
	var offer := _overtime_offer()
	_overtime_button.visible = bool(offer["visible"]) and near_end and not sheets.is_open()
	_overtime_button.disabled = not bool(offer["enabled"])
	_overtime_button.text = tr("AD_OVERTIME") if bool(offer["enabled"]) else tr("AD_UNAVAILABLE")


func _request_overtime() -> void:
	_overtime_button.disabled = true
	Monetization.request_reward("overtime", func(rewarded: bool) -> void:
		if not is_inside_tree():
			return
		if rewarded:
			career.mark_ad_used("overtime")
			shift.extend_time(float(shift.ctx.balance["shift"]["overtime_seconds"]))
			_running = true
			_close_sheet()
		_sync())


func _request_endless_continue() -> void:
	Monetization.request_reward("endless_continue", func(rewarded: bool) -> void:
		if not is_inside_tree() or not rewarded:
			return
		if (GameSession.mode as EndlessRun).continue_with_life():
			_running = true
			_shown = null
			_close_sheet()
			_clear_customer()
			_sync())


## Mod koşusunda işlem sonrası: eklenen yeni kuralı duyur, araç düğmelerini yenile.
func _on_mode_submit(outcome: Dictionary) -> void:
	var rule_id := str(outcome.get("rule_added", ""))
	if rule_id.is_empty():
		return
	toolbar.refresh_tools()
	booth.announce(tr("MODE_NEW_RULE") % tr("RULE_%s" % rule_id))


# --- Sayfalar (testler ve araçlar bu adlarla çağırır) ------------------------------

func _close_sheet() -> void:
	sheets.close()


func _open_inspect_sheet(index: int) -> void:
	note_sheets.open_inspect(index)


func _open_pause_sheet() -> void:
	flow_sheets.open_pause()
