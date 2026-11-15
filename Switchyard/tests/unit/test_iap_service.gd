extends TestCase

## IapService + MockIapProvider: fiyat mağazadan gelir, satın alma sahipliği yazar, geri yükleme,
## hata/iptal yolları, "mağaza yok" durumunda sahte başarı verilmez. Kayıt diske yazılmaz.

var _service: IapService = null
var _progress: Node = null
var _old_persist: bool = true
var _purchase_failures: Array[String] = []
var _restores: Array[bool] = []


func before_each() -> void:
	_progress = autoload_node("Progress")
	_old_persist = bool(_progress.get("persist"))
	_progress.set("persist", false)
	_progress.call("reset_state")
	_purchase_failures.clear()
	_restores.clear()
	_service = IapService.new()
	add_node(_service)
	_service.set_provider(MockIapProvider.new())
	_service.purchase_failed.connect(func(reason: String) -> void: _purchase_failures.append(reason))
	_service.restore_done.connect(func(found: bool) -> void: _restores.append(found))


func after_each() -> void:
	_service.queue_free()
	_progress.call("reset_state")
	_progress.set("persist", _old_persist)


func test_price_comes_from_the_store() -> void:
	assert_eq(_service.price_text(), MockIapProvider.MOCK_PRICE)
	assert_true(_service.store_available())


func test_purchase_sets_ownership_in_progress() -> void:
	assert_false(_service.remove_ads_owned())
	_service.buy_remove_ads()
	assert_true(_service.remove_ads_owned())
	assert_true(bool(_progress.call("remove_ads_owned")))
	assert_eq(_purchase_failures, [] as Array[String])


func test_canceled_and_failed_purchases_do_not_grant() -> void:
	var mock: MockIapProvider = _service.provider as MockIapProvider
	mock.cancel_next = true
	_service.buy_remove_ads()
	mock.fail_next = true
	_service.buy_remove_ads()
	assert_false(_service.remove_ads_owned())
	assert_eq(_purchase_failures, [IapProvider.REASON_CANCELED, IapProvider.REASON_ERROR] as Array[String])


func test_restore_reports_whether_something_was_found() -> void:
	_service.restore_purchases()
	assert_eq(_restores, [false] as Array[bool], "satın alım yokken bulunamadı")
	_service.buy_remove_ads()
	_service.restore_purchases()
	assert_eq(_restores, [false, true] as Array[bool])


func test_mock_restore_never_erases_local_ownership() -> void:
	_progress.call("set_remove_ads_owned", true)
	_service.restore_purchases()
	assert_true(_service.remove_ads_owned(), "sahte mağaza (yetkili değil) kaydı silmez")


func test_no_store_means_no_fake_success() -> void:
	_service.set_provider(IapProvider.new())
	assert_false(_service.store_available())
	_service.buy_remove_ads()
	assert_false(_service.remove_ads_owned())
	assert_eq(_purchase_failures, [IapProvider.REASON_UNAVAILABLE] as Array[String])
	_service.restore_purchases()
	assert_eq(_restores, [false] as Array[bool])


func test_already_owned_purchase_is_a_no_op() -> void:
	_service.buy_remove_ads()
	_service.buy_remove_ads()
	assert_eq(_purchase_failures, [] as Array[String])
	assert_true(_service.remove_ads_owned())
