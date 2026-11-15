extends MenuScreen
## Hangar: gemi seçimi / satın alma. Sol-sağ oklar, A/D ve ←/→ ile gezilir; `ship_preview` oyun sahnesindeki gemiyi değiştirir.

const KIT = preload("res://scripts/ui/ui_kit.gd")
const W = preload("res://scripts/ui/screens/widgets.gd")

var index := 0
var _name: Label
var _weapon: Label
var _desc: Label
var _bars: W.StatBars
var _action: Button
var _page: Label
var _cores: W.CoreBadge


static func ship_ids() -> Array:
	var ids: Array = []
	for def in GameData.ships:
		ids.append(str(def.get("id", "")))
	return ids


func build() -> void:
	root = host.make_screen("hangar", 0.0)
	root.add_child(host.side_shade(0.95))
	var margin: Vector4 = host.margin
	var col := VBoxContainer.new()
	col.anchor_bottom = 1.0
	col.offset_left = margin.x + 56.0
	col.offset_right = margin.x + 600.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	root.add_child(col)
	var head := KIT.label(tr("HANGAR"), 20, KIT.GREEN, KIT.bold())
	col.add_child(head)
	_name = KIT.label("", 58, Color(1, 1, 1), KIT.title())
	_name.add_theme_constant_override("outline_size", 12)
	col.add_child(_name)
	_weapon = KIT.label("", 18, KIT.GOLD, KIT.bold())
	col.add_child(_weapon)
	_desc = KIT.label("", 17, KIT.TEXT)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(520, 50)
	col.add_child(_desc)
	col.add_child(KIT.spacer(4))
	_bars = W.StatBars.new()
	col.add_child(_bars)
	col.add_child(KIT.spacer(6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var prev := W.ArrowButton.new(-1)
	prev.pressed.connect(func(): step(-1))
	row.add_child(prev)
	_action = KIT.button("", KIT.GREEN, Vector2(330, 64), 21, true)
	_action.pressed.connect(act)
	row.add_child(_action)
	var next := W.ArrowButton.new(1)
	next.pressed.connect(func(): step(1))
	row.add_child(next)
	col.add_child(row)
	_page = KIT.label("", 15, KIT.DIM, null, HORIZONTAL_ALIGNMENT_CENTER)
	_page.custom_minimum_size = Vector2(496, 0)
	_page.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(_page)
	col.add_child(KIT.spacer(4))
	var back := KIT.button(tr("GERİ"), Color(0.6, 0.66, 0.78), Vector2(240, 54), 20)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(host._back)
	col.add_child(back)
	host.focus["hangar"] = _action
	_cores = W.CoreBadge.new(26)
	_cores.anchor_left = 1.0
	_cores.anchor_right = 1.0
	_cores.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_cores.offset_right = -margin.z - 30.0
	_cores.offset_top = margin.y + 24.0
	root.add_child(_cores)


func on_open() -> void:
	var ids := ship_ids()
	index = maxi(0, ids.find(Settings.meta.ship))
	refresh(false)


func step(delta: int) -> void:
	var ids := ship_ids()
	if ids.is_empty():
		return
	index = MenuLogic.wrap_index(index, delta, ids.size())
	Sound.play("ui_toggle")
	refresh()


func refresh(animate := true) -> void:
	var ids := ship_ids()
	if ids.is_empty():
		return
	var meta: MetaProgress = Settings.meta
	var id: String = ids[index]
	var def := meta.ship_def(id)
	var color := Color.from_string(str(def.get("color", "#5ce1ff")), KIT.CYAN)
	_name.text = tr(str(def.get("name", "")))
	_name.add_theme_color_override("font_color", color.lerp(Color(1, 1, 1), 0.35))
	_name.add_theme_color_override("font_outline_color", Color(color, 0.3))
	_weapon.text = tr("SİLAH: %s") % tr(str(def.get("weapon_name", "")))
	_desc.text = tr(str(def.get("desc", "")))
	_bars.bars = def.get("bars", {})
	_bars.color = color
	_bars.queue_redraw()
	_page.text = MenuLogic.page_text(index, ids.size())
	_cores.set_amount(meta.cores, animate)
	match MenuLogic.ship_button(meta.ship == id, meta.owns_ship(id)):
		MenuLogic.ShipButton.SELECTED:
			_action.text = tr("SEÇİLİ")
			_action.disabled = true
		MenuLogic.ShipButton.SELECT:
			_action.text = tr("SEÇ")
			_action.disabled = false
		_:
			_action.text = tr("%s ÇEKİRDEKLE AÇ") % KIT.fmt(meta.ship_cost(id))
			_action.disabled = false
	host.ship_preview.emit(id)


func act() -> void:
	var ids := ship_ids()
	var id: String = ids[index]
	var meta: MetaProgress = Settings.meta
	if meta.owns_ship(id):
		meta.select_ship(id)
		Settings.save()
		Sound.play("card_pick")
	elif meta.buy_ship(id):
		meta.select_ship(id)
		Settings.save()
		Sound.play("purchase")
		host.flash(Color.from_string(str(meta.ship_def(id).get("color", "#ffffff")), Color.WHITE), 0.35, 0.5)
	else:
		Sound.play("deny")
		_cores.set_amount(meta.cores)
		var tw := _action.create_tween()
		for k in 3:
			tw.tween_property(_action, "position:x", _action.position.x + 8.0, 0.04)
			tw.tween_property(_action, "position:x", _action.position.x - 8.0, 0.04)
		tw.tween_property(_action, "position:x", _action.position.x, 0.04)
		return
	refresh()
	host.sync_main_cores()
