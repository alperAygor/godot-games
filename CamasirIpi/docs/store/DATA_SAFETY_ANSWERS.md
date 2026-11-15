# Play Console beyanları — önerilen cevaplar (taslak)

Okuma tarihi: 2026-11-15. Bunlar **öneridir**; formu dolduran ve doğruluktan sorumlu olan **sahiptir** (Google, formun sorumluluğunun geliştiriciye ait olduğunu söyler: https://developers.google.com/admob/android/next-gen/privacy/play-data-disclosure). Hukuki tavsiye değildir.
Gerçek davranış değişirse (analitik, bildirim, hesap, başka SDK) bu cevaplar ve `PRIVACY_POLICY_DRAFT.md` birlikte güncellenir. Form, politikayla tutarlı olmalıdır (https://support.google.com/googleplay/android-developer/answer/10787469).
Kaynak türleri: **K** = resmi sayfa okundu; **Ç** = bizim çıkarımımız.

## A. Veri güvenliği formu (Data safety)

Tanımlar (K): "toplama" = veriyi cihazdan dışarı iletmek; "paylaşma" = üçüncü tarafa aktarmak; kullanıcı verisini sizin adınıza işleyen "hizmet sağlayıcıya" aktarım paylaşma sayılmaz. Üçüncü taraf SDK verisi forma dahildir. Kaynak: .../answer/10787469.

| Soru | Önerilen cevap | Gerekçe / kaynak |
|---|---|---|
| Uygulama kullanıcı verisi topluyor veya paylaşıyor mu? | **Evet** | Google Mobile Ads SDK otomatik veri toplar (K: https://developers.google.com/admob/android/next-gen/privacy/play-data-disclosure) |
| Toplanan tüm veri aktarımda şifreli mi? | **Evet** | Sayfa: SDK verisi TLS ile şifreli (K); bağlantı kontrolü HTTPS (`online_checker.gd` uç noktaları `https://...`) |
| Kullanıcıların veri silme talep etme yolu var mı? | **Hayır** (hesap yok; SDK verisi Google'dadır) — gizlilik politikasında reklam kimliği silme anlatılır. Formdaki seçenek metnini konsolda oku. | Ç; hesap silme politikası hesaba dayanır (https://support.google.com/googleplay/android-developer/answer/10144311) |
| Gizlilik politikası URL'si | `[POLICY URL]` (sahip barındırır) | K |

### Veri türleri (Google rehberinin dört türü → Play kategorileri; **eşleştirme ÇIKARIM**, konsoldaki "Learn more" tablosuyla doğrula)

| Google rehberindeki tür | Play veri türü (öneri) | Toplanıyor | Paylaşılıyor | Zorunlu/isteğe bağlı | Amaç |
|---|---|---|---|---|---|
| Android reklam kimliği, app set ID | **Device or other IDs** | Evet | Evet (reklam ağı = Google) | İsteğe bağlı (reklam kimliği kapatılabilir — K) | Reklam veya pazarlama; sahtecilik önleme/güvenlik; (analitik: Google rehberi "analitik" amacını da sayar) |
| IP adresi | Play'de ayrı "IP" türü yok; en yakın: **Device or other IDs** altında ya da "Approximate location" (**belirsiz — DOĞRULANAMADI**) | Evet | Evet | Zorunlu (ağ isteğinin parçası) | Reklam; sahtecilik önleme |
| Kullanıcı-ürün etkileşimleri (açılış, dokunma, video izleme) | **App activity → App interactions** | Evet | Evet | Zorunlu | Reklam; analitik; sahtecilik önleme |
| Tanılama bilgisi (açılış süresi, takılma, enerji) | **App info and performance → Diagnostics** (ve/veya Crash logs) | Evet | Evet | Zorunlu | Analitik; sahtecilik önleme |
| Satın alma geçmişi | **Toplanmaz**: Google Play faturalandırması ödeme verisini Google'da tutar, uygulama yalnız sahiplik durumunu yerelde saklar | Hayır | Hayır | — | Ç |
| Konum, kişisel bilgi (ad/e-posta/telefon), mesajlar, fotoğraf/ses, kişiler, takvim, finansal bilgi, sağlık, web gezinme | **Toplanmaz** | Hayır | Hayır | — | Uygulama bu izinleri istemiyor |
| Çevrimiçi kapı (gstatic/Cloudflare'a GET) | Ayrı veri türü beyan edilmez; IP zaten yukarıda. Bu istekler **hiçbir kimlik/çerez taşımaz** (`http_online_transport.gd`). | — | — | — | Ç |

Notlar:
1. **"Paylaşma"**: AdMob reklam sunucusu "hizmet sağlayıcı" mı yoksa üçüncü taraf mı? Google'ın kendi rehberi reklam amaçlı verileri "toplanır ve paylaşılır" diye anlatır → konservatif cevap **paylaşılıyor**. (Ç)
2. Rehber "son sürüm" içindir; SDK güncellenince sayfa yeniden okunup form güncellenir (K).
3. Bildirim eklentisi (yerel bildirim) ileride gelirse `POST_NOTIFICATIONS` izni ve ek beyan gerekebilir; bugün yok (`scripts/retention/notifier.gd` eklenti beklemede).

## B. Uygulama içeriği (App content) beyanları

| Beyan | Önerilen cevap | Kaynak/Not |
|---|---|---|
| **Gizlilik politikası** | URL'yi gir; uygulama içi bağlantı da ekle | K: https://support.google.com/googleplay/android-developer/answer/9859455 ; .../answer/10144311 |
| **Reklamlar** | **Evet, uygulama reklam içeriyor** (AdMob: interstitial + rewarded) | K: .../answer/9859455 |
| **Uygulama erişimi** | Tüm işlevler kısıtsız (giriş yok). Çevrimiçi kapı yalnız internet ister; kimlik bilgisi gerekmez | K (giriş maddesi); Ç |
| **Hedef kitle ve içerik** | **13 yaş ve üzeri gruplar** (13-15, 16-17, 18+). 5 yaş altı/6-8/9-12 **seçilmez.** Çocuk dostu görsel stili: ilan metni ve görsellerde çocuklara yönelik anlatım kullanılmaz. Play "çocuklara çekici" diye değerlendirirse Aileler politikası yükümlülükleri doğabilir (self-certified reklam SDK, kişiselleştirilmiş reklam yok, AAID gönderimi yok...) | K: https://support.google.com/googleplay/android-developer/answer/9893335 ("imagery and terminology ... may affect Google Play's assessment"); öneri Ç. Sahip kararı |
| **Haber uygulaması** | Hayır | Ç |
| **COVID-19** | Uygulama bu konuyla ilgili değil | Ç |
| **Devlet uygulaması** | Hayır | Ç (kuruluş hesabı gerektiren türler: .../answer/13634885) |
| **Finansal özellikler** | "My app doesn't provide any financial features" seç (uygulama içi satın alma finansal özellik sayılmaz; jeton satılmıyor) | K: https://support.google.com/googleplay/android-developer/answer/13849271 |
| **Sağlık uygulaması / sağlık beyanları** | Hayır (sayfa değinmiyor; kuruluş hesabı türleri arasında "sağlık" geçer, bizim oyun değil) | Ç |
| **Reklam Kimliği (Advertising ID)** | **Evet, kullanıyor.** Amaç: **Reklamcılık veya pazarlama**; (Google rehberi analitik/sahtecilik de sayar → sahtecilik önleme/güvenlik uygun). Manifestte `com.google.android.gms.permission.AD_ID` olmalı (SDK ≥ 20.4.0 kendisi ekler; Next-Gen SDK için birleşik manifestte doğrula) | K: https://support.google.com/googleplay/android-developer/answer/6048248 ; https://developers.google.com/admob/android/quick-start |
| **Hesap silme URL'si** | Uygulanmaz: hesap oluşturma yok | K: .../answer/10144311 ("apps that allow users to create an account") |
| **Çocuklara yönelik ekstra (Families)** | Uygulanmaz (13+) | Ç |

## C. İçerik derecelendirme (IARC) — beklenen cevaplar

Anketin soru metinleri Play Console'da çıkar; resmi sayfa kategorileri saymıyor (K: https://support.google.com/googleplay/android-developer/answer/9859655 — "yanlış beyan kaldırma sebebidir", "reklamlar derecelendirmeye uygun olmalı"). Aşağıdakiler oyunun gerçek içeriğine göre **öneri**dir (Ç):

| Konu | Cevap |
|---|---|
| Şiddet, kan, korku | Yok |
| Cinsellik / çıplaklık | Yok |
| Küfür / kaba dil | Yok |
| Uyuşturucu, alkol, tütün | Yok |
| Kumar / simüle kumar | Yok (jeton satılmıyor, parayla rastgele ödül yok; sandık ödülleri ücretsiz oyun içi ilerleme — satılan rastgele ürün olmadığını doğrula) |
| Kullanıcı etkileşimi / kullanıcı içeriği paylaşımı / sohbet | Yok |
| Konum paylaşımı | Yok |
| Dijital satın alma | **Evet** (reklamları kaldır) |
| Reklam içeriyor | **Evet** |
| Sınırsız web erişimi | Hayır |
| Beklenen sonuç | Düşük yaş derecesi (örn. PEGI 3 / ESRB Everyone / USK 0 civarı) — **tahmin**, gerçek sonucu IARC verir. AdMob konsolunda **reklam içerik derecesini** ve engelleme kontrollerini ayarla |

## D. Mağaza ayarları ve diğer

| Konu | Öneri |
|---|---|
| Uygulama / oyun | **Oyun** (Bulmaca) |
| Ücretsiz / ücretli | Ücretsiz (+ uygulama içi satın alma + reklam) — Play ilanında "Contains ads" ve "In-app purchases" etiketleri otomatik |
| Ülkeler | Tümü (dünya çapı); Japonya ve Kore satıcı bilgisi kuralları: PLAY_REQUIREMENTS 4.5 |
| Dahili test + kapalı test | PLAY_RELEASE_PLAN.md |
| Fiyat | `remove_ads` fiyatı sahibe ait (kod örnek fiyat `$2.99` sahte) |
