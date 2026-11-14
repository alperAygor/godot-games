class_name ModeStore
extends RefCounted
## Mod kayıtları (skorlar, deneme hakları, hikayede ulaşılan en ileri gün). Saf veri: `data` bir sözlüğün KENDİSİDİR
## (oyunda SaveManager.data["modes"]); değişiklikler doğrudan oraya yazılır. Hikaye kaydından (career) bağımsızdır:
## yeni oyun skorları ve açılmış modları silmez.
## Yapı: {"max_day": n, "daily": {"YYYY-MM-DD": {"attempts": n, "bonus": n, "best": n}}, "endless": {"best": n, "runs": n}}

var data: Dictionary
var _cfg: Dictionary


func _init(store: Dictionary, config: Dictionary = {}) -> void:
	data = store
	_cfg = config if not config.is_empty() else JsonIO.read_dict("res://data/modes.json")


# --- Açılma ----------------------------------------------------------------------

## Hikayede `day` gününün sabahına ulaşıldı (en ileri gün hatırlanır).
func note_day_reached(day: int) -> void:
	data["max_day"] = maxi(int(data.get("max_day", 0)), day)


func max_day() -> int:
	return int(data.get("max_day", 0))


## `kind` (daily|endless) açık mı? Hikayede unlock_after_day günü GEÇİLMİŞ olmalı (sonraki günün sabahına ulaşılmış).
func is_unlocked(kind: String) -> bool:
	return max_day() > int(_cfg.get(kind, {}).get("unlock_after_day", 9999))


# --- Günün Kuru -------------------------------------------------------------------

func _day(date: String) -> Dictionary:
	if not data.has("daily"):
		data["daily"] = {}
	var daily: Dictionary = data["daily"]
	if not daily.has(date):
		daily[date] = {"attempts": 0, "bonus": 0, "best": -1}
	return daily[date]


## Okuma için: kayıt yoksa oluşturmadan varsayılanı verir.
func _peek(date: String) -> Dictionary:
	return (data.get("daily", {}) as Dictionary).get(date, {"attempts": 0, "bonus": 0, "best": -1})


## O tarih için kalan resmi deneme sayısı (varsayılan 1 + reklamla kazanılan).
func official_attempts_left(date: String) -> int:
	var entry := _peek(date)
	return maxi(0, int(_cfg["daily"]["official_attempts"]) + int(entry["bonus"]) - int(entry["attempts"]))


## Oyun başlarken çağrılır: resmi deneme varsa harcar ve true döner; yoksa puansız alıştırmadır (false).
func start_daily_attempt(date: String) -> bool:
	if official_attempts_left(date) <= 0:
		return false
	var entry := _day(date)
	entry["attempts"] = int(entry["attempts"]) + 1
	return true


## O tarihe reklamla kazanılmış ek deneme sayısı (günde en çok 1 teklif edilir).
func bonus_granted(date: String) -> int:
	return int(_peek(date)["bonus"])


## `daily_retry` ödüllü reklamı: o tarihe +1 resmi deneme.
func grant_bonus_attempt(date: String) -> void:
	var entry := _day(date)
	entry["bonus"] = int(entry["bonus"]) + 1


## Resmi denemenin puanını kaydeder. Dönen: yeni en iyi mi.
func record_daily(date: String, score: int) -> bool:
	var entry := _day(date)
	var improved := score > int(entry["best"])
	if improved:
		entry["best"] = score
	_prune()
	return improved


## O tarihin en iyi puanı (hiç resmi deneme yoksa -1).
func best_daily(date: String) -> int:
	return int(_peek(date)["best"])


func _prune() -> void:
	var daily: Dictionary = data.get("daily", {})
	var keep := int(_cfg["daily"].get("keep_dates", 60))
	if daily.size() <= keep:
		return
	var dates := daily.keys()
	dates.sort()
	for date: Variant in dates.slice(0, dates.size() - keep):
		daily.erase(date)


# --- Sonsuz -------------------------------------------------------------------------

func endless_best() -> int:
	return int((data.get("endless", {}) as Dictionary).get("best", 0))


## Koşu bitti. Dönen: yeni rekor mu.
func record_endless(score: int) -> bool:
	if not data.has("endless"):
		data["endless"] = {"best": 0, "runs": 0}
	var entry: Dictionary = data["endless"]
	entry["runs"] = int(entry["runs"]) + 1
	var improved := score > int(entry["best"])
	if improved:
		entry["best"] = score
	return improved
