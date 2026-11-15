class_name SoundGate
extends RefCounted

## Hızlı oyunda ses kapısı (saf; saat dışarıdan verilir). Neden: AudioService'te 6 oynatıcılık döngü
## var; art arda onlarca olay gelince sesler "makineli tüfek" gibi tekrarlanıyor ve havuz dolunca
## çalan ses yarıda kesiliyordu. Kapı: aynı ses çok yakın tekrarlanırsa düşürülür, kısa sürede tekrar
## ederse perdesi küçük adımlarla yükselir ve hafifçe kısılır; toplam ses sayısı
## pencere başına sınırlıdır (havuz hiç taşmaz).

const MIN_GAP_MSEC: int = 45
const STREAK_WINDOW_MSEC: int = 260
const PITCH_STEP: float = 0.035
const MAX_STEPS: int = 4
const DB_STEP: float = -1.5
const WINDOW_MSEC: int = 150
const MAX_PER_WINDOW: int = 5
## Müzikal/tekil sesler perde adımı almaz (nota zinciri bozulmasın), yalnız sınırlanır.
const NO_STEP: Array[String] = ["note", "win", "lose", "coin", "level_start"]

var _last: Dictionary[String, int] = {}
var _streak: Dictionary[String, int] = {}
var _recent: Array[int] = []


## Kabul edilirse (perde çarpanı, dB farkı); düşürülürse Vector2.ZERO.
func admit(sound_name: String, now_msec: int) -> Vector2:
	while not _recent.is_empty() and now_msec - _recent[0] >= WINDOW_MSEC:
		_recent.pop_front()
	var last: int = _last.get(sound_name, -100000)
	if now_msec - last < MIN_GAP_MSEC or _recent.size() >= MAX_PER_WINDOW:
		return Vector2.ZERO
	var steps: int = 0
	if now_msec - last < STREAK_WINDOW_MSEC and not NO_STEP.has(sound_name):
		steps = mini(_streak.get(sound_name, 0) + 1, MAX_STEPS)
	_streak[sound_name] = steps
	_last[sound_name] = now_msec
	_recent.append(now_msec)
	return Vector2(1.0 + PITCH_STEP * float(steps), DB_STEP * float(steps))


func reset() -> void:
	_last.clear()
	_streak.clear()
	_recent.clear()
