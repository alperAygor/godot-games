class_name AdPacing
extends RefCounted

## Reklam politikası kararları — SAF fonksiyonlar, sahne/saat/dosya yok (zaman dışarıdan verilir).
## Neden ayrı: oyuncuyu bezdirme sınırı en hassas ürün kararıdır; testle sabitlenir.
## Değerlerin kaynağı `data/ads.json` (`interstitial`, `banner`, `quiet` blokları); buradaki sabitler
## yalnız dosya okunamazsa yedektir.
##
## Priz kuralları (tasarım belgesi):
##  * İlk `quiet.levels` (3) seviyede reklam, mağaza ve açılır pencere YOK (`is_quiet`).
##  * Geçiş reklamı YALNIZ seviye geçişinde: tamamlanan seviye >= `first_after_level` (5), her reklamdan
##    sonra `gap_cycle` (2, 3, 2, 3 ...) seviye beklenir, iki reklam arası en az `min_seconds_between`
##    (90) sn, o geçişte ödüllü reklam izlendiyse yok, "reklamları kaldır" varsa asla.
##    Aralık seçimi BELİRLENİMCİDİR (rastgele değil): n. reklamdan (n >= 1) sonraki bekleme
##    `gap_cycle[(n - 1) % uzunluk]`; yani reklamlar 5, 7, 10, 12, 15, 17 ... seviyelerinde gelir.
##  * Banner YALNIZ `banner.screens` listesindeki ekranlarda (mahalle, koleksiyon); oyun ekranında asla.

const DEFAULT_QUIET_LEVELS: int = 3
const DEFAULT_FIRST_AFTER_LEVEL: int = 5
const DEFAULT_GAP_CYCLE: Array[int] = [2, 3]
const DEFAULT_MIN_SECONDS: float = 90.0
const DEFAULT_BANNER_SCREENS: Array[String] = ["neighbourhood", "collection"]


## Sessiz dönem: `level` oynanmakta olan (ya da az önce bitirilen) seviye numarasıdır.
static func is_quiet(level: int, quiet: Dictionary) -> bool:
	return level <= ProgressData.to_count(quiet.get("levels"), DEFAULT_QUIET_LEVELS)


## `shown_count`. geçiş reklamından sonra beklenecek seviye sayısı (en az 1). Hiç reklam
## gösterilmediyse (0) ilk aralık döner; ilk reklamın zamanını `first_after_level` belirler.
static func gap_after(shown_count: int, pacing: Dictionary) -> int:
	var cycle: Array[int] = _gap_cycle(pacing)
	return cycle[maxi(shown_count - 1, 0) % cycle.size()]


## Geçiş reklamı gösterilsin mi?
##  * `completed_level`: az önce bitirilen seviye,
##  * `levels_since`: son geçiş reklamından beri tamamlanan seviye sayısı (bu seviye dahil),
##  * `shown_count`: şimdiye dek gösterilen geçiş reklamı sayısı,
##  * `last_time` / `now`: unix saniye; `last_time <= 0` hiç gösterilmedi demektir.
static func should_show(completed_level: int, ads_removed: bool, rewarded_in_transition: bool,
		levels_since: int, shown_count: int, last_time: float, now: float,
		pacing: Dictionary, quiet: Dictionary = {}) -> bool:
	if ads_removed or rewarded_in_transition:
		return false
	if is_quiet(completed_level, quiet):
		return false
	if completed_level < ProgressData.to_count(pacing.get("first_after_level"), DEFAULT_FIRST_AFTER_LEVEL):
		return false
	if levels_since < gap_after(shown_count, pacing):
		return false
	var min_seconds: float = _to_seconds(pacing.get("min_seconds_between"), DEFAULT_MIN_SECONDS)
	return last_time <= 0.0 or now - last_time >= min_seconds


## Banner `screen_id` ekranında görünebilir mi (oyun ekranı listede olmadığından asla).
static func banner_allowed(screen_id: StringName, ads_removed: bool, quiet_now: bool,
		banner: Dictionary) -> bool:
	if ads_removed or quiet_now:
		return false
	var screens: Variant = banner.get("screens")
	var list: Array[String] = DEFAULT_BANNER_SCREENS
	if screens is Array:
		list = []
		for entry: Variant in screens as Array:
			if entry is String:
				list.append(entry as String)
	return list.has(String(screen_id))


static func _gap_cycle(pacing: Dictionary) -> Array[int]:
	var cycle: Array[int] = []
	var raw: Variant = pacing.get("gap_cycle")
	if raw is Array:
		for entry: Variant in raw as Array:
			cycle.append(maxi(ProgressData.to_count(entry, 1), 1))
	return cycle if not cycle.is_empty() else DEFAULT_GAP_CYCLE


static func _to_seconds(value: Variant, fallback: float) -> float:
	if value is int or value is float:
		var number: float = float(value)
		if not is_nan(number) and not is_inf(number) and number >= 0.0:
			return number
	return fallback
