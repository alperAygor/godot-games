class_name MockIapProvider
extends IapProvider
## Geliştirme ve test için sahte mağaza: her satın alma başarılı olur, fiyat data/products.json'daki mock_price.
## "Mağaza sahipliği" bellekte tutulur (restore bunu döndürür). Yayın sürümünde gerçek Google Play Billing kullanılmalı.

## Mağazanın bildiği sahiplikler (uygulama yeniden açılınca sıfırlanır, tıpkı gerçek test mağazası gibi değil: sadece dev).
var owned: PackedStringArray = []
## Testlerde bir sonraki satın almayı başarısız ettirmek için hata kodu ("" = başarılı).
var fail_next := ""
## Testlerde mağaza bağlantısını kesmek/getirmek için (gerçek mağaza geç bağlanabilir).
var available := true
## true ise bir sonraki satın alma "beklemede" biter (hata kodu "pending", sahiplik verilmez).
var pending_next := false


func set_available(value: bool) -> void:
	if available != value:
		available = value
		availability_changed.emit()


func is_available() -> bool:
	return available


func get_price_text(product_id: String) -> String:
	if GameData.has_table("products"):
		return str(GameData.table("products").get("products", {}).get(product_id, {}).get("mock_price", ""))
	return ""


func purchase(product_id: String) -> void:
	if not available:
		purchase_finished.emit.call_deferred(product_id, false, "store_unavailable")
		return
	if pending_next:
		pending_next = false
		purchase_finished.emit.call_deferred(product_id, false, "pending")
		return
	if not fail_next.is_empty():
		var error := fail_next
		fail_next = ""
		purchase_finished.emit.call_deferred(product_id, false, error)
		return
	if not (product_id in owned):
		owned.append(product_id)
	purchase_finished.emit.call_deferred(product_id, true, "")


func restore_purchases() -> void:
	if not available:
		restore_failed.emit.call_deferred("store_unavailable")
		return
	purchases_restored.emit.call_deferred(owned.duplicate())
