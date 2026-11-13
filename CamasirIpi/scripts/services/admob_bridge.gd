class_name AdmobBridge
extends RefCounted

## AdMob eklentisi ile oyun arasındaki İNCE soyutlama. Taban sınıf "eklenti yok" davranışıdır;
## `PoingAdmobBridge` gerçek eklentiye bağlanır, testler sahte bir köprü verir.
## Neden köprü: sağlayıcının durum makinesi (yükle/göster/yeniden dene/zaman aşımı) eklentiden
## bağımsız test edilebilsin ve eklenti API'si değişirse yalnız tek dosya güncellensin.
## Tüm geri çağrılar Callable'dır; köprü bunları ana iş parçacığında çağırır.

func is_present() -> bool:
	return false


## `config`: {"app_id","test_device_ids"}. Hazır olunca `on_done.call()`.
func initialize(_config: Dictionary, on_done: Callable) -> void:
	on_done.call()


## GDPR/UMP onay akışı. Bitince `on_done.call(can_request_ads: bool)`.
func request_consent(_config: Dictionary, on_done: Callable) -> void:
	on_done.call(true)


func load_rewarded(_unit_id: String, _on_loaded: Callable, on_failed: Callable) -> void:
	on_failed.call("no_plugin")


func load_interstitial(_unit_id: String, _on_loaded: Callable, on_failed: Callable) -> void:
	on_failed.call("no_plugin")


## Yüklü ödüllü reklamı gösterir: `on_shown()`, `on_earned()`, `on_dismissed()`, `on_failed(reason)`.
func show_rewarded(_on_shown: Callable, _on_earned: Callable, _on_dismissed: Callable, on_failed: Callable) -> void:
	on_failed.call("no_plugin")


func show_interstitial(_on_shown: Callable, _on_dismissed: Callable, on_failed: Callable) -> void:
	on_failed.call("no_plugin")
