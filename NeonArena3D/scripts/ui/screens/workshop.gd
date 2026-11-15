extends MenuScreen
## Atölye: çekirdekle kalıcı yükseltmeler (3 sütunlu ızgara).
##
## EKLENECEK YER: mağaza / "reklamsız" satın alma girişi `add_footer(control)` ile ızgaranın altına eklenir
## (A2 faturalandırma görevi); kendi ekranı gerekirse `host.open_sub("shop", "workshop")` kullanılır.

const KIT = preload("res://scripts/ui/ui_kit.gd")
const W = preload("res://scripts/ui/screens/widgets.gd")

var box: VBoxContainer
var _cores: W.CoreBadge
var _tiles: Array = []
var _back_button: Button


func build() -> void:
	root = host.make_screen("workshop", 0.86)
	box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	host.center(root).add_child(box)
	box.add_child(KIT.heading(tr("ATÖLYE"), 42, KIT.GOLD))
	box.add_child(KIT.label(tr("çekirdeklerle kalıcı yükseltmeler al — her koşuda geçerli"), 16, KIT.DIM, null, HORIZONTAL_ALIGNMENT_CENTER))
	_cores = W.CoreBadge.new(26)
	_cores.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_cores)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	for def in GameData.upgrades:
		var tile := W.UpgradeTile.new()
		tile.def = def
		var id := str(def.get("id", ""))
		tile.pressed.connect(func(): _buy(id, tile))
		if not Settings.touch:
			tile.mouse_entered.connect(func(): Sound.play("ui_hover"))
		grid.add_child(tile)
		_tiles.append(tile)
	_back_button = KIT.button(tr("GERİ"), KIT.GOLD, Vector2(240, 56), 22, true)
	_back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back_button.pressed.connect(host._back)
	box.add_child(_back_button)
	host.focus["workshop"] = _tiles[0] if not _tiles.is_empty() else _back_button


func on_open() -> void:
	refresh(false)


func refresh(animate := true) -> void:
	if _cores != null:
		_cores.set_amount(Settings.meta.cores, animate)
	host.sync_main_cores()
	for tile in _tiles:
		(tile as Control).queue_redraw()


func _buy(id: String, tile: W.UpgradeTile) -> void:
	if Settings.meta.buy(id):
		Settings.save()
		Sound.play("purchase")
		tile.bump(true)
	else:
		Sound.play("deny")
		tile.bump(false)
	refresh()


## SEAM: GERİ düğmesinin hemen üstüne ek denetim (mağaza girişi vb.) ekler.
func add_footer(control: Control) -> void:
	box.add_child(control)
	box.move_child(control, _back_button.get_index())
