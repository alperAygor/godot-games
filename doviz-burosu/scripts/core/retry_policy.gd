class_name RetryPolicy
extends RefCounted
## "Günü tekrar oyna" (retry_day) yolları (saf, testli). İLKE: reklam gösterilemiyorsa oyuncunun ÜCRETSİZ bir yolu olmalıdır;
## ilerleme asla yalnızca ödüllü reklamın arkasında kalmaz (Play ödüllü reklam politikası: reklam isteğe bağlı olmalı).
## Ayarlar data/ads.json "free_retry". Ücretin NE olacağı tasarım kararıdır (docs/MONETIZATION.md "Bekleyen karar O8"; uygulama T-B1):
## burada yalnızca mekanizma ve işaretli varsayılan vardır. Bu sınıf ücreti UYGULAMAZ; yalnızca ne olduğunu söyler.

const WHEN_AD_UNAVAILABLE := "ad_unavailable"
const WHEN_ALWAYS := "always"

const REASON_NONE := ""
const REASON_AD_NOT_READY := "ad_not_ready"
const REASON_AD_FAILED := "ad_failed"
const REASON_ALWAYS := "always_available"
const REASON_DISABLED := "disabled"
const REASON_AD_OK := "ad_available"


## `ad_enabled`: ödüllü reklam şu an gösterilebilir. `ad_failed`: bu oturumda bu yer için reklam denendi ve ödül gelmedi
## (zaman aşımı, kapatma, yükleme hatası). Dönen: {"available": bool, "reason": String, "cost_kind": String, "cost_value": int, "decision_pending": bool}
static func free_option(ad_enabled: bool, ad_failed: bool, config: Dictionary = {}) -> Dictionary:
	var cfg: Dictionary = config if not config.is_empty() else JsonIO.read_shared("res://data/ads.json").get("free_retry", {})
	var cost: Dictionary = cfg.get("cost", {}) as Dictionary
	var result := {
		"available": false,
		"reason": REASON_DISABLED,
		"cost_kind": str(cost.get("kind", "none")),
		"cost_value": int(cost.get("value", 0)),
		"decision_pending": bool(cfg.get("decision_pending", true)),
	}
	if not bool(cfg.get("enabled", true)):
		return result
	if str(cfg.get("available_when", WHEN_AD_UNAVAILABLE)) == WHEN_ALWAYS:
		result["available"] = true
		result["reason"] = REASON_ALWAYS
	elif ad_failed:
		result["available"] = true
		result["reason"] = REASON_AD_FAILED
	elif not ad_enabled:
		result["available"] = true
		result["reason"] = REASON_AD_NOT_READY
	else:
		result["reason"] = REASON_AD_OK
	return result
