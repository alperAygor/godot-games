# Changelog

Format [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/), sürümleme [SemVer](https://semver.org/lang/tr/).

## [Unreleased]

### Eklendi
- Faz 1 çekirdek: `BatteryModel`, `Wallet` (Altın/Hurda), `CheckpointTracker`, `DeliveryReward`, `data/cargo.json` + testler (85 test).
- Faz 2 robot dilimi: `RobotController` (RigidBody3D + 4 raycast süspansiyon), `SuspensionWheel`, `CameraRig`, `InputService` (klavye + sanal joystick), `Proto.tscn` (zemin + rampa), fizik parametreleri `data/balance.json`; `tools/game_probe.gd` kabul probu.
- Faz 2 kargo dilimi: `CargoBasket` (açık yay-sönüm sallanma, `impact_reported`/`slosh_reported`), ters dönme kurtarması, parlak ortam ışığı; 6DOF eklem karşılaştırması `docs/physics/`.
- Faz 3: `desk_01.tscn` (72 m masa haritası), `KeyboardKey`/`FanWind`/`RollingPencil` tehlikeleri, kontrol noktaları, V1 modelleriyle masa eşyaları; `level_probe` kabul probu.
- Faz 4a: `UpgradeModel`, `ProfileData`, `data/upgrades.json`; V1 Blender model seti (11 model).
- Faz 4b: `SaveService` (atomik kayıt, bozuk dosya yedeği), `OrderSelect`, `Garage`, menü/sonuç bağlantıları, yükseltme efektleri (`state.mods`); `meta_probe`.
- Faz 5: reklam yerleşimleri (CARGO_INSURANCE revive, BATTERY_RECHARGE, DOUBLE_REWARD, TRY_BEFORE_BUY, GOLDEN_BOX); `ads_probe`.
- Faz 7.1: görsel stil laboratuvarı (toon+outline / soft clay / bold flat), `assets/shaders/`, `docs/art/style_lab_sheet.png`.
- Faz 6: Şok Emici Jel modülü, SFX seti (offline sentez) ve olay→ses bağlantıları, ayarlar (ses aç/kapat), ilk açılış rehberi; `polish_probe`.
- `DamageModel` (darbe/çalkalanma/düşme → 0..1 hasar) ve `CargoHealth` (birikim, Şok Jeli koruması, kırık kargo) + 25 birim test.
- Faz 7 görsel paket: stil A (toon + anahat) shader sistemi, model v2 (robot, tekerlek, sepet, 3 kargo, 20 masa/oda modeli), ahşap masa, sıcak oda zemini ve arka plan dekoru, MSAA 2x.
- Faz 7 arayüz: modern/sade UI + tek aile ikon seti (HUD'da ikon + yüzde, menü, sipariş, garaj, sonuç, ayarlar, rehber), `UiMotion` mikro-etkileşimleri, canlı 3B menü vitrini.
- Faz 7 animasyon: robot eğimi/darbe sarsıntısı/göz ifadeleri/tekerlek tozu, sonuç yıldızı + sayaç animasyonu, kupa buharı, bitki/perde sallanması.
- Faz 8: `tools/perf_measure.gd` (gerçek pencerede kare süresi/çizim çağrısı/üçgen), `tools/cargo_preview.tscn` (sipariş küçük resimleri), Android debug export ön ayarı (`export_presets.cfg`, arm64).

- Faz 9 sonsuz level modu: `LevelProgression` (level boyu/zorluk/parça planı), `EndlessReward` (level ödülü, kırılınca kasanın yarısı, zor kargo çarpanı), `RunRecords` (en yüksek level/mesafe/puan), `ZoneCycle` (5 level'da bir çevre bölgesi); `EndlessLevel` + `Segment` (parça dizici, 24 yol parçası), HUD'da level/mesafe/kasa, sonuç ve rekor arayüzü; `endless_probe`, `segment_probe`, `tools/segment_tools.py`.
- Faz 9 bölgeler: Çalışma Masası, Mutfak Tezgâhı, Kitaplık Köşesi, Gece Odası, Pastel Oda (zemin paleti, gökyüzü, sis, ışık; `data/zones.json`).

### Eklendi (Faz 10)
- Yükseltme kademeleri 5 → 8 (Şasi/Tekerlek/Batarya), Şok Jeli 2 kademe; yeni Sigorta (kırılma ödemesi en çok %80) ve Sözleşme (+%25 altın) yükseltmeleri.
- 16 yeni bölge eşyası modeli (`assets/models/v3/zone/`); bölge değişince arka plan eşyaları yumuşakça değişir.
- Düz modern arayüz: çizgi ve gölgeler kalktı, ikincil düğme/çip/kart soluk dolgulu; ikonlar ve düğmeler küçüldü, HUD çubukları koyu yolla her zeminde görünür.
- Minimal arayüz: HUD arka plansız ince çubuklar ve küçük yazı; düğme, kart, ikon ve yazı boyutları küçüldü, gölgeler hafifledi.
- Bölge başına güneş yönü, ortam ışığı, ışıma ve dolgu ışığı (`data/zones.json`).

### Değişti
- Batarya teslimatta level boyuna orantılı dolar (kapasitenin %0.1'i/metre); hız bir ödünleşme olur.
- Sahne ışığı tek bölmeli gölge (`directional_shadow_mode = 0`, 22 m): çizim çağrısı ~376 → ~263, üçgen ~108k → ~75k.

---

## [0.1.0] — 2026-11-11

### Eklendi
- studio-kit şablonundan iskelet: Boot/Menu/Game/Result, autoload dörtlüsü,
  tema + OFL font, `RunScoring` ve birim testleri, `tools/verify.sh`.
