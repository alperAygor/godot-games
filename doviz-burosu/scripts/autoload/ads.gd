extends Node
## Reklam servisi. Oyun kodu sadece bu autoload'u kullanır, SDK'yı doğrudan çağırmaz.
## Sağlayıcı değiştirmek için: Ads.set_provider(MockAdsProvider.new())

signal rewarded_finished(placement: String, rewarded: bool)
signal interstitial_closed(placement: String)
signal consent_finished

var provider: AdsProvider


func _ready() -> void:
	set_provider(AdsProvider.new())


func set_provider(new_provider: AdsProvider) -> void:
	if provider:
		provider.rewarded_finished.disconnect(_on_rewarded_finished)
		provider.interstitial_closed.disconnect(_on_interstitial_closed)
		provider.consent_finished.disconnect(_on_consent_finished)
	provider = new_provider
	provider.rewarded_finished.connect(_on_rewarded_finished)
	provider.interstitial_closed.connect(_on_interstitial_closed)
	provider.consent_finished.connect(_on_consent_finished)
	provider.initialize()


func is_rewarded_ready(placement: String) -> bool:
	return provider.is_rewarded_ready(placement)


func show_rewarded(placement: String) -> void:
	Analytics.log_event("ad_rewarded_requested", {"placement": placement})
	provider.show_rewarded(placement)


func show_interstitial(placement: String) -> void:
	provider.show_interstitial(placement)


func set_banner_visible(is_visible: bool) -> void:
	provider.set_banner_visible(is_visible)


func request_consent() -> void:
	provider.request_consent()


func show_privacy_options() -> bool:
	return provider.show_privacy_options()


func set_personalization(allowed: bool) -> void:
	provider.set_personalization(allowed)


func _on_consent_finished() -> void:
	consent_finished.emit()


func _on_rewarded_finished(placement: String, rewarded: bool) -> void:
	rewarded_finished.emit(placement, rewarded)


func _on_interstitial_closed(placement: String) -> void:
	interstitial_closed.emit(placement)
