# CHANGELOG — Kablo Düğümü: Akım Ustası

Tüm önemli değişiklikler bu dosyada. Sürümleme: SemVer.

## [0.1.0] — 2026-11-10

### Eklendi
- studio-kit şablonundan proje iskeleti (`godot-games/KabloDugumu`).
- Oyun tasarım belgesi (`PROJECT_SPEC.md`) ve mikro-mimari sözleşmesi (`ARCHITECTURE.md`).
- Core sözleşme sınıfları (CableSpec, SocketSpec, KnotLevel, OverloadModel, SnapRule,
  LevelScoring, PlayerProfile, CableMath) ve GameManager akışı.
- 12 seviyelik veri tablosu, denge tablosu, koyu-neon tema.
- 3D pano dünyası (`Game.tscn`): board/socket/fiş görselleri, verlet halat fiziği,
  temas tarayıcı, kıvılcım partikülü, kamera hareketi, aşırı yük barı, voltmetre.
- Tüm 2D akış: Boot, Menu, LevelSelect (12 bölüm, kilit/yıldız), HUD (bar, süre,
  reklam butonları, fail/pause/ad overlay), Result (yıldız animasyonu, en iyi süre).
- Ses: `tools/make_sfx.py` deterministik sentez ile 13 efekt üretir
  (`ui_tap, cable_pull, spark, clack, wrong_socket, fuse_pop, level_start, shield_on,
  cutter, success, win, fail, hum`); adlar `data/sfx_recipes.json`, tablo `data/sounds.json`.
- Reklam: `AdManager` üç ödüllü yerleşim (FUSE_RESCUE, GOLDEN_CUTTER, INSULATION_SPRAY),
  `data/ads.json` tur/oturum limitleri, idempotent ödül, pending koruması,
  varsayılan `MockAdsProvider` (1.2 sn, %8 başarısız) ve `NoAdsProvider`.
- QA araçları: `tools/game_probe.gd` (headless oyun dumanı + idle adalet regresyonu;
  `verify.sh` 4. adım), `tools/flow_shot.gd` (gerçek pencerede boot→…→result akışı,
  gerçek dokunma/sürükleme enjeksiyonu, fail/win kareleri), `tools/make_shots.sh`
  (`/tmp/kablo_sheet.png` kontak sayfası).
- Birim testleri: reklam limitleri/pending/idempotens, core, halat, UI akışları.

### Değişti
- `AudioService`: `set_muted` + `muted`, 8'li havuz, headless sessiz, eksik ses için
  tek uyarı; `play/has_sound` sözleşmesi korundu.
- `AdManager`: yerleşim enum'u oyunun üç reklam kancasına geçti; limitler JSON'dan
  varsayılanların üzerine bindiriliyor; `has_pending()` ve `used_in_session()` QA için.

### Düzeltildi
- `LevelController` (`RefCounted`) içinde `get_tree()` çağrısı → gerçek dokunmada
  `_plane_point` çöküyordu; `CameraRig.get_viewport().get_camera_3d()` kullanılıyor.
- Dinlenen iki kablonun teması kısa devre sayılıyordu → `ContactMonitor` adalet kuralı +
  1.1 sn warm-up (dinlenen çiftler kıvılcım/bar üretmez).
- `Voltmeter` iğne/hub düğümleri iki kez ebeveyne ekleniyordu.
- macOS'ta arkada kalan pencerede ekran görüntüleri donuyordu → flow_shot
  `always_on_top` + `RenderingServer.force_draw`.

### Doğrulama
- `bash tools/verify.sh`: import (2 geçiş) + açılış dumanı + 137 test / 2590 doğrulama
  (0 başarısız) + headless oyun probe'u (idle adalet + force_snap → win) → **geçti**.
- `python3 tools/build_theme.py --check`: tema güncel.
- `bash tools/make_shots.sh`: 11 karelik akış montajı (`/tmp/kablo_sheet.png`):
  boot, menu, levelselect, game, kıvılcım, gerçek drag-snap, drag-temas, kalkan,
  fail, win, result.
