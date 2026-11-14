extends Control
## Market: "Reklamları Kaldır" (no_ads, tek seferlik) ve satın alımları geri yükle. Sahiplik Monetization'da; burası sadece gösterir.
## Satın alma yalnızca geçiş reklamlarını kapatır; ödüllü reklamlar isteğe bağlı kalır (ve Destekçi masa süsü verir).

var _status: Label
var _buy: Button


func _ready() -> void:
	var column := UiKit.screen_column(self, 16)
	column.add_child(UiKit.label(tr("MARKET_TITLE"), &"BoothTitle", "MarketTitle"))
	var card := UiKit.card(tr("MARKET_NO_ADS_TITLE"), &"FloatCard", "NoAdsCard")
	card.add_child(UiKit.wrapped(tr("MARKET_NO_ADS_TEXT"), &"GoalLabel", "NoAdsText"))
	_buy = UiKit.button("", "BuyNoAdsButton", &"InkButton", 92.0)
	_buy.pressed.connect(_on_buy)
	card.add_child(_buy)
	column.add_child(card.get_meta("panel"))
	_status = UiKit.wrapped("", &"BoothBody", "MarketStatus")
	column.add_child(_status)
	var restore := UiKit.icon_button("refresh", tr("MARKET_RESTORE"), "RestoreButton", true, true, 84.0)
	restore.pressed.connect(_on_restore)
	column.add_child(restore)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	var back := UiKit.icon_button("back", tr("COMMON_BACK"), "BackButton", true, true, 88.0)
	back.pressed.connect(SceneManager.back)
	column.add_child(back)
	Monetization.purchase_result.connect(_on_purchase_result)
	Monetization.restore_result.connect(_on_restore_result)
	_refresh()
	print("[Market] hazır")


func _exit_tree() -> void:
	if Monetization.purchase_result.is_connected(_on_purchase_result):
		Monetization.purchase_result.disconnect(_on_purchase_result)
	if Monetization.restore_result.is_connected(_on_restore_result):
		Monetization.restore_result.disconnect(_on_restore_result)


func handle_back() -> bool:
	return false


func _refresh() -> void:
	if Monetization.owns_no_ads():
		_buy.text = tr("MARKET_OWNED")
		_buy.disabled = true
	elif not Monetization.store_available():
		_buy.text = tr("MARKET_STORE_OFF")
		_buy.disabled = true
	else:
		_buy.text = tr("MARKET_BUY") % Monetization.price_text(Monetization.NO_ADS)
		_buy.disabled = false


func _on_buy() -> void:
	_buy.disabled = true
	_status.text = ""
	Monetization.buy(Monetization.NO_ADS)


func _on_purchase_result(_product_id: String, success: bool, _error: String) -> void:
	_status.text = tr("MARKET_BOUGHT") if success else tr("MARKET_FAILED")
	_refresh()


func _on_restore() -> void:
	_status.text = ""
	Monetization.restore()


func _on_restore_result(product_ids: PackedStringArray) -> void:
	_status.text = tr("MARKET_RESTORED") if not product_ids.is_empty() else tr("MARKET_NOTHING_RESTORED")
	_refresh()
