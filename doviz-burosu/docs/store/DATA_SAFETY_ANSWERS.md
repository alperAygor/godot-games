# Play Console beyanları — önerilen cevaplar (Döviz Bürosu, T-S1 taslağı)

Tarih: 2026-11-15. Bunlar **öneridir**; formu dolduran ve doğruluktan sorumlu olan **sahiptir**. Hukuki tavsiye değildir. Genel çerçeve ve kaynaklar: `~/Desktop/Games/godot-games/CamasirIpi/docs/store/DATA_SAFETY_ANSWERS.md` ve `PLAY_REQUIREMENTS.md` (G2: finans/kumar temaları). Bu belge o kalıba göre **bu oyunun gerçek davranışına** uyarlandı.
Gerçek davranış değişirse (analitik, bildirim, hesap, başka SDK/reklam ağı) bu cevaplar, `docs/PRIVACY_POLICY.md` (+`.tr.md`) ve oyun içi onay metinleri (`MON_NOTICE_TEXT`, `MON_FORM_TEXT`) **birlikte** güncellenir; Play tutarsızlığı politika ihlali sayar (answer/10787469).
Kaynak türleri: **K** = Çamaşır İpi belgelerinde "resmi sayfa okundu" olarak kayıtlı (bu çalışmada yeniden okunmadı); **O** = bu projenin kodundan olgu; **Ç** = çıkarım (konsolda doğrula).

## 0. Bu oyunun veri olguları (O)

| Olgu | Kanıt |
|---|---|
| Hesap, giriş, sunucu, kullanıcı içeriği yok | `scripts/**` (kimlik doğrulama/HTTP yok); ASSESSMENT §10-11 |
| Kendi analitiğimiz yok; olaylar yalnız bellekte (son 50), cihazdan çıkmaz | `scripts/autoload/analytics.gd` |
| Kayıt/ayarlar yerel (`user://save.json`, `settings.cfg`) | `SaveManager`, `SettingsManager` |
| Ağ yalnız Google Mobile Ads SDK + UMP + Play Billing | ASSESSMENT §10; `scripts/services/*` |
| Reklam: geçiş (gün sonu) + ödüllü (isteğe bağlı); banner yok; içerik sınıfı en çok PG | `data/ads.json`, `data/ads_ids.json` |
| Onay: UMP (AB/UK/İsviçre vb.) ya da oyun içi kısa bilgi + kişiselleştirme seçimi | `docs/MONETIZATION.md` §2, `ConsentFlow` |
| Tek satın alma: `no_ads` (tek seferlik, tüketilmeyen); oyun içi para satılmaz; şansa bağlı ödül satışı yok | `data/products.json` |
| İzinler (kendimiz): INTERNET, ACCESS_NETWORK_STATE, VIBRATE; SDK'lardan: AD_ID, ACCESS_ADSERVICES_*, WAKE_LOCK, FOREGROUND_SERVICE, BILLING | `docs/store/RELEASE_STATUS.md` |

## A. Veri güvenliği formu (Data safety)

| Soru | Önerilen cevap | Gerekçe |
|---|---|---|
| Uygulama kullanıcı verisi topluyor veya paylaşıyor mu? | **Evet** | Google Mobile Ads SDK otomatik veri toplar (K: https://developers.google.com/admob/android/privacy/play-data-disclosure) |
| Toplanan tüm veri aktarımda şifreli mi? | **Evet** | Google'ın SDK rehberi: TLS (K). Kendi sunucumuz yok |
| Kullanıcıların veri silme talep etme yolu var mı? | **Hayır** (hesap yok; yerel veri kaldırmayla silinir; SDK verisi Google'dadır). Politikada reklam kimliği silme anlatılır. Formdaki seçenek metnini konsolda oku. | Ç; hesap silme politikası hesaba dayanır (answer/10144311) |
| Gizlilik politikası URL'si | `[POLICY URL]` (sahip barındırır; aynı URL oyunda `data/ads_ids.json privacy_policy_url`) | K |

### Veri türleri (Google rehberinin dört türü → Play kategorileri; **eşleştirme Ç**, konsoldaki "Learn more" tablosuyla ve rehberin güncel hâliyle doğrula)

| Google rehberindeki tür | Play veri türü (öneri) | Toplanıyor | Paylaşılıyor | Zorunlu/isteğe bağlı | Amaç |
|---|---|---|---|---|---|
| Android reklam kimliği, app set ID | **Device or other IDs** | Evet | Evet (reklam ağı = Google) | İsteğe bağlı (kullanıcı reklam kimliğini silebilir/sıfırlayabilir) | Reklam veya pazarlama; sahtecilik önleme/güvenlik/uyum |
| IP adresi | Play'de ayrı "IP" türü yok; Google rehberindeki eşleştirmeyi konsolda izle (olası: Device or other IDs ya da Approximate location — **doğrulanamadı**) | Evet | Evet | Zorunlu (ağ isteğinin parçası) | Reklam; sahtecilik önleme |
| Kullanıcı-ürün etkileşimleri (açılış, dokunma, video izleme) | **App activity → App interactions** | Evet | Evet | Zorunlu | Reklam; sahtecilik önleme (Google rehberi analitiği de sayar → rehberi izle) |
| Tanılama bilgisi (açılış süresi, takılma, enerji) | **App info and performance → Diagnostics** | Evet | Evet | Zorunlu | Sahtecilik önleme/güvenlik (rehber analitiği de sayar) |
| Satın alma geçmişi | **Toplanmaz**: ödeme verisi Google Play'de kalır; oyun yalnız sahiplik durumunu yerelde saklar | Hayır | Hayır | — | O |
| Konum, kişisel bilgi (ad/e-posta/telefon), mesajlar, fotoğraf/ses/video, dosyalar, kişiler, takvim, finansal bilgi, sağlık/fitness, web gezinme | **Toplanmaz** | Hayır | Hayır | — | İzin istenmiyor (O) |
| Kendi analitiğimiz, çökme raporumuz | **Yok** (kendi SDK'mız yok) | Hayır | Hayır | — | `Analytics` yalnız bellekte (O) |

Notlar:
1. **"Paylaşma"**: Google'ın kendi rehberi reklam amaçlı verileri "toplanır ve paylaşılır" diye anlatır → konservatif cevap **paylaşılıyor** (Ç).
2. Rehber "son sürüm" içindir; SDK güncellenince sayfa yeniden okunup form güncellenir (K). Bu oyunun reklam eklentisi AdMob v7.0 (klasik Google Mobile Ads SDK, Gradle ile; ASSESSMENT §2).
3. Bildirim, analitik ya da yeni SDK gelirse form yeniden doldurulur.
4. Oyun içi onay metni (`MON_NOTICE_TEXT`) ile bu form ve politika aynı üç olguyu söyler: reklam kimliği/IP/etkileşim AdMob tarafından toplanabilir; hesap yok; analitik yok.

## B. Uygulama içeriği (App content) beyanları

| Beyan | Önerilen cevap | Not |
|---|---|---|
| **Gizlilik politikası** | `[POLICY URL]` gir; uygulama içi bağlantı da var (Ayarlar > Gizlilik politikası; URL geçerliyken) | K: answer/9859455, 10144311 |
| **Reklamlar** | **Evet, uygulama reklam içeriyor** (AdMob: geçiş + ödüllü) | K |
| **Uygulama erişimi** | Tüm işlevler kısıtsız (giriş yok) | O |
| **Hedef kitle ve içerik** | **13 yaş ve üzeri** (13-15, 16-17, 18+). 5 yaş altı / 6-8 / 9-12 **seçilmez**. İlan metni ve görsellerde çocuklara yönelik anlatım yok. Piksel görünüm çizgi film estetiği değil; yine de Play "çocuklara çekici" sayarsa Aileler yükümlülükleri doğar → sahip kararı | K: answer/9893335; öneri Ç |
| **Haber uygulaması** | Hayır (oyun içindeki "Pahalistan Gazetesi" kurgusal oyun içeriğidir, haber uygulaması değil) | Ç |
| **COVID-19** | Uygulanmaz | Ç |
| **Devlet uygulaması** | Hayır (oyunda bir "bakanlık/merkez" kurgusu vardır; gerçek kurum değil) | Ç |
| **Finansal özellikler** | **"My app doesn't provide any financial features"** (finansal özellik yok). Uygulama içi satın alma finansal özellik değildir; oyun içi para satılmaz; gerçek para/ödeme/transfer/döviz işlemi, yatırım tavsiyesi, kredi, kripto yok | K: answer/13849271. Form serbest metin/açıklama alanı sunarsa: "Fiction game with fictional countries and currencies; no real money, exchange rates, trading, payments or advice." Seçenekler arasında döviz/para transferi/ticaret gibi bir türü **işaretleme**; oyun bunlardan hiçbirini sunmaz |
| **Sağlık uygulaması** | Hayır | Ç |
| **Reklam Kimliği (Advertising ID)** | **Evet, kullanıyor.** Amaç: **Reklamcılık veya pazarlama**; sahtecilik önleme/güvenlik uygun. Manifestte `com.google.android.gms.permission.AD_ID` var (birleşik manifest: `tools/release_check.sh` AAB denetimi izin listesinde) | K: answer/6048248 |
| **Hesap silme URL'si** | Uygulanmaz: hesap oluşturma yok | K: answer/10144311 |
| **Aileler (Families) programı** | Uygulanmaz (13+) | Ç |
| **Kumar / simüle kumar** | Yok | O (ASSESSMENT §10: şans oyunu mekaniği yok, rastgele ödüllü satış yok) |

## C. İçerik derecelendirme (IARC) — beklenen cevaplar

Anket soru metinleri Play Console'da çıkar; resmi sayfa kategorileri saymaz (K: answer/9859655 — "yanlış beyan kaldırma sebebidir", "reklamlar derecelendirmeye uygun olmalı"). Aşağıdakiler **oyunun gerçek içeriğine göre öneridir** (olgu kaynağı: ASSESSMENT §10, `story.csv`):

| Konu | Cevap | Ayrıntı / dürüstlük notu |
|---|---|---|
| Şiddet, kan, silah, korku | Yok | Çatışma yok; polis çağırma ve "tutuklandı" yalnız metin/olay (ASSESSMENT §10 anahtar kelime taraması: şiddet/ölüm/silah yok) |
| Cinsellik / çıplaklık | Yok | — |
| Küfür / kaba dil | Yok | — |
| Uyuşturucu, alkol, tütün | Yok | — |
| Kumar / simüle kumar | **Yok** | Parayla rastgele ödül ya da şans oyunu yok; sonuç beceriye bağlı |
| Suç / yasadışı eylem / yolsuzluk teması | Anket **sorarsa**: **Evet, hafif, kurgusal, grafik değil.** Hikâyede rüşvet zarfı (oyuncu reddedebilir; kabul kötü sona götürür), sahte banknot/kimlik ve polis çağırma var; ton kara mizah | Yanlış beyan yasak: gizleme, olduğu gibi bildir. Oyun yolsuzluğu teşvik etmez: ahlaki sonuçlarıyla sunar (ASSESSMENT §10) |
| Kullanıcı etkileşimi / içerik paylaşımı / sohbet | Yok | "Paylaş" düğmesi yalnız panoya metin kopyalar |
| Konum paylaşımı | Yok | — |
| Dijital satın alma | **Evet** (Reklamları kaldır) | — |
| Reklam içeriyor | **Evet** | AdMob konsolunda reklam içerik derecesi en çok PG (kodda da PG) |
| Sınırsız web erişimi | Hayır | — |
| Beklenen sonuç | Düşük/orta düşük yaş derecesi (tahmin: PEGI 3–7 / ESRB Everyone–E10+ / USK 0–6 bandı) — **Ç**; gerçek sonucu IARC verir. Sonucun hedef kitle 13+ ile çelişmediğini kontrol et | Anket cevapları ilan metnindeki "İçerik notu" ile aynı olmalı |

## D. Mağaza ayarları ve diğer

| Konu | Öneri |
|---|---|
| Uygulama / oyun | **Oyun › Simülasyon** (Finans DEĞİL) — gerekçe `docs/store/PLAY_LISTING.md` §6 |
| Ücretsiz / ücretli | Ücretsiz (+ uygulama içi satın alma + reklam); ilanda "Contains ads" ve "In-app purchases" etiketleri otomatik |
| Ülkeler | Sahip kararı. Para kazanan hesapta tam adres herkese açık (PLAY_REQUIREMENTS 1.6/4.5); Japonya/Kore satıcı bilgisi kuralları taranmalı |
| Fiyat | `no_ads` fiyatı sahibe ait (kodda mock `$2.99`; bölgesel fiyat Play'de) |
| Test | Dahili + kapalı test: `docs/store/OWNER_CHECKLIST.md` |

## E. AdMob konsolu ayarları (sahip uygular; kod karşılığı yok)

- **Reklam içerik derecesi** en çok **PG** (kodda `ads_ids.json ads.max_ad_content_rating = "PG"`; konsol ayarıyla aynı tut).
- **Reklam kategorisi engelleme** (AdMob > Blocking controls): finans/kumar çağrışımlı kategorileri engelle — bahis/kumar/casino, forex/ticaret/yatırım, kripto, kredi/hızlı para, "kolay para kazan" tipi reklamlar. Kategori adları konsolda değişebilir: listeden en yakın olanları seç (tam adlar bu çalışmada doğrulanamadı). Neden: oyun döviz temalıdır; gerçek forex/kumar reklamı gösterilirse hem oyuncuya yanıltıcı olur hem ilanın "gerçek para değil" mesajıyla çelişir (PLAY_REQUIREMENTS G2.5).
- **Gizlilik ve mesajlaşma:** AB/UK/İsviçre için **GDPR iletisi** oluştur ve yayımla (UMP; olmadan oyundaki `form` rejimi çalışmaz); ABD eyalet iletisi önerilir (answer/13554116 ve developers.google.com/admob/android/privacy/us-states — K).
- `app-ads.txt` (geliştirici web sitesinin kökünde); Play ilanına web sitesi eklenir.
- Gerçek kimlikler yalnız `data/ads_ids.json` `real_*` alanlarına (sonra `python3 tools/sync_ads_config.py`); kendi canlı reklamına tıklama yok.

## F. Politika ile çelişki kontrol listesi (gönderme öncesi)

- [ ] Veri güvenliği cevapları = `docs/PRIVACY_POLICY.md` = oyun içi `MON_NOTICE_TEXT`/`MON_FORM_TEXT` (üçü de: reklam kimliği/IP/etkileşim AdMob, hesap yok, analitik yok).
- [ ] İlan metni (`PLAY_LISTING.md`) "kurgusal ülke/para, finansal tavsiye değil, gerçek para kazanılmaz" der; ekran görüntüsünde gerçek banknot/para birimi adı yok.
- [ ] Finansal özellikler: "yok". Kategori: Oyun. Finans etiketi/kategorisi yok.
- [ ] Hedef kitle 13+; IARC cevapları §C ile aynı; ilanda "İçerik notu" bulunur.
- [ ] AdMob: PG, finans/kumar engelleri, GDPR iletisi yayında.
