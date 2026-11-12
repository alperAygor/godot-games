extends Control

## Sipariş seçimi: kartlar `data/cargo.json`'dan kurulur, kargo sayısı değişince
## kod değişmez. Sözleşme: ARCHITECTURE.md §5.4.
##
## F7.6b: her kartta büyük kargo görseli, ad, zorluk noktaları ve altın/hurda
## ödül çipleri bulunur; renk/ölçü `UiTheme` (data/theme.json) token'larından okunur.

const CARGO_TABLE: String = "cargo"
const CARD_PREFIX: String = "CargoCard_"
const CARGO_IMAGE_DIR: String = "res://assets/ui/cargo_"
const CARGO_IMAGE_SUFFIX: String = ".png"
const BACK_ICON_SIZE: int = 44
const CARD_MIN_HEIGHT: float = 300.0
const CARD_IMAGE_SIZE: float = 220.0
const NAME_FONT_SIZE: int = 40
const DOTS_TOTAL: int = 3
const DOT_SIZE: float = 24.0
const CHIP_ICON_SIZE: float = 40.0
const REWARD_FONT_SIZE: int = 32
const CARD_PADDING: int = 24
const CARD_SEPARATION: int = 28

@onready var _card_list: VBoxContainer = %CardList
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %Title
@onready var _hint_label: Label = %Hint

var _cards: Array[Control] = []


func _ready() -> void:
	_stylize()
	_title_label.text = UiStrings.ORDER_TITLE
	_hint_label.text = UiStrings.ORDER_HINT
	_back_button.text = UiStrings.BACK
	Icons.apply(_back_button, "lucide/arrow-left", UiTheme.color("on_surface"), BACK_ICON_SIZE)
	_back_button.add_theme_constant_override("h_separation", 14)
	_back_button.pressed.connect(_on_back)
	GameManager.back_requested.connect(_on_back)
	_build_cards()
	# Dinamik kartlar kurulduktan sonra tıklama sesi + basış geri bildirimi.
	UiSfx.bind(self)
	UiMotion.fade_in(self)
	UiMotion.stagger_pop(_cards)


func _stylize() -> void:
	(%Background as ColorRect).color = UiTheme.color("background")
	_title_label.add_theme_color_override("font_color", UiTheme.color("text"))
	_hint_label.add_theme_color_override("font_color", UiTheme.color("text_muted"))


func _build_cards() -> void:
	for child: Node in _card_list.get_children():
		child.queue_free()
	_cards.clear()
	var table: Dictionary = GameData.table(CARGO_TABLE)
	for key: Variant in table.keys():
		var cargo_id: String = String(key)
		var profile_raw: Variant = table.get(key)
		if not profile_raw is Dictionary:
			continue
		var card: Button = _make_card(cargo_id, profile_raw as Dictionary)
		_card_list.add_child(card)
		_cards.append(card)


func _make_card(cargo_id: String, profile: Dictionary) -> Button:
	var card := Button.new()
	# Probe ve kabul denetimi bu adı arar; kargo kimliği veriden gelir.
	card.name = CARD_PREFIX + cargo_id
	card.custom_minimum_size = Vector2(0.0, CARD_MIN_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_card_style(card)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", CARD_PADDING)
	margin.add_theme_constant_override("margin_right", CARD_PADDING)
	margin.add_theme_constant_override("margin_top", CARD_PADDING)
	margin.add_theme_constant_override("margin_bottom", CARD_PADDING)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", CARD_SEPARATION)
	margin.add_child(row)

	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(CARD_IMAGE_SIZE, CARD_IMAGE_SIZE)
	image.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	image.texture = _cargo_texture(cargo_id)
	row.add_child(image)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override("separation", 16)
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = UiStrings.cargo_name(String(profile.get("name_key", cargo_id)))
	name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	name_label.add_theme_color_override("font_color", UiTheme.color("text"))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(name_label)

	info.add_child(_make_dots(int(profile.get("difficulty", 0))))

	var reward_row := HBoxContainer.new()
	reward_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_row.add_theme_constant_override("separation", 20)
	info.add_child(reward_row)
	reward_row.add_child(_make_reward_chip("lucide/coins", UiTheme.color("secondary"),
		int(profile.get("reward_gold", 0))))
	reward_row.add_child(_make_reward_chip("lucide/cog", UiTheme.color("text_muted"),
		int(profile.get("reward_scrap", 0))))

	card.pressed.connect(_on_card_pressed.bind(cargo_id))
	return card


## Zorluk noktaları: toplam 3, dolu = zorluk değeri (●●○ biçiminde).
func _make_dots(difficulty: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	for i: int in DOTS_TOTAL:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(DOT_SIZE, DOT_SIZE)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(int(DOT_SIZE * 0.5))
		style.bg_color = UiTheme.color("primary") if i < difficulty \
			else UiTheme.color("text_muted", 0.25)
		dot.add_theme_stylebox_override("panel", style)
		row.add_child(dot)
	return row


func _make_reward_chip(icon_name: String, tint: Color, amount: int) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"ChipPanel"
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inner := HBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override("separation", 10)
	chip.add_child(inner)
	var icon := TextureRect.new()
	icon.texture = Icons.texture(icon_name)
	icon.modulate = tint
	icon.custom_minimum_size = Vector2(CHIP_ICON_SIZE, CHIP_ICON_SIZE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(icon)
	var value := Label.new()
	value.text = str(amount)
	value.add_theme_font_size_override("font_size", REWARD_FONT_SIZE)
	value.add_theme_color_override("font_color", UiTheme.color("text"))
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(value)
	return chip


func _cargo_texture(cargo_id: String) -> Texture2D:
	var path: String = CARGO_IMAGE_DIR + cargo_id + CARGO_IMAGE_SUFFIX
	if ResourceLoader.exists(path):
		var loaded: Texture2D = load(path) as Texture2D
		if loaded != null:
			return loaded
	# Görsel yoksa tek aileden bir yedek ikon; kart yine okunur kalır.
	return Icons.texture("lucide/package")


func _apply_card_style(card: Button) -> void:
	var radius: int = int(UiTheme.metric("radius", 28.0))
	card.add_theme_stylebox_override("normal",
		UiTheme.stylebox("surface", "text", radius, 0.90, 0.08, true))
	card.add_theme_stylebox_override("hover",
		UiTheme.stylebox("surface", "primary", radius, 1.0, 0.55, true))
	card.add_theme_stylebox_override("pressed",
		UiTheme.stylebox("surface_soft", "primary", radius, 1.0, 0.65, true))
	card.add_theme_stylebox_override("focus",
		UiTheme.stylebox("surface", "text", radius, 0.90, 0.08, false))
	card.add_theme_color_override("font_color", UiTheme.color("text"))
	card.add_theme_color_override("font_hover_color", UiTheme.color("text"))
	card.add_theme_color_override("font_pressed_color", UiTheme.color("text"))


func _on_card_pressed(cargo_id: String) -> void:
	GameManager.selected_cargo_id = cargo_id
	GameManager.start_game()


func _on_back() -> void:
	GameManager.goto_scene(&"menu")
