class_name PlayBillingIapProvider
extends IapProvider
## Gerçek Google Play Billing sağlayıcısı (godot-sdk-integrations/godot-google-play-billing 3.3.0, Billing Library 9.1.0'ı sarar).
## - `no_ads` gibi tek seferlik (INAPP) ürünler. Ödeme tamamlanınca (PURCHASED) mutlaka ACKNOWLEDGE edilir (3 gün içinde edilmezse Play iade eder).
## - Açılışta bağlanır, ürün ayrıntılarını (fiyat) ve sahiplikleri sorgular; ödenmemiş/onaysız satın almalar bulunursa onaylanır.
## - Ödül (`purchase_finished(success=true)`) yalnızca PURCHASED durumunda verilir; PENDING beklenir; iptal/hata başarısızdır.
## `client` bir BillingClient düğümü ya da aynı sinyal/metotlara sahip sahte nesne olabilir (testler); verilmezse oluşturulur.

const RESPONSE_OK := 0
const RESPONSE_USER_CANCELED := 1
const RESPONSE_ITEM_ALREADY_OWNED := 7
const PURCHASED := 1
const PENDING := 2
const PRODUCT_TYPE_INAPP := 0

var client: Node
var product_ids: PackedStringArray = []
var connected := false
## Ürün kimliği -> mağazadaki biçimli fiyat ("$2,99"). Yalnızca mağaza yanıt verdiyse dolar.
var prices: Dictionary = {}

var _pending_purchase := ""
var _wanted_restore := false
var _acknowledging: Array[String] = []
var _owned: PackedStringArray = []


func _init(existing_client: Node = null) -> void:
	client = existing_client


func initialize(ids: PackedStringArray) -> void:
	product_ids = ids
	if client == null:
		client = BillingClient.new()
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			tree.root.add_child.call_deferred(client)
	client.connect("connected", _on_connected)
	client.connect("disconnected", _on_disconnected)
	client.connect("connect_error", _on_connect_error)
	client.connect("query_product_details_response", _on_product_details)
	client.connect("query_purchases_response", _on_purchases_queried)
	client.connect("on_purchase_updated", _on_purchase_updated)
	client.connect("acknowledge_purchase_response", _on_acknowledged)
	client.call("start_connection")


func is_available() -> bool:
	return connected and bool(client.call("is_ready"))


func get_price_text(product_id: String) -> String:
	return str(prices.get(product_id, ""))


func purchase(product_id: String) -> void:
	if not is_available():
		purchase_finished.emit.call_deferred(product_id, false, "store_unavailable")
		return
	if not _pending_purchase.is_empty():
		purchase_finished.emit.call_deferred(product_id, false, "purchase_in_progress")
		return
	_pending_purchase = product_id
	var result: Dictionary = client.call("purchase", product_id)
	if int(result.get("response_code", RESPONSE_OK)) != RESPONSE_OK:
		_pending_purchase = ""
		purchase_finished.emit.call_deferred(product_id, false, "billing_error_%d" % int(result.get("response_code", -1)))


func restore_purchases() -> void:
	_wanted_restore = true
	if is_available():
		client.call("query_purchases", PRODUCT_TYPE_INAPP)
	# Bağlı değilse bağlanınca (`_on_connected`) sorgulanır ve sahiplikler bildirilir.


# --- Bağlantı ------------------------------------------------------------------------------------

func _on_connected() -> void:
	connected = true
	_wanted_restore = true  # açılışta sahiplikler mağazadan okunur (ve onaysız satın almalar onaylanır)
	client.call("query_product_details", product_ids, PRODUCT_TYPE_INAPP)
	client.call("query_purchases", PRODUCT_TYPE_INAPP)


func _on_disconnected() -> void:
	connected = false


func _on_connect_error(_code: Variant = null, _message: Variant = null) -> void:
	connected = false


# --- Ürün ayrıntıları ----------------------------------------------------------------------------

func _on_product_details(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != RESPONSE_OK:
		return
	for detail: Variant in response.get("product_details", []):
		if not (detail is Dictionary):
			continue
		var product_id := str((detail as Dictionary).get("product_id", ""))
		var price := _find_formatted_price(detail)
		if not product_id.is_empty() and not price.is_empty():
			prices[product_id] = price


## Fiyat metnini (formatted_price) iç içe sözlükte arar; eklenti sürümleri arasında yerleşim değişebilir.
func _find_formatted_price(node: Variant) -> String:
	if node is Dictionary:
		var dict := node as Dictionary
		if dict.has("formatted_price"):
			return str(dict["formatted_price"])
		for value: Variant in dict.values():
			var found := _find_formatted_price(value)
			if not found.is_empty():
				return found
	elif node is Array:
		for value: Variant in node:
			var found := _find_formatted_price(value)
			if not found.is_empty():
				return found
	return ""


# --- Satın alma ------------------------------------------------------------------------------------

func _on_purchase_updated(response: Dictionary) -> void:
	var code := int(response.get("response_code", -1))
	if code != RESPONSE_OK:
		var product := _pending_purchase
		_pending_purchase = ""
		if code == RESPONSE_ITEM_ALREADY_OWNED:
			# Zaten sahip: sahipliği yeniden sorgula; başarı olarak bildir.
			if not product.is_empty():
				client.call("query_purchases", PRODUCT_TYPE_INAPP)
				purchase_finished.emit(product, true, "")
			return
		var error := "user_cancelled" if code == RESPONSE_USER_CANCELED else "billing_error_%d" % code
		purchase_finished.emit(product if not product.is_empty() else "", false, error)
		return
	for purchase_data: Variant in response.get("purchases", []):
		_process_purchase(purchase_data as Dictionary, true)


func _on_purchases_queried(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != RESPONSE_OK:
		if _wanted_restore:
			_wanted_restore = false
			purchases_restored.emit(PackedStringArray())
		return
	_owned = PackedStringArray()
	for purchase_data: Variant in response.get("purchases", []):
		_process_purchase(purchase_data as Dictionary, false)
	if _wanted_restore:
		_wanted_restore = false
		purchases_restored.emit(_owned.duplicate())


## Bir satın almayı işler: PURCHASED ise sahiplik sayılır, onaysızsa onaylanır; PENDING beklenir.
func _process_purchase(data: Dictionary, from_update: bool) -> void:
	if int(data.get("purchase_state", 0)) != PURCHASED:
		return  # PENDING ya da bilinmeyen: ödül verilmez
	var ids: PackedStringArray = data.get("product_ids", PackedStringArray())
	for product_id in ids:
		if not (product_id in _owned):
			_owned.append(product_id)
	if bool(data.get("is_acknowledged", false)):
		if from_update:
			_complete_purchase(ids)
		return
	var token := str(data.get("purchase_token", ""))
	if token.is_empty() or token in _acknowledging:
		return
	_acknowledging.append(token)
	_ack_products[token] = ids
	_ack_from_update[token] = from_update
	client.call("acknowledge_purchase", token)


var _ack_products := {}
var _ack_from_update := {}


func _on_acknowledged(response: Dictionary) -> void:
	var token := str(response.get("token", ""))
	_acknowledging.erase(token)
	var ids: PackedStringArray = _ack_products.get(token, PackedStringArray())
	var from_update: bool = _ack_from_update.get(token, false)
	_ack_products.erase(token)
	_ack_from_update.erase(token)
	if int(response.get("response_code", -1)) == RESPONSE_OK:
		if from_update:
			_complete_purchase(ids)
		return
	if from_update:
		_pending_purchase = ""
		purchase_finished.emit(ids[0] if not ids.is_empty() else "", false, "acknowledge_failed")


func _complete_purchase(ids: PackedStringArray) -> void:
	_pending_purchase = ""
	for product_id in ids:
		purchase_finished.emit(product_id, true, "")
