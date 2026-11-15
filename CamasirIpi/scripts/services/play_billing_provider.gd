class_name PlayBillingProvider
extends IapProvider

## Google Play Faturalandırma — resmi eklenti "godot-google-play-billing" v3.x (PBL 9.1.0, Godot >= 4.2).
## Eklenti GDScript sınıfı `BillingClient` (Node) sunar; o da native tekil nesne `GodotGooglePlayBilling`
## ile konuşur. Eklenti KURULU DEĞİLKEN bu dosya yine derlenir (sınıf adla DEĞİL, global sınıf listesinden
## dinamik bulunur); `plugin_present()` false döner ve IapService mock'a/boş mağazaya düşer. Kurulum: docs/store/PENDING_APPROVALS.md.
##
## KAYNAKLAR: GERÇEK eklenti 3.3.0 (2026-11-15 kuruldu, SHA-256 20d75623...8568) — `addons/GodotGooglePlayBilling/`.
## "BillingClient.gd:N" = o dizindeki gerçek dosyanın satırı; sözlük alan adları ise AAR'daki derlenmiş
## `Utils.class` / `GodotGooglePlayBilling.class` sabit dizgelerinden doğrulandı (kaynak .kt dosyası pakette yoktur).
##  * sınıf               `class_name BillingClient extends Node`, yol res://addons/GodotGooglePlayBilling/BillingClient.gd (zip'te export_scripts/ YOK);
##                        `_init()` native tekil nesneyi (`Engine.get_singleton("GodotGooglePlayBilling")`) bulur, `initPlugin()` çağırır, sinyalleri aktarır
##  * sinyaller           BillingClient.gd:3-10  (connected, disconnected, connect_error(code,msg), query_product_details_response(dict),
##                        query_purchases_response(dict), on_purchase_updated(dict), consume_purchase_response, acknowledge_purchase_response(dict))
##  * enum'lar            BillingClient.gd:13 BillingResponseCode, :36 ProductType {INAPP=0,SUBS=1}, :41 PurchaseState {UNSPECIFIED_STATE=0,PURCHASED=1,PENDING=2}
##  * yöntemler           BillingClient.gd:88-143: start_connection, is_ready, query_product_details(PackedStringArray, ProductType),
##                        query_purchases(ProductType, include_suspended_subs=false), purchase(product_id, purchase_option_id="", offer_id="", is_offer_personalized=false) -> Dictionary,
##                        acknowledge_purchase(token) (dönüş yok; sonuç acknowledge_purchase_response)
##  * yanıt sözlükleri    AAR dizgeleri: {response_code, debug_message}; ürün: {product_id, product_type, one_time_purchase_offer_details_list[{formatted_price,
##                        price_amount_micros, price_currency_code, purchase_option_id, offer_id, offer_token...}]}; satın alma: {order_id, purchase_token,
##                        package_name, purchase_state, purchase_time, original_json, is_acknowledged, is_auto_renewing, is_suspended, product_ids...};
##                        yanıta `product_details`/`unfetched_products` (ürün sorgusu), `purchases` (sorgu/güncelleme), ack yanıtına `token` eklenir.
##  * satın alma önkoşulu GitHub kaynağı (GodotGooglePlayBilling.kt:163-166): ürün ayrıntısı ÖNCE sorgulanmamışsa purchase DEVELOPER_ERROR döner
##    -> bu sağlayıcı ayrıntı yanıtı gelmeden satın almayı başlatmaz (bekletir). (AAR'da bu dizge görülmez; davranış cihazda doğrulanacak.)
##  * onaylama            docs/api/methods.md "acknowledge_purchase": her satın alma onaylanmalı, yoksa Google iade eder (3 gün).
## Pakete girme: export_filter=all_resources + exclude_filter'da addons/GodotGooglePlayBilling yok -> BillingClient.gd pck'ya girer (build kanıtı: docs/store/RELEASE_STATUS.md).
## HÂLÂ CİHAZDA DOĞRULANACAK: `purchase_option_id` boş bırakmanın tek-seçenekli tek-seferlik üründe çalıştığı; acknowledge zamanlaması;
## ürün ayrıntısı önkoşulunun davranışı; gerçek `purchase_state` tamsayı değerleri (enum ile aynı olduğu varsayılır).
##
## Akış: start_connection -> connected -> query_product_details(["remove_ads"], INAPP) + query_purchases(INAPP)
## purchase("remove_ads") -> on_purchase_updated -> (PURCHASED) acknowledge_purchase -> purchase_succeeded
## Açılışta/yeniden kurulumda geri yükleme = query_purchases (sahiplik buradan gelir).

const SINGLETON_NAME: String = "GodotGooglePlayBilling"
const CLIENT_CLASS: StringName = &"BillingClient"
const ANDROID_OS_NAME: String = "Android"
## BillingClient.ProductType.INAPP (BillingClient.gd:37-40).
const PRODUCT_TYPE_INAPP: int = 0
## BillingClient.BillingResponseCode (BillingClient.gd:13-27) — yalnız kullanılanlar.
const RESPONSE_OK: int = 0
const RESPONSE_USER_CANCELED: int = 1
const RESPONSE_SERVICE_UNAVAILABLE: int = 2
const RESPONSE_BILLING_UNAVAILABLE: int = 3
const RESPONSE_ITEM_UNAVAILABLE: int = 4
const RESPONSE_ITEM_ALREADY_OWNED: int = 7
const RESPONSE_NETWORK_ERROR: int = 12
const RESPONSE_SERVICE_DISCONNECTED: int = -1
const RESPONSE_SERVICE_TIMEOUT: int = -3
## Alan eksikse varsayılan: BillingResponseCode.ERROR (BillingClient.gd:20).
const RESPONSE_ERROR_FALLBACK: int = 6
## Bağlantı sorunu sayılan kodlar (oyuncuya "bağlanılamadı" denir, tekrar denenir).
const CONNECTION_CODES: Array[int] = [RESPONSE_SERVICE_UNAVAILABLE, RESPONSE_BILLING_UNAVAILABLE,
	RESPONSE_NETWORK_ERROR, RESPONSE_SERVICE_DISCONNECTED, RESPONSE_SERVICE_TIMEOUT]
## BillingClient.PurchaseState (BillingClient.gd:42-46).
const PURCHASE_STATE_PURCHASED: int = 1
const PURCHASE_STATE_PENDING: int = 2

var _client: Object = null
var _connected: bool = false
var _connecting: bool = false
var _details_ready: bool = false
var _prices: Dictionary = {}
var _restore_when_connected: bool = false
var _purchase_when_ready: String = ""
## Şu an onay (acknowledge) yanıtı beklenen jetonlar: aynı jeton için ikinci çağrı yapılmaz.
var _ack_inflight: Dictionary = {}
var _acknowledged: Dictionary = {}
## Beklemedeki (PENDING) ödeme görüldü mü (teşhis; sahiplik vermez).
var pending_seen: bool = false


## `client` yalnız testler içindir (sahte BillingClient); üretimde null: eklenti sınıfı bulunur.
func _init(client: Object = null) -> void:
	_client = client


## Gerçek cihazda eklenti kurulu mu: Android + native tekil nesne + BillingClient sınıfı.
static func plugin_present() -> bool:
	return OS.get_name() == ANDROID_OS_NAME and Engine.has_singleton(SINGLETON_NAME) \
		and _client_script() != null


static func _client_script() -> GDScript:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if StringName(String(entry.get("class", ""))) == CLIENT_CLASS:
			return load(String(entry.get("path", ""))) as GDScript
	return null


func initialize() -> void:
	if _client == null:
		var script: GDScript = _client_script()
		if script == null or OS.get_name() != ANDROID_OS_NAME:
			return
		_client = script.new() as Object
	if _client == null:
		return
	_bind("connected", _on_connected)
	_bind("disconnected", _on_disconnected)
	_bind("connect_error", _on_connect_error)
	_bind("query_product_details_response", _on_product_details_response)
	_bind("query_purchases_response", _on_query_purchases_response)
	_bind("on_purchase_updated", _on_purchase_updated)
	_bind("acknowledge_purchase_response", _on_acknowledge_response)
	_connect_store()


func is_available() -> bool:
	return _client != null


func is_authoritative() -> bool:
	return true


func price_text(product_id: String) -> String:
	return String(_prices.get(product_id, ""))


func purchase(product_id: String) -> void:
	if _client == null:
		purchase_failed.emit(product_id, REASON_UNAVAILABLE)
		return
	if not _connected or not _details_ready:
		# Bağlantı/ayrıntı hazır değilse sıraya alınır (Kotlin tarafı ayrıntısız satın almayı reddeder).
		_purchase_when_ready = product_id
		if not _connected:
			_connect_store()
		return
	_start_purchase(product_id)


func restore() -> void:
	if _client == null:
		restore_finished.emit(PackedStringArray(), false)
		return
	if not _connected:
		_restore_when_connected = true
		_connect_store()
		return
	_client.call("query_purchases", PRODUCT_TYPE_INAPP)


# --- Saf ayrıştırıcılar (cihaz olmadan test edilir) --------------------------------------

## Fiyat metni: `one_time_purchase_offer_details_list[0].formatted_price` (Utils.kt:71-77,100); boşsa "".
static func parse_price(details: Dictionary) -> String:
	var offers: Variant = details.get("one_time_purchase_offer_details_list")
	if offers is Array and not (offers as Array).is_empty() and (offers as Array)[0] is Dictionary:
		return String(((offers as Array)[0] as Dictionary).get("formatted_price", ""))
	return ""


## Bir satın alma kaydının ürün kimlikleri (`product_ids`, Utils.kt:33).
static func purchase_product_ids(purchase_info: Dictionary) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	var raw: Variant = purchase_info.get("product_ids")
	if raw is Array or raw is PackedStringArray:
		for entry: Variant in raw:
			ids.append(String(entry))
	return ids


## Yalnız PURCHASED durumundakiler sahiplik sayılır; PENDING ya da bilinmeyen durum SAYILMAZ.
## Durum alanı yoksa sahiplik VERİLMEZ (eski sürümdeki "varsayılan satın alındı" kaldırıldı: güvenli taraf).
static func owned_ids(purchases: Array) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for entry: Variant in purchases:
		if not (entry is Dictionary):
			continue
		var info: Dictionary = entry as Dictionary
		if int(info.get("purchase_state", -1)) != PURCHASE_STATE_PURCHASED:
			continue
		for id: String in purchase_product_ids(info):
			if not result.has(id):
				result.append(id)
	return result


## Onay gerektiren jetonlar: PURCHASED + is_acknowledged == false (docs: yalnız bunlar onaylanır).
static func tokens_to_acknowledge(purchases: Array) -> PackedStringArray:
	var tokens: PackedStringArray = PackedStringArray()
	for entry: Variant in purchases:
		if not (entry is Dictionary):
			continue
		var info: Dictionary = entry as Dictionary
		if int(info.get("purchase_state", -1)) != PURCHASE_STATE_PURCHASED or bool(info.get("is_acknowledged", false)):
			continue
		var token: String = String(info.get("purchase_token", ""))
		if not token.is_empty() and not tokens.has(token):
			tokens.append(token)
	return tokens


## Yanıt kodu -> arayüz sebebi.
static func reason_for_code(code: int) -> String:
	if code == RESPONSE_USER_CANCELED:
		return REASON_CANCELED
	if CONNECTION_CODES.has(code):
		return REASON_NOT_CONNECTED
	return REASON_ERROR


# --- Eklenti geri çağrıları ---------------------------------------------------------------

func _bind(signal_name: String, handler: Callable) -> void:
	if _client.has_signal(signal_name) and not _client.is_connected(signal_name, handler):
		_client.connect(signal_name, handler)


func _connect_store() -> void:
	if _client == null or _connecting:
		return
	if bool(_client.call("is_ready")):
		_on_connected()
		return
	_connecting = true
	_client.call("start_connection")


func _on_connected() -> void:
	_connecting = false
	_connected = true
	_details_ready = false
	_client.call("query_product_details", PackedStringArray(PRODUCT_IDS), PRODUCT_TYPE_INAPP)
	# Açılışta sahiplik yeniden doğrulanır (yeniden kurulum, cihaz değişimi, iade).
	_client.call("query_purchases", PRODUCT_TYPE_INAPP)
	_restore_when_connected = false


func _on_disconnected() -> void:
	_connecting = false
	_connected = false
	_details_ready = false
	_fail_waiting_purchase(REASON_NOT_CONNECTED)


func _on_connect_error(_code: int, _message: String) -> void:
	_connecting = false
	_connected = false
	_fail_waiting_purchase(REASON_NOT_CONNECTED)
	if _restore_when_connected:
		_restore_when_connected = false
		restore_finished.emit(PackedStringArray(), false)


func _fail_waiting_purchase(reason: String) -> void:
	if not _purchase_when_ready.is_empty():
		var waiting: String = _purchase_when_ready
		_purchase_when_ready = ""
		purchase_failed.emit(waiting, reason)


func _on_product_details_response(response: Dictionary) -> void:
	if int(response.get("response_code", RESPONSE_ERROR_FALLBACK)) == RESPONSE_OK:
		for entry: Variant in response.get("product_details", []) as Array:
			if entry is Dictionary:
				var info: Dictionary = entry as Dictionary
				_prices[String(info.get("product_id", ""))] = parse_price(info)
		_details_ready = true
		if not _purchase_when_ready.is_empty():
			var waiting: String = _purchase_when_ready
			_purchase_when_ready = ""
			_start_purchase(waiting)
	else:
		_fail_waiting_purchase(reason_for_code(int(response.get("response_code", RESPONSE_ERROR_FALLBACK))))
	prices_changed.emit()





func _start_purchase(product_id: String) -> void:
	# Dönen sözlük yalnız "akış açıldı mı"dır (docs/api/methods.md "purchase"); sonuç on_purchase_updated'dadır.
	var result: Variant = _client.call("purchase", product_id)
	if result is Dictionary:
		var code: int = int((result as Dictionary).get("response_code", RESPONSE_OK))
		if code == RESPONSE_ITEM_ALREADY_OWNED:
			_client.call("query_purchases", PRODUCT_TYPE_INAPP)  # sahiplik geri yüklenir
		elif code != RESPONSE_OK:
			purchase_failed.emit(product_id, reason_for_code(code))


func _on_purchase_updated(response: Dictionary) -> void:
	var code: int = int(response.get("response_code", RESPONSE_ERROR_FALLBACK))
	if code != RESPONSE_OK:
		if code == RESPONSE_ITEM_ALREADY_OWNED:
			_client.call("query_purchases", PRODUCT_TYPE_INAPP)
			return
		purchase_failed.emit(PRODUCT_REMOVE_ADS, reason_for_code(code))
		return
	var purchases: Array = response.get("purchases", []) as Array
	_acknowledge_all(purchases)
	var granted: PackedStringArray = owned_ids(purchases)
	for id: String in granted:
		purchase_succeeded.emit(id)
	if granted.is_empty():
		for entry: Variant in purchases:
			if entry is Dictionary and int((entry as Dictionary).get("purchase_state", -1)) == PURCHASE_STATE_PENDING:
				# Ödeme beklemede: sahiplik yok; arayüze "tamamlanmadı" denir, Play sonra bildirir.
				pending_seen = true
				purchase_failed.emit(PRODUCT_REMOVE_ADS, REASON_PENDING)
				return


func _on_query_purchases_response(response: Dictionary) -> void:
	if int(response.get("response_code", RESPONSE_ERROR_FALLBACK)) != RESPONSE_OK:
		restore_finished.emit(PackedStringArray(), false)
		return
	var purchases: Array = response.get("purchases", []) as Array
	_acknowledge_all(purchases)
	restore_finished.emit(owned_ids(purchases), true)


## Onaylanmamış PURCHASED satın almaları BİR kez onaylar (tüketilmez: ürün kalıcıdır).
## Başarısız yanıtta jeton listeden düşer; bir sonraki sorguda (açılış) yeniden denenir.
func _acknowledge_all(purchases: Array) -> void:
	for token: String in tokens_to_acknowledge(purchases):
		if _ack_inflight.has(token) or _acknowledged.has(token):
			continue
		_ack_inflight[token] = true
		_client.call("acknowledge_purchase", token)


func _on_acknowledge_response(response: Dictionary) -> void:
	var token: String = String(response.get("token", ""))
	_ack_inflight.erase(token)
	if int(response.get("response_code", RESPONSE_ERROR_FALLBACK)) == RESPONSE_OK:
		_acknowledged[token] = true
