# Changelog

Bu proje [Semantic Versioning](https://semver.org/lang/tr/) kullanır.
Format [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/) temellidir.
Tarihler `YYYY-AA-GG` biçimindedir.

---

## [Unreleased]

### Eklendi
- **3D varlık hattı** — `tools/blender/make_models.py`: beş modeli prosedürel üreten Blender 5.2 betiği. Girinti/örgü yerine kod; model değişikliği = script değişikliği.
- **`assets/models/backpack_base.glb`** — ön yüzü açık kurye çantası, 4×5 = 20 cep ızgarası, pastel palet (nane/krem/pudra/lavanta). 1.412 üçgen, 4 materyal, 0,346 × 0,470 × 0,138 m.
- **`assets/models/pkg_glass_1x2.glb`** — 1×2 yarı saydam mavi cam kargo kutusu, köşe dikmeleri ve kapak. 308 üçgen, `alphaMode = BLEND` (alfa 0,42).
- **`assets/models/pkg_ice_1x1.glb`** — 1×1 açık camgöbeği buz paketi, kristal kesimli gövde + üstte buz dikenleri. 176 üçgen.
- **`assets/models/pkg_iron_2x2.glb`** — 2×2 ağır demir kasa, köşe dikmeleri, çift bant ve 8 perçin. 452 üçgen, metalik 0,85.
- **`assets/models/pkg_spring_1x1.glb`** — 1×1 darbe emici kutu, açık üstlü tekne + 3 sarım helezon yay. 316 üçgen.
- **`assets/models/README.md`** — varlık sözleşmesi: ızgara birimi, boyutlar, üçgen bütçeleri, palet ve Godot kullanım notları.

### Doğrulama
- Beş dosya da `minY = 0`, `centerX = centerZ = 0`, node'da TRS yok (transformlar uygulanmış).
- Godot 4.7.2 `gl_compatibility` projesinde içe aktarma hatasız; toplam **2.664 üçgen / 13 yüzey**.
- Görsel kontrol: EEVEE ile üç açıdan render edilip incelendi.

### Eklenecek
- Faz 1: `project.godot`, autoload iskeletleri, boot/menu sahneleri
- Faz 2: çanta ve paket fizik prototipi

---

## [0.1.0] - 2026-11-10

İlk sürüm: proje iskeleti ve dokümantasyon. Oynanabilir içerik yok.

### Eklendi
- **Dizin yapısı:** `scenes/`, `scripts/autoload/`, `assets/models/`, `assets/audio/` (boş dizinler `.gitkeep` ile korunur).
- **`CLAUDE.md`** — ajan çalışma kuralları: Godot 4.7.2, `gl_compatibility` renderer, 1080x1920 portrait, tam statik tipli GDScript zorunluluğu, klasör sorumlulukları, fizik kuralları, commit/doğrulama akışı.
- **`PROJECT_SPEC.md`** — kurye çantasına kırılabilir/yaylı paket dizme konsepti, 5 adımlı core loop, paket tipleri tablosu, puanlama, ekonomi, ödüllü reklam kancaları:
  - *Ekstra Cep Aç* (`EXTRA_POCKET`) — tur boyunca +1 dayanıklı cep.
  - *Paketi Bandıyla Kurtar* (`TAPE_RESCUE`) — kırılmak üzere olan paketi kurtarır.
- **`ARCHITECTURE.md`** — autoload mimarisi (`GameManager`, `AudioService`, `AdManager`), sahne ağaçları, sinyal akışı, fizik katmanları, kayıt şeması, performans bütçesi, karar kaydı.
- **`TASKS.md`** — Faz 0–9 yol haritası ve faz bitti kriterleri.
- **`.gitignore`** — Godot önbelleği, build çıktıları, keystore ve `.env`.

### Notlar
- Proje henüz `project.godot` içermez; Godot editöründe açılamaz. Bu Faz 1'in ilk işidir.
- Autoload dosyaları (`GameManager.gd`, `AudioService.gd`, `AdManager.gd`) henüz yoktur; yalnızca mimarisi tanımlıdır.
- Repo ilk kez bu commit ile başlatıldı.

---

[Unreleased]: https://github.com/alperAygor/godot-games/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/alperAygor/godot-games/releases/tag/v0.1.0
