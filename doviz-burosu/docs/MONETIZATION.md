# Döviz Bürosu — Para kazanma, onay ve satın alma (T-M1)

Durum: 2026-11-15. Kod hazır, **kapalı**: kimlikler test, `providers.play_billing=false`. Gerçek kimlikler, Play Console ürünü ve gizlilik adresi sahibe aittir (RELEASE_ROADMAP O-maddeleri). Bu belgedeki "karar bekliyor" maddeleri açıkça işaretlidir.

## 1. Katmanlar
`Monetization` (oyun kodunun tek kapısı) → `Ads` / `IAP` autoload'ları → sağlayıcılar (`scripts/services/`): `AdMobAdsProvider` (eklenti AdMob v7.0), `PlayBillingIapProvider` (eklenti GodotGooglePlayBilling 3.3.0), `Mock*` (debug/test), taban sınıflar (reklamsız/mağazasız). Saf kurallar (`scripts/core/`): `AdPolicy` (geçiş/ödüllü sınırları), `ConsentFlow` (onay rejimi), `AdsConfig` (kimlik doğrulaması, politika adresi), `RetryPolicy` (ücretsiz yol). Ayarlar: `data/ads.json` (sınırlar, zaman aşımları, ücretsiz yol), `data/ads_ids.json` (mod, kimlikler, sağlayıcı bayrakları, **tek** gizlilik adresi), `data/products.json`.

## 2. Tek, dürüst onay deneyimi
Eskiden `ConsentSheet` ve UMP formu AB/UK'de ilk açılışta üst üste çıkıyordu; metin "anonim kullanım verisi" vaat ediyor, ama gönderen kod yoktu. Şimdi:

| Rejim | Ne zaman | Oyuncunun gördüğü | SDK ne zaman başlar |
|---|---|---|---|
| `form` | UMP durumu `REQUIRED`/`OBTAINED` (AB/EEA, UK ...) | **Yalnızca Google'ın UMP formu.** Oyunun penceresi çıkmaz. Ayarlar > Gizlilik seçenekleri: "Reklam seçenekleri" düğmesi UMP'yi yeniden açar. | UMP bitince |
| `notice` | UMP `NOT_REQUIRED`, ya da UMP yanıt vermedi/ağ yok (bölge bilinemedi) | Bir kez, ana menüde **kısa bilgi**: reklam var (Google AdMob, reklam kimliği olabilir), kişiselleştirilmiş/kişiselleştirilmemiş seçimi, hesap yok, kişisel veri toplanmaz, **analitik yok**. | Pencere yanıtlanınca (kayıtlı karar varsa hemen) |
| `none` | Reklam SDK'sı yok (taban sağlayıcı: release masaüstü, yapılandırma hatası) | Hiçbir şey sorulmaz | Başlamaz |

**İlk açılış sırası** (`Monetization._ready`): 1) sağlayıcılar kurulur, SDK **başlamaz** → 2) kayıtlı tercih (`game/ads_personalized`) ve "bilgi yanıtlandı" (`game/consent_asked`) sağlayıcıya iletilir → 3) `Ads.request_consent()` = UMP `update_consent_info` (AB/UK'de form çıkar) → 4) rejim belli olunca `Monetization.consent_resolved`; `notice` ise ve sorulmadıysa `notice_needed` sinyali, ana menü pencereyi açar → 5) **ilk reklam isteği ve SDK `initialize()` ancak** `form`'da UMP bitince / `notice`'te pencere yanıtlanınca (tek yer: `AdMobAdsProvider._maybe_start_sdk`) → 6) yükleme/ön yükleme → mağaza bağlantısı ve sahiplik sorgusu (SDK sırasından bağımsız).
Anahtarlar: `game/ads_personalized` (reklam kişiselleştirme), `game/consent_asked` (oyun penceresi yanıtlandı). **Analitik anahtarı yok**: analitik SDK'sı olmadığı için `Analytics` yalnızca bellekte yerel günlüktür, `_send()` kaldırıldı; ileride SDK eklenirse ayrı açık-izin anahtarı + metin + Veri güvenliği + politika birlikte güncellenir.
`form` rejiminde kişiselleştirmeyi UMP belirler (oyun ezmez). Eklenti v7.0 UMP'nin "gizlilik seçenekleri formu" API'sini sunmaz; bu yüzden `show_privacy_options()` kayıtlı onayı sıfırlayıp (`reset_consent_info`) formu yeniden ister — **cihazda doğrulanmalı** (bkz. §7 madde 6).
Metin T-S1 ile mutabık olmalı: `MON_NOTICE_TEXT` / `MON_FORM_TEXT` (strings.csv sonu, TR+EN) gizlilik politikası ve Veri güvenliği formuyla aynı şeyleri söylemeli (reklam kimliği: evet; analitik: yok; hesap: yok). Eski `CONSENT_*` satırları artık kullanılmıyor (silmeyi T-L1 yapar).
**Gizlilik politikası bağlantısı:** tek kaynak `data/ads_ids.json` `privacy_policy_url` (yer tutucu `https://example.com/...`). Oyun içi düğme (`PrivacyPolicyButton`) yayın sürümünde yer tutucuyken **gizlidir**; yayın kapısı (`release_check`) aynı alanı okur ve yer tutucuda başarısız olur. Sahip gerçek https adresini yalnızca bu alana yazar (`tools/release_state.json`'daki eski alan kaldırıldı).
**Ayarlar ekranı sözleşmesi (T-A2):** `settings_screen.gd` hâlâ `Monetization.open_provider_privacy_options()` + `add_child(ConsentSheet.new())` çağırıyor; bu çalışır (ilki artık hiçbir şey açmaz, böylece iki pencere üst üste çıkmaz). T-A2 ekranı güncellerken yalnızca `ConsentSheet.new()` ekler; pencere rejime göre içeriğini kendisi seçer. Yeni arayüz isterse `Monetization.provider_form_applies()`, `open_ump_privacy_options()`, `privacy_policy_visible()`, `open_privacy_policy()` vardır.

## 3. Reklam sertleştirme
- **Gerçek kimlik asla sessizce test'e düşmez.** `AdsConfig.problem()`: `mode=real` iken eksik (`real_ids_incomplete`) ya da Google test yayıncısı (`real_id_is_google_test_id`) → `Monetization.install_providers` reklam SDK'sını **kurmaz** (taban sağlayıcı, reklam yok), `Monetization.config_error` dolar ve hata yazılır: release'te `push_error`, debug'da `push_warning`. `AdMobAdsProvider.initialize` aynı koşulda SDK'yı başlatmaz. Yayın kapısı (`ReleaseGuard.check_ads`) ve `tools/sync_ads_config.py` aynı kuralları denetler; üç katman birbirini tutar.
- Release'te `mode=test` ile çalışmak (iç test kanalı için) engellenmez ama `push_warning` yazar; Play'e yükleme kapıda reddedilir.
- **Zaman aşımları** (`data/ads.json timeouts`): ödüllü istek 150 sn'de yanıtlanmazsa `done(false)` (tam bir kez), bekleyen durum temizlenir, `reward_failed(yer, "timeout")`; geçiş reklamı 90 sn'de kapanmazsa `then` yine çalışır (tam bir kez). Sağlayıcının kendi gösterim zaman aşımı 120 sn (`ads_ids.json ads.show_timeout_seconds`, istek zaman aşımından kısa). Geç gelen SDK yanıtı ikinci geri çağrı üretmez.
- **"Reklam yok"**: hazır değilse buton pasif ("Reklam şu an yok"); `request_reward` hazır değilken de takılmaz (`reward_failed(…, "not_ready")`). Başarısızlık nedenleri: `not_ready | busy | timeout | no_reward`.
- **Geçiş reklamı** (değişmedi, `AdPolicy` testli): yalnızca gün sonu/mod sonucu, hikaye günü ≥ 3, ≥ 2 oyun birimi, ≥ 180 sn herhangi reklamdan sonra, ≥ 120 sn oturum, ≥ 2. açılış, `no_ads` sahibine hiç; masa ortasında ve ilk oturumda asla. Banner yok.
- Test kimlikleri varsayılan (`mode=test`); test kimliği başka hiçbir dosyada bulunamaz (`sync_ads_config.py` sızıntı taraması).

## 4. Kovulma çıkmazı: ücretsiz yol (kanca hazır, **karar bekliyor**)
Sorun: "Günü tekrar oyna" yalnızca ödüllü reklamla mümkündü; reklam yoksa tek yol "Yeni oyun" (15 günlük kayıp) — kötü deneyim ve politika riski (ilerleme reklama bağlı).
Mekanizma (`Monetization`, UI'sız):
- `retry_day_options()` → `{"ad": {visible, enabled}, "free": {available, reason, cost_kind, cost_value, decision_pending}}`.
- `take_free_retry()` → uygunsa `{"ok": true, cost_kind, cost_value}` (analitik olayı `retry_day_free`); **bedeli uygulamak ve `Career.restore_morning()` çağırmak çağıranındır** (T-B1, `game_over_screen.gd`).
- Ücretsiz yol şu varsayılanla **reklam gösterilemediğinde** açılır: reklam hazır değil (`ad_not_ready`) ya da bu oturumda istek zaman aşımına/hazır-değil'e düştü (`ad_failed`). Oyuncunun reklamı kendi isteğiyle erken kapatması açmaz.
- Ayar: `data/ads.json free_retry` (`enabled`, `available_when`: `ad_unavailable` | `always`, `cost {kind, value}`, `decision_pending`).
**Karar gereken (O8 → T-B1):** (a) ücretsiz yolun bedeli — varsayılan şimdilik **bedelsiz** (`cost.kind="none"`); seçenekler: bedelsiz, sabah nakdinden PL kesintisi (`cash_pl`), günün ilerlemesini yarıya indirme, günde/oyunda en fazla N kez; (b) reklam çalışırken de gösterilsin mi (`available_when="always"`); (c) `no_ads` sahibi için ek ayrıcalık. **Bağlanmadığı sürece** `game_over_screen.gd` (T-B1'in) hâlâ yalnızca reklam düğmesini gösterir → çıkmaz T-B1 arayüzü bağlayana dek sürer. Metin anahtarı hazır: `MON_RETRY_FREE`.

## 5. Satın alma (`no_ads`)
- Eklenti: `addons/GodotGooglePlayBilling` **3.3.0** (Billing Library 9.1.0; 2026-07-27, GitHub `godot-sdk-integrations/godot-google-play-billing` Godot 4 hattının **güncel** sürümü; "1.4.0" etiketi Godot 3 hattıdır). `BillingClient.gd` imzaları sağlayıcıyla uyumlu → **eklenti güncellemesi gerekmiyor, onay bekleyen indirme yok.**
- `PlayBillingIapProvider` yeniden düzenlendi: ürün ayrıntısı gelmeden `purchase` başlatılmaz (Play DEVELOPER_ERROR verir; sıraya alınır, ürün mağazada yoksa `item_unavailable`); PURCHASED → `acknowledge` → ancak sonra ödül; **PENDING** → `purchase_finished(false, "pending")` (Market "ödeme beklemede" der), sonradan PURCHASED gelirse normal yoldan sahiplik verilir; bağlantı kopması/`connect_error` → üstel yeniden bağlanma (2→60 sn) ve `availability_changed`; açılışta sahiplik sorgusu (restore) + onaysız satın almaların onaylanması; geri yükleme hatası (`restore_failed`) "geri yüklenecek yok"tan ayrı.
- Market: mağaza yokken "Mağazaya bağlanılıyor…" gösterir, 4 sn'de bir `Monetization.retry_store()` dener, `store_changed` ile kendini yeniler; fiyat gelmeden de satın alma başlatılabilir; iptalde sessiz, beklemede özel mesaj.
- **Bayrak:** `providers.play_billing=true` yalnız lider/sahip tarafından, Play Console'da `no_ads` ürünü (O7) oluşturulup etkinleştirildikten sonra. Kod hazır; ürün kimliği `data/ads_ids.json billing.product_ids` ve `data/products.json` (`no_ads`) belgelenmiş yer tutucudur.

## 6. Bekleyen onaylar / sahibe kalanlar
- **İndirme/eklenti onayı: yok** (AdMob v7.0 ve Billing 3.3.0 güncel; ağ yalnız GitHub release listesi okumak için kullanıldı).
- Eklentide UMP "gizlilik seçenekleri formu" API'si yok (v7.0). Yeniden onay sıfırlama yolu cihazda doğrulanmalı; yetmezse AdMob eklentisinin sonraki sürümü beklenir ya da özel köprü yazılır (onay gerekir).
- Sahip: gerçek AdMob kimlikleri → `ads_ids.json` + `python3 tools/sync_ads_config.py`; Play Console `no_ads` ürünü + lisans test hesapları; gizlilik politikası URL'si → `privacy_policy_url`; "Reklam kimliği" beyanı = **Evet**; O8 kararı (§4).

## 7. Gerçek cihaz test listesi (test reklamı + lisans test satın alması)
Ön koşul: `mode=test`, debug veya imzalı iç test AAB'si; cihaz Play Store'a lisans test hesabıyla girmiş; test cihazı kaydı `adb shell setprop` değil, AdMob test kimlikleri (Google'ın herkese açık) yeterli.
1. **Temiz kurulum, AB dışı:** açılış → ana menüde kısa bilgi penceresi; Kabul/Reddet → bir daha sorulmaz; ilk test reklamı (ödüllü) pencereden **sonra** yüklenir (logcat'te `initialize` öncesi reklam isteği yok).
2. **AB/UK simülasyonu:** `Admob` `debug_geography=EEA` (geçici yerel değişiklik, commit'leme) → yalnızca UMP formu; oyun penceresi çıkmaz; form bitince reklam yüklenir. Ayarlar > Gizlilik seçenekleri > "Reklam seçenekleri" formu yeniden açar.
3. **Ödüllü:** akşam ekranı "çift maaş", masa "mesai" (son 60 sn), Günün Kuru yeniden, Sonsuz devam: ödül yalnız izlenince; erken kapatınca yok. Uçak modunda "Reklam şu an yok"; kovulma ekranında reklam yokken (O8 bağlanınca) ücretsiz yol.
4. **Geçiş reklamı:** hikaye günü ≥ 3, 2 birim sonra gün sonunda; masa ortasında hiç; hemen ardından ikincisi yok.
5. **Satın alma (`play_billing=true`, test ürünü):** Market'te fiyat (mağaza yerelleştirmeli) → satın al → Play sayfası → reklamlar kalkar, destekçi süsü; Play Console'da "onaylandı" (acknowledged); uygulamayı sil/yeniden kur → açılışta sahiplik geri gelir; "Geri yükle" düğmesi; iade (lisans testçisi) sonrası ilk açılışta sahiplik düşer mi (kayıt `purchases` yalnız ekleniyor — **iade senaryosu açık madde**, gerekirse T-M1 sonrası ele alınır).
6. **PENDING:** lisans test kartı "yavaş onay" → "Ödemen beklemede" mesajı, ödül yok; onaydan sonra uygulama açılınca sahiplik.
7. **Geç bağlanma:** uçak modunda Market → "Mağazaya bağlanılıyor…"; ağ gelince düğme otomatik açılır.
8. **Yapılandırma hatası:** (yalnız yerel deneme) `mode=real` + boş kimlik ile release derleme → logcat'te `[Monetization] ... reklam yapılandırması geçersiz` ve reklam yok; asla test reklamı yok.
9. `python3 tools/sync_ads_config.py --check` ve `tools/release_check.sh` çıktıları kaydedilir.
