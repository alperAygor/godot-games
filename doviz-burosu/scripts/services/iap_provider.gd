class_name IapProvider
extends RefCounted
## Uygulama içi satın alma arayüzü. Gerçek bir SDK (ör. Google Play Billing eklentisi) bu sınıfı extend eder.
## Bu temel sınıf mağazaya bağlanmaz: her satın alma "kullanılamıyor" hatasıyla biter.

signal purchase_finished(product_id: String, success: bool, error: String)
signal purchases_restored(product_ids: PackedStringArray)
## Geri yükleme yapılamadı (mağazaya bağlanılamadı vb.). "Geri yüklenecek bir şey yok" ile karıştırılmaz.
signal restore_failed(reason: String)
## Mağaza kullanılabilirliği (bağlantı) değişti; arayüz yeniden çizilir.
signal availability_changed


func initialize(_product_ids: PackedStringArray) -> void:
	pass


func is_available() -> bool:
	return false


## Mağazadaki yerelleştirilmiş fiyat metni. Bilinmiyorsa boş döner.
func get_price_text(_product_id: String) -> String:
	return ""


func purchase(product_id: String) -> void:
	purchase_finished.emit.call_deferred(product_id, false, "store_unavailable")


func restore_purchases() -> void:
	purchases_restored.emit.call_deferred(PackedStringArray())


## Mağaza bağlantısı yoksa yeniden bağlanmayı dener (Market ekranı geç bağlanmada çağırır). Taban: yapacak bir şey yok.
func reconnect() -> void:
	pass
