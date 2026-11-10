class_name LevelScoring
extends RefCounted

## Bolum sonu yildiz/puan hesabi. Esikler oyun kuralidir; taban puan data/balance.json'da.
##
## PROJECT_SPEC bolum 4-5:
##  3 yildiz: temiz (0 kisa devre) + par sure icinde
##  2 yildiz: <=2 kisa devre + 1.6x par sure
##  1 yildiz: bolum tamamlandi
## Tepe asiri yuk yildizi degil, puani cezalandirir.

const TWO_STAR_TIME_FACTOR: float = 1.6
const TWO_STAR_MAX_SHORTS: int = 2
const SCORE_BASE: int = 1000
const SCORE_PER_SECOND_LEFT: int = 10
const SCORE_SHORT_PENALTY: int = 50
const SCORE_PEAK_PENALTY: int = 200


@warning_ignore("unused_parameter")
static func stars(elapsed: float, par_seconds: float, shorts: int,
		peak_overload: float) -> int:
	var time: float = maxf(0.0, elapsed)
	var par: float = maxf(0.0, par_seconds)
	var short_count: int = maxi(0, shorts)
	if short_count == 0 and time <= par:
		return 3
	if short_count <= TWO_STAR_MAX_SHORTS and time <= par * TWO_STAR_TIME_FACTOR:
		return 2
	return 1


## {"stars": int, "score": int, "time_bonus": int, "elapsed": float, "shorts": int, "peak": float}
static func compute(elapsed: float, par_seconds: float, shorts: int,
		peak_overload: float) -> Dictionary:
	var time: float = maxf(0.0, elapsed)
	var par: float = maxf(0.0, par_seconds)
	var short_count: int = maxi(0, shorts)
	var peak: float = clampf(peak_overload, 0.0, 1.0)
	var earned: int = stars(time, par, short_count, peak)
	var seconds_left: float = maxf(0.0, par - time)
	var time_bonus: int = int(roundf(seconds_left)) * SCORE_PER_SECOND_LEFT
	var peak_penalty: int = int(roundf(peak * float(SCORE_PEAK_PENALTY)))
	var score: int = SCORE_BASE + time_bonus - short_count * SCORE_SHORT_PENALTY - peak_penalty
	return {
		"stars": earned,
		"score": maxi(0, score),
		"time_bonus": time_bonus,
		"elapsed": time,
		"shorts": short_count,
		"peak": peak,
	}
