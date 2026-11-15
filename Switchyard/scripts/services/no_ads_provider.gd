class_name NoAdsProvider
extends AdsProvider

## Reklam göstermeyen güvenli varsayılan. Oyun bu sağlayıcıyla da tam OYNANABİLİR;
## yalnızca ödüllü kancalar devre dışı kalır. Testlerde ve ilk açılışta kullanılır.

func is_ready(_placement: int) -> bool:
	return false


func show(_placement: int) -> void:
	failed.emit("ads_disabled")
