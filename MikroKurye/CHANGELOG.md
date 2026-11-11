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
- `DamageModel` (darbe/çalkalanma/düşme → 0..1 hasar) ve `CargoHealth` (birikim, Şok Jeli koruması, kırık kargo) + 25 birim test.

### Eklenecek
- Oyun mekaniği (Faz 1 kalanı, Faz 2 fizik prototipi)

---

## [0.1.0] — 2026-11-11

### Eklendi
- studio-kit şablonundan iskelet: Boot/Menu/Game/Result, autoload dörtlüsü,
  tema + OFL font, `RunScoring` ve birim testleri, `tools/verify.sh`.
