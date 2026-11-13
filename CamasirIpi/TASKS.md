# TASKS — Çamaşır İpi

| Faz | Konu | Durum |
|---|---|---|
| 0 | İskelet (Boot/Menu/Game/Result, autoload'lar, tema, testler) | ✅ |
| 1 | Oyun mekaniği | ⬜ |

## Faz 0 — İskelet ✅

- [x] `project.godot` — portre, `gl_compatibility`, statik tip hataları açık
- [x] Autoload dörtlüsü: `GameManager`, `AudioService`, `AdManager`, `GameData`
- [x] Sahneler: Boot → Menu → Game → Result
- [x] Tema + OFL font (Baloo 2)
- [x] `RunScoring` + birim testleri
- [x] `tools/verify.sh`

---

## Faz 1 — Oyun mekaniği

**Hedef:** (buraya yaz)

- [ ] ...
- [ ] ...

**Bitti kriteri:** ...

## Çamaşır İpi — prototip
- [x] **P1** Çekirdek kurallar (`LaundryBoard`), seviye üretici (`LevelGenerator`), çözücü (`LevelSolver`) + birim testleri
- [x] **P2** Oynanabilir oyun ekranı (ipler, askı, sepetler, kuyruk, kazanma/kaybetme, +1 askı) + `tools/play_probe.gd`
- [x] **P3** Yüksek kaliteli çamaşır/sepet/mandal sprite'ları (`tools/blender/make_sprites.py` + `tools/post_sprites.py`)
- [x] **P4a** Engeller: ıslak (sv 8), gizemli (sv 14), kilitli mandal (sv 20); ASMR ses seti; bahçe arka planı; havada katlanma, sepet yığını, parıltı
- [ ] **P4b** Çarşaf, çorap çifti, boya akıtan; güçlendiriciler; renk körlüğü desenleri
- [ ] **P5** Ana ekran (çamaşırhane), ekonomi, reklam yerleşimi
- [x] **P6** Premium geçiş (2.5D): Blender render bahçe katmanları + askı, yeniden yapılan çamaşır/sepet/mandal modelleri (Cycles), yavaş ve yumuşak animasyonlar (`Motion`, kumaş sallanma shader'ı), ElevenLabs ses seti (`tools/make_el_sfx.py`)
