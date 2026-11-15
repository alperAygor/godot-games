# Sahibin onayını bekleyen adımlar (indirme / SDK / lisans)

Bu işçi yalnız Gradle'ın standart Maven depolarından kendiliğinden çektiklerini indirdi (Gradle 8.11.1 dağıtımı, AndroidX, Google Mobile Ads
Next-Gen SDK 1.4.0). Aşağıdakiler **yapılmadı**; onay verilirse komutlar aynen çalıştırılır.

## 1. GodotGooglePlayBilling 3.3.0 eklentisi — TAMAM (2026-11-15, sahip onayıyla)
- Kaynak: https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/tag/3.3.0 (yayın 2026-07-27, MIT); tek dosya `godot-google-play-billing.zip`.
- Doğrulama: **43 050 bayt** (GitHub API `assets[0].size` ile aynı), **SHA-256 `20d75623d6f337f08d8283c83098b73678d5f575e39247af5a8eb80588b18568`**
  (GitHub API `digest` alanıyla aynı). Proje DIŞINDA, boş bir dizine indirildi; içerik çalıştırılmadan `unzip -Z -l` ile listelendi: yalnızca
  `GodotGooglePlayBilling/` altında 10 giriş, yol atlama (`..`/mutlak yol) yok, çalıştırılabilir/betik yok.
- Dosyalar (hepsi `addons/GodotGooglePlayBilling/` altına): `plugin.cfg` (v3.3.0), `export_plugin.gd`, `BillingClient.gd` (`class_name BillingClient`, zip kökünde —
  `export_scripts/` DEĞİL), `LICENSE` (MIT, "Copyright (c) 2020 Godot Engine contributors"), `bin/debug/GodotGooglePlayBilling-debug.aar` (19 665 B),
  `bin/release/GodotGooglePlayBilling-release.aar` (18 307 B). Zip kökü zaten `GodotGooglePlayBilling/` olduğundan "asset root" sorunu yok.
- Etkinleştirildi: `project.godot` `[editor_plugins] enabled` listesinde `res://addons/GodotGooglePlayBilling/plugin.cfg`. Plugin Gradle'a
  `com.android.billingclient:billing-ktx:9.1.0` ekler (Maven'den gelir; AAB'de doğrulandı). `exclude_filter`'da eklenti YOK: `BillingClient.gd` pakete `.gdc` olarak girer.
  `Android (test apk)` ön ayarı Gradle'sızdır; native katman girmez (yalnız `BillingClient.gd` betiği pakete girer, masaüstünde/sürümsüz cihazda no-op).
- Lisans bildirimi: oyunda "hakkında/lisanslar" ekranı yok; MIT metni `addons/GodotGooglePlayBilling/LICENSE` dosyasında depoda durur (sürüm paketine .md/lisans
  filtresiyle değil, kaynak olarak girer). Play listesi/gizlilik sayfasında üçüncü taraf bildirimi istenirse bu dosya kaynak alınır.
- Cihazda doğrulanacak (hâlâ): `purchase()` boş `purchase_option_id` ile tek seçenekli üründe çalışıyor mu; acknowledge zamanlaması (3 gün); lisans-test hesabıyla gerçek satın alma/geri yükleme.

## 2. Android SDK bileşenleri
- **NDK gerekmedi**: şablon `ndkVersion 29.0.14206865` yazar ama debug AAB NDK olmadan başarıyla üretildi (strip yok, `debugSymbolLevel NONE`).
  **Release** AAB'de strip adımı NDK isteyebilir: ilk gerçek release derlemesinde hata çıkarsa (kod: "NDK ... not found"):
  `~/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager "ndk;29.0.14206865"` (lisans kabulü sahibe aittir; ~1 GB). Onaysız çalıştırılmadı.
- Lisans kabulü (`sdkmanager --licenses`) yapılmadı; mevcut `licenses/` klasörü yeterli oldu.

## 3. bundletool (isteğe bağlı)
- AAB'yi cihaz APK'sına çevirip `zipalign -c -P 16` ile 16 KB sayfa hizasını APK düzeyinde denemek için gerekir. Gerekmedi: `tools/aab_inspect.py`
  AAB içindeki `.so` dosyalarının ELF `PT_LOAD` hizasını doğrudan okur (arm64 `libgodot_android.so` ve `libc++_shared.so` = 16384 ✔).
- Kaynak: https://github.com/google/bundletool/releases (jar, Apache-2.0). `bundletool dump config` ile `PAGE_ALIGNMENT_16K` bayrağı görülebilir;
  AGP 8.6.1'in ürettiği BundleConfig 1.16.0 bu alanı taşımıyor (bkz. RELEASE_STATUS.md).

## 4. Sahibin hesap işleri (kod işçisi yapamaz)
Bkz. `docs/store/OWNER_CHECKLIST.md` ve `docs/store/SIGNING.md` (yükleme anahtarı), `docs/store/RELEASE_STATUS.md` (sıralı liste).
