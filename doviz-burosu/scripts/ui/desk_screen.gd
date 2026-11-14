extends Control
## Gişe masası. Sadece gösterir ve oyuncunun girdisini DeskModel/Shift'e iletir; kural ve hesap burada yok.
## Prototip (Faz 4): gri kutularla Gün 1-3. Yerleşim (dikey): üst çubuk, pencere (müşteri), tezgâh (banknotlar + kaderi bölgeleri),
## ödeme, araç çubuğu, karar butonları. Sayfalar (inceleme, katalog, hesap, kurlar/kurallar, ödeme, neden) alttan açılır.

## Banknot sayısına göre tezgâh düzeni: az banknot büyük çizilir, çoğu sıkışık (tezgâh ayrıca kaydırılabilir).
const NOTE_SCALE_FEW := 1.6
const NOTE_SCALE_MID := 1.25
const NOTE_SCALE_MANY := 0.95
const FEW_NOTES := 2
const MID_NOTES := 6
const INSPECT_SCALE := 3.4
const SLIP_SECONDS := 4.0
const MIDDAY_SECONDS := 4.0
## Neden listesi 13 kurala kadar uzar; ekranın büyük kısmını kullanır, sığmayan kısım kaydırılır.
const REASON_LIST_HEIGHT := 760.0
const MAX_FRAME_DELTA := 0.25
const BAND_HEIGHT := 128.0
const DOC_MAX_WIDTH := 320.0
const OVERLAP_MIN := 0.6    # satırlar en çok bu oranda üst üste biner
const MIN_NOTE_SCALE := 0.62 # banknot ölçeği alt sınırı (okunurluk)

## Boşsa varsayılan hikaye kariyeri kurulur; testler play() ile verir.
var career: Career
var shift: Shift
var model: DeskModel
var uv_lamp := false
var magnifier := false
var backlight := false

var _running := false
var _shown: Customer = null
var _sheet: Control = null
var _sheet_closable := true
var _sheet_pauses := false
var _slip_left := 0.0
var _midday_left := 0.0
var _calculator := Calculator.new()
var _numpad_text := ""

var _day_label: Label
var _clock_label: Label
var _mistake_label: Label
var _pay_label: Label
var _face: FaceView
var _name_label: Label
var _bubble_label: Label
var _notes_grid: Control
var _hint_label: Label
var _overtime_button: Button
var _zones_row: HBoxContainer
var _slip: PanelContainer
var _slip_box: VBoxContainer
var _pay_row: HBoxContainer
var _complete_button: Button
var _reject_button: Button
var _police_button: Button
var _uv_button: Button
var _magnifier_button: Button
var _tool_buttons := {}
var _docs_row: Control
var _booth: BoothView
var _surface: DeskSurface
var _items: Control
var _receipt: PanelContainer
var _count_label: Label
var _midday_banner: PanelContainer
## Vardiyanın bu kadar saniyesi kalınca müzik gergin parçaya geçer.
const TENSION_SECONDS := 70.0
var _tick_sound_left := 0.0
var _office_button: IconButton
var _pins_box: VBoxContainer
var _memos_announced := 0
var _midday_announced := false
var _note_scale := 1.25
var _shown_laid_out := false
var _arrival_tweens: Array[Tween] = []
## Hikaye sayfası şu olay için açıldı (boşsa değil); aynı olay için iki kez açılmasın.
var _story_sheet_for := ""
var _story_db: StoryDb
var _rate_text_value := ""


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
		if _running and _sheet == null and shift != null:
			_open_pause_sheet()


## Zamanı ilerletir (testlerde elle çağrılır).
func tick(delta: float) -> void:
	if not _running or _sheet_pauses:
		return
	shift.advance(delta)
	if shift.seconds_left() < TENSION_SECONDS and not shift.is_closed():  # son dakikalarda duvar saati duyulur
		_tick_sound_left -= delta
		if _tick_sound_left <= 0.0:
			_tick_sound_left = 2.0
			Feel.sfx("clock_tick", 1.0)
	if _slip_left > 0.0:
		_slip_left -= delta
		if _slip_left <= 0.0:
			_slip.visible = false
	if _midday_left > 0.0:
		_midday_left -= delta
		if _midday_left <= 0.0:
			_midday_banner.visible = false
	_sync()


## Android geri tuşu: açık sayfa varsa kapatır (duraklatma sayfasını kapatmak vardiyayı sürdürür); sayfa yoksa
## vardiyayı duraklatır. Mesai bitti sayfası kapanmaz.
func handle_back() -> bool:
	if _sheet != null:
		if _sheet_closable:
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
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	safe.add_child(column)

	column.add_child(_build_top_bar())
	_overtime_button = UiKit.icon_button("ad", "", "OvertimeButton", true, true, 68.0)
	_overtime_button.visible = false
	_overtime_button.pressed.connect(_request_overtime)
	column.add_child(_overtime_button)
	column.add_child(_build_booth())
	column.add_child(_build_surface())
	column.add_child(_build_tools())
	column.add_child(_build_decisions())
	add_child(Atmosphere.new())


func _label(text: String, variation := &"", node_name := "") -> Label:
	var label := Label.new()
	label.text = text
	if variation != &"":
		label.theme_type_variation = variation
	if not node_name.is_empty():
		label.name = node_name
	return label


func _button(text: String, node_name: String, variation := &"", min_height := 0.0) -> Button:
	var button := Button.new()
	button.text = text
	button.name = node_name
	if variation != &"":
		button.theme_type_variation = variation
	if min_height > 0.0:
		button.custom_minimum_size.y = min_height
	return button


func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"BoothHud"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	_day_label = _label("", &"HudMuted", "DayLabel")
	_clock_label = _label("09:00", &"HudClock", "ClockLabel")
	_mistake_label = _label("", &"HudLabel", "MistakeLabel")
	_pay_label = _label("", &"HudPay", "PayLabel")
	for label in [_day_label, _clock_label, _mistake_label, _pay_label]:
		row.add_child(label)
	_clock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return panel


func _build_booth() -> Control:
	_booth = BoothView.new()
	_face = _booth.figure.face
	_name_label = _booth.plate_label
	_bubble_label = _booth.bubble.label
	if Monetization.owns_no_ads():
		var decor := SupporterDecor.new()
		decor.position = Vector2(34, 232)
		_booth.overlay.add_child(decor)
	# Uyarı fişi ve gün ortası duyurusu gişe sahnesinin üstüne biner (sıradaki müşterinin banknotlarını örtmesin).
	_slip = PanelContainer.new()
	_slip.name = "Slip"
	_slip.visible = false
	_slip.z_index = 20
	_slip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_slip.gui_input.connect(_on_slip_input)
	_slip_box = VBoxContainer.new()
	_slip_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slip.add_child(_slip_box)
	_booth.overlay.add_child(_slip)
	_midday_banner = PanelContainer.new()
	_midday_banner.name = "MiddayBanner"
	_midday_banner.theme_type_variation = &"SlipPanel"
	_midday_banner.visible = false
	_midday_banner.z_index = 25
	_midday_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_midday_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_midday_banner.add_child(_label(tr("DESK_MIDDAY_UPDATE"), &"SlipTitle", "MiddayText"))
	_booth.overlay.add_child(_midday_banner)
	# Ofis: Merkez talimatı + tüple gelen notlar. Köşede küçük bir düğme; rozeti okunmamış not sayısıdır.
	_office_button = UiKit.icon_button("document", tr("OFFICE_TITLE"), "OfficeButton", true, true, 52.0)
	_office_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_office_button.offset_left = 8.0
	_office_button.offset_right = 198.0
	_office_button.offset_top = -66.0
	_office_button.offset_bottom = -14.0
	_office_button.z_index = 26
	_office_button.visible = false
	_office_button.pressed.connect(_open_office_sheet)
	_booth.overlay.add_child(_office_button)
	_pins_box = VBoxContainer.new()
	_pins_box.name = "PinnedNotes"
	_pins_box.z_index = 26
	_pins_box.add_theme_constant_override("separation", 4)
	_pins_box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_pins_box.alignment = BoxContainer.ALIGNMENT_END
	_pins_box.offset_left = -260.0
	_pins_box.offset_top = -170.0
	_pins_box.offset_right = -8.0
	_pins_box.offset_bottom = -14.0
	_pins_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_pins_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_booth.overlay.add_child(_pins_box)
	_refresh_pins()
	return _booth


func _build_surface() -> Control:
	_surface = DeskSurface.new()
	_surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_surface.custom_minimum_size.y = 300.0
	# Üst bölge: nesnelerin serbestçe durduğu alan; alt bant: fiş + tepsiler
	_items = Control.new()
	_items.name = "Items"
	_items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_items.set_anchors_preset(Control.PRESET_FULL_RECT)
	_items.offset_bottom = -BAND_HEIGHT
	_surface.add_child(_items)
	_items.resized.connect(func() -> void:  # ekran/yerleşim değişirse (ilk kare, döndürme) kâğıtlar yeniden dizilir
		if _shown != null and _shown_laid_out:
			_layout_items(false))
	_hint_label = _label("", &"DeskLabel", "CounterHint")
	_hint_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_items.add_child(_hint_label)
	_count_label = _label("", &"DeskLabel", "CountLabel")
	_count_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_count_label.offset_top = 26.0
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.visible = false
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_items.add_child(_count_label)
	_docs_row = Control.new()
	_docs_row.name = "DocsRow"
	_docs_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_docs_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	_items.add_child(_docs_row)
	_notes_grid = Control.new()
	_notes_grid.name = "NotesGrid"
	_notes_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notes_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	_items.add_child(_notes_grid)
	var band := HBoxContainer.new()
	band.name = "Band"
	band.add_theme_constant_override("separation", 8)
	band.anchor_top = 1.0
	band.anchor_right = 1.0
	band.anchor_bottom = 1.0
	band.offset_left = 8.0
	band.offset_right = -8.0
	band.offset_top = -BAND_HEIGHT
	band.offset_bottom = -8.0
	_surface.add_child(band)
	_receipt = PanelContainer.new()
	_receipt.name = "Receipt"
	_receipt.theme_type_variation = &"ReceiptPanel"
	_receipt.custom_minimum_size.x = 250.0
	var receipt_box := VBoxContainer.new()
	receipt_box.add_theme_constant_override("separation", 4)
	_receipt.add_child(receipt_box)
	var receipt_title := _label(tr("DESK_RECEIPT"), &"SmallLabel", "ReceiptTitle")
	receipt_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	receipt_box.add_child(receipt_title)
	_pay_row = HBoxContainer.new()
	_pay_row.name = "PayRow"
	_pay_row.add_theme_constant_override("separation", 6)
	receipt_box.add_child(_pay_row)
	band.add_child(_receipt)
	_zones_row = HBoxContainer.new()
	_zones_row.name = "Trays"
	_zones_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zones_row.add_theme_constant_override("separation", 6)
	for fate in [Verdict.FATE_RETURN, Verdict.FATE_ACCEPT, Verdict.FATE_CONFISCATE]:
		var zone := FateZone.new()
		zone.name = "Zone_%s" % fate
		zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zone.setup(fate)
		zone.dropped.connect(_on_note_dropped)
		_zones_row.add_child(zone)
	band.add_child(_zones_row)
	return _surface


func _build_payment() -> Control:
	return _pay_row


func _build_tools() -> Control:
	var row := HBoxContainer.new()
	row.name = "ToolsGrid"
	row.add_theme_constant_override("separation", 4)
	var book := _tool("book", tr("TOOL_BOOK"), tr("TOOL_BOOK_SHORT"), "ToolBookButton")
	book.pressed.connect(_open_info_sheet)
	var calc := _tool("calc", tr("TOOL_CALC"), tr("TOOL_CALC_SHORT"), "ToolCalcButton")
	calc.pressed.connect(_open_calculator_sheet)
	var catalog := _tool("catalog", tr("TOOL_CATALOG"), tr("TOOL_CATALOG_SHORT"), "ToolCatalogButton")
	catalog.pressed.connect(_open_catalog_sheet)
	_uv_button = _tool("uv", tr("TOOL_UV"), tr("TOOL_UV_SHORT"), "ToolUvButton")
	_uv_button.toggle_mode = true
	_uv_button.toggled.connect(_on_uv_toggled)
	_magnifier_button = _tool("magnifier", tr("TOOL_MAGNIFIER"), tr("TOOL_MAGNIFIER_SHORT"), "ToolMagnifierButton")
	_magnifier_button.toggle_mode = true
	_magnifier_button.toggled.connect(_on_magnifier_toggled)
	var till := _tool("till", tr("TOOL_TILL"), tr("TOOL_TILL_SHORT"), "ToolTillButton")
	till.pressed.connect(_open_till_sheet)
	var rate := _tool("rate", tr("TOOL_RATE_CALC"), tr("TOOL_RATE_SHORT"), "ToolRateButton")
	rate.pressed.connect(_open_rate_sheet)
	_tool_buttons = {"book": book, "calc": calc, "catalog": catalog, "uv": _uv_button, "magnifier": _magnifier_button,
		"till": till, "rate_calc": rate}
	for button: Button in _tool_buttons.values():
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	return row


## Araç çubuğu düğmesi: ikon üstte, kısa etiket altta; tam metin `text`te (erişilebilirlik/test) durur.
func _tool(icon_name: String, full_text: String, short_text: String, node_name: String) -> IconButton:
	var button := UiKit.icon_button(icon_name, full_text, node_name, false, true, 84.0, short_text)
	button.accent = Color("C8892B")
	return button


## Hangi araçlar görünür: temel üçü her zaman; UV / büyüteç / kur hesaplayıcı satın alınmış ya da verilmişse; kasa görünümü R_SELL_FOREIGN açılınca.
## Sayaç aracı ayrı bir düğme değil: sahipse tezgâhta toplam otomatik görünür.
func _refresh_tools() -> void:
	_uv_button.visible = career.has_tool("uv")
	_magnifier_button.visible = career.has_tool("magnifier")
	(_tool_buttons["rate_calc"] as Button).visible = career.has_tool("rate_calc")
	(_tool_buttons["till"] as Button).visible = shift.ctx.rule_active("R_SELL_FOREIGN")
	_uv_button.set_pressed_no_signal(false)
	_magnifier_button.set_pressed_no_signal(false)
	uv_lamp = false
	magnifier = false
	backlight = false


func _build_decisions() -> Control:
	var row := HBoxContainer.new()
	row.name = "Stamps"
	row.add_theme_constant_override("separation", 10)
	_complete_button = _stamp(tr("DECISION_COMPLETE"), "CompleteButton", Color("3F7D4E"))
	_complete_button.pressed.connect(_stamp_then.bind(_complete_button, _decide.bind(Verdict.DECISION_COMPLETE, "")))
	_reject_button = _stamp(tr("DECISION_REJECT"), "RejectButton", Color("B07A18"))
	_reject_button.pressed.connect(_stamp_then.bind(_reject_button, _open_reason_sheet))
	_police_button = _stamp(tr("DECISION_POLICE"), "PoliceButton", Color("A82E26"))
	_police_button.pressed.connect(_stamp_then.bind(_police_button, _decide.bind(Verdict.DECISION_POLICE, "")))
	for button in [_complete_button, _reject_button, _police_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	return row


func _stamp(text: String, node_name: String, ink: Color) -> StampButton:
	var button := StampButton.new()
	button.text = text
	button.name = node_name
	button.ink = ink
	button.custom_minimum_size = Vector2(0, 128)
	return button


## Damga basılır: kalkıp iner, mühür vurulduğu an eylem çalışır.
func _stamp_then(button: StampButton, action: Callable) -> void:
	button.press_animation(action)


# --- Vardiya akışı ---------------------------------------------------------------

func _start_shift() -> void:
	shift = career.new_shift()
	shift.start()
	_running = true
	_shown = null
	model = null
	_midday_announced = false
	_story_sheet_for = ""
	_midday_banner.visible = false
	_refresh_tools()
	_day_label.text = tr(str(GameSession.mode.hud()["title_key"])) if GameSession.mode != null else tr("DESK_DAY") % career.day
	_slip.visible = false
	_clear_customer()
	_sync()


func _sync() -> void:
	_sync_office()
	AudioManager.set_tension(shift.seconds_left() < TENSION_SECONDS)
	# Hikaye olayı çözülene dek müşteri gösterilmez (olay müşterinin ÖNCESİNDE oynanır).
	var visible_customer: Customer = shift.current if shift.pending_beat.is_empty() else null
	if visible_customer != _shown:
		_shown = visible_customer
		_show_customer()
	if not shift.pending_beat.is_empty() and _story_sheet_for != str(shift.pending_beat["id"]):
		_story_sheet_for = str(shift.pending_beat["id"])
		_open_story_sheet(shift.pending_beat)
	_clock_label.text = shift.clock_text()
	var free_left := maxi(0, int(shift.ctx.balance["shift"]["free_mistakes"]) - int(shift.stats["mistake_transactions"]))
	_mistake_label.text = tr("DESK_MISTAKES") % [int(shift.stats["mistake_transactions"]), int(shift.ctx.balance["shift"]["free_mistakes"])]
	_mistake_label.modulate = Color(1, 1, 1) if free_left > 0 else Color(0.85, 0.25, 0.25)
	_pay_label.text = _money(int(shift.report()["net_minor"]), "PL")
	if GameSession.mode != null:
		var hud := GameSession.mode.hud()
		_mistake_label.text = tr(str(hud["status_key"])) % int(hud["status_arg"])
		_mistake_label.modulate = Color(1, 1, 1)
		_pay_label.text = tr("MODE_SCORE") % int(hud["score"])
	_refresh_overtime()
	if shift.ctx.use_midday_rates() and not _midday_announced:
		_midday_announced = true
		_midday_banner.visible = true
		_midday_left = MIDDAY_SECONDS
	if _running and shift.is_closed() and shift.current == null:
		_running = false
		_show_day_end()


func _show_customer() -> void:
	_clear_customer()
	if _shown == null:
		return
	model = DeskModel.new(_shown)
	_face.setup(_shown.face_id, _shown.holder_name, CustomerFigure.HEAD)
	_booth.bring_customer(_shown.face_id, _shown.holder_name, _speech(_shown))
	_hint_label.text = tr("DESK_COUNTER_HINT")
	var count := _shown.notes.size()
	_note_scale = NOTE_SCALE_FEW if count <= FEW_NOTES else (NOTE_SCALE_MID if count <= MID_NOTES else NOTE_SCALE_MANY)
	_show_documents()
	_show_counter_total()
	for i in _shown.notes.size():
		var tile := NoteTile.new()
		tile.name = "NoteTile%d" % i
		tile.setup(i, _shown.notes[i], _note_scale, uv_lamp, magnifier)
		tile.tapped.connect(_open_inspect_sheet)
		tile.released.connect(_on_item_released)
		_notes_grid.add_child(tile)
	for code in model.payment_codes(shift.ctx.book.local_code):
		var pay := _button("", "PayButton_%s" % code, &"GhostButton", 64.0)
		pay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pay.pressed.connect(_open_numpad_sheet.bind(code))
		_pay_row.add_child(pay)
	_refresh_payment()
	_set_decisions_enabled(true)
	_layout_items()


## Müşteri gelişi: zil, yüz ve belgeler yerine oturur, banknotlar sırayla "pat" diye düşer.
## Banknotlar ve belgeler pencerenin yuvasından kayarak gelir, sırayla "pat" diye masaya oturur.
func _animate_arrival() -> void:
	for old in _arrival_tweens:
		old.kill()
	_arrival_tweens.clear()
	Feel.sfx("door_buzz" if int(shift.stats["served"]) % 4 == 3 else "bell")
	var delay := 0.55  # müşteri yürüyüp durana kadar
	var tiles: Array = _docs_row.get_children() + _notes_grid.get_children()
	for tile: DraggableItem in tiles:
		var target := tile.home_position
		if Feel.instant:
			tile.position = target
			continue
		tile.position = Vector2(target.x, -120.0)
		tile.modulate.a = 0.0
		var tween := tile.create_tween()
		_arrival_tweens.append(tween)
		tween.tween_interval(delay)
		tween.tween_callback(Feel.sfx.bind("paper_slide"))
		tween.tween_property(tile, "modulate:a", 1.0, 0.05)
		tween.tween_property(tile, "position", target, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_callback(Feel.sfx.bind("note_drop"))
		delay += 0.16


## Müşterinin getirdiği belgeler (varsa) tezgâhta kutu olarak durur.
## Müşterinin getirdiği belgeler (varsa) tezgâhta kâğıt olarak durur.
func _show_documents() -> void:
	if _shown.id_card != null:
		var card := _shown.id_card
		var tile := DocTile.new()
		tile.setup(DocTile.KIND_ID, tr("DOC_ID"), card.holder_name, tr("DOC_NUMBER") % card.number)
		tile.tapped.connect(_open_document_sheet)
		tile.released.connect(_on_item_released)
		_docs_row.add_child(tile)
	if _shown.declaration != null:
		var declaration := _shown.declaration
		var tile := DocTile.new()
		tile.setup(DocTile.KIND_DECLARATION, tr("DOC_DECLARATION"), declaration.holder_name, _money(declaration.amount_minor, "PL"))
		tile.tapped.connect(_open_document_sheet)
		tile.released.connect(_on_item_released)
		_docs_row.add_child(tile)


## Para sayma makinesi (satın alınmışsa): tezgâhtaki banknotların para birimi başına toplamı.
func _show_counter_total() -> void:
	_count_label.visible = career.has_tool("counter")
	if not _count_label.visible:
		return
	var totals := {}
	for note in _shown.notes:
		totals[note.currency] = int(totals.get(note.currency, 0)) + note.value_minor()
	var parts: PackedStringArray = []
	for code: String in totals:
		parts.append(_money(int(totals[code]), code))
	_count_label.text = tr("DESK_COUNTER_TOTAL") % ", ".join(parts)


func _clear_customer(leaving := false) -> void:
	_shown_laid_out = false
	for layer: Control in [_docs_row, _notes_grid]:
		for child in layer.get_children():
			layer.remove_child(child)
			if leaving and not Feel.instant and is_inside_tree():
				_sweep_away(child as Control)
			else:
				child.queue_free()
	_count_label.visible = false
	if not leaving:
		var old_ink := _surface.get_node_or_null("ReceiptInk")
		if old_ink != null:
			old_ink.queue_free()
			_surface.remove_child(old_ink)
	for child in _pay_row.get_children():
		child.queue_free()
		_pay_row.remove_child(child)
	if leaving:
		_booth.send_customer_away()
	else:
		_booth.clear_customer()
	_bubble_label.text = tr("DESK_WAITING")
	_hint_label.text = ""
	_set_decisions_enabled(false)


## İşlem bitti: masadaki kâğıtlar yuvadan geri kayıp gider (geçici düğüm; ad çakışmasın diye yeniden adlandırılır).
func _sweep_away(item: Control) -> void:
	item.name = "Leaving"
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.add_child(item)
	item.global_position = item.global_position
	var tween := item.create_tween()
	tween.tween_property(item, "position:y", item.position.y - 140.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(item, "modulate:a", 0.0, 0.3)
	tween.tween_callback(item.queue_free)


func _set_decisions_enabled(enabled: bool) -> void:
	for button in [_complete_button, _reject_button, _police_button]:
		button.disabled = not enabled


func _speech(customer: Customer) -> String:
	var amount := customer.nominal_minor(customer.currency) if customer.intent == Customer.INTENT_SELL else customer.requested_foreign_minor
	var key := "DESK_SELL_SAY" if customer.intent == Customer.INTENT_SELL else "DESK_BUY_SAY"
	return tr(key) % [Money.format(amount, "", _locale()), customer.currency]


func _decide(decision: String, reason: String) -> void:
	if shift == null or shift.current == null or model == null:
		return
	_close_sheet()
	var verdict := shift.current_verdict
	var result := shift.submit(model.build_move(decision, reason))
	_show_slip(result, verdict)
	_feedback(decision, result)
	if not bool(result["correct"]):
		Analytics.log_event("mistake", {"decision": decision, "reasons": verdict.reasons})
	if GameSession.mode != null:
		_on_mode_submit(GameSession.mode.on_submit(result))
	_shown = null
	model = null
	_clear_customer(true)
	_sync()


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
	if not near_end and not _overtime_button.visible and _sheet == null:
		return
	var offer := _overtime_offer()
	_overtime_button.visible = bool(offer["visible"]) and near_end and _sheet == null
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


## Fişe mühür izi basılır (bir sonraki müşteriye dek kalır).
func _ink_receipt(decision: String) -> void:
	var colors := {Verdict.DECISION_COMPLETE: UiKit.GOOD_COLOR, Verdict.DECISION_REJECT: UiKit.WARN_COLOR, Verdict.DECISION_POLICE: UiKit.BAD_COLOR}
	var ink := _label(tr("STAMP_%s" % decision.to_upper()), &"StampLabel", "ReceiptInk")
	ink.add_theme_font_size_override("font_size", 44)
	ink.add_theme_color_override("font_color", colors[decision])
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ink.rotation = -0.22
	ink.modulate.a = 0.0
	ink.z_index = 6
	_surface.add_child(ink)
	ink.position = _receipt.global_position - _surface.global_position + Vector2(18.0, 40.0)
	var tween := ink.create_tween()
	tween.tween_interval(0.0 if Feel.instant else 0.12)
	tween.tween_property(ink, "modulate:a", 0.85, 0.05)


## Mod koşusunda işlem sonrası: eklenen yeni kuralı duyur, araç düğmelerini yenile.
func _on_mode_submit(outcome: Dictionary) -> void:
	var rule_id := str(outcome.get("rule_added", ""))
	if rule_id.is_empty():
		return
	_refresh_tools()
	(_midday_banner.get_child(0) as Label).text = tr("MODE_NEW_RULE") % tr("RULE_%s" % rule_id)
	_midday_banner.visible = true
	_midday_left = MIDDAY_SECONDS


## Karar anının "hissi": damga, sarsıntı, ses, titreşim ve (doğruysa) kazanç yazısı.
func _feedback(decision: String, result: Dictionary) -> void:
	_ink_receipt(decision)
	var colors := {Verdict.DECISION_COMPLETE: UiKit.GOOD_COLOR, Verdict.DECISION_REJECT: UiKit.WARN_COLOR, Verdict.DECISION_POLICE: UiKit.BAD_COLOR}
	Feel.stamp(self, tr("STAMP_%s" % decision.to_upper()), colors[decision])
	var correct := bool(result["correct"])
	Feel.shake(self, 4.0 if correct else 8.0)
	Feel.sfx("stamp")
	get_tree().create_timer(0.05).timeout.connect(Feel.sfx.bind("ink_press"))
	if decision == Verdict.DECISION_POLICE:
		get_tree().create_timer(0.25).timeout.connect(Feel.sfx.bind("siren"))
	elif decision == Verdict.DECISION_COMPLETE and correct:
		get_tree().create_timer(0.3).timeout.connect(Feel.sfx.bind("drawer"))
	Feel.haptic(25 if correct else 70)
	Fx.splat(self, size / 2.0, colors[decision])
	if correct:
		Fx.coin_burst(self, _pay_label.global_position + Vector2(40, 30), 7)
		Feel.float_text(self, "+" + _money(int(result["bonus_minor"]), "PL"), UiKit.GOOD_COLOR, _pay_label.global_position + Vector2(0, 40))
		get_tree().create_timer(0.12).timeout.connect(Feel.sfx.bind("coin"))
	else:
		Fx.flash(self, UiKit.BAD_COLOR, 0.3 if bool(result["fined"]) else 0.18)
		get_tree().create_timer(0.12).timeout.connect(Feel.sfx.bind("error"))


func _on_note_dropped(note_index: int, fate: String) -> void:
	_set_fate(note_index, fate)


func _set_fate(note_index: int, fate: String, seat := true) -> void:
	if model == null:
		return
	model.set_fate(note_index, fate)
	var tile := _notes_grid.get_node_or_null("NoteTile%d" % note_index) as NoteTile
	if tile == null:
		return
	tile.set_fate(fate)
	if seat:
		_seat_tile(tile, fate)


## Banknot kaderine göre yerleşir: iade / el koy tepsisine (küçülerek) ya da kabulde masadaki yerine döner.
func _seat_tile(tile: NoteTile, fate: String) -> void:
	tile.z_index = 0
	if fate == Verdict.FATE_ACCEPT:
		tile.scale = Vector2.ONE
		Feel.slide_to(tile, tile.home_position)
		return
	var zone := _zones_row.get_node_or_null("Zone_%s" % fate) as Control
	if zone == null or not zone.is_inside_tree():
		return
	var shrink := 0.6
	tile.pivot_offset = tile.size / 2.0
	tile.scale = Vector2(shrink, shrink)
	var center := zone.global_position + zone.size / 2.0 - _notes_grid.global_position
	Feel.slide_to(tile, center - tile.size / 2.0)
	tile.z_index = 2
	Feel.sfx("crumple" if fate == Verdict.FATE_CONFISCATE else "note_drop", 0.9)


## Bırakılan nesne: banknot bir tepsinin üstündeyse o kadere geçer; masaya bırakılırsa orada kalır (tepsiden çıkarsa kabul).
func _on_item_released(item: DraggableItem, center: Vector2) -> void:
	var note_tile := item as NoteTile
	if note_tile != null and model != null:
		for zone: FateZone in _zones_row.get_children():
			if zone.get_global_rect().has_point(center):
				_set_fate(note_tile.index, zone.fate)
				return
		if model.fate(note_tile.index) != Verdict.FATE_ACCEPT:
			_set_fate(note_tile.index, Verdict.FATE_ACCEPT, false)
			note_tile.scale = Vector2.ONE
	var layer_rect := Rect2(Vector2.ZERO, _items.size)
	var local := item.position
	local.x = clampf(local.x, 0.0, maxf(0.0, layer_rect.size.x - item.size.x))
	local.y = clampf(local.y, 30.0, maxf(30.0, layer_rect.size.y - item.size.y + 40.0))
	Feel.slide_to(item, local, 0.1)
	if note_tile == null or model == null or model.fate(note_tile.index) == Verdict.FATE_ACCEPT:
		item.home_position = local
	Feel.sfx("note_drop", 0.95)


## Müşterinin kâğıtlarını masaya dizer: önce belgeler, altında banknotlar; sığmazsa küçültür. Hafif çarpık durur, yuvadan kayarak gelir.
func _layout_items(animate := true) -> void:
	for attempt in 4:
		if _items.size.x >= 100.0:
			break
		await get_tree().process_frame
	if _shown == null or not is_instance_valid(_items):
		return
	_shown_laid_out = true
	var rng := Seed.rng("desk-layout|%d" % _shown.id)
	var area := Rect2(10.0, 54.0, _items.size.x - 20.0, _items.size.y - 60.0)
	var docs: Array = _docs_row.get_children()
	var notes: Array = _notes_grid.get_children()
	var y := area.position.y
	if not docs.is_empty():
		var gap := 10.0
		var width := minf(DOC_MAX_WIDTH, (area.size.x - gap * (docs.size() - 1)) / docs.size())
		var height := 0.0
		for tile: DraggableItem in docs:
			tile.size = Vector2(width, tile.get_combined_minimum_size().y)
			height = maxf(height, tile.size.y)
		for i in docs.size():
			var tile := docs[i] as DraggableItem
			tile.position = Vector2(area.position.x + i * (width + gap), y)
			_pose(tile, rng, 0.03)
		y += height + 10.0
	if not notes.is_empty():
		var columns := 2 if notes.size() <= FEW_NOTES else (3 if notes.size() <= MID_NOTES else 4)
		var gap := 10.0
		var rows := ceili(float(notes.size()) / columns)
		var available_height := area.end.y - y
		var scale_factor := 1.0
		var cell := Vector2.ZERO
		# Sığana dek küçült; çok banknotta satırlar üst üste biner (gerçek masa gibi), okunurluk için alt sınır var.
		for pass_index in 10:
			cell = Vector2.ZERO
			for tile: NoteTile in notes:
				tile.view.setup(tile.view.note, _note_scale * scale_factor, uv_lamp, false, magnifier)
				tile.size = tile.get_combined_minimum_size()
				cell = cell.max(tile.size)
			var need_width := columns * cell.x + (columns - 1) * gap
			var need_height := cell.y + (rows - 1) * cell.y * OVERLAP_MIN
			var fit := minf(area.size.x / need_width, available_height / need_height)
			if fit >= 1.0 or scale_factor <= MIN_NOTE_SCALE:
				break
			scale_factor = maxf(MIN_NOTE_SCALE, scale_factor * maxf(0.6, fit * 0.96))
		var row_step := cell.y + gap
		if rows > 1:
			row_step = clampf((available_height - cell.y) / (rows - 1), cell.y * OVERLAP_MIN, cell.y + gap)
		var used_columns := mini(columns, notes.size())
		var left := area.position.x + (area.size.x - (used_columns * cell.x + (used_columns - 1) * gap)) / 2.0
		for i in notes.size():
			var tile := notes[i] as NoteTile
			tile.position = Vector2(left + (i % columns) * (cell.x + gap), y + (i / columns) * row_step)
			_pose(tile, rng, 0.045)
	if animate:
		_animate_arrival()
	else:
		# Yeniden dizim: geliş animasyonu sürüyorsa yeni yerlere göre baştan başlar; bittiyse kâğıtlar yeni yerine geçer.
		var animating := _arrival_tweens.any(func(tween: Tween) -> bool: return tween.is_valid() and tween.is_running())
		for tile: DraggableItem in docs + notes:
			tile.position = tile.home_position
			tile.modulate.a = 1.0
		if animating:
			_animate_arrival()


## Nesne hafif çarpık ve kaymış durur (masada özenle dizilmemiş gibi); dönme merkezden.
func _pose(tile: DraggableItem, rng: RandomNumberGenerator, max_angle: float) -> void:
	tile.pivot_offset = tile.size / 2.0
	tile.rotation = rng.randf_range(-max_angle, max_angle)
	tile.position += Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-3.0, 3.0))
	# Her koşulda masanın içinde kalır (sığmayan son satır biraz üst üste biner).
	tile.position.y = clampf(tile.position.y, 30.0, maxf(30.0, _items.size.y - tile.size.y - 6.0))
	tile.position.x = clampf(tile.position.x, 2.0, maxf(2.0, _items.size.x - tile.size.x - 2.0))
	tile.home_position = tile.position


func _on_uv_toggled(on: bool) -> void:
	uv_lamp = on
	if on:
		Feel.sfx("uv_on")
	for tile in _notes_grid.get_children():
		(tile as NoteTile).set_uv_lamp(on)


func _on_magnifier_toggled(on: bool) -> void:
	magnifier = on
	if on:
		Feel.sfx("lens")
	for tile in _notes_grid.get_children():
		(tile as NoteTile).set_magnifier(on)


func _refresh_payment() -> void:
	if model == null:
		return
	for code in model.payment_codes(shift.ctx.book.local_code):
		var button := _pay_row.get_node_or_null("PayButton_%s" % code) as Button
		if button != null:
			button.text = tr("DESK_PAYMENT") % _money(model.paid_minor(code), code)


# --- Uyarı fişi ------------------------------------------------------------------

func _show_slip(result: Dictionary, verdict: Verdict) -> void:
	for child in _slip_box.get_children():
		_slip_box.remove_child(child)
		child.queue_free()
	var title := ""
	if bool(result["correct"]):
		_slip.theme_type_variation = &"SlipOkPanel"
		title = tr("SLIP_TITLE_OK") % _money(int(result["bonus_minor"]), "PL")
		if int(result["skimmed_minor"]) > 0:
			title += "  (+%s)" % _money(int(result["skimmed_minor"]), "PL")
	elif bool(result["fined"]):
		_slip.theme_type_variation = &"CardBrokenPanel"
		title = tr("SLIP_TITLE_FINE") % _money(int(result["fine_minor"]), "PL")
	else:
		_slip.theme_type_variation = &"SlipPanel"
		title = tr("SLIP_TITLE_WARNING")
	_slip_box.add_child(_label(title, &"SlipTitle", "SlipTitle"))
	var lines := Slip.lines(result["mistakes"], verdict)
	for line in lines:
		var text := _label("• " + _format_line(line), &"SlipLine")
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_slip_box.add_child(text)
	if not bool(result["correct"]) and not bool(result["fined"]):
		var left := maxi(0, int(shift.ctx.balance["shift"]["free_mistakes"]) - int(shift.stats["mistake_transactions"]))
		_slip_box.add_child(_label(tr("DESK_FREE_LEFT") % left, &"SmallLabel"))
	_slip.visible = true
	_slip_left = SLIP_SECONDS


func _format_line(line: Dictionary) -> String:
	var args: Array = []
	for arg: Variant in line["args"]:
		if arg is String and (arg as String).begins_with("@"):
			args.append(tr((arg as String).substr(1)))
		elif arg is Dictionary and (arg as Dictionary).has("money"):
			args.append(_money(int(arg["money"][0]), str(arg["money"][1])))
		else:
			args.append(arg)
	var template := tr(str(line["key"]))
	return template % args if not args.is_empty() else template


func _on_slip_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_slip.visible = false
		_slip_left = 0.0


# --- Sayfalar (alttan açılan paneller) ---------------------------------------------

func _open_sheet(title_key: String, closable := true) -> VBoxContainer:
	_close_sheet()
	_sheet_closable = closable
	_sheet = Control.new()
	_sheet.name = "Sheet"
	_sheet.z_index = 40  # atmosfer katmanının (z 30) üstünde: belgeler okunaklı kalsın
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_sheet)
	var dim := ColorRect.new()
	dim.color = UiKit.DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and _sheet_closable:
			_close_sheet())
	_sheet.add_child(dim)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SheetPanel"
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_sheet.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := _label(tr(title_key), &"SheetTitle", "SheetTitle")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	if closable:
		var close := UiKit.icon_button("close", tr("COMMON_CLOSE"), "CloseSheetButton", true, false, 64.0)
		close.pressed.connect(_close_sheet)
		header.add_child(close)
	return content


func _set_sheet_title(content: VBoxContainer, text: String) -> void:
	(content.find_child("SheetTitle", true, false) as Label).text = text


func _close_sheet() -> void:
	_sheet_pauses = false
	if _sheet != null:
		_sheet.queue_free()
		remove_child(_sheet)
		_sheet = null


func _scroll(min_height: float) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = min_height
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	list.set_meta("scroll", scroll)
	return list


func _open_inspect_sheet(index: int) -> void:
	if model == null or index >= _shown.notes.size():
		return
	var note := _shown.notes[index]
	var content := _open_sheet("DESK_INSPECT_TITLE")
	_set_sheet_title(content, "%s %d" % [note.currency, note.denom])
	var center := CenterContainer.new()
	var big := BanknoteView.new()
	big.name = "InspectView"
	big.setup(note, INSPECT_SCALE, uv_lamp, false, magnifier)
	center.add_child(big)
	content.add_child(center)
	for text in [tr("DESK_INFO_SERIAL") % note.serial, tr("DESK_INFO_SIZE") % [note.size_mm.x, note.size_mm.y],
			tr("DESK_INFO_PORTRAIT") % note.portrait.get_slice("_", 1), tr("DESK_INFO_SERIES") % note.series_id]:
		content.add_child(_label(text, &"SheetInfo"))
	var microtext := _label("", &"SheetInfo", "InspectMicrotext")
	microtext.visible = magnifier
	microtext.text = tr("DESK_INFO_MICROTEXT") % note.microtext
	content.add_child(microtext)
	var fates := HBoxContainer.new()
	fates.add_theme_constant_override("separation", 8)
	content.add_child(fates)
	for fate in [Verdict.FATE_ACCEPT, Verdict.FATE_RETURN, Verdict.FATE_CONFISCATE]:
		var button := _button(tr("FATE_%s" % fate.to_upper()), "Inspect_%s" % fate, &"SegmentButton", 80.0)
		button.toggle_mode = true
		button.button_pressed = model.fate(index) == fate
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			_set_fate(index, fate)
			for other in fates.get_children():
				(other as Button).set_pressed_no_signal(other.name == "Inspect_%s" % fate))
		fates.add_child(button)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	content.add_child(tools)
	if career.has_tool("uv"):
		var lamp := _button(tr("TOOL_UV"), "InspectUvButton", &"WarnButton", 80.0)
		lamp.toggle_mode = true
		lamp.button_pressed = uv_lamp
		lamp.toggled.connect(func(on: bool) -> void:
			_uv_button.button_pressed = on
			big.set_tools(on, big.backlight, big.magnifier))
		tools.add_child(lamp)
	if career.has_tool("magnifier"):
		var lens := _button(tr("TOOL_MAGNIFIER"), "InspectMagnifierButton", &"WarnButton", 80.0)
		lens.toggle_mode = true
		lens.button_pressed = magnifier
		lens.toggled.connect(func(on: bool) -> void:
			_magnifier_button.button_pressed = on
			microtext.visible = on
			big.set_tools(big.uv_lamp, big.backlight, on))
		tools.add_child(lens)
	if shift.ctx.rule_active("R_WATERMARK"):
		# Basılı tutunca arka ışık: bırakınca söner.
		var light := _button(tr("TOOL_BACKLIGHT"), "InspectBacklightButton", &"WarnButton", 80.0)
		light.button_down.connect(func() -> void: big.set_tools(big.uv_lamp, true, big.magnifier))
		light.button_up.connect(func() -> void: big.set_tools(big.uv_lamp, false, big.magnifier))
		tools.add_child(light)
	for button in tools.get_children():
		(button as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Kimlik / kaynak beyanı ayrıntı sayfası.
func _open_document_sheet(kind: String) -> void:
	if _shown == null:
		return
	var content := _open_sheet("DOC_ID" if kind == DocTile.KIND_ID else "DOC_DECLARATION")
	if kind == DocTile.KIND_ID and _shown.id_card != null:
		content.add_child(DocumentViews.build_id(_shown.id_card))
	elif kind == DocTile.KIND_DECLARATION and _shown.declaration != null:
		content.add_child(DocumentViews.build_declaration(_shown.declaration))


func _open_reason_sheet() -> void:
	if model == null:
		return
	var content := _open_sheet("DESK_REASON_TITLE")
	var list := _scroll(REASON_LIST_HEIGHT)
	content.add_child(list.get_meta("scroll"))
	for rule_id in shift.ctx.rules.active_ids(shift.ctx.day):
		var button := _button(tr("RULE_%s" % rule_id), "Reason_%s" % rule_id, &"GhostButton", 76.0)
		button.pressed.connect(_decide.bind(Verdict.DECISION_REJECT, rule_id))
		list.add_child(button)


## 0-9 / C / ⌫ tuş takımı. `text_holder` bir Array: [0] metni tutar; her tuşta `on_change` çağrılır. En fazla 7 hane.
func _keypad(text_holder: Array, on_change: Callable) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for key in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "<"]:
		var button := _button(key if key != "<" else "⌫", "Key_%s" % ("back" if key == "<" else key), &"KeyButton", 84.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			Feel.sfx("calc_key", 0.94 + randf() * 0.12)
			var text: String = text_holder[0]
			match key:
				"C":
					text = ""
				"<":
					text = text.left(maxi(0, text.length() - 1))
				_:
					if text.length() < 7 and not (text.is_empty() and key == "0"):
						text += key
			text_holder[0] = text
			on_change.call())
		grid.add_child(button)
	return grid


func _open_numpad_sheet(code: String) -> void:
	if model == null:
		return
	var content := _open_sheet("DESK_NUMPAD_TITLE")
	_set_sheet_title(content, tr("DESK_NUMPAD_TITLE") % code)
	var holder := ["" if model.paid_minor(code) == 0 else str(model.paid_minor(code) / Money.UNIT)]
	var display := _label("", &"BigNumber", "NumpadDisplay")
	display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(display)
	var refresh := func() -> void:
		display.text = "%s %s" % [holder[0] if not str(holder[0]).is_empty() else "0", code]
	refresh.call()
	content.add_child(_keypad(holder, refresh))
	var ok := _button(tr("DESK_OK"), "NumpadOk", &"", 88.0)
	ok.pressed.connect(func() -> void:
		Feel.sfx("pen_scratch")
		model.set_paid(code, (int(holder[0]) if not str(holder[0]).is_empty() else 0) * Money.UNIT)
		_refresh_payment()
		_close_sheet())
	content.add_child(ok)


## Kur hesaplayıcı (satın alınmış araç): döviz tutarını yaz, PL karşılığını ALIŞ ve SATIŞ kuruyla gör (5 PL yuvarlaması dahil).
func _open_rate_sheet() -> void:
	var content := _open_sheet("TOOL_RATE_CALC")
	var codes := shift.ctx.book.foreign_codes(shift.ctx.day)
	var state := {"code": codes[0] if not codes.is_empty() else ""}
	var holder := [""]
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	content.add_child(tabs)
	var display := _label("", &"BigNumber", "RateDisplay")
	display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(display)
	var buy_label := _label("", &"GoalLabel", "RateBuy")
	var sell_label := _label("", &"GoalLabel", "RateSell")
	content.add_child(buy_label)
	content.add_child(sell_label)
	var refresh := func() -> void:
		var units := int(holder[0]) if not str(holder[0]).is_empty() else 0
		var minor := units * Money.UNIT
		var midday := shift.ctx.use_midday_rates()
		display.text = "%d %s" % [units, state["code"]]
		buy_label.text = tr("DESK_RATE_BUY_RESULT") % _money(shift.ctx.rates.buy_payout(state["code"], minor, shift.ctx.day, midday), "PL")
		sell_label.text = tr("DESK_RATE_SELL_RESULT") % _money(shift.ctx.rates.sell_cost(state["code"], minor, shift.ctx.day, midday), "PL")
	var group := ButtonGroup.new()
	for code in codes:
		var tab := _button(code, "RateTab_%s" % code, &"SegmentButton", 64.0)
		tab.toggle_mode = true
		tab.button_group = group
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(func() -> void:
			state["code"] = code
			refresh.call())
		tabs.add_child(tab)
		if code == state["code"]:
			tab.button_pressed = true
	content.add_child(_keypad(holder, refresh))
	refresh.call()


## Kasa görünümü: para birimi başına kupür sayıları ve toplam.
## Ofis düğmesi: talimat ilerlemesi + okunmamış not rozeti; yeni not düşünce tüp sesi ve kısa dürtme.
func _sync_office() -> void:
	if _office_button == null:
		return
	var has_directive := not shift.directive.is_empty()
	_office_button.visible = has_directive or not shift.memos_delivered.is_empty()
	if has_directive:
		var status := Directives.status(shift.directive, shift.stats)
		_office_button.text = tr("DIR_CHIP") % [int(status["progress"]), int(status["target"])]
		var warn := bool(status["failed"]) or (not bool(status["at_least"]) and int(status["progress"]) == int(status["target"]))
		_office_button.ink = Color("E2554A") if warn else Color("F5EEDC")
	else:
		_office_button.text = tr("OFFICE_TITLE")
	_office_button.badge = shift.unread_memos()
	if shift.memos_delivered.size() > _memos_announced:
		_memos_announced = shift.memos_delivered.size()
		_announce_memo()


func _announce_memo() -> void:
	var latest: Dictionary = shift.memos_delivered[-1]
	Feel.sfx("phone" if str(latest["kind"]) in ["directive_change", "call"] else "tube")
	Feel.haptic(30)
	if Feel.instant or _office_button == null:
		return
	Fx.capsule_drop(self, _office_button.global_position + Vector2(_office_button.size.x / 2.0, 20.0))
	_office_button.pivot_offset = _office_button.size / 2.0
	var tween := create_tween()
	for i in 3:
		tween.tween_property(_office_button, "scale", Vector2(1.12, 1.12), 0.12)
		tween.tween_property(_office_button, "scale", Vector2.ONE, 0.12)


func _open_office_sheet() -> void:
	var content := _open_sheet("OFFICE_TITLE")
	_sheet_pauses = true
	var list := _scroll(620)
	content.add_child(list.get_meta("scroll"))
	if not shift.directive.is_empty():
		var def := shift.directive
		var status := Directives.status(def, shift.stats)
		var card := PanelContainer.new()
		card.name = "DirectiveCard"
		card.theme_type_variation = &"SlipPanel"
		list.add_child(card)
		var box := VBoxContainer.new()
		card.add_child(box)
		box.add_child(_label(tr("DIR_TITLE"), &"SlipTitle"))
		var text := _label(UiKit.directive_text(def), &"SlipLine", "DirectiveText")
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(text)
		var bar := ProgressBar.new()
		bar.name = "DirectiveBar"
		bar.max_value = maxi(1, int(status["target"]))
		bar.value = mini(int(status["progress"]), int(bar.max_value))
		bar.show_percentage = false
		bar.custom_minimum_size.y = 18.0
		box.add_child(bar)
		box.add_child(_label(tr("DIR_PROGRESS") % [int(status["progress"]), int(status["target"])], &"SlipLine", "DirectiveProgress"))
		for line in UiKit.directive_terms(def):
			box.add_child(_label(line, &"SlipLine"))
	list.add_child(_label(tr("OFFICE_INBOX"), &"CardTitle"))
	if shift.memos_delivered.is_empty():
		list.add_child(_label(tr("OFFICE_NO_MEMOS"), &"CardDetail", "NoMemos"))
	var index := shift.memos_delivered.size()
	while index > 0:  # en yeni üstte
		index -= 1
		list.add_child(_memo_card(shift.memos_delivered[index]))


## Telefon notunun seçenekleri: cevaplanmadıysa düğmeler, cevaplandıysa seçilen cevap soluk yazılır.
func _add_call_options(box: VBoxContainer, memo: Dictionary) -> void:
	if not str(memo["answered"]).is_empty():
		for option: Dictionary in memo["options"]:
			if str(option["id"]) == str(memo["answered"]):
				box.add_child(_label("✓ " + tr(str(option["text_key"])), &"CardDetail", "CallAnswered"))
		return
	for option: Dictionary in memo["options"]:
		var button := UiKit.icon_button("phone", tr(str(option["text_key"])), "CallOption_%s_%s" % [memo["id"], option["id"]], true, false, 64.0)
		button.pressed.connect(func() -> void:
			if shift.answer_call(str(memo["id"]), str(option["id"])):
				Feel.sfx("note_drop")
				_open_office_sheet()
				_sync_office())
		box.add_child(button)


func _memo_card(memo: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.name = "Memo_%s" % memo["id"]
	card.theme_type_variation = &"CardPanel"
	var box := VBoxContainer.new()
	card.add_child(box)
	box.add_child(_label(tr("OFFICE_FROM") % tr(str(memo["sender_key"])), &"CardDetail"))
	var body := ""
	match str(memo["kind"]):
		"call":
			body = tr(str(memo["text_key"]))
		"stolen_add":
			body = tr(str(memo["text_key"])) % [memo.get("from_serial", "?"), memo.get("to_serial", "?")]
		"directive_change":
			body = tr(str(memo["text_key"])) % UiKit.directive_text(Directives.by_id(str(memo.get("directive_id", ""))))
		_:
			body = tr(str(memo["text_key"]))
	var text := _label(body, &"CardTitle", "MemoText")
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(text)
	if str(memo["kind"]) == "call":
		_add_call_options(box, memo)
		return card
	if not bool(memo["read"]):
		var stamp := UiKit.icon_button("stamp", tr("OFFICE_READ"), "MemoStamp_%s" % memo["id"], true, false, 64.0)
		stamp.pressed.connect(func() -> void:
			shift.mark_memo_read(str(memo["id"]))
			Feel.sfx("stamp")
			_open_office_sheet()
			_sync_office())
		box.add_child(stamp)
	return card


func _open_till_sheet() -> void:
	var content := _open_sheet("TOOL_TILL")
	var list := _scroll(560)
	content.add_child(list.get_meta("scroll"))
	var codes: Array[String] = [shift.ctx.book.local_code]
	codes.append_array(shift.ctx.book.foreign_codes(shift.ctx.day))
	for code in codes:
		var parts: PackedStringArray = []
		var denoms := shift.ctx.book.denominations(code)
		denoms.reverse()
		for denom in denoms:
			var count := shift.ctx.till.count(code, denom)
			if count > 0:
				parts.append("%d × %d" % [count, denom])
		var card := PanelContainer.new()
		card.name = "TillRow_%s" % code
		card.theme_type_variation = &"CardPanel"
		list.add_child(card)
		var box := VBoxContainer.new()
		card.add_child(box)
		box.add_child(_label("%s — %s" % [code, _money(shift.ctx.till.total_minor(code), code)], &"CardTitle"))
		var detail := _label("  ".join(parts) if not parts.is_empty() else tr("DESK_TILL_EMPTY"), &"CardDetail")
		detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(detail)


func _open_calculator_sheet() -> void:
	var content := _open_sheet("TOOL_CALC")
	var display := _label(_calculator.display, &"BigNumber", "CalcDisplay")
	display.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content.add_child(display)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content.add_child(grid)
	var layout := [["7", "7"], ["8", "8"], ["9", "9"], ["÷", "/"], ["4", "4"], ["5", "5"], ["6", "6"], ["×", "*"],
		["1", "1"], ["2", "2"], ["3", "3"], ["−", "-"], ["C", "C"], ["0", "0"], [".", "."], ["+", "+"]]
	for entry in layout:
		var key: String = entry[1]
		var names := {"/": "div", "*": "mul", "-": "sub", "+": "add", ".": "dot"}
		var button := _button(str(entry[0]), "Calc_%s" % names.get(key, key), &"KeyButton", 80.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			_calculator.press(key)
			display.text = _calculator.display)
		grid.add_child(button)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	content.add_child(bottom)
	for entry in [["⌫", "<", "Calc_back"], ["=", "=", "Calc_equals"]]:
		var button := _button(str(entry[0]), str(entry[2]), &"KeyButton", 80.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			_calculator.press(str(entry[1]))
			display.text = _calculator.display)
		bottom.add_child(button)


func _open_info_sheet(start_rule := "") -> void:
	var content := _open_sheet("TOOL_BOOK")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	content.add_child(tabs)
	var body := VBoxContainer.new()
	content.add_child(body)
	var group := ButtonGroup.new()
	var rates_tab := _button(tr("DESK_RATES"), "InfoRatesTab", &"SegmentButton", 64.0)
	var rules_tab := _button(tr("DESK_RULES"), "InfoRulesTab", &"SegmentButton", 64.0)
	var buttons: Array[Button] = [rates_tab, rules_tab]
	var has_bulletin := not shift.ctx.bulletin.stolen_ranges.is_empty() or not shift.ctx.bulletin.wanted_faces.is_empty()
	if has_bulletin:
		var bulletin_tab := _button(tr("MORNING_BULLETIN"), "InfoBulletinTab", &"SegmentButton", 64.0)
		bulletin_tab.pressed.connect(_fill_bulletin.bind(body))
		buttons.append(bulletin_tab)
	for button in buttons:
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
	rates_tab.pressed.connect(_fill_rates.bind(body))
	rules_tab.pressed.connect(func() -> void: _fill_rules(body))
	if start_rule.is_empty():
		rates_tab.button_pressed = true
		_fill_rates(body)
	else:
		rules_tab.button_pressed = true
		_fill_rules(body, start_rule)


func _fill_rates(body: VBoxContainer) -> void:
	_clear_children(body)
	var midday := shift.ctx.use_midday_rates()
	var header := HBoxContainer.new()
	body.add_child(header)
	for text in ["", tr("DESK_BUY_RATE"), tr("DESK_SELL_RATE")]:
		var label := _label(text, &"SheetInfo")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.add_child(label)
	for code in shift.ctx.book.foreign_codes(shift.ctx.day):
		var rates := shift.ctx.rates.rates(code, shift.ctx.day, midday)
		var row := HBoxContainer.new()
		row.name = "RateRow_%s" % code
		body.add_child(row)
		for text in [code, _rate_text(int(rates["buy"])), _rate_text(int(rates["sell"]))]:
			var label := _label(text, &"BigNumber" if text == code else &"CardTitle")
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_child(label)


func _fill_bulletin(body: VBoxContainer) -> void:
	_clear_children(body)
	var list := _scroll(560)
	body.add_child(list.get_meta("scroll"))
	var bulletin := shift.ctx.bulletin
	if not bulletin.stolen_ranges.is_empty():
		list.add_child(_label(tr("MORNING_STOLEN"), &"SlipTitle"))
		var row_index := 0
		for range_def in bulletin.stolen_ranges:
			var from_serial := shift.ctx.book.make_serial(range_def["currency"], range_def["series_id"], int(range_def["from"]))
			var to_serial := shift.ctx.book.make_serial(range_def["currency"], range_def["series_id"], int(range_def["to"]))
			var fresh := "  [%s]" % tr("RULEBOOK_NEW") if row_index >= shift.initial_stolen_count else ""
			list.add_child(_label("%s  %s – %s%s" % [range_def["currency"], from_serial, to_serial, fresh], &"GoalLabel", "StolenRow"))
			row_index += 1
	if not bulletin.wanted_faces.is_empty():
		list.add_child(_label(tr("MORNING_WANTED"), &"SlipTitle"))
		var faces := HBoxContainer.new()
		faces.name = "WantedFaces"
		faces.add_theme_constant_override("separation", 12)
		for face_id in bulletin.wanted_faces:
			var face := FaceView.new()
			face.setup(face_id, "?")
			face.custom_minimum_size = Vector2(110, 110)
			faces.add_child(face)
		list.add_child(faces)


func _fill_rules(body: VBoxContainer, start_rule := "") -> void:
	_clear_children(body)
	var book := RuleBook.new(shift.ctx, career, GameSession.pinned_rules, start_rule)
	book.pins_changed.connect(_refresh_pins)
	body.add_child(book)


## Masaya iğnelenen kural notları (sağ üst): dokununca kılavuz o kuralın sayfasında açılır.
func _refresh_pins() -> void:
	if _pins_box == null:
		return
	_clear_children(_pins_box)
	for rule_id: Variant in GameSession.pinned_rules:
		var note := UiKit.icon_button("pin", tr("RULE_%s" % rule_id), "Pinned_%s" % rule_id, true, true, 44.0)
		note.custom_minimum_size.x = 250.0
		note.pressed.connect(_open_info_sheet.bind(str(rule_id)))
		_pins_box.add_child(note)


func _open_catalog_sheet() -> void:
	var content := _open_sheet("TOOL_CATALOG")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	content.add_child(tabs)
	var body := VBoxContainer.new()
	content.add_child(body)
	var group := ButtonGroup.new()
	var codes: Array[String] = [shift.ctx.book.local_code]
	codes.append_array(shift.ctx.book.foreign_codes(shift.ctx.day))
	for code in codes:
		var button := _button(code, "CatalogTab_%s" % code, &"SegmentButton", 64.0)
		button.toggle_mode = true
		button.button_group = group
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_fill_catalog.bind(body, code))
		tabs.add_child(button)
		if code == codes[0]:
			button.button_pressed = true
	_fill_catalog(body, codes[0])


func _fill_catalog(body: VBoxContainer, code: String) -> void:
	_clear_children(body)
	var book := shift.ctx.book
	var list := _scroll(560)
	body.add_child(list.get_meta("scroll"))
	var general := book.spec(code, book.denominations(code)[0])
	var features := _label("%s · %s" % [tr("DESK_CATALOG_WATERMARK") % tr("WM_SHAPE_%s" % str(general["watermark_shape"]).to_upper()),
		tr("DESK_CATALOG_MICROTEXT") % general["microtext"]], &"CardDetail", "CatalogFeatures")
	features.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(features)
	for series_id in book.series_ids(code):
		var until := book.series_valid_until(code, series_id)
		var span := tr("DESK_CATALOG_SERIES_SPAN") % [book.series_valid_from(code, series_id), until] if until >= 0 else tr("DESK_CATALOG_SERIES_OPEN") % book.series_valid_from(code, series_id)
		list.add_child(_label("%s · %s" % [tr("DESK_CATALOG_SERIES") % [series_id, book.series_prefix(code, series_id)], span], &"CardDetail", "SeriesRow_%s" % series_id))
	for denom in book.denominations(code):
		var spec := book.spec(code, denom)
		var row := HBoxContainer.new()
		row.name = "CatalogRow_%d" % denom
		row.add_theme_constant_override("separation", 10)
		list.add_child(row)
		row.add_child(_swatch(Color(str(spec["color"]))))
		row.add_child(_label("%d" % denom, &"BigNumber"))
		var size: Vector2i = spec["size_mm"]
		var info := _label(tr("DESK_CATALOG_ROW") % [size.x, size.y, str(spec["portrait"]).get_slice("_", 1), tr("DESK_UV_AT_" + str(spec["uv_position"]).to_upper())], &"CardDetail")
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		row.add_child(_swatch(Color(str(spec["uv_color"]))))


func _swatch(color: Color) -> ColorRect:
	var swatch := ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(44, 44)
	return swatch


func _clear_children(node: Control) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


# --- Duraklatma ve gün sonu -------------------------------------------------------

## Hikaye olayı: konuşan karakter, söyledikleri ve (varsa) seçenekler. Vardiya durur; kapatılamaz, bir seçim ya da "Devam" gerekir.
func _open_story_sheet(beat: Dictionary) -> void:
	if _story_db == null:
		_story_db = StoryDb.load_default()
	var character := _story_db.character(str(beat["character"]))
	var content := _open_sheet("", false)
	_sheet.name = "StorySheet"
	_sheet_pauses = true
	_set_sheet_title(content, tr(str(character.get("name_key", "CHAR_RIZA"))))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	content.add_child(row)
	if character.has("icon"):  # yüzü olmayan konuşmacı (radyo)
		var badge := CenterContainer.new()
		badge.custom_minimum_size = Vector2(110, 110)
		badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		badge.add_child(IconView.new(str(character["icon"]), Color("C8892B"), 84.0))
		row.add_child(badge)
	else:
		var face := FaceView.new()
		face.caption = false
		face.setup(int(character.get("face_id", 0)), str(character.get("holder_name", "?")), 110.0)
		face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(face)
	var lines := VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override("separation", 8)
	row.add_child(lines)
	var index := 0
	for line_key: Variant in beat["lines"]:
		index += 1
		var line := _label(tr(str(line_key)), &"", "StoryLine%d" % index)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lines.add_child(line)
	if shift.director.has_choice(beat):
		for option in shift.director.options(beat):
			var text := tr(str(option["text"]))
			if not option["available"]:
				text += "  " + tr("STORY_LOCKED")
			var tempting: bool = option["tag"] in ["bribe", "skim"]
			var button := _button(text, "StoryOption_%s" % option["id"], &"WarnButton" if tempting else &"", 88.0)
			button.disabled = not option["available"]
			button.pressed.connect(_on_story_choice.bind(str(option["id"])))
			content.add_child(button)
	else:
		var next := _button(tr("STORY_OK"), "StoryContinueButton", &"", 88.0)
		next.pressed.connect(_on_story_choice.bind(""))
		content.add_child(next)


func _on_story_choice(option_id: String) -> void:
	if shift.resolve_beat(option_id):
		_close_sheet()
		_sync()


func _open_pause_sheet() -> void:
	var content := _open_sheet("PAUSE_TITLE")
	_sheet_pauses = true
	var resume := _button(tr("PAUSE_RESUME"), "ResumeButton", &"", 96.0)
	resume.pressed.connect(_close_sheet)
	content.add_child(resume)
	var menu := _button(tr("PAUSE_MENU"), "PauseMenuButton", &"GhostButton", 96.0)
	menu.pressed.connect(func() -> void:
		GameSession.abort_mode()
		SceneManager.goto(Scenes.MAIN))
	content.add_child(menu)


## Mesai bitti: özet akşam ekranında; burada son uyarı fişini okumaya zaman bırakır.
func _show_day_end() -> void:
	var content := _open_sheet("MODE_RUN_OVER" if GameSession.mode is EndlessRun else "DESK_SHIFT_OVER", false)
	if GameSession.mode is EndlessRun:
		var endless := GameSession.mode as EndlessRun
		var offer := Monetization.rewarded_offer("endless_continue", endless.continues_used)
		if bool(offer["visible"]):
			var more := _button(tr("AD_ENDLESS_CONTINUE") if bool(offer["enabled"]) else tr("AD_UNAVAILABLE"), "EndlessContinueButton", &"InkButton", 96.0)
			more.disabled = not bool(offer["enabled"])
			more.pressed.connect(_request_endless_continue)
			content.add_child(more)
	elif GameSession.mode == null:
		var overtime := _overtime_offer()
		if bool(overtime["visible"]):
			var extend := _button(tr("AD_OVERTIME") if bool(overtime["enabled"]) else tr("AD_UNAVAILABLE"), "OvertimeEndButton", &"InkButton", 96.0)
			extend.disabled = not bool(overtime["enabled"])
			extend.pressed.connect(_request_overtime)
			content.add_child(extend)
	if GameSession.mode != null:
		var result_button := _button(tr("MODE_SEE_RESULT"), "ToResultButton", &"", 96.0)
		result_button.pressed.connect(func() -> void:
			GameSession.finish_mode()
			SceneManager.goto(Scenes.MODE_RESULT))
		content.add_child(result_button)
		return
	var next := _button(tr("DESK_TO_EVENING"), "ToEveningButton", &"", 96.0)
	next.pressed.connect(func() -> void:
		GameSession.shift = shift
		SceneManager.goto(Scenes.EVENING))
	content.add_child(next)


# --- Yardımcılar -----------------------------------------------------------------

func _locale() -> String:
	return "tr" if TranslationServer.get_locale().begins_with("tr") else "en"


func _money(minor: int, code: String) -> String:
	return Money.format(minor, code, _locale())


## Kur (x RATE_SCALE) -> "29.70": 1 birimin PL karşılığı.
func _rate_text(rate: int) -> String:
	return Money.format(rate / 100, "", _locale())
