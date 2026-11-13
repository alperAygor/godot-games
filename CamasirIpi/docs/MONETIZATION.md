# Çamaşır İpi — Para kazanma (AdMob + Google Play Faturalandırma)

Bu belge, kodun hazır olduğu ama **elle yapılması gereken** adımları anlatır. Poing Studios AdMob
eklentisi **v5.1.0** projeye kuruludur (`addons/admob/`, yalnız temel `ads` modülü; aracılık/mediation
bağdaştırıcıları YOK). Masaüstünde oyun kendi sahte sağlayıcısını (`MockAdsProvider`) kullanır;
Android cihazda eklentinin native tekil nesneleri bulunursa kendiliğinden `AdmobAdsProvider` devreye girer.
Google Play Faturalandırma eklentisi henüz indirilmedi.

## 1. Oyundaki kurallar (kullanıcı kararları)

| Konu | Kural |
|---|---|
| Kayıpta devam | **Yalnız ödüllü reklamla**, seviye başına bir kez (+1 askı). Jetonla devam yok. |
| Jeton harcama | Yalnız güçlendirici ve kaplama (makine yükseltmesi ayrı işçide). |
| 2x jeton | Yalnız **kazanmada**, ödüllü reklamla. Kayıpta jeton verilmez. |
| Geçiş reklamı | 4. seviyeden itibaren **her seviye geçişinde** ("Devam"). İlk 3 seviye reklamsız. Oyun sırasında asla. |
| İstisna 1 | "Reklamları kaldır" alındıysa geçiş reklamı asla. Ödüllü reklamlar açık kalır. (Banner yok.) |
| İstisna 2 | Oyuncu o geçişte ödüllü reklam izlediyse (ör. 2x) hemen ardından geçiş reklamı gösterilmez. |
| Reklam yoksa | Reklam hazır değilse ya da 3 sn içinde ekrana gelmezse akış sessizce devam eder; "Devam" asla takılmaz. |

Değerler: `data/balance.json` (`interstitial.first_level`, `shop`, `booster_cost`),
`data/ads.json` (yerleşim limitleri, `settings.show_start_timeout_seconds`, `admob` bloğu).
Karar fonksiyonu: `scripts/core/ad_pacing.gd` (saf, birim testli).

## 2. Mimari (nerede ne var)

- `scripts/autoload/AdManager.gd` — ödüllü/geçiş orkestrasyonu, limitler, zaman aşımı. Sağlayıcı seçimi:
  AdMob eklentisi varsa `AdmobAdsProvider`; yoksa hata ayıklama sürümünde `MockAdsProvider`; yayın sürümünde `NoAdsProvider`.
- `scripts/services/admob_ads_provider.gd` — durum makinesi (ön yükleme, yeniden deneme, ödül/kapanış). Eklentiden bağımsız, sahte köprüyle test edilir.
- `scripts/services/poing_admob_bridge.gd` — **Poing Studios godot-admob-plugin** çağrıları (tek dosya; eklenti API'si değişirse yalnız burası güncellenir).
- `scripts/services/iap_provider.gd` (arayüz), `mock_iap_provider.gd`, `play_billing_provider.gd` (**GodotGooglePlayBilling** tekil nesnesi), `iap_service.gd` (seçim + sahiplik + açılış doğrulaması).
  Servis autoload değildir; `Boot` ve `ShopScreen` `IapService.ensure(get_tree())` çağırır.
- Sahiplik: `Progress` modül `"shop"`, anahtar `"remove_ads"` (`Progress.remove_ads_owned()`). Mağaza hazırsa her açılışta Play'den yeniden doğrulanır; Play sorguyu başarıyla yanıtlayıp ürünü görmezse (iade) kayıt temizlenir.
- Mağaza: `scenes/shop/Shop.tscn`, `scripts/shop/shop.gd` (`ShopScreen.open(parent)`), kurallar `scripts/shop/shop_logic.gd`.
- Kaplamalar: `data/skins.json`, `scripts/skins/` (`SkinCatalog`, `SkinStore`, `SkinLook`, `RopePainter`), mandal dokuları `assets/sprites/skins/` (üretici: `tools/make_pin_skins.py`).

## 3. AdMob — elle yapılacaklar

### 3.1 Eklenti kurulumu (YAPILDI) ve kalan Android adımları

**Projede hazır olanlar** (v5.1.0, MIT lisanslı, `addons/admob/LICENSE`):
- `addons/admob/{plugin.cfg,admob.gd,gdscript/src,internal/*}` — GDScript API + editör/export eklentisi + masaüstü mock'u.
- `addons/admob/android/bin/package.gd` + `addons/admob/android/bin/ads/` — Godot 4.7.2 Android şablonu (yalnız `ads`:
  `poing-godot-admob-{ads,core}-{debug,release}.aar` ve `poing_godot_admob_ads.gd`; ~280 KB). Eklenti bunları
  yoksa internetten indirmeye çalışır; dosyalar depoda olduğu için indirme gerekmez.
- `addons/admob/ios/bin/package.gd` — iOS ikilileri için **yer tutucu**: eklenti headless editörde (`godot --import`, CI)
  iOS ikililerini yoksa `curl` ile indirmeye kalkar; bu dosya bunu engeller. Proje iOS hedeflemiyor (`admob/general/ios/enabled=false`).
- `project.godot`: `[editor_plugins] enabled=…admob/plugin.cfg`, `[admob] general/ios/enabled=false`.
  (Android `enabled=true` ve `app_id` = Google TEST kimliği eklentinin varsayılanıdır; bu yüzden dosyada görünmez.
  Godot editörü/`--import` project.godot'u yeniden yazar; dosya başı yorumları bu yüzden kalmayabilir.)
- Sürümler: eklenti v5.1.0 + AAR v5.1.0 + Godot 4.7.2; Google Mobile Ads **Next-Gen SDK 1.4.0** (Gradle bağımlılığı olarak çekilir).

**Boyut/dışlama:** `csharp/`, `docs/`, `skills/`, örnek sahneler, bağış görselleri, çeviriler eklentiden çıkarıldı
(`addons/admob/csharp/.gdignore` var). Eklenti toplamı ≈ 1,4 MB (kaynak ağacı); pakete giren kısım aşağıdaki süzgeçle ≈ 0,57 MB (GDScript API kaynağı; paketlemede sıkışır).
Export ön ayarı oluşturulurken **Resources > Filters to exclude** alanına şunu yazın:
```
addons/admob/android/*, addons/admob/ios/*, addons/admob/admob.gd, addons/admob/internal/editor/*, addons/admob/internal/exporters/*, addons/admob/internal/services/*, addons/admob/internal/mock/*, addons/admob/assets/*
```
Çalışma anında yalnız `addons/admob/gdscript/src/**`, `internal/version/plugin_version.gd` ve (export eklentisinin eklediği) `plugin.cfg` gerekir.
Eklenti kodu tipsizdir; Godot'un varsayılan `debug/gdscript/warnings/exclude_addons=true` ayarı sayesinde projedeki
"tipsiz bildirim = hata" kuralı eklentiye uygulanmaz (ek ayar gerekmedi).

**Elle yapılacaklar (Android Studio/Gradle gerektirir):**
1. Godot editöründe projeyi açın; *Project Settings > Plugins*'te **AdMob** işaretli olmalı (project.godot'ta zaten etkin).
2. *Project > Install Android Build Template* → `res://android/build/` oluşur (`.gitignore` `build/` ile hariç tutar; her makinede yeniden kurulur).
3. *Project > Export > Add… > Android*: **Use Gradle Build** AÇIK olmalı (kapalıyken eklenti export'ta hata verir: "Prebuilt APK export is not supported").
   Bu eklentide ayrı bir "Plugins" onay kutusu yoktur: Android tarafı `EditorExportPlugin` olarak otomatik eklenir
   (AAR'lar, Gradle bağımlılıkları, `APPLICATION_ID` meta-data'sı). Aç/kapa anahtarı *Project Settings > General > Admob > General > Android > Enabled*'dır.
   Depoda `export_presets.cfg` vardır (`Android (release)`: AAB, Gradle, yalnız arm64, dışlama filtreleri; ayrıntı `docs/size/after.md`); imza bilgisini editörde yerelde girin (bkz. 6.). Filtreye `internal/handlers/*` ve `csharp/*` de eklidir.
4. Gereksinimler: JDK 17, Android SDK (*Editor Settings > Export > Android*), Min SDK: eklenti belgesi bir değer vermiyor; Godot 4.7 varsayılanı (24) kullanın, Google Mobile Ads Next-Gen SDK 1.4.0'ın güncel alt sınırını Google belgesinden doğrulayın (Gradle derlemesi uyumsuzlukta hata verir), Target SDK güncel, arm64-v8a işaretli.
5. Release için *Project Settings > Admob > General > Android > Enable R8 Optimization* önerilir (Play "obfuscation < %25" uyarısı; eklenti `minifyEnabled` ve ProGuard kurallarını export sırasında yazar).
6. Keystore yolu/şifresi bu depoya YAZILMAZ; imzalamayı editörde yerel olarak yapın (`export_credentials.cfg` `.gitignore`'dadır).

### 3.2 Uygulama kimliği (v5.1.0: Proje Ayarı, elle AndroidManifest GEREKMEZ)
AdMob uygulama kimliği olmadan uygulama açılışta çöker. v5.1.0'da kimlik **Project Settings > General > Admob > General > Android > App Id**
(`admob/general/android/app_id`) alanına yazılır; export eklentisi bunu `AndroidManifest.xml` içine
`com.google.android.gms.ads.APPLICATION_ID` meta-data'sı olarak kendisi ekler. `android/build/AndroidManifest.xml` elle DÜZENLENMEZ.
- Şu an değer eklentinin varsayılanı, Google'ın **test uygulama kimliğidir**: `ca-app-pub-3940256099942544~3347511713`.
- Yayın öncesi bu alanı AdMob konsolundaki **gerçek** `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY` ile değiştirin
  (project.godot'ta `[admob] general/android/app_id="…"` satırı oluşur) **ve** `data/ads.json` → `admob.production.app_id` alanına da yazın.
  İki yer aynı kimliği taşımalıdır; ads.json yalnız birim kimliklerini seçer, manifest'i Proje Ayarı belirler.

### 3.3 AdMob konsolunda reklam birimleri
1. https://admob.google.com → *Uygulamalar > Uygulama ekle* → Android → Play'deki paket adınız.
2. İki reklam birimi oluşturun: **Ödüllü (Rewarded)** ve **Geçiş (Interstitial)**.
3. *Gizlilik ve mesajlaşma* bölümünde **GDPR (UMP) onay formu** oluşturup yayınlayın (AB/UK oyuncuları için zorunlu; `app-ads.txt` önerilir).

### 3.4 Kimlikleri koda verme — `data/ads.json` → `admob`
```json
"mode": "production",
"production": {
  "app_id": "ca-app-pub-...~...",
  "rewarded_unit_id": "ca-app-pub-.../...",
  "interstitial_unit_id": "ca-app-pub-.../..."
}
```
- Varsayılan `mode: "test"` Google'ın resmi **test kimliklerini** kullanır (ödüllü `ca-app-pub-3940256099942544/5224354917`, geçiş `ca-app-pub-3940256099942544/1033173712`).
- `production` yalnız **yayın sürümünde**, `mode` = `production` ve hiçbir alan `REPLACE_` ile başlamıyorsa kullanılır; aksi halde sağlayıcı kendiliğinden test kimliğine düşer (yanlışlıkla gerçek reklama tıklayıp hesabı riske atmayı önler). Hata ayıklama sürümü her zaman test kimliği kullanır.
- Aynı `app_id` değerini Proje Ayarı'na (`admob/general/android/app_id`) de yazmayı unutmayın (3.2); manifest'i o belirler.
- Kendi cihazınızda test: `data/ads.json` → `admob.test_device_ids` listesine cihaz kimliğini ekleyin (logcat'te "Use RequestConfiguration.Builder().setTestDeviceIds" satırında yazar).

### 3.5 GDPR / UMP onayı
`admob.request_consent` (varsayılan `true`) iken açılışta `PoingAdmobBridge.request_consent` çalışır. Akış eklentinin v5.1.0 örneğiyle aynıdır:
`UserMessagingPlatform.consent_information.update()` → form uygunsa `UserMessagingPlatform.load_consent_form()` →
durum `REQUIRED` ise `form.show()` → kapanınca SDK başlatılır. Her hata/“form yok”/“gerekmiyor” yolu da reklamları başlatır;
UMP native tekil nesnesi yoksa ya da form `consent_timeout_seconds` (8 sn) içinde bitmezse oyun beklemeden devam eder.
- **Konsol:** AdMob > *Gizlilik ve mesajlaşma* > GDPR iletisi oluşturup uygulamaya bağlayıp yayınlayın; form yayınlanmadıkça cihazda görünmez.
- **Formu AB dışında denemek (yalnız hata ayıklama sürümü):** `data/ads.json` → `admob.consent_debug_geography` = `"eea"` ve
  `test_device_ids`'e cihazın karma kimliğini (logcat: `addTestDeviceHashedId("…")`) yazın; deneme bitince alanı `""` yapın.
- **Eksik (sonraki iş):** AB'de Google, oyuncuya onayı değiştirme yolu sunmanızı ister (`UserMessagingPlatform.show_privacy_options_form()`,
  `consent_information.get_privacy_options_requirement_status() == REQUIRED` iken). Ayarlar ekranına bir “Gizlilik seçenekleri” düğmesi eklenmeli; köprüde henüz yok.

## 4. Google Play Faturalandırma — elle yapılacaklar

### 4.1 Eklenti
Godot'nun resmi **GodotGooglePlayBilling** (Godot 4 sürümü) eklentisini Godot dokümantasyonundaki
"Integrating with Google Play Billing" sayfasındaki adımlarla kurun (AAR/eklenti dosyaları + Android build template +
export ön ayarında eklentiyi işaretleme). Tekil nesne adı `GodotGooglePlayBilling`'dir; kod yalnız
`Engine.has_singleton("GodotGooglePlayBilling")` doğruysa devreye girer.
`AndroidManifest.xml`'e faturalandırma izni eklentiyle gelir (`com.android.vending.BILLING`); eklenti belgesini kontrol edin.

### 4.2 Play Console'da ürün
1. *Para kazanma > Ürünler > Uygulama içi ürünler > Ürün oluştur*.
2. **Ürün kimliği: `remove_ads`** (tam bu yazım; kodda `IapProvider.PRODUCT_REMOVE_ADS`). Tür: tek seferlik (yönetilen, tüketilmeyen).
3. Ad: "Reklamları kaldır"; fiyatı belirleyip **etkinleştirin**.
4. Test için *Lisans testi* hesaplarını ekleyin; uygulamayı en az dahili test kanalına yükleyin (Play ürünleri yalnız yüklenmiş uygulamada görünür).

Kod: satın alma sonrası `acknowledgePurchase` otomatik çağrılır (3 gün içinde onaylanmayan alımlar Google tarafından iade edilir).

## 5. Test listesi

**Masaüstü (eklentisiz) — şimdiden çalışır**
- [ ] Ana ekran > mağaza sekmesi: bölümler açılıyor, jeton rozeti güncelleniyor.
- [ ] Mağazada "Reklamları kaldır" (sahte fiyat `$2.99`) → "Satın alındı"; seviye geçişinde geçiş reklamı çıkmıyor; "2×" ve "+1 askı" ödüllü reklamları hâlâ var.
- [ ] 4. seviyeden önce hiç geçiş reklamı yok; 4. seviyeden sonra her "Devam"da var (reklamları kaldırmadan).
- [ ] Kaybedince yalnız "+1 askı" (reklam) ve "Tekrar dene"; jetonla devam yok.
- [ ] Kaplama satın al/seç → ana ekrandaki süs ipi ve oyundaki ip/mandallar değişiyor.

**Android cihaz (eklentilerle) — doğrulanmamış, ilk kez burada test edilecek**
- [ ] Önce Gradle export'un hatasız bittiği ve APK'nın açıldığı: logcat'te `[AdMob] Native plugin ... not found` OLMAMALI (varsa Use Gradle Build / Enabled ayarını kontrol edin; oyun bu durumda reklamsız devam eder).
- [ ] Logcat'te AdMob başlatma tamamlanıyor; `AdmobAdsProvider` seçilmiş (ödüllü düğmeler yalnız reklam yüklüyken görünür).
- [ ] Test modunda (varsayılan) ödüllü reklam: "+1 askı" ve "2×" Google test reklamı gösteriyor, ödül reklam kapanınca (kullanıcı ödülü kazandıysa) veriliyor; erken kapatınca ödül yok.
- [ ] Geçiş reklamı 4. seviyeden itibaren "Devam"da geliyor; uçak modunda hiç takılmıyor (≤3 sn sonra devam).
- [ ] İlk açılışta UMP formu (AB VPN/test cihazı ile) çıkıyor ve oyun beklemeden açılıyor.
- [ ] Lisans test hesabıyla `remove_ads` satın alma → anında geçiş reklamları kapanıyor; uygulama silinip yeniden kurulunca (veya "Satın alımları geri yükle") sahiplik geri geliyor.
- [ ] Satın alma iptali → hata balonu yok (sessiz), sahiplik verilmiyor.
- [ ] Release build'de `mode: production` + gerçek kimlikler; test kimliği kalmadığını logcat'te doğrulayın.
- [ ] Mağazada hiç yanıt yokken ("Mağazaya bağlanıyor") düğmeler donmuyor.

## 6. Bilinen sınırlar
- `PoingAdmobBridge` sınıf/yöntem/sinyal adları eklenti v5.1.0 **kaynağına karşı** doğrulandı ve eklentinin masaüstü mock'una karşı uçtan uca (başlat, yükle, göster, ödül, kapanış) çalıştırıldı;
  ama gerçek native katman (AAR, UMP, Google SDK) cihazda **doğrulanmadı**. Eklentinin `skills/*.md` örnekleri (ör. `ConsentInformation.request_consent_info_update`, `OnConsentInfoUpdateListener`)
  v5.1.0 kaynağıyla UYUŞMUYOR; doğru API kaynak kodudur, köprü ona göre yazıldı.
- Masaüstünde eklentinin kendi mock'u KULLANILMAZ (gerçek zamanlı 8 sn'lik sahte reklam penceresi açar; probe/testleri belirsizleştirir). Masaüstü = `MockAdsProvider`.
- `PlayBillingProvider` gerçek eklenti olmadan doğrulanmadı.
- Banner reklam yoktur (ileride eklenirse `AdPacing` ile aynı "reklamları kaldır" kuralına bağlanmalıdır).
