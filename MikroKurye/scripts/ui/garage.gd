extends Control

## Garaj: cüzdanı gösterir, yükseltme satın alır. Karar `UpgradeModel` ve
## `SaveService` içinde; bu script yalnızca gösterir ve yeniler.
## Sözleşme: ARCHITECTURE.md §5.4.

const UPGRADES_TABLE: String = "upgrades"
const BUTTON_PREFIX: String = "UpgradeButton_"
const BUTTON_MIN_HEIGHT: float = 148.0
const BUTTON_FONT_SIZE: int = 32
const BACK_ICON_SIZE: int = 44

@onready var _gold_label: Label = %GoldLabel
@onready var _scrap_label: Label = %ScrapLabel
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %Title
@onready var _hint_label: Label = %Hint
@onready var _upgrade_list: VBoxContainer = %UpgradeList

var _buttons: Dictionary[String, Button] = {}


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.GARAGE)
	_title_label.text = UiStrings.GARAGE_TITLE
	_hint_label.text = UiStrings.GARAGE_HINT
	_back_button.text = UiStrings.BACK
	Icons.apply(_back_button, "lucide/arrow-left", Color(0.29, 0.20, 0.09), BACK_ICON_SIZE)
	_back_button.pressed.connect(_on_back)
	GameManager.back_requested.connect(_on_back)
	_build_rows()
	_refresh()


func _build_rows() -> void:
	for child: Node in _upgrade_list.get_children():
		child.queue_free()
	_buttons.clear()
	var table: Dictionary = GameData.table(UPGRADES_TABLE)
	for key: Variant in table.keys():
		var category: String = String(key)
		var button: Button = Button.new()
		# Probe ve kabul denetimi bu adı arar; kategori veriden gelir.
		button.name = BUTTON_PREFIX + category
		button.custom_minimum_size = Vector2(0.0, BUTTON_MIN_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_upgrade_pressed.bind(category))
		_upgrade_list.add_child(button)
		_buttons[category] = button


func _refresh() -> void:
	var wallet: Wallet = SaveService.profile().wallet()
	_gold_label.text = UiStrings.gold_label(wallet.gold())
	_scrap_label.text = UiStrings.scrap_label(wallet.scrap())
	for key: Variant in _buttons.keys():
		var category: String = String(key)
		var button: Button = _buttons[category]
		var cost: Dictionary = SaveService.upgrade_cost(category)
		button.text = UiStrings.upgrade_button(category,
			SaveService.profile().level(category), _max_level(category), cost)
		# Maliyet yoksa kategori maksimumdadır; aksi hâlde bakiyeye bakılır.
		button.disabled = cost.is_empty() or not wallet.can_afford(cost)


func _on_upgrade_pressed(category: String) -> void:
	# Disabled düğme programatik sinyalle de gelebilir: bakiyeyi burada da doğrula.
	var cost: Dictionary = SaveService.upgrade_cost(category)
	if cost.is_empty() or not SaveService.profile().wallet().can_afford(cost):
		return
	if SaveService.purchase(category):
		AudioService.play("ui_tap")
		_refresh()


func _on_back() -> void:
	AudioService.play("ui_tap")
	GameManager.goto_scene(&"menu")


func _max_level(category: String) -> int:
	var entry_raw: Variant = GameData.table(UPGRADES_TABLE).get(category)
	if not entry_raw is Dictionary:
		return 0
	var entry: Dictionary = entry_raw as Dictionary
	var max_raw: Variant = entry.get("max_level")
	if typeof(max_raw) == TYPE_INT:
		return maxi(int(max_raw), 0)
	if typeof(max_raw) == TYPE_FLOAT:
		return maxi(int(roundf(float(max_raw))), 0)
	# max_level bozuksa tablodaki seviye sayısı üst sınırdır (UpgradeModel gibi).
	var levels_raw: Variant = entry.get("levels")
	if levels_raw is Array:
		return (levels_raw as Array).size()
	return 0
