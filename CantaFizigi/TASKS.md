# TASKS — Çanta Fiziği

Durum: **v1.0.0 dikey dilim tamamlandı.**
Bu dosya yalnızca **gerçekten yapılmış** işleri listeler. Kapsam dışı kalan işler
listenin sonunda, işaretlenmeden durur — tamamlanmış gibi gösterilmez.

---

## Faz 0 — Dokümantasyon ve klasör iskeleti ✅

- [x] `scenes/`, `scripts/autoload/`, `assets/models/`, `assets/audio/` dizinleri
- [x] `CLAUDE.md` — Godot 4.x, `gl_compatibility`, 1080x1920 portrait, statik tip kuralları
- [x] `PROJECT_SPEC.md` — konsept, core loop, ödüllü reklam kancaları
- [x] `ARCHITECTURE.md` — autoload'lar ve sahne ağacı
- [x] `TASKS.md` — faz listesi
- [x] `CHANGELOG.md` — sürüm notları
- [x] `.gitignore` — Godot çıktıları, build, keystore, `.env`

## Faz 1 — Proje iskeleti ve autoload'lar ✅

- [x] `project.godot`: ad, ana sahne `res://scenes/Main.tscn`, `gl_compatibility`
- [x] Ekran 1080x1920, `canvas_items`/`expand`, `handheld/orientation=1` (portrait)
- [x] `pointing/emulate_touch_from_mouse=true`, 60 Hz fizik
- [x] `debug/gdscript/warnings/untyped_declaration=2` (hata seviyesi)
- [x] Autoload kaydı ve sırası: `GameManager` → `AudioService` → `AdManager`
- [x] `scripts/autoload/GameManager.gd` — faz makinesi, `fail_run`/`revive`, duraklatma
- [x] `scripts/autoload/AudioService.gd` — SFX havuzu, bus yönetimi, headless koruması
- [x] `scripts/autoload/AdManager.gd` — yerleşim enum'u, limitler, idempotent ödül
- [x] `scripts/services/ads_provider.gd`, `mock_ads_provider.gd`, `no_ads_provider.gd`
- [x] `data/ads.json` — yerleşim limitleri
- [x] `assets/audio/default_bus_layout.tres` — Master / SFX / Music

## Faz 2 — Çanta, ızgara ve yerleştirme ✅

- [x] `scenes/BackpackGrid.tscn` — çanta modeli + hücre düğümleri
- [x] `scripts/gameplay/GridController.gd` — 4x5 ızgara, doluluk takibi
- [x] `InputEventScreenDrag` ile sürükle-bırak, kameraya paralel taşıma düzlemi
- [x] Çok hücreli footprint desteği (1x1, 1x2, 2x2)
- [x] Hücreye snap + **squash & stretch** tween'i (ezilme → ters yaylanma → elastic durulma)
- [x] Hücre parıltısı: boş = yeşil, dolu = kırmızı, hedefte taşan halo
- [x] Geçersiz bırakmada paketin ana konumuna geri dönüşü

## Faz 3 — Fizik: sarsıntı, kırılma, erime ✅

- [x] `scripts/gameplay/ShakeSimulator.gd` — "Teslimata Başla" ile 5 sn sinüs tabanlı sarsıntı
- [x] Zarf eğrisi (rampa-in / tümsek ritmi / rampa-out) + dönme bileşeni
- [x] Sarsıntı tek bir `ShakeRoot` düğümüne biner: çanta ve paketler birlikte sallanır
- [x] `scripts/gameplay/PackagePhysics.gd` — şiddete göre biriken stres
- [x] **Cam kutusu** eşiği aşınca kırılır → oyun **duraklatılır** ve hata tetiklenir
- [x] **Buz paketi** sarsıntıyla erir, küçülür ve komşularına stres yükleyip onları sarsar
- [x] Yalnızca çantaya yerleştirilmiş paketler sarsıntıdan etkilenir (tepsidekiler değil)
- [x] `revive` sonrası sarsıntı kaldığı yerden devam eder

## Faz 4 — Ses: ElevenLabs ✅

- [x] `tools/make_sfx.py` — ElevenLabs Sound Generation API + deterministik yedek sentez
- [x] `package_drop.wav` — paket bırakma tok sesi (0,60 sn)
- [x] `glass_break.wav` — cam kırılma sesi (1,36 sn)
- [x] `ice_clink.wav` — buz tıkırtısı (0,80 sn)
- [x] `success.wav` — başarı melodisi (2,00 sn)
- [x] Tepe normalizasyonu (kırpılma yok) + 44.1 kHz mono 16-bit
- [x] Anahtar yalnızca `.env`/ortam değişkeninden; repoya **hiç** yazılmadı

## Faz 5 — Ödüllü reklam kancaları ✅

- [x] **"Ekstra Cep Aç"**: ızgarayı **4x5 → 5x5** yapar, ek sütun çantanın sağına takılır
- [x] Yeni sütun gerçekten kullanılabilir (paket yerleştirme testiyle doğrulandı)
- [x] **"Paketi Bandıyla Kurtar"**: kırılan ilk paketi onarır ve teslimatı sürdürür (revive)
- [x] Ödül yalnızca `rewarded_finished` doğrulandıktan sonra verilir; limitler `data/ads.json`
- [x] Reklam yüklenemezse sessiz geçilir, oyun bozulmaz
- [x] Mock sağlayıcı ile uçtan uca akış + "Reklam oynatılıyor" katmanı

## Faz 6 — HUD ve görsel atmosfer ✅

- [x] `scenes/HUD.tscn` + `scripts/ui/HUD.gd` — başlık, durum, sarsıntı barı, 3 buton
- [x] Hata katmanı (ÇANTA HASARLI) + kurtarma/baştan dene
- [x] Butonlar duraklatılmış sahnede de çalışır (`process_mode = ALWAYS`)
- [x] `WorldEnvironment`: bloom, SSAO, ayarlamalar (A/B render ile doğrulandı)
- [x] Sıcak renk düzeltme (lift/gain + doygunluk + vinyet) tam ekran shader ile
- [x] Stylized ışık kurulumu, masa, pastel palet, 3D modeller

## Faz 7 — Doğrulama ✅

- [x] `godot --headless --path . --import` temiz
- [x] `godot --headless --path . --quit` hatasız (0 çıkış)
- [x] `tools/screenshot.gd` ile 8 senaryo görsel olarak doğrulandı
      (idle, placed, shake, fail, revive, success, pocket, pocket_place)
- [x] Ses dosyaları dalga analiziyle doğrulandı (sessiz değil, süreler doğru)

---

## Kapsam dışı — v1 sonrası (yapılmadı, yapılmış gibi gösterilmiyor)

Bunlar `PROJECT_SPEC.md`'nin yol haritasında var; bu sürümde **yok**:

- Sürüş fazı: kamyonet, yol segmentleri, tümsek/çukur yerleşimi
- Paketlerin `RigidBody3D` ile gerçek fizik simülasyonu (şu an tween + birikimli stres modeli)
- Paket döndürme (90°), köpük/bant uygulama
- `scenes/boot.tscn`, `tests/` (birim testleri), `tools/verify.sh`
- Ekonomi, yükseltmeler, kalıcı kayıt (`PlayerProfile`)
- IAP mağazası, gerçek AdMob eklentisi, Play Store yayını
- Müzik (`Music` bus'ı hazır, parça yok), TR/EN çeviri dosyaları
