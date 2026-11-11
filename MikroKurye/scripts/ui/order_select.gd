extends Control

## Sipariş seçimi: kartlar `data/cargo.json`'dan kurulur, kargo sayısı değişince
## kod değişmez. Sözleşme: ARCHITECTURE.md §5.4.
##
## Yalnızca gösterir ve seçimi GameManager'a yazar; sahne geçişi GameManager'da.

const CARGO_TABLE: String = "cargo"
const CARD_PREFIX: String = "CargoCard_"
const CARD_MIN_HEIGHT: float = 148.0
const CARD_FONT_SIZE: int = 34
const BACK_ICON_SIZE: int = 44

@onready var _card_list: VBoxContainer = %CardList
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %Title
@onready var _hint_label: Label = %Hint


func _ready() -> void:
	_title_label.text = UiStrings.ORDER_TITLE
	_hint_label.text = UiStrings.ORDER_HINT
	_back_button.text = UiStrings.BACK
	Icons.apply(_back_button, "lucide/arrow-left", Color(0.29, 0.20, 0.09), BACK_ICON_SIZE)
	_back_button.pressed.connect(_on_back)
	GameManager.back_requested.connect(_on_back)
	_build_cards()
	# Kartlar veriden üretildi; tıklama sesi ancak şimdi bağlanabilir.
	UiSfx.bind(self)


func _build_cards() -> void:
	for child: Node in _card_list.get_children():
		child.queue_free()
	var table: Dictionary = GameData.table(CARGO_TABLE)
	for key: Variant in table.keys():
		var cargo_id: String = String(key)
		var profile_raw: Variant = table.get(key)
		if not profile_raw is Dictionary:
			continue
		_card_list.add_child(_make_card(cargo_id, profile_raw as Dictionary))


func _make_card(cargo_id: String, profile: Dictionary) -> Button:
	var card: Button = Button.new()
	# Probe ve kabul denetimi bu adı arar; kargo kimliği veriden gelir.
	card.name = CARD_PREFIX + cargo_id
	var display_name: String = UiStrings.cargo_name(String(profile.get("name_key", cargo_id)))
	card.text = UiStrings.cargo_card(display_name,
		int(profile.get("difficulty", 0)), int(profile.get("reward_gold", 0)))
	card.custom_minimum_size = Vector2(0.0, CARD_MIN_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Uzun adlar tek satıra sığmaz; dokunma hedefi yüksekliği korunur.
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_theme_font_size_override("font_size", CARD_FONT_SIZE)
	card.pressed.connect(_on_card_pressed.bind(cargo_id))
	return card


func _on_card_pressed(cargo_id: String) -> void:
	GameManager.selected_cargo_id = cargo_id
	GameManager.start_game()


func _on_back() -> void:
	GameManager.goto_scene(&"menu")
