extends TestCase

## IapProvider / MockIapProvider / IapService / PlayBillingProvider ayrıştırıcıları.

var _progress: Node = null
var _service: IapService = null
var _mock: MockIapProvider = null


func before_each() -> void:
	var script: GDScript = load("res://scripts/autoload/Progress.gd") as GDScript
	_progress = script.new()
	_progress.set("persist", false)
	_progress.set("save_path", "user://test_iap_never_written.json")
	_progress.set("balance", ProgressData.load_balance())
	_service = IapService.new()
	_service.progress = _progress
	_mock = MockIapProvider.new()
	_service.set_provider(_mock)


func after_each() -> void:
	_service.free()
	_progress.free()


func test_product_id_constant() -> void:
	assert_eq(IapProvider.PRODUCT_REMOVE_ADS, "remove_ads")


func test_mock_purchase_succeeds_and_persists_ownership() -> void:
	assert_false(_service.remove_ads_owned())
	_service.buy_remove_ads()
	assert_true(_service.remove_ads_owned())
	assert_true(bool(_progress.call("remove_ads_owned")))
	assert_eq(_progress.call("module_value", "shop", "remove_ads", false), true, "modül shop / anahtar remove_ads")


func test_mock_failure_and_cancel_do_not_grant() -> void:
	var reasons: Array[String] = []
	_service.purchase_failed.connect(func(reason: String) -> void: reasons.append(reason))
	_mock.fail_next = true
	_service.buy_remove_ads()
	_mock.cancel_next = true
	_service.buy_remove_ads()
	assert_false(_service.remove_ads_owned())
	assert_eq(reasons, [IapProvider.REASON_ERROR, IapProvider.REASON_CANCELED])
	_service.buy_remove_ads()
	assert_true(_service.remove_ads_owned(), "hata bir kerelikti")


func test_base_provider_is_unavailable() -> void:
	var reasons: Array[String] = []
	_service.set_provider(IapProvider.new())
	_service.purchase_failed.connect(func(reason: String) -> void: reasons.append(reason))
	assert_false(_service.store_available())
	_service.buy_remove_ads()
	assert_eq(reasons, [IapProvider.REASON_UNAVAILABLE])
	assert_false(_service.remove_ads_owned(), "mağaza yokken sahte başarı verilmez")


func test_restore_grants_from_store() -> void:
	var found: Array[bool] = []
	_service.restore_done.connect(func(value: bool) -> void: found.append(value))
	_service.restore_purchases()
	assert_eq(found, [false], "sahte mağazada henüz alım yok")
	_service.buy_remove_ads()
	_progress.call("set_remove_ads_owned", false)
	_service.restore_purchases()
	assert_true(_service.remove_ads_owned(), "mağazadaki alım geri yüklendi")
	assert_eq(found, [false, true])


class FakeStore extends IapProvider:
	var owned: PackedStringArray = PackedStringArray()
	var ok: bool = true

	func is_available() -> bool:
		return true

	func is_authoritative() -> bool:
		return true

	func restore() -> void:
		restore_finished.emit(owned, ok)


func test_authoritative_store_revokes_refunded_purchase() -> void:
	_progress.call("set_remove_ads_owned", true)
	var store: FakeStore = FakeStore.new()
	store.owned = PackedStringArray()
	_service.set_provider(store)  # açılış doğrulaması: mağaza "yok" diyor
	assert_false(_service.remove_ads_owned(), "iade edilen alım kayıttan düşer")


func test_failed_store_query_does_not_revoke() -> void:
	_progress.call("set_remove_ads_owned", true)
	var store: FakeStore = FakeStore.new()
	store.ok = false
	_service.set_provider(store)
	assert_true(_service.remove_ads_owned(), "sorgu başarısızsa sahiplik silinmez")


func test_authoritative_store_confirms_on_boot() -> void:
	var store: FakeStore = FakeStore.new()
	store.owned = PackedStringArray(["remove_ads"])
	_service.set_provider(store)
	assert_true(_service.remove_ads_owned(), "yeni cihaz: sahiplik mağazadan gelir")


func test_mock_never_revokes() -> void:
	_progress.call("set_remove_ads_owned", true)
	_service.set_provider(MockIapProvider.new())
	assert_true(_service.remove_ads_owned(), "mock yerel kaydı silmez")


func test_price_text_comes_from_provider() -> void:
	assert_eq(_service.price_text(), MockIapProvider.MOCK_PRICE)
	_service.set_provider(IapProvider.new())
	assert_eq(_service.price_text(), "")


func test_play_billing_parsers() -> void:
	assert_eq(PlayBillingProvider.parse_price({"one_time_purchase_offer_details": {"formatted_price": "₺149,99"}}), "₺149,99")
	assert_eq(PlayBillingProvider.parse_price({"price": "$2.99"}), "$2.99")
	assert_eq(PlayBillingProvider.parse_price({}), "")
	var purchases: Array = [
		{"product_ids": ["remove_ads"], "purchase_state": 1, "is_acknowledged": false},
		{"product_ids": ["other"], "purchase_state": 2},
		{"sku": "legacy", "purchase_state": 1},
	]
	var owned: PackedStringArray = PlayBillingProvider.owned_ids(purchases)
	assert_true(owned.has("remove_ads"))
	assert_false(owned.has("other"), "beklemedeki ödeme sahiplik değildir")
	assert_true(owned.has("legacy"))


func test_default_provider_selection_has_no_plugin_here() -> void:
	assert_false(PlayBillingProvider.plugin_present(), "masaüstünde eklenti yok")
	var provider: IapProvider = IapService.make_default_provider()
	if OS.is_debug_build():
		assert_true(provider is MockIapProvider)
	else:
		assert_false(provider.is_available())
