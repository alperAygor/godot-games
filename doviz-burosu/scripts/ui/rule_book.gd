class_name RuleBook
extends VBoxContainer
## Kılavuzun "Kurallar" bölümü: her sayfada bir kural. Kuralın ne dediği, NASIL denetleneceği (adım adım), hangi araç gerektiği,
## bugün açıldıysa "YENİ" damgası ve masaya iğneleme (yapışkan not) düğmesi. Sayfalar kaydırarak ya da Önceki/Sonraki ile çevrilir.
## Yalnızca arayüz: kuralları RuleSet verir, iğnelenenleri GameSession tutar.

signal pins_changed

const PAGE_SLIDE := 60.0
const SWIPE_DISTANCE := 70.0
## kural aracı -> [ikon, çeviri anahtarı]
const TOOL_INFO := {
	"calculator": ["calc", "TOOLREF_CALCULATOR"], "catalog": ["catalog", "TOOLREF_CATALOG"], "uv": ["uv", "TOOLREF_UV"],
	"counter": ["till", "TOOLREF_COUNTER"], "id": ["person", "TOOLREF_ID"], "bulletin": ["siren", "TOOLREF_BULLETIN"],
	"backlight": ["uv", "TOOLREF_BACKLIGHT"], "declaration": ["document", "TOOLREF_DECLARATION"], "magnifier": ["magnifier", "TOOLREF_MAGNIFIER"],
	"none": ["", "TOOLREF_NONE"],
}
## Araç kimliği (kural tanımı) -> sahip olunması gereken araç (Career.has_tool); boşsa her zaman vardır.
const OWNED_TOOL := {"uv": "uv", "magnifier": "magnifier", "backlight": "uv"}

var page := 0

var _day: int
var _rules: Array[String] = []
var _rule_defs: Dictionary = {}
var _career: Career
var _pins: Array
var _holder: Control
var _content: VBoxContainer
var _dots: HBoxContainer
var _swipe_start := -1.0


## `pinned`: iğnelenen kural kimlikleri (paylaşılan dizi). `start_rule`: ilk açılacak kural (boşsa en yeni kural).
func _init(context: DayContext, career: Career, pinned: Array, start_rule := "") -> void:
	name = "RuleBook"
	_day = context.day
	_career = career
	_pins = pinned
	add_theme_constant_override("separation", 10)
	for rule_id in context.rules.active_ids(context.day):
		_rules.append(str(rule_id))
	for def: Dictionary in context.rules.all():
		_rule_defs[str(def["id"])] = def
	page = maxi(0, _rules.find(start_rule)) if not start_rule.is_empty() else _rules.size() - 1
	page = clampi(page, 0, maxi(0, _rules.size() - 1))
	_holder = Control.new()
	_holder.name = "RulePages"
	_holder.clip_contents = true
	_holder.custom_minimum_size.y = 470.0
	_holder.gui_input.connect(_on_page_input)
	add_child(_holder)
	_content = VBoxContainer.new()
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.add_theme_constant_override("separation", 8)
	_holder.add_child(_content)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	add_child(nav)
	var previous := UiKit.icon_button("back", tr("RULEBOOK_PREV"), "RulePrev", true, false, 64.0)
	previous.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	previous.pressed.connect(func() -> void: turn(-1))
	nav.add_child(previous)
	_dots = HBoxContainer.new()
	_dots.alignment = BoxContainer.ALIGNMENT_CENTER
	_dots.add_theme_constant_override("separation", 6)
	nav.add_child(_dots)
	var next := UiKit.icon_button("play", tr("RULEBOOK_NEXT"), "RuleNext", true, false, 64.0)
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next.pressed.connect(func() -> void: turn(1))
	nav.add_child(next)
	_fill()


func current_rule() -> String:
	return _rules[page] if not _rules.is_empty() else ""


## Sayfayı `step` kadar çevirir (baştan/sondan öteye geçmez).
func turn(step: int) -> void:
	var target := clampi(page + step, 0, _rules.size() - 1)
	if target == page:
		return
	page = target
	Feel.sfx("page", 1.0 + 0.04 * randf())
	_fill()
	if not Feel.instant and is_inside_tree():
		_content.position.x = PAGE_SLIDE * signf(step)
		_content.modulate.a = 0.0
		var tween := create_tween().set_parallel(true)
		tween.tween_property(_content, "position:x", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(_content, "modulate:a", 1.0, 0.16)


func _on_page_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.pressed:
			_swipe_start = event.position.x
		elif _swipe_start >= 0.0:
			var delta: float = event.position.x - _swipe_start
			_swipe_start = -1.0
			if absf(delta) >= SWIPE_DISTANCE:
				turn(-1 if delta > 0.0 else 1)


func _fill() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	for child in _dots.get_children():
		_dots.remove_child(child)
		child.queue_free()
	for i in _rules.size():
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(16 if i == page else 8, 8)
		dot.color = Color("C8892B") if i == page else Color(0.45, 0.4, 0.33, 0.5)
		_dots.add_child(dot)
	if _rules.is_empty():
		return
	var rule_id := _rules[page]
	var def: Dictionary = _rule_defs.get(rule_id, {})
	var header := HBoxContainer.new()
	_content.add_child(header)
	var counter := UiKit.label(tr("RULEBOOK_PAGE") % [page + 1, _rules.size()], &"CardDetail", "RulePageNumber")
	counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(counter)
	if int(def.get("from_day", 0)) == _day:
		var fresh := UiKit.label(tr("RULEBOOK_NEW"), &"SlipTitle", "RuleNewStamp")
		fresh.add_theme_color_override("font_color", UiKit.BAD_COLOR)
		header.add_child(fresh)
	var title := UiKit.wrapped(tr("RULE_%s" % rule_id), &"SheetTitle", "RuleTitle")
	_content.add_child(title)
	_content.add_child(UiKit.wrapped(tr("RULE_%s_DESC" % rule_id), &"CardTitle", "RuleDesc"))
	_content.add_child(UiKit.label(tr("RULEBOOK_HOW"), &"SlipTitle"))
	var how := UiKit.wrapped(tr("RULE_%s_HOW" % rule_id), &"CardDetail", "RuleHow")
	_content.add_child(how)
	_content.add_child(_tool_row(str(def.get("tool", "none"))))
	var pinned := rule_id in _pins
	var pin := UiKit.icon_button("pin", tr("RULEBOOK_UNPIN") if pinned else tr("RULEBOOK_PIN"), "RulePin_%s" % rule_id, true, false, 64.0)
	pin.toggle_mode = true
	pin.set_pressed_no_signal(pinned)
	pin.pressed.connect(_toggle_pin.bind(rule_id))
	_content.add_child(pin)


func _tool_row(tool_id: String) -> Control:
	var info: Array = TOOL_INFO.get(tool_id, TOOL_INFO["none"])
	var row := HBoxContainer.new()
	row.name = "RuleTool"
	row.add_theme_constant_override("separation", 10)
	var owned_id: String = OWNED_TOOL.get(tool_id, "")
	var owned := owned_id.is_empty() or _career.has_tool(owned_id)
	if not str(info[0]).is_empty():
		row.add_child(IconView.new(str(info[0]), Color("2B2A33") if owned else Color(0.45, 0.4, 0.33, 0.6), 34.0))
	var label := UiKit.label(tr("RULEBOOK_TOOL") % tr(str(info[1])) if tool_id != "none" else tr("RULEBOOK_TOOL_NONE"), &"CardDetail")
	if not owned:
		label.text += "  " + tr("RULEBOOK_TOOL_LOCKED")
	row.add_child(label)
	return row


func _toggle_pin(rule_id: String) -> void:
	if rule_id in _pins:
		_pins.erase(rule_id)
	elif _pins.size() >= GameSession.MAX_PINS:
		_pins.pop_front()  # en eski not düşer
		_pins.append(rule_id)
	else:
		_pins.append(rule_id)
	Feel.sfx("note_drop")
	pins_changed.emit()
	_fill()
