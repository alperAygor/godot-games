# Priz — Para kazanma (AdMob)

Projede **AdMob eklentisi KURULU DEĞİLDİR** (`addons/admob` kopyalanmadı). Reklam kodu hazırdır ve eklenti/native tekil
nesneleri bulunana dek kendiliğinden pasiftir: masaüstünde/debug'da `MockAdsProvider`, release'te `NoAdsProvider`.

## 1. Priz kuralları (tasarım belgesi; `data/ads.json` + saf `AdPacing`, birim testli)

| Konu | Kural |
|---|---|
| Ödüllü yerleşimler | `extra_fuse` (sigortalar bitince +1 hak), `double_coins` (seviye sonu), `hint` (bir cihazın doğru prizi), `day_preview` (gün önizleme), `renovation_early` (yenileme parçasını erken aç). Her birinin tur/oturum limiti `ads.json`'da. Ödül YALNIZ sağlayıcı `rewarded` verince. |
| Sessiz dönem | İlk `quiet.levels` (**3**) seviyede reklam, mağaza ve açılır pencere YOK. Arayüz tek soru sorar: `Progress.is_quiet_period()` (ya da `AdManager.is_offer_allowed(seviye)`). Bu sürede ödüllü düğme sunulmaz, geçiş reklamı ve banner yok. |
| Geçiş reklamı | YALNIZ seviye geçişinde ("Devam" yolu, `RunFlow.maybe_interstitial`). Tamamlanan seviye ≥ `interstitial.first_after_level` (**5**). Her reklamdan sonra `gap_cycle` = **2, 3, 2, 3 ...** seviye beklenir (BELİRLENİMCİ, rastgele değil): reklamlar 5, 7, 10, 12, 15, 17 ... seviyelerinde. İki reklam arası ≥ `min_seconds_between` (**90 sn**, kayıtlı `last_interstitial_time`). |
| İstisna 1 | O geçişte ödüllü reklam izlendiyse geçiş reklamı yok (sayaç korunur; bir sonraki geçişte uygun olur). |
| İstisna 2 | "Reklamları kaldır" alındıysa (`Progress.remove_ads_owned()`) geçiş reklamı ve banner asla; ödüllü açık kalır. |
| Banner | YALNIZ `banner.screens` ekranlarında: `neighbourhood` (ana ekran = mahalle) ve `collection`. **Oyun ekranında asla** (`RunFlow.on_level_start` `game` ekranını bildirir). Her ekran açılışında `AdManager.set_banner_visible(ekran_kimliği)`; sağlayıcıya `show_banner()/hide_banner()`; mock yalnız kaydeder (`banner_visible`, `banner_show_count`). Sessiz dönemde ve reklamlar kaldırılınca da gizli. |
| Reklam yoksa | Hazır değilse ya da 3 sn içinde ekrana gelmezse akış sessizce sürer. |
| Çevrimdışı | Oynamak yasak (`data/balance.json` → `require_online`; `OnlineGate`). Kapatmak için `false`. |

Karar fonksiyonları `scripts/shell/ad_pacing.gd` (saf; zaman dışarıdan verilir) — testler `tests/unit/test_shell_ad_pacing.gd`,
`test_shell_run_flow.gd`, `test_shell_ad_manager.gd`; uçtan uca `tools/play_probe.gd` (5. seviyeden sonra 2-3 aralık,
ödüllü izlenen geçişte reklam yok, oyun ekranında banner yok). Sayaçlar kayıtta: `levels_since_interstitial`,
`interstitials_shown`, `last_interstitial_time` (`ProgressData`).
Yeni yerleşim: `AdManager.Placement` enum'una SONA (INTERSTITIAL'dan ÖNCE eklenecekse `AdsProvider.INTERSTITIAL_PLACEMENT`
sabitini ve `test_shell_ad_manager.gd`'yi birlikte güncelle), `PLACEMENT_KEYS` + `data/ads.json` limitini yaz.
Şablonun varsayılanı (4. seviyeden itibaren her geçişte, kayıpta devam) Priz için KALDIRILDI.

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

`export_presets.cfg` içindeki `package/unique_name` yer tutucudur (`com.priz.game`, test: `com.priz.game.test`); yayından önce gerçek kimliği yaz.
Keystore yolu/şifresi bu depoya YAZILMAZ; imzalamayı editörde yerel yap (`export_credentials.cfg` `.gitignore`'dadır).
İnternet izinleri (`internet`, `access_network_state`) çevrimiçi kapısı ve reklamlar için preset'lerde açıktır.
Ön ayarlar: **Android (release)** (Gradle AAB, arm64), **Android (test apk)** (Gradle'sız debug APK), **Desktop pack check (Linux)** (boyut/PCK denetimi).

## 5. Kapsam dışı (şimdilik YOK)

AdMob **banner** gösterimi yazılmadı: `AdsProvider.show_banner()/hide_banner()` kancaları var, politika ve mock hazır, gerçek
`AdmobAdsProvider` aşama 6'da banner birimini bağlar (`ads.json` `admob.*.banner_unit_id` eklenecek).

Google Play Faturalandırma / "reklamları kaldır" satın alma servisi taşınmadı; yalnız sahiplik bayrağı vardır
(`Progress.set_remove_ads_owned`). Satın alma eklenecekse bir `IapProvider` arayüzü + mock + Play Billing sağlayıcısı yazılır
ve açılışta sahiplik mağazadan yeniden doğrulanır.

## 6. Test listesi (Android cihaz, ilk kez burada doğrulanır)

- [ ] Gradle export hatasız; logcat'te `[AdMob] Native plugin ... not found` yok.
- [ ] Test modunda ödüllü reklam: "Bir hak daha" ve "İkiye katla" ödülü yalnız kapanınca (ödül kazanıldıysa) verir; erken kapatınca yok.
- [ ] Geçiş reklamı 5. seviyeden sonra, 2-3 seviyede bir, ≥ 90 sn arayla "Devam"da; uçak modunda takılmaz (≤3 sn sonra devam).
- [ ] Banner yalnız ana ekranda/koleksiyonda; oyun ekranında hiç yok.
- [ ] UMP formu (AB VPN/test cihazı) çıkar, oyun beklemeden açılır.
- [ ] Release'te `mode: production` + gerçek kimlikler; test kimliği kalmadı.
