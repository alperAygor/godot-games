# Switchyard — Para kazanma (AdMob)

Şablonda **AdMob eklentisi KURULU DEĞİLDİR** (`addons/admob` kopyalanmadı). Reklam kodu hazırdır ve eklenti/native tekil
nesneleri bulunana dek kendiliğinden pasiftir: masaüstünde/debug'da `MockAdsProvider`, release'te `NoAdsProvider`.

## 1. Varsayılan kurallar (oyunun sahibi değiştirebilir)

| Konu | Kural |
|---|---|
| Kayıpta devam | Yalnız ödüllü reklamla, tur başına bir kez (`CONTINUE`). |
| 2x jeton | Yalnız kazanmada, ödüllü reklamla (`DOUBLE_COINS`). |
| Geçiş reklamı | `data/ads.json` → `interstitial.first_level` (4) ve sonrası HER seviye geçişinde ("Devam" yolunda). Oyun sırasında asla. |
| İstisna 1 | "Reklamları kaldır" alındıysa geçiş reklamı asla (`Progress.remove_ads_owned()`); ödüllü açık kalır. |
| İstisna 2 | O geçişte ödüllü reklam izlendiyse hemen ardından geçiş reklamı yok. |
| Reklam yoksa | Hazır değilse ya da 3 sn içinde ekrana gelmezse akış sessizce sürer. |
| Çevrimdışı | Oynamak yasak (`data/balance.json` → `require_online`; `OnlineGate`). Kapatmak için `false`. |

Karar fonksiyonu `scripts/core/ad_pacing.gd` (saf, testli). Yeni yerleşim: `AdManager.Placement` enum'una SONA ekle,
`PLACEMENT_KEYS` + `data/ads.json` limitini yaz (`INTERSTITIAL` sırası `AdsProvider.INTERSTITIAL_PLACEMENT` ile aynı kalmalı;
yerleşim INTERSTITIAL'dan sonra eklenecekse sabiti ve testi birlikte güncelle).

## 2. AdMob eklentisini eklemek (elle)

Poing Studios `godot-admob-plugin` v5.1.0 (Godot 4, MIT) için yazıldı (`scripts/services/poing_admob_bridge.gd`).
Başka bir projeden ya da eklentinin deposundan (kullanıcı onayıyla indirme) **kopyalanır**:

1. `addons/admob/` klasörünü projeye koy (yalnız temel `ads` modülü; mediation yok). Android AAR'ları
   `addons/admob/android/bin/` altında olmalı (yoksa eklenti internetten indirmeye çalışır; iOS için `ios/bin/package.gd`
   yer tutucusu headless importta indirmeyi engeller). `csharp/` ve örnek sahneler çıkarılabilir.
2. `project.godot`'a ekle:
   ```
   [admob]

   general/ios/enabled=false

   [editor_plugins]

   enabled=PackedStringArray("res://addons/admob/plugin.cfg")
   ```
3. Godot: *Project > Install Android Build Template*; export ön ayarında **Use Gradle Build** açık (şablonda release ön ayarı hazır).
   JDK 17 + Android SDK gerekir. Eklenti kodu tipsizdir; Godot varsayılan `exclude_addons=true` olduğu için strict kural ona uygulanmaz.
4. Export `exclude_filter` zaten `addons/admob/android/*`, `internal/editor/*` ... kalıplarını dışlar (`export_presets.cfg`).
5. `tools/pck_check.py`/`size_report.py` eklenti yollarını bilir.

## 3. Kimlikler

`data/ads.json` → `admob`: varsayılan `mode: "test"` Google'ın **resmi test kimlikleridir**. Yayın için AdMob konsolunda
uygulama + **Ödüllü** + **Geçiş** birimleri oluştur, `production` bloğundaki `REPLACE_*` alanlarını doldur ve `mode`'u
`production` yap. Üretim kimlikleri YALNIZ release sürümde, mode=production ve hiçbir alan `REPLACE_` değilken kullanılır;
aksi halde test kimliğine düşer (kendi reklamına tıklamak hesap yasağı sebebidir).
Uygulama kimliği ayrıca **Project Settings > Admob > General > Android > App Id** (`admob/general/android/app_id`)
alanına da yazılmalıdır (manifest'i bu belirler; yoksa uygulama açılışta çöker).
GDPR/UMP onayı: `admob.request_consent` (varsayılan true); AdMob konsolunda GDPR iletisi yayınla.

## 4. Paket kimliği ve imza

`export_presets.cfg` içindeki `package/unique_name` yer tutucudur (`com.studio.<ad>`); yayından önce gerçek kimliği yaz.
Keystore yolu/şifresi bu depoya YAZILMAZ; imzalamayı editörde yerel yap (`export_credentials.cfg` `.gitignore`'dadır).
İnternet izinleri (`internet`, `access_network_state`) çevrimiçi kapısı ve reklamlar için preset'lerde açıktır.
Ön ayarlar: **Android (release)** (Gradle AAB, arm64), **Android (test apk)** (Gradle'sız debug APK), **Desktop pack check (Linux)** (boyut/PCK denetimi).

## 5. Kapsam dışı (şablonda YOK)

Google Play Faturalandırma / "reklamları kaldır" satın alma servisi taşınmadı; yalnız sahiplik bayrağı vardır
(`Progress.set_remove_ads_owned`). Satın alma eklenecekse bir `IapProvider` arayüzü + mock + Play Billing sağlayıcısı yazılır
ve açılışta sahiplik mağazadan yeniden doğrulanır.

## 6. Test listesi (Android cihaz, ilk kez burada doğrulanır)

- [ ] Gradle export hatasız; logcat'te `[AdMob] Native plugin ... not found` yok.
- [ ] Test modunda ödüllü reklam: "Devam et" ve "2×" ödülü yalnız kapanınca (ödül kazanıldıysa) verir; erken kapatınca yok.
- [ ] Geçiş reklamı `first_level` ve sonrası "Devam"da; uçak modunda takılmaz (≤3 sn sonra devam).
- [ ] UMP formu (AB VPN/test cihazı) çıkar, oyun beklemeden açılır.
- [ ] Release'te `mode: production` + gerçek kimlikler; test kimliği kalmadı.
