class_name PlayBillingIapProvider
extends IapProvider
## Gerçek Google Play Billing sağlayıcısı (godot-sdk-integrations/godot-google-play-billing 3.3.0, Billing Library 9.1.0'ı sarar;
## 3.3.0, 2026-11-15 itibarıyla Godot 4 hattının GÜNCEL sürümüdür: `BillingClient.gd` imzaları aşağıdaki kullanımla uyumlu).
## - `no_ads` gibi tek seferlik (INAPP) ürünler. Ödeme tamamlanınca (PURCHASED) mutlaka ACKNOWLEDGE edilir (3 gün içinde edilmezse Play iade eder).
## - Açılışta bağlanır, ürün ayrıntılarını (fiyat) ve sahiplikleri sorgular; ödenmemiş/onaysız satın almalar bulunursa onaylanır.
## - Ödül (`purchase_finished(success=true)`) yalnızca PURCHASED durumunda verilir. PENDING: ödül YOK, "pending" hatasıyla bitirilir; Play ödemeyi
##   sonradan tamamlayınca `on_purchase_updated` (ya da bir sonraki açılış sorgusu) PURCHASED getirir ve normal yoldan sahiplik verilir.
## - Play, ürün ayrıntısı sorgulanmadan `purchase` çağrısını DEVELOPER_ERROR ile reddeder: satın alma, ayrıntı yanıtı gelene dek beklemeye alınır.
## - Bağlantı kopar/başarısız olursa üstel beklemeyle yeniden bağlanır; her kullanılabilirlik değişikliği `availability_changed` ile duyurulur
##   (Market ekranı geç bağlanmada kendini yeniler). Sahiplik her açılışta mağazadan okunur (geri yükleme).
## `client` bir BillingClient düğümü ya da aynı sinyal/metotlara sahip sahte nesne olabilir (testler); verilmezse oluşturulur.

const RESPONSE_OK := 0
const RESPONSE_USER_CANCELED := 1
const RESPONSE_ITEM_ALREADY_OWNED := 7
const PURCHASED := 1
const PENDING := 2
const PRODUCT_TYPE_INAPP := 0
const RECONNECT_BASE_SECONDS := 2.0
const RECONNECT_MAX_SECONDS := 60.0

var client: Node
var product_ids: PackedStringArray = []
var connected := false
## Ürün kimliği -> mağazadaki biçimli fiyat ("$2,99"). Yalnızca mağaza yanıt verdiyse dolar.
var prices: Dictionary = {}
## Ürün ayrıntıları bu bağlantıda başarıyla alındı mı (satın alma önkoşulu).
var details_ready := false
## Yeniden bağlanma sayacı ve zamanlayıcı bayrağı (testler `schedule_reconnects=false` ile gerçek zamanlayıcıyı kapatır).
var reconnect_attempts := 0
var schedule_reconnects := true
var reconnect_pending := false

var _connecting := false
var _pending_purchase := ""
## Ayrıntı yanıtı beklenirken sıraya alınmış satın alma.
var _purchase_when_ready := ""
var _wanted_restore := false
var _acknowledging: Array[String] = []
var _owned: PackedStringArray = []
var _known_products: PackedStringArray = []
var _ack_products := {}
var _ack_from_update := {}


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
	_connecting = true
	client.call("start_connection")


func is_available() -> bool:
	return connected and is_instance_valid(client) and bool(client.call("is_ready"))


func get_price_text(product_id: String) -> String:
	return str(prices.get(product_id, ""))


func purchase(product_id: String) -> void:
	if not is_available():
		reconnect()
		purchase_finished.emit.call_deferred(product_id, false, "store_unavailable")
		return
	if not _pending_purchase.is_empty() or not _purchase_when_ready.is_empty():
		purchase_finished.emit.call_deferred(product_id, false, "purchase_in_progress")
		return
	if not details_ready:
		# Ayrıntı yanıtı gelmeden Play satın almayı reddeder: sıraya al, ayrıntıları yeniden iste.
		_purchase_when_ready = product_id
		client.call("query_product_details", product_ids, PRODUCT_TYPE_INAPP)
		return
	_start_purchase(product_id)


func restore_purchases() -> void:
	_wanted_restore = true
	if is_available():
		client.call("query_purchases", PRODUCT_TYPE_INAPP)
	else:
		reconnect()  # bağlanınca (`_on_connected`) sorgulanır ve sahiplikler bildirilir


func reconnect() -> void:
	if connected or _connecting or client == null or not is_instance_valid(client):
		return
	_connecting = true
	client.call("start_connection")


func _start_purchase(product_id: String) -> void:
	if not (product_id in _known_products):
		purchase_finished.emit.call_deferred(product_id, false, "item_unavailable")  # Play Console'da ürün yok/etkin değil
		return
	_pending_purchase = product_id
	var result: Dictionary = client.call("purchase", product_id)
	if int(result.get("response_code", RESPONSE_OK)) != RESPONSE_OK:
		_pending_purchase = ""
		purchase_finished.emit.call_deferred(product_id, false, "billing_error_%d" % int(result.get("response_code", -1)))


# --- Bağlantı ------------------------------------------------------------------------------------

func _on_connected() -> void:
	var was := connected
	connected = true
	_connecting = false
	reconnect_pending = false
	reconnect_attempts = 0
	details_ready = false
	_wanted_restore = true  # açılışta sahiplikler mağazadan okunur (ve onaysız satın almalar onaylanır)
	client.call("query_product_details", product_ids, PRODUCT_TYPE_INAPP)
	client.call("query_purchases", PRODUCT_TYPE_INAPP)
	if not was:
		availability_changed.emit()


func _on_disconnected() -> void:
	var was := connected
	connected = false
	_connecting = false
	details_ready = false
	_fail_waiting_purchase("store_unavailable")
	_schedule_reconnect()
	if was:
		availability_changed.emit()


func _on_connect_error(_code: Variant = null, _message: Variant = null) -> void:
	var was := connected
	connected = false
	_connecting = false
	_fail_waiting_purchase("store_unavailable")
	if _wanted_restore:
		_wanted_restore = false
		restore_failed.emit.call_deferred("store_unavailable")
	_schedule_reconnect()
	if was:
		availability_changed.emit()


func _fail_waiting_purchase(error: String) -> void:
	if not _purchase_when_ready.is_empty():
		var waiting := _purchase_when_ready
		_purchase_when_ready = ""
		purchase_finished.emit.call_deferred(waiting, false, error)
	if not _pending_purchase.is_empty() and error == "store_unavailable":
		var product := _pending_purchase
		_pending_purchase = ""
		purchase_finished.emit.call_deferred(product, false, error)


## Üstel bekleme: 2 sn, 4 sn, ... en çok 60 sn. Gerçek zamanlayıcı yalnızca `schedule_reconnects` açıksa kurulur.
func reconnect_delay(attempt: int) -> float:
	return minf(RECONNECT_MAX_SECONDS, RECONNECT_BASE_SECONDS * pow(2.0, maxf(0.0, attempt - 1.0)))


func _schedule_reconnect() -> void:
	reconnect_attempts += 1
	reconnect_pending = true
	if not schedule_reconnects:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	tree.create_timer(reconnect_delay(reconnect_attempts), true, false, true).timeout.connect(_reconnect_now)


func _reconnect_now() -> void:
	reconnect_pending = false
	reconnect()


# --- Ürün ayrıntıları ----------------------------------------------------------------------------

func _on_product_details(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != RESPONSE_OK:
		_fail_waiting_purchase("store_unavailable")
		return
	_known_products = PackedStringArray()
	for detail: Variant in response.get("product_details", []):
		if not (detail is Dictionary):
			continue
		var product_id := str((detail as Dictionary).get("product_id", ""))
		if product_id.is_empty():
			continue
		_known_products.append(product_id)
		var price := _find_formatted_price(detail)
		if not price.is_empty():
			prices[product_id] = price
	details_ready = true
	availability_changed.emit()  # fiyat geldi: arayüz yenilenir
	if not _purchase_when_ready.is_empty():
		var waiting := _purchase_when_ready
		_purchase_when_ready = ""
		_start_purchase(waiting)


## Fiyat metnini (formatted_price) iç içe sözlükte arar; eklenti sürümleri arasında yerleşim değişebilir
## (3.3.0: `one_time_purchase_offer_details_list[0].formatted_price`).
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
			restore_failed.emit("billing_error_%d" % int(response.get("response_code", -1)))
		return
	_owned = PackedStringArray()
	for purchase_data: Variant in response.get("purchases", []):
		_process_purchase(purchase_data as Dictionary, false)
	if _wanted_restore:
		_wanted_restore = false
		purchases_restored.emit(_owned.duplicate())


## Bir satın almayı işler: PURCHASED ise sahiplik sayılır, onaysızsa onaylanır; PENDING ödül vermez (kullanıcıya "beklemede" denir).
func _process_purchase(data: Dictionary, from_update: bool) -> void:
	var state := int(data.get("purchase_state", 0))
	if state != PURCHASED:
		if state == PENDING and from_update:
			var waiting := _pending_purchase
			_pending_purchase = ""
			var ids_pending: PackedStringArray = data.get("product_ids", PackedStringArray())
			var product := waiting if not waiting.is_empty() else (ids_pending[0] if not ids_pending.is_empty() else "")
			purchase_finished.emit(product, false, "pending")
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
	# Onay başarısız: bir sonraki sorguda (açılış/geri yükleme) yeniden denenir; Play 3 gün içinde onaylanmazsa iade eder.
	if from_update:
		_pending_purchase = ""
		purchase_finished.emit(ids[0] if not ids.is_empty() else "", false, "acknowledge_failed")


func _complete_purchase(ids: PackedStringArray) -> void:
	_pending_purchase = ""
	for product_id in ids:
		purchase_finished.emit(product_id, true, "")
