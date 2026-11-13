class_name MachineUpgrades
extends Sheet

## Makine yükseltme sayfası (jeton harcama yeri): çamaşır ve kurutma makinesi, her birinde iki
## yol (kapasite, hız). Düz, çizgisiz alt sayfa (Sheet/UiKit dili). Bedel tablosu
## `MachineRules`/`data/machines.json`; seviyeler `Progress` modülünde ("machines") durur.
## Giriş noktası (ana ekran) bu dosyada değildir:  MachineUpgrades.open(parent)
## Rozet için:  MachineUpgrades.can_upgrade_any()

signal upgraded(machine: String, track: String, level: int)

const MODULE: String = "machines"
const NAME_SIZE: int = UiKit.TYPE_HEADING - 4
const ROW_SIZE: int = UiKit.TYPE_BODY
const CAPTION_SIZE: int = UiKit.TYPE_CAPTION
const COIN_SIZE: int = UiTokens.TYPE_NUMERIC_SM
const THUMB: float = 168.0
const ROW_GAP: float = UiKit.SPACE_MD
const CARD_GAP: float = UiKit.SPACE_LG
const CARD_PAD: int = UiTokens.SPACE_LG
const BUY_HEIGHT: float = UiKit.HEIGHT_COMPACT
const BUY_WIDTH: float = 230.0
const LOCKED_ALPHA: float = 0.4
const ARROW: String = "  →  "
const COIN_ICON: String = "lucide/coins"
const THUMBS: Dictionary = {
	MachineRules.WASHER: "res://assets/sprites/machines/machine_washer.png",
	MachineRules.DRYER: "res://assets/sprites/machines/machine_dryer.png",
}
const NAME_KEYS: Dictionary = {MachineRules.WASHER: "MACHINE_WASHER", MachineRules.DRYER: "MACHINE_DRYER"}
const TRACK_KEYS: Dictionary = {MachineRules.CAPACITY: "MACHINE_CAPACITY", MachineRules.MOVES: "MACHINE_SPEED"}
const BUY_SOUND: String = "unlock"
const BUY_PITCH: float = 1.1
const BUY_DB: float = -4.0

var _rows: VBoxContainer = null
var _coins: Label = null


## Autoload'lara düğüm yoluyla erişilir: betik araç/test (-s) kipinde de derlensin (orada autoload
## adları derleme anında çözülmüyor).
const PROGRESS_PATH: NodePath = ^"/root/Progress"
const AUDIO_PATH: NodePath = ^"/root/AudioService"


static func _progress() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node(PROGRESS_PATH)


static func _coins_now() -> int:
	return int(_progress().call("coins"))


static func open(parent: Node) -> Node:
	var sheet: MachineUpgrades = MachineUpgrades.new()
	sheet.build(parent, false)
	sheet.dismiss_on_dim = true
	sheet._fill()
	sheet.play_intro()
	return sheet


## Kayıttaki yükseltme seviyesi.
static func level_of(machine: String, track: String) -> int:
	return int(_progress().call("module_value", MODULE, MachineRules.key(machine, track), 0))


## Oyunun tahtaya vereceği değerler (seviye başında bir kez okunur).
static func board_params() -> Dictionary:
	var levels: Dictionary = {}
	for machine: String in MachineRules.MACHINES:
		for track: String in MachineRules.TRACKS:
			levels[MachineRules.key(machine, track)] = level_of(machine, track)
	return MachineRules.board_params(levels)


static func is_unlocked(machine: String) -> bool:
	return int(_progress().call("level")) >= MachineRules.unlock_level(machine)


## Rozet: açık bir makinede jetonun yettiği bir yükseltme var mı.
static func can_upgrade_any() -> bool:
	for machine: String in MachineRules.MACHINES:
		if not is_unlocked(machine):
			continue
		for track: String in MachineRules.TRACKS:
			var price: int = MachineRules.cost(machine, track, level_of(machine, track))
			if price != MachineRules.MAXED and price <= _coins_now():
				return true
	return false


## Satın alır: jeton yetmezse ya da en üstteyse false.
static func buy(machine: String, track: String) -> bool:
	if not is_unlocked(machine):
		return false
	var level: int = level_of(machine, track)
	var price: int = MachineRules.cost(machine, track, level)
	if price == MachineRules.MAXED or not bool(_progress().call("spend_coins", price)):
		return false
	_progress().call("set_module_value", MODULE, MachineRules.key(machine, track), level + 1)
	return true


func _fill() -> void:
	var column: VBoxContainer = content()
	add_title(Loc.t("MACHINES_TITLE"))
	# Bakiye başlığın altında ortada, sakin: ikon + sayı; altında tek satır sönük açıklama.
	var balance: HBoxContainer = HBoxContainer.new()
	balance.alignment = BoxContainer.ALIGNMENT_CENTER
	balance.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(balance)
	var coin_icon: TextureRect = UiKit.tinted_icon(COIN_ICON, UiKit.ICON_MD, UiKit.GOLD)
	coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	balance.add_child(coin_icon)
	_coins = UiKit.numeric_label("", COIN_SIZE)
	balance.add_child(_coins)
	column.add_child(UiKit.spacer(UiKit.SPACE_XS))
	column.add_child(UiKit.wrap_label(Loc.t("MACHINES_SUB"), CAPTION_SIZE, UiKit.TEXT_MUTED))
	column.add_child(UiKit.spacer(CARD_GAP))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", int(CARD_GAP))
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_rows)
	column.add_child(UiKit.spacer(UiKit.SPACE_XL))
	var ok: Button = add_action(Loc.t("OK"), false)
	ok.pressed.connect(close)
	_refresh()


## Kartlar baştan kurulur (satın almadan sonra da): az düğüm, kare başına iş yok.
func _refresh() -> void:
	_coins.text = UiKit.fmt_int(_coins_now())
	for child: Node in _rows.get_children():
		child.queue_free()
	for machine: String in MachineRules.MACHINES:
		_rows.add_child(_machine_card(machine))


func _machine_card(machine: String) -> PanelContainer:
	var card: PanelContainer = UiKit.card(UiKit.SURFACE_SOFT, UiKit.RADIUS_CARD, CARD_PAD, CARD_PAD)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", int(CARD_PAD))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var unlocked: bool = is_unlocked(machine)
	var thumb: TextureRect = TextureRect.new()
	thumb.texture = load(String(THUMBS[machine])) as Texture2D
	thumb.custom_minimum_size = Vector2(THUMB, THUMB)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not unlocked:
		thumb.modulate = Color(1.0, 1.0, 1.0, LOCKED_ALPHA)
	row.add_child(thumb)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", int(UiKit.SPACE_SM))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)
	var name: Label = UiKit.label(Loc.t(String(NAME_KEYS[machine])), NAME_SIZE)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(name)
	if not unlocked:
		var locked: Label = UiKit.label(Loc.f("MACHINE_LOCKED", [MachineRules.unlock_level(machine)]), ROW_SIZE,
			UiKit.TEXT_MUTED)
		locked.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		column.add_child(locked)
		return card
	for track: String in MachineRules.TRACKS:
		column.add_child(_track_row(machine, track))
	return card


func _track_row(machine: String, track: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", int(ROW_GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var level: int = level_of(machine, track)
	var price: int = MachineRules.cost(machine, track, level)
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var caption: Label = UiKit.label(Loc.t(String(TRACK_KEYS[track])), CAPTION_SIZE, UiKit.TEXT_MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_child(caption)
	var shown: String = _value_text(track, MachineRules.value(machine, track, level))
	if price != MachineRules.MAXED:
		shown += ARROW + _value_text(track, MachineRules.value(machine, track, level + 1))
	var value: Label = UiKit.label(shown, ROW_SIZE)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.add_child(value)
	if price == MachineRules.MAXED:
		var done: Label = UiKit.label(Loc.t("MACHINE_MAX"), CAPTION_SIZE, UiKit.ACCENT)
		done.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(done)
		return row
	var buy_button: Button = UiKit.button(str(price), &"" if price <= _coins_now() else &"SecondaryButton",
		COIN_ICON, BUY_HEIGHT)
	buy_button.custom_minimum_size.x = BUY_WIDTH
	buy_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiKit.set_enabled(buy_button, price <= _coins_now())
	buy_button.pressed.connect(_on_buy.bind(machine, track))
	row.add_child(buy_button)
	return row


func _value_text(track: String, amount: int) -> String:
	if track == MachineRules.CAPACITY:
		return Loc.f("MACHINE_CAPACITY_VALUE", [amount])
	return Loc.n("MACHINE_MOVES_ONE", "MACHINE_MOVES_OTHER", amount) % amount


func _on_buy(machine: String, track: String) -> void:
	if not buy(machine, track):
		return
	var audio: Node = get_node_or_null(AUDIO_PATH)
	if audio != null:
		audio.call("play_pitched", BUY_SOUND, BUY_PITCH, BUY_DB)
	upgraded.emit(machine, track, level_of(machine, track))
	_refresh()
