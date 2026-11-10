# Changelog

Bu proje [Semantic Versioning](https://semver.org/lang/tr/) kullanır.
Format [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/) temellidir.
Tarihler `YYYY-AA-GG` biçimindedir.

---

## [1.2.0] — 2026-11-10

**Faz 2 — oyun kabuğu.** Uygulama artık doğrudan oyuna açılmıyor:
**boot → menü → oyun → sonuç → menü** döngüsü kapandı.

### Eklendi
- **`scenes/Boot.tscn`** — 0.4 sn bekleme (flash önlemi), menüye geçiş.
- **`scenes/Menu.tscn`** — Oyna; sürüm etiketi `project.godot`'dan okunur (elle güncellenmez).
- **`scenes/Result.tscn`** — yıldız, toplam hasar, ücret ve **paket bazında hasar raporu**
  (`Buz — %100 hasar`, `Demir — %0 hasar`), "Tekrar Oyna" + "Ana Menü".
- **`scripts/core/run_scoring.gd`** — hasar → yıldız/ücret/itibar (`PROJECT_SPEC.md` §2 tablosu),
  saf `RefCounted`, **7 birim test**.
- **`data/balance.json`** — `delivery_base_fee`.
- **`assets/theme/ui_theme.tres`** + **Baloo 2 (OFL)** + `tools/build_theme.py`:
  tema artık palette'ten üretilir (`data/theme.json`), elle yazılmaz.
- **`tools/flow_shot.gd`** — boot→menü→oyun→sonuç akışını sürüp dört ekranı kaydeden kabul aracı.

### Değişti
- **`GameManager`**: `SCENES` kaydı, `goto_scene()` (tek geçiş noktası), `finish_run()`,
  `last_result`, `back_requested` sinyali; `Phase`'e `BOOT`/`MENU` eklendi
  (mevcut sayısal değerler korundu — testler ve araçlar `FAILED = 2` varsayımını kullanıyor).
- **`Main.gd`**: başarılı tur → `GameManager.finish_run(_build_result(true))` → sonuç ekranı;
  geri tuşu → menü; "Baştan Dene" → `goto_scene(&"game")`; `_build_result()` paket bazlı hasarı toplar.
- Ana sahne `res://scenes/Boot.tscn`.
- Tüm arayüz Baloo 2 ile çiziliyor (önce varsayılan font).
- Sürüm `1.2.0`.

### Doğrulama
- `tools/verify.sh` → **34 test / 96 doğrulama**, 0 başarısız.
- `tools/flow_shot.gd` → boot, menü, oyun (sarsıntı ortası), sonuç ekranları gerçek pencerede
  render edilip görsel kontrol yapıldı.

---

## [1.1.0] — 2026-11-10

**Faz 1 — sağlamlaştırma.** Kullanıcıya görünen değişiklik yok; proje artık
regresyona karşı korumalı ve denge sayıları veride.

### Eklendi
- **`tests/test_case.gd`** — assert tabanı, runner'ın doldurduğu `tree` ve autoload erişimi.
- **`tests/run_tests.gd`** — test koşucusu: `--filter=`, çıkış kodu 0/1/2, bozuk script atlanır,
  beklenmedik hatada süreç kilitlenmez (`_process` içinde çalışır, `_initialize` askıda kalmaz).
- **27 test / 78 doğrulama**, dört dosyada:
  `test_package_physics` (9), `test_grid` (7), `test_shake` (6), `test_ad_limits` (6).
- **`tools/verify.sh`** — içe aktarma + açılış dumanı + testler; Godot hata verse de 0
  dönebildiği için çıktı `SCRIPT ERROR` için ayrıca taranır. Loglar `tests/results/` (git dışı).
- **`scripts/autoload/GameData.gd`** — `res://data/*.json` tablolarını yükler.
- **`data/packages.json`** — cam/buz/demir/yay/standart için `break_threshold`, `fragility`, `melt_seconds`.

### Değişti
- `PackagePhysics` denge değerlerini artık `data/packages.json`'dan okur (`use_data_tuning`
  kapatılabilir). `Main.tscn`'deki gömülü eşikler kaldırıldı.
- `GridController._nudge()` ve `AudioService` pitch varyasyonu **sabit tohumlu**
  `RandomNumberGenerator` kullanıyor (CLAUDE.md §5).
- `AdManager.reset_session_limits()` eklendi (testler ve "yeni oyun" için).
- Sürüm `1.1.0`.

### Düzeltildi
- **`melt_seconds` belgesiyle kod çelişiyordu:** alan "tam erime süresi" diyordu ama formül
  0.5 taban yüzünden iki katını veriyordu. Formül artık `(1.0 + intensity * 1.5) / melt_seconds`;
  sarsıntı erimeyi en fazla 2.5 kat hızlandırıyor.

### Doğrulama
`tools/verify.sh` → `SONUÇ: geçti` (27 test, 0 başarısız); açılış dumanı temiz; hata ekranı
görsel olarak yeniden kontrol edildi (davranış değişmedi).

---

## [1.0.0] — 2026-11-10

**Dikey dilim tamamlandı.** Oyun baştan sona oynanabilir: paketle → sarsıntılı
teslimat → kırılma/erime → ödüllü kurtarma. Sürüş fazı ve mağaza yayını kapsam dışı.

### Eklendi — Fizik ve sarsıntı
- **`ShakeSimulator.gd`** — "Teslimata Başla" ile **5 saniyelik** sinüs tabanlı sarsıntı.
  Zarf eğrisi (rampa-in → tümsek ritmi → rampa-out), dönme bileşeni ve kaldığı yerden
  devam edebilen `stop()`/`resume()`. Sarsıntı tek bir `ShakeRoot`'a biner; çanta ve
  paketler birlikte sallanır, paketlerin kendi tween'leri bozulmaz.
- **`PackagePhysics.gd`** — şiddete göre biriken stres modeli.
  - **Cam kutusu**: eşik aşılırsa kırılır → `GameManager.fail_run()` **oyunu duraklatır** ve
    hata ekranını açar. Kırılma animasyonu duraklatılmış sahnede de oynar.
  - **Buz paketi**: sarsıntıyla erir, küçülür; tamamen eridiğinde komşularına stres yükler
    ve onları sarsar (komşu camı çatlatabilir).
  - Yalnızca çantaya yerleştirilmiş paketler etkilenir; tepsidekiler sürüşe katılmaz.

### Eklendi — ElevenLabs ses
- **`tools/make_sfx.py`** — ElevenLabs Sound Generation API ile üretim; anahtar yoksa
  deterministik yedek sentez. Tepe normalizasyonu (clipping yok), 44.1 kHz mono 16-bit.
- **`assets/audio/sfx/`**: `package_drop.wav` (0,60 sn), `glass_break.wav` (1,36 sn),
  `ice_clink.wav` (0,80 sn), `success.wav` (2,00 sn) — dördü de API'den üretildi,
  dalga analiziyle doğrulandı (sessiz değil, süreler doğru).
- **`AudioService.gd`** — 8 kanallı SFX havuzu, pitch varyasyonu, `Master/SFX/Music`
  bus düzeni, headless koruması. Sahne kodundan çağrı: `play_drop()`, `play_glass_break()`,
  `play_ice_clink()`, `play_success()`.
- Anahtar yalnızca `.env`/ortam değişkeninden okunur; **repoya hiçbir zaman yazılmadı**.

### Eklendi — Ödüllü reklam kancaları
- **`AdManager.gd`** — `Placement` enum'u, `data/ads.json` limitleri, tek uçuş koruması,
  idempotent ödül. Ödül yalnızca `rewarded_finished` sonrası verilir.
- **`AdsProvider`** arayüzü + `MockAdsProvider` (1,2 sn simülasyon, %8 başarısızlık) +
  `NoAdsProvider`. Reklam yüklenemezse oyun sessizce devam eder.
- **"Ekstra Cep Aç"** — ızgarayı **4x5 → 5x5** yapar. Ek sütun çantanın sağına takılan
  yarı saydam bir ceptir ve **gerçekten kullanılabilir** (paket yerleştirme testiyle doğrulandı).
- **"Paketi Bandıyla Kurtar"** — kırılan ilk paketi onarır, teslimatı kaldığı yerden sürdürür.

### Eklendi — HUD
- **`scenes/HUD.tscn`** + **`HUD.gd`** — başlık, durum satırı, sarsıntı barı, üç buton
  (Ekstra Cep / Teslimata Başla / Bandıyla Kurtar), hata katmanı ve reklam katmanı.
- Butonlar hem pasif hem aktif durumda okunur; duraklatılmış sahnede çalışır.
- **`Main.gd`** — sahne kablolaması; karar mantığı autoload'larda kalır.

### Değişti
- `GridController` yeniden yazıldı: sabit 4x5 yerine **genişleyebilir** ızgara
  (sol kenar sabit, ek sütunlar sağa büyür), doluluk artık hücre→paket sözlüğü,
  paket olayları (kırılma/erime/onarım) bağlandı.
- `Main.tscn` yeniden kuruldu: `ShakeRoot` altında çanta + paketler, `ShakeSimulator`,
  `HUD`, renk düzeltme katmanı.
- Sürüm `1.0.0`.

### Düzeltildi
- Cam kırılınca oyun yalnızca sarsıntı sonunda değil, **kırılma anında** duraklıyor.
- Tepsideki paketler de sarsıntı hasarı alıyordu; bu yüzden "başarı" yolu ulaşılamazdı —
  artık yalnızca çantadaki paketler etkileniyor.
- Ekstra cep kutusu hücre parıltılarını kapatıyordu; kutu parıltı düzleminin gerisine alındı.
- Pasif butonların yazıları okunmuyordu; ayrı pasif stil ve yazı rengi tanımlandı.

### Doğrulama
- `--import` ve `--quit` hatasız (0 çıkış, statik tip hataları açıkken).
- Sekiz senaryo gerçek pencerede render edilerek görsel kontrol: idle, placed, shake,
  fail, revive, success, pocket, pocket_place.
- Ses dosyaları dalga analizi (süre, tepe, RMS) ile doğrulandı.

### Kapsam dışı (yapılmadı)
Sürüş fazı (kamyonet/yol), `RigidBody3D` tabanlı gerçek simülasyon, ekonomi/yükseltme/kayıt,
birim testleri, IAP, gerçek AdMob eklentisi, Play Store yayını, müzik. Ayrıntı: `TASKS.md`.

---

## [0.2.0] — 2026-11-10

### Eklendi — sahne kurulumu ve stylized atmosfer
- **`project.godot`** — Android portrait 1080x1920, `gl_compatibility`, dokunmatik emülasyonu.
- **`scenes/Main.tscn`**, **`scenes/BackpackGrid.tscn`**.
- **`GridController.gd`** — sürükle-bırak, squash & stretch, hücre parıltısı.
- **`color_correction.gdshader`** — sıcak renk düzeltme (lift/gain, doygunluk, vinyet).
- **Bloom** ve **SSAO** `gl_compatibility`'de A/B render + determinizm kontrolüyle doğrulandı.

### Bulgular
- Environment'ın `adjustment_color_correction` LUT'u `gl_compatibility`'de bozuk sonuç veriyor
  (kimlik LUT bile sahneyi kırmızıya boyadı) → renk düzeltme tam ekran shader ile yapıldı.

---

## [0.1.0] — 2026-11-10

İlk sürüm: proje iskeleti ve dokümantasyon.

### Eklendi
- Dizin yapısı, `CLAUDE.md`, `PROJECT_SPEC.md`, `ARCHITECTURE.md`, `TASKS.md`, `.gitignore`.
- **3D varlık hattı** (`tools/blender/make_models.py` ile prosedürel):
  `backpack_base.glb` (1.412 tris, 4x5 = 20 cep), `pkg_glass_1x2.glb` (308),
  `pkg_ice_1x1.glb` (176), `pkg_iron_2x2.glb` (452), `pkg_spring_1x1.glb` (316).
  Toplam **2.664 üçgen / 13 yüzey**; hepsinde transformlar uygulanmış, origin alt-merkez.

[1.1.0]: https://github.com/alperAygor/godot-games/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/alperAygor/godot-games/compare/v0.2.0...v1.0.0
[0.2.0]: https://github.com/alperAygor/godot-games/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/alperAygor/godot-games/releases/tag/v0.1.0
