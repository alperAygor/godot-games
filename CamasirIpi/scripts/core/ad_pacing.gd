class_name AdPacing
extends RefCounted

## Geçiş reklamı (interstitial) kararı — SAF fonksiyon, sahne/saat/dosya yok.
## Neden ayrı: oyuncuyu bezdirme sınırı en hassas ürün kararıdır; testle sabitlenir.
##
## Kural (kullanıcı kararı): 4. seviyeden itibaren HER seviye geçişinde gösterilir (ilk 3
## seviye reklamsızdır). Aralık/süre koşulu yoktur. İstisnalar:
##  * "Reklamları kaldır" satın alındıysa asla,
##  * oyuncu bu geçişte (kazanma sayfasında) ödüllü reklam izlediyse asla — izlediği reklamın
##    hemen ardından ikinci bir reklam göstermek cezalandırmak olur,
##  * oyun sırasında asla (çağıran yalnız "Devam" yolunda sorar).
## `pacing` = balance.json'daki "interstitial" bloğu.

const DEFAULT_FIRST_LEVEL: int = 4


static func should_show(next_level: int, ads_removed: bool, rewarded_in_transition: bool,
		pacing: Dictionary) -> bool:
	if ads_removed or rewarded_in_transition:
		return false
	return next_level >= ProgressData.to_count(pacing.get("first_level"), DEFAULT_FIRST_LEVEL)
