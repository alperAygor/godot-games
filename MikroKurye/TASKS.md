# TASKS — Micro Courier

| Faz | Konu | Durum |
|---|---|---|
| 0 | İskelet (Boot/Menu/Game/Result, autoload'lar, tema, testler) | ✅ |
| 1 | Çekirdek mantık (saf `core`, testler ÖNCE) | ✅ |
| 2 | Fizik: robot + sallanan kargo + oyun akışı (HUD, kontrol noktası, teslimat) | ✅ (his onayı kullanıcıda) |
| 3 | Çalışma Masası haritası ve tehlikeler | ✅ |
| 4 | Meta: çekirdek, `SaveService`, sipariş, garaj, sonuç ekranı | ✅ |
| 5 | Reklam yerleşimleri (revive, batarya, 2× ödül, deneme sürüşü) | ⬜ |
| 6 | Şok Jeli modülü, ses (SFX), ilk açılış rehberi, ayarlar | ⬜ |
| 7 | **GÖRSEL FAZ (ayrı):** sanat yönü yenileme, shader/ışık/ortam, robot, efektler, UI teması | ⬜ |
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

- [ ] **F5.1** `CARGO_INSURANCE` (revive): kargo kırılınca/masadan düşünce teklif; kabul edilirse son kontrol noktasında sağlam kargo [O]
- [ ] **F5.2** `BATTERY_RECHARGE`: batarya bitince HUD düğmesi, reklamla %100 + 10 sn boost [K]
- [ ] **F5.3** `DOUBLE_REWARD`: sonuç ekranında 2× ödül [K]
- [ ] **F5.4** `TRY_BEFORE_BUY`: garajda kilitli yükseltmeyi 1 koşu deneme [O]
- [ ] **F5.5** Altın Kutu (seviyede ulaşması zor kutu → teslimde bonus açma reklamı) [O]

## Faz 6 — Modül, ses, rehber

- [ ] **F6.1** Şok Emici Jel modülü (MVP modülü): garajdan sahip olunur, koşu başında takılı; kargo ilk kırılmayı atlatır (`CargoHealth` jel hakkı) [O]
- [ ] **F6.2** SFX seti (ElevenLabs `make_sfx.py` ya da yedek sentez): çarpma, klavye tıkı, teslimat, satın alma, UI; ASMR hissi [O]
- [ ] **F6.3** İlk açılış rehberi (3 kısa ipucu), ayarlar (ses açık/kapalı), geri tuşu davranışı [O]

## Faz 7 — GÖRSEL FAZ (ayrı faz; kullanıcı görselleri beğenmedi)

Hedef: "yer tutucu prototip" görünümünden **ürün kalitesinde stilize low-poly** görünüme. Her adım ekran görüntüsüyle denetlenir (`scene_shot.gd`, `shots.sh`); son onay kullanıcıdadır [U].

- [ ] **F7.1** Sanat yönü yeniden tanımı: PROJECT_SPEC §13 güncellenir (referans, palet, malzeme dili, ışık); kısa bir "stil kılavuzu" sahnesi (`scenes/StyleGuide.tscn`) [O]
- [ ] **F7.2** Shader sistemi: toon/cel gölgelendirme + rim ışık, anahatlar (outline), ahşap masa dokusu (prosedürel), düşük maliyetli (mobil/Compatibility) [Z]
- [ ] **F7.3** Robot yeniden tasarımı: karakterli yüz/gözler, kurye detayları, tekerlek ve süspansiyon görselleri, idle/hız animasyonları (squash & stretch, anten) [Z]
- [ ] **F7.4** Ortam: oda (duvar, pencere ışığı, uzakta dev objeler), masa kenarı derinliği, yumuşak gölge, bloom/renk düzeltme, hafif toz parçacığı [Z]
- [ ] **F7.5** Efektler: çarpma kıvılcımı, hız çizgileri, kırılma, kontrol noktası/teslimat konfeti, klavye tuşu uyarı parıltısı [O]
- [ ] **F7.6** UI teması: HUD, menü, sipariş kartları, garaj, sonuç; ikonlar (Lucide/Kenney), yazı tipi, düğme animasyonları [O]
- [ ] **F7.7** Kamera: hız bağımlı FOV, hafif sarsıntı, geçişler [K]
- [ ] **F7.8** Görsel QA turu: tüm ekranların ekran görüntüleri, tutarlılık düzeltmeleri; kullanıcı onayı [U]

## Faz 8 — Final

- [ ] **F8.1** Performans: `perf_probe` ve düşük segment Android hedefi (60 FPS), çokgen/draw call bütçesi [O]
- [ ] **F8.2** Android debug export hazırlığı (`export_presets.cfg`, APK notları) [K]
- [ ] **F8.3** Tam kabul koşusu (tüm probalar + `verify.sh`), CHANGELOG/README, kullanıcı oynama paketi [K]

---

## Kararlar

Bkz. `PROJECT_SPEC.md` §12 (ad: Micro Courier; Altın+Hurda; MVP modülü Şok Jeli; K1 onaylı).
Kullanıcı onayı gerektirenler: oyun hissi (Faz 2 kapısı), mağaza/yayın, ücretli API.
