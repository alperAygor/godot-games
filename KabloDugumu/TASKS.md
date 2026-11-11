# TASKS — Cable Knot: Current Master

Durum: **v0.2 "ASMR redesign" — uygulanıyor**. Sıralı plan ve kabul ölçütleri: `ROADMAP.md`.
Her iş "bitti" sayılmadan önce `bash tools/verify.sh` yeşil olmalı.

## v0.2 — TAMAMLANDI (doğrulama: 160 test, perf hedefi aşıldı)

### Lead
- [x] İngilizce kimlik (project.godot: Cable Knot: Current Master)
- [x] `Loc` autoload + `data/i18n/{en,tr}.json` + settings.cfg kalıcılığı
- [x] Manrope (OFL) fontu + lisans
- [x] ARCHITECTURE §10–§16 (i18n, ayarlar, modifier, backdrop, perf, tasarım token'ı, ASMR)
- [ ] `tools/perf_probe.gd` + i18n parite testi + entegrasyon
- [ ] README/PROJECT_SPEC İngilizce kimliğe güncelleme
- [ ] Final verify + ekran görüntüsü montajı + commit

### craft-ui (task-6)
- [ ] Tasarım dili: palet + metrik + Manrope (theme.json → build_theme.py)
- [ ] Boot/Menu/LevelSelect/HUD/Fail/Pause/Result yeniden tasarım (küçük buton, ikon, sade)
- [ ] Menu animasyonlu arka plan (AmbientBackdrop SubViewport) + dil değiştirici + ayarlar
- [ ] Tüm UI metinleri Loc.t anahtarlarında; TR/EN parite

### live-world (task-7)
- [ ] ASMR ışık/palet/partikül atmosferi + yumuşak feedback
- [ ] `AmbientBackdrop` (menü + oyun arka planı): fan, lamba, konveyör, buhar
- [ ] Performans: halat mesh yeniden inşası olay-tabanlı; kare bütçesi; perf raporu
- [ ] Drag sırasında p95 kare süresi ölçümü (hedef < 16.7 ms M4 / 33 ms düşük segment)

### level-forge (task-8)
- [ ] KnotLevel düğüm görünümü (fişler kaynaktan uzak) + zorluk eğrisi
- [ ] Modifier data altyapısı + sway / locked_socket / blackout / fast_overload
- [ ] L5+ kademeli mekanik girişi, L12 final; testler + verify yeşil

### audio-mood (task-9)
- [x] ASMR SFX seti (yumuşak crackle, ahşap clack, sürtünme, chime) + ambient hum/pad
- [x] AudioService loop/ambient API + mix + mute kalıcılığı
- [x] data/sfx_recipes.json + sounds.json + üretim (deterministik sentez)

## Tamamlanan (v0.1)
- [x] studio-kit şablonundan proje; core mantık + 12 bölüm + 86 core testi
- [x] PBD halat fiziği + tüp mesh; fiş/priz/temas/kıvılcım; 137 test yeşil
- [x] 3D pano, HUD, menü, bölüm seçimi, sonuç; 3 reklam yerleşimi; 13 SFX
- [x] verify.sh 4 adım (import + smoke + test + oyun dumanı); imleç/girdi düzeltmesi
- [x] İlk oynanabilir sürüm commit'i (`6908c08`)

## Bilinen riskler
- Manrope variable font: başlık ağırlığı FontVariation ile verilmezse ince kalır.
- Ambient backdrop ikinci viewport maliyeti; düşük segmentte 30 fps tabanı korunmalı.
- Modifier'lar mevcut 130 testi kırmamalı; önce saf core, sonra görsel katman.
- Eşzamanlı yazım: HUD.tscn ve game.gd tek sahipte kalmalı.
