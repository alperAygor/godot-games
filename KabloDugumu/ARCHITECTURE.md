# ARCHITECTURE — Kablo Düğümü: Akım Ustası

## Katmanlar

```
UI (Control)            -> sunum, giriş
Gameplay (Node3D)       -> dünya, fizik
Autoload servisleri     -> akış, ses, reklam, veri
Core (RefCounted)       -> saf mantık, test edilebilir
Services (AdsProvider)  -> dış SDK sınırı
```

Bağımlılık yukarıdan aşağı; `core` hiçbir katmanı tanımaz.

## Autoload'lar

| Servis | Sorumluluk | API |
|---|---|---|
| `GameManager` | Faz makinesi, sahne yönlendirme, tur sonucu, geri tuşu | `goto_scene(key)`, `start_game()`, `finish_run(result)`, `back_requested` |
| `AudioService` | SFX havuzu, `data/sounds.json` tabanlı | `play(ad, pitch_variance)` |
| `AdManager` | Ödüllü reklam orkestrasyonu, limitler | `can_offer(p)`, `show_rewarded(p)`, `rewarded_finished` |
| `GameData` | `res://data/*.json` tabloları | `table(ad)`, `value(tablo, anahtar, varsayilan)` |

## Sahne akışı

```
Boot --(0.4 sn)--> Menu --(Oyna)--> Game --(finish_run)--> Result
                      ^                                      |
                      +--------------(Ana Menü)--------------+
```

`GameManager.last_result` sözlüğü `Result` sahnesinin tek veri kaynağıdır:
`{damage, stars, multiplier, fee, reputation, success}`.

## Yeni içerik eklerken

1. Denge sayısı → `data/*.json`
2. Kural → `scripts/core/` (saf sınıf) + test
3. Görsel → `scenes/` + `scripts/ui/`
4. Ses → dosyayı `assets/audio/sfx/` altına koy, `data/sounds.json`'a yaz
