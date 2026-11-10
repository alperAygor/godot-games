# TASKS — Kablo Düğümü: Akım Ustası

Durum: **v0.1 — oynanabilir dikey dilim**. Her iş "bitti" sayılmadan önce
`bash tools/verify.sh` yeşil olmalı (import + duman + birim testleri + oyun probe'u).

## Faz 0 — Sözleşme (Lead) ✅
- [x] studio-kit şablonundan `godot-games/KabloDugumu` üretimi
- [x] `CLAUDE.md`, `PROJECT_SPEC.md`, `ARCHITECTURE.md`
- [x] `data/levels.json`, `data/balance.json`, tema
- [x] Core + GameManager + HUD iskelet sözleşmesi (derlenir, verify yeşil)

## Faz 1 — Paralel modüller ✅
- [x] **forge-core**: `KnotLevel` üretimi (12 seviye, garantiler), `OverloadModel`, `SnapRule`,
      `LevelScoring`, `PlayerProfile`, `CableMath` + birim testleri
- [x] **volt-rope**: verlet halat + tüp mesh, fiş/priz görseli, temas tarayıcı, kıvılcım partikülü
- [x] **panel-ui**: tema, Boot/Menu/LevelSelect/Result/HUD sahneleri ve script'leri
- [x] **signal-qa**: 13 SFX üretimi + AdManager yerleşimleri + reklam limitleri + testler
      (`tools/make_sfx.py`, `data/sfx_recipes.json`, `data/sounds.json`,
      `scripts/autoload/AudioService.gd`, `scripts/autoload/AdManager.gd`,
      `scripts/services/*`, `tests/unit/test_ad_limits.gd`)

## Faz 2 — Dünya ✅
- [x] **panel-world**: pano/environment/kamera/voltmetre, `Game.tscn`, `game.gd` orkestrasyon
- [x] core + rope + UI + HUD entegrasyonu (temas → bar → fail/win → Result)
- [x] Gerçek dokunma/sürükleme yolu (unproject + sürükleme düzlemi + snap) ve
      adalet kuralı (dinlenen temaslar sayılmaz)

## Faz 3 — Cila ✅
- [x] Bölüm dengesi (par süreleri, kablo uzunluğu, bar hızları) — oynayarak ölç
- [x] Ekran görüntüsü akışı + montaj: `tools/flow_shot.gd` + `tools/make_shots.sh`
      (`/tmp/kablo_shots/`, `/tmp/kablo_sheet.png`)
- [x] Reklam kancaları uçtan uca (mock) — üç yerleşim: FUSE_RESCUE, GOLDEN_CUTTER,
      INSULATION_SPRAY (limitler `data/ads.json`, ödül yalnız `rewarded_finished` sonrası)
- [x] Headless oyun dumanı: `tools/game_probe.gd` — idle adalet + force_snap → win
- [x] CHANGELOG, final `verify.sh` (4 adım) + tema `--check`

## Doğrulama komutları
```bash
bash tools/verify.sh                    # import + duman + testler + game_probe
python3 tools/build_theme.py --check    # tema senkron mu
godot --path . -s res://tools/flow_shot.gd -- --out-dir=/tmp/kablo_shots  # gerçek pencere
bash tools/make_shots.sh                # flow_shot + /tmp/kablo_sheet.png montajı
```

## Bilinen riskler
- Verlet tüp mesh'i mobilde pahalı → 6 kenar, 16 nokta, güncelleme seyreltme.
- `-s` script'lerinde autoload kimliği derlenmez (GOTCHAS #2) → `get_node` kullan.
- `.tscn` elle düzenlemek kırılgan → sahneleri GDScript ile kur, mümkünse.
- macOS'ta pencere arkada kalınca çizim durabiliyor → flow_shot `always_on_top` +
  `RenderingServer.force_draw` ile kareleri tazeliyor.
- ElevenLabs anahtarı repoda yok → sesler deterministik sentez ile üretiliyor;
  anahtar eklenirse aynı komut gerçek üretimi kullanır.

## Tamamlananlar
- 2026-11-10: iskelet üretimi, verify yeşil — Lead
- 2026-11-10: core + rope + UI + pano entegrasyonu; gerçek drag → snap, kısa devre,
  kalkan, fail/retry/win — panel-world / panel-ui / volt-rope / forge-core
- 2026-11-10: 13 SFX + üç reklam yerleşimi + limit testleri; headless oyun probe'u;
  akış ekran görüntüleri + montaj; final verify 137 test / 2590 doğrulama yeşil — signal-qa
