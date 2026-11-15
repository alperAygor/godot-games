class_name TimeScale
extends RefCounted
## Oyun hızının TEK sahibi (saf mantık; `Fx` autoload'ı sonucu `Engine.time_scale`e yazar).
## Neden: eskiden vuruş donması "o anki hızı hatırla, bitince geri yaz" yapıyordu; ölüm yavaş çekimi (0.3) sırasında
## başlayan bir donma, yavaş çekim 1.0'a dönüp bittikten SONRA 0.3'ü geri yazar ve ölüm ekranı sonraki koşuya dek
## yavaş kalırdı. Burada her katman kendi değerini tutar; etkin hız her zaman katmanlardan HESAPLANIR, geri yazılan
## eski değer yoktur. Katmanlar:
##   base      araçların istediği temel hız (scene_probe 3x); oyuncu için 1.0
##   override  mutlak yavaş çekim (ölüm 0.3); <0 = yok. Temel hızı yok sayar (eski davranışla aynı)
##   hit       vuruş donması çarpanı (1.0 = yok); etkin hız = (override ya da base) * hit
## Her başlatma bir bilet döndürür; yalnız güncel bilet katmanı kapatabilir (eski/yarışan bitişler etkisiz).

var base := 1.0
var override := -1.0
var hit := 1.0
var _hit_ticket := 0
var _override_ticket := 0


func current() -> float:
	return (override if override >= 0.0 else base) * hit


func hit_active() -> bool:
	return hit < 1.0


func begin_hit(slow: float) -> int:
	## Vuruş donması zaten sürüyorsa -1 (yeni donma eklenmez: eski davranış).
	if hit_active():
		return -1
	hit = clampf(slow, 0.0, 1.0)
	_hit_ticket += 1
	return _hit_ticket


func end_hit(ticket: int) -> void:
	if ticket == _hit_ticket and ticket > 0:
		hit = 1.0


func begin_override(scale: float) -> int:
	override = maxf(scale, 0.0)
	_override_ticket += 1
	return _override_ticket


func end_override(ticket: int) -> void:
	if ticket == _override_ticket and ticket > 0:
		override = -1.0


func set_base(scale: float) -> void:
	base = maxf(scale, 0.0)


## Geçici katmanları (donma, yavaş çekim) kapatır ve bekleyen bitişleri geçersiz kılar: duraklatma, devam, kart ekranı,
## reklam, yeni koşu. Temel hız (araç) korunur.
func settle() -> void:
	hit = 1.0
	override = -1.0
	_hit_ticket += 1
	_override_ticket += 1
