extends Node
## Analitik. Şimdilik no-op: olayları hiçbir yere göndermez.
## Gerçek SDK eklenince sadece _send() değişir; oyun kodu Analytics.log_event(...) çağırmaya devam eder.
## Kullanıcı onayı (KVKK/GDPR) olmadan hiçbir şey gönderilmemeli: `consent_given`.

var consent_given := false
## Son olaylar (yalnızca bellekte; testler ve hata ayıklama için). Gönderim yine onaya bağlıdır.
var recent: Array[Dictionary] = []


func _ready() -> void:
	consent_given = bool(SettingsManager.get_value("game", "analytics_consent"))


func set_consent(given: bool) -> void:
	consent_given = given


func log_event(event_name: String, params: Dictionary = {}) -> void:
	recent.append({"name": event_name, "params": params})
	if recent.size() > 50:
		recent.pop_front()
	if OS.is_debug_build():
		print_verbose("[Analytics] %s %s" % [event_name, params])
	if consent_given:
		_send(event_name, params)


func _send(_event_name: String, _params: Dictionary) -> void:
	pass
