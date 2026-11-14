class_name MockIapProvider
extends IapProvider
## Geliştirme ve test için sahte mağaza: her satın alma başarılı olur, fiyat data/products.json'daki mock_price.
## "Mağaza sahipliği" bellekte tutulur (restore bunu döndürür). Yayın sürümünde gerçek Google Play Billing kullanılmalı.

## Mağazanın bildiği sahiplikler (uygulama yeniden açılınca sıfırlanır, tıpkı gerçek test mağazası gibi değil: sadece dev).
var owned: PackedStringArray = []
## Testlerde bir sonraki satın almayı başarısız ettirmek için hata kodu ("" = başarılı).
var fail_next := ""


func is_available() -> bool:
	return true


func get_price_text(product_id: String) -> String:
	if GameData.has_table("products"):
		return str(GameData.table("products").get("products", {}).get(product_id, {}).get("mock_price", ""))
	return ""


func purchase(product_id: String) -> void:
	if not fail_next.is_empty():
		var error := fail_next
		fail_next = ""
		purchase_finished.emit.call_deferred(product_id, false, error)
		return
	if not (product_id in owned):
		owned.append(product_id)
	purchase_finished.emit.call_deferred(product_id, true, "")


func restore_purchases() -> void:
	purchases_restored.emit.call_deferred(owned.duplicate())
