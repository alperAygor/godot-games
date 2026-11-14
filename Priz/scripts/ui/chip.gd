class_name UiChip
extends PanelContainer

## Küçük, yarı saydam, çizgisiz miktar hapı. Priz'de ekranda RAKAM YOK: miktar bir sıra jeton
## simgesiyle gösterilir (`Quantity.coin_layout`: simge sayısı sınırlı, çok olunca "yığın" simgesi).
## Değer artınca yeni simgeler sırayla "pop" yapar; azalınca sessizce küçülür.
## `set_value(int)` API'si şablonla aynıdır (Home/HUD/sonuç sayfası değişmeden kullanır).

const ICON_PIXELS: float = 40.0
const HEIGHT: float = float(UiTokens.H_CHIP)
const ICON_GAP: int = UiTokens.SPACE_SM
const POP_STAGGER_SECONDS: float = 0.09
const POP_FROM_SCALE: float = 0.2
const PILE_ICON: String = "lucide/coins"

var _value: int = 0
var _icons: int = 0
var _pile: bool = false
var _icon_name: String = PILE_ICON
var _color: Color = UiKit.GOLD
var _row: HBoxContainer = null
## İlk değer animasyonsuz yazılır: ekran açılırken boş başlayıp dolmasın.
var _primed: bool = false
var _display: Dictionary = {}


func setup(icon_name: String, icon_color: Color) -> void:
	_icon_name = icon_name
	_color = icon_color
	_display = UiData.balance_block("coin_display")
	theme_type_variation = &"ChipPanel"
	custom_minimum_size = Vector2(0.0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", ICON_GAP)
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_rebuild(0, false, false)


func set_value(value: int, animated: bool = true) -> void:
	if not _primed:
		_primed = true
		animated = false
	elif value == _value:
		return
	var layout: Dictionary = Quantity.coin_layout(value, _display)
	var grew: bool = value > _value
	_value = value
	_rebuild(int(layout["icons"]), bool(layout["pile"]), animated and grew)


func value() -> int:
	return _value


## Görünen jeton simgesi sayısı (yığın hariç) — testler/problar için.
func icon_count() -> int:
	return _icons


func has_pile() -> bool:
	return _pile


func _rebuild(icons: int, pile: bool, animate_new: bool) -> void:
	var previous: int = _icons
	_icons = icons
	_pile = pile
	for child: Node in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	if icons == 0 and not pile:
		var empty: UiCoinIcon = UiCoinIcon.new()
		empty.setup(_color, false)
		_row.add_child(empty)
		return
	for index: int in range(icons):
		var coin: UiCoinIcon = UiCoinIcon.new()
		coin.setup(_color)
		_row.add_child(coin)
		if animate_new and index >= previous:
			_pop_in(coin, float(index - previous) * POP_STAGGER_SECONDS)
	if pile:
		var heap: TextureRect = UiKit.tinted_icon(_icon_name, ICON_PIXELS, _color)
		heap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		heap.name = "Pile"
		_row.add_child(heap)
		if animate_new:
			_pop_in(heap, float(icons - previous) * POP_STAGGER_SECONDS)
	if animate_new and icons <= previous and not pile:
		UiKit.pop(self)


func _pop_in(node: Control, delay: float) -> void:
	node.pivot_offset = Vector2(ICON_PIXELS, ICON_PIXELS) * 0.5
	node.scale = Vector2.ONE * POP_FROM_SCALE
	var tween: Tween = node.create_tween()
	tween.tween_interval(maxf(delay, 0.0))
	tween.tween_property(node, "scale", Vector2.ONE, UiTokens.MOTION_RELEASE_SECONDS)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
