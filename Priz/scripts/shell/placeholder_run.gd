class_name PlaceholderRun
extends RefCounted

## YER TUTUCU oyun mantığı (saf, sahnesiz): N kez dokun -> kazan; "kaybet" düğmesi -> kaybet.
## Akışı (Boot -> Home -> Game -> sonuç sayfası, kayıt, jeton, reklam) denemek içindir.
## Gerçek oyun başlarken bu dosya + scripts/ui/game.gd içindeki yer tutucu kısım SİLİNİR,
## yerine oyunun kendi saf kural sınıfı gelir (aynı kalıp: RefCounted, sahnesiz, birim testli).

enum State { PLAYING, WON, LOST }

var target: int = 5
var taps: int = 0
var state: State = State.PLAYING


func _init(taps_to_win: int = 5) -> void:
	target = maxi(taps_to_win, 1)


## Dokunuş sayılır. Dönen: dokunuş işlendi mi (tur bitmişse false).
func tap() -> bool:
	if state != State.PLAYING:
		return false
	taps += 1
	if taps >= target:
		state = State.WON
	return true


func lose() -> void:
	if state == State.PLAYING:
		state = State.LOST


## Kayıpta devam (ödüllü reklam): tur kaldığı yerden sürer, ilerleme korunur.
func revive() -> bool:
	if state != State.LOST:
		return false
	state = State.PLAYING
	return true


func is_playing() -> bool:
	return state == State.PLAYING


func is_won() -> bool:
	return state == State.WON


func is_lost() -> bool:
	return state == State.LOST


func remaining() -> int:
	return maxi(target - taps, 0)
