class_name AdsProvider
extends RefCounted
## Reklam SDK'sının tek sınırı. `AdManager` dışında hiçbir script bunu kullanmaz; oyun kodu `Ads` cephesiyle konuşur.
## Somut uygulamalar (mock, AdMob, reklamsız) yalnızca bu arayüzü genişletir.
##
## Sinyal sözleşmesi:
##  * `shown`     reklam ekrana geldi,
##  * `rewarded`  ödüllü reklam: kullanıcı ödülü hak etti (ve reklam kapandı). ÖDÜL YALNIZ BUNDAN doğar,
##  * `dismissed` reklam kapandı (geçiş reklamı bu sinyalle tamamlanır),
##  * `failed`    gösterilemedi ya da ödül alınmadan kapatıldı.
##
## Onay (consent) sözleşmesi: yönetici önce `request_consent()` çağırır; sağlayıcı `initialize()` ancak onay
## çözüldükten ve `can_request_ads == true` ise çağrılır. Onay çözülmeden HİÇBİR reklam isteği yapılmaz.

## AdPlacement.Id.INTERSTITIAL ile AYNI sayı (testle sabit): sağlayıcı hangi reklam türünün istendiğini buradan ayırır.
const INTERSTITIAL_PLACEMENT: int = AdPlacement.Id.INTERSTITIAL

signal shown()
signal rewarded()
signal dismissed()
signal failed(reason: String)


## Onay akışı. Bitince `on_done.call(can_request_ads: bool)`. Onay gerekmeyen sağlayıcılar hemen `true` döner.
func request_consent(on_done: Callable) -> void:
	on_done.call(true)


## Gizlilik seçenekleri (UMP) formu gerekli mi? İsteğe bağlı yetenek; ayarlar ekranı "Gizlilik seçenekleri" satırı için.
func privacy_options_required() -> bool:
	return false


## Gizlilik seçenekleri formunu gösterir; bitince `on_done.call()`. Desteklemeyen sağlayıcı hemen çağırır.
func show_privacy_options(on_done: Callable) -> void:
	on_done.call()


## Onay sonrası SDK'yı başlatır ve ilk reklamları önyükler.
func initialize() -> void:
	pass


func is_ready(_placement: int) -> bool:
	return false


func show(_placement: int) -> void:
	failed.emit("not_implemented")


## Sıradaki reklamı önceden yükletir (varsa). Gösterimden sonra sağlayıcı kendi de çağırır.
func preload_ads() -> void:
	pass
