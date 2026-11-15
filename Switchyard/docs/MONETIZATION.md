# Switchyard — Para kazanma (AdMob)

Şablonda **AdMob eklentisi KURULU DEĞİLDİR** (`addons/admob` kopyalanmadı). Reklam kodu hazırdır ve eklenti/native tekil
nesneleri bulunana dek kendiliğinden pasiftir: masaüstünde/debug'da `MockAdsProvider`, release'te `NoAdsProvider`.

## 1. Reklam politikası (sahibin kararı, 2026-11-15; sayılar `data/ads.json`)

Jeton ekonomisi YOKTUR. Para kazanma dört yerleşimdir:

| Yerleşim | Tür | Kural |
|---|---|---|
| İpucu | ödüllü | Her ipucu bir reklam. Ödül gelince `LevelSession.show_hint()` çağrılır. Seviye başına sınır yok (`HINT.per_run: 99`). |
| Seviyeyi atla | ödüllü | Önce onay sayfası ("Seviye atlansın mı?"), sonra bir reklam. Ödülden sonra seviye "atlandı" işaretlenir, sıradaki açılır, yıldız yok. Seviye başına bir kez (`SKIP.per_run: 1`). |
| Geçiş reklamı | interstitial | Aşağıdaki kural. Oyun sırasında ASLA; yalnız sonuç sayfasından çıkarken (Sonraki ya da Seviyeler). |
| Reklamları kaldır | ücretli, tek seferlik | YALNIZ geçiş reklamını kapatır; ipucu ve atlama ödüllü kalır. |

**Düğme eşiği:** ipucu ve atla düğmeleri 1-3. seviyelerde görünmez (`rewarded.buttons_from_level: 4`).

**Geçiş reklamı kuralı** (`interstitial.first_level: 4`, `every_n: 3`, `min_gap_seconds: 60`; karar saf `AdPacing`, testli):
- 1-3. seviyeler oynanırken reklam yok. `first_level` = reklamın ÖNÜNDE gelebileceği ilk seviye: 3. seviye bitince 4'e
  geçerken ilk reklam gelir, sonra her `every_n` seviyede bir. Yani reklam, **3, 6, 9, 12... numaralı seviyelerin bitişinde**.
- Yalnız seviye İLK KEZ tamamlandığında (çözme ya da atlama) sayılır. Eski seviyeyi tekrar oynamak sırayı ilerletmez.
- "Reklamları kaldır" alındıysa asla.
- O seviyede ödüllü reklam izlendiyse (ipucu ya da atlama) o geçişte yok (`suppress_after_rewarded: true`; `false` yaparsan serbest).
- Son geçiş reklamından beri `min_gap_seconds` dolmadıysa yok. Bu yüzden atlanan reklam ERTELENMEZ; sıradaki reklam kendi sırasında gelir.
- Reklam hazır değilse ya da `settings.show_start_timeout_seconds` (3 sn) içinde ekrana gelmezse akış sessizce sürer.
- Sonuç sayfasından "Tekrar" ile çıkılırsa reklam yok; sıra hakkı seviyeden gerçekten çıkarken (Sonraki / Seviyeler) tüketilir.

12 seviyelik örnek (hep ilk kez, bitişler arası >= 60 sn, reklam hazır, ödüllü kullanılmadı):

| biten seviye | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| geçiş reklamı | - | - | **var** | - | - | **var** | - | - | **var** | - | - | **var** |

Varyasyonlar: 6. seviyede ipucu izlendiyse 6'daki reklam yok (9'daki yine gelir); 9. seviye atlandıysa 9'daki yok;
3'ten 30 sn sonra biten 6'da reklam yok (aralık); reklamlar kaldırıldıysa hiçbiri.

**Reklam yoksa:** ödüllü düğme nedenini söyler (kısa bildirim: reklam yok / bağlantı yok / reklam açılmadı / video yarıda
kapandı) ve hiçbir şey takılmaz (düğme yeniden açılır, saha girdisi açık). Çevrimdışı oynamak yasak: `data/balance.json` →
`require_online`, `OnlineGate`.

**Kod yolu:** `Game` (`scripts/ui/game.gd`) → `RunFlow` (`scripts/ui/run_flow.gd`: ödüllü akış, geçiş kararı, saat) →
`AdManager` (sağlayıcı, sınırlar, 3 sn zaman aşımı) → `AdsProvider` (Mock / NoAds / AdMob). Yerleşimler:
`AdManager.Placement { HINT, SKIP, INTERSTITIAL }` (INTERSTITIAL sırası `AdsProvider.INTERSTITIAL_PLACEMENT` ile aynı kalır).

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

## 5. Satın alma ("Reklamları kaldır")

Arayüz `IapProvider` (taban = "mağaza yok"), `MockIapProvider` (masaüstü/debug), `IapService` (sağlayıcıyı seçer, sahipliği
`Progress` "shop" modülüne yazar, açılışta mağazadan yeniden doğrular). Adlar ve sinyaller kardeş projeyle (CamasirIpi)
AYNIDIR; gerçek `play_billing_provider.gd` olduğu gibi kopyalanıp `IapService.make_default_provider()` içindeki KANCA'ya
bağlanır (eklenti kurulumu ayrı görev). Release derlemesinde sağlayıcı yoksa "mağaza yok": düğme kapalı, sahte başarı VERİLMEZ.
Satır (`UiShopRow`): fiyat mağazadan, satın al, geri yükle, sahip olunca "Reklamlar kaldırıldı". Yeri: Ayarlar sayfası ve
ana ekrandaki küçük "yasak" ikonundan açılan `ShopSheet` (sahip olununca ikon kalkar).
Ürün kimliği: `remove_ads` (Play Console ile aynı olmalı).

## 6. Test listesi (Android cihaz, ilk kez burada doğrulanır)

- [ ] Gradle export hatasız; logcat'te `[AdMob] Native plugin ... not found` yok.
- [ ] Test modunda ödüllü reklam: ipucu ve atlama ödülü yalnız izlenince verilir; erken kapatınca yok ("video yarıda kapandı" bildirimi).
- [ ] Geçiş reklamı 3, 6, 9, 12. seviye bitişinde (Sonraki / Seviyeler); uçak modunda takılmaz (≤3 sn sonra devam).
- [ ] "Reklamları kaldır" gerçek Play Billing ile: satın alma, yeniden kurulumda geri yükleme, iade sonrası kaydın temizlenmesi.
- [ ] UMP formu (AB VPN/test cihazı) çıkar, oyun beklemeden açılır.
- [ ] Release'te `mode: production` + gerçek kimlikler; test kimliği kalmadı.
