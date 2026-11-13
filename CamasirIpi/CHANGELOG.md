# Changelog

Format [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/), sürümleme [SemVer](https://semver.org/lang/tr/).

## [Unreleased]

### Yerelleştirme (orch/ci-i18n) — Türkçe / İngilizce / İspanyolca
- Tek kaynak tablo `data/i18n/strings.csv` (`keys,tr,en,es`; Godot CSV içe aktarımı -> `.translation`,
  `project.godot` `locale/translations`, `locale/fallback="tr"`). Anahtarlar sabit UPPER_SNAKE.
- `Loc` (scripts/core/loc.gd): `t/f/n` (çoğul duyarlı), cihaz dilinden otomatik seçim (tr/en/es, diğer -> en),
  kayıt `Progress` `settings.language`; `Boot` ilk ekrandan önce uygular.
- `UiStrings/TutorialStrings/DailyStrings/MetaStrings` anahtar sarmalayıcıları oldu; serbest metinler tabloya taşındı.
- Ayarlar sayfasında TR/EN/ES hap düğmeleri (`UiLanguageRow`); dil değişince sahne baştan kurulur.
- Araçlar `--lang=tr|en|es` alır; `tests/unit/test_loc.gd` tablo/yer tutucu/kullanılmayan anahtar denetimi yapar.

### Eklenecek
- Oyun mekaniği

### Başarım (orch/ci-perf) — ölçümler `docs/perf/baseline.md` / `docs/perf/after.md`
- `LevelPrefetch` (scripts/core): seviye üretimi WorkerThreadPool'da; sonraki seviye oynarken
  üretilir, Boot/ana ekran oyuncunun seviyesini önceden ister, günlük bulmaca kart açıkken kurulur.
  Sonuç eşzamanlı üretimle birebir aynı (`test_level_prefetch.gd`). "Devam" karesi 1017 ms -> ~25 ms.
- Doku belleği: büyük bahçe katmanları + 47 çamaşırhane katmanı VRAM sıkıştırmalı (mobil ASTC 4x4,
  masaüstü BPTC); çamaşırhane katmanları 4'ün katına dolduruldu (yeniden ölçeklemesin, bulanmasın;
  `make_meta.py` de öyle kırpar); 6 çamaşır dokusu 384 px içe aktarılır (havlu/çarşaf 768 kalır).
- Çamaşırhane isabet testi tam RGBA kopya yerine 1 bit maske (`BitMap`) tutar.
- Ana ekran, opak meta ekranı (çamaşırhane/koleksiyon) açıkken kendi katmanlarını gizler/durdurur.
- `game.gd`: `_draw` artık her kare değil tahta değişince; gökyüzü gradyanı yalnız görünür değişimde
  yeniden üretilir. Bahçe/gökyüzü: durağan tonlar yalnız görünüm değişince yazılır.
- Bahçe dokuları uygulama boyunca bir kez yüklenir (Boot beklemesinde iş parçacığında başlar).
- Çıkış sızıntıları giderildi (ses akışları, eco_probe sahte düğmeleri, yarım doku yüklemeleri);
  sıkma parçacıkları bitince silinir; hızlı oyunda silinmiş görünüme olay gelmesi (`_live`) düzeltildi.
- `physics_ticks_per_second` 60 -> 30 (fizik kullanılmıyor). Yeni araç: `tools/perf_probe.gd`.

---

## [0.1.0] — 2026-11-13

### Eklendi
- studio-kit şablonundan iskelet: Boot/Menu/Game/Result, autoload dörtlüsü,
  tema + OFL font, `RunScoring` ve birim testleri, `tools/verify.sh`.
