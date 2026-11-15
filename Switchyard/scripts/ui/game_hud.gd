class_name GameHud
extends Control

## Oyun içi HUD iskeleti: duraklat düğmesi (sol), seviye başlığı (orta), jeton hapı (sağ).
## Güvenli alana (çentik/kamera) ve asgari kenar boşluğuna saygılıdır; oyun alanına taşmaz.
## Jeton, `Progress` varsa onun değerini izler; yoksa `set_coins` ile verilen değeri gösterir.
## Oyuna özgü göstergeler (sayaç, hamle, zincir...) bu sınıfa alt düğüm olarak eklenir.

signal pause_requested

const TITLE_SIZE: int = UiTokens.TYPE_NUMERIC_SM
## Başlık ile yan öğeler (duraklat düğmesi, jeton hapı) arası en az boşluk.
const TITLE_SIDE_GAP: float = UiKit.SPACE_MD
const TITLE_MAX_WIDTH: float = 400.0
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
	_pause_button.name = "PauseButton"
	_pause_button.setup("lucide/pause")
	_pause_button.position = Vector2(insets.x + UiKit.SIDE_MARGIN - (UiKit.MIN_TOUCH - UiIconButton.DISC_DIAMETER) * 0.5, row_top)
	_pause_button.pressed.connect(pause_requested.emit)
	add_child(_pause_button)
	_title = UiKit.label("", TITLE_SIZE)
	_title.position = Vector2(view.x * 0.5 - TITLE_MAX_WIDTH * 0.5, row_top)
	_title.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	_title.size = Vector2(TITLE_MAX_WIDTH, ROW_HEIGHT)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Uzun başlık (EN/ES) yan öğelere binmesin: genişlik hap ölçüsüne göre kısılır, taşan "…" olur.
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
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
	_title.text = UiStrings.level(number)


## Seviye numarası olmayan ekranlarda başlık doğrudan yazılır.
func set_title(text: String) -> void:
	_title.text = text


## Başlık rengi zemine göre değişebilir (koyu zeminde açık renk).
func set_title_color(color: Color) -> void:
	_title.add_theme_color_override("font_color", color)


## Progress yoksa jeton sayısı buradan gelir.
func set_coins(value: int) -> void:
	if not _has_progress_coins:
		_coin_chip.set_value(value)


func title_text() -> String:
	return _title.text


func _on_progress_changed() -> void:
	if UiData.progress() != null:
		_has_progress_coins = true
		_coin_chip.set_value(UiData.coins())


func _place_chip(view: Vector2, insets: Vector4, row_top: float) -> void:
	var chip_size: Vector2 = _coin_chip.get_combined_minimum_size()
	_coin_chip.size = chip_size
	_coin_chip.position = Vector2(view.x - insets.z - UiKit.SIDE_MARGIN - chip_size.x,
		row_top + (ROW_HEIGHT - chip_size.y) * 0.5)
	# Başlık ekran ortasında kalır; yarı genişliği hapın sol kenarına ve duraklat düğmesine göre sınırlanır.
	var left_limit: float = insets.x + UiKit.SIDE_MARGIN + UiIconButton.DISC_DIAMETER + TITLE_SIDE_GAP
	var half: float = minf(TITLE_MAX_WIDTH * 0.5, minf(view.x * 0.5 - left_limit,
		_coin_chip.position.x - TITLE_SIDE_GAP - view.x * 0.5))
	_title.size.x = maxf(half, 0.0) * 2.0
	_title.position.x = view.x * 0.5 - half
