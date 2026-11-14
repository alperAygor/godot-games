class_name AdsProvider
extends RefCounted
## Reklam SDK'sı arayüzü. Gerçek bir SDK (ör. AdMob eklentisi) bu sınıfı extend eder.
## Bu temel sınıf hiçbir reklam göstermez: ödüllü reklam her zaman "ödülsüz" biter.

signal rewarded_finished(placement: String, rewarded: bool)
signal interstitial_closed(placement: String)
signal consent_finished


func initialize() -> void:
	pass


func is_rewarded_ready(_placement: String) -> bool:
	return false


func show_rewarded(placement: String) -> void:
	rewarded_finished.emit.call_deferred(placement, false)


func show_interstitial(placement: String) -> void:
	interstitial_closed.emit.call_deferred(placement)


func set_banner_visible(_is_visible: bool) -> void:
	pass


## Reklam onayı (GDPR/UMP): gerekiyorsa formu gösterir; bitince `consent_finished` yayılır. Taban sınıf: onay gerekmez.
func request_consent() -> void:
	consent_finished.emit.call_deferred()


## Ayarlar > Gizlilik seçenekleri: sağlayıcının onay formunu yeniden açar (varsa). Açabildiyse true.
func show_privacy_options() -> bool:
	return false


## Kullanıcı reklam kişiselleştirmesine izin verdi mi (false = yalnızca kişiselleştirilmemiş reklam).
func set_personalization(_allowed: bool) -> void:
	pass
