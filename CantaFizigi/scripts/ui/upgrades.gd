extends Control

## Yukseltme ekrani: satirlar `data/upgrades.json`'dan uretilir (elle yazilmaz).
## Fiyat/limit matematigi Economy'de; burada yalnizca gosterim ve satin alma var.

@onready var currency_label: Label = %Currency
@onready var hint_label: Label = %Hint
@onready var list_box: VBoxContainer = %List

var _table: Dictionary = {}


func _ready() -> void:
	_table = GameData.table("upgrades")
	(%BackButton as Button).pressed.connect(_on_back)
	GameManager.back_requested.connect(_on_back)
	GameManager.currency_changed.connect(_on_currency_changed)
	_rebuild()


func _on_back() -> void:
	GameManager.goto_scene(&"menu")


func _on_currency_changed(amount: int) -> void:
	currency_label.text = "Para: %d" % amount


func _rebuild() -> void:
	for child: Node in list_box.get_children():
		child.queue_free()
	currency_label.text = "Para: %d" % GameManager.profile.currency
	var ids: Array = _table.keys()
	ids.sort()
	for upgrade_id: Variant in ids:
		list_box.add_child(_build_row(String(upgrade_id)))


func _build_row(upgrade_id: String) -> HBoxContainer:
	var data: Dictionary = Economy.row(_table, upgrade_id)
	var level: int = GameManager.profile.upgrade_level(upgrade_id)
	var limit: int = Economy.max_level(_table, upgrade_id)
	var price: int = Economy.cost(_table, upgrade_id, level)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)

	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)

	var title: Label = Label.new()
	title.text = "%s  (%d/%d)" % [String(data.get("label", upgrade_id)), level, limit]
	title.add_theme_font_size_override("font_size", 34)
	column.add_child(title)

	var description: Label = Label.new()
	description.text = String(data.get("description", ""))
	description.add_theme_font_size_override("font_size", 22)
	description.add_theme_color_override("font_color", Color(0.478, 0.416, 0.369, 1.0))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(description)

	var buy: Button = Button.new()
	buy.custom_minimum_size = Vector2(260, 96)
	if price == Economy.INVALID:
		buy.text = "Maks"
		buy.disabled = true
	else:
		buy.text = "%d" % price
		buy.disabled = GameManager.profile.currency < price
	buy.pressed.connect(_on_buy.bind(upgrade_id))
	row.add_child(buy)
	return row


func _on_buy(upgrade_id: String) -> void:
	var level: int = GameManager.profile.upgrade_level(upgrade_id)
	var price: int = Economy.cost(_table, upgrade_id, level)
	if price == Economy.INVALID:
		return
	if not GameManager.spend_currency(price):
		hint_label.text = "Para yetersiz"
		return
	GameManager.profile.set_upgrade_level(upgrade_id, level + 1)
	GameManager.save_profile()
	hint_label.text = "Alındı: %s" % String(Economy.row(_table, upgrade_id).get("label", upgrade_id))
	_rebuild()
