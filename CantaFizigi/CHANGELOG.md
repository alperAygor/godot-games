# Changelog

Bu proje [Semantic Versioning](https://semver.org/lang/tr/) kullanır.
Format [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/) temellidir.
Tarihler `YYYY-AA-GG` biçimindedir.

---

## [Unreleased]

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
