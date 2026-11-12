# TASKS — Micro Courier

| Faz | Konu | Durum |
|---|---|---|
| 0 | İskelet (Boot/Menu/Game/Result, autoload'lar, tema, testler) | ✅ |
| 1 | Çekirdek mantık (saf `core`, testler ÖNCE) | ✅ |
| 2 | Fizik: robot + sallanan kargo + oyun akışı (HUD, kontrol noktası, teslimat) | ✅ (his onayı kullanıcıda) |
| 3 | Çalışma Masası haritası ve tehlikeler | ✅ |
| 4 | Meta: çekirdek, `SaveService`, sipariş, garaj, sonuç ekranı | ✅ |
| 5 | Reklam yerleşimleri (revive, batarya, 2× ödül, deneme sürüşü, Altın Kutu) | ✅ |
| 6 | Şok Jeli modülü, ses (SFX), ilk açılış rehberi, ayarlar | ✅ (SFX kulakla dinlenmeli) |
| 7 | **GÖRSEL FAZ (ayrı):** 7.1 ✅ · **stil A seçildi** · 7.2 ✅ · 7.3 robot/kargo/eşya modelleri ✅ · 7.4–7.8 sırada | 🟨 |
| 8 | Final: tam doğrulama, performans, Android derleme, kullanıcı paketi | ⬜ |

Kullanıcı kararı (2026-11-11): çözüm hattında **tek aday** (iki aday yarıştırma kaldırıldı); görseller beğenilmedi → ayrı Faz 7; işlevsel fazlar önce.

Etiketler: **[K]** kolay/mekanik · **[O]** orta · **[Z]** zor · **[T]** önce-test hattı (`solve.sh --tests-first` ya da lider testleri) ·
**[F]** fizik/his (otomatik doğrulanamaz; oyuncu denemesi) · **[U]** kullanıcı kararı bekliyor.

---

## Faz 0 — İskelet ✅

- [x] `project.godot` — portre, `gl_compatibility`, statik tip hataları açık
- [x] Autoload dörtlüsü: `GameManager`, `AudioService`, `AdManager`, `GameData`
- [x] Sahneler: Boot → Menu → Game → Result; tema + font; `RunScoring` + testler; `tools/verify.sh`

---

## Faz 1 — Çekirdek mantık  (hepsi [T]; sözleşmeler `ARCHITECTURE.md` §4)

**Hedef:** Oyunun sayısal kuralları sahne olmadan, testle sabit. Fizik prototipi bu sınıflara ölçüm besler.

- [x] **F1.1** `data/cargo.json` + şema testi (zorunlu anahtarlar, aralıklar) [K][T]
- [x] **F1.2** `DamageModel` (statik) — eşikler, sınırlar, kırpma [O][T]
- [x] **F1.3** `CargoHealth` — birikim, Şok Jeli koruması (0.95 kuralı), kırık kargo [O][T]
- [x] **F1.4** `BatteryModel` — tüketim, hız faktörü, boost, doldurma [O][T]
- [x] **F1.5** `DeliveryReward` — altın/hurda, `RunScoring` ile uyum [O][T]
- [x] **F1.6** `CheckpointTracker` — yalnız ileri ilerleme [K][T]
- [x] **F1.7** `Wallet` — Altın/Hurda bakiyesi, harcama, kayıt sözlüğü [K][T]

Bitti: `verify.sh` yeşil, her sınıfın sınır değeri testleri var, `CHANGELOG.md` güncel.

---

## Faz 2 — Fizik prototipi  ([Z][F]; K4: projenin tek riski)

**Hedef:** Boş bir masada robot sürülür, sırtta kargo gerçekçi sallanır, rampadan atlanır, kargo darbesi `CargoHealth`'e akar ve HUD'da görünür.
**Kapı:** Bu faz bittiğinde **kullanıcı oynar**; hissi onaylamadan Faz 3'e geçilmez.

- [x] **F2.1** Robot: `RigidBody3D` + 4 raycast süspansiyon, joystick girdisi, hızlanma/dönme eğrisi [Z][F]
- [x] **F2.2** Kargo sepeti: sırtta `RigidBody3D` + yaylı 6DOF (ya da yay-sönüm kodu); iki yaklaşımı `game_probe.gd` ile karşılaştır [Z][F]
- [x] **F2.3** Kamera: arkadan-yukarıdan takip [O][F]
- [~] **F2.4** Test haritası: düz masa ve rampa ✅ (Proto.tscn); kenar + düşme sınırı → kontrol noktası bekliyor [O]
- [ ] **F2.5** `ImpactSensor` + sinyaller → `CargoHealth` → HUD sağlık çubuğu [O]
- [ ] **F2.6** Havada denge kaydırması [Z][F]
- [x] **F2.9** Ters dönme kurtarması: robot >100° eğik 1.5 sn kalırsa kendini doğrult (inceleme bulgusu) [K]
- [x] **F2.10** Proto ortam ışığı: `ambient_light_source` uyumsuzluğu, daha parlak/doygun low-poly görünüm (şu an koyu lacivert gökyüzü) [K]
- [x] **F2.7** `tools/game_probe.gd`: sabit girdiyle sürüş, sallanma genliği ve hasar eğrisi çıktısı [O]
- [x] **F2.8** Fizik sabitlerini `data/balance.json`'a taşı ve ayar rehberi yaz [K]

Fizik işlerinde **best-of-N** (`solve.sh --workers "dsh:sol dsh"`) ve görsel denetim (`shots.sh`) kullanılır; kabul: `verify.sh` + `game_probe` sayıları + kullanıcı denemesi.

---

## Faz 3 — Masa haritası ve tehlikeler

- [x] **F3.1** `LevelRoot`: başlangıç, kontrol noktaları, teslimat bölgesi [O]
- [x] **F3.2** `KeyboardKey` (aniden basılan tuş, işaret verir) [O][F]
- [x] **F3.3** `FanWind` (dönen fan rüzgârı, Area3D kuvvet) [O][F]
- [x] **F3.4** `RollingPencil` (yuvarlanan kalem) [O][F]
- [x] **F3.5** Cetvel rampası ve kısayol [O]
- [x] **F3.6** Masa görsel stili (low-poly, doygun renk) [O]

## Faz 4 — Oyun döngüsü

- [x] **F4.1** `OrderSelect`: 3 kargo kartı → `GameManager` [O]
- [x] **F4.2** Teslimat sonu: `DeliveryReward` → `Result` genişletme [K]
- [x] **F4.3** `UpgradeModel` + `data/upgrades.json` (şasi, tekerlek, batarya) [O][T]
- [x] **F4.4** `Garage` ekranı [O]
- [x] **F4.5** `SaveService` (user://save.json, sürümlü, bozuk dosya toleransı) [O][T]

## Faz 5 — Reklam yerleşimleri  (`AdManager`; sözleşme ARCHITECTURE §5.5 yazılacak)

- [x] **F5.1** `CARGO_INSURANCE` (revive): kargo kırılınca/masadan düşünce teklif; kabul edilirse son kontrol noktasında sağlam kargo [O]
- [x] **F5.2** `BATTERY_RECHARGE`: batarya bitince HUD düğmesi, reklamla %100 + 10 sn boost [K]
- [x] **F5.3** `DOUBLE_REWARD`: sonuç ekranında 2× ödül [K]
- [x] **F5.4** `TRY_BEFORE_BUY`: garajda kilitli yükseltmeyi 1 koşu deneme [O]
- [x] **F5.5** Altın Kutu (seviyede ulaşması zor kutu → teslimde bonus açma reklamı) [O]

## Faz 6 — Modül, ses, rehber

- [x] **F6.1** Şok Emici Jel modülü (MVP modülü): garajdan sahip olunur, koşu başında takılı; kargo ilk kırılmayı atlatır (`CargoHealth` jel hakkı) [O]
- [x] **F6.2** SFX seti (ElevenLabs `make_sfx.py` ya da yedek sentez): çarpma, klavye tıkı, teslimat, satın alma, UI; ASMR hissi [O]
- [x] **F6.3** İlk açılış rehberi (3 kısa ipucu), ayarlar (ses açık/kapalı), geri tuşu davranışı [O]

## Faz 7 — GÖRSEL FAZ (ayrı faz; kullanıcı geri bildirimi: pikselimsi/basit; daha detaylı, modern UI, animasyonlar)

Hedef: **low-poly'nin üstü**, pürüzsüz ve ürün kalitesinde stilize görünüm. Her adım ekran görüntüsüyle denetlenir (`scene_shot.gd`); son onay kullanıcıdadır [U]. Fizik/oynanış probe sayıları değişmez.

- [x] **F7.1** Stil laboratuvarı; stil A seçildi
- [x] **F7.2** Malzeme/shader sistemi, ışık, ahşap masa
- [x] **F7.3** Robot/kargo/eşya modellerinin oyuna girişi (ilk sürüm, basit modellerle)
- [x] **F7.4** Kamera + ortam (oda derinliği, pencere ışığı, toz) ✅ (ilk sürüm; model v2 ile yenilenecek)
- [x] **F7.9** **Render kalitesi:** MSAA/FXAA ile kenar tırtığı yok, doku/mip filtreleme, yumuşak toon bantları ve anti-aliased anahat, ölçek [O]
- [x] **F7.10a** **Model v2 — robot, tekerlek, sepet, 3 kargo:** hero kalite (kavisli formlar, bevel, yumuşak normal, yüz/detaylar) [Z]
- [x] **F7.10b** **Model v2 — masa eşyaları ve oda/çevre kiti:** monitör, lamba, bitki, kitap yığını, kulaklık, defter, kalemlik, yapışkan not, pencere/raf/perde, klavye/kupa/kalem/cetvel/kitap yenileme [Z]
- [x] **F7.10c** Model v2 sahne entegrasyonu (Game/Proto/level/menü vitrini) [O]
- [x] **F7.6b** **Modern, nazik, sade UI/UX** + ikon sistemi (HUD, menü, sipariş, garaj, sonuç, ayarlar, rehber) [Z]
- [x] **F7.11** (robot + UI/dünya ✅) **Animasyon ve "juice":** robot (idle, sürüş, iniş squash, anten, yüz ifadeleri), dünya (tuş, fan, kalem, buhar, toz), UI (geçişler, sayaç, yıldız, düğme), kamera, parçacıklar, ses-senkron [Z]
- [x] **F7.8** (lider QA turu; kullanıcı onayı bekliyor) Görsel QA turu + kullanıcı onayı [U]

## Faz 8 — Final

- [x] **F8.1** Performans: `perf_probe` ve düşük segment Android hedefi (60 FPS), çokgen/draw call bütçesi [O]
- [x] **F8.2** Android debug export hazırlığı (`export_presets.cfg`, APK notları) [K]
- [ ] **F8.3** Tam kabul koşusu (tüm probalar + `verify.sh`), CHANGELOG/README, kullanıcı oynama paketi [K]

---

## Kararlar

Bkz. `PROJECT_SPEC.md` §12 (ad: Micro Courier; Altın+Hurda; MVP modülü Şok Jeli; K1 onaylı).
Kullanıcı onayı gerektirenler: oyun hissi (Faz 2 kapısı), mağaza/yayın, ücretli API.

## Faz 9 — Sonsuz level modu

- [x] **F9.1** Tasarım kararları (PROJECT_SPEC §14) ✅
- [x] **F9.2** Çekirdek: `LevelProgression`, `EndlessReward`, `RunRecords` (ProfileData) + testler [Z]
- [x] **F9.3** Çalışma zamanı: parça dizici, sonsuz level, teslimat noktası, GameController entegrasyonu [Z]
- [x] **F9.4** Parça kütüphanesi ve yeni engeller (segment sözleşmesi + `segment_probe`) [Z]
- [x] **F9.5** HUD (level/mesafe/kasa), sonuç ve rekor arayüzü, öğretici ✅ (ekonomi dengesi: oyun denemesi sonrası)
- [x] **F9.6** Çevre temaları (raf, mutfak…) [Z]
- [x] **F9.7** `endless_probe`, tam kabul, APK [K]
