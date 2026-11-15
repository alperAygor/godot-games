class_name ConsentFlow
extends RefCounted
## Onay akışı kararları (saf, testli). Tek onay deneyimi:
##  - REGIME_FORM   : UMP (Google'ın onay formu) bu kullanıcı için geçerli (AB/EEA, UK ...). Yalnızca UMP formu çıkar; oyun kendi penceresini göstermez.
##  - REGIME_NOTICE : UMP gerekmiyor (diğer bölgeler, ya da UMP yanıt vermedi). Kısa, dürüst bir bilgi penceresi bir kez gösterilir;
##                    "kişiselleştirilmiş reklam" tercihi burada sorulur.
##  - REGIME_NONE   : bu sürümde reklam SDK'sı yok (taban sağlayıcı / yapılandırma hatası): sorulacak bir şey yok.
##  - REGIME_UNKNOWN: onay adımı henüz bitmedi.
## Reklam SDK'sı (başlatma dahil) ancak onay çözülünce başlar: FORM'da UMP bitince, NOTICE'te bilgi penceresi yanıtlanınca.

const REGIME_UNKNOWN := "unknown"
const REGIME_FORM := "form"
const REGIME_NOTICE := "notice"
const REGIME_NONE := "none"


## UMP durum metninden (UserConsent.to_status_string) rejim. REQUIRED/OBTAINED = UMP bu kullanıcıya uygulanıyor.
## NOT_REQUIRED ve bilinmeyen/hata = bilgi penceresi (UMP bölgeyi bilemediyse dürüst varsayılan).
static func regime_for_status(status: String) -> String:
	if status == "REQUIRED" or status == "OBTAINED":
		return REGIME_FORM
	return REGIME_NOTICE


## Uygulamanın kendi bilgi penceresi gösterilmeli mi?
static func notice_needed(regime: String, already_asked: bool) -> bool:
	return regime == REGIME_NOTICE and not already_asked


## Reklam SDK'sı başlayabilir mi?
static func sdk_may_start(regime: String, notice_answered: bool) -> bool:
	if regime == REGIME_FORM:
		return true
	return regime == REGIME_NOTICE and notice_answered


## SDK'ya uygulanacak kişiselleştirme: FORM rejiminde karar UMP'nindir (oyun üzerine yazmaz); NOTICE'te oyuncunun seçimi.
static func personalization_for(regime: String, user_choice: bool) -> bool:
	return true if regime == REGIME_FORM else user_choice
