# Changelog

Bu proje [Semantic Versioning](https://semver.org/lang/tr/) kullanır.
Format [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/) temellidir.
Tarihler `YYYY-AA-GG` biçimindedir.

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

[1.0.0]: https://github.com/alperAygor/godot-games/compare/v0.2.0...v1.0.0
[0.2.0]: https://github.com/alperAygor/godot-games/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/alperAygor/godot-games/releases/tag/v0.1.0
