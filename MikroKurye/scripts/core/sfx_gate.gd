class_name SfxGate
extends RefCounted

## Aynı sesin çok sık çalınmasını engelleyen saf zaman kapısı.
## Sözleşme: ARCHITECTURE.md §5.6 (aynı ses 80 ms içinde iki kez çalınmaz).
##
## Zaman dışarıdan verilir; bu sınıf `Time`/`Engine` çağırmaz, böylece headless
## test edilebilir. Yalnızca izin verilen çalmaların zamanını saklar; reddedilen
## bir deneme önceki zamanı (ve dolayısıyla bekleme penceresini) uzatmaz.

var _last_ms: Dictionary[String, int] = {}


## `sound` bu anda çalınabilir mi? İzin verilirse zamanı kaydeder.
func allow(sound: String, now_ms: int, min_gap_ms: int) -> bool:
	if sound.is_empty():
		return false
	var gap: int = maxi(min_gap_ms, 0)
	if _last_ms.has(sound) and now_ms - _last_ms[sound] < gap:
		return false
	_last_ms[sound] = now_ms
	return true


func last_time(sound: String) -> int:
	return int(_last_ms.get(sound, 0))


func reset() -> void:
	_last_ms.clear()
