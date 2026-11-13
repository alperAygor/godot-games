class_name IapProvider
extends RefCounted

## Uygulama içi satın alma mağazasının tek sınırı (AdsProvider'ın eşi). Taban sınıf aynı zamanda
## "mağaza yok" davranışıdır: `is_available()` false, satın alma hemen `unavailable` ile düşer.
## Somut uygulamalar: `MockIapProvider` (masaüstü/test), `PlayBillingProvider` (Android).
## Oyun yalnız `IapService` üzerinden konuşur; SDK türleri bu sınırın dışına çıkmaz.

## Mağazadaki "Reklamları kaldır" ürününün kimliği (Play Console ürün kimliğiyle AYNI olmalı).
const PRODUCT_REMOVE_ADS: String = "remove_ads"
const PRODUCT_IDS: Array[String] = [PRODUCT_REMOVE_ADS]

## Sebep kodları (UI yalnız bunlara bakar, mağaza metnine değil).
const REASON_UNAVAILABLE: String = "unavailable"
const REASON_CANCELED: String = "canceled"
const REASON_ERROR: String = "error"
const REASON_NOT_CONNECTED: String = "not_connected"

signal purchase_succeeded(product_id: String)
signal purchase_failed(product_id: String, reason: String)
## Sahip olunan ürünler. `ok` false ise sorgu başarısızdı (liste boş olabilir ama "sahip değil" DEMEK DEĞİL).
signal restore_finished(owned_ids: PackedStringArray, ok: bool)
## Fiyat bilgisi geldi/değişti (mağaza sayfası yeniden çizilsin).
signal prices_changed


func initialize() -> void:
	pass


func is_available() -> bool:
	return false


## Gerçek mağaza mı? Yalnız gerçek mağazanın "sahip değil" yanıtı yerel kaydı silebilir (iade);
## mock hiçbir şeyi silmez.
func is_authoritative() -> bool:
	return false


## Mağazanın yerelleştirilmiş fiyat metni ("₺149,99"); henüz bilinmiyorsa boş.
func price_text(_product_id: String) -> String:
	return ""


func purchase(product_id: String) -> void:
	purchase_failed.emit(product_id, REASON_UNAVAILABLE)


func restore() -> void:
	restore_finished.emit(PackedStringArray(), false)
