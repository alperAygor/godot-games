class_name AdFlow
extends RefCounted
## Reklam akışının OYUNCU tarafındaki saf kuralları ve sayıları (`data/ads_flow.json`). Sahne, autoload, saat YOK;
## testli (tests/unit/test_ad_flow.gd). Reklam kuralları (limit, pacing) `AdConfig`/`AdPacing`de; burası "ne zaman
## arayüz göster" ve "ne kadar ver" kararıdır.

const PATH := "res://data/ads_flow.json"
const MAX_BONUS := 100000

## Dosya okunamazsa / alan bozuksa en KISITLAYICI güvenli değerler (az ödül, geç teklif).
const DEFAULTS := {
	"min_completed_runs": 1, "revive_offer_seconds": 5.0, "daily_bonus_cores": 50,
	"double_cores_multiplier": 2, "reroll_grant": 1, "reroll_offer_at_or_below": 0,
}

var min_completed_runs := 1
var revive_offer_seconds := 5.0
var daily_bonus_cores := 50
var double_cores_multiplier := 2
var reroll_grant := 1
var reroll_offer_at_or_below := 0


static func load_file(path := PATH) -> AdFlow:
	var parsed: Variant = null
	if FileAccess.file_exists(path):
		parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_warning("AdFlow: %s okunamadı, varsayılanlar kullanılıyor" % path)
		parsed = {}
	return from_dict(parsed as Dictionary)


static func from_dict(d: Dictionary) -> AdFlow:
	var f := AdFlow.new()
	f.min_completed_runs = _int(d.get("min_completed_runs"), 1, 0, 1000)
	f.revive_offer_seconds = _num(d.get("revive_offer_seconds"), 5.0, 1.0, 30.0)
	f.daily_bonus_cores = _int(d.get("daily_bonus_cores"), 50, 0, MAX_BONUS)
	f.double_cores_multiplier = _int(d.get("double_cores_multiplier"), 2, 1, 10)
	f.reroll_grant = _int(d.get("reroll_grant"), 1, 1, 10)
	f.reroll_offer_at_or_below = _int(d.get("reroll_offer_at_or_below"), 0, 0, 100)
	return f


static func _int(v: Variant, fallback: int, lo: int, hi: int) -> int:
	if typeof(v) == TYPE_INT or (typeof(v) == TYPE_FLOAT and is_finite(float(v))):
		return clampi(int(v), lo, hi)
	return fallback


static func _num(v: Variant, fallback: float, lo: float, hi: float) -> float:
	if typeof(v) == TYPE_INT or (typeof(v) == TYPE_FLOAT and is_finite(float(v))):
		return clampf(float(v), lo, hi)
	return fallback


## Reklam arayüzü açık mı? `runs_done` = o koşu BAŞLARKEN biten koşu sayısı (ilk koşu temiz kalır).
func ads_unlocked(runs_done: int) -> bool:
	return runs_done >= min_completed_runs


## Çift çekirdekte EK verilecek miktar (mevcut kazanç kayda zaten işlenmiştir).
func double_bonus(earned: int) -> int:
	return maxi(0, earned) * (double_cores_multiplier - 1)


## Yenileme reklamı teklifi: kalan yenileme eşiğin altına/eşiğe inince.
func reroll_offer_wanted(rerolls: int) -> bool:
	return rerolls <= reroll_offer_at_or_below


## Geri sayım (gerçek süre; oyun hızından bağımsız beslenir). `tick` süre bitince true döner (bir kez).
class Countdown extends RefCounted:
	var total := 5.0
	var remaining := 5.0
	var expired := false

	func _init(seconds := 5.0) -> void:
		total = maxf(seconds, 0.01)
		remaining = total

	func tick(delta: float) -> bool:
		if expired:
			return false
		remaining = maxf(0.0, remaining - maxf(delta, 0.0))
		if remaining <= 0.0:
			expired = true
			return true
		return false

	func seconds_left() -> int:
		return int(ceil(remaining))

	func fraction() -> float:
		return clampf(remaining / total, 0.0, 1.0)
