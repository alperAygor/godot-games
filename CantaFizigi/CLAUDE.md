# CantaFizigi — ajan kuralları

Kurye çantasına paketleri dizip sarsıntılı yolda **hasarsız teslimat** yapma oyunu.
Android, dikey (portrait), 3D fizik, `gl_compatibility` renderer.

Bu dosya projenin anayasasıdır. Kod yazmadan önce oku; kural ile sezgi çatışırsa kural kazanır.

---

## 1. Sürümler ve hedef platform

- **Godot 4.7.2 stable** (Godot 4.x serisi), dil **GDScript**. C# yok.
- Godot 3 API'si yasak: `yield`, `KinematicBody2D`, `export var`, `Spatial`, `OS.get_ticks_msec` yerine `Time.get_ticks_msec()`.
- Renderer **`gl_compatibility`** (OpenGL ES 3.0 / WebGL2). Sebep: Play Store'daki düşük segment cihazlarda Vulkan sürücü hataları ve siyah ekran riski. Vulkan'a geçiş ancak ölçülmüş bir performans ihtiyacı doğarsa, kullanıcı onayıyla.
- Ekran: **1080x1920 portrait**, `canvas_items` / `expand`. UI 1080 genişlikte tasarlanır, güvenli alan (çentik/nav bar) her zaman hesaba katılır.
- Girdi: dokunma (`InputEventScreenTouch`, `InputEventScreenDrag`). Masaüstünde fare dokunma olarak taklit edilir (`pointing/emulate_touch_from_mouse=true`).
- Hedef: **60 FPS**, orta segment Android (Snapdragon 6xx / Mali-G52 sınıfı). 30 FPS altına düşen sahne yayına çıkmaz.
- Android minSdk 24, targetSdk 36.

Emin olmadığın API'yi **tahmin etme**. Godot MCP ile `godot-docs` sorgula, yoksa `godot --headless --doctool` çıktısına/dokümantasyona bak.

---

## 2. Statik tip kuralları (pazarlıksız)

Proje **tam statik tipli GDScript** yazar. Tip belirtilmemiş değişken = hata.

```gdscript
# DOĞRU
const MAX_PACKAGE_COUNT: int = 12
const GRAVITY_SCALE: float = 1.0

@export var move_speed: float = 6.0
@export var package_scene: PackedScene

var current_damage: float = 0.0
var packed_items: Array[Node3D] = []
var settings: Dictionary[String, Variant] = {}

func apply_impact(force: float, kind: DamageKind) -> void:
    if force <= 0.0:
        return
    current_damage += force * kind.multiplier

func collect_targets() -> Array[Node3D]:
    var result: Array[Node3D] = []
    return result
```

```gdscript
# YANLIŞ
var speed = 6.0                  # tipsiz
func move(delta):                # tipsiz parametre ve dönüş
    var n = get_node("Bag")      # n: Node, daraltma yok
    for p in packed_items:       # p: Variant
        pass
```

Kurallar:

1. **Her fonksiyon** parametre ve dönüş tipi taşır; dönüş yoksa `-> void` yazılır (atlama, açıkça yaz).
2. **Her değişken** tiplidir. `var x := ...` sadece sağ tarafın tipi tartışmasızsa (ör. `Vector3.ZERO`, `load()` sonucu `PackedScene`, sabit sayı) kullanılır. Şüphede açık tip yaz.
3. **Koleksiyonlar tiplidir**: `Array[Node3D]`, `Dictionary[String, float]`. `Array`/`Dictionary` çıplak kullanılmaz.
4. **`class_name` taşıyan** her sınıf `scripts/core/` altında, saf veri/mantık, sahneye bağımlı değil.
5. **Daraltma (narrowing)**: `Node` dönen API'lerde `as` ile daralt, `is` ile doğrula:
   ```gdscript
   var body: RigidBody3D = node as RigidBody3D
   if body == null:
       push_error("Beklenen RigidBody3D: %s" % node.name)
       return
   ```
6. **Enum** kullan, sihirli sayı değil: `enum Phase { PACKING, DRIVING, DELIVERED }`.
7. **Sinyal imzaları tipli** yazılır: `signal package_broken(package: Node3D, damage: float)`.
8. `Variant` yalnızca JSON/save sınırlarında; kullanıcıya açık fonksiyonlarda değil.
9. `null` kontrolü zorunlu: fizik gövdeleri serbest bırakılabilir (`is_instance_valid()`).
10. `project.godot` içinde `debug/gdscript/warnings/untyped_declaration=2` (error) açık kalır. Uyarıyı susturmak için `@warning_ignore` kullanma; kodu düzelt.

---

## 3. Klasör yapısı ve sorumluluklar

| Klasör | Ne konur | Ne konmaz |
|---|---|---|
| `scenes/` | `.tscn` sahneleri (boot, menü, oyun, sonuç) | script |
| `scripts/autoload/` | `GameManager.gd`, `AudioService.gd`, `AdManager.gd` — global servisler | sahne mantığı |
| `scripts/core/` | Saf mantık: hasar hesabı, puanlama, ekonomi, paket tanımları. `RefCounted`/`Resource`, sahneye bağımsız, test edilebilir | `get_node` çağrısı |
| `scripts/gameplay/` | Bag, Package, Truck, Road gibi fizik düğümleri | UI |
| `scripts/ui/` | Ekran/HUD script'leri. Sadece gösterir, core'a delege eder | kural/hesap |
| `scripts/services/` | Dış SDK arayüzleri (`AdsProvider`) | SDK'yı doğrudan çağıran kod |
| `assets/models/` | `.glb` modeller (Blender çıktısı) | .blend kaynak (ayrı yedeklenir) |
| `assets/audio/` | `.ogg` müzik, `.wav` SFX (ElevenLabs üretimi) | telifsiz olmayan ses |
| `data/` | JSON denge tabloları (Faz 2'de açılır) | script |
| `tests/` | `test_*.gd` birim testleri (Faz 1'de açılır) | üretim kodu |

**Tek yönlü bağımlılık:** `ui` → `gameplay` → `core`. `core` hiçbir şeyi import etmez. Autoload'lar `core` ve `services` kullanabilir.

---

## 4. Kod stili

- Dosyalar `snake_case.gd`, sınıflar `PascalCase`, sabitler `SCREAMING_SNAKE_CASE`, özel üyeler `_underscore`.
- Sinyaller geçmiş zaman: `package_landed`, `run_finished`. Sinyal adı fiil değil olay bildirir.
- **Sihirli sayı yok.** Fizik kuvveti, hasar eşiği, para ödülü → `data/*.json`. Kodda varsayılan yalnızca `const` olarak ve tek yerde.
- Bir fonksiyon ~40 satırı geçiyorsa böl. Bir script ~300 satırı geçiyorsa sorumlulukları ayır.
- Yorum, kodu tekrar etmez; **neden**'i yazar. Türkçe yorum serbest, kod tanımlayıcıları İngilizce.
- `print()` üretim kodunda yasak → `push_warning` / `push_error` veya `Debug` yardımcısı.
- Her `RigidBody3D` için `physics_material_override` açıkça atanır (sürtünme varsayılana bırakılmaz).

**Renk düzeltme:** Environment'ın `adjustment_color_correction` LUT'unu kullanma — Godot 4.7 `gl_compatibility`'de bozuk sonuç veriyor (ölçüldü). Sıcak ton `assets/shaders/color_correction.gdshader` üzerinden, `CanvasLayer` (layer 1) içindeki tam ekran `ColorRect` ile uygulanır. UI katmanı onun **üstünde** (layer 2) olmalı, yoksa arayüz de renk düzeltmesinden geçer.

---

## 5. Fizik ve oynanış kuralları

- **Birim:** 1 Godot birimi = 1 metre. Çanta ~0.35 m genişlik, paketler 0.06–0.18 m.
- **Fizik tick 60 Hz** (`physics/common/physics_ticks_per_second=60`). 120 Hz hedefleme; mobilde ısınma yaratır.
- Paketler `RigidBody3D`, `continuous_cd` açık, `max_contacts_reported = 4`. Temas sayısı fazla olan gövde `sleeping`'e bırakılır.
- Çantanın iç yüzeyi **ayrı `StaticBody3D` duvarlardan** oluşur; konkav mesh collider kullanılmaz (Godot 4'te güvenilmez ve pahalı).
- Kırılma, temas kuvvetiyle değil **impuls + hız değişimiyle** hesaplanır (`_integrate_forces` içinde `contact impulse` okunur). Eşikler `data/packages.json`.
- Rastgelelik tohumlanabilir olmalı (`RandomNumberGenerator`), test tekrar üretilebilir olsun.
- Fizik "çıldırırsa" paket ışınlanmaz; `Node3D` pozisyonu NaN/Inf kontrolünden geçer, NaN görülürse çalışma iptal edilir ve telemetriye yazılır.

---

## 6. Autoload ve SDK kuralları

- Autoload listesi `project.godot` içinde **sıralıdır** ve sıra korunur: `GameManager` → `AudioService` → `AdManager`.
- Sahne script'leri başka sahneyi `get_tree().change_scene_to_file` ile açmaz; **`GameManager` üzerinden** geçiş yapılır.
- **Reklamı doğrudan çağırma.** `AdManager.show_rewarded(AdPlacement.EXTRA_POCKET)` kullan; SDK çağrısı sadece `AdsProvider` implementasyonunda yaşar.
- **Ses çalma doğrudan `AudioStreamPlayer` ile yapılmaz**, `AudioService.play_sfx(...)` kullanılır.
- **Sır yok.** ElevenLabs/AdMob/Play anahtarları repoya girmez; `.env` veya ortam değişkeni adı belirtilir. Anahtarı log'a basma.
- Reklam ödülü **yalnızca** `rewarded_finished` sinyali doğrulandıktan sonra verilir; çift ödül koruması (idempotency) zorunlu.

---

## 7. Commit ve doğrulama

- Her değişiklikten sonra: `godot --headless --path . --import` + proje açılış smoke testi + `tests/run_tests.gd`.
- **Doğrulama geçmeden commit yok.** Script hatası çıktıda `SCRIPT ERROR` / `ERROR:` ile aranır.
- Commit mesajı Conventional Commits: `feat(CantaFizigi): ...`, `fix(...): ...`, `docs(...): ...`.
- Bir mantıksal değişiklik = bir commit. Karışık commit atma.
- Kullanıcıya ait dosya (keystore, `.env`, kişisel not) silinmez/üzerine yazılmaz.
- `.godot/`, `build/`, `*.apk` repoda tutulmaz (`.gitignore`).

---

## 8. Araçlar (MCP)

| Araç | Kullanım |
|---|---|
| **Godot MCP** | Projeyi çalıştır → `get_debug_output` ile hatayı oku → durdur. Sahne ağacını denetle. |
| **Blender MCP** | `assets/models/` için çanta, paket, kamyonet modelleri. Dışa aktarım **`.glb`**, ölçek metre, +Z ileri, taban Y=0. |
| **ElevenLabs** | SFX/müzik üretimi (`assets/audio/`, `.ogg` 128 kbps). Anahtar `.env`'den, asla repoya yazılmaz. |
| **Bash/Git** | Build, doğrulama, push. Yıkıcı komut öncesi hedefi doğrula. |

Model üretiminde hedef: **düşük poligon** (paket ≤ 500 tris, çanta ≤ 2.000 tris), doku ≤ 512 px. Bugünkü beş modelin toplamı 2.664 tris / 13 yüzey (`assets/models/README.md`). Model eklerken bu bütçeyi aşan varlık sahneye girmez.

Varlıklar **elle değil** kodla üretilir: `tools/blender/make_models.py`. Model değişecekse script düzenlenir ve `--out assets/models` ile yeniden üretilir; `.blend` kaynak repoya girmez.

Sesler de kodla üretilir: `python3 tools/make_sfx.py` (ElevenLabs, anahtar `.env` veya `ELEVENLABS_API_KEY`). Anahtar yoksa aynı isimlerle deterministik yedek sentez üretilir; oyun her durumda sesli çalışır. Yeni ses eklerken `SOUNDS` sözlüğüne yaz ve `AudioService`'e bir `play_` metodu ekle.

---

## 9. Tanım: "bitti"

Bir iş ancak şu üçü sağlandığında biter:
1. Kod tam statik tipli ve `--import` temiz (hata yok).
2. Yanında testi var ya da test neden yok yorumla gerekçelendi.
3. `TASKS.md` ve `CHANGELOG.md` güncellendi.
