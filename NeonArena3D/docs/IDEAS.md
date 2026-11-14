# Neon Arena 3D — Geliştirme Fikirleri ve Para Kazanma Tasarımı

Kaynak: `docs/ASSESSMENT.md` bulguları. Boyut: S ≤ 1 gün ajan işi, M ≈ 2–4, L ≈ 5+ (tek işçi). "Doğrulama" = otomatik ölçüt
(birim test / probe / denge simülasyonu). Yeni dosyalar mümkünse mevcut dosyalara dokunmayacak şekilde tasarlandı (bkz. `docs/ROADMAP.md`).

## Bölüm A — Oynanış derinliği (öncelik sırasıyla)

Ortak ön koşul: **denge simülasyonu** (`tools/sim/balance_sim.gd`: N tohum × gemi × yapı, headless bot; medyan dalga, ölüm nedeni,
çekirdek/koşu, saniye/koşu). Her fikir bu araçla "dalga ≥ X'e ulaşan bot oranı" gibi eşiklerle doğrulanır. Mevcut `smoke_test.gd` bot'u
(`player.autopilot`) temel alınır.

### 1. Sektör hedefleri + zafer ekranı + sektör arası risk/ödül seçimi (M) — en yüksek etki
- Ne: Koşu = 3 sektör × 5 dalga (≈ 8–10 dk) ve boss yenilince "SEKTÖR TEMİZ" + zafer; sonra "sonsuz mod" açılır. Sektör arasında 3 seçenekli
  kapı: (a) iyileş + kart yenileme, (b) "lanetli" kart (güçlü ama bedelli), (c) zor modifikatör (+%X çekirdek). Kısa seans için "5 dalgalık
  hızlı koşu" modu.
- Neden: Bugün sonu/ödül anı yok; mobil için net bir bitiş ve karar anı retention'ın temeli. Reklam yerleşimleri (koşu sonu) için doğal kırılma.
- Bağımlılıklar: `run_state.gd` (saf çekirdek, kolay), `balance.json` `waves`; UI ekranı (menü bölünmesi sonrası).
- Doğrulama: `test_run_state.gd` yeni aşama makinesi; sim: bot'un 3 sektörü tamamlama oranı hedef aralıkta (örn. %25–45 başlangıç donanımında).

### 2. Yeni düşman davranışları + elit ön ekleri (M)
- Ne: Bölücü (ölünce 2 küçük), kalkancı (çevre düşmanlara kalkan aurası, öncelikli hedef), mayın bırakan, ışınlanan (blink), sömürücü (XP çalar),
  kuluçka (ana gemi, düşman doğurur), yılan (iz bırakır). Elit ön ekleri: Hızlı, Yansıtıcı, Patlayıcı, Vampir (rastgele 1–2).
  İlk görünüm dalgaları `unlock` alanıyla kademeli.
- Neden: 10. dalgadan sonra "yeni şey öğrenme" yok → eğri düz. Her yeni davranış yeni karar (öncelik, konum) demek; en ucuz çeşitlilik.
- Bağımlılık: `enemy3d.gd`, `balance.json` `enemies`; model: mevcut glb'lerin renk/ölçek varyantı (yeni el modeli gerekmez; Blender betiği kullanılabilir).
- Doğrulama: `test_balance.gd` şeması, yeni probe `enemy_probe.gd` (her tür için davranış: bölünme sayısı, kalkan etkisi), sim: tür başına öldürme süresi/hasar payı.

### 3. Kart havuzunu 20 → 45'e çıkar + evrim (M)
- Ne: 25 yeni kart (ör. yörünge bıçakları, zaman yavaşlatma alanı, kara delik nova, geri tepme, kritik zinciri, yansıyan mermi, otomatik taret);
  "evrim": iki kart belirli seviyede birleşip yeni silah olur (Vampire-Survivors tarzı); kart "yasakla/banish" hakkı; lanetli kartlar (güç + bedel).
- Neden: Tekrar oynanabilirliğin ana kaynağı yapı çeşitliliği; sinerji sistemi marka kimliği olabilir ama yalnız 6 sinerji var.
- Bağımlılık: `cards.json`, `loadout.gd`; yeni etkiler `game3d.gd`/refactor sonrası modüllere kanca ister (hazır kanca arayüzü gerekli).
- Doğrulama: `test_loadout.gd` + `synergy_probe.gd` genişletmesi (her kart/evrim için etkinin ölçümü); sim: "kırık kombinasyon" taraması (kart çiftleri arası medyan dalga farkı ≥ eşik → uyarı).

### 4. Günlük meydan okuma (tohumlu) + görevler + başarımlar (M)
- Ne: Günün tohumu (tarihten türetilir, sunucu yok): sabit gemi, sabit modifikatörler (ör. "çift hızlı düşman, yarı can"), hedef skor/dalga;
  günlük 3 görev (örn. "20 elit öldür", "boss'u atılma ile yen") ödül çekirdek; ~40 başarım (rozet). Telefonda yerel "seri (streak)" göstergesi.
- Neden: Günlük geri dönüş sebebi; ödüllü reklam için doğal "günlük bonus" noktası. `RunState._init(balance, seed_value)` tohum zaten destekliyor.
- Bağımlılık: yeni `scripts/core/missions.gd`, `daily.gd`, `data/missions.json`; kayıt şeması (Settings), yeni ekran.
- Doğrulama: `test_daily.gd` (aynı tarih → aynı tohum/modifikatör; saat dilimi sınırı), `test_missions.gd` (ilerleme, tek seferlik ödül, kayıt gidiş-dönüşü).

### 5. Arena tehlikeleri ve sektör modifikatörleri (M)
- Ne: Haritaya mekanik kimlik: Neon = lazer ızgara (periyodik koridor), Kızıl = lav şeritleri/alan hasarı, Buz = kayma (düşük sürtünme) + donma
  bölgeleri; ek olarak "kütleçekim kuyusu", "EMP alanı (nova kapalı)". Dalga başı rastgele modifikatör (örn. karanlık: görüş azalır, hızlı).
- Neden: Haritalar şu an yalnız renk; mekanik fark tekrar oynanabilirlik ve boss öncesi ritim yaratır.
- Bağımlılık: `map_builder.gd`, yeni `scripts/world/hazards.gd` + `data/maps.json`; shader (ring/field_wall mevcut stil).
- Doğrulama: `hazard_probe.gd` (hasar alanı oyuncuya doğru hasar veriyor mu, uyarı süresi ≥ X sn), sim: tehlike başına ölüm payı ≤ %30.

### 6. Hissiyat (juice) paketi (S)
- Ne: Hit-stop (2–4 kare, ağır vuruş/boss/elit), öldürme zincirinde yükselen perde + kamera nabzı, seviye atlamada kısa yavaşlatma, ölümde
  ağır çekim (var, ince ayar), silah/gemi başına iz renkleri ve namlu alevi, kritik vuruşta ayrı ses/parıltı, kamera darbesi ölçeklemesi,
  erişilebilirlik: "azaltılmış ışık/sarsıntı" anahtarı.
- Neden: Düşük maliyet, yüksek algılanan kalite; mağaza videosu/ekran görüntüsü kalitesini artırır.
- Bağımlılık: `fx.gd`, `sparks.gd`, `sound.gd`; hit-stop için oyun döngüsü kancası (refactor sonrası).
- Doğrulama: `fx_probe.gd` (hit-stop süresi toplam zamanı bozmuyor, `Engine.time_scale` her zaman geri dönüyor), `audio_report.py` LUFS/tepe sınırları.

### 7. Onboarding + erişilebilirlik + tek el (M)
- Ne: İlk koşuda etkileşimli 60 sn öğretim (hareket ettir → vur → atıl → ilk kart → nova; her adım tamamlanana dek bekler), metinsiz ikon ağırlıklı
  ipuçları. "Tek el modu": yalnız sol çubuk + otomatik nişan/ateş/atılma (düşmana yaklaşınca otomatik atılma opsiyonu), sol-el yerleşim,
  düğme boyut/konum ayarı, renk körü paleti, yazı ölçeği.
- Neden: İlk 30 sn kayıp oranı ve mağaza yorumlarının en sık şikâyetleri (kontrol).
- Bağımlılık: `touch_controls.gd`, `hud.gd`, ayarlar ekranı.
- Doğrulama: `touch_probe.gd` genişletmesi (sol-el düzeninde aynı kontroller çalışıyor), öğretim adımı probe'u (sentetik girdiyle tamamlanır), ekran görüntüsü karşılaştırması.

### 8. Gemi başına aktif yetenek/pasif + 2 yeni gemi (M)
- Ne: Her gemiye benzersiz pasif (örn. Kasırga: yakın mesafe hasar aurası; Mızrak: şarj olan atış) + 2 yeni gemi (örn. "Orbit": dönen bıçaklar,
  "Mimar": taret kurar). Gemiye özel mini görev ("Mızrak ile 5. dalga") ile açma seçeneği.
- Neden: Gemi seçimi şimdi sadece silah tipi; kimlik ve koleksiyon hedefi ekler.
- Bağımlılık: `ships.json`, `player3d.gd`, yeni glb (Blender betiği ile procedural).
- Doğrulama: `ship_probe.gd` (her gemi yetenek etkisi), sim: gemiler arası medyan dalga farkı ≤ %20.

### 9. Meta ilerleme derinliği (M)
- Ne: İkinci para birimi (boss'tan "Çekirdek Kristali") ile gemi başına ustalık ağacı (3 kademe), kart kilidi (yeni kartlar seviye/başarımla açılır —
  koşuyu kirletmeden "yeni oyuncuya az kart"), kozmetik iz/gövde rengi (shader parametresi; dükkân). "Sonsuz sektör" için zorluk ısısı (heat)
  çarpanı çekirdek kazancını artırır.
- Neden: Bugün tüm meta ≈5150 çekirdekte bitiyor (60–70 koşu). 
- Bağımlılık: `meta_progress.gd`, `upgrades.json`, Atölye UI.
- Doğrulama: `test_meta_progress.gd`; sim: ekonomi eğrisi (koşu başına çekirdek / toplam sink ≥ 150–250 koşu).

### 10. Boss çeşitliliği: mini-boss + 4. sektör boss + boss rush (L)
- Ne: Her 5 dalgada boss yerine bazı sektörlerde mini-boss + sonda büyük boss; yeni boss "Kovan Ana" (doğurma + alan kontrolü). Modüler saldırı
  kütüphanesi (radyal, sarmal, lazer, yer uyarı, ışınlanma, sıçrama zaten var) → veriden boss kurma; ardından "boss rush" modu.
- Neden: Bosslar oyunun en iyi parçası (okunaklı saldırı dili) — daha fazlası doğrudan değer.
- Bağımlılık: `boss3d.gd` modülerleştirme; yeni glb (procedural).
- Doğrulama: `boss_probe.gd` (her boss'un tüm saldırıları tetikleniyor, faz geçişi, ölüm), sim: boss başına yenilme süresi aralığı.

### 11. Zorluk modları / ısı sistemi (S)
- Ne: Normal / Zor / Kâbus: düşman hızı, HP, mermi sayısı ve çekirdek çarpanı; "ısı" seviyesi koşu başında seçilir. Reklam/IAP ile ilgisi yok.
- Neden: Eski oyuncular için eğri; atölye gücünü dengeler.
- Doğrulama: sim (her mod için hedef medyan dalga), `test_balance.gd`.

### 12. Koşu içi olaylar ve pikaplar (S–M)
- Ne: Rastgele olaylar (hazine drone'u 10 sn içinde vur → ödül; "kırmızı alarm" kısa yoğun dalga, bonus çekirdek), yeni pikaplar (mıknatıs, bomba, dondurma,
  zaman yavaşlatma), mini dükkân (çekirdek kristali harca).
- Neden: Dalga arası boşlukları ve tempo değişimini sağlar.
- Doğrulama: `event_probe.gd`; sim: olay başına ödül/ risk.

### 13. Yaşam kalitesi ve istatistik (S)
- Ne: Koşu özeti ekranında "neden öldün" (öldüren düşman/mermi türü), koşu geçmişi (son 10), Hakkında ekranı (OFL font atıfları, sürüm),
  paylaş ekran görüntüsü (yalnız yerel kaydet; ağ yok), ana menüde geri tuşu için "çıkmak istiyor musun?" onayı.
- Doğrulama: birim test (ölüm nedeni kaydı), ekran görüntüsü aracı.

### 14. Çoklu dil genişletme (S–M)
- Ne: ES/PT-BR/DE/FR vb. (otomatik çeviri + sahip incelemesi), `tr()` anahtarlarını kimlik tabanlı tabloya çevirme (Türkçe cümle anahtarı kırılgan).
- Doğrulama: `test_i18n.gd` her dil için eksik anahtar = 0; taşma kontrolü ekran görüntüsüyle.

## Bölüm B — Önerilen ilk 5 (en yüksek etki/maliyet)
1. **#1 Sektör hedefleri + zafer + risk/ödül kapıları** — oyuna şekil ve reklam yerleşimi için doğal kırılma verir.
2. **#2 Yeni düşman davranışları + elit ön ekleri** — tüm eğriyi canlandırır, en ucuz çeşitlilik.
3. **#3 Kart havuzu + evrim + lanetli kartlar** — tekrar oynanabilirliğin motoru.
4. **#4 Günlük meydan okuma + görev + başarım** — retention ve günlük ödüllü reklam noktası.
5. **#6 + #7 Juice ve onboarding/tek el** — ucuz; ilk izlenim ve mağaza videosu kalitesini belirler.

Sonra: #5 tehlikeler, #9 meta, #10 bosslar, #8 gemiler, #11–#14.

## Bölüm C — Para kazanma tasarımı

### C.1 Öneri (özet)
| Öğe | Karar | Gerekçe |
|---|---|---|
| Ödüllü: **İkinci şans (revive)** | Evet, koşu başına 1 kez, ölüm ekranında "ÖLDÜN — izle ve devam et" (yarı can + 2,2 sn dokunulmazlık; mevcut `_on_player_died` kancası) | Oyuncu için net değer, rakip türlerde en iyi dönüşüm; `ikincisans` kartıyla çakışmaz (kart zaten 1 kez; reklam revive'ı ondan sonra) |
| Ödüllü: **Koşu sonu çekirdek ×2** | Evet, game over ekranında | Atölye ekonomisini hızlandırır, pay-to-win değil (yalnız ilerleme hızı) |
| Ödüllü: **Kart yenileme (reroll) +1** | Evet, kart ekranında "reklam izle → +1 yenileme", koşu başına en fazla 2 | Kart seçimi oyunun kalbi; "ücretsiz ama isteğe bağlı" |
| Ödüllü: **Günlük bonus sandığı** | Evet (günlük meydan okuma ile birlikte), günde 1 | Günlük geri dönüş |
| Geçiş (interstitial) | Sadece koşu bitiminde, "TEKRAR OYNA / ANA MENÜ"e basıldığı anda; ilk 3 koşuda yok; son geçişten ≥ 180 sn; her 2. ölümden fazla değil; revive/çift çekirdek reklamı izlendiyse o ölümde yok; "reklamsız" alındıysa asla | Doğal kırılma, kısa koşularda bile bezdirmez |
| Banner | Hayır | Oyun alanını/HUD'u kirletir, düşük gelir |
| **Reklamları kaldır (tek seferlik IAP)** | Evet — yalnız geçiş reklamını kaldırır, ödüllü reklamlar isteğe bağlı kalır; fiyat sahibin kararı | Genre standardı, adil |
| Başlangıç/çekirdek paketi IAP | **İlk sürümde hayır**; sonra isteğe bağlı küçük "başlangıç paketi" (reklamsız + 1500 çekirdek) düşünülebilir | Çevrimdışı tek oyunculu; çekirdek satışı meta ilerlemeyi ucuzlatır, tasarım değeri düşürür |

**Asla yapılmayacaklar:** oyun sırasında (savaşta/kart seçerken/boss anında) reklam; ilk 3 koşuda geçiş reklamı; reklam izlemeden ilerleyememe
(zorunlu duvar); zamanlayıcı/kıtlık baskısı ("24 saatte bitiyor"); yanlış yönlendiren/yaklaşık kapatma düğmeleri; ödüllü reklam gösterilmeden
ödül verme (ödül yalnız sağlayıcıdan `rewarded` gelince); kendi reklamına tıklama/üretim kimliğiyle test (hesap yasağı sebebi); çocuk hedef kitlesi
için kişiselleştirilmiş reklam; ağ yokken takılan akış (reklam hazır değilse sessizce sürer); gücü doğrudan para ile satmak (yalnız hız/kozmetik/reklamsız).
Çocuk hedef kitle/derecelendirme kararları sahibe ait (`ROADMAP.md` sahip listesi).

### C.2 Teknik şekil
Sınır = `AdsProvider` arayüzü; hiçbir oyun kodu SDK'yı görmez. Yeni yerleşimler `Placement` enum'una sona eklenir.

```
scripts/services/ads_provider.gd         (arayüz: initialize/is_ready/show/preload_ads + sinyaller shown/rewarded/dismissed/failed)
scripts/services/mock_ads_provider.gd    (masaüstü/test/hata ayıklama: sahte "izlendi" + gecikme/başarısızlık simülasyonu)
scripts/services/no_ads_provider.gd      (release'te eklenti yoksa: sessiz)
scripts/services/admob_ads_provider.gd   (yükle/göster/yeniden dene/zaman aşımı durum makinesi)
scripts/services/admob_bridge.gd         (taban: "eklenti yok") + poing_admob_bridge.gd (Poing Studios godot-admob-plugin v5.1.0 bağlantısı, UMP dahil)
scripts/autoload/AdManager.gd            (autoload; yerleşim başına limit, bekleyen istek bileti, 3 sn zaman aşımı)
scripts/core/ad_pacing.gd                (SAF karar fonksiyonu; veri: data/ads.json)
data/ads.json                            (limitler + pacing + AdMob kimlikleri: mode=test|production)
tests/unit/test_ad_*.gd                  (manager, pacing, admob durum makinesi, poing köprü)
```
**Şablondan olduğu gibi kopyalanabilir** (referans: `/Users/alperaygorduler/Desktop/Games/studio-kit/template-mobile`, salt okunur):
`scripts/services/*` (6 dosya), `scripts/autoload/AdManager.gd`, `tests/unit/test_ad_admob.gd`, `test_ad_manager.gd`, `test_ad_poing_bridge.gd`,
`data/ads.json` yapısı (`admob` bloğu ve `settings`), `docs/MONETIZATION.md` kuralları, UMP/consent akışı (`admob.request_consent`),
test kimliği → üretim kimliği güvenlik kuralı (release + `mode=production` + `REPLACE_*` yok), `export_presets.cfg` "Android (release)" ön ayarı
(Gradle AAB, arm64, `internet`/`access_network_state` izinleri), `tools/pck_check.py`, `tools/size_report.py`.

**Uyarlanacaklar:**
- `AdManager.Placement`: `CONTINUE`, `DOUBLE_COINS`, `INTERSTITIAL` → `REVIVE`, `DOUBLE_CORES`, `REROLL`, `DAILY_BONUS`, `INTERSTITIAL`;
  `AdsProvider.INTERSTITIAL_PLACEMENT` sabiti ve ilgili test ile **birlikte** güncellenir (enum sırası testle sabitli).
- `ad_pacing.gd`: şablon **seviye numarası** bazlı (puzzle). Burada koşu/süre bazlı olmalı: `should_show(runs_completed, seconds_since_last, deaths_since_last, ads_removed, rewarded_in_transition, pacing)`;
  veri: `first_run`, `min_seconds`, `every_n_deaths`. Saf fonksiyon + birim test (sınır değerleri: 3. koşu yok, 4. var, 179 sn yok, 180 var, remove-ads daima yok).
- `data/ads.json` yerleşim limitleri: `REVIVE per_run 1`, `DOUBLE_CORES per_run 1`, `REROLL per_run 2`, `DAILY_BONUS per_session 1`.
- Şablonun **çevrimiçi kapısı (`scripts/net/*`, `require_online`) alınmaz**: bu oyun çevrimdışı oynanır.
- `AnalyticsLog` (ağsız halka tampon) alınabilir (`scripts/core/analytics_log.gd`); gerçek analitik ayrı karar.
- Kayıt: `Settings`'e `ads_removed`, günlük bonus tarihi, koşu sayacı (sürümlü kayıt şeması ile) eklenir; şablon `Progress.remove_ads_owned()` karşılığı.
- IAP: şablonda yok (`MONETIZATION.md` §5). `IapProvider` arayüzü + `MockIapProvider` + Play Billing sağlayıcısı yazılır; açılışta sahiplik mağazadan yeniden doğrulanır, çevrimdışı iken yerel bayrak kullanılır.
- Entegrasyon noktaları (oyun kodu): `_on_player_died` (revive), `show_gameover` (çift çekirdek + geçiş), `show_cards` (reroll), ana menü (günlük). Hepsi `AdManager` sinyalini dinler; oyun, sağlayıcı olmadan da çalışır (reklam yoksa düğmeler gizli/pasif).
- Teknik ön koşul: AdMob yerel eklentisi **Gradle build** ister; mevcut `use_gradle_build=false` ön ayarı değişmeli ve `android/build` şablonu kurulmalı (sahip onayı: eklenti indirme).

**Doğrulama (otomatik):** `tests/unit/test_ad_pacing.gd` (tablo testi), `test_ad_manager.gd` (ödül yalnız `rewarded` ile; limitler; zaman aşımı akışı serbest bırakır),
`MockAdsProvider` ile oyun akışı probe'u (`ads_flow_probe.gd`: revive reklamı → oyuncu canlanır; reklam başarısız → ödül yok; remove-ads → geçiş yok),
`pck_check.py` (test kimliği/anahtarların pakete sızmaması). Cihazda manuel: `docs/MONETIZATION.md` §6 listesi (test reklam kimlikleriyle).

### C.3 Beklenti notu
Reklam gelirini artırmak için tasarlanan baskı yok; revive/çift çekirdek/yenileme düğmeleri yalnız oyuncu isterse çıkar. Gerçek dönüşüm/geliri
**ölçülemez ve tahmin etmiyorum**; kapalı testte sezgisel değerlendirme (kaç oyuncu reklam seçiyor, kaçı çıkıyor) önerilir.
