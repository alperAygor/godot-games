# Micro Courier (Mikro-Kurye)

Masa üstünde küçük bir kurye robotuyla kırılgan kargo taşıdığın dikey (portre) 3B mobil oyun. Godot 4.7, GDScript, `gl_compatibility`.

## Oynanış
- Sol alttaki sanal joystick (ya da klavye ok/WASD) ile robotu sür; kargoyu çarpmadan teslim et.
- Tehlikeler: klavye tuşları (uyarıyla kapanır), fanlar, yuvarlanan kalemler. Kargo hasarı ve batarya HUD'da ikon + yüzde olarak görünür.
- Teslimat altın + hurda kazandırır; garajda şasi, tekerlek, batarya ve şok jeli yükseltilir.
- Ödüllü reklam yerleşimleri (revive, hızlı şarj, 2× ödül, altın kutu, deneme) test modundadır; gerçek reklam SDK'sı bağlı değildir.

## Çalıştırma
```bash
godot --path . res://scenes/Boot.tscn
```

## Test / kabul
```bash
studio-kit/tools/verify.sh godot-games/MikroKurye        # içe aktarma + açılış + birim testleri
for p in game flow level meta ads polish; do godot --headless --path . -s res://tools/${p}_probe.gd; done
```

## Performans ölçümü (gerçek pencere)
```bash
godot --path . --resolution 1080x1920 -s res://tools/perf_measure.gd -- --scene=res://scenes/Game.tscn
```
Masaüstü (Apple Silicon) örnek: ~8.7 ms ort. kare, ~263 çizim çağrısı, ~75k üçgen. Android gerçek aygıt ölçümü yapılmadı.

## Android debug APK
Şablonlar ve debug anahtarı kuruluysa:
```bash
godot --headless --path . --export-debug "Android" build/android/micro-courier-debug.apk
```
`export_presets.cfg` arm64 hedefler; ETC2/ASTC sıkıştırma `project.godot` içinde açıktır. Yayın (release) imzası ve mağaza kimliği henüz ayarlanmadı.

## Belgeler
`PROJECT_SPEC.md` (tasarım), `ARCHITECTURE.md` (sözleşmeler), `TASKS.md` (faz durumu), `CHANGELOG.md`, `docs/art/` (görsel kararlar ve ekran görüntüleri).
