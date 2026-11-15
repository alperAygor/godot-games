extends TestCase

## PlayBillingProvider — resmi eklenti v3.x `BillingClient` API'sine karşı, SAHTE istemciyle.
## Sahte istemci eklentinin belgelenmiş sinyallerini/sözlüklerini taklit eder (alan adlarının kaynağı:
## play_billing_provider.gd başlık yorumu). Cihazda gerçek eklentiyle denenmesi hâlâ gerekir.


class FakeBillingClient extends RefCounted:
	signal connected
	signal disconnected
	signal connect_error(response_code: int, debug_message: String)
	signal query_product_details_response(response: Dictionary)
	signal query_purchases_response(response: Dictionary)
	signal on_purchase_updated(response: Dictionary)
	signal acknowledge_purchase_response(response: Dictionary)

	var ready: bool = false
	var calls: Array[String] = []
	var acknowledged_tokens: Array[String] = []
	var purchase_result: Dictionary = {"response_code": 0, "debug_message": ""}

	func is_ready() -> bool:
		return ready

	func start_connection() -> void:
		calls.append("start_connection")

	func query_product_details(products: PackedStringArray, product_type: int) -> void:
		calls.append("query_product_details:%s:%d" % [",".join(products), product_type])

	func query_purchases(product_type: int) -> void:
		calls.append("query_purchases:%d" % product_type)

	func purchase(product_id: String) -> Dictionary:
		calls.append("purchase:" + product_id)
		return purchase_result

	func acknowledge_purchase(token: String) -> void:
		calls.append("acknowledge:" + token)
		acknowledged_tokens.append(token)


var _client: FakeBillingClient = null
var _provider: PlayBillingProvider = null
var _succeeded: Array[String] = []
var _failed: Array[String] = []
var _restored: Array = []


func before_each() -> void:
	_client = FakeBillingClient.new()
	_provider = PlayBillingProvider.new(_client)
	_succeeded.clear()
	_failed.clear()
	_restored.clear()
	_provider.purchase_succeeded.connect(func(id: String) -> void: _succeeded.append(id))
	_provider.purchase_failed.connect(func(id: String, reason: String) -> void: _failed.append("%s:%s" % [id, reason]))
	_provider.restore_finished.connect(func(ids: PackedStringArray, ok: bool) -> void: _restored.append([ids, ok]))


func _details(price: String = "₺149,99") -> Dictionary:
	return {"response_code": 0, "debug_message": "", "unfetched_products": [], "product_details": [
		{"product_id": "remove_ads", "title": "x", "name": "x", "description": "", "product_type": "inapp",
			"one_time_purchase_offer_details_list": [{"formatted_price": price, "purchase_option_id": "legacy-base"}],
			"subscription_offer_details": null}]}


func _purchase(state: int = 1, acked: bool = false, token: String = "tok1") -> Dictionary:
	return {"order_id": "GPA.1", "purchase_token": token, "package_name": "com.clotheslinesort.game",
		"purchase_state": state, "is_acknowledged": acked, "is_auto_renewing": false, "quantity": 1,
		"product_ids": PackedStringArray(["remove_ads"])}


func _connect_and_load() -> void:
	_provider.initialize()
	_client.connected.emit()
	_client.query_product_details_response.emit(_details())


func test_connect_then_query_details_and_purchases() -> void:
	_provider.initialize()
	assert_eq(_client.calls, ["start_connection"] as Array[String])
	assert_true(_provider.is_available())
	_client.connected.emit()
	assert_true(_client.calls.has("query_product_details:remove_ads:0"), "INAPP = 0")
	assert_true(_client.calls.has("query_purchases:0"), "açılışta sahiplik sorgusu")


func test_price_text_from_one_time_offer() -> void:
	_connect_and_load()
	assert_eq(_provider.price_text("remove_ads"), "₺149,99")
	assert_eq(PlayBillingProvider.parse_price({}), "")
	assert_eq(PlayBillingProvider.parse_price({"one_time_purchase_offer_details_list": null}), "")


func test_purchase_flow_grants_and_acknowledges_once() -> void:
	_connect_and_load()
	_provider.purchase("remove_ads")
	assert_true(_client.calls.has("purchase:remove_ads"))
	_client.on_purchase_updated.emit({"response_code": 0, "debug_message": "", "purchases": [_purchase()]})
	assert_eq(_succeeded, ["remove_ads"] as Array[String])
	assert_eq(_client.acknowledged_tokens, ["tok1"] as Array[String])
	# Aynı satın alma tekrar bildirilirse (onay yanıtı gelmeden) ikinci onay çağrısı yapılmaz.
	_client.on_purchase_updated.emit({"response_code": 0, "debug_message": "", "purchases": [_purchase()]})
	assert_eq(_client.acknowledged_tokens.size(), 1)
	_client.acknowledge_purchase_response.emit({"response_code": 0, "debug_message": "", "token": "tok1"})
	_client.query_purchases_response.emit({"response_code": 0, "debug_message": "", "purchases": [_purchase()]})
	assert_eq(_client.acknowledged_tokens.size(), 1, "onaylanmış jeton yeniden onaylanmaz")


func test_already_acknowledged_purchase_is_not_acknowledged() -> void:
	_connect_and_load()
	_client.query_purchases_response.emit({"response_code": 0, "purchases": [_purchase(1, true)]})
	assert_true(_client.acknowledged_tokens.is_empty())
	assert_eq((_restored[0] as Array)[0], PackedStringArray(["remove_ads"]))


func test_failed_acknowledge_is_retried_on_next_query() -> void:
	_connect_and_load()
	_client.query_purchases_response.emit({"response_code": 0, "purchases": [_purchase()]})
	_client.acknowledge_purchase_response.emit({"response_code": 6, "debug_message": "err", "token": "tok1"})
	_client.query_purchases_response.emit({"response_code": 0, "purchases": [_purchase()]})
	assert_eq(_client.acknowledged_tokens.size(), 2, "başarısız onay bir sonraki sorguda yeniden denenir")


func test_pending_purchase_grants_nothing() -> void:
	_connect_and_load()
	_provider.purchase("remove_ads")
	_client.on_purchase_updated.emit({"response_code": 0, "purchases": [_purchase(PlayBillingProvider.PURCHASE_STATE_PENDING)]})
	assert_true(_succeeded.is_empty(), "PENDING sahiplik vermez")
	assert_eq(_failed, ["remove_ads:pending"] as Array[String])
	assert_true(_client.acknowledged_tokens.is_empty(), "PENDING onaylanmaz")
	assert_true(PlayBillingProvider.owned_ids([_purchase(2)]).is_empty())
	assert_true(PlayBillingProvider.owned_ids([{"product_ids": ["remove_ads"]}]).is_empty(), "durum alanı yoksa sahiplik yok")


func test_refund_means_empty_ok_restore() -> void:
	_connect_and_load()
	_client.query_purchases_response.emit({"response_code": 0, "debug_message": "", "purchases": []})
	assert_eq(_restored.size(), 1)
	assert_true(_provider.is_authoritative())
	assert_eq((_restored[0] as Array)[0], PackedStringArray())
	assert_true((_restored[0] as Array)[1], "sorgu başarılı: IapService sahipliği silebilir")


func test_failed_query_is_not_a_refund() -> void:
	_connect_and_load()
	_client.query_purchases_response.emit({"response_code": 2, "debug_message": "unavailable"})
	assert_false((_restored[0] as Array)[1], "ok=false: yerel kayıt silinmez")


func test_user_cancel_is_silent_reason() -> void:
	_connect_and_load()
	_provider.purchase("remove_ads")
	_client.on_purchase_updated.emit({"response_code": 1, "debug_message": "canceled"})
	assert_eq(_failed, ["remove_ads:canceled"] as Array[String])
	assert_true(_succeeded.is_empty())


func test_error_code_mapping() -> void:
	assert_eq(PlayBillingProvider.reason_for_code(1), IapProvider.REASON_CANCELED)
	for code: int in [2, 3, 12, -1, -3]:
		assert_eq(PlayBillingProvider.reason_for_code(code), IapProvider.REASON_NOT_CONNECTED)
	assert_eq(PlayBillingProvider.reason_for_code(5), IapProvider.REASON_ERROR)
	assert_eq(PlayBillingProvider.reason_for_code(4), IapProvider.REASON_ERROR)


func test_launch_failure_is_reported() -> void:
	_connect_and_load()
	_client.purchase_result = {"response_code": 5, "debug_message": "dev"}
	_provider.purchase("remove_ads")
	assert_eq(_failed, ["remove_ads:error"] as Array[String])


func test_already_owned_triggers_restore_query() -> void:
	_connect_and_load()
	_client.calls.clear()
	_client.purchase_result = {"response_code": 7, "debug_message": "owned"}
	_provider.purchase("remove_ads")
	assert_true(_failed.is_empty())
	assert_true(_client.calls.has("query_purchases:0"))


func test_purchase_waits_for_connection_and_details() -> void:
	_provider.initialize()
	_provider.purchase("remove_ads")
	assert_false(_client.calls.has("purchase:remove_ads"), "bağlanmadan satın alma başlamaz")
	_client.connected.emit()
	assert_false(_client.calls.has("purchase:remove_ads"), "ürün ayrıntısı gelmeden başlamaz (Kotlin DEVELOPER_ERROR verir)")
	_client.query_product_details_response.emit(_details())
	assert_true(_client.calls.has("purchase:remove_ads"))


func test_connection_error_drops_waiting_purchase() -> void:
	_provider.initialize()
	_provider.purchase("remove_ads")
	_client.connect_error.emit(3, "billing unavailable")
	assert_eq(_failed, ["remove_ads:not_connected"] as Array[String])
	_provider.restore()
	_client.connect_error.emit(2, "x")
	assert_eq((_restored[0] as Array)[1], false, "bağlantı hatasında geri yükleme başarısız (ok=false)")


func test_disconnect_drops_waiting_purchase_and_reconnects_on_demand() -> void:
	_connect_and_load()
	_client.disconnected.emit()
	_provider.purchase("remove_ads")
	assert_eq(_client.calls.count("start_connection"), 2, "kopunca yeniden bağlanılır")


func test_already_ready_client_skips_start_connection() -> void:
	_client.ready = true
	_provider.initialize()
	assert_false(_client.calls.has("start_connection"))
	assert_true(_client.calls.has("query_purchases:0"))


func test_restore_waits_for_connection() -> void:
	_provider.initialize()
	_provider.restore()
	assert_true(_restored.is_empty())
	_client.connected.emit()
	_client.query_purchases_response.emit({"response_code": 0, "purchases": [_purchase(1, true)]})
	assert_eq(_restored.size(), 1)


func test_failed_details_query_fails_waiting_purchase() -> void:
	_provider.initialize()
	_client.connected.emit()
	_provider.purchase("remove_ads")
	_client.query_product_details_response.emit({"response_code": 3, "debug_message": "x"})
	assert_eq(_failed, ["remove_ads:not_connected"] as Array[String])


func test_without_plugin_everything_is_a_safe_noop() -> void:
	assert_false(PlayBillingProvider.plugin_present(), "masaüstünde eklenti yok")
	var bare: PlayBillingProvider = PlayBillingProvider.new()
	bare.initialize()
	assert_false(bare.is_available())
	var failed: Array[String] = []
	bare.purchase_failed.connect(func(_id: String, reason: String) -> void: failed.append(reason))
	bare.purchase("remove_ads")
	assert_eq(failed, [IapProvider.REASON_UNAVAILABLE] as Array[String])
	var restored: Array[bool] = []
	bare.restore_finished.connect(func(_ids: PackedStringArray, ok: bool) -> void: restored.append(ok))
	bare.restore()
	assert_eq(restored, [false] as Array[bool])
	assert_eq(bare.price_text("remove_ads"), "")


func test_purchase_ids_helpers() -> void:
	assert_eq(PlayBillingProvider.purchase_product_ids({"product_ids": ["a", "b"]}), PackedStringArray(["a", "b"]))
	assert_eq(PlayBillingProvider.tokens_to_acknowledge([_purchase(1, false, "a"), _purchase(1, true, "b"),
		_purchase(2, false, "c"), _purchase(1, false, "a")]), PackedStringArray(["a"]))
