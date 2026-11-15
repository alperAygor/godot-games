# Sahibin onayını bekleyen adımlar (indirme / SDK / lisans)

Bu işçi yalnız Gradle'ın standart Maven depolarından kendiliğinden çektiklerini indirdi (Gradle 8.11.1 dağıtımı, AndroidX, Google Mobile Ads
Next-Gen SDK 1.4.0). Aşağıdakiler **yapılmadı**; onay verilirse komutlar aynen çalıştırılır.

## 1. GodotGooglePlayBilling 3.3.0 eklentisi (Billing / "Reklamları kaldır")
- Kaynak: https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/tag/3.3.0 (yayın tarihi 2026-07-27, MIT)
- Dosya: `godot-google-play-billing.zip` — **43 050 bayt** (GitHub API `assets[0].size`)
- Hedef: zip içeriği `addons/GodotGooglePlayBilling/` altına (AssetLib kurulumunda "Ignore asset root" KAPALI). Zip'in tam dizin düzeni
  indirilmediği için görülmedi; beklenen: `plugin.cfg`, `export_plugin.gd`, `BillingClient.gd`, `bin/debug|release/GodotGooglePlayBilling-*.aar`
  (kaynak: `export_scripts/export_plugin.gd` AAR yollarını `GodotGooglePlayBilling/bin/<debug|release>/GodotGooglePlayBilling-<...>.aar` olarak verir).
- Etkinleştirme: `project.godot` `[editor_plugins] enabled` listesine `res://addons/GodotGooglePlayBilling/plugin.cfg` eklenir
  (Proje Ayarları > Eklentiler). Export ön ayarı Gradle'lı olduğundan ek ayar yok; plugin Gradle'a `com.android.billingclient:billing-ktx:9.1.0` ekler (Maven'den gelir).
- Kurulduktan sonra: `exclude_filter`'da `addons/GodotGooglePlayBilling/*` YOK (BillingClient.gd pakete girmeli); `Android (test apk)` ön ayarı
  Gradle'sız olduğundan eklentiyi içermez, dokunulmaz. `bash tools/release_check.sh` birleşik manifestte `com.android.vending.BILLING` izni ve
  boyut farkını denetler (izin `ReleaseGuard.ALLOWED_PERMISSIONS`'ta zaten var).
- Doğrulanacak (cihaz): `purchase()` boş `purchase_option_id` ile tek seçenekli üründe çalışıyor mu; `BillingClient.gd` zip'te hangi yolda.

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
