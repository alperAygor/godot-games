class_name GameHud
extends Control

## Oyun içi HUD: duraklat düğmesi (sol), seviye başlığı (orta), jeton hapı (sağ).
## Güvenli alana (çentik/kamera) ve asgari kenar boşluğuna saygılıdır; tahtaya taşmaz.
## Jeton, `Progress` varsa onun değerini izler; yoksa `set_coins` ile verilen değeri gösterir.

signal pause_requested

const TITLE_SIZE: int = UiTokens.TYPE_NUMERIC_SM
## Başlık ile yan öğeler (duraklat düğmesi, jeton hapı) arası en az boşluk.
const TITLE_SIDE_GAP: float = UiKit.SPACE_MD
const TITLE_MAX_WIDTH: float = 400.0
const ROW_HEIGHT: float = UiKit.MIN_TOUCH
## Zincir hapı: başlığın altında, tahtanın üstünde küçük bir "×N" (ikon + sayı).
const CHAIN_ICON: String = "lucide/zap"
const CHAIN_ICON_PIXELS: float = UiKit.ICON_SM + 2.0
const CHAIN_FONT_SIZE: int = UiTokens.TYPE_NUMERIC_SM
const CHAIN_GAP: float = UiKit.SPACE_XS
const CHAIN_POP_SCALE: float = 1.2
const CHAIN_POP_IN_SECONDS: float = 0.12
const CHAIN_POP_OUT_SECONDS: float = 0.32
const CHAIN_FADE_SECONDS: float = 0.6
const CHAIN_FORMAT: String = "×%d"

var _title: Label = null
var _coin_chip: UiChip = null
var _pause_button: UiIconButton = null
var _has_progress_coins: bool = false
var _chain_pill: PanelContainer = null
var _chain_label: Label = null
var _chain_tween: Tween = null


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
	_title.position = Vector2(view.x * 0.5 - TITLE_MAX_WIDTH * 0.5, row_top)
	_title.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	_title.size = Vector2(TITLE_MAX_WIDTH, ROW_HEIGHT)
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Uzun başlık (EN/ES günlük bulmaca) yan öğelere binmesin: genişlik hap ölçüsüne göre kısılır, taşan "…" olur.
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_title)
	_coin_chip = UiChip.new()
	_coin_chip.setup("lucide/coins", UiKit.GOLD)
	add_child(_coin_chip)
	# Sağa yaslı: hap genişledikçe sol kenarı kayar, sağ kenarı sabit kalır.
	_coin_chip.resized.connect(_place_chip.bind(view, insets, row_top))
	_place_chip(view, insets, row_top)
	_build_chain_pill(view, row_top)
	UiData.connect_changed(_on_progress_changed)
	_on_progress_changed()


func set_level(number: int) -> void:
	_title.text = UiStrings.level(number)


## Progress yoksa jeton sayısı buradan gelir.
## Başlık rengi günün evresine göre değişir (gece koyu zeminde açık renk) ki okunur kalsın.
func set_title_color(color: Color) -> void:
	_title.add_theme_color_override("font_color", color)


## Günlük bulmaca gibi seviye numarası olmayan oyunlarda başlık doğrudan yazılır.
func set_title(text: String) -> void:
	_title.text = text


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
	# Başlık ekran ortasında kalır; yarı genişliği hapın sol kenarına ve duraklat düğmesine göre sınırlanır.
	var left_limit: float = insets.x + UiKit.SIDE_MARGIN + UiIconButton.DISC_DIAMETER + TITLE_SIDE_GAP
	var half: float = minf(TITLE_MAX_WIDTH * 0.5, minf(view.x * 0.5 - left_limit,
		_coin_chip.position.x - TITLE_SIDE_GAP - view.x * 0.5))
	_title.size.x = maxf(half, 0.0) * 2.0
	_title.position.x = view.x * 0.5 - half


func _build_chain_pill(view: Vector2, row_top: float) -> void:
	_chain_pill = PanelContainer.new()
	_chain_pill.theme_type_variation = &"ChipPanel"
	_chain_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chain_pill.modulate.a = 0.0
	_chain_pill.visible = false
	_chain_pill.position = Vector2(view.x * 0.5, row_top + ROW_HEIGHT + CHAIN_GAP)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", UiTokens.SPACE_SM)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chain_pill.add_child(row)
	var icon: TextureRect = UiKit.tinted_icon(CHAIN_ICON, CHAIN_ICON_PIXELS, UiKit.FLAME)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	_chain_label = UiKit.label("", CHAIN_FONT_SIZE)
	row.add_child(_chain_label)
	add_child(_chain_pill)


## Zincir adımı `step` (>= 2): hap yumuşakça belirir ve her adımda küçük bir "pop" yapar.
func show_chain(step: int) -> void:
	_kill_chain_tween()
	_chain_label.text = CHAIN_FORMAT % step
	_chain_pill.visible = true
	# Genişlik sayıyla değişir: merkez sabit kalsın diye boyut ve eksen her seferinde yenilenir.
	var pill_size: Vector2 = _chain_pill.get_combined_minimum_size()
	_chain_pill.size = pill_size
	_chain_pill.position.x = get_viewport_rect().size.x * 0.5 - pill_size.x * 0.5
	_chain_pill.pivot_offset = pill_size * 0.5
	_chain_pill.modulate.a = 1.0
	_chain_tween = create_tween()
	_chain_tween.tween_property(_chain_pill, "scale", Vector2.ONE * CHAIN_POP_SCALE, CHAIN_POP_IN_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_chain_tween.tween_property(_chain_pill, "scale", Vector2.ONE, CHAIN_POP_OUT_SECONDS)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Zincir koptu: hap yumuşakça söner.
func fade_chain() -> void:
	if not _chain_pill.visible:
		return
	_kill_chain_tween()
	_chain_tween = create_tween()
	_chain_tween.tween_property(_chain_pill, "modulate:a", 0.0, CHAIN_FADE_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_chain_tween.tween_callback(_chain_pill.hide)


## Seviye başı: hap anında gizlenir.
func hide_chain() -> void:
	_kill_chain_tween()
	_chain_pill.visible = false
	_chain_pill.modulate.a = 0.0
	_chain_pill.scale = Vector2.ONE


func _kill_chain_tween() -> void:
	if _chain_tween != null and _chain_tween.is_valid():
		_chain_tween.kill()
