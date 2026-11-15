# Yayın durumu — "Clothesline Sort" (Çamaşır İpi), Google Play

Tarih: 2026-11-15, dal `orch/ci-release`. Kural: **tek-yerden-değişir** değerler ilk Play yüklemesine kadar değiştirilebilir (aşağıda "Nerede" sütunu).

## Kararlar ve nerede değişir
| Karar | Değer | Nerede |
|---|---|---|
| Uygulama kimliği | `com.clotheslinesort.game` | `export_presets.cfg` preset.0 `package/unique_name` (Play'e yüklemeden sonra DEĞİŞMEZ) |
| Uygulama adı | "Clothesline Sort" (tr: "Çamaşır İpi", `config/name_localized`) | `package/name` + `project.godot` `config/name_localized` |
| versionCode / versionName | 1 / "1.0.0" | `version/code`, `version/name`; her yüklemeden sonra `docs/store/release_state.json` güncellenir |
| min / target SDK | 24 / 36 | `gradle_build/min_sdk`, `gradle_build/target_sdk` |
| Hedef kitle / kategori | 13+ (çocuklara yönelik değil) / Oyun > Bulmaca | Play Console; kodda `tag_for_under_age_of_consent=false` |
| Mağaza başlığı | "Clothesline Sort: Color Puzzle" (30 karakter) | `PLAY_LISTING_DRAFT.md` / Play Console |
| Ses lisansı | ücretli ElevenLabs planıyla yeniden üretildi | `docs/AUDIO_LICENSE.md` (bu ağaçta var) |
| Gizlilik politikası URL'si | YER TUTUCU `https://example.invalid/...` | `data/store.json` (tek değer) |
| AdMob kimlikleri | test; üretim `REPLACE_*` | `data/ads.json` `admob.production` + `project.godot` `[admob] general/android/app_id` |

## Gereksinim bazında durum
Durumlar: **TAMAM** (kodda/yapılandırmada kanıtlı), **ONAY** (sahibin onayını bekliyor), **SAHİP** (hesap/konsol işi), **CİHAZ** (gerçek cihaz gerekir).

| # | Gereksinim | Durum | Kanıt / not |
|---|---|---|---|
| B2 | Gradle şablonu (`android/`) | **TAMAM** | `godot --headless --install-android-build-template ...` (bu sürümde bayrak var; yalnız `--export-*` ile birlikte çalışır). Şablon = yerel `android_source.zip`; `android/.build_version`=`4.7.2.stable`, `android/build/.gdignore`. Aşağıda "Şablon değerleri". |
| B3 | Hedef API 36 | **TAMAM** | Birleşik manifest: `targetSdkVersion=36`, `minSdkVersion=24` (`tools/aab_inspect.py`) |
| 16 KB | Sayfa hizası | **TAMAM (ELF) / bundletool bayrağı doğrulanamadı** | AGP 8.6.1 (≥ 8.5.1). AAB'deki `libgodot_android.so` ve `libc++_shared.so` `PT_LOAD` hizası 16384; `extractNativeLibs=false`. BundleConfig (bundletool 1.16.0) `PAGE_ALIGNMENT_16K` alanı taşımıyor; `zipalign -c -P 16` APK gerektirir → bundletool ONAY bekliyor. Play yüklemesinde "16 KB uyumlu" uyarısı çıkmaması beklenir ama CİHAZ/Play ile doğrulanmadı. |
| B8 | Simge | **TAMAM** | `assets/icons/app/` (192 ana, 432 adaptif ön/arka/tek renk), `config/icon`; üretici `tools/make_app_icons.py` (yalnız proje sanatı). Mağaza simgesi 512 + öne çıkan 1024x500: `docs/store/assets/` |
| B9 | Yayın ön ayarı | **TAMAM** | paket, sürüm, SDK, izinler (yalnız INTERNET + ACCESS_NETWORK_STATE + kitaplıklarınki), kenardan kenara, dikey, appCategory=game |
| İzinler | Birleşik manifest | **TAMAM** | AD_ID ×2, READ_BASIC_PHONE_STATE, WAKE_LOCK, FOREGROUND_SERVICE kitaplıklardan (kaynakları `ReleaseGuard`/MONETIZATION §3.5); Play Console'da "Reklam kimliği: evet" beyanı SAHİP. WAKE_LOCK/FOREGROUND_SERVICE'i `tools:node="remove"` ile atmak mümkün ama SDK'nın arka plan işini bozabilir → karar sahibin. |
| B4 | İmza | **SAHİP** | Yükleme anahtarı üretilecek: `docs/store/SIGNING.md`. Anahtarsız release dışa aktarım reddedilir (denendi). Debug AAB imzasız çıkıyor (DOĞRULANMADI: release imzası anahtarla denenecek). |
| B1 | Billing eklentisi | **kod TAMAM / eklenti ONAY** | `play_billing_provider.gd` yeni `BillingClient` API'sine yeniden yazıldı, 20 testli (sahte istemci). Eklenti zip'i `docs/store/PENDING_APPROVALS.md` §1. CİHAZ: gerçek satın alma/geri yükleme. |
| B6 | AdMob kimlikleri | **SAHİP** | Konsol işi (OWNER_CHECKLIST). `release_check` placeholder/test kimliğiyle başarısız. |
| UMP | Onay (AB/BK) | **kod TAMAM / CİHAZ** | Onay çözülmeden reklam isteği yok (SDK bile başlamaz); gizlilik seçenekleri girişi Ayarlar'da UMP gerektiriyorsa; testli (sahte köprü). Gerçek UMP formu cihazda AB test coğrafyasıyla denenecek. |
| B7 | Gizlilik politikası | **kod TAMAM / SAHİP** | Ayarlar'da "Gizlilik politikası" düğmesi (`data/store.json`); URL'yi sahip barındırır. Yer tutucu yayın sürümünde gizli + `release_check` hatası. |
| 3.1/3.2 | Reklam yerleşimi | **TAMAM** | Geçiş reklamı yalnız `EcoFlow.maybe_interstitial` (sonuç sayfası "Devam"); `tests/unit/test_ad_placement.gd` yapısal sınırı sabitler; ödül yalnız `rewarded` geri çağrısında (mevcut testler). Açılış/çıkış/oynanışta reklam yok. |
| Çevrimdışı | OnlineGate | **CİHAZ** | Kod mevcut; uçak modu denemesi cihazda. |
| Mağaza grafikleri | ekran görüntüsü, öne çıkan | **TAMAM (aday)** | `docs/store/assets/`: icon_512, feature_1024x500, 6 en ekran görüntüsü (810x1440 gerçek pencereden 1080x1920'ye büyütüldü). Sahip onayı + es/ja/… sürümleri `tools/store_shots.sh <dizin> <dil>` ile. |
| B5 | Kapalı test 12 kişi x 14 gün | **SAHİP** | PLAY_RELEASE_PLAN §3 |
| B10 | Ses lisansı | **TAMAM (başka işte)** | `docs/AUDIO_LICENSE.md` |

## Derleme sonucu (bu makinede, hata ayıklama imzasız AAB, yayın ön ayarıyla)
- Komut: `JAVA_HOME=<JDK17> godot --headless --path . --export-debug "Android (release)" build/release/camasiripi-debug.aab` (~1 dk, Gradle önbelleği sıcakken).
- Çıktı: `build/release/camasiripi-debug.aab` — **63.0 MiB** (debug şablonu; release şablonu daha küçük olur, `docs/size/after.md` ≈ 48 MiB beklentisiyle karşılaştırma release AAB'de yapılacak).
- Birleşik manifest: paket `com.clotheslinesort.game`, versionCode 1 / "1.0.0", min 24, target 36, `appCategory=game`, `isGame=true`, ikon `@mipmap/icon`
  (adaptif + tek renk katman dahil), etiket `@string/godot_project_name_string` (varsayılan "Clothesline Sort", tr "Çamaşır İpi" — `values-tr` ile doğrulandı),
  `APPLICATION_ID` = Google TEST kimliği (beklenen; `release_check` bunu yayında reddeder), izinler yukarıdaki liste.
- Yerel kitaplıklar: yalnız `arm64-v8a` (`libgodot_android.so`, `libc++_shared.so`), ikisi de 16 KB hizalı.
- `tools/release_check.sh` bu AAB üzerinde çalışır ve dürüstçe BAŞARISIZ olur (AdMob üretim kimliği/imza/gizlilik URL'si yok, AAB debug).
- Release dışa aktarımı: anahtar yokken `Kod İmzalama: Sürüm anahtar deposu bulunamadı, dışa aktarılamıyor.` (beklenen).
- NDK GEREKMEDİ (debug); release için bkz. `PENDING_APPROVALS.md` §2. Gradle daemon'ları durduruldu.

## Şablon değerleri (`android/build/config.gradle`, 4.7.2.stable)
AGP **8.6.1**, Gradle **8.11.1** (wrapper), Kotlin 2.1.21, Java **17**, compileSdk **36**, targetSdk **36**, minSdk **24**, buildTools 36.1.0 (SDK'da var),
ndkVersion 29.0.14206865 (kurulu değil; debug için gerekmedi). Plan beklentisi (AGP 8.13.2) farklı çıktı ama 8.6.1 ≥ 8.5.1 (16 KB paketleme) olduğundan engel yok.
Depoya giren: şablon metin kaynakları ~155 KB (`android/.build_version`, `android/build/{build,config,settings}.gradle`, gradle.properties, wrapper, `src/main`, `res/values/themes.xml`, ...).
Girmeyen (`.gitignore`): `android/build/libs/` (216 MB godot-lib AAR'ları), `build/`, `.gradle/`, `assetPackInstallTime/{build,src}`, üretilen mipmap'ler ve `godot_project_name_string.xml`.
`build.gradle` Poing eklentisince export sırasında yamanır (sonuna `configurations.configureEach { exclude play-services-ads ... }` eklenir); yamalı hali depodadır.
Temiz klonda şablonu geri kurmak: `godot --headless --path . --install-android-build-template --export-debug "Android (release)" build/x.aab` (yerel şablon zip'inden; indirme yok).

## Release AAB nasıl üretilir (onaylar ve kimlikler gelince)
1. Sahip: AdMob uygulaması + 2 birim; Play Console'da uygulama (paket `com.clotheslinesort.game`), `remove_ads` ürünü; gizlilik politikası URL'si; yükleme anahtarı (SIGNING.md).
2. Kod: `data/ads.json` `production.*` + `mode:"production"`; `project.godot` `[admob] general/android/app_id` aynı uygulama kimliği; `data/store.json` URL; Billing eklentisi (PENDING §1);
   `export_presets.cfg` `version/code` > `docs/store/release_state.json`.
3. `export GODOT_ANDROID_KEYSTORE_RELEASE_*` + `JAVA_HOME`; `godot --headless --path . --export-release "Android (release)" build/release/camasiripi-release.aab`.
4. `bash tools/release_check.sh build/release/camasiripi-release.aab` → **SONUC: GECTI**. Ardından `docs/store/release_check_<tarih>.md` notu.
5. Dahili test kanalına yükle → cihaz testleri (`PLAY_RELEASE_PLAN.md` Adım 12) → kapalı test (14 gün) → üretim.

## Sahibin sıralı kalan işleri
1. Play Console geliştirici hesabı + kimlik/satıcı doğrulaması (OWNER_CHECKLIST).
2. Yükleme anahtarı (SIGNING.md) ve güvenli yedek.
3. AdMob hesabı, uygulama, ödüllü + geçiş birimleri; `app-ads.txt` + geliştirici web sitesi; GDPR iletisi (AdMob > Gizlilik ve mesajlaşma).
4. Gizlilik politikasını (taslak `PRIVACY_POLICY_DRAFT.md`) barındır, URL'yi `data/store.json`'a yaz.
5. Billing eklentisi indirme onayı (PENDING §1); gerekirse NDK onayı (§2).
6. Play Console: Uygulama içeriği (veri güvenliği `DATA_SAFETY_ANSWERS.md`, Reklam kimliği beyanı, hedef kitle 13+, derecelendirme), `remove_ads` ürünü, ilan metni/grafikleri onayı.
7. Cihaz testleri (Billing, UMP AB, çevrimdışı, 16 KB, geri hareketi, kenardan kenara).
8. Kapalı test: ≥ 12 test kullanıcısı × 14 gün → üretim başvurusu.

## Doğrulanamayanlar (dürüst liste)
Gerçek cihazda hiçbir şey çalıştırılmadı (AdMob/UMP/Billing native katmanı, geri hareketi, kenardan kenara, tablet davranışı); release imzası; bundletool 16K bayrağı;
Billing `purchase_option_id` davranışı; ekran görüntüleri 1080x1920'ye büyütülmüş 810x1440 yakalamalardır (ekran yüksekliği gerçek 1920 pencereye izin vermedi).
Oynanış akışı dosyalarına dokunulmadığı için `play_probe` çalıştırılmadı.
