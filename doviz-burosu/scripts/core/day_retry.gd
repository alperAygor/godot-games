class_name DayRetry
extends RefCounted
## "Günü tekrar oyna" kuralı (O8 kararı, T-B1; saf, testli). Kovulan/oyunu biten oyuncu ASLA çıkmaza düşmez ve ilerleme ASLA
## reklama bağlı değildir:
## - Her hikaye günü için `free_per_day` (1) ücretsiz tekrar: günün sabah anlık görüntüsüne bedelsiz döner (hikaye durumu aynı).
## - Ücretsiz hak bittiyse: ya oyun içi bedel (kurgusal PL; dönülen sabahın nakdinden düşer, nakdi `cash_floor_pl` altına indirmez)
##   ya da reklam hazırsa ödüllü reklamla bedelsiz tekrar. Reklam yoksa bedelli yol HER ZAMAN vardır.
## - `no_ads` sahibi (no_ads_free) reklam izlemeden bedelsiz tekrar eder.
## - "Yeni oyun" her zaman vardır ama tek çıkış değildir.
## Sayılar data/ads.json `free_retry` içinde (Monetization.retry_day_options/take_free_retry sözleşmesiyle aynı blok).
## Bu sınıf yalnızca teklifi hesaplar ve kariyere uygular; reklamı Monetization gösterir.

const KIND_FREE := "free"
const KIND_NO_ADS := "no_ads"
const KIND_PAID := "paid"
const KIND_AD := "ad"

## Simülasyonda (balance_sim, testler) tekrar edilebilen bitişler. "arrested" müfettiş riskinin bedelidir; oyuncuya yine
## sunulur (gün 14 sabahına dönmek davranışı değiştirebilir) ama denge botları onu sonuç sayar.
const SIM_RETRY_ON := ["fired", "evicted", "family_left"]


static func config() -> Dictionary:
	return JsonIO.read_shared("res://data/ads.json").get("free_retry", {}) as Dictionary


## Oyun içi bedelin tam fiyatı (kuruş); cost.kind "cash_pl" değilse 0.
static func price_minor(cfg: Dictionary) -> int:
	var cost: Dictionary = cfg.get("cost", {}) as Dictionary
	if str(cost.get("kind", "none")) != "cash_pl":
		return 0
	return Money.units(maxi(0, int(cost.get("value", 0))))


## Bedelli tekrarın dönülen sabahta bırakacağı en az nakit (kuruş).
static func floor_minor(cfg: Dictionary) -> int:
	return Money.units(maxi(0, int(cfg.get("cash_floor_pl", 0))))


## Bu günün tekrar teklifi. `owns_no_ads`: Monetization.owns_no_ads(). Dönen:
## {available, kind (free|no_ads|paid), free_left, used, price_minor, cost_minor, morning_cash_minor, cash_after_minor,
##  ad_useful (reklam bedeli siler mi: yalnız "paid" iken), day}
static func quote(career: Career, owns_no_ads: bool, cfg: Dictionary = {}) -> Dictionary:
	var c: Dictionary = cfg if not cfg.is_empty() else config()
	var used := career.retries_used()
	var free_left := maxi(0, int(c.get("free_per_day", 1)) - used)
	var morning_cash := int((career.morning_snapshot.get("household", {}) as Dictionary).get("cash_minor", career.household.cash_minor))
	var kind := KIND_PAID
	if free_left > 0:
		kind = KIND_FREE
	elif owns_no_ads and bool(c.get("no_ads_free", true)):
		kind = KIND_NO_ADS
	var price := price_minor(c)
	var cost := 0
	if kind == KIND_PAID:
		cost = mini(price, maxi(0, morning_cash - floor_minor(c)))
	return {
		"available": career.is_over() and not career.morning_snapshot.is_empty(),
		"kind": kind, "free_left": free_left, "used": used, "day": career.day,
		"price_minor": price, "cost_minor": cost, "morning_cash_minor": morning_cash,
		"cash_after_minor": morning_cash - cost, "ad_useful": kind == KIND_PAID and cost > 0,
	}


## Teklifi uygular: sabaha döner, hakkı sayar, bedeli (varsa) düşer. `via_ad`: ödüllü reklam izlendi (bedelsiz).
static func apply(career: Career, offer: Dictionary, via_ad := false) -> bool:
	if not bool(offer.get("available", false)):
		return false
	return career.retry_day(0 if via_ad else int(offer.get("cost_minor", 0)))


## Denge/test yardımcısı: botu `days` gün oynatır; tekrar edilebilen bitişte (SIM_RETRY_ON) en kötü durumu varsayar —
## reklam YOK, no_ads YOK: önce ücretsiz hak, sonra bedelli tekrar. Gün başına en çok `max_per_day` tekrar.
## Dönen: {reports (yalnız tamamlanan/son deneme günleri), attempts (tüm denemeler), retries, retry_cost_minor}
static func play_career(bot: ClerkBot, career: Career, days: int, max_per_day := 3, cfg: Dictionary = {}) -> Dictionary:
	var reports: Array[Dictionary] = []
	var attempts: Array[Dictionary] = []
	var retries := 0
	var retry_cost := 0
	var guard := 0
	while reports.size() < days and guard < days * (max_per_day + 2):
		guard += 1
		if career.is_over():
			if not (career.game_over in SIM_RETRY_ON) or career.retries_used() >= max_per_day:
				break
			var offer := quote(career, false, cfg)
			if not apply(career, offer):
				break
			retries += 1
			retry_cost += int(offer["cost_minor"])
			reports.pop_back()  # başarısız deneme yerine tekrarın sonucu yazılır
		var played := bot.play_career(career, 1)
		if played.is_empty():
			break
		attempts.append(played[0])
		reports.append(played[0])
	return {"reports": reports, "attempts": attempts, "retries": retries, "retry_cost_minor": retry_cost}
