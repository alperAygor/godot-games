class_name AdsProvider
extends RefCounted

## Reklam SDK'sının tek sınırı. `AdManager` dışında hiçbir script bunu import etmez.
## Somut uygulamalar (mock, AdMob) yalnızca bu arayüzü genişletir.
##
## Sinyal sözleşmesi:
##  * `shown`     reklam ekrana geldi,
##  * `rewarded`  ödüllü reklam: kullanıcı ödülü hak etti (ve reklam kapandı); mock'ta geçiş
##                reklamı için de "tamamlandı" anlamında kullanılabilir,
##  * `dismissed` reklam kapandı (geçiş reklamı bu sinyalle tamamlanır),
##  * `failed`    gösterilemedi ya da ödül alınmadan kapatıldı.

## AdManager.Placement.INTERSTITIAL ile AYNI sayı (enum sırası testle sabitlenir):
## sağlayıcı autoload'a bağımlı olmadan hangi reklam türü istendiğini buradan ayırır.
const INTERSTITIAL_PLACEMENT: int = 6

signal shown()
signal rewarded()
signal dismissed()
signal failed(reason: String)


func initialize() -> void:
	pass


func is_ready(_placement: int) -> bool:
	return false


func show(_placement: int) -> void:
	failed.emit("not_implemented")


## Sıradaki reklamı önceden yükletir (varsa). Gösterimden sonra sağlayıcı kendi de çağırır.
func preload_ads() -> void:
	pass
