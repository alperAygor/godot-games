class_name ConsentRules
extends RefCounted

## UMP (Google User Messaging Platform) durum kuralları — SAF fonksiyonlar.
## Sayılar Poing eklentisinin `ConsentInformation.ConsentStatus` / `PrivacyOptionsRequirementStatus`
## enum'larıdır (addons/admob/gdscript/src/ump/api/ConsentInformation.gd: UNKNOWN, NOT_REQUIRED,
## REQUIRED, OBTAINED = 0..3; UNKNOWN, NOT_REQUIRED, REQUIRED = 0..2). Eklenti yokken test edilebilsin diye
## burada yinelenir; köprü çalışma anında eklentinin gerçek sabit haritasını okuyup bunlara yedekler.
## Eklentinin `canRequestAds()` karşılığı yoktur (API'de bulunamadı): kural Google'ın tanımıdır —
## onay GEREKMİYOR ya da ALINDI ise reklam istenebilir; BİLİNMİYOR ya da GEREKLİ (form kapatıldı/yüklenemedi)
## ise istenemez.

const STATUS_UNKNOWN: int = 0
const STATUS_NOT_REQUIRED: int = 1
const STATUS_REQUIRED: int = 2
const STATUS_OBTAINED: int = 3

const PRIVACY_UNKNOWN: int = 0
const PRIVACY_NOT_REQUIRED: int = 1
const PRIVACY_REQUIRED: int = 2


## Reklam isteği/başlatma yalnız bu durumlarda serbesttir (AB/Birleşik Krallık: onay alınmadan asla).
static func can_request_ads(consent_status: int) -> bool:
	return consent_status == STATUS_NOT_REQUIRED or consent_status == STATUS_OBTAINED


## Onay formu yalnız durum REQUIRED iken kullanıcıya gösterilir.
static func should_show_form(consent_status: int, form_available: bool) -> bool:
	return form_available and consent_status == STATUS_REQUIRED


## Ayarlardaki "Gizlilik seçenekleri" girişi yalnız UMP bunu zorunlu kılıyorsa görünür.
static func privacy_options_visible(requirement_status: int) -> bool:
	return requirement_status == PRIVACY_REQUIRED
