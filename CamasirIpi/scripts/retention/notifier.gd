class_name Notifier
extends RefCounted

## Yerel bildirim sağlayıcı soyutlaması. Oyun yalnız `Notifier.schedule/cancel` çağırır;
## altındaki sağlayıcı platforma göre seçilir:
##  * NoopProvider  : masaüstü/editör/iOS (şimdilik) — hiçbir şey göndermez, yalnız kaydeder (testler okur).
##  * AndroidProvider: ÖRNEK KANCA. Bir Android yerel-bildirim eklentisi (Godot 4 Android plugin) tekil
##    nesne olarak `Engine.has_singleton(ANDROID_SINGLETON)` ile görünür; yöntem adları aşağıda
##    belgelenmiştir. Eklenti bu projeye İNDİRİLMEDİ; singleton yoksa Noop'a düşülür.
## Metinler anahtarla verilir ve PLANLAMA ANINDAKİ dilde çevrilir (dil değişince bir sonraki
## planlamada güncellenir). Bildirim izni (Android 13+ POST_NOTIFICATIONS) eklentinin sorumluluğudur.

const ANDROID_SINGLETON: String = "CamasirIpiLocalNotifications"
## Eklentiden beklenen yöntemler:
##   schedule(id: String, delay_seconds: int, title: String, body: String) -> void
##   cancel(id: String) -> void
const ANDROID_METHOD_SCHEDULE: String = "schedule"
const ANDROID_METHOD_CANCEL: String = "cancel"

static var provider: Provider = null


class Provider extends RefCounted:
	func schedule(_id: String, _seconds: int, _title: String, _body: String) -> void:
		pass

	func cancel(_id: String) -> void:
		pass


class NoopProvider extends Provider:
	## id -> {seconds, title, body}; yalnız test/hata ayıklama içindir.
	var scheduled: Dictionary = {}

	func schedule(id: String, seconds: int, title: String, body: String) -> void:
		scheduled[id] = {"seconds": seconds, "title": title, "body": body}

	func cancel(id: String) -> void:
		scheduled.erase(id)


class AndroidProvider extends Provider:
	var _plugin: Object = null

	func _init(plugin: Object) -> void:
		_plugin = plugin

	func schedule(id: String, seconds: int, title: String, body: String) -> void:
		if _plugin != null and _plugin.has_method(ANDROID_METHOD_SCHEDULE):
			_plugin.call(ANDROID_METHOD_SCHEDULE, id, seconds, title, body)

	func cancel(id: String) -> void:
		if _plugin != null and _plugin.has_method(ANDROID_METHOD_CANCEL):
			_plugin.call(ANDROID_METHOD_CANCEL, id)


static func get_provider() -> Provider:
	if provider == null:
		if Engine.has_singleton(ANDROID_SINGLETON):
			provider = AndroidProvider.new(Engine.get_singleton(ANDROID_SINGLETON))
		else:
			provider = NoopProvider.new()
	return provider


static func schedule(id: String, seconds_from_now: int, title_key: String, body_key: String) -> void:
	get_provider().schedule(id, maxi(seconds_from_now, 1), Loc.t(title_key), Loc.t(body_key))


static func cancel(id: String) -> void:
	get_provider().cancel(id)
