class_name PlayBillingProvider
extends IapProvider

## Google Play Faturalandırma — Godot'nun resmi Android eklentisi "GodotGooglePlayBilling"
## (godot-google-play-billing, Godot 4 sürümü) tekil nesnesine karşı yazıldı.
## Yalnız `Engine.has_singleton("GodotGooglePlayBilling")` ise etkinleşir; eklenti yokken
## proje değişmeden çalışır (bkz. IapService seçimi). Kurulum adımları: docs/MONETIZATION.md.
##
## Akış: startConnection -> connected -> queryProductDetails (fiyat) + queryPurchases (sahiplik)
## purchase(id) -> purchases_updated -> acknowledgePurchase (3 gün içinde onaylanmazsa Google iade eder!)

const SINGLETON_NAME: String = "GodotGooglePlayBilling"
const PRODUCT_TYPE_INAPP: String = "inapp"
## Eklentinin sabitleri: yanıt kodu 0 = OK, 1 = kullanıcı iptal etti; satın alma durumu 1 = satın alındı.
const RESPONSE_OK: int = 0
const RESPONSE_USER_CANCELED: int = 1
const PURCHASE_STATE_PURCHASED: int = 1

var _billing: Object = null
var _connected: bool = false
var _connecting: bool = false
var _prices: Dictionary = {}
var _restore_when_connected: bool = false
var _purchase_when_connected: String = ""


static func plugin_present() -> bool:
	return Engine.has_singleton(SINGLETON_NAME)


func initialize() -> void:
	if not plugin_present():
		return
	_billing = Engine.get_singleton(SINGLETON_NAME)
	_bind("connected", _on_connected)
	_bind("disconnected", _on_disconnected)
	_bind("connect_error", _on_connect_error)
	_bind("product_details_query_completed", _on_product_details)
	_bind("product_details_query_error", _on_product_details_error)
	_bind("purchases_updated", _on_purchases_updated)
	_bind("purchase_error", _on_purchase_error)
	_bind("query_purchases_response", _on_query_purchases)
	_bind("purchase_acknowledged", _on_acknowledged)
	_connect_store()


func is_available() -> bool:
	return _billing != null


func is_authoritative() -> bool:
	return true


func price_text(product_id: String) -> String:
	return String(_prices.get(product_id, ""))


func purchase(product_id: String) -> void:
	if _billing == null:
		purchase_failed.emit(product_id, REASON_UNAVAILABLE)
		return
	if not _connected:
		# Bağlantı yoksa kurulur ve bağlanınca satın alma başlar; oyuncu "bağlanıyor" bekler.
		_purchase_when_connected = product_id
		_connect_store()
		return
	_start_purchase(product_id)


func restore() -> void:
	if _billing == null:
		restore_finished.emit(PackedStringArray(), false)
		return
	if not _connected:
		_restore_when_connected = true
		_connect_store()
		return
	_billing.call("queryPurchases", PRODUCT_TYPE_INAPP)


# --- Saf ayrıştırıcılar (cihaz olmadan test edilir) --------------------------------------

## Eklenti sürümüne göre fiyat alanı değişir: 2.x `one_time_purchase_offer_details.formatted_price`,
## eski sürümler `price`.
static func parse_price(details: Dictionary) -> String:
	var offer: Variant = details.get("one_time_purchase_offer_details")
	if offer is Dictionary and not String((offer as Dictionary).get("formatted_price", "")).is_empty():
		return String((offer as Dictionary)["formatted_price"])
	return String(details.get("price", ""))


## Bir satın alma kaydının ürün kimlikleri (`product_ids` dizisi; eski sürümde `sku`).
static func purchase_product_ids(purchase_info: Dictionary) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	var raw: Variant = purchase_info.get("product_ids", purchase_info.get("skus"))
	if raw is Array or raw is PackedStringArray:
		for entry: Variant in raw:
			ids.append(String(entry))
	elif purchase_info.has("sku"):
		ids.append(String(purchase_info["sku"]))
	return ids


## Yalnız "satın alındı" durumundakiler sahiplik sayılır (beklemede olan ödeme henüz değildir).
static func owned_ids(purchases: Array) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for entry: Variant in purchases:
		if not (entry is Dictionary):
			continue
		var info: Dictionary = entry as Dictionary
		if int(info.get("purchase_state", PURCHASE_STATE_PURCHASED)) != PURCHASE_STATE_PURCHASED:
			continue
		for id: String in purchase_product_ids(info):
			if not result.has(id):
				result.append(id)
	return result


# --- Eklenti geri çağrıları ---------------------------------------------------------------

func _bind(signal_name: String, handler: Callable) -> void:
	if _billing.has_signal(signal_name):
		_billing.connect(signal_name, handler)


func _connect_store() -> void:
	if _billing == null or _connecting:
		return
	_connecting = true
	_billing.call("startConnection")


func _on_connected() -> void:
	_connecting = false
	_connected = true
	_billing.call("queryProductDetails", PackedStringArray(PRODUCT_IDS), PRODUCT_TYPE_INAPP)
	# Açılışta sahiplik yeniden doğrulanır (cihaz değişimi, iade).
	_billing.call("queryPurchases", PRODUCT_TYPE_INAPP)
	if not _purchase_when_connected.is_empty():
		var pending: String = _purchase_when_connected
		_purchase_when_connected = ""
		_start_purchase(pending)
	_restore_when_connected = false


func _on_disconnected() -> void:
	_connecting = false
	_connected = false


func _on_connect_error(_code: int, _message: String) -> void:
	_connecting = false
	_connected = false
	if not _purchase_when_connected.is_empty():
		purchase_failed.emit(_purchase_when_connected, REASON_NOT_CONNECTED)
		_purchase_when_connected = ""
	if _restore_when_connected:
		_restore_when_connected = false
		restore_finished.emit(PackedStringArray(), false)


func _on_product_details(details: Array) -> void:
	for entry: Variant in details:
		if entry is Dictionary:
			var info: Dictionary = entry as Dictionary
			_prices[String(info.get("product_id", ""))] = parse_price(info)
	prices_changed.emit()


func _on_product_details_error(_code: int, _message: String, _queried: Array) -> void:
	prices_changed.emit()


func _start_purchase(product_id: String) -> void:
	var result: Variant = _billing.call("purchase", product_id)
	# Eklentinin bazı sürümleri başlatma sonucunu sözlük olarak döndürür (status != 0 = açılamadı).
	if result is Dictionary and int((result as Dictionary).get("status", RESPONSE_OK)) != RESPONSE_OK:
		purchase_failed.emit(product_id, REASON_ERROR)


func _on_purchases_updated(purchases: Array) -> void:
	for entry: Variant in purchases:
		if not (entry is Dictionary):
			continue
		var info: Dictionary = entry as Dictionary
		if int(info.get("purchase_state", PURCHASE_STATE_PURCHASED)) != PURCHASE_STATE_PURCHASED:
			continue
		_acknowledge(info)
		for id: String in purchase_product_ids(info):
			purchase_succeeded.emit(id)


func _on_purchase_error(code: int, _message: String) -> void:
	purchase_failed.emit(PRODUCT_REMOVE_ADS,
		REASON_CANCELED if code == RESPONSE_USER_CANCELED else REASON_ERROR)


func _on_query_purchases(result: Dictionary) -> void:
	if int(result.get("status", RESPONSE_OK)) != RESPONSE_OK:
		restore_finished.emit(PackedStringArray(), false)
		return
	var purchases: Array = result.get("purchases", []) as Array
	for entry: Variant in purchases:
		if entry is Dictionary:
			_acknowledge(entry as Dictionary)
	restore_finished.emit(owned_ids(purchases), true)


## Onaylanmamış satın almayı onaylar (tüketilmez: ürün kalıcıdır).
func _acknowledge(info: Dictionary) -> void:
	if bool(info.get("is_acknowledged", false)):
		return
	var token: String = String(info.get("purchase_token", ""))
	if not token.is_empty() and _billing != null:
		_billing.call("acknowledgePurchase", token)


func _on_acknowledged(_token: String) -> void:
	pass
