class_name DeskToolbar
extends RefCounted
## Masanın alt iki satırı: araç çubuğu ("ToolsGrid": kılavuz, hesap makinesi, katalog, UV, büyüteç, kasa, kur hesaplayıcı)
## ve karar damgaları ("Stamps": Tamamla / Reddet / Polis). Damgalar başparmak erişiminde, ekranın en altında durur.

const STAMP_HEIGHT := 128.0
const TOOL_HEIGHT := 88.0

var desk: DeskScreen
var complete_button: StampButton
var reject_button: StampButton
var police_button: StampButton
var uv_button: IconButton
var magnifier_button: IconButton
## Araç kimliği -> düğme ("book", "calc", "catalog", "uv", "magnifier", "till", "rate_calc").
var tool_buttons := {}


func _init(owner_desk: DeskScreen) -> void:
	desk = owner_desk


func build_tools() -> Control:
	var row := HBoxContainer.new()
	row.name = "ToolsGrid"
	row.add_theme_constant_override("separation", 4)
	var sheets := desk.tool_sheets
	var book := _tool("book", tr("TOOL_BOOK"), tr("TOOL_BOOK_SHORT"), "ToolBookButton")
	book.pressed.connect(sheets.open_info)
	var calc := _tool("calc", tr("TOOL_CALC"), tr("TOOL_CALC_SHORT"), "ToolCalcButton")
	calc.pressed.connect(sheets.open_calculator)
	var catalog := _tool("catalog", tr("TOOL_CATALOG"), tr("TOOL_CATALOG_SHORT"), "ToolCatalogButton")
	catalog.pressed.connect(sheets.open_catalog)
	uv_button = _tool("uv", tr("TOOL_UV"), tr("TOOL_UV_SHORT"), "ToolUvButton")
	uv_button.toggle_mode = true
	uv_button.toggled.connect(desk.counter.set_uv_lamp)
	magnifier_button = _tool("magnifier", tr("TOOL_MAGNIFIER"), tr("TOOL_MAGNIFIER_SHORT"), "ToolMagnifierButton")
	magnifier_button.toggle_mode = true
	magnifier_button.toggled.connect(desk.counter.set_magnifier)
	var till := _tool("till", tr("TOOL_TILL"), tr("TOOL_TILL_SHORT"), "ToolTillButton")
	till.pressed.connect(sheets.open_till)
	var rate := _tool("rate", tr("TOOL_RATE_CALC"), tr("TOOL_RATE_SHORT"), "ToolRateButton")
	rate.pressed.connect(sheets.open_rate)
	tool_buttons = {"book": book, "calc": calc, "catalog": catalog, "uv": uv_button, "magnifier": magnifier_button,
		"till": till, "rate_calc": rate}
	for button: Button in tool_buttons.values():
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	return row


## Araç çubuğu düğmesi: ikon üstte, kısa etiket altta; tam metin `text`te (erişilebilirlik/test) durur.
func _tool(icon_name: String, full_text: String, short_text: String, node_name: String) -> IconButton:
	var button := UiKit.icon_button(icon_name, full_text, node_name, false, true, TOOL_HEIGHT, short_text)
	button.accent = Color("C8892B")
	return button


## Hangi araçlar görünür: temel üçü her zaman; UV / büyüteç / kur hesaplayıcı satın alınmış ya da verilmişse; kasa görünümü R_SELL_FOREIGN açılınca.
## Sayaç aracı ayrı bir düğme değil: sahipse tezgâhta toplam otomatik görünür.
func refresh_tools() -> void:
	var career := desk.career
	uv_button.visible = career.has_tool("uv")
	magnifier_button.visible = career.has_tool("magnifier")
	(tool_buttons["rate_calc"] as Button).visible = career.has_tool("rate_calc")
	(tool_buttons["till"] as Button).visible = desk.shift.ctx.rule_active("R_SELL_FOREIGN")
	uv_button.set_pressed_no_signal(false)
	magnifier_button.set_pressed_no_signal(false)
	desk.uv_lamp = false
	desk.magnifier = false
	desk.backlight = false


func build_decisions() -> Control:
	var row := HBoxContainer.new()
	row.name = "Stamps"
	row.add_theme_constant_override("separation", 10)
	complete_button = _stamp(tr("DECISION_COMPLETE"), "CompleteButton", Color("3F7D4E"))
	complete_button.pressed.connect(_stamp_then.bind(complete_button, desk._decide.bind(Verdict.DECISION_COMPLETE, "")))
	reject_button = _stamp(tr("DECISION_REJECT"), "RejectButton", Color("B07A18"))
	reject_button.pressed.connect(_stamp_then.bind(reject_button, desk.note_sheets.open_reason))
	police_button = _stamp(tr("DECISION_POLICE"), "PoliceButton", Color("A82E26"))
	police_button.pressed.connect(_stamp_then.bind(police_button, desk._decide.bind(Verdict.DECISION_POLICE, "")))
	for button in [complete_button, reject_button, police_button]:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(button)
	return row


func _stamp(text: String, node_name: String, ink: Color) -> StampButton:
	var button := StampButton.new()
	button.text = text
	button.name = node_name
	button.ink = ink
	button.custom_minimum_size = Vector2(0, STAMP_HEIGHT)
	return button


## Damga basılır: kalkıp iner, mühür vurulduğu an eylem çalışır.
func _stamp_then(button: StampButton, action: Callable) -> void:
	button.press_animation(action)


func set_decisions_enabled(enabled: bool) -> void:
	for button in [complete_button, reject_button, police_button]:
		button.disabled = not enabled
