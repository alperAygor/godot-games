class_name GameHud
extends Control

## Oyun içi HUD: duraklat düğmesi (sol), seviye başlığı (orta), jeton hapı (sağ).
## Güvenli alana (çentik/kamera) ve asgari kenar boşluğuna saygılıdır; tahtaya taşmaz.
## Jeton, `Progress` varsa onun değerini izler; yoksa `set_coins` ile verilen değeri gösterir.

signal pause_requested

const TITLE_SIZE: int = 40
const ROW_HEIGHT: float = UiKit.MIN_TOUCH

var _title: Label = null
var _coin_chip: UiChip = null
var _pause_button: UiIconButton = null
var _has_progress_coins: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view: Vector2 = get_viewport_rect().size
	var insets: Vector4 = UiKit.safe_insets(view)
	var row_top: float = insets.y
	_pause_button = UiIconButton.new()
	_pause_button.setup("lucide/pause")
	_pause_button.position = Vector2(insets.x + UiKit.SIDE_MARGIN - (UiKit.MIN_TOUCH - UiIconButton.DISC_DIAMETER) * 0.5, row_top)
	_pause_button.pressed.connect(pause_requested.emit)
	add_child(_pause_button)
	_title = UiKit.label("", TITLE_SIZE)
	_title.position = Vector2(view.x * 0.5 - 200.0, row_top)
	_title.custom_minimum_size = Vector2(400.0, ROW_HEIGHT)
	_title.size = Vector2(400.0, ROW_HEIGHT)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_title)
	_coin_chip = UiChip.new()
	_coin_chip.setup("lucide/coins", UiKit.GOLD)
	add_child(_coin_chip)
	# Sağa yaslı: hap genişledikçe sol kenarı kayar, sağ kenarı sabit kalır.
	_coin_chip.resized.connect(_place_chip.bind(view, insets, row_top))
	_place_chip(view, insets, row_top)
	UiData.connect_changed(_on_progress_changed)
	_on_progress_changed()


func set_level(number: int) -> void:
	_title.text = UiStrings.LEVEL % number


## Progress yoksa jeton sayısı buradan gelir.
func set_coins(value: int) -> void:
	if not _has_progress_coins:
		_coin_chip.set_value(value)


func _on_progress_changed() -> void:
	if UiData.progress() != null:
		_has_progress_coins = true
		_coin_chip.set_value(UiData.coins())


func _place_chip(view: Vector2, insets: Vector4, row_top: float) -> void:
	var chip_size: Vector2 = _coin_chip.get_combined_minimum_size()
	_coin_chip.size = chip_size
	_coin_chip.position = Vector2(view.x - insets.z - UiKit.SIDE_MARGIN - chip_size.x,
		row_top + (ROW_HEIGHT - chip_size.y) * 0.5)
