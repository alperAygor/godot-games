class_name UiShopRow
extends VBoxContainer

## "Reklamları kaldır" satırı (ayarlar ve mağaza sayfasında ortak): fiyat mağazadan gelir, satın alma,
## geri yükleme, sahip olunan durum. Yalnız `IapService` ile konuşur (SDK türleri burada yok).
## Sahip olunca satın alma düğmesi yerine sakin "Reklamlar kaldırıldı" satırı görünür.
## Yalnız GEÇİŞ reklamlarını kapatır; ipucu ve atlama ödüllü kalır (kısa not satırı bunu söyler).

const NOTE_SIZE: int = UiKit.TYPE_CAPTION
const MESSAGE_SECONDS: float = 3.0
const RESTORE_HEIGHT: float = UiKit.MIN_TOUCH
const ROW_GAP: int = UiTokens.SPACE_SM

var _service: IapService = null
var _buy: Button = null
var _owned_row: Control = null
var _note: Label = null
var _restore: Button = null
var _message: Label = null
var _message_ticket: int = 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", ROW_GAP)


func _ready() -> void:
	_service = IapService.ensure(get_tree())
	_buy = UiKit.button(UiStrings.shop_remove_ads(), &"SecondaryButton", "lucide/ban", UiKit.HEIGHT_SECONDARY)
	_buy.name = "RemoveAdsButton"
	_buy.pressed.connect(_on_buy)
	add_child(_buy)
	_owned_row = _build_owned()
	add_child(_owned_row)
	_note = UiKit.wrap_label(UiStrings.shop_note(), NOTE_SIZE, UiKit.TEXT_MUTED)
	add_child(_note)
	_restore = Button.new()
	_restore.name = "RestoreButton"
	_restore.flat = true
	_restore.focus_mode = Control.FOCUS_NONE
	_restore.custom_minimum_size = Vector2(0.0, RESTORE_HEIGHT)
	_restore.text = UiStrings.shop_restore()
	_restore.add_theme_font_size_override("font_size", NOTE_SIZE + 4)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_restore.add_theme_color_override(color_name, UiKit.TEXT_MUTED)
	var none: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		_restore.add_theme_stylebox_override(state, none)
	_restore.pressed.connect(_on_restore)
	add_child(_restore)
	_message = UiKit.wrap_label("", NOTE_SIZE, UiKit.FLAME)
	_message.name = "Message"
	add_child(_message)
	_service.state_changed.connect(_refresh)
	_service.purchase_failed.connect(_on_purchase_failed)
	_service.restore_done.connect(_on_restore_done)
	_refresh()


func _exit_tree() -> void:
	if _service == null or not is_instance_valid(_service):
		return
	if _service.state_changed.is_connected(_refresh):
		_service.state_changed.disconnect(_refresh)
	if _service.purchase_failed.is_connected(_on_purchase_failed):
		_service.purchase_failed.disconnect(_on_purchase_failed)
	if _service.restore_done.is_connected(_on_restore_done):
		_service.restore_done.disconnect(_on_restore_done)


func _build_owned() -> Control:
	var holder: CenterContainer = CenterContainer.new()
	holder.name = "OwnedRow"
	holder.custom_minimum_size = Vector2(0.0, UiKit.HEIGHT_SECONDARY)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", UiKit.BUTTON_ICON_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(row)
	row.add_child(UiKit.tinted_icon("lucide/check", UiKit.ICON_MD, UiKit.ACCENT))
	row.add_child(UiKit.label(UiStrings.shop_ads_removed(), UiKit.SECONDARY_FONT_SIZE, UiKit.TEXT))
	return holder


## Sahiplik / fiyat / mağaza durumuna göre satırı yeniler.
func _refresh() -> void:
	var owned: bool = _service.remove_ads_owned()
	_buy.visible = not owned
	_owned_row.visible = owned
	_note.visible = not owned
	_restore.visible = not owned
	var price: String = _service.price_text()
	var caption: String = UiStrings.shop_remove_ads()
	UiKit.set_button_text(_buy, caption + " · " + price if not price.is_empty() else caption)
	UiKit.set_enabled(_buy, _service.store_available())


func _on_buy() -> void:
	_service.buy_remove_ads()


func _on_restore() -> void:
	_service.restore_purchases()


func _on_purchase_failed(reason: String) -> void:
	# İptal bir hata değildir: sessiz kalır.
	if reason != IapProvider.REASON_CANCELED:
		_say(reason)


func _on_restore_done(found: bool) -> void:
	_say("restored" if found else "nothing")


func _say(code: String) -> void:
	_message.text = UiStrings.shop_message(code)
	_message_ticket += 1
	var ticket: int = _message_ticket
	get_tree().create_timer(MESSAGE_SECONDS, true, false, true).timeout.connect(_clear_message.bind(ticket))


func _clear_message(ticket: int) -> void:
	if ticket == _message_ticket and is_instance_valid(_message):
		_message.text = ""
