# Çamaşır İpi — ajan kuralları

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
