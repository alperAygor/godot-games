class_name DeskCounter
extends RefCounted
## Tezgâh (`DeskSurface`): üstte müşterinin kâğıtlarının serbestçe durduğu "Items" alanı (belgeler "DocsRow",
## banknotlar "NotesGrid"), altta "Band": fiş ("Receipt" + ödeme satırı "PayRow") ve üç kader tepsisi ("Trays": Zone_<kader>).
## Kâğıtları dizer, geliş/gidiş animasyonlarını oynatır, sürükle-bırak ve tepsiye oturtmayı yönetir.

## Banknot sayısına göre tezgâh düzeni: az banknot büyük çizilir, çoğu sıkışık.
const NOTE_SCALE_FEW := 1.6
const NOTE_SCALE_MID := 1.25
const NOTE_SCALE_MANY := 0.95
const FEW_NOTES := 2
const MID_NOTES := 6
const BAND_HEIGHT := 148.0
const DOC_MAX_WIDTH := 320.0
const OVERLAP_MIN := 0.6    # satırlar en çok bu oranda üst üste biner
const MIN_NOTE_SCALE := 0.62 # banknot ölçeği alt sınırı (okunurluk)
const PAY_BUTTON_HEIGHT := 88.0

var desk: DeskScreen
var surface: DeskSurface
var items: Control
var notes_grid: Control
var docs_row: Control
var hint_label: Label
var count_label: Label
var receipt: PanelContainer
var pay_row: HBoxContainer
var zones_row: HBoxContainer

var _note_scale := 1.25
var _laid_out := false
var _arrival_tweens: Array[Tween] = []


func _init(owner_desk: DeskScreen) -> void:
	desk = owner_desk


func build() -> DeskSurface:
	surface = DeskSurface.new()
	surface.size_flags_vertical = Control.SIZE_EXPAND_FILL
	surface.custom_minimum_size.y = 300.0
	# Üst bölge: nesnelerin serbestçe durduğu alan; alt bant: fiş + tepsiler
	items = Control.new()
	items.name = "Items"
	items.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items.set_anchors_preset(Control.PRESET_FULL_RECT)
	items.offset_bottom = -BAND_HEIGHT
	surface.add_child(items)
	items.resized.connect(func() -> void:  # ekran/yerleşim değişirse (ilk kare, döndürme) kâğıtlar yeniden dizilir
		if desk._shown != null and _laid_out:
			layout_items(false))
	hint_label = UiKit.label("", &"DeskLabel", "CounterHint")
	hint_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items.add_child(hint_label)
	count_label = UiKit.label("", &"DeskLabel", "CountLabel")
	count_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	count_label.offset_top = 26.0
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.visible = false
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items.add_child(count_label)
	docs_row = Control.new()
	docs_row.name = "DocsRow"
	docs_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	docs_row.set_anchors_preset(Control.PRESET_FULL_RECT)
	items.add_child(docs_row)
	notes_grid = Control.new()
	notes_grid.name = "NotesGrid"
	notes_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notes_grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	items.add_child(notes_grid)
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
	surface.add_child(band)
	receipt = PanelContainer.new()
	receipt.name = "Receipt"
	receipt.theme_type_variation = &"ReceiptPanel"
	receipt.custom_minimum_size.x = 250.0
	var receipt_box := VBoxContainer.new()
	receipt_box.add_theme_constant_override("separation", 0)
	receipt.add_child(receipt_box)
	var receipt_title := UiKit.label(tr("DESK_RECEIPT"), &"GoalLabel", "ReceiptTitle")
	receipt_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	receipt_box.add_child(receipt_title)
	pay_row = HBoxContainer.new()
	pay_row.name = "PayRow"
	pay_row.add_theme_constant_override("separation", 6)
	receipt_box.add_child(pay_row)
	band.add_child(receipt)
	zones_row = HBoxContainer.new()
	zones_row.name = "Trays"
	zones_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zones_row.add_theme_constant_override("separation", 6)
	for fate in [Verdict.FATE_RETURN, Verdict.FATE_ACCEPT, Verdict.FATE_CONFISCATE]:
		var zone := FateZone.new()
		zone.name = "Zone_%s" % fate
		zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		zone.setup(fate)
		zone.dropped.connect(_on_note_dropped)
		zones_row.add_child(zone)
	band.add_child(zones_row)
	return surface


## Müşterinin kâğıtlarını tezgâha koyar: belgeler, para sayma makinesi toplamı, banknotlar, ödeme satırları.
## Dizmek (`layout_items`) ayrı adımdır: masa önce karar düğmelerini açar, sonra dizer.
func show_customer(customer: Customer) -> void:
	hint_label.text = tr("DESK_COUNTER_HINT")
	var count := customer.notes.size()
	_note_scale = NOTE_SCALE_FEW if count <= FEW_NOTES else (NOTE_SCALE_MID if count <= MID_NOTES else NOTE_SCALE_MANY)
	_show_documents(customer)
	_show_counter_total(customer)
	for i in customer.notes.size():
		var tile := NoteTile.new()
		tile.name = "NoteTile%d" % i
		tile.setup(i, customer.notes[i], _note_scale, desk.uv_lamp, desk.magnifier)
		tile.tapped.connect(desk.note_sheets.open_inspect)
		tile.released.connect(_on_item_released)
		notes_grid.add_child(tile)
	for code in desk.model.payment_codes(desk.shift.ctx.book.local_code):
		var pay := UiKit.button("", "PayButton_%s" % code, &"GhostButton", PAY_BUTTON_HEIGHT)
		pay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pay.pressed.connect(desk.note_sheets.open_numpad.bind(code))
		pay_row.add_child(pay)
	refresh_payment()


## Müşterinin getirdiği belgeler (varsa) tezgâhta kâğıt olarak durur.
func _show_documents(customer: Customer) -> void:
	if customer.id_card != null:
		var card := customer.id_card
		var tile := DocTile.new()
		tile.setup(DocTile.KIND_ID, tr("DOC_ID"), card.holder_name, tr("DOC_NUMBER") % card.number)
		tile.tapped.connect(desk.note_sheets.open_document)
		tile.released.connect(_on_item_released)
		docs_row.add_child(tile)
	if customer.declaration != null:
		var declaration := customer.declaration
		var tile := DocTile.new()
		tile.setup(DocTile.KIND_DECLARATION, tr("DOC_DECLARATION"), declaration.holder_name, UiKit.money(declaration.amount_minor, "PL"))
		tile.tapped.connect(desk.note_sheets.open_document)
		tile.released.connect(_on_item_released)
		docs_row.add_child(tile)


## Para sayma makinesi (satın alınmışsa): tezgâhtaki banknotların para birimi başına toplamı.
func _show_counter_total(customer: Customer) -> void:
	count_label.visible = desk.career.has_tool("counter")
	if not count_label.visible:
		return
	var totals := {}
	for note in customer.notes:
		totals[note.currency] = int(totals.get(note.currency, 0)) + note.value_minor()
	var parts: PackedStringArray = []
	for code: String in totals:
		parts.append(UiKit.money(int(totals[code]), code))
	count_label.text = tr("DESK_COUNTER_TOTAL") % ", ".join(parts)


## Tezgâhı boşaltır. `leaving`: kâğıtlar yuvadan geri kayıp gider (fişin mühür izi kalır).
func clear(leaving := false) -> void:
	_laid_out = false
	for layer: Control in [docs_row, notes_grid]:
		for child in layer.get_children():
			layer.remove_child(child)
			if leaving and not Feel.instant and desk.is_inside_tree():
				_sweep_away(child as Control)
			else:
				child.queue_free()
	count_label.visible = false
	if not leaving:
		var old_ink := surface.get_node_or_null("ReceiptInk")
		if old_ink != null:
			old_ink.queue_free()
			surface.remove_child(old_ink)
	for child in pay_row.get_children():
		child.queue_free()
		pay_row.remove_child(child)
	hint_label.text = ""


## İşlem bitti: masadaki kâğıtlar yuvadan geri kayıp gider (geçici düğüm; ad çakışmasın diye yeniden adlandırılır).
func _sweep_away(item: Control) -> void:
	item.name = "Leaving"
	item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(item)
	item.global_position = item.global_position
	var tween := item.create_tween()
	tween.tween_property(item, "position:y", item.position.y - 140.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(item, "modulate:a", 0.0, 0.3)
	tween.tween_callback(item.queue_free)


## Müşteri gelişi: zil, banknotlar ve belgeler pencerenin yuvasından kayarak gelir, sırayla "pat" diye masaya oturur.
func _animate_arrival() -> void:
	for old in _arrival_tweens:
		old.kill()
	_arrival_tweens.clear()
	Feel.sfx("door_buzz" if int(desk.shift.stats["served"]) % 4 == 3 else "bell")
	var delay := 0.55  # müşteri yürüyüp durana kadar
	var tiles: Array = docs_row.get_children() + notes_grid.get_children()
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


func _on_note_dropped(note_index: int, fate: String) -> void:
	set_fate(note_index, fate)


func set_fate(note_index: int, fate: String, seat := true) -> void:
	if desk.model == null:
		return
	desk.model.set_fate(note_index, fate)
	var tile := notes_grid.get_node_or_null("NoteTile%d" % note_index) as NoteTile
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
	var zone := zones_row.get_node_or_null("Zone_%s" % fate) as Control
	if zone == null or not zone.is_inside_tree():
		return
	var shrink := 0.6
	tile.pivot_offset = tile.size / 2.0
	tile.scale = Vector2(shrink, shrink)
	var center := zone.global_position + zone.size / 2.0 - notes_grid.global_position
	Feel.slide_to(tile, center - tile.size / 2.0)
	tile.z_index = 2
	Feel.sfx("crumple" if fate == Verdict.FATE_CONFISCATE else "note_drop", 0.9)


## Bırakılan nesne: banknot bir tepsinin üstündeyse o kadere geçer; masaya bırakılırsa orada kalır (tepsiden çıkarsa kabul).
func _on_item_released(item: DraggableItem, center: Vector2) -> void:
	var note_tile := item as NoteTile
	var model := desk.model
	if note_tile != null and model != null:
		for zone: FateZone in zones_row.get_children():
			if zone.get_global_rect().has_point(center):
				set_fate(note_tile.index, zone.fate)
				return
		if model.fate(note_tile.index) != Verdict.FATE_ACCEPT:
			set_fate(note_tile.index, Verdict.FATE_ACCEPT, false)
			note_tile.scale = Vector2.ONE
	var layer_rect := Rect2(Vector2.ZERO, items.size)
	var local := item.position
	local.x = clampf(local.x, 0.0, maxf(0.0, layer_rect.size.x - item.size.x))
	local.y = clampf(local.y, 30.0, maxf(30.0, layer_rect.size.y - item.size.y + 40.0))
	Feel.slide_to(item, local, 0.1)
	if note_tile == null or model == null or model.fate(note_tile.index) == Verdict.FATE_ACCEPT:
		item.home_position = local
	Feel.sfx("note_drop", 0.95)


## Müşterinin kâğıtlarını masaya dizer: önce belgeler, altında banknotlar; sığmazsa küçültür. Hafif çarpık durur, yuvadan kayarak gelir.
func layout_items(animate := true) -> void:
	for attempt in 4:
		if items.size.x >= 100.0:
			break
		if not desk.is_inside_tree():
			break
		await desk.get_tree().process_frame
		if not is_instance_valid(desk):  # masa beklerken kapandı
			return
	var shown := desk._shown
	if shown == null or not is_instance_valid(items):
		return
	_laid_out = true
	var rng := Seed.rng("desk-layout|%d" % shown.id)
	var area := Rect2(10.0, 54.0, items.size.x - 20.0, items.size.y - 60.0)
	var docs: Array = docs_row.get_children()
	var notes: Array = notes_grid.get_children()
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
				tile.view.setup(tile.view.note, _note_scale * scale_factor, desk.uv_lamp, false, desk.magnifier)
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
	tile.position.y = clampf(tile.position.y, 30.0, maxf(30.0, items.size.y - tile.size.y - 6.0))
	tile.position.x = clampf(tile.position.x, 2.0, maxf(2.0, items.size.x - tile.size.x - 2.0))
	tile.home_position = tile.position


func set_uv_lamp(on: bool) -> void:
	desk.uv_lamp = on
	if on:
		Feel.sfx("uv_on")
	for tile in notes_grid.get_children():
		(tile as NoteTile).set_uv_lamp(on)


func set_magnifier(on: bool) -> void:
	desk.magnifier = on
	if on:
		Feel.sfx("lens")
	for tile in notes_grid.get_children():
		(tile as NoteTile).set_magnifier(on)


func refresh_payment() -> void:
	var model := desk.model
	if model == null:
		return
	for code in model.payment_codes(desk.shift.ctx.book.local_code):
		var button := pay_row.get_node_or_null("PayButton_%s" % code) as Button
		if button != null:
			button.text = tr("DESK_PAYMENT") % UiKit.money(model.paid_minor(code), code)


## Fişe mühür izi basılır (bir sonraki müşteriye dek kalır).
func ink_receipt(decision: String) -> void:
	var ink := UiKit.label(tr("STAMP_%s" % decision.to_upper()), &"StampLabel", "ReceiptInk")
	ink.add_theme_font_size_override("font_size", 44)
	ink.add_theme_color_override("font_color", DeskFeedback.DECISION_COLORS[decision])
	ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ink.rotation = -0.22
	ink.modulate.a = 0.0
	ink.z_index = 6
	surface.add_child(ink)
	ink.position = receipt.global_position - surface.global_position + Vector2(18.0, 40.0)
	var tween := ink.create_tween()
	tween.tween_interval(0.0 if Feel.instant else 0.12)
	tween.tween_property(ink, "modulate:a", 0.85, 0.05)
