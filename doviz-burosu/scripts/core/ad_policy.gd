class_name AdPolicy
extends RefCounted
## Reklam kararları (saf, testli): geçiş reklamı ne zaman gösterilir, ödüllü reklam teklifi sınırları.
## Ayarlar data/ads.json. Geçiş reklamı yalnızca "oyun birimi" aralarında sorulur (akşam → sabah, mod sonucu); vardiya ortasında ASLA.

## Engelleme nedenleri (kimlikler testlerde ve analitikte kullanılır).
const BLOCK_NO_ADS := "no_ads_owned"
const BLOCK_STORY_DAY := "story_day_too_early"
const BLOCK_UNITS := "too_soon_since_last_interstitial"
const BLOCK_ANY_AD := "too_soon_since_any_ad"
const BLOCK_SESSION_TIME := "session_too_short"
const BLOCK_FIRST_SESSION := "first_session"


## `state`: {owns_no_ads, story_day (ulaşılan en ileri gün), units, last_interstitial_unit (hiç yoksa -1000000),
## seconds_since_any_ad, session_play_seconds, session_index}. Dönen: {"allowed": bool, "blocked_by": Array[String]}.
static func interstitial(state: Dictionary, config: Dictionary = {}) -> Dictionary:
	var cfg: Dictionary = config if not config.is_empty() else JsonIO.read_shared("res://data/ads.json").get("interstitial", {})
	var blocked: Array[String] = []
	if bool(state.get("owns_no_ads", false)):
		blocked.append(BLOCK_NO_ADS)
	if int(state.get("story_day", 0)) < int(cfg["min_story_day"]):
		blocked.append(BLOCK_STORY_DAY)
	if int(state.get("units", 0)) - int(state.get("last_interstitial_unit", -1000000)) < int(cfg["min_units_between"]):
		blocked.append(BLOCK_UNITS)
	if float(state.get("seconds_since_any_ad", 0.0)) < float(cfg["min_seconds_since_any_ad"]):
		blocked.append(BLOCK_ANY_AD)
	if float(state.get("session_play_seconds", 0.0)) < float(cfg["min_session_play_seconds"]):
		blocked.append(BLOCK_SESSION_TIME)
	if int(state.get("session_index", 0)) < int(cfg["min_session_index"]):
		blocked.append(BLOCK_FIRST_SESSION)
	return {"allowed": blocked.is_empty(), "blocked_by": blocked}


## Ödüllü reklam yeri bu kullanımda sınırı aştı mı? `used`: aynı kapsamda (gün/tarih/koşu) şimdiye dek kazanılan ödül sayısı.
static func rewarded_within_limit(placement: String, used: int, config: Dictionary = {}) -> bool:
	var cfg: Dictionary = config if not config.is_empty() else JsonIO.read_shared("res://data/ads.json").get("rewarded", {})
	var limit := int((cfg.get(placement, {}) as Dictionary).get("limit", 1))
	return limit <= 0 or used < limit


static func rewarded_config(placement: String) -> Dictionary:
	return JsonIO.read_shared("res://data/ads.json").get("rewarded", {}).get(placement, {})
