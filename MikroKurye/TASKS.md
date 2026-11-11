# TASKS — Micro Courier

| Faz | Konu | Durum |
|---|---|---|
| 0 | İskelet (Boot/Menu/Game/Result, autoload'lar, tema, testler) | ✅ |
| 1 | Çekirdek mantık (saf `core`, testler ÖNCE) | ✅ Tamam |
| 2 | Fizik prototipi: robot + sallanan kargo + rampa (**oyuncu denemesi kapısı**) | 🟨 Robot ✅; kargo sırada |
| 3 | Masa haritası ve tehlikeler | ✅ Tamam (görsel cila V2'de) |
| 4 | Oyun döngüsü: sipariş, teslimat, ödül, garaj, kayıt | ⬜ |
| 5 | Reklam yerleşimleri | ⬜ |
| 6 | Modüller, mutfak/salon, boss | ⬜ |
| 7 | Cilalama, ses (ASMR), UA kreatifleri | ⬜ |

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

- [ ] **F4.1** `OrderSelect`: 3 kargo kartı → `GameManager` [O]
- [ ] **F4.2** Teslimat sonu: `DeliveryReward` → `Result` genişletme [K]
- [x] **F4.3** `UpgradeModel` + `data/upgrades.json` (şasi, tekerlek, batarya) [O][T]
- [ ] **F4.4** `Garage` ekranı [O]
- [ ] **F4.5** `SaveService` (user://save.json, sürümlü, bozuk dosya toleransı) [O][T]

## Faz 5 — Reklam yerleşimleri

- [ ] **F5.1** `CARGO_INSURANCE` (revive → son kontrol noktası, sağlam kargo) [O]
- [ ] **F5.2** `BATTERY_RECHARGE` [K]
- [ ] **F5.3** `GOLDEN_BOX` [O]
- [ ] **F5.4** `TRY_BEFORE_BUY` [O]

## Faz 6–7

Modüller (Kanca, Şok Jeli, Drone), Mutfak ve Salon, Robot Süpürge boss, ses (ASMR), UA kreatifleri. Ayrıntı Faz 3–4 bittiğinde.

---

## Kararlar

Bkz. `PROJECT_SPEC.md` §12 (ad: Micro Courier; Altın+Hurda; MVP modülü Şok Jeli; K1 onaylı).
Kullanıcı onayı gerektirenler: oyun hissi (Faz 2 kapısı), mağaza/yayın, ücretli API.
