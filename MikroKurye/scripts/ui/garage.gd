extends Control

## Garaj: cüzdanı gösterir, yükseltme satın alır. Karar `UpgradeModel` ve
## `SaveService` içinde; bu script yalnızca gösterir ve yeniler.
## Sözleşme: ARCHITECTURE.md §5.4 + §5.5 (TRY_BEFORE_BUY).
##
## F7.6b: 2×2 kart ızgarası; her kartta ikon, ad, seviye pip'leri, sonraki
## seviyenin etkisi ve fiyat çipleri; yetersiz bakiye soluk + kilit gösterir.

const UPGRADES_TABLE: String = "upgrades"
const BUTTON_PREFIX: String = "UpgradeButton_"
const TRY_PREFIX: String = "TryButton_"
const BACK_ICON_SIZE: int = 44
const WALLET_ICON_SIZE: float = 40.0
const CATEGORY_ICON_SIZE: float = 48.0
const LOCK_ICON_SIZE: float = 44.0
const PIP_SIZE: float = 22.0
const CHIP_ICON_SIZE: float = 36.0
const NAME_FONT_SIZE: int = 36
const EFFECT_FONT_SIZE: int = 26
const PRICE_FONT_SIZE: int = 30
const WALLET_FONT_SIZE: int = 36

@onready var _gold_label: Label = %GoldLabel
@onready var _scrap_label: Label = %ScrapLabel
@onready var _gold_icon: TextureRect = %GoldIcon
@onready var _scrap_icon: TextureRect = %ScrapIcon
@onready var _back_button: Button = %BackButton
@onready var _title_label: Label = %Title
@onready var _hint_label: Label = %Hint
@onready var _upgrade_list: GridContainer = %UpgradeList

var _buttons: Dictionary[String, Button] = {}
var _try_buttons: Dictionary[String, Button] = {}
var _content: Dictionary[String, Control] = {}
var _pips: Dictionary[String, HBoxContainer] = {}
var _price: Dictionary[String, HBoxContainer] = {}
var _locks: Dictionary[String, TextureRect] = {}
var _ad: Node = null
var _trial_pending: String = ""
var _cards: Array[Control] = []


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.GARAGE)
	_stylize()
	_title_label.text = UiStrings.GARAGE_TITLE
	_hint_label.text = UiStrings.GARAGE_HINT
	_back_button.text = UiStrings.BACK
	Icons.apply(_back_button, "lucide/arrow-left", UiTheme.color("on_surface"), BACK_ICON_SIZE)
	_back_button.add_theme_constant_override("h_separation", 14)
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
	UiMotion.fade_in(self)
	UiMotion.stagger_pop(_cards)


func _stylize() -> void:
	(%Background as ColorRect).color = UiTheme.color("background")
	_title_label.add_theme_color_override("font_color", UiTheme.color("text"))
	_hint_label.add_theme_color_override("font_color", UiTheme.color("text_muted"))
	_gold_label.add_theme_color_override("font_color", UiTheme.color("text"))
	_scrap_label.add_theme_color_override("font_color", UiTheme.color("text"))
	_gold_icon.texture = Icons.texture("lucide/coins")
	_scrap_icon.texture = Icons.texture("lucide/cog")
	_gold_icon.modulate = UiTheme.color("secondary")
	_scrap_icon.modulate = UiTheme.color("text_muted")


func _build_rows() -> void:
	for child: Node in _upgrade_list.get_children():
		child.queue_free()
	_buttons.clear()
	_try_buttons.clear()
	_content.clear()
	_pips.clear()
	_price.clear()
	_locks.clear()
	_cards.clear()
	var table: Dictionary = GameData.table(UPGRADES_TABLE)
	for key: Variant in table.keys():
		var category: String = String(key)
		var card: PanelContainer = _make_card(category)
		_upgrade_list.add_child(card)
		_cards.append(card)


func _make_card(category: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	card.add_child(column)

	# İçerik yetersiz bakiyede soluklaşır; butonlar sönük kalmaz.
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	column.add_child(content)
	_content[category] = content

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	content.add_child(header)

	var icon := TextureRect.new()
	icon.texture = Icons.texture(_category_icon(category))
	icon.modulate = UiTheme.color("primary_dark")
	icon.custom_minimum_size = Vector2(CATEGORY_ICON_SIZE, CATEGORY_ICON_SIZE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)

	var name_label := Label.new()
	name_label.text = UiStrings.category_name(category)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	name_label.add_theme_color_override("font_color", UiTheme.color("text"))
	header.add_child(name_label)

	var lock := TextureRect.new()
	lock.texture = Icons.texture("lucide/lock")
	lock.modulate = UiTheme.color("text_muted")
	lock.custom_minimum_size = Vector2(LOCK_ICON_SIZE, LOCK_ICON_SIZE)
	lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock.visible = false
	header.add_child(lock)
	_locks[category] = lock

	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 8)
	content.add_child(pips)
	_pips[category] = pips

	var effect := Label.new()
	effect.text = UiStrings.category_effect(category)
	effect.add_theme_font_size_override("font_size", EFFECT_FONT_SIZE)
	effect.add_theme_color_override("font_color", UiTheme.color("text_muted"))
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(effect)

	var price := HBoxContainer.new()
	price.add_theme_constant_override("separation", 14)
	content.add_child(price)
	_price[category] = price

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	column.add_child(buttons)

	var buy := Button.new()
	# Probe ve kabul denetimi bu adı arar; kategori veriden gelir.
	buy.name = BUTTON_PREFIX + category
	buy.text = UiStrings.BUY
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy.custom_minimum_size = Vector2(0.0, 96.0)
	buy.pressed.connect(_on_upgrade_pressed.bind(category))
	buttons.add_child(buy)
	_buttons[category] = buy

	var try_button := Button.new()
	try_button.name = TRY_PREFIX + category
	try_button.text = UiStrings.TRY_BEFORE_BUY
	try_button.theme_type_variation = &"SecondaryButton"
	try_button.custom_minimum_size = Vector2(170.0, 96.0)
	try_button.pressed.connect(_on_try_pressed.bind(category))
	buttons.add_child(try_button)
	_try_buttons[category] = try_button

	return card


func _category_icon(category: String) -> String:
	match category:
		"chassis":
			return "lucide/truck"
		"wheels":
			return "lucide/refresh-cw"
		"battery":
			return "lucide/zap"
		"shock_gel":
			return "lucide/shield"
		_:
			return "lucide/package"


func _refresh() -> void:
	var pending: bool = not _trial_pending.is_empty()
	var can_try: bool = not pending and _ad != null \
		and bool(_ad.call("can_offer", AdManager.Placement.TRY_BEFORE_BUY))
	_back_button.disabled = pending
	var profile: ProfileData = SaveService.profile()
	var wallet: Wallet = profile.wallet()
	_gold_label.text = str(wallet.gold())
	_scrap_label.text = str(wallet.scrap())
	for key: Variant in _buttons.keys():
		var category: String = String(key)
		var cost: Dictionary = SaveService.upgrade_cost(category)
		var maxed: bool = cost.is_empty()
		var affordable: bool = wallet.can_afford(cost)
		var level: int = profile.level(category)
		var max_level: int = _max_level(category)
		_rebuild_pips(_pips[category], level, max_level)
		_rebuild_price(_price[category], cost, maxed)
		(_locks[category]).visible = maxed or not affordable
		# Yetersiz bakiyede kart içeriği soluk; maksimumda kilit zaten söyler.
		(_content[category]).modulate.a = 0.55 if (not maxed and not affordable) else 1.0
		var button: Button = _buttons[category]
		button.text = UiStrings.MAX_LEVEL if maxed else UiStrings.BUY
		button.disabled = pending or maxed or not affordable
		var try_button: Button = _try_buttons[category]
		try_button.visible = not maxed
		try_button.disabled = not can_try or maxed


func _rebuild_pips(box: HBoxContainer, level: int, max_level: int) -> void:
	for child: Node in box.get_children():
		child.queue_free()
	var total: int = maxi(max_level, 1)
	for i: int in total:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(PIP_SIZE, PIP_SIZE)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(int(PIP_SIZE * 0.5))
		style.bg_color = UiTheme.color("primary") if i < level \
			else UiTheme.color("text_muted", 0.22)
		dot.add_theme_stylebox_override("panel", style)
		box.add_child(dot)


func _rebuild_price(box: HBoxContainer, cost: Dictionary, maxed: bool) -> void:
	for child: Node in box.get_children():
		child.queue_free()
	if maxed:
		var label := Label.new()
		label.text = UiStrings.MAX_LEVEL
		label.add_theme_font_size_override("font_size", PRICE_FONT_SIZE)
		label.add_theme_color_override("font_color", UiTheme.color("text_muted"))
		box.add_child(label)
		return
	box.add_child(_make_price_chip("lucide/coins", UiTheme.color("secondary"),
		int(cost.get("gold", 0))))
	box.add_child(_make_price_chip("lucide/cog", UiTheme.color("text_muted"),
		int(cost.get("scrap", 0))))


func _make_price_chip(icon_name: String, tint: Color, amount: int) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.theme_type_variation = &"ChipPanel"
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	chip.add_child(inner)
	var icon := TextureRect.new()
	icon.texture = Icons.texture(icon_name)
	icon.modulate = tint
	icon.custom_minimum_size = Vector2(CHIP_ICON_SIZE, CHIP_ICON_SIZE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	inner.add_child(icon)
	var value := Label.new()
	value.text = str(amount)
	value.add_theme_font_size_override("font_size", PRICE_FONT_SIZE)
	value.add_theme_color_override("font_color", UiTheme.color("text"))
	inner.add_child(value)
	return chip


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
