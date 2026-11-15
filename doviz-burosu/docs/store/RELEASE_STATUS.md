# Yayın durumu — "Döviz Bürosu", Google Play (T-R1 Android derleme/imza hattı; T-A2/T-S1 ile güncellendi)

Tarih: 2026-11-15, dallar `orch/dv-r1` (hat), `orch/dv-a2` (ayarlar/Hakkında/mağaza belgeleri). Kural: **tek-yerden-değişir** değerler ilk Play yüklemesine kadar değiştirilebilir ("Nerede" sütunu).

## Kararlar ve nerede değişir
| Karar | Değer | Nerede |
|---|---|---|
| Uygulama kimliği | `com.dovizburosu.game` | `export_presets.cfg` her üç preset `package/unique_name` (yüklemeden sonra DEĞİŞMEZ) |
| Uygulama adı (etiket) | EN (varsayılan) "Pahalistan Exchange Desk", TR "Döviz Bürosu" (sahip kararı: adı lider seçti, ilan taslağıyla aynı) | `project.godot` `config/name` + `config/name_localized`; `export_presets.cfg` `package/name` BOŞ (3 preset; Godot proje adını/yerelleştirilmişini kullanır); oyun içi: `strings.csv` `APP_TITLE`. Uygulama kimliği aynı. Ad müsaitlik/marka taraması hâlâ sahipte (`OWNER_CHECKLIST.md`). |
| versionCode / versionName | 1 / "1.0.0" | `version/code`, `version/name` (3 preset); her yüklemeden sonra `tools/release_state.json` `last_uploaded_version_code` güncellenir. `project.godot config/version` = "1.0.0" (preset ile aynı; kapı `version_name_mismatch_project` ile denetler; Hakkında ekranı bu değeri gösterir) |
| min / target SDK | 24 / 36 | `gradle_build/min_sdk`, `gradle_build/target_sdk` |
| Kategori / hedef kitle | Oyun (`package/app_category=2`) / 13+ | preset; Play Console |
| Gizlilik politikası URL'si | yer tutucu (`https://example.com/...`) | **`data/ads_ids.json` `privacy_policy_url`** (https://, sahibin barındırdığı adres) — oyun içi bağlantı (Ayarlar > Gizlilik politikası; yer tutucuyken düğme gizli) ve yayın kapısı bu TEK alanı okur. `tools/release_state.json`'da artık yalnız `last_uploaded_version_code` vardır. Metin: `docs/PRIVACY_POLICY.md` (+`.tr.md`) |
| AdMob/Billing | test; gerçek yok; `play_billing=false` | `data/ads_ids.json` (T-M1/sahip) + `python3 tools/sync_ads_config.py` |
| İmza | yok (sahip üretecek) | ortam değişkenleri, `docs/store/SIGNING.md` |

## T-A2 / T-S1 ile eklenenler (2026-11-15)
| Madde | Durum | Not |
|---|---|---|
| Ayarlar (ana ses, yazı boyutu, renk körü, hareketi azalt, titreşim, dil, öğreticiyi yeniden oynat, gizlilik, politika, geri yükle) | **TAMAM (kod+test)** | `scripts/ui/settings_screen.gd`; `tests/unit/test_accessibility.gd`. Cihazda dokunma boyutu/okunabilirlik doğrulanmadı (CİHAZ) |
| Hakkında + lisanslar + "simülasyondur" bildirimi | **TAMAM (kod+test)** | `scripts/ui/about_sheet.gd`, `data/licenses.json` (üreten: `tools/build_licenses.py`); metinler kaynak dosyalarla birebir (`test_about.gd`). AdMob eklentisinde LICENSE dosyası yok → metin plugin.cfg'deki telif satırı + standart MIT; **sahip yukarı akıştaki LICENSE ile değiştirmeli** |
| Kullanılmayan yazı tipleri (`Baloo2.ttf`, `PixelifySans.ttf`) | **SAHİP ONAYI** | Silinmedi. Şu an pakete giriyor (`export_filter=all_resources`) → OFL gereği lisansları Hakkında'da listeli. Silinirse `tools/build_licenses.py` içinden kayıtlarını da çıkar |
| Gizlilik politikası (EN + TR) | **TASLAK** | `docs/PRIVACY_POLICY.md`, `docs/PRIVACY_POLICY.tr.md`; sahip yer tutucuları doldurur, barındırır |
| Play ilanı, Veri güvenliği/IARC/hedef kitle/finansal özellik cevapları, sahip listesi | **TASLAK** | `docs/store/PLAY_LISTING.md`, `DATA_SAFETY_ANSWERS.md`, `OWNER_CHECKLIST.md` |
| Oyun içi onay metinleri (`MON_NOTICE_TEXT`/`MON_FORM_TEXT`) | **GÜNCELLENDİ** | Politika ve Veri güvenliği ile aynı üç olguyu söyler (reklam kimliği/IP/etkileşim AdMob; hesap yok; analitik yok) |

## Gereksinim bazında durum
**TAMAM** = yapılandırmada/derlemede kanıtlı; **SAHİP** = hesap/konsol/karar; **CİHAZ** = gerçek cihaz gerekir; **ONAY** = indirme onayı (`PENDING_APPROVALS.md`).

| Gereksinim | Durum | Kanıt / not |
|---|---|---|
| Gradle şablonu (`android/`) | **TAMAM** | `godot --headless --path . --install-android-build-template --export-debug "Android Release" build/release/x.aab` yerel `android_source.zip`'ten kurar (indirme yok). `android/.build_version`=`4.7.2.stable`. Depoya giren ~156 KB metin (36 dosya). |
| Hedef API 36 / min 24 | **TAMAM** | Birleşik manifest: `targetSdkVersion=36`, `minSdkVersion=24`. AGP 8.6.1, Gradle wrapper, Kotlin 2.1.21, Java 17, compileSdk 36, build-tools 36.1.0 (SDK'da var). |
| Yayın preset'i (AAB, arm64) | **TAMAM** | "Android Release": `export_format=1`, yalnız `arm64-v8a`, kenardan kenara + immersive, `allowBackup=false`, `appCategory=game`, `isGame=true`. |
| Dikey yön | **TAMAM** | Manifest ana etkinlik `screenOrientation=portrait` (`project.godot` `window/handheld/orientation=1` -> Godot yazar). Şablonun `landscape` varsayılanı ezildi. |
| İzinler | **TAMAM (+karar)** | Preset: INTERNET, ACCESS_NETWORK_STATE, **VIBRATE (eklendi; `Feel.haptic` için eksikti)**. Birleşik manifest ek: AD_ID (2), ACCESS_ADSERVICES_AD_ID/ATTRIBUTION/TOPICS, WAKE_LOCK, FOREGROUND_SERVICE (reklam SDK'sı/androidx.work), `com.android.vending.BILLING`, `<paket>.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`. Hepsi `ReleaseGuard.ALLOWED_PERMISSIONS`'ta; başkası kapıda hata. Roadmap "başka izin yok" der: SDK kaynaklı bu izinler gerçektir. ACCESS_ADSERVICES_ATTRIBUTION/TOPICS ve WAKE_LOCK/FOREGROUND_SERVICE `android/build/src/main/AndroidManifest.xml`'e `tools:node="remove"` ile atılabilir ama SDK'nın arka plan/atıf işini bozabilir -> sahip kararı. Play "Reklam kimliği: evet" beyanı gerekir. |
| Titreşimin cihazda çalışması | **CİHAZ** | İzin artık manifestte; gerçek cihazda `Feel.haptic` doğrulanmadı (cihaz yok). |
| 16 KB sayfa hizası | **TAMAM (ELF) / bundletool bayrağı doğrulanamadı** | AAB'deki `libgodot_android.so` ve `libc++_shared.so` `PT_LOAD` hizası 16384, `extractNativeLibs=false`. `BundleConfig` `PAGE_ALIGNMENT_16K` alanı yok; bundletool onayı bekliyor (PENDING §2). Kapı: `aab_native_lib_not_16k_aligned`. |
| İkon | **TAMAM (ara çözüm)** | `tools/make_launcher_icons.py` -> `assets/launcher_icons/{icon,adaptive_fg,adaptive_bg,adaptive_mono}.png`, preset `launcher_icons/*`; AAB'de `icon=@mipmap/icon`. T-R2 marka sanatını getirince yalnız preset yolları değişir. 512 Play ikonu/öne çıkan görsel T-R2. |
| Açılış ekranı | **T-R2/lider** | `boot_splash` hâlâ yok (project.godot lider). |
| R8/ProGuard | **KAPALI (karar)** | Şablon `release` buildType'ında `minifyEnabled` yok; Godot oyunlarında varsayılan. Eklenti sınıfları yansımayla çağrılır, açmak risk: öneri **kapalı kalsın**. |
| `profileable` | **KARAR: kalsın** | Şablon `src/main` manifestinde `<profileable shell="true">` (release dahil). Yalnız `adb shell` profilleme açar; Play reddi sebebi değil, performans turu (T-P1) için işe yarar. Kaldırmak: o satırı `android/build/src/main/AndroidManifest.xml`'den silmek. |
| Yayın kapısı | **TAMAM** | `tools/release_guard.gd` (saf, 24 testli `tests/unit/test_release_guard.gd`) + `tools/release_check.sh/.gd` + `tools/aab_inspect.py` + `tools/release_build.sh`. Kapı geçmeden AAB üretilmez. |
| İmza | **SAHİP** | `docs/store/SIGNING.md`. Anahtarsız `--export-release` reddedilir (denendi). Debug AAB imzasız çıkar (release imzası DOĞRULANMADI). |
| Billing/AdMob gerçek kimlik, UMP, gizlilik URL'si | **SAHİP / T-M1 / T-S1** | Kapıda `ads_*`, `play_billing_disabled`, `privacy_policy_url_missing` olarak görünür. |
| NDK | **ONAY (gerekirse)** | Debug için gerekmedi; release strip'te gerekebilir (PENDING §1). |
| Boyut | **ÖLÇÜLDÜ (debug)** | Debug AAB 43 032 088 B (41,0 MiB); `libgodot_android.so` 76 MB açılmış (debug şablonu). Release AAB ölçümü anahtardan sonra; bundletool indirme tahmini onaya bağlı. Özel şablon önerisi: T-P1 raporu. |

## Derleme denemesi sonucu (bu makinede, "Android Release" preset'iyle debug şablonu)
- Komut: `tools/release_build.sh --debug-aab` (= `JAVA_HOME=<JDK17> godot --headless --path . --export-debug "Android Release" build/release/doviz-burosu-debug.aab`, ~2 dk).
- Çıktı: `build/release/doviz-burosu-debug.aab`, **43 032 088 bayt**, SHA-256 `0ede67d120e1567ac48bc613723d7edb1d85be658a8cae24dd216c81013dc759` (git dışı).
- Birleşik manifest: paket `com.dovizburosu.game`, versionCode 1 / "1.0.0", min 24, target 36, `debuggable=true` (debug şablonu), `appCategory=game`, ikon `@mipmap/icon`, yalnız `arm64-v8a`, `screenOrientation=portrait`, `allowBackup=false`, AdMob `APPLICATION_ID` = Google TEST kimliği (beklenen), `data/ads_ids.json` mode=test.
- Gradle daemon'ları durduruldu (`./gradlew --stop`, bitiş kontrolü: çalışan daemon yok).
- `tools/release_check.sh build/release/doviz-burosu-debug.aab` dürüstçe BAŞARISIZ olur (test kimlikleri, anahtar yok, debug, imzasız, gizlilik URL'si yok, billing kapalı, `config/version` uyuşmuyor).

## Şablonu yeniden kurma (temiz klon)
`android/` kaynakları depodadır; eksikse/bozuksa: `godot --headless --path . --install-android-build-template --export-debug "Android Release" build/release/x.aab` (`build/release/` klasörü olmalı; `tools/release_build.sh` kendisi kurar).
Depoya girmeyen: `android/build/libs/` (godot-lib AAR ~206 MB), `android/build/build/` (Gradle çıktısı ~900 MB), `.gradle/`, üretilen mipmap'ler, `godot_project_name_string.xml`, `src/debug/`.
`.gitignore` kuralları buna göre; `build/*` zaten dışarıda.

## Release AAB nasıl üretilir (kimlikler ve anahtar gelince)
1. Sahip: Play Console uygulaması (`com.dovizburosu.game`), AdMob uygulaması + ödüllü/geçiş birimleri, `no_ads` ürünü, gizlilik URL'si, yükleme anahtarı (SIGNING.md).
2. `data/ads_ids.json`: `mode:"real"`, `android.real_*` dolu, `providers.play_billing:true` (T-M1/lider bayrağı) -> `python3 tools/sync_ads_config.py`.
3. `data/ads_ids.json` `privacy_policy_url` (gerçek https adresi); `project.godot config/version` = preset `version/name`; `version/code` > `last_uploaded_version_code`.
4. `export GODOT_ANDROID_KEYSTORE_RELEASE_{PATH,USER,PASSWORD}` (SIGNING.md) ve (gerekirse) `JAVA_HOME`.
5. `tools/release_build.sh` -> kapı geçerse `build/release/doviz-burosu-release.aab`; boyut ve SHA-256 basılır. Yalnız denetim: `tools/release_check.sh [--latest|yol.aab]`.
6. Yükleme sonrası `tools/release_state.json` güncellenir. Dahili test -> cihaz turu -> kapalı test (≥12 kişi × 14 gün, Play Console'daki güncel şarta bak) -> üretim.

## Sahibin sıralı kalan işleri
1. Play Console geliştirici hesabı + kimlik doğrulama (kapalı test süresi en uzun bekleme; tester bulmayı hemen başlat).
2. Yükleme anahtarı üret + yedekle (SIGNING.md).
3. Paket kimliği (`com.dovizburosu.game`) ve İngilizce mağaza adı kararını onayla (ilk yüklemeden sonra değişmez).
4. AdMob hesabı, uygulama, ödüllü + geçiş birimleri -> `data/ads_ids.json` `real_*` (T-M1 ile); Play Console `no_ads` ürünü.
5. Gizlilik politikasını (T-S1: `docs/PRIVACY_POLICY.md`, TR: `.tr.md`) barındır, URL'yi `data/ads_ids.json` `privacy_policy_url` alanına yaz (`tools/release_state.json` değil).
6. Play Console: Uygulama içeriği (Reklam kimliği: evet, Veri güvenliği, hedef kitle 13+, IARC), **Finansal özellikler beyanı** (finansal özellik yok; kategori Oyun) — cevaplar `docs/store/DATA_SAFETY_ANSWERS.md`; mağaza metni `docs/store/PLAY_LISTING.md`; grafikler T-R2. Tam sahip listesi: `docs/store/OWNER_CHECKLIST.md`.
7. Gerçek cihaz turu: titreşim, kenardan kenara/çentik, geri tuşu, 16 KB cihazda açılış, test reklamı, lisans testçisiyle satın alma.
8. Gerekirse NDK/bundletool onayı (PENDING_APPROVALS.md).
9. Kapalı test -> üretim başvurusu -> aşamalı yayın.

## Doğrulanamayanlar (dürüst liste)
Gerçek cihazda hiçbir şey çalıştırılmadı (titreşim, kenardan kenara, AdMob/Billing native katmanı); release imzası ve release şablonunun NDK gereksinimi (anahtar yok); bundletool 16 KB bayrağı ve indirme boyutu tahmini.
