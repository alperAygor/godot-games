# TASKS — Çanta Fiziği

Durum: **Faz 0 tamamlandı**. Sıradaki: **Faz 1**.
Bir işi bitirince `[ ]` → `[x]` yap ve `CHANGELOG.md`'ye ekle. Faz bitti kriteri sağlanmadan sonraki faza geçilmez.

---

## Faz 0 — Dokümantasyon ve klasör iskeleti ✅

**Hedef:** Projenin kuralları ve hedef mimarisi yazılı olsun; repo'da beklenen dizinler hazır olsun.

- [x] `scenes/` dizini (Faz 1'de `.tscn` dosyaları gelecek)
- [x] `scripts/autoload/` dizini
- [x] `assets/models/` dizini
- [x] `assets/audio/` dizini
- [x] `CLAUDE.md` — Godot 4.x, `gl_compatibility`, 1080x1920 portrait, statik tip kuralları
- [x] `PROJECT_SPEC.md` — konsept, core loop, ödüllü reklam kancaları
- [x] `ARCHITECTURE.md` — autoload'lar ve sahne ağacı
- [x] `TASKS.md` — faz listesi (bu dosya)
- [x] `CHANGELOG.md` — sürüm notu başlangıcı
- [x] `.gitignore` — Godot çıktıları, build artıkları, sırlar

**Bitti kriteri:** Dokümanlar repo'da, dizinler mevcut, commit atıldı ve `main`'e push edildi. ✅

---

## Faz 1 — Proje iskeleti ve autoload'lar

**Hedef:** Proje Godot 4.7.2'de hatasız açılsın, boş bir sahne çalışsın, test altyapısı koşsun.

- [x] `project.godot`: ad `CantaFizigi`, ana sahne `res://scenes/Main.tscn`, renderer `gl_compatibility`
- [x] Ekran: 1080x1920, `stretch/mode=canvas_items`, `aspect=expand`, `handheld/orientation=1` (portrait)
- [x] `pointing/emulate_touch_from_mouse=true`
- [x] `debug/gdscript/warnings/untyped_declaration=2` (error), `unused_parameter=1`
- [ ] Autoload kaydı (sırayla): `GameManager`, `AudioService`, `AdManager`
- [ ] `scripts/autoload/GameManager.gd` — `Phase` enum'u, `_set_phase`, `goto_scene`, boş `save/load`
- [ ] `scripts/autoload/AudioService.gd` — bus volume API'si, headless guard
- [ ] `scripts/autoload/AdManager.gd` — `Placement` enum, `can_offer`, `reset_run_limits` (sağlayıcı `NoAdsProvider`)
- [ ] `scripts/services/ads_provider.gd`, `no_ads_provider.gd`, `mock_ads_provider.gd`
- [x] `scenes/Main.tscn` — `Main` + `UILayer/Safe` (SceneHost/Fade autoload'larla birlikte gelecek)
- [ ] `scenes/boot.tscn` — logo, 0.4 sn bekleme, menüye geçiş
- [ ] `tests/test_case.gd` + `tests/run_tests.gd` (çıkış kodu 0/1/2)
- [ ] `tools/verify.sh` — `--import` + 5 kare smoke + testler, `SCRIPT ERROR` taraması
- [ ] `icon.svg`, `assets/theme/main_theme.tres` (boş tema)

**Bitti kriteri:** `godot --headless --path . --import` hata vermeden biter; `tools/verify.sh` 0 döner; boot → menü geçişi çalışır (boş menü yeterli).
**Bağımlılık:** Faz 0.

---

## Faz 2 — Çanta ve paket fizik prototipi

**Hedef:** "Paketleme" bulmacası oynanabilsin; kırılma mantığı çalışsın ve testle doğrulansın.

- [ ] `data/packages.json` — standart, kırılabilir, yaylı, ağır tanımları
- [ ] `scripts/core/package_data.gd` (`Resource`) + `data` yükleyici
- [ ] `scripts/core/damage_model.gd` — impuls → hasar; birim testi
- [ ] `scripts/core/damage_kind.gd` — enum + çarpanlar
- [ ] `scenes/gameplay.tscn` — `Bag` düğümü, iç duvarlar (5 ayrı `CollisionShape3D`)
- [ ] `scripts/gameplay/bag.gd` — paket listesi, `damage_changed`, `package_broken`
- [ ] `scripts/gameplay/package.gd` — `RigidBody3D`, `_integrate_forces` ile temas impulsu
- [x] Sürükle-bırak: `InputEventScreenDrag` + kameraya paralel düzlem, hücreye snap, **squash & stretch** tween, geçersiz bırakmada geri dönüş (`scripts/gameplay/GridController.gd`)
- [x] Hücre parıltısı: boş = yeşil, dolu = kırmızı, hedef hücrede taşan halo
- [ ] Paket döndürme (90° adım), köpük/bant uygulama (görsel placeholder)
- [ ] Fizik: paketler `RigidBody3D` olacak (şu an sadece görsel/tween — kırılma Faz 3'te)
- [ ] `assets/models/package_standard.glb` (Blender) — geçici küp de kabul
- [ ] Test: kırılabilir paket 4.0 m/s üstünde kırılır, altında kırılmaz; yaylı paket sekme katsayısı

**Bitti kriteri:** 6 paket elle dizilebiliyor, sert düşüşte kırılanlar kırılıyor, hasar barı doğru güncelleniyor; `test_damage_model` geçiyor.
**Bağımlılık:** Faz 1.

---

## Faz 3 — Sürüş, yol ve puanlama

**Hedef:** Turun ikinci yarısı: tümsekli yolda sürüş ve teslimat sonucu.

- [ ] `scripts/core/scoring.gd` — hasar → yıldız/ücret tablosu + test
- [ ] `scripts/core/run_state.gd` — aktif tur verisi
- [ ] `scripts/gameplay/truck.gd` — otomatik ilerleme, fren/gaz, şerit
- [ ] `scripts/gameplay/road.gd` — segment havuzu, spawn/despawn
- [ ] 3 yol segmenti: düz, tümsekli, virajlı (+ çukur bantlı)
- [ ] `BagMount` süspansiyonu — gecikmeli/sönümlü takip, sarsıntı kaynağı
- [ ] `data/balance.json` — hız, tümsek etkisi, hasar katsayıları
- [ ] `scripts/gameplay/camera_rig.gd` — takip + azaltılabilir sarsıntı
- [ ] Teslimat tetikleyicisi → `Gameplay.finished(RunResult)`
- [ ] Test: 3 yıldız eşiği, 0 yıldız/para kesintisi, segment sırası deterministik

**Bitti kriteri:** Tek tur baştan sona oynanıyor; hasar gerçekçi dağılıyor; 3 yıldız alınabiliyor; sonuç ekranına veri akıyor.
**Bağımlılık:** Faz 2.

---

## Faz 4 — Ekonomi, ilerleme, kayıt

**Hedef:** Oyuncu ilerlemesi kalıcı olsun.

- [ ] `scripts/core/player_profile.gd` — şema v1, `_migrate`
- [ ] `GameManager.save/load` — atomik yazma, bozuk dosya kurtarma
- [ ] `scripts/core/economy.gd` — para ekle/harca, itibar
- [ ] `data/upgrades.json` + yükseltme ekranı (çanta kapasitesi, süspansiyon, bant, kasko)
- [ ] Mahalle/teslimat ilerlemesi (`data/roads.json`)
- [ ] Test: save/load round-trip, bozuk JSON, v0→v1 migrasyon

**Bitti kriteri:** Uygulama kapanıp açılınca para/ilerleme/ses ayarları korunuyor.
**Bağımlılık:** Faz 3.

---

## Faz 5 — Arayüz akışı

**Hedef:** Menü, HUD, sonuç ekranı, ayarlar — tam mobil UI.

- [ ] `scenes/menu.tscn` — Oyna / Yükselt / Ayarlar
- [ ] `scenes/ui/settings_popup.tscn` — müzik, SFX, titreşim, kamera sarsıntısı
- [ ] `scripts/ui/hud.gd` — hasar barı, inklinometre, hız göstergesi
- [ ] `scenes/result.tscn` — yıldızlar, paket raporu, ödül
- [ ] `SafeArea` — çentik/nav bar güvenliği, tüm ekranlarda
- [ ] Android geri tuşu — popup kapatır, menüde çıkış onayı
- [ ] TR/EN çeviriler (`assets/translations/strings.csv`)
- [ ] Dokunma hedefi ≥ 88 px denetimi

**Bitti kriteri:** Akış: boot → menü → oyun → sonuç → menü; geri tuşu her ekranda doğru; metinler çeviriden.
**Bağımlılık:** Faz 4.

---

## Faz 6 — Ödüllü reklam kancaları

**Hedef:** `AdManager` gerçek akışla çalışsın; önce mock sağlayıcıyla ölçülsün.

- [ ] `scripts/services/mock_ads_provider.gd` — 1.5 sn bekleme, %10 hata simülasyonu
- [ ] `data/ads.json` — yerleşim limitleri ve cooldown
- [ ] `EXTRA_POCKET` — cep dolu durumunda teklif, tur boyunca +1 cep
- [ ] `TAPE_RESCUE` — %80–99 hasarda 3 sn pencere, hasarı %40'a indir, 1 kez
- [ ] `DOUBLE_REWARD` — sonuç ekranında ücret ×2
- [ ] `AdManager` idempotency + limit testleri (`test_ad_limits.gd`)
- [ ] Reklam dolmadığında: buton gizlenir, hata mesajı yok
- [ ] Gerçek SDK: AdMob Android eklentisi `AdMobProvider` (yalnızca `services/` altında)

**Bitti kriteri:** İki kanca da uçtan uca çalışıyor; ödül çift verilmiyor; limitler aşılamıyor; SDK yoksa oyun bozulmuyor.
**Bağımlılık:** Faz 5.

---

## Faz 7 — Ses ve görsel varlıklar

**Hedef:** Oyun "hissedilsin": model, doku, ses, efekt.

- [x] Blender — çanta ve paketler: `backpack_base.glb`, `pkg_glass_1x2.glb`, `pkg_ice_1x1.glb`, `pkg_iron_2x2.glb`, `pkg_spring_1x1.glb` (toplam 2.664 üçgen, metre ölçek, +Z ileri, alt-merkez origin). Detay: `assets/models/README.md`
- [ ] Blender — `truck_01.glb` ve yol parçaları (Faz 3 ile birlikte)
- [ ] Malzeme atlası + 512 px dokular; `gl_compatibility` ile doğrula
- [ ] ElevenLabs SFX: çarpma (3 malzeme), kırılma, bant, motor, UI tık
- [ ] Müzik döngüsü (≤ 60 sn, `.ogg`)
- [ ] `AudioService` SFX havuzu + müzik geçişi
- [ ] Hasar/kırılma görsel geri bildirimi (parçacık, çatlak decal, 200 ms uyarı)
- [ ] Ekran sarsıntısı ve titreşim

**Bitti kriteri:** Kırılma anı ses+efekt ile net; 8 eşzamanlı ses kesilmeden çalıyor; model bütçeleri aşılmıyor.
**Bağımlılık:** Faz 6.

---

## Faz 8 — Cila ve performans

- [ ] Orta segment cihazda 60 FPS (ölçüm: Godot profiler + `--print-fps`)
- [ ] Draw call ≤ 120, tris ≤ 60k, aktif gövde ≤ 16
- [ ] `gl_compatibility` uyumluluk taraması (gölge, materyal, post-process yok)
- [ ] İlk açılış süresi ≤ 1.2 sn
- [ ] Fizik kararlılığı: 10 dk sürekli oynanışta NaN/patlama yok
- [ ] Animasyon eğrileri, buton geri bildirimi, geçişler
- [ ] Erişilebilirlik: renk körlüğü ikonları, dokunma alanları, metin okunabilirliği

**Bitti kriteri:** FPS bütçesi tutuyor; 30 dakikalık oynanış oturumunda çökme yok.
**Bağımlılık:** Faz 7.

---

## Faz 9 — Test ve Android yayın

- [ ] Birim test kapsamı: core sınıflarının tamamı
- [ ] Emülatörde (Pixel 8, SDK 36) tam akış testi
- [ ] Gerçek cihazda fizik performans testi
- [ ] Export preset: paket adı `com.alperaygor.cantafizigi`, minSdk 24, targetSdk 36
- [ ] Debug APK → internal track → closed testing
- [ ] Gizlilik politikası, veri güvenliği formu, yaş derecelendirmesi
- [ ] Crash reporting (opsiyonel, KVKK/GDPR onaylı)
- [ ] Mağaza görselleri, 1080x1920 ekran görüntüleri

**Bitti kriteri:** Play Store internal track'te crash-free ≥ %99, D1 retention ilk verisi toplandı.
**Bağımlılık:** Faz 8.

---

## Şu anki durum

| Faz | Durum | Not |
|---|---|---|
| 0 | ✅ Bitti | Dokümanlar + dizinler |
| 1 | 🟡 Kısmi | `project.godot` + sahneler hazır; autoload'lar ve boot/test altyapısı kaldı |
| 2–9 | ⬜ Bekliyor | |
| 7 (varlık) | 🟡 Kısmi | 5 model hazır; araç/yol ve ses kaldı |

**Sıradaki somut adım:** Faz 1 — `project.godot` oluştur, üç autoload'u boş iskeletle ekle, `main.tscn` + `boot.tscn` kur, `tools/verify.sh` ile doğrula.

> Not: Faz 7'nin model üretimi bilinçli olarak öne çekildi — Faz 2 prototipinin gerçek varlıklarla kurulabilmesi için paketler erken üretildi.
