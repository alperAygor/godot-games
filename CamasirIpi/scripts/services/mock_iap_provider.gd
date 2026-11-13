class_name MockIapProvider
extends IapProvider

## Masaüstü/test mağazası: satın alma anında başarılı olur, `fail_next` ile hata yolu denenir.
## Sahiplik yalnız bellektedir; gerçek kayıt `Progress`tedir (servis yazar).

const MOCK_PRICE: String = "$2.99"

## true iken sıradaki satın alma `error` ile düşer (sonra kendiliğinden false olur).
var fail_next: bool = false
## true iken sıradaki satın alma `canceled` ile düşer.
var cancel_next: bool = false
var _owned: PackedStringArray = PackedStringArray()


func initialize() -> void:
	prices_changed.emit()


func is_available() -> bool:
	return true


func price_text(product_id: String) -> String:
	return MOCK_PRICE if PRODUCT_IDS.has(product_id) else ""


func purchase(product_id: String) -> void:
	if not PRODUCT_IDS.has(product_id):
		purchase_failed.emit(product_id, REASON_ERROR)
		return
	if cancel_next:
		cancel_next = false
		purchase_failed.emit(product_id, REASON_CANCELED)
		return
	if fail_next:
		fail_next = false
		purchase_failed.emit(product_id, REASON_ERROR)
		return
	if not _owned.has(product_id):
		_owned.append(product_id)
	purchase_succeeded.emit(product_id)


func restore() -> void:
	restore_finished.emit(_owned.duplicate(), true)
