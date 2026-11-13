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
- [ ] **P3** Yüksek kaliteli çamaşır/sepet sprite'ları (Blender render; low-poly yasak)
- [ ] **P4** Engeller (ıslak, çarşaf, gizemli…), güçlendiriciler, ses/titreşim, renk körlüğü desenleri
- [ ] **P5** Ana ekran (çamaşırhane), ekonomi, reklam yerleşimi
