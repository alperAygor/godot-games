extends "res://tests/test_case.gd"
## Gerçek SDK sağlayıcıları (AdMob, Google Play Billing) SAHTE eklenti düğümleriyle: onay akışı, ödül, geçiş reklamı, satın alma,
## onaylama (acknowledge), geri yükleme. Gerçek eklenti (Admob / BillingClient) bu testlerde ASLA oluşturulmaz (yalnızca Android'de çalışır).


class FakeConsent extends RefCounted:
	var status := "NOT_REQUIRED"

	func to_status_string() -> String:
		return status


class FakeAdmob extends Node:
	signal initialization_completed(status_data)
	signal consent_info_updated
	signal consent_info_update_failed(error_data)
	signal consent_form_loaded
	signal consent_form_failed_to_load(error_data)
	signal consent_form_dismissed(error_data)
	signal rewarded_ad_loaded(ad_info, response_info)
	signal rewarded_ad_failed_to_load(ad_info, error_data)
	signal rewarded_ad_user_earned_reward(ad_info, reward_data)
	signal rewarded_ad_dismissed_full_screen_content(ad_info)
	signal rewarded_ad_failed_to_show_full_screen_content(ad_info, error_data)
	signal interstitial_ad_loaded(ad_info, response_info)
	signal interstitial_ad_failed_to_load(ad_info, error_data)
	signal interstitial_ad_dismissed_full_screen_content(ad_info)
	signal interstitial_ad_failed_to_show_full_screen_content(ad_info, error_data)

	var calls: Array[String] = []
	var consent := FakeConsent.new()
	var form_available := false
	var rewarded_loaded := false
	var interstitial_loaded := false
	var is_real := true
	var android_debug_application_id := ""
	var android_real_application_id := ""
	var android_real_rewarded_id := ""
	var android_real_interstitial_id := ""
	var auto_configure_on_initialize := false
	var max_ad_content_rating := 0
	var remove_rewarded_ads_after_displayed := false
	var remove_interstitial_ads_after_displayed := false

	func update_consent_info() -> void:
		calls.append("update_consent_info")

	func reset_consent_info() -> void:
		calls.append("reset_consent_info")

	func get_consent_status() -> FakeConsent:
		return consent

	func is_consent_form_available() -> bool:
		return form_available

	func load_consent_form() -> void:
		calls.append("load_consent_form")

	func show_consent_form() -> void:
		calls.append("show_consent_form")

	func initialize() -> void:
		calls.append("initialize")

	func set_personalization_state(value: int) -> void:
		calls.append("personalization:%d" % value)

	func set_request_configuration() -> void:
		calls.append("request_configuration")

	func is_rewarded_ad_loaded() -> bool:
		return rewarded_loaded

	func load_rewarded_ad() -> void:
		calls.append("load_rewarded")

	func show_rewarded_ad() -> void:
		calls.append("show_rewarded")

	func is_interstitial_ad_loaded() -> bool:
		return interstitial_loaded

	func load_interstitial_ad() -> void:
		calls.append("load_interstitial")

	func show_interstitial_ad() -> void:
		calls.append("show_interstitial")


class FakeBilling extends Node:
	signal connected
	signal disconnected
	signal connect_error(response_code, debug_message)
	signal query_product_details_response(response)
	signal query_purchases_response(response)
	signal on_purchase_updated(response)
	signal acknowledge_purchase_response(response)

	var calls: Array[String] = []
	var ready_state := true
	var purchase_result := {"response_code": 0, "debug_message": ""}

	func start_connection() -> void:
		calls.append("start_connection")

	func is_ready() -> bool:
		return ready_state

	func query_product_details(ids: PackedStringArray, _type: int) -> void:
		calls.append("details:%s" % ",".join(ids))

	func query_purchases(_type: int) -> void:
		calls.append("purchases")

	func purchase(product_id: String) -> Dictionary:
		calls.append("purchase:%s" % product_id)
		return purchase_result

	func acknowledge_purchase(token: String) -> void:
		calls.append("ack:%s" % token)


var admob: FakeAdmob
var ads: AdMobAdsProvider
var billing: FakeBilling
var iap: PlayBillingIapProvider
var logged: Array[String] = []


func after_each() -> void:
	for node: Node in [admob, billing]:
		if is_instance_valid(node):
			node.free()
	admob = null
	billing = null
	ads = null
	iap = null


func _make_ads(config: Dictionary = {}) -> void:
	if is_instance_valid(admob):
		admob.free()  # bir testte ikinci kez kurulursa öncekini bırak
	admob = FakeAdmob.new()
	logged.clear()
	ads = AdMobAdsProvider.new(config, admob)
	ads.problem_logger = func(message: String) -> void: logged.append(message)
	ads.initialize()


func _make_iap() -> void:
	billing = FakeBilling.new()
	iap = PlayBillingIapProvider.new(billing)
	iap.schedule_reconnects = false  # gerçek zamanlayıcı kurma; yeniden bağlanma testte elle tetiklenir
	iap.initialize(PackedStringArray(["no_ads"]))


## Bağlanır ve ürün ayrıntılarını alır (satın almanın önkoşulu).
func _connect_iap(price := "₺99,99") -> void:
	billing.connected.emit()
	billing.query_product_details_response.emit({"response_code": 0, "product_details": [
		{"product_id": "no_ads", "one_time_purchase_offer_details_list": [{"formatted_price": price}]}]})


func _ready_ads() -> void:
	_make_ads()
	ads.set_notice_answered(true)
	ads.request_consent()
	admob.consent_info_updated.emit()
	admob.initialization_completed.emit(null)


# --- AdMob: yapılandırma ---------------------------------------------------------------------------

func test_test_ids_are_used_unless_real_ids_are_complete() -> void:
	var base := {"mode": "test", "android": {"real_app_id": "ca-app-pub-1~2", "real_rewarded_unit": "ca-app-pub-1/3", "real_interstitial_unit": "ca-app-pub-1/4"}}
	assert_false(AdMobAdsProvider.new(base).uses_real_ids(), "mode=test")
	var empty := {"mode": "real", "android": {"real_app_id": "", "real_rewarded_unit": "x", "real_interstitial_unit": "y"}}
	assert_false(AdMobAdsProvider.new(empty).uses_real_ids())
	assert_eq(AdMobAdsProvider.new(empty).config_problem(), AdsConfig.PROBLEM_REAL_INCOMPLETE, "boş gerçek kimlik artık sessizce test'e DÜŞMEZ, sorun olarak bildirilir")
	var real := base.duplicate(true)
	real["mode"] = "real"
	assert_true(AdMobAdsProvider.new(real).uses_real_ids())
	assert_eq(AdMobAdsProvider.new(real).config_problem(), "")


func test_real_mode_with_missing_or_test_ids_never_starts_the_sdk() -> void:
	var test_ids := {"test_app_id": "t~1", "test_rewarded_unit": "t/1", "test_interstitial_unit": "t/2"}
	var incomplete := {"mode": "real", "android": test_ids.merged({"real_app_id": "", "real_rewarded_unit": "", "real_interstitial_unit": ""})}
	_make_ads(incomplete)
	assert_eq(ads.config_problem(), AdsConfig.PROBLEM_REAL_INCOMPLETE)
	assert_eq(logged.size(), 1, "yüksek sesle hata yazılır")
	assert_true("test'e düşülmedi" in logged[0] or "test kimliğine düşülmedi" in logged[0])
	var finished := [0]
	ads.consent_finished.connect(func() -> void: finished[0] += 1)
	ads.set_notice_answered(true)
	ads.request_consent()
	await tree.process_frame
	assert_eq(finished[0], 1, "onay bekleyen kalmaz")
	assert_eq(admob.calls, [], "SDK'ya hiçbir çağrı yapılmaz (ne onay ne başlatma ne yükleme)")
	assert_eq(ads.consent_regime(), ConsentFlow.REGIME_NONE)
	assert_false(ads.is_rewarded_ready("x"))
	var leaked := incomplete.duplicate(true)
	leaked["android"]["real_app_id"] = "ca-app-pub-3940256099942544~3347511713"
	leaked["android"]["real_rewarded_unit"] = "ca-app-pub-1111111111111111/2222222222"
	leaked["android"]["real_interstitial_unit"] = "ca-app-pub-1111111111111111/3333333333"
	assert_eq(AdMobAdsProvider.new(leaked).config_problem(), AdsConfig.PROBLEM_REAL_IS_TEST, "real alanında Google test kimliği = hata")


func test_shipped_config_is_test_mode_with_google_test_ids() -> void:
	var cfg := JsonIO.read_dict("res://data/ads_ids.json")
	assert_eq(cfg["mode"], "test", "yayından önce kullanıcı gerçek kimlikleri verene dek test modu")
	assert_true(str(cfg["android"]["test_app_id"]).begins_with("ca-app-pub-3940256099942544~"), "Google'ın herkese açık test uygulama kimliği")
	assert_true(str(cfg["android"]["test_rewarded_unit"]).begins_with("ca-app-pub-3940256099942544/"))
	assert_false(AdMobAdsProvider.new().uses_real_ids())


func test_export_config_file_matches_ids_json() -> void:
	var text := FileAccess.get_file_as_string("res://addons/AdmobPlugin/android_export.cfg")
	var cfg := JsonIO.read_dict("res://data/ads_ids.json")
	assert_true(text.contains("is_real=false"))
	assert_true(text.contains(str(cfg["android"]["test_app_id"])), "android_export.cfg güncel olmalı (python3 tools/sync_ads_config.py)")


func test_provider_configures_the_plugin_node() -> void:
	_make_ads()
	assert_eq(admob.is_real, false)
	assert_eq(admob.android_debug_application_id, "ca-app-pub-3940256099942544~3347511713")
	assert_eq(admob.max_ad_content_rating, 1, "PG")
	assert_true(admob.auto_configure_on_initialize and admob.remove_rewarded_ads_after_displayed)


# --- AdMob: onay (UMP) -----------------------------------------------------------------------------

func test_ads_start_only_after_consent_is_resolved() -> void:
	_make_ads()
	ads.set_notice_answered(true)
	var finished := [0]
	ads.consent_finished.connect(func() -> void: finished[0] += 1)
	ads.request_consent()
	assert_eq(admob.calls, ["update_consent_info"], "önce onay bilgisi güncellenir; SDK henüz başlamaz")
	admob.consent_info_updated.emit()
	assert_eq(admob.calls, ["update_consent_info", "personalization:1", "initialize"], "onay gerekmiyor: SDK başlar")
	assert_eq(finished[0], 1)


func test_required_consent_shows_the_form_before_starting() -> void:
	_make_ads()  # UMP rejiminde oyunun kendi penceresi beklenmez: form bitince SDK başlar
	admob.consent.status = "REQUIRED"
	admob.form_available = true
	ads.request_consent()
	admob.consent_info_updated.emit()
	assert_eq(admob.calls, ["update_consent_info", "load_consent_form"])
	admob.consent_form_loaded.emit()
	assert_eq(admob.calls.back(), "show_consent_form")
	assert_false("initialize" in admob.calls, "form kapanmadan SDK başlamaz")
	admob.consent_form_dismissed.emit(null)
	assert_true("initialize" in admob.calls)


func test_consent_failures_do_not_block_the_game() -> void:
	_make_ads()
	ads.set_notice_answered(true)
	ads.request_consent()
	admob.consent_info_update_failed.emit(null)
	assert_true("initialize" in admob.calls)
	_make_ads()
	admob.consent.status = "REQUIRED"
	admob.form_available = true
	ads.request_consent()
	admob.consent_info_updated.emit()
	admob.consent_form_failed_to_load.emit(null)
	assert_true("initialize" in admob.calls)


func test_outside_ump_regions_the_sdk_waits_for_the_games_own_notice() -> void:
	_make_ads()
	var finished := [0]
	ads.consent_finished.connect(func() -> void: finished[0] += 1)
	ads.request_consent()
	admob.consent_info_updated.emit()  # NOT_REQUIRED: UMP formu yok
	assert_eq(finished[0], 1)
	assert_eq(ads.consent_regime(), ConsentFlow.REGIME_NOTICE)
	assert_false("initialize" in admob.calls, "bilgi penceresi yanıtlanmadan SDK (ve reklam isteği) yok")
	ads.set_notice_answered(true)
	assert_eq(admob.calls.count("initialize"), 1)
	ads.set_notice_answered(true)
	assert_eq(admob.calls.count("initialize"), 1, "SDK bir kez başlar")


func test_ump_regions_show_only_the_ump_form_and_ignore_the_games_own_notice() -> void:
	_make_ads()
	admob.consent.status = "REQUIRED"
	admob.form_available = true
	ads.request_consent()
	admob.consent_info_updated.emit()
	admob.consent_form_loaded.emit()
	admob.consent_form_dismissed.emit(null)
	assert_eq(ads.consent_regime(), ConsentFlow.REGIME_FORM)
	assert_true("initialize" in admob.calls, "yalnız UMP yeterli: oyun penceresi beklenmez")
	assert_true(ads.show_privacy_options(), "ayarlardan UMP yeniden açılabilir")
	assert_eq(admob.calls.slice(-2), ["reset_consent_info", "update_consent_info"])


func test_a_failed_consent_lookup_falls_back_to_the_notice_regime() -> void:
	_make_ads()
	ads.request_consent()
	admob.consent_info_update_failed.emit(null)
	assert_eq(ads.consent_regime(), ConsentFlow.REGIME_NOTICE)
	assert_false(ads.show_privacy_options(), "UMP yok: gizlilik seçenekleri oyunun kendi penceresinden")


func test_personalization_follows_the_users_choice() -> void:
	_make_ads()
	ads.set_notice_answered(true)
	ads.set_personalization(false)
	assert_eq(admob.calls.back(), "personalization:2", "reddedince kişiselleştirilmemiş reklam")
	ads.request_consent()
	admob.consent_info_updated.emit()
	assert_eq(admob.calls.count("initialize"), 1)
	admob.initialization_completed.emit(null)
	ads.set_personalization(true)
	assert_eq(admob.calls.slice(-2), ["personalization:1", "request_configuration"], "başlatıldıktan sonra SDK'ya yeniden uygulanır")


func test_umps_decision_is_not_overridden_by_the_games_personalization_setting() -> void:
	_make_ads()
	admob.consent.status = "OBTAINED"
	ads.set_personalization(false)
	ads.request_consent()
	admob.consent_info_updated.emit()
	assert_eq(admob.calls.filter(func(c: String) -> bool: return c.begins_with("personalization")).back(), "personalization:1")


# --- AdMob: ödüllü ----------------------------------------------------------------------------------

func test_ads_preload_after_initialization() -> void:
	_ready_ads()
	assert_true("load_rewarded" in admob.calls and "load_interstitial" in admob.calls)
	assert_false(ads.is_rewarded_ready("x"), "yüklenene dek hazır değil")
	admob.rewarded_loaded = true
	assert_true(ads.is_rewarded_ready("x"))


func test_rewarded_pays_only_when_the_reward_was_earned() -> void:
	_ready_ads()
	var results: Array = []
	ads.rewarded_finished.connect(func(placement: String, rewarded: bool) -> void: results.append([placement, rewarded]))
	admob.rewarded_loaded = true
	ads.show_rewarded("double_pay")
	assert_eq(admob.calls.back(), "show_rewarded")
	admob.rewarded_ad_user_earned_reward.emit(null, null)
	admob.rewarded_loaded = false
	admob.rewarded_ad_dismissed_full_screen_content.emit(null)
	assert_eq(results, [["double_pay", true]])
	assert_eq(admob.calls.back(), "load_rewarded", "bir sonraki hemen yüklenir")
	# Kapatılırsa (ödül kazanılmadan) ödül yok
	admob.rewarded_loaded = true
	ads.show_rewarded("rate_tip")
	admob.rewarded_loaded = false
	admob.rewarded_ad_dismissed_full_screen_content.emit(null)
	assert_eq(results.back(), ["rate_tip", false])


func test_rewarded_that_fails_to_show_gives_no_reward() -> void:
	_ready_ads()
	var results: Array = []
	ads.rewarded_finished.connect(func(placement: String, rewarded: bool) -> void: results.append([placement, rewarded]))
	admob.rewarded_loaded = true
	ads.show_rewarded("overtime")
	admob.rewarded_ad_failed_to_show_full_screen_content.emit(null, null)
	assert_eq(results, [["overtime", false]])


func test_rewarded_without_a_loaded_ad_finishes_unrewarded_without_crashing() -> void:
	_ready_ads()
	var results: Array = []
	ads.rewarded_finished.connect(func(placement: String, rewarded: bool) -> void: results.append([placement, rewarded]))
	ads.show_rewarded("retry_day")
	await tree.process_frame
	assert_eq(results, [["retry_day", false]])
	assert_false("show_rewarded" in admob.calls)


func test_reward_flag_does_not_leak_into_the_next_ad() -> void:
	_ready_ads()
	var results: Array = []
	ads.rewarded_finished.connect(func(placement: String, rewarded: bool) -> void: results.append(rewarded))
	admob.rewarded_loaded = true
	ads.show_rewarded("a")
	admob.rewarded_ad_user_earned_reward.emit(null, null)
	admob.rewarded_ad_dismissed_full_screen_content.emit(null)
	admob.rewarded_loaded = true
	ads.show_rewarded("b")
	admob.rewarded_ad_dismissed_full_screen_content.emit(null)
	assert_eq(results, [true, false])


# --- AdMob: geçiş ------------------------------------------------------------------------------------

func test_interstitial_shows_and_reports_closing() -> void:
	_ready_ads()
	var closed: Array = []
	ads.interstitial_closed.connect(func(placement: String) -> void: closed.append(placement))
	admob.interstitial_loaded = true
	ads.show_interstitial("day_end")
	assert_eq(admob.calls.back(), "show_interstitial")
	admob.interstitial_loaded = false
	admob.interstitial_ad_dismissed_full_screen_content.emit(null)
	assert_eq(closed, ["day_end"])
	assert_eq(admob.calls.back(), "load_interstitial")


func test_interstitial_that_is_not_ready_never_blocks_the_game() -> void:
	_ready_ads()
	var closed: Array = []
	ads.interstitial_closed.connect(func(placement: String) -> void: closed.append(placement))
	ads.show_interstitial("day_end")
	await tree.process_frame
	assert_eq(closed, ["day_end"], "hazır değilse hemen kapanmış sayılır")
	admob.interstitial_loaded = true
	ads.show_interstitial("mode_end")
	admob.interstitial_ad_failed_to_show_full_screen_content.emit(null, null)
	assert_eq(closed, ["day_end", "mode_end"], "gösterilemezse de oyun devam eder")


func test_reload_delay_backs_off_exponentially_up_to_the_cap() -> void:
	_make_ads()
	var delays: Array = []
	for attempt in range(1, 7):
		delays.append(ads.retry_delay(attempt))
	assert_eq(delays, [20.0, 40.0, 80.0, 160.0, 240.0, 240.0])


# --- Google Play Billing --------------------------------------------------------------------------------

func _purchase(state := 1, acknowledged := false, token := "tok-1") -> Dictionary:
	return {"response_code": 0, "debug_message": "", "purchases": [{"purchase_token": token, "purchase_state": state,
		"is_acknowledged": acknowledged, "product_ids": PackedStringArray(["no_ads"])}]}


func test_billing_connects_and_queries_details_and_owned_items() -> void:
	_make_iap()
	assert_eq(billing.calls, ["start_connection"])
	billing.connected.emit()
	assert_eq(billing.calls, ["start_connection", "details:no_ads", "purchases"])
	assert_true(iap.is_available())


func test_price_text_comes_from_the_store_wherever_it_is_nested() -> void:
	_make_iap()
	billing.connected.emit()
	assert_eq(iap.get_price_text("no_ads"), "", "yanıt gelene dek boş (arayüz sahte fiyata düşmez)")
	billing.query_product_details_response.emit({"response_code": 0, "product_details": [
		{"product_id": "no_ads", "one_time_purchase_offer_details": {"formatted_price": "₺99,99", "price_amount_micros": 99990000}}]})
	assert_eq(iap.get_price_text("no_ads"), "₺99,99")
	billing.query_product_details_response.emit({"response_code": 3, "product_details": []})
	assert_eq(iap.get_price_text("no_ads"), "₺99,99", "hatalı yanıt eski fiyatı bozmaz")


func test_a_purchase_is_acknowledged_before_the_reward_is_given() -> void:
	_make_iap()
	_connect_iap()
	var results: Array = []
	iap.purchase_finished.connect(func(id: String, ok: bool, error: String) -> void: results.append([id, ok, error]))
	iap.purchase("no_ads")
	assert_eq(billing.calls.back(), "purchase:no_ads")
	billing.on_purchase_updated.emit(_purchase())
	assert_eq(billing.calls.back(), "ack:tok-1", "satın alma ONAYLANIR")
	assert_eq(results, [], "onay tamamlanmadan ödül yok")
	billing.acknowledge_purchase_response.emit({"response_code": 0, "token": "tok-1"})
	assert_eq(results, [["no_ads", true, ""]])


func test_an_already_acknowledged_purchase_completes_at_once() -> void:
	_make_iap()
	_connect_iap()
	var results: Array = []
	iap.purchase_finished.connect(func(id: String, ok: bool, _e: String) -> void: results.append([id, ok]))
	iap.purchase("no_ads")
	billing.on_purchase_updated.emit(_purchase(1, true))
	assert_eq(results, [["no_ads", true]])
	assert_false("ack:tok-1" in billing.calls)


func test_pending_purchases_give_nothing() -> void:
	_make_iap()
	_connect_iap()
	var results: Array = []
	iap.purchase_finished.connect(func(id: String, ok: bool, _e: String) -> void: results.append([id, ok]))
	iap.purchase("no_ads")
	billing.on_purchase_updated.emit(_purchase(2))
	assert_eq(results, [["no_ads", false]], "sahiplik/ödül yok; 'beklemede' başarısız olarak bildirilir")
	assert_false("ack:tok-1" in billing.calls, "PENDING onaylanmaz")


func test_cancelled_and_failed_purchases_report_failure() -> void:
	_make_iap()
	_connect_iap()
	var results: Array = []
	iap.purchase_finished.connect(func(id: String, ok: bool, error: String) -> void: results.append([id, ok, error]))
	iap.purchase("no_ads")
	billing.on_purchase_updated.emit({"response_code": 1, "debug_message": "", "purchases": []})
	assert_eq(results.back(), ["no_ads", false, "user_cancelled"])
	iap.purchase("no_ads")
	billing.on_purchase_updated.emit({"response_code": 6, "debug_message": "", "purchases": []})
	assert_eq(results.back(), ["no_ads", false, "billing_error_6"])


func test_failed_acknowledge_is_reported_as_failure() -> void:
	_make_iap()
	_connect_iap()
	var results: Array = []
	iap.purchase_finished.connect(func(id: String, ok: bool, error: String) -> void: results.append([id, ok, error]))
	iap.purchase("no_ads")
	billing.on_purchase_updated.emit(_purchase())
	billing.acknowledge_purchase_response.emit({"response_code": 6, "token": "tok-1"})
	assert_eq(results, [["no_ads", false, "acknowledge_failed"]])


func test_item_already_owned_counts_as_success() -> void:
	_make_iap()
	_connect_iap()
	var results: Array = []
	iap.purchase_finished.connect(func(id: String, ok: bool, _e: String) -> void: results.append([id, ok]))
	iap.purchase("no_ads")
	billing.on_purchase_updated.emit({"response_code": 7, "debug_message": "", "purchases": []})
	assert_eq(results, [["no_ads", true]])


func test_purchase_without_a_store_connection_fails_cleanly() -> void:
	_make_iap()
	var results: Array = []
	iap.purchase_finished.connect(func(id: String, ok: bool, error: String) -> void: results.append([id, ok, error]))
	iap.purchase("no_ads")
	await tree.process_frame
	assert_eq(results, [["no_ads", false, "store_unavailable"]])
	assert_false(iap.is_available())


func test_owned_items_are_restored_on_startup_and_unacknowledged_ones_get_acknowledged() -> void:
	_make_iap()
	var restored: Array = []
	iap.purchases_restored.connect(func(ids: PackedStringArray) -> void: restored.append(ids))
	_connect_iap()
	billing.query_purchases_response.emit(_purchase(1, false, "tok-9"))
	assert_eq(restored.size(), 1)
	assert_true("no_ads" in restored[0], "açılışta sahiplik bildirilir")
	assert_eq(billing.calls.back(), "ack:tok-9", "kaçırılmış (onaysız) satın alma onaylanır; 3 gün sınırı")


func test_restore_reports_nothing_for_pending_or_failed_queries() -> void:
	_make_iap()
	_connect_iap()
	billing.query_purchases_response.emit({"response_code": 0, "purchases": []})
	var restored: Array = []
	iap.purchases_restored.connect(func(ids: PackedStringArray) -> void: restored.append(ids))
	iap.restore_purchases()
	billing.query_purchases_response.emit(_purchase(2))
	assert_true(restored[0].is_empty(), "beklemedeki satın alma sahiplik sayılmaz")
	var failures: Array = []
	iap.restore_failed.connect(func(reason: String) -> void: failures.append(reason))
	iap.restore_purchases()
	billing.query_purchases_response.emit({"response_code": 6, "purchases": []})
	assert_eq(restored.size(), 1, "hatalı sorgu 'hiçbir şey yok' demez")
	assert_eq(failures, ["billing_error_6"])


func test_restore_before_connection_is_answered_after_connecting() -> void:
	_make_iap()
	var restored: Array = []
	iap.purchases_restored.connect(func(ids: PackedStringArray) -> void: restored.append(ids))
	iap.restore_purchases()
	assert_eq(restored.size(), 0)
	_connect_iap()
	billing.query_purchases_response.emit(_purchase(1, true))
	assert_eq(restored.size(), 1)
	assert_true("no_ads" in restored[0])


func test_purchase_waits_for_product_details_before_starting() -> void:
	_make_iap()
	billing.connected.emit()
	var results: Array = []
	iap.purchase_finished.connect(func(id: String, ok: bool, error: String) -> void: results.append([id, ok, error]))
	iap.purchase("no_ads")
	assert_false("purchase:no_ads" in billing.calls, "ayrıntısız satın alma Play'de DEVELOPER_ERROR verir: bekletilir")
	billing.query_product_details_response.emit({"response_code": 0, "product_details": [{"product_id": "no_ads"}]})
	assert_eq(billing.calls.back(), "purchase:no_ads")
	assert_eq(results, [])


func test_a_product_missing_from_the_store_fails_cleanly() -> void:
	_make_iap()
	billing.connected.emit()
	billing.query_product_details_response.emit({"response_code": 0, "product_details": [], "unfetched_products": ["no_ads"]})
	var results: Array = []
	iap.purchase_finished.connect(func(id: String, ok: bool, error: String) -> void: results.append([id, ok, error]))
	iap.purchase("no_ads")
	await tree.process_frame
	assert_eq(results, [["no_ads", false, "item_unavailable"]])
	assert_false("purchase:no_ads" in billing.calls)


func test_pending_purchase_reports_pending_and_a_later_confirmation_grants() -> void:
	_make_iap()
	_connect_iap()
	var results: Array = []
	iap.purchase_finished.connect(func(id: String, ok: bool, error: String) -> void: results.append([id, ok, error]))
	iap.purchase("no_ads")
	billing.on_purchase_updated.emit(_purchase(2))
	assert_eq(results, [["no_ads", false, "pending"]], "ödül yok ama oyuncuya 'beklemede' denir")
	iap.purchase("no_ads")  # takılı kalmaz: yeni deneme mümkün
	assert_eq(billing.calls.back(), "purchase:no_ads")
	# Play ödemeyi sonradan tamamlar (uygulama o sırada başka ekranda olabilir)
	billing.on_purchase_updated.emit(_purchase(1, false, "tok-late"))
	billing.acknowledge_purchase_response.emit({"response_code": 0, "token": "tok-late"})
	assert_eq(results.back(), ["no_ads", true, ""])


func test_late_connection_announces_availability_and_price() -> void:
	_make_iap()
	var changes := [0]
	iap.availability_changed.connect(func() -> void: changes[0] += 1)
	assert_false(iap.is_available())
	_connect_iap("$2,99")
	assert_true(iap.is_available())
	assert_true(changes[0] >= 1, "Market ekranı yenilenir")
	assert_eq(iap.get_price_text("no_ads"), "$2,99", "3.3.0 yerleşimi: one_time_purchase_offer_details_list[0].formatted_price")


func test_a_dropped_connection_reconnects_with_backoff() -> void:
	_make_iap()
	_connect_iap()
	var changes := [0]
	iap.availability_changed.connect(func() -> void: changes[0] += 1)
	billing.disconnected.emit()
	assert_false(iap.is_available())
	assert_eq(changes[0], 1)
	assert_true(iap.reconnect_pending)
	assert_eq([iap.reconnect_delay(1), iap.reconnect_delay(2), iap.reconnect_delay(3), iap.reconnect_delay(9)], [2.0, 4.0, 8.0, 60.0])
	var starts := billing.calls.count("start_connection")
	iap._reconnect_now()
	assert_eq(billing.calls.count("start_connection"), starts + 1)
	iap._reconnect_now()
	assert_eq(billing.calls.count("start_connection"), starts + 1, "bağlanma sürerken ikinci başlatma yok")
	billing.connected.emit()
	assert_true(iap.is_available())
	assert_eq(iap.reconnect_attempts, 0)


func test_connect_error_fails_a_waiting_restore_and_a_purchase_cleanly() -> void:
	_make_iap()
	var failures: Array = []
	iap.restore_failed.connect(func(reason: String) -> void: failures.append(reason))
	iap.restore_purchases()
	billing.connect_error.emit(3, "billing unavailable")
	await tree.process_frame
	assert_eq(failures, ["store_unavailable"], "'geri yüklenecek yok' ile karıştırılmaz")
	assert_true(iap.reconnect_pending)


func test_a_purchase_before_the_store_is_ready_asks_for_a_reconnect() -> void:
	_make_iap()
	billing.connect_error.emit(3, "")
	var starts := billing.calls.count("start_connection")
	iap.purchase("no_ads")
	await tree.process_frame
	assert_eq(billing.calls.count("start_connection"), starts + 1)


# --- Sağlayıcı seçimi --------------------------------------------------------------------------------------

func test_desktop_runs_never_pick_the_real_providers() -> void:
	var monetization := tree.root.get_node("Monetization")
	var ads_node := tree.root.get_node("Ads")
	var iap_node := tree.root.get_node("IAP")
	monetization.install_providers()
	assert_false(ads_node.provider is AdMobAdsProvider, "eklenti tekili yalnızca Android'de var")
	assert_false(iap_node.provider is PlayBillingIapProvider)
	assert_true(ads_node.provider is MockAdsProvider or ads_node.provider is AdsProvider)
