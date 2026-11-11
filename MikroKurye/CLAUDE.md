# Micro Courier — ajan kuralları (klasör adı MikroKurye)

Godot 4.7, GDScript (C# yok), `gl_compatibility`, dikey 1080x1920.
Bu dosya projenin anayasasıdır; kural ile sezgi çatışırsa kural kazanır.

## 1. Kod kuralları

- **Tam statik tip.** `project.godot` içinde `untyped_declaration=2` (hata).
  Her fonksiyon parametre ve dönüş tipi taşır; dönüş yoksa `-> void`.
  Koleksiyonlar tiplidir: `Array[Node3D]`, `Dictionary[String, float]`.
- **Sahne geçişi yalnızca `GameManager.goto_scene()`** ile. Sahneler
  `change_scene_to_file` çağırmaz.
- **Ses yalnızca `AudioService.play("ad")`** ile; sesler `data/sounds.json`'da tanımlıdır.
- **Reklam yalnızca `AdManager`** üzerinden; SDK çağrısı sadece `AdsProvider` uygulamasında.
- **Sihirli sayı yok.** Denge değerleri `data/*.json` + `GameData.value(...)`.
- **Saf mantık `scripts/core/`** altında, sahneye bağımlı olmayan sınıflar; test edilir.
- Yorum "ne" değil "neden" yazar. `print()` üretimde yasak → `push_warning`/`push_error`.

## 2. Klasörler

| Klasör | İçerik |
|---|---|
| `scenes/` | `.tscn` sahneleri |
| `scripts/autoload/` | Global servisler |
| `scripts/core/` | Saf mantık (test edilebilir) |
| `scripts/ui/` | Ekran script'leri; sadece gösterir |
| `scripts/services/` | Dış SDK sınırları |
| `data/` | JSON denge tabloları |
| `tests/` | `test_*.gd` birim testleri |
| `tools/` | Doğrulama, ekran görüntüsü |

## 3. Akış

`Boot` → `Menu` → `Game` → `Result`. Tur sonucu `GameManager.last_result`
sözlüğüdür; `Result` onu okur. Geri tuşu `GameManager.back_requested` sinyaliyle gelir.

## 4. Autoload'lar (sıra korunur)

`GameManager` (faz + yönlendirme) → `AudioService` → `AdManager` → `GameData`.
Servisler `PROCESS_MODE_ALWAYS` çalışır; duraklatılmış sahnede de yanıt verir.

## 5. Doğrulama (commit öncesi zorunlu)

```bash
bash tools/verify.sh
```

İçe aktarma + açılış dumanı + testler. Godot **script hatasında da 0 döndürür**, bu yüzden
çıktı ayrıca taranır. Kırmızıysa commit atılmaz.

## 6. "Bitti" tanımı

1. `verify.sh` yeşil,
2. yeni davranışın testi var (ya da neden yok yazılı),
3. `TASKS.md` ve `CHANGELOG.md` güncel.

## 7. Belgeler (bağlayıcı)

- `PROJECT_SPEC.md` — oyun tasarımı (tek doğru kaynak). Tasarım kararı gerektiren bir şey bulursan **tahmin etme, raporda "tasarım sorusu" yaz**.
- `ARCHITECTURE.md` — modül sözleşmeleri. **İmzalara birebir uy** (sınıf adı, dosya yolu, fonksiyon adı, parametre ve dönüş tipi); testler bunlara yazılır.
- `TASKS.md` — iş sırası; görevin Faz/numarası görev metninde verilir.

## 8. Mimari kurallar (bu oyun)

- **`scripts/core/` saf mantıktır:** sahne, düğüm, autoload, `Engine`, `OS`, `Input` çağırmaz; yalnızca sayı/`Dictionary`/`Array` alır-verir. Böylece headless test edilir.
- **Fizik hasar kararı vermez; ölçer.** Darbe impulsu, açısal ivme, düşüş yüksekliği `core`'a (`DamageModel`, `CargoHealth`) beslenir.
- **Sihirli sayı yok:** fizik ve denge değerleri `data/balance.json` / `data/cargo.json`'da; koda yazma. Okuma `GameData.value(...)` ile (yalnız gameplay/ui katmanında; `core` değeri parametre olarak alır).
- **Fizik 60 Hz sabit adım.** `_physics_process` içinde allocation yok (yeni `Array`/`Dictionary`/vektör dizisi üretme); çarpışma şekilleri basit (kutu/kapsül/küre); robot başına 4 raycast.
- **Stilize orta-detay (mid-poly), pürüzsüz gölgelemeli:** kırık/köşeli "low-poly" görünüm HEDEF DEĞİL (kullanıcı beğenmedi). Kavisli formlar, bevel, yumuşak normaller, vertex-renk gradyanı/AO; PBR/ağır doku yok. GLB bütçesi: hero robot ≤ 12000 üçgen, tekerlek ≤ 2000, sepet ≤ 4000, kargo ≤ 2500, masa eşyaları ≤ 6000, uzak ortam silüetleri ≤ 4000; sahnede aynı anda görünen toplam ≤ ~150k üçgen (`studio-kit/tools/validate_glb.py`, `ACCEPT_MAX_TRIS` ile).
- Yeni dosya her zaman tipli GDScript; `class_name` ile adlandır, dosya adı `snake_case`.
- Girdi: dokunma (`InputEventScreenTouch/Drag`); masaüstünde fare dokunma taklidi (`emulate_touch_from_mouse`).

## 9. Doğrulama notları

- Headless testler `core` içindir; fizik hissi otomatik doğrulanamaz. Fizik işinde `tools/game_probe.gd` çıktısı (sayılar) rapora girer.
- `.tscn`/`.tres` düzenliyorsan: `ext_resource` yolları var olmalı, her `ExtResource/SubResource` tanımlı olmalı, düğüm yolları geçerli olmalı (kabul denetimi `tscn_lint` ile bakar).
- Godot API'sinden emin değilsen tahmin etme: `studio-kit/tools/fetch_docs.sh` çıktısını `grep`'le.
