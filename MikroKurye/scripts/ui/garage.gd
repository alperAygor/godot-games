extends Control

## Garaj: cüzdanı gösterir, yükseltme satın alır. Karar `UpgradeModel` ve
## `SaveService` içinde; bu script yalnızca gösterir ve yeniler.
## Sözleşme: ARCHITECTURE.md §5.4 + §5.5 (TRY_BEFORE_BUY).

const UPGRADES_TABLE: String = "upgrades"
const BUTTON_PREFIX: String = "UpgradeButton_"
const TRY_PREFIX: String = "TryButton_"
const BUTTON_MIN_HEIGHT: float = 148.0
const TRY_MIN_WIDTH: float = 220.0
const BUTTON_FONT_SIZE: int = 32
const TRY_FONT_SIZE: int = 30
const BACK_ICON_SIZE: int = 44

@onready var _gold_label: Label = %GoldLabel
@onready var _scrap_label: Label = %ScrapLabel
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %Title
@onready var _hint_label: Label = %Hint
@onready var _upgrade_list: VBoxContainer = %UpgradeList

var _buttons: Dictionary[String, Button] = {}
var _try_buttons: Dictionary[String, Button] = {}
var _ad: Node = null
var _trial_pending: String = ""


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.GARAGE)
	_title_label.text = UiStrings.GARAGE_TITLE
	_hint_label.text = UiStrings.GARAGE_HINT
	_back_button.text = UiStrings.BACK
	Icons.apply(_back_button, "lucide/arrow-left", Color(0.29, 0.20, 0.09), BACK_ICON_SIZE)
	_back_button.pressed.connect(_on_back)
	GameManager.back_requested.connect(_on_back)
	_ad = get_node_or_null("/root/AdManager")
	if _ad != null:
		if not _ad.is_connected("rewarded_finished", _on_ad_rewarded):
			_ad.connect("rewarded_finished", _on_ad_rewarded)
		if not _ad.is_connected("ad_failed", _on_ad_failed):
			_ad.connect("ad_failed", _on_ad_failed)
	_build_rows()
	_refresh()
	# Dinamik kategori düğmeleri kurulduktan sonra tek yerden tıklama sesi.
	UiSfx.bind(self)


func _build_rows() -> void:
	for child: Node in _upgrade_list.get_children():
		child.queue_free()
	_buttons.clear()
	_try_buttons.clear()
	var table: Dictionary = GameData.table(UPGRADES_TABLE)
	for key: Variant in table.keys():
		var category: String = String(key)
		var row: HBoxContainer = HBoxContainer.new()
		row.name = "Row_" + category
		row.add_theme_constant_override("separation", 16)
		_upgrade_list.add_child(row)

		var button: Button = Button.new()
		# Probe ve kabul denetimi bu adı arar; kategori veriden gelir.
		button.name = BUTTON_PREFIX + category
		button.custom_minimum_size = Vector2(0.0, BUTTON_MIN_HEIGHT)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_on_upgrade_pressed.bind(category))
		row.add_child(button)
		_buttons[category] = button

		var try_button: Button = Button.new()
		try_button.name = TRY_PREFIX + category
		try_button.custom_minimum_size = Vector2(TRY_MIN_WIDTH, BUTTON_MIN_HEIGHT)
		try_button.add_theme_font_size_override("font_size", TRY_FONT_SIZE)
		try_button.text = UiStrings.TRY_BEFORE_BUY
		try_button.pressed.connect(_on_try_pressed.bind(category))
		row.add_child(try_button)
		_try_buttons[category] = try_button


func _refresh() -> void:
	var pending: bool = not _trial_pending.is_empty()
	var can_try: bool = not pending and _ad != null \
		and bool(_ad.call("can_offer", AdManager.Placement.TRY_BEFORE_BUY))
	_back_button.disabled = pending
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
		button.disabled = pending or cost.is_empty() or not wallet.can_afford(cost)
		# Maksimum seviyede deneme anlamsızdır; düğme gizlenir (§5.5).
		var try_button: Button = _try_buttons.get(category) as Button
		if try_button != null:
			try_button.visible = not cost.is_empty()
			try_button.disabled = not can_try or cost.is_empty()


func _on_upgrade_pressed(category: String) -> void:
	if not _trial_pending.is_empty():
		return
	# Disabled düğme programatik sinyalle de gelebilir: bakiyeyi burada da doğrula.
	var cost: Dictionary = SaveService.upgrade_cost(category)
	if cost.is_empty() or not SaveService.profile().wallet().can_afford(cost):
		return
	if SaveService.purchase(category):
		_refresh()


## Deneme reklamı: başarılıysa kategori bir sonraki koşu için açılır; seviye
## satın alınmaz, dolayısıyla Satın Al düğmesi ve cüzdan değişmez.
func _on_try_pressed(category: String) -> void:
	if _ad == null or not _trial_pending.is_empty():
		return
	var button: Button = _try_buttons.get(category) as Button
	if button == null or not button.visible or button.disabled:
		return
	if SaveService.upgrade_cost(category).is_empty():
		return
	if not bool(_ad.call("can_offer", AdManager.Placement.TRY_BEFORE_BUY)):
		return
	_trial_pending = category
	_refresh()
	_ad.call("show_rewarded", AdManager.Placement.TRY_BEFORE_BUY)


func _on_ad_rewarded(placement: int, success: bool) -> void:
	if placement != AdManager.Placement.TRY_BEFORE_BUY or _trial_pending.is_empty():
		return
	var category: String = _trial_pending
	_trial_pending = ""
	if success and not category.is_empty():
		SaveService.set_trial(category)
	_refresh()


func _on_ad_failed(placement: int, _reason: String) -> void:
	if placement == AdManager.Placement.TRY_BEFORE_BUY:
		_trial_pending = ""
		_refresh()


func _on_back() -> void:
	if not _trial_pending.is_empty():
		return
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
