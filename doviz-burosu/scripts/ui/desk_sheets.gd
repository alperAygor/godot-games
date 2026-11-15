class_name DeskSheets
extends RefCounted
## Masanın alttan açılan sayfa ("Sheet") yuvası: aynı anda tek sayfa; kapatılabilir mi, vardiya saatini durdurur mu.
## Sayfa düğümü masanın doğrudan çocuğudur ("Sheet", z 40: atmosfer katmanının üstünde). İçerik kuran sınıflar
## (`DeskNoteSheets`, `DeskToolSheets`, `DeskOffice`, `DeskFlowSheets`) `open()` dönen kutuya ekler.

signal opened(sheet_name: String)
signal closed

var desk: DeskScreen
## Açık sayfanın kökü (yoksa null).
var sheet: Control = null
var closable := true
## true iken vardiya saati işlemez (ofis, hikaye, duraklatma).
var pauses := false


func _init(owner_desk: DeskScreen) -> void:
	desk = owner_desk


func is_open() -> bool:
	return sheet != null


func open(title_key: String, can_close := true) -> VBoxContainer:
	close()
	closable = can_close
	sheet = Control.new()
	sheet.name = "Sheet"
	sheet.z_index = 40  # atmosfer katmanının (z 30) üstünde: belgeler okunaklı kalsın
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	desk.add_child(sheet)
	var dim := ColorRect.new()
	dim.color = UiKit.DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and closable:
			close())
	sheet.add_child(dim)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"SheetPanel"
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sheet.add_child(panel)
	# Sayfa ekranın altına yapışır: çentik/gezinme çubuğu boşluğu kadar içeride kalsın (güvenli alan).
	var inset := MarginContainer.new()
	inset.name = "SheetInset"
	var margins := Vector4.ZERO
	var safe := desk.safe_area as SafeAreaContainer
	if safe != null:
		margins = safe.current_safe_margins()
	inset.add_theme_constant_override("margin_left", int(margins.x))
	inset.add_theme_constant_override("margin_top", 0)
	inset.add_theme_constant_override("margin_right", int(margins.z))
	inset.add_theme_constant_override("margin_bottom", int(margins.w))
	panel.add_child(inset)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	inset.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := UiKit.label(tr(title_key), &"SheetTitle", "SheetTitle")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	if can_close:
		var close_button := UiKit.icon_button("close", tr("COMMON_CLOSE"), "CloseSheetButton", true, false, 88.0)
		close_button.custom_minimum_size.x = 88.0
		close_button.pressed.connect(close)
		header.add_child(close_button)
	opened.emit(title_key)
	return content


## Açık sayfanın panelinin ekran dikdörtgeni (yoksa boş).
func panel_rect() -> Rect2:
	if sheet == null or sheet.get_child_count() < 2:
		return Rect2()
	return (sheet.get_child(1) as Control).get_global_rect()


## Sayfanın kökünü yeniden adlandırır (ör. "StorySheet"); `opened` sinyali adı değil başlık anahtarını taşır.
func rename(sheet_name: String) -> void:
	if sheet != null:
		sheet.name = sheet_name


func set_title(content: VBoxContainer, text: String) -> void:
	(content.find_child("SheetTitle", true, false) as Label).text = text


func close() -> void:
	pauses = false
	if sheet != null:
		sheet.queue_free()
		desk.remove_child(sheet)
		sheet = null
		closed.emit()


## Kaydırılabilir liste; dönen kutunun "scroll" meta'sı eklenecek ScrollContainer'dır.
static func scroll(min_height: float) -> VBoxContainer:
	var scroll_box := ScrollContainer.new()
	scroll_box.custom_minimum_size.y = min_height
	scroll_box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll_box.add_child(list)
	list.set_meta("scroll", scroll_box)
	return list


## 0-9 / C / ⌫ tuş takımı. `text_holder` bir Array: [0] metni tutar; her tuşta `on_change` çağrılır. En fazla 7 hane.
static func keypad(text_holder: Array, on_change: Callable) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for key in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "<"]:
		var button := UiKit.button(key if key != "<" else "⌫", "Key_%s" % ("back" if key == "<" else key), &"KeyButton", 88.0)
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
