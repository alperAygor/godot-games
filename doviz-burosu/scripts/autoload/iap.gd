extends Node
## Satın alma servisi. Oyun kodu sadece bu autoload'u kullanır.
## Ürün kimlikleri data/products.json içinde tutulur (kodda değil).
## Önemli: satın alma sonucu ödül vermeden önce gerçek SDK'da sunucu/mağaza doğrulaması yapılmalı.

signal purchase_finished(product_id: String, success: bool, error: String)
signal purchases_restored(product_ids: PackedStringArray)

var provider: IapProvider


func _ready() -> void:
	set_provider(IapProvider.new())


func set_provider(new_provider: IapProvider) -> void:
	if provider:
		provider.purchase_finished.disconnect(_on_purchase_finished)
		provider.purchases_restored.disconnect(_on_purchases_restored)
	provider = new_provider
	provider.purchase_finished.connect(_on_purchase_finished)
	provider.purchases_restored.connect(_on_purchases_restored)
	provider.initialize(get_product_ids())


func get_product_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	if GameData.has_table("products"):
		for product_id in GameData.table("products").get("products", {}).keys():
			ids.append(product_id)
	return ids


func is_available() -> bool:
	return provider.is_available()


func purchase(product_id: String) -> void:
	Analytics.log_event("iap_purchase_requested", {"product_id": product_id})
	provider.purchase(product_id)


func restore_purchases() -> void:
	provider.restore_purchases()


func _on_purchase_finished(product_id: String, success: bool, error: String) -> void:
	purchase_finished.emit(product_id, success, error)


func _on_purchases_restored(product_ids: PackedStringArray) -> void:
	purchases_restored.emit(product_ids)
