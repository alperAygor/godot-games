# Google Play yayın planı — kod işçisi için sıralı mühendislik planı

Okuma tarihi: 2026-11-15. Gereksinim kaynakları ve satır numaraları: `docs/store/PLAY_REQUIREMENTS.md` (R-x.y = o belgedeki satır).
Kural: **indirme gerektiren her adım için önce sahibin onayı alınır** (aşağıda "İNDİRME" ile işaretli). Bu planı uygulayan işçi `CLAUDE.md` kurallarına uyar (tam statik tip, SDK çağrısı yalnız sağlayıcıda, `verify.sh` yeşil, `TASKS.md`/`CHANGELOG.md` güncel).

## 0. Karar gerektiren üç şey (sahip)

1. **Paket adı** (Play'de bir kez seçilir, sonra değişmez): öneri `com.camasiripi.game` (test ön ayarı zaten `com.camasiripi.game.test`). Sahip onaylamadan ön ayara yazma.
2. **ElevenLabs planı** (R-3.17): ücretli plan alınmadan ses yeniden üretilmeyecek; üretim yapılmış olsa bile ticari yayın öncesi karar sahibe ait.
3. **Hedef kitle**: "13+ gruplar" önerisi (R-3.5). Aileler politikası kapsamına girmek istenmiyorsa ilan metnine çocuklara yönelik dil konmaz.

## 1. Sürüm matrisi (eklenecek şeyler)

| Bileşen | Sürüm | Lisans | Kaynak (İNDİRME → onay) | Not |
|---|---|---|---|---|
| Godot | 4.7.2 (mevcut) | MIT | zaten kurulu | Android dışa aktarım şablonları kurulu olmalı |
| OpenJDK | **17** (önerilen) | GPLv2+CE (Temurin/OpenJDK dağıtımına göre; doğrulanmadı) | https://docs.godotengine.org/en/latest/tutorials/export/exporting_for_android.html | İNDİRME |
| Android SDK paketleri | `platform-tools`, `build-tools/36.1.0`, `platforms/android-36`, `cmdline-tools/latest`, `ndk/29.0.14206865`, `cmake/3.22.1` | Android SDK Lisansı (Google, kabul gerekir) | aynı belge | İNDİRME; lisans kabulü sahibe ait. Şablon `master` değerleri: `config.gradle` (bkz. R-2.1) — 4.7.2 kararlı şablonuyla uyumu şablon kurulunca doğrula |
| Poing AdMob eklentisi | **5.1.0** (projede kurulu) | MIT (`addons/admob/LICENSE`) | https://github.com/Poing-Studios/godot-admob-plugin | Yeni iş yok; 5.2 gece sürümlerini kullanma |
| Google Mobile Ads **Next-Gen SDK** | 1.4.0 (Gradle bağımlılığı: `com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk:1.4.0`) | Google (tescilli; AdMob koşulları) | Maven (Gradle çeker) | minSdk ≥ 24, compileSdk ≥ 35 (R-2.2) |
| **GodotGooglePlayBilling** | **3.3.0** (27 Tem 2026; PBL 9.1.0; Godot ≥ 4.2) | MIT (README) | https://github.com/godot-sdk-integrations/godot-google-play-billing/releases (zip) | İNDİRME. Konum: `addons/GodotGooglePlayBilling/`. Bağımlılık: `com.android.billingclient:billing-ktx:9.1.0` |
| bundletool / apkanalyzer / zipalign | Android SDK içinde (`build-tools`); bundletool ayrı jar | Apache-2.0 (bundletool; doğrulanmadı) | https://developer.android.com/tools/bundletool | İNDİRME (yalnız AAB incelemesi için) |

Uyarı: `docs/MONETIZATION.md` 4.1 hâlâ "GodotGooglePlayBilling tekil nesnesi + camelCase" diyor — eskimiş; bu planın 5. adımı belgeyi de günceller.

## 2. Mühendislik adımları (sırayla)

Her adımın sonunda: `bash tools/verify.sh` yeşil + adımın "Doğrulama"sı. Android cihazı olmayan adımlar masaüstünde kapanır; cihaz adımları "CİHAZ" etiketlidir.

### Adım 1 — Araç zinciri (editör, İNDİRME onaylı)
- JDK 17 + SDK paketlerini kur; Godot Editör Ayarları: `Java SDK Path`, `Android SDK Path` (`platform-tools/adb` içeren dizin).
- Doğrulama: Godot Editörü → Proje → Dışa Aktar → Android: "hata yok" göstergesi; `adb devices` cihazı listeler.

### Adım 2 — Gradle şablonu
- Editör: **Proje → Android Derlemesi Kur (Install Android Build Template)** (belge adı "Setup Android Build...") → `res://android/build` oluşur.
- `android/` klasörü depoya girer mi karar: şablon kaynakları sürüm kontrolüne alınır, `android/build/build/` ve `*.aab/*.apk` çıktıları `.gitignore`'a (yeni dosya değişikliği bu işin kapsamında).
- `android/build/config.gradle` değerlerini kaydet (hedef/min/compile SDK, build-tools, NDK, AGP, Java). Beklenen (master): minSdk 24, targetSdk **36**, compileSdk 36, AGP 8.13.2, Java 17. Farklıysa dışa aktarma seçeneklerinden `target_sdk=36` zorla; AGP < 8.5.1 ise dur ve sahibe bildir (16 KB paketleme, R-2.5).
- Doğrulama: `android/build/` altında `gradlew` çalışır (`./gradlew --version`).

### Adım 3 — Yayın ön ayarı (`export_presets.cfg`, preset.0 "Android (release)")
Seçenek adları editörde kontrol edilir; değerler:
- `package/unique_name` = sahibin onayladığı ad; `package/name` = "Clothesline Sort"; yerelleştirilmiş uygulama adı için proje ayarı `application/config/name_localized/<dil>` (editörde var mı doğrula) → Çamaşır İpi marka adı tr/diğerlerinde korunabilir.
- `version/code` = 1 (her yüklemede artırılır; Play aynı kodu iki kez kabul etmez), `version/name` = "1.0.0".
- `gradle_build/min_sdk` = 24, `gradle_build/target_sdk` = 36 (seçenek adlarını editörden doğrula).
- `permissions/internet` = true, `permissions/access_network_state` = true; diğer tüm izinler kapalı (R-2.7).
- `package/signed` = true; **imza bilgisini dosyaya yazma**: ortam değişkenleri `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `..._USER`, `..._PASSWORD` (Godot belgesi). Keystore ve anahtar parolası aynı, yalnız harf-rakam. "Export With Debug" kapalı.
- Ana simge ≥ 192×192, adaptif ön/arka plan ≥ 432×432 (Godot belgesi); `project.godot` `application/config/icon` + ön ayarda `launcher_icons/*`.
- Mevcut `exclude_filter` değiştirilmez (AAR'lar Gradle yoluyla girer); preset.3 test APK'si **eklentisiz** kalır (Gradle yok).
- Doğrulama: `godot --headless --path . --export-pack "Android (release)" build/size/game.pck` hâlâ çalışır; `tools/pck_check.py` geçer.

### Adım 4 — Çalışma-zamanı koruması: gerçek kimlik olmadan yayın yapılamasın
- Yeni saf sınıf `scripts/core/release_guard.gd` (ya da `tools/release_check.py`): `data/ads.json` içinde `mode == "production"` iken `REPLACE_*` veya Google test kimliği (`ca-app-pub-3940256099942544`) kalmışsa **hata** döndürür.
- Test: `tests/unit/test_release_guard.gd` (4 durum: test modu geçer; üretim+placeholder hata; üretim+gerçek biçim geçer; üretim+test kimliği hata). Kimlik biçimi: `ca-app-pub-<16 hane>~<10 hane>` (uygulama), `ca-app-pub-<16>/<10>` (birim) — biçim regex'i test eder.
- Doğrulama: `verify.sh`; yayın öncesi `tools/release_check.sh` (yeni, manifest+kimlik+sürüm taraması — Adım 11'de kullanılır).

### Adım 5 — Billing: eklentiyi kur ve sağlayıcıyı yeniden yaz (B1)
- İNDİRME: `GodotGooglePlayBilling` 3.3.0 zip → `addons/GodotGooglePlayBilling/`; Proje Ayarları → Eklentiler'de etkinleştir; `project.godot` `[editor_plugins]` listesine eklenir.
- `scripts/services/play_billing_provider.gd` yeniden yazılır (arayüz `IapProvider` korunur; `IapService` değişmez):
  - `Engine.has_singleton("GodotGooglePlayBilling")` kontrolü kalkar. Yeni sınıf `BillingClient` (eklenti GDScript'i `export_scripts/BillingClient.gd`) kullanılır; yalnız `OS.has_feature("android")` iken `BillingClient.new()`. **Gerçek native tekil nesne adı ve sınıfın dışa aktarımda `addons/` içinden pakete girip girmediği eklenti kaynağından doğrulanmalı** (belgede yok).
  - Akış: `start_connection()` → `connected` → `query_product_details(["remove_ads"], BillingClient.ProductType.INAPP)` → `query_product_details_response(dict)` (`response_code == OK` → fiyat metni; **ürün detayı alanları belgede yazılı değil**, eklenti kaynağından oku ve `parse_price` benzeri saf fonksiyona yaz) → `query_purchases(INAPP)` → `query_purchases_response`.
  - Satın alma: `purchase("remove_ads")` döndürdüğü sözlükte `response_code` başarısızsa `purchase_failed(REASON_ERROR)`; asıl sonuç `on_purchase_updated(dict)`; yalnız `purchase_state == BillingClient.PurchaseState.PURCHASED` sahiplik verir; PENDING sahiplik vermez; `is_acknowledged == false` ise `acknowledge_purchase(purchase_token)` (**3 gün içinde**, aksi halde iade).
  - Kullanıcı iptali sessiz (`REASON_CANCELED`), ağ hatası `REASON_NOT_CONNECTED`.
  - `purchase()` tek-seferlik ürünlerin "satın alma seçeneği" (purchase_option_id) alanı: ilk/tek seçenekle çağrılabilir (varsayılan boş) — cihazda doğrula.
- Test: `tests/unit/test_play_billing_provider.gd` — sahte `FakeBillingClient` (sinyalleri elle yayar; `acknowledge_purchase` çağrılarını sayar): (a) bağlan→fiyat→sahiplik; (b) PENDING sahiplik vermez; (c) iade (sorgu başarılı ama ürün yok) → `restore_finished(boş, true)`; (d) acknowledge yalnız `is_acknowledged=false` iken ve bir kez; (e) iptal sessiz; (f) bağlantı hatası bekleyen satın almayı düşürür. Mevcut saf ayrıştırıcıların testleri taşınır.
- `docs/MONETIZATION.md` 4.1 ve "Bilinen sınırlar" güncellenir.
- Doğrulama: masaüstünde testler; CİHAZ: Adım 12.

### Adım 6 — AdMob üretim yapılandırması
- Sahip AdMob'da (OWNER_CHECKLIST) uygulama + 2 birim (Rewarded, Interstitial) oluşturur ve kimlikleri verir. `data/ads.json` → `production.*` doldurulur, `mode: "production"` **yalnız yayın dalında**; Adım 4 koruması geçmeli.
- **Uygulama kimliği manifestte olmalı** (`com.google.android.gms.ads.APPLICATION_ID`, yoksa "Missing application ID" çökmesi — Google belgesi): eklenti bunu proje ayarından yazar (`[admob]` bölümü; varsayılan test kimliği). Gerçek uygulama kimliği Proje Ayarları → AdMob'dan girilir (ayar adı editörde doğrulanır; `project.godot` `[admob]` bölümü şu an yalnız `general/ios/enabled=false`). Birleşik manifestte (Adım 11) test kimliğinin kalmadığı doğrulanır.
- `poing_admob_bridge.gd`: `show_privacy_options` yöntemi eklenir (`UserMessagingPlatform.show_privacy_options_form()` ve `consent_information.get_privacy_options_requirement_status() == REQUIRED`) — mevcut kanca `UiData.privacy_options_available()/show_privacy_options` (`scripts/ui/ui_data.gd`) buna bağlanır. Test: sahte köprüyle `AdmobAdsProvider`/`UiData` testi.
- Reklam derecelendirmesi/yaş: `tagForChildDirectedTreatment` ayarlanmaz (13+ hedef, R-3.5). Reklam içeriği filtresi AdMob konsolunda (sahip).
- Doğrulama: `verify.sh`; CİHAZ: Adım 12.

### Adım 7 — Gizlilik politikası bağlantısı (B7)
- `scripts/ui/info_sheet.gd`: "Gizlilik politikası" düğmesi → `OS.shell_open(<URL>)`. URL sabiti tek yerde (`data/` JSON, ör. `data/store.json` → `privacy_policy_url`; boşsa düğme gizli). Yeni metin anahtarı `UI_PRIVACY_POLICY` → `data/i18n/strings.csv` (tr/en/es + yeni diller; **çeviri işçileriyle koordine**, dosyaya yalnız işaretli küçük ekleme — TASKS kuralı). Düğme ≤ 20 karakter (`docs/I18N.md`).
- Test: `tests/unit/test_loc.gd` bütçesi; URL boşken düğmenin yokluğu.
- Doğrulama: ekran görüntüsü aracıyla Ayarlar/Bilgi sayfası.

### Adım 8 — Reklam yerleşimi gözden geçirmesi (R-3.1, R-3.2)
- `AdManager` akışını oku: geçiş reklamı yalnız sonuç/ara ekranında oyuncu "Devam"a bastıktan sonra, **sonraki seviye sahnesi yüklenmeden/oynanış başlamadan** gösterilir; reklam kapanınca oynanış başlar. Seviye başlangıcında ya da oynanış sırasında hiç reklam yok. Ana ekrandan çıkış/geri/home sırasında reklam yok. Ardışık iki interstitial yok (ödüllü sonrası atlanıyor: var).
- Test (varsa genişlet): `ad_pacing` testleri + "ödüllü ardından geçiş reklamı yok" mevcut; ek: "oyun sahnesi aktifken interstitial isteği reddedilir".
- Ödüllü düğmelerin metni ödülü açıkça söyler ("+1 askı için reklam izle", "Jetonları 2x yap").

### Adım 9 — Çevrimiçi kapı ve çevrimdışı deneyim (R-3.18)
- Mevcut `OnlineGate` cihazda denenir (uçak modu → "Bağlantı gerekli" sayfası → Yeniden dene; bağlantı gelince devam; seviye ortasında kopma oyunu kesmez). Uç noktalar `connectivitycheck.gstatic.com`, `cp.cloudflare.com` (gizlilik politikasında belirtilir).
- AdMob/UMP açılış süresi ≤ `consent_timeout_seconds` (8 sn) — kapı + UMP birlikte ilk açılışta kullanıcıyı 10 sn'den fazla bekletmemeli (ölç).

### Adım 10 — Mağaza grafikleri ve metinleri
- Simge 512×512 PNG (alfalı) + adaptif katmanlar; öne çıkan 1024×500 (alfasız); ≥ 5 ekran görüntüsü 1080×1920 (9:16) — `PLAY_LISTING_DRAFT.md` listesi; `tools/` içindeki ekran görüntüsü aracı kullanılır (mevcut). Çıktı klasörü `build/store/` (pakete girmez: `build/*` hariç).
- İlan metni: `PLAY_LISTING_DRAFT.md` (sahip onaylar). Diğer diller çeviriler incelenince.

### Adım 11 — AAB üretimi ve statik denetim (`tools/release_check.sh`, yeni)
Komutlar (cihaz gerekmez; SDK/bundletool kurulduktan sonra):
1. Godot: Dışa Aktar → **Android (release)** → `build/release/camasiripi-release.aab` (ya da `godot --headless --export-release "Android (release)" <yol>`; imza ortam değişkenleri tanımlı).
2. `bundletool dump manifest --bundle=<aab>` → doğrula: `targetSdkVersion=36`, `minSdkVersion=24`; `uses-permission` yalnız `INTERNET`, `ACCESS_NETWORK_STATE`, `com.google.android.gms.permission.AD_ID` (+ `com.android.vending.BILLING`); `com.google.android.gms.ads.APPLICATION_ID` meta-data **gerçek** kimlik; `appCategory`/`isGame` bakılır; `enableOnBackInvokedCallback`.
3. `bundletool dump config --bundle=<aab> | grep alignment` → **PAGE_ALIGNMENT_16K** (4K ise Adım 2'deki AGP/paketleme düzeltilir).
4. `bundletool build-apks --bundle=<aab> --output=build/release/test.apks --connected-device` (ya da `--mode=universal`) → APK'yı aç: `lib/arm64-v8a/*.so` listesi; her `.so` için `llvm-objdump -p ... | grep LOAD` → `align 2**14`; `zipalign -c -P 16 -v 4 <apk>` "Verification successful" (Google belgesi).
5. Boyut: AAB ve tahmini indirme boyutu `docs/size/after.md` (≈ 48 MiB) ile karşılaştırılır; ≥ %20 sapma varsa raporla.
6. Tarama: `strings`/ayrıştırma ile `REPLACE_` ve `ca-app-pub-3940256099942544` kalmadığını doğrula (üretim yapısında).
- Çıktı: `docs/store/release_check_<tarih>.md` (kod işçisi yazar; bu belge değil).

### Adım 12 — CİHAZ testleri (Pixel/üretici cihazı; 16 KB için emülatör/Pixel 8+ geliştirici seçeneği)
Sırayla:
1. Hata ayıklama + Gradle yapısı (test kimlikleriyle) USB ile yükle: açılış, logcat'te `[AdMob] Native plugin ... not found` **olmamalı**; AdMob başlar, ödüllü/interstitial test reklamı gelir; erken kapatınca ödül yok; uçak modunda akış ≤ 3 sn sonra devam.
2. AB UMP: `consent_debug_geography="eea"` + `test_device_ids` (yalnız debug), form gelir, "Gizlilik seçenekleri" düğmesi formu açar. Sonra alanları boşalt.
3. 16 KB: emülatör "Google APIs Experimental 16 KB Page Size ARM 64 v8a" ya da Pixel geliştirici seçeneği; `adb shell getconf PAGE_SIZE` = 16384; uygulama açılır, 10 dk oyna.
4. Android 16 cihaz/emülatör: geri hareketi (menüde geri → çıkış onayı değil, beklenen davranış; oyunda geri → duraklat/menü), çentik/gezinme çubuğu altında düğme kalmıyor (kenardan kenara), tablet sw600dp+ görünüm.
5. Billing (yalnız dahili test kanalına yüklenmiş yapıyla + lisans testi hesabı): fiyat gösterimi, satın alma, anında reklamların kapanması, silip yeniden kurulumda geri yükleme, iptal, 3 gün içinde acknowledge (Play Console'da siparişin "onaylandı" durumu).
6. Ölçümler: açılış süresi, kare süresi (`tools/perf_probe2.gd` benzeri cihaz içi ölçüm), ASTC görüntü kalitesi, bellek. Bulgular `docs/perf/android_device.md` (yeni).
7. Pre-launch raporu (Play Console) → çökme/ANR/erişilebilirlik uyarıları düzeltilir.

### Adım 13 — Belgeleme
- `TASKS.md` "Yayın hazırlığı" satırlarını güncelle (`ci-release`), `CHANGELOG.md`; `docs/MONETIZATION.md` güncelle; bu planın "bitti" kutularını işle.

## 3. Yayın sırası ve gerçekçi süreler

| Aşama | İş | Süre (kaynak) |
|---|---|---|
| A | Sahip: geliştirici hesabı, kimlik/ödeme profili, satıcı hesabı | Satıcı doğrulaması "en çok beş gün" (R-1.3); kayıt doğrulamaları anlık-günlük |
| B | Kod: Adım 1-11 (cihaz olmadan) | 4-7 iş günü (tahmin, ÇIKARIM) |
| C | **Dahili test**: ilk AAB; test kullanıcıları (≤ 100); billing + reklam testleri | Güncellemeler dakikalar içinde ulaşır; ilk yayında bağlantı "birkaç saat" gecikebilir, geçici ad 48 saate dek (R-1.8) |
| D | Play Console: App content, veri güvenliği, derecelendirme, ilan, IAP ürünü | 1-2 gün (sahip) |
| E | **Kapalı test**: ≥ 12 test kullanıcısı, **14 ardışık gün** (R-1.7). Öneri: 15-20 kişi davet et (çıkanlar sayacı bozar). Aynı AAB üretim adayı olabilir; kritik hata çıkarsa sayaç testçiler için sürüm değişse bile sürer (kullanıcının "sürekli katılımı" önemli). | ≥ 14 gün |
| F | "Apply for production" formu → Google incelemesi | "genellikle 7 gün veya daha az, bazen daha uzun" (R-1.7) |
| G | **Üretim sürümü** ilk inceleme | Güncellemeler "7 güne dek" (R-1.10); yeni uygulama için süre yazılı değil — 7 gün varsay |
| H | AdMob: Play ilanı yayına girince uygulamayı mağazaya bağla; `app-ads.txt` taraması | ≤ 24 saat (R-3.4); ilan değişikliği AdMob'a 24 saate dek yansır |
| I | Aşamalı yayın (staged rollout) %10 → %50 → %100; Android vitals ve çökme izleme | Sahip kararı (sayfa okunmadı; ÇIKARIM) |

**Toplam tahmin**: hesap hazır + kod hazır → kapalı test başı (gün 0) → gün 14 başvuru → ~gün 21 üretim erişimi → ~gün 28 yayında. Hesap kurulumu ve kodlama paralel yürütülürse toplam ≈ **5-7 hafta** (yalnız resmi süreler toplanırsa en az 14 + 7 + 7 = 28 gün; ÇIKARIM).

## 4. Yeni yazılacak testler (özet)

| Test dosyası | Kapsam |
|---|---|
| `tests/unit/test_release_guard.gd` | üretim kimliği/placeholder/test-kimliği koruması |
| `tests/unit/test_play_billing_provider.gd` | yeni `BillingClient` akışı (sahte istemciyle), acknowledge, iade, iptal |
| `tests/unit/test_privacy_link.gd` | URL boş → düğme yok; doluysa var; metin bütçesi |
| `tests/unit/test_ads_consent_bridge.gd` | `show_privacy_options` köprüsü (sahte köprü) |
| `tests/unit/test_ad_placement.gd` | oynanış sırasında interstitial reddi |
| `tools/release_check.sh` (betik) | AAB manifest/izin/hizalama/kimlik taraması (Adım 11) |

## 5. Riskler

1. Poing 5.1.0 notlarında Godot alt sınırı 4.4/4.5 çelişkisi var; "4.7.2'ye dek test" yazıyor (R-2.15). İlk Gradle derlemesinde hata çıkarsa eklenti sürümünü değiştirmeden önce hata ayıklama günlüğüyle sahibe raporla.
2. Billing eklentisi 3.x `BillingClient` GDScript sınıfının Godot'ta pakete giriş yolu ve ürün detayı alanları belgede yok → Adım 5'te kaynaktan okunur.
3. Dikey oyun + tabletler: `appCategory=game` istisnasına güvenme; cihazda test (R-2.10).
4. ElevenLabs ticari hak belirsizliği Play'i değil sahibi etkiler (R-3.17).
5. Gerçek AdMob onayı (yeni AdMob hesabı/uygulama incelemesi) süresi bu oturumda resmi sayfadan doğrulanamadı → "reklam sınırlı/hazır değil" durumunda oyun reklamsız devam etmeli (kod böyle).
