class_name AdPacing
extends RefCounted
## Geçiş reklamı (interstitial) kararı — SAF fonksiyon: sahne, saat, dosya, autoload YOK; her girdi `Context`'te.
## Neden ayrı: oyuncuyu bezdirme sınırı en hassas ürün kararıdır; tablo testiyle sabitlenir (tests/unit/test_ad_pacing.gd).
## Kurallar `data/ads.json` -> "interstitial" bloğundan gelir (`AdConfig.pacing()` ile doğrulanmış), kodda sabit sayı yok:
##   free_runs            ilk N koşuda asla (biten koşu sayısı N veya daha azsa yok; N+1. koşudan itibaren olabilir)
##   min_seconds          son geçişten en az bu kadar sn (180 -> 179 yok, 180 var); hiç gösterilmediyse sorun değil
##   every_n_deaths       son geçişten bu yana en az bu kadar ölüm (2 -> "en fazla her 2. ölümde")
##   block_after_rewarded bu koşuda ödüllü reklam izlendiyse (revive / çift çekirdek / reroll) geçiş yok
##   moments              yalnız bu anlarda ("run_end"); oyun sırasında/kart/boss anında asla
##   enabled              false -> hiç
## "Reklamları kaldır" alındıysa geçiş HİÇBİR koşulda yok; ödüllü yerleşimler bundan etkilenmez ve pacing'e tabi değildir.
## Saat geri alınırsa (şimdi < son geçiş) karar "yok"tur (kısıtlayıcı yön).

const REASON_OK: String = ""
const REASON_ADS_REMOVED: String = "ads_removed"
const REASON_DISABLED: String = "disabled"
const REASON_MOMENT: String = "bad_moment"
const REASON_REWARDED: String = "rewarded_just_watched"
const REASON_FREE_RUNS: String = "free_runs"
const REASON_DEATHS: String = "death_gap"
const REASON_CLOCK: String = "clock_rollback"
const REASON_TOO_SOON: String = "too_soon"


## Karar girdileri. Tüm alanların güvenli varsayılanı "gösterme" yönündedir.
class Context extends RefCounted:
	var placement: int = AdPlacement.Id.INTERSTITIAL
	## Reklamın istendiği an ("run_end" = koşu bitti ekranı). Oyun içi anlar reddedilir.
	var moment: String = "run_end"
	## Biten koşu sayısı; İÇİNDE şimdi biten koşu VARDIR (Settings.record_run sonrası değer).
	var runs_completed: int = 0
	## Son geçişten (veya oturum başından) bu yana ölüm sayısı; şimdiki ölüm dahildir.
	var deaths_since_last: int = 0
	var now_unix: int = 0
	## Son geçişin Unix zamanı; 0 = hiç gösterilmedi.
	var last_interstitial_unix: int = 0
	var rewarded_just_watched: bool = false
	var ads_removed: bool = false


## Boş string = göster; aksi halde nedeni (REASON_*). Ödüllü yerleşimler pacing'e tabi değildir (her zaman REASON_OK).
static func evaluate(ctx: Context, pacing: Dictionary) -> String:
	if not AdPlacement.is_interstitial(ctx.placement):
		return REASON_OK
	if ctx.ads_removed:
		return REASON_ADS_REMOVED
	if not bool(pacing.get("enabled", true)):
		return REASON_DISABLED
	if not (pacing.get("moments", []) as Array).has(ctx.moment):
		return REASON_MOMENT
	if ctx.rewarded_just_watched and bool(pacing.get("block_after_rewarded", true)):
		return REASON_REWARDED
	if ctx.runs_completed <= int(pacing.get("free_runs", 3)):
		return REASON_FREE_RUNS
	if ctx.deaths_since_last < maxi(1, int(pacing.get("every_n_deaths", 2))):
		return REASON_DEATHS
	if ctx.last_interstitial_unix > 0:
		if ctx.now_unix < ctx.last_interstitial_unix:
			return REASON_CLOCK
		if ctx.now_unix - ctx.last_interstitial_unix < int(pacing.get("min_seconds", 180)):
			return REASON_TOO_SOON
	return REASON_OK


static func should_show(ctx: Context, pacing: Dictionary) -> bool:
	return evaluate(ctx, pacing) == REASON_OK
