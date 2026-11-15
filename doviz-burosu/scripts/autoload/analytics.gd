extends Node
## Yerel olay günlüğü. Bu oyunda analitik SDK'sı YOK ve hiçbir olay cihazdan ÇIKMAZ: olaylar yalnızca bellekte (son 50) tutulur;
## testler ve hata ayıklama içindir. Gönderim yolu bilerek yok (eski `_send()` kaldırıldı); bu yüzden onay/anahtar da yok ve
## gizlilik metni analitikten söz etmez. Gerçek bir analitik SDK'sı eklenirse ÖNCE ayrı bir açık-izin anahtarı (`game/analytics_consent`),
## onay penceresi metni, Veri güvenliği formu ve gizlilik politikası güncellenmelidir (docs/MONETIZATION.md).
## Oyun kodu `Analytics.log_event(...)` çağırmaya devam eder.

## Son olaylar (yalnızca bellekte).
var recent: Array[Dictionary] = []


func log_event(event_name: String, params: Dictionary = {}) -> void:
	recent.append({"name": event_name, "params": params})
	if recent.size() > 50:
		recent.pop_front()
	if OS.is_debug_build():
		print_verbose("[Analytics] %s %s" % [event_name, params])
