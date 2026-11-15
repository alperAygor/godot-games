# Sahip yapılacaklar listesi — Döviz Bürosu (yalnız senin yapabileceklerin)

Tarih: 2026-11-15. Genel liste (hesap, vergi, imza anahtarı üretimi, kapalı test ayrıntıları, kaynak bağlantıları): `~/Desktop/Games/godot-games/CamasirIpi/docs/store/OWNER_CHECKLIST.md` — **orayı da oku**; burada yalnız bu oyuna özgü kararlar, değerler ve hangi dosyaya ne yazılacağı var. Hesap/anahtar adımlarında "Çamaşır İpi" yerine bu oyunun adı ve paket kimliği geçer. Hukuki tavsiye değildir.
Durum tablosu ve kapı çıktısı: `docs/store/RELEASE_STATUS.md`, `tools/release_check.sh` (sahip işleri bitmeden BAŞARISIZ olması beklenir). Kodlayıcıya verilecek hiçbir sır yoktur: anahtar/parola yalnız ortam değişkenlerinde.

## 0. Önce karar ver
- [ ] **Mağaza başlığı (EN)**: öneri `Pahalistan Exchange Desk` (24/30); yedek `Stamp & Count: Exchange Desk` — `docs/store/PLAY_LISTING.md` §1. **Ad müsaitlik/marka taramasını sen yap** (çevrimiçi kontrol yapılmadı). TR başlık önerisi `Döviz Bürosu: Damga ve Say`.
- [ ] **Paket kimliği**: şu an `com.dovizburosu.game` (`export_presets.cfg`, 3 preset; ilk yüklemeden sonra DEĞİŞMEZ). Onayla ya da ilk yüklemeden ÖNCE kendi alan/adına göre değiştirt (T-R1).
- [ ] **Hedef kitle**: 13+ (çocuk değil) — hikâyede rüşvet/sahte belge/polis var (`DATA_SAFETY_ANSWERS.md` B, C). Daha yüksek (16+) istersen ilan ve anket cevaplarını buna göre güncelle.
- [ ] **Kategori**: Oyun › Simülasyon (Finans değil) — `PLAY_LISTING.md` §6.
- [ ] **Para birimi adları**: oyun "Federal Dolar (FED)" ve "Avrin (AVR)" gibi gerçek para birimlerini çağrıştıran kurgusal adlar kullanıyor (ASSESSMENT §10). Mağazada "kurgusal" vurgusu ve ekran görüntüleri bunu dengeler; yine de kabul edilebilir mi, yoksa adlar değişsin mi karar ver (değişirse T-C1/T-L1 işi).
- [ ] **No-ads fiyatı** (kodda mock $2,99; bölgesel fiyat Play'de) ve ilanda fiyat yazılmaz.
- [ ] **ElevenLabs**: ses dosyaları ücretsiz plan döneminde üretildi (ASSESSMENT §4). Ücretli plan al, tümünü yeniden ürettir (T-A1, anahtar sende), üretim kaydı/faturayı sakla. Hakkında ekranı "ElevenLabs ile üretildi" der; yeniden üretimden sonra da doğru kalır.
- [ ] **Kullanılmayan yazı tipleri**: `assets/fonts/Baloo2.ttf` (683 KB) ve `PixelifySans.ttf` kullanılmıyor ama pakete giriyor. Silmeye **onay ver** ya da kalsın de; silinirse lisans kayıtları `tools/build_licenses.py` içinden de çıkarılır (CLAUDE.md kural 6).
- [ ] **AdMob eklentisi LICENSE**: `addons/AdmobPlugin/` içinde LICENSE dosyası yok; Hakkında'daki metin standart MIT + plugin.cfg telif satırıdır. Yukarı akıştaki (github.com/godot-sdk-integrations/godot-admob) LICENSE dosyasını eklemeye onay ver (indirme gerekir) ve `python3 tools/build_licenses.py` ile yenilet.

## 1. Hesaplar (genel listedeki §1)
- [ ] Play Console geliştirici hesabı + kimlik doğrulama + satıcı/ödeme profili + vergi. **Para kazanan hesapta adresin herkese açık görüneceğini bil** (genel liste §1).
- [ ] Geliştirici **web sitesi** (gizlilik politikası ve `app-ads.txt` burada).
- [ ] Yeni kişisel hesap: **kapalı test ≥ 12 test kullanıcısı × 14 ardışık gün**, sonra üretim başvurusu (genel liste §6; Play Console'daki güncel şarta bak). Tester bulmaya hemen başla: en uzun bekleme budur.

## 2. Gizlilik politikası (T-S1 çıktısı → senin barındırman)
- [ ] `docs/PRIVACY_POLICY.md` (EN) ve `docs/PRIVACY_POLICY.tr.md` (TR) taslaklarını oku. Yer tutucuları doldur: `[DEVELOPER NAME]`, `[POSTAL ADDRESS]`, `[CONTACT EMAIL]`, `[EFFECTIVE DATE]`, `[POLICY URL]` (TR: `[GELİŞTİRİCİ ADI]` vb.). Türkiye'de yerleşikseniz KVKK paragrafını bir uzmana göster; değilsen sil. Dosyanın başındaki "Sahip için not" kutusunu YAYIMLAMA.
- [ ] Herkese açık, coğrafi kısıtsız, PDF olmayan bir https adresinde yayımla (örn. `https://<alan>/doviz-burosu/privacy`; TR sürüm aynı sayfada ya da `/tr`).
- [ ] URL'yi **yalnız** `data/ads_ids.json` `privacy_policy_url` alanına yaz (oyun içi bağlantı ve yayın kapısı oradan okur; `tools/release_state.json` değil). Kodlayıcıya yaptırabilirsin.
- [ ] Aynı URL'yi Play Console > Uygulama içeriği > Gizlilik politikası alanına gir.
- [ ] Kökte `https://<alan>/app-ads.txt` (içeriği AdMob verir).

## 3. AdMob
- [ ] Hesap + uygulama (Android, paket kimliği) + 2 reklam birimi: **Rewarded** ve **Interstitial** (banner YOK). Üç kimliği (uygulama + iki birim) kodlayıcıya ver → `data/ads_ids.json` `real_*` + `python3 tools/sync_ads_config.py`; `mode` `"real"` yapılır. Kendi canlı reklamına **tıklama**.
- [ ] **Gizlilik ve mesajlaşma**: AB/UK/İsviçre **GDPR iletisini oluştur ve yayımla** (UMP; oyunun `form` rejimi buna bağlı), ABD eyalet iletisi önerilir.
- [ ] **Reklam içerik derecesi en çok PG**; **finans/kumar çağrışımlı reklam kategorilerini engelle** (bahis/kumar, forex/ticaret/yatırım, kripto, kredi/hızlı para) — `DATA_SAFETY_ANSWERS.md` E.
- [ ] Uygulama Play'de yayınlanınca AdMob'da mağazaya bağla.

## 4. Play Console (uygulama + ürün)
- [ ] Uygulamayı oluştur (Oyun, Ücretsiz), Play Uygulama İmzalama şartları.
- [ ] **Uygulama içi ürün `no_ads`**: tek seferlik, yönetilen/tüketilmeyen, ad "Reklamları kaldır", fiyat, **Etkin**. Ürün kimliği kodda `no_ads`. Lisans testi hesapları ekle. Sonra `data/ads_ids.json providers.play_billing=true` (lider/sahip bayrağı, `docs/MONETIZATION.md` §5).
- [ ] **Uygulama içeriği**: cevaplar `docs/store/DATA_SAFETY_ANSWERS.md` — Gizlilik politikası, Reklamlar = Evet, Uygulama erişimi (kısıtsız), Hedef kitle (13+), İçerik derecelendirme anketi (§C; doğru ve eksiksiz — yanlış beyan kaldırma sebebi), Veri güvenliği (§A), Reklam kimliği = Evet, **Finansal özellikler = "yok"** (§B).
- [ ] **Mağaza ilanı**: `docs/store/PLAY_LISTING.md` metinleri (EN birincil + TR; başlık ≤ 30, kısa ≤ 80), kategori, etiketler, iletişim, web sitesi. İlandaki iddiaları yayın sürümüyle karşılaştır (`PLAY_LISTING.md` §5). `[DEVELOPER EMAIL]` yer tutucusunu doldur.
- [ ] **Grafikler** (T-R2): 512 simge, 1024×500 öne çıkan, telefon ekran görüntüleri TR+EN (`PLAY_LISTING.md` §7).

## 5. İmza (genel listedeki §4 + `docs/store/SIGNING.md`)
- [ ] Yükleme anahtarını **sen** üret, en az iki yere yedekle, depoya koyma; yalnız kendi makinende `GODOT_ANDROID_KEYSTORE_RELEASE_{PATH,USER,PASSWORD}` ortam değişkenlerini ver. Kodlayıcı parolayı bilmez.

## 6. Cihaz ve test (genel liste §6)
- [ ] En az bir gerçek Android telefon + `docs/MONETIZATION.md` §7 test listesi (test reklamı, UMP, lisans testçisiyle satın alma/geri yükleme/iade, titreşim, kenardan kenara/çentik, büyük yazıda ve renk körü kipinde ana ekranlar).
- [ ] **Dahili test** → **kapalı test** → "Apply for production" → aşamalı yayın; Android vitals izle.
- [ ] İlandaki "çevrimdışı oynanır" gibi bir cümle eklemek istersen önce uçak modunda cihazda doğrula (şu an ilanda YOK).

## 7. Yayın kapısı
- [ ] `tools/release_check.sh` (AAB ile: `tools/release_check.sh --latest`) tüm satırlar PASS olmadan Play'e yükleme.
- [ ] Yüklemeden sonra `tools/release_state.json` `last_uploaded_version_code` güncelle.
