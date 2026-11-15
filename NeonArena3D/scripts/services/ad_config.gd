class_name AdConfig
extends RefCounted
## `data/ads.json` okuyucu + doğrulayıcı. Tüm reklam sayıları BURADAN (veri) gelir; koda gömülmez.
## Bozuk/eksik/yanlış tipli alan -> güvenli varsayılan (en kısıtlayıcı yöne).

const PATH: String = "res://data/ads.json"
const UNLIMITED: int = 999999

## ads.json okunamazsa kullanılan yedek (dosyadakiyle aynı değerler; testle karşılaştırılır).
const DEFAULTS: Dictionary = {
	"placements": {
		"REVIVE": {"per_run": 1, "per_session": 999},
		"DOUBLE_CORES": {"per_run": 1, "per_session": 999},
		"REROLL": {"per_run": 2, "per_session": 999},
		"DAILY_BONUS": {"per_day": 1},
	},
	"interstitial": {
		"enabled": true, "free_runs": 3, "min_seconds": 180, "every_n_deaths": 2,
		"block_after_rewarded": true, "moments": ["run_end"],
	},
	"settings": {"show_start_timeout_seconds": 3.0, "max_ad_seconds": 180.0},
}


static func load_file(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("AdConfig: %s yok, varsayılanlar kullanılıyor" % path)
		return DEFAULTS.duplicate(true)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_warning("AdConfig: %s okunamadı, varsayılanlar kullanılıyor" % path)
		return DEFAULTS.duplicate(true)
	return (parsed as Dictionary).duplicate(true)


static func _count(value: Variant, fallback: int) -> int:
	if typeof(value) == TYPE_INT:
		return clampi(int(value), 0, UNLIMITED)
	if typeof(value) == TYPE_FLOAT and is_finite(float(value)):
		return clampi(int(value), 0, UNLIMITED)
	return fallback


static func _seconds(value: Variant, fallback: float, lo: float, hi: float) -> float:
	if (typeof(value) == TYPE_INT) or (typeof(value) == TYPE_FLOAT and is_finite(float(value))):
		return clampf(float(value), lo, hi)
	return fallback


## Yerleşim limitleri: {per_run, per_session, per_day}. Dosyada olmayan alan = UNLIMITED; alan var ama bozuksa 1
## (kısıtlayıcı). Yerleşim dosyada hiç yoksa varsayılan blok; bilinmeyen yerleşim 1/1/1.
static func limits(config: Dictionary, placement_key: String) -> Dictionary:
	var fallback: Dictionary = (DEFAULTS["placements"] as Dictionary).get(placement_key, {"per_run": 1, "per_session": 1, "per_day": 1})
	var placements: Variant = config.get("placements")
	var configured: Variant = (placements as Dictionary).get(placement_key) if placements is Dictionary else null
	var source: Dictionary = (configured as Dictionary) if configured is Dictionary else fallback
	var out: Dictionary = {}
	for field: String in ["per_run", "per_session", "per_day"]:
		out[field] = _count(source[field], 1) if source.has(field) else UNLIMITED
	return out


## Pacing bloğu (AdPacing girdisi) — her alan doğrulanmış.
static func pacing(config: Dictionary) -> Dictionary:
	var d: Dictionary = DEFAULTS["interstitial"]
	var raw: Dictionary = (config.get("interstitial") as Dictionary) if config.get("interstitial") is Dictionary else {}
	var moments: Array[String] = []
	var raw_moments: Variant = raw.get("moments", d["moments"])
	if raw_moments is Array:
		for m: Variant in raw_moments as Array:
			if typeof(m) == TYPE_STRING:
				moments.append(String(m))
	else:
		for m: String in d["moments"]:
			moments.append(m)
	return {
		"enabled": bool(raw["enabled"]) if typeof(raw.get("enabled")) == TYPE_BOOL else bool(d["enabled"]),
		"free_runs": _count(raw.get("free_runs"), int(d["free_runs"])),
		"min_seconds": _count(raw.get("min_seconds"), int(d["min_seconds"])),
		"every_n_deaths": maxi(1, _count(raw.get("every_n_deaths"), int(d["every_n_deaths"]))),
		"block_after_rewarded": bool(raw["block_after_rewarded"]) if typeof(raw.get("block_after_rewarded")) == TYPE_BOOL else bool(d["block_after_rewarded"]),
		"moments": moments,
	}


## Gösterim istendikten sonra reklam bu sürede ekrana gelmezse akış reklamsız sürer.
static func show_timeout(config: Dictionary) -> float:
	var s: Dictionary = (config.get("settings") as Dictionary) if config.get("settings") is Dictionary else {}
	return _seconds(s.get("show_start_timeout_seconds"), 3.0, 0.5, 30.0)


## Ekrandaki reklam bu sürede bitmezse (SDK takıldı) akış serbest bırakılır.
static func max_ad_seconds(config: Dictionary) -> float:
	var s: Dictionary = (config.get("settings") as Dictionary) if config.get("settings") is Dictionary else {}
	return _seconds(s.get("max_ad_seconds"), 180.0, 5.0, 600.0)
