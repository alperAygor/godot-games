# Kablo Düğümü: Akım Ustası

Yüksek voltajlı renkli kabloları düğümden çözüp **kendi rengindeki** prizlere bağladığın,
3D fizik ve bulmaca oyunu. Stilize low-poly endüstriyel pano, neon fişler, kısa devre
kıvılcımları ve ASMR hissi veren ses geri bildirimleri.

- **Motor:** Godot 4.7.2 (GDScript, C# yok)
- **Platform:** Android, dikey 1080x1920, `gl_compatibility` (düşük segment uyumluluğu)
- **Hedef:** 60 FPS, tek elle oynanır, 45–105 saniyelik 12 bölüm

## Oynanış

1. **Analiz et** — üstte ana pano (kaynak terminaller), altta priz şeridi. Kablolar düğümlü,
   fişler panonun ortasında mıknatısla tutulu.
2. **Sürükle** — fişe dokun, parmağını gezdir. Fiş havaya kalkar, kablo verlet fizikle peşinden gelir.
3. **Teması kes** — farklı renkli iki kablo birbirine değerse kıvılcım çıkar ve **aşırı yük barı** dolar.
   Teması kesersen bar boşalır. Bar %100 olursa sigorta atar, bölüm başarısız olur.
4. **Tak** — fişi kendi rengindeki prizin üstüne bırak: snap + "clack". Yanlış renk priz ark yapar,
   bar cezası alırsın ve fiş geri seker.
5. **Dengele** — bütün fişler yerindeyse devre tamamlanır; voltmetre sakinleşir, yıldızlar verilir.

Aynı renk teması güvenlidir. Kabloların uzunluğu sınırlıdır; fişi kablo boyunun ötesine çekemezsin.
Yıldızlar süre, kısa devre sayısı ve tepe yükten hesaplanır.

### Kontroller
- **Dokun + sürükle:** fişi taşı (masaüstünde fare, `emulate_touch_from_mouse`).
- **Esc / Android geri tuşu:** geri (oyun içinde menü, menüde çıkış).
- Oyun içi HUD: duraklat, Altın Keski, Yalıtım Spreyi.

## Ödüllü reklam kancaları

| Yerleşim | Tetikleyici | Ödül |
|---|---|---|
| `FUSE_RESCUE` | Sigorta attığında | Yükü sıfırlar + 15 sn yalıtım kalkanı, aynı bölümden devam |
| `GOLDEN_CUTTER` | Bölüm içi buton (1/bölüm) | En çok dolaşan fişi altın ışınla otomatik bağlar |
| `INSULATION_SPRAY` | Bölüm içi buton (1/bölüm) | 10 sn kalkan: temas barı doldurmaz |

Bugün `MockAdsProvider` kullanılır (1.2 sn simülasyon, %8 dolmama). Gerçek SDK eklemek için
yalnızca `scripts/services/ads_provider.gd` arayüzünü uygulayan yeni bir sağlayıcı yazılır;
oyun kodu değişmez. Limitler `data/ads.json`.

## Çalıştırma

```bash
cd godot-games/KabloDugumu
godot --path .                    # editörde açmak için: godot --path . -e
bash tools/verify.sh              # import + açılış dumanı + birim testleri + oyun dumanı
python3 tools/build_theme.py --check
```

Doğrulama Godot script hatasında bile 0 dönebildiği için `verify.sh` çıktıyı ayrıca
`SCRIPT ERROR|Parse Error` için tarar. Kırmızıysa iş bitmemiştir.

## Proje yapısı

```
scenes/            Boot, Menu, LevelSelect, Game, Result, HUD (sahne geçişi yalnız GameManager'dan)
scripts/autoload/  GameManager (akış+kayıt), AudioService, AdManager, GameData
scripts/core/      saf mantık: seviye üretimi, aşırı yük, snap, skor, kayıt, halat matematiği (testli)
scripts/gameplay/  3D dünya: pano, kablo fiziği, fiş/priz, temas, kıvılcım, kamera, voltmetre
scripts/ui/        HUD ve ekranlar (sadece gösterir)
scripts/services/  AdsProvider sınırı (SDK buraya hapsolur)
data/              JSON denge tabloları: levels, balance, ads, theme, sounds, sfx_recipes
tests/             tests/unit/test_*.gd — otomatik keşif, headless koşar
tools/             verify.sh, build_theme.py, make_sfx.py, game_probe.gd, flow_shot.gd, montage
```

Dokümanlar: [PROJECT_SPEC.md](PROJECT_SPEC.md) (tasarım), [ARCHITECTURE.md](ARCHITECTURE.md)
(sözleşmeler), [CLAUDE.md](CLAUDE.md) (kod kuralları), [TASKS.md](TASKS.md), [CHANGELOG.md](CHANGELOG.md).

## Ses

Ses efektleri `data/sfx_recipes.json`'dan üretilir:

```bash
python3 tools/make_sfx.py            # eksikleri üretir (anahtar yoksa deterministik sentez)
ELEVENLABS_API_KEY=... python3 tools/make_sfx.py --force   # ElevenLabs sound-generation
```

ElevenLabs anahtarı repoya girmez; anahtar yoksa aynı isimlerle sentez üretilir, oyun her durumda seslidir.

## Ekran görüntüleri

```bash
godot --path . -s res://tools/flow_shot.gd -- --out-dir=/tmp/kablo_shots
bash tools/make_shots.sh             # + montaj kontak sayfası
```

## Lisans / varlıklar

- Font: Baloo 2 (OFL) — `assets/fonts/OFL_Baloo2.txt`
- İkonlar: Lucide (ISC) — `assets/icons/LICENSE_lucide.txt`
- 3D varlıklar prosedürel primitiflerdir; harici model yok.
- Ses: anahtar varsa ElevenLabs, yoksa deterministik sentez.
