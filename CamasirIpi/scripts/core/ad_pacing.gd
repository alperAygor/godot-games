class_name AdPacing
extends RefCounted

## Geçiş reklamı (interstitial) sıklık kararı — SAF fonksiyon, saat dışarıdan verilir.
## Neden ayrı: oyuncuyu bezdirmeyen sıklık en hassas ürün kararı; testle sabitlenir.

## Kural: sonraki seviye `first_level`dan önce asla; son reklamdan beri 2-3 seviye geçmeli
## (hangisi olduğu seviye numarasına bağlı, böylece deterministik ve testlenebilir);
## son reklamdan en az `min_seconds_between` sn; az önce ödüllü reklam izlendiyse asla.
## `pacing` = balance.json'daki "interstitial" bloğu.
static func should_show(next_level: int, levels_since: int, now: float,
		last_interstitial: float, last_rewarded: float, pacing: Dictionary) -> bool:
	if next_level < ProgressData.to_count(pacing.get("first_level"), 4):
		return false
	if levels_since < levels_needed(next_level, pacing):
		return false
	var min_gap: float = float(ProgressData.to_count(pacing.get("min_seconds_between"), 90))
	# Hiç gösterilmediyse (0) süre koşulu aranmaz.
	if last_interstitial > 0.0 and now - last_interstitial < min_gap:
		return false
	var cooldown: float = float(ProgressData.to_count(pacing.get("rewarded_cooldown_seconds"), 120))
	if last_rewarded > 0.0 and now - last_rewarded < cooldown:
		return false
	return true


## 2 ile 3 arasında, seviye numarasına göre dönüşümlü.
static func levels_needed(next_level: int, pacing: Dictionary) -> int:
	var low: int = maxi(ProgressData.to_count(pacing.get("min_levels_between"), 2), 1)
	var high: int = maxi(ProgressData.to_count(pacing.get("max_levels_between"), 3), low)
	return low + (next_level % (high - low + 1))
