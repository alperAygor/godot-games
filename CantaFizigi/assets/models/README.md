# assets/models — 3D varlıklar

Tüm modeller `tools/blender/make_models.py` ile **prosedürel** üretilir. Elle modelleme yok; değişiklik
için script düzenlenir ve yeniden üretilir.

```bash
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
    --python tools/blender/make_models.py -- --out assets/models
```

## Sözleşme (tüm dosyalar için)

| Kural | Değer |
|---|---|
| Format | `.glb` (glTF 2.0 binary), gömülü materyal, doku yok |
| Birim | 1 birim = 1 metre |
| Yön | +Z ileri, +Y yukarı (Godot ile aynı) |
| Origin | **Alt-merkez**; model zemine oturur (`minY = 0`, `centerX = centerZ = 0`) |
| Transform | Tümü uygulanmış (node'da TRS yok; `location=0, rotation=0, scale=1`) |
| Gölgeleme | Flat (low-poly), smooth yok |
| Materyal | Palet rengi, sır yok; `doubleSided = false` |
| Izgara | 1 hücre = **0,075 m** |

## Dosyalar

| Dosya | Izgara | Boyut G×Y×D (m) | Üçgen | Yüzey | Notlar |
|---|---|---|---|---|---|
| `backpack_base.glb` | 4×5 | 0,346 × 0,470 × 0,138 | 1.412 | 4 | Ön yüzü açık, içi 20 bölmeli kurye çantası |
| `pkg_glass_1x2.glb` | 1×2 | 0,075 × 0,150 × 0,075 | 308 | 2 | Yarı saydam mavi cam (`alphaMode = BLEND`, alfa 0,42) |
| `pkg_ice_1x1.glb` | 1×1 | 0,073 × 0,075 × 0,073 | 176 | 2 | Kristal kesim, üstte buz dikenleri |
| `pkg_iron_2x2.glb` | 2×2 | 0,150 × 0,150 × 0,078 | 452 | 2 | Köşe dikmeleri + perçinler, metalik 0,85 |
| `pkg_spring_1x1.glb` | 1×1 | 0,075 × 0,071 × 0,075 | 316 | 3 | Açık üstlü tekne + 3 sarım helezon yay |
| **Toplam** | | | **2.664** | **13** | |

Çanta bölmeleri: 4 sütun × 5 satır = **20 cep**, her cep 0,075 × 0,075 × ~0,085 m.
1×1 paket bir cebe tam oturur; 2×2 paket üç boyutta 2 hücre kaplar.

## Palet

| Materyal | Hex | Kullanım |
|---|---|---|
| `BAG_Body` | `#8FD9B6` | Çanta gövdesi (nane) |
| `BAG_Trim` | `#FFF0D2` | Ön çerçeve, kayış tokaları, kulp (krem) |
| `BAG_Grid` | `#A9CFEA` | Izgara bölücüler (pudra mavisi) |
| `BAG_Strap` | `#B9A3EC` | Omuz kayışları (lavanta) |
| `Glass_Blue` / `Glass_Frame` | `#7FB8F0` / `#4C7FB5` | Cam gövde / çerçeve |
| `Ice_Cyan` / `Ice_Deep` | `#9FE8EF` / `#5FC7D6` | Buz gövde / dikenler |
| `Iron_Dark` / `Iron_Steel` | `#4A5060` / `#9AA3B2` | Demir gövde / dikme + perçin |
| `Spring_Shell` / `Spring_Inner` / `Spring_Coil` | `#FFD75E` / `#FFE9A8` / `#C9861C` | Tekne / taban / yay |

## Godot'ta kullanım

- Sahneye eklerken kök düğümün konumu **zemine temas noktasıdır**; ayrıca hizalama gerekmez.
- Çarpıştırıcı modelden **türetilmez**, elle konur (kutu `BoxShape3D`) — çanta duvarları ayrı `StaticBody3D`.
- Paket çarpıştırıcı boyutu ızgara ölçüsüdür (`1x1` → 0,075³), model bunun biraz içinde kalır.
- Cam materyali saydam olduğu için `gl_compatibility`'de sıralama sorunlarına karşı paket sayısı ≤ 12 ile sınırlanır.
