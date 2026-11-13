# Çamaşır İpi — Para kazanma (AdMob + Google Play Faturalandırma)

Bu belge, kodun hazır olduğu ama **elle yapılması gereken** adımları anlatır. Kod, eklentiler
yokken de olduğu gibi çalışır (masaüstünde sahte reklam/mağaza); eklenti dosyaları eklenince
kendiliğinden gerçek sağlayıcıya geçer. Hiçbir SDK bu depoya indirilmedi.

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

### 3.1 Eklentiyi indirme
Poing Studios `godot-admob-plugin` (Godot 4, Android) — GitHub sürümlerinden, projenizin Godot sürümüyle
uyumlu en son sürümü indirin (kaynak: `https://github.com/poingstudios/godot-admob-plugin`).
Sürüm notlarındaki kurulum talimatı esastır; genel olarak:

1. Sürümden `addons/admob` klasörünü projeye `res://addons/admob/` olarak koyun.
2. Android için sürümde gelen AAR/`gdextension`/export eklentisi dosyalarını (README'de "Android" bölümü) belirtilen yere koyun.
3. Android derleme şablonunu kurun: Godot → *Project > Install Android Build Template* (`res://android/build/` oluşur).
4. *Project > Project Settings > Plugins* içinde AdMob eklentisini **etkinleştirin**.
5. *Project > Export > Android* ön ayarında: **Use Gradle Build** açık, eklentinin listelediği "Plugins" kutusunu işaretleyin.
   Önerilen: Min SDK 23+, Target SDK güncel (Play gereği).

### 3.2 Uygulama kimliği (AndroidManifest)
AdMob uygulama kimliği olmadan uygulama açılışta çöker. Eklentinin README'sine göre uygulama kimliği
eklentinin ayarında (*Project Settings > AdMob*) ya da `android/build/AndroidManifest.xml` içinde şu şekilde verilir:

```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY"/>
```
Geliştirme sırasında Google'ın **test uygulama kimliği** kullanılır: `ca-app-pub-3940256099942544~3347511713`.

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
- Aynı `app_id` değerini AndroidManifest'e de yazmayı unutmayın (3.2).
- Kendi cihazınızda test: `data/ads.json` → `admob.test_device_ids` listesine cihaz kimliğini ekleyin (logcat'te "Use RequestConfiguration.Builder().setTestDeviceIds" satırında yazar).

### 3.5 GDPR / UMP onayı
`admob.request_consent` (varsayılan `true`) iken açılışta `PoingAdmobBridge.request_consent` çalışır: eklentinin
`UserMessagingPlatform` sınıfı varsa bilgi güncellenir ve gerekiyorsa form gösterilir; sınıf yoksa ya da form
8 sn (`consent_timeout_seconds`) içinde bitmezse reklamlar yine de başlatılır (oyun takılmaz).
Form sonucu "reklam istenemez" ise AdMob zaten reklam dönmez; oyun bunu fark etmeden devam eder.
> Eklenti sürümünüzde UMP sınıf/yöntem adları farklıysa yalnız `poing_admob_bridge.gd` içindeki `request_consent` güncellenir.

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
- [ ] Test modunda (varsayılan) ödüllü reklam: "+1 askı" ve "2×" Google test reklamı gösteriyor, ödül reklam kapanınca (kullanıcı ödülü kazandıysa) veriliyor; erken kapatınca ödül yok.
- [ ] Geçiş reklamı 4. seviyeden itibaren "Devam"da geliyor; uçak modunda hiç takılmıyor (≤3 sn sonra devam).
- [ ] İlk açılışta UMP formu (AB VPN/test cihazı ile) çıkıyor ve oyun beklemeden açılıyor.
- [ ] Lisans test hesabıyla `remove_ads` satın alma → anında geçiş reklamları kapanıyor; uygulama silinip yeniden kurulunca (veya "Satın alımları geri yükle") sahiplik geri geliyor.
- [ ] Satın alma iptali → hata balonu yok (sessiz), sahiplik verilmiyor.
- [ ] Release build'de `mode: production` + gerçek kimlikler; test kimliği kalmadığını logcat'te doğrulayın.
- [ ] Mağazada hiç yanıt yokken ("Mağazaya bağlanıyor") düğmeler donmuyor.

## 6. Bilinen sınırlar
- `PoingAdmobBridge` ve `PlayBillingProvider` gerçek eklentiler bu depoda olmadığı için cihazda **doğrulanmadı**; adlar ilgili eklentilerin belgelerine göre yazıldı. Entegrasyonda ilk iş test listesindeki Android maddeleridir.
- Banner reklam yoktur (ileride eklenirse `AdPacing` ile aynı "reklamları kaldır" kuralına bağlanmalıdır).
