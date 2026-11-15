class_name AdPacing
extends RefCounted

## Reklam sıklığı kararları — SAF fonksiyonlar, sahne/saat/dosya yok (saat parametre olarak gelir).
## Neden ayrı: oyuncuyu bezdirme sınırı en hassas ürün kararıdır; testle sabitlenir.
## Sayılar `data/ads.json` ("interstitial" ve "rewarded" blokları); burada yalnız yedek değerler var.
##
## Geçiş reklamı kuralı (sahibinin kararı 2026-11-15):
##  * `first_level` (4): reklamın ÖNÜNDE gelebileceği ilk seviye. Yani 1-3. seviyeler oynanırken reklam
##    yoktur; 3. seviye bitince 4'e geçerken ilk reklam gelir, sonra her `every_n` (3) seviyede bir:
##    3, 6, 9, 12... seviyelerin bitişinde.
##  * Yalnız seviye ARASINDA ve yalnız seviye İLK KEZ tamamlandığında (çözme ya da atlama). Eski bir
##    seviyeyi tekrar oynamak sırayı ilerletmez; "tekrar oyna, reklam al" döngüsü olmaz.
##  * "Reklamları kaldır" alındıysa asla.
##  * O seviyede ödüllü reklam izlendiyse (ipucu ya da atlama) o geçişte yok (`suppress_after_rewarded`).
##  * Son geçiş reklamından beri `min_gap_seconds` dolmadıysa yok. Reklam bu yüzden atlanırsa ertelenmez:
##    sıradaki reklam kendi sırasında gelir.

const DEFAULT_FIRST_LEVEL: int = 4
const DEFAULT_EVERY_N: int = 3
const DEFAULT_MIN_GAP_SECONDS: float = 60.0
const DEFAULT_BUTTONS_FROM_LEVEL: int = 4
## Hiç geçiş reklamı gösterilmediyse "çok uzun zaman önce".
const NEVER_SECONDS: float = 1.0e12


## `completed_number`: biten seviyenin sıra numarası (1'den). Yalnız sıra kararı; diğer koşullar `should_show`da.
static func is_due(completed_number: int, first_completion: bool, pacing: Dictionary) -> bool:
	if not first_completion or completed_number < 1:
		return false
	var next_number: int = completed_number + 1
	var first: int = maxi(ProgressData.to_count(pacing.get("first_level"), DEFAULT_FIRST_LEVEL), 1)
	var every: int = maxi(ProgressData.to_count(pacing.get("every_n"), DEFAULT_EVERY_N), 1)
	if next_number < first:
		return false
	return (next_number - first) % every == 0


## Son geçiş reklamından beri geçen süre (sn). Kayıt yoksa ya da saat geri alındıysa "yeterince uzun".
static func seconds_since(now_unix: float, last_unix: float) -> float:
	if last_unix <= 0.0 or now_unix < last_unix:
		return NEVER_SECONDS
	return now_unix - last_unix


static func should_show(completed_number: int, first_completion: bool, ads_removed: bool,
		rewarded_in_transition: bool, seconds_since_last: float, pacing: Dictionary) -> bool:
	if ads_removed:
		return false
	if not is_due(completed_number, first_completion, pacing):
		return false
	if rewarded_in_transition and bool(pacing.get("suppress_after_rewarded", true)):
		return false
	return seconds_since_last >= min_gap_seconds(pacing)


static func min_gap_seconds(pacing: Dictionary) -> float:
	var value: Variant = pacing.get("min_gap_seconds")
	if (value is int or value is float) and not is_nan(float(value)) and float(value) >= 0.0:
		return float(value)
	return DEFAULT_MIN_GAP_SECONDS


## İpucu / atlama düğmeleri bu seviyeden itibaren görünür (öğrenme seviyelerinde yok).
static func rewarded_buttons_visible(level_number: int, rewarded: Dictionary) -> bool:
	return level_number >= maxi(ProgressData.to_count(rewarded.get("buttons_from_level"),
		DEFAULT_BUTTONS_FROM_LEVEL), 1)
