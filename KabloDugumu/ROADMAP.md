# ROADMAP — Cable Knot: Current Master (v0.2 "ASMR redesign")

Kullanıcı geri bildirimi (2026-11-11): UI doğal değil/dağınık, butonlar gereksiz büyük;
oyun biraz kasıyor; bölümler aşamalı zorlaşmalı ve yeni mekanikler gelmeli; oyun **ASMR /
rahatlatıcı** hissettirmeli; sesler güncellenmeli; çoklu dil desteği; ana menüde **İngilizce**
oyun adı ve **animasyonlu arka plan**; oyun içinde de arka planda canlı çevre animasyonları.

Sıra: **önce altyapı (i18n + tasarım dili + perf ölçümü)**, sonra UI, sonra atmosfer,
sonra zorluk/mekanikler, en son doğrulama. Aynı anda en fazla 4 yazıcı; dosya sahipliği
ARCHITECTURE.md §2'de.

---

## Faz 0 — Plan ve sözleşme (Lead) ✅

- [x] Yeni hedeflerin sözleşmeye işlenmesi: i18n, ayarlar, perf bütçesi, modifier'lar,
      ambient backdrop, UI tasarım token'ları, ASMR kuralları (ARCHITECTURE §10–§16).
- [x] `Loc` autoload + `data/i18n/{en,tr}.json` + `user://settings.cfg` kalıcılığı.
- [x] İngilizce kimlik: `project.godot` adı **Cable Knot: Current Master**, açıklama, sürüm 0.2.0.
- [x] Manrope (OFL) fontu projeye eklendi (`assets/fonts/Manrope.ttf`).
- [x] Ölçüm: mevcut durum 7 kablo/12. bölümde ortalama ~500 fps (M4), min 21.7 (hitch);
      takılma hissi için kare süresi kuyruğu (p95/p99) ölçülecek, drag sırasında ölçüm şart.

## Faz 1 — Altyapı (paralel)

- [x] **craft-ui**: yeni tasarım dili (theme.json palet+metrik, Manrope, ikon-öncelikli,
      buton yüksekliği 88–100 tasarım px, 8 px grid) + `build_theme.py` çıktısı.
- [x] **craft-ui**: tüm UI metinlerini `Loc.t(...)` anahtarlarına taşı (TR/EN parite).
- [x] **live-world**: `tools/perf_probe.gd` ile drag sırasında FPS/p95 ölçümü; baseline.
- [x] **audio-mood**: `AudioService`'e loop/ambient API + mix; ses üretim tarifleri ASMR'a göre.

## Faz 2 — UI/UX yeniden tasarımı (craft-ui)

- [x] **Boot**: sade splash (logo + sürüm), 0.6 sn.
- [x] **Menu**: İngilizce başlık (`game.title`/`game.subtitle`), animasyonlu 3D arka plan
      (`AmbientBackdrop` SubViewport), küçük ikonlu butonlar (Oyna/Bölümler/Ayarlar),
      üst köşede dil değiştirici (TR/EN), yıldız sayacı, sürüm etiketi.
- [x] **LevelSelect**: sade 3x4 kart; kilit ikonu, yıldızlar, ilerleme satırı; geri.
- [x] **HUD**: sade üst bar (bölüm adı, süre, bağlı, pause), panoyu örtmeyen küçük
      aşırı yük barı + voltaj okuması, alt bilgi pill'i, küçük ikonlu reklam butonları.
- [x] **Fail/Pause/Result**: sade kartlar, ikon, küçük butonlar, i18n.
- [x] **Ayarlar**: dil, ses, ilerleme sıfırla, krediler (tek panel).

## Faz 3 — ASMR atmosfer (live-world + audio-mood)

- [x] **live-world**: sıcak-koyu palet, yumuşak glow, panoda nefes alan ışıklar, toz
      partikülleri, yavaş tarama parlaması; sert kırmızı flash/shake'i yumuşat.
- [x] **live-world**: `scenes/AmbientBackdrop.tscn` — panonun arkasında atölye: dönen
      fan, salınan asma lamba, yavaş konveyör/bobin, buhar; menüde de kullanılır.
- [x] **live-world + volt-rope perf**: halat mesh yeniden inşası olay-tabanlı (hareket
      yoksa yeniden kurma), alt örnekleme bütçesi; kare süresi p95 < 16.7 ms (M4'te %1 cihaz
      değil, orta segment hedefi: düşük segmentte 30 fps taban).
- [x] **audio-mood**: yumuşak SFX (crackle yumuşak, clack ahşap, sürtünme, chime),
      ambient hum + pad loop, reklam/bölüm geçişleri yumuşak; ses seviyeleri mix.
- [x] **craft-ui**: geçişlerde yumuşak easing; kısa devrede agresif kırmızı yerine sıcak
      amber vinyet; kutlama sakin.

## Faz 4 — Aşamalı zorluk + yeni mekanikler (level-forge)

- [x] **KnotLevel**: fiş dinlenme konumları kaynaktan uzak (gerçek düğüm görünümü);
      zorluk eğrisi; determinizm ve mevcut garantiler korunur.
- [x] **Modifier altyapısı**: `data/levels.json -> modifiers` (sway, locked_socket,
      blackout, fast_overload); KnotLevel taşır; gameplay okur.
- [x] **sway** (L5+): panoda yavaşça salınan "canlı hatlar"; temas kısa devre sayılır.
- [x] **locked_socket** (L7+): kapağı açmak için fiş priz yanında 0.6 sn tutulur.
- [x] **blackout** (L9+): pano ışıkları yumuşakça söner/yanar (görsel zorluk).
- [x] **fast_overload** (L10+): bar `overload.fill_per_second * 1.5` ile dolar.
- [x] **Bölüm eğrisi**: par süreleri sıkılaşır, kablo 3→7, L12 tüm modifier'lar.
- [x] **Testler**: 12 bölüm garantileri + modifier davranış testleri + i18n parite testi.

## Faz 5 — Doğrulama ve teslim (Lead + QA)

- [x] `bash tools/verify.sh` yeşil; `python3 tools/build_theme.py --check` yeşil.
- [x] i18n anahtar parite testi (en/tr aynı anahtar kümesi) verify'da.
- [x] Perf raporu: menü, oyun, drag; p95 kare süresi hedefi.
- [x] Ekran görüntüsü seti: menü (animasyonlu), bölüm seçimi, oyun (TR+EN), drag, kıvılcım,
      fail, result; montaj.
- [x] README/TASKS/CHANGELOG/PROJECT_SPEC güncel; commit.

## Riskler

- Manrope değişken font (variable): Godot 4.7'de import edilir; başlık için `FontVariation`
  (`wght` 800) kullanılmazsa ince görünür. Font yüklenmezse Baloo2'ye düşülür.
- Ambient backdrop 3D ikinci görüntüleme = ek maliyet; SubViewport 540x960, 3-5 düğüm,
  gölge yok, 30 fps güncelleme ile sınırlanır.
- Modifier'lar mevcut testleri kırmasın: önce data + core (saf), sonra görsel katman.
- Eş zamanlı yazarlar: game.gd ve HUD.tscn tek sahipte; diğerleri arayüz üzerinden bağlanır.
