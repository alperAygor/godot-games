# F7.9 — Render Kalitesi (pikselimsi görünüm)

Kullanıcı görüntüyü "pikselimsi" buldu: kenarlarda merdiven tırtığı, kaba toon
bantları, titrek/kesik anahat. Bu belge yapılan **yalnız görsel** değişiklikleri,
gerekçelerini ve mobil maliyet notlarını toplar. Fizik, çarpışma ve probe sayıları
değişmedi.

## 1. Kenar yumuşatma — `project.godot`

| Ayar | Değer | Neden |
|---|---|---|
| `anti_aliasing/quality/msaa_3d` | `1` (2×) | Geometri silüetini (robot gövdesi, tekerlek, sepet) ve anahat kabuğunu çok-örnekle yumuşatır. `2` (4×) daha pürüzsüz ama mobilde pahalı; ileride "Kalite" seçeneği. |
| `anti_aliasing/quality/screen_space_aa` | — | **Compatibility renderer'da desteklenmiyor** (Godot: "yalnız Forward+/Mobile"). Bu yüzden açılmadı; shader kaynaklı kenarlar (toon bandı) `smoothstep`+`fwidth` ile, ince anahat MSAA ile yumuşatılır. |
| `textures/default_filters/use_nearest_mipmap_filter` | `false` | Mipmap zincirinde trilinear örnekleme (varsayılan). |
| `textures/default_filters/anisotropic_filtering_level` | `4` (16×) | Eğik yüzeylerde doku bulanıklığını önler. Şu an malzemeler prosedürel olduğu için etkisiz; dokulu varlık gelince geçerli olur. |
| `scaling_3d/mode` / `scaling_3d/scale` | `0` / `1.0` | 3B **ekran çözünürlüğünde** render edilir; düşük çözünürlük ölçekleme yok. Varsayılan açıkça yazıldı. |

**Stretch doğrulaması:** `display/window/stretch/mode="canvas_items"` yalnız 2D/canvas
öğelerini ölçekler; 3B viewport her zaman pencere çözünürlüğünde render edilir.
`viewport_width/height=1080/1920` taban boyuttur, `--resolution 1080x1920` ile pencere
aynı boyutta açılır → 3B düşük çözünürlükte çizilmez. Değişiklik gerekmedi.

**Maliyet notu:** MSAA 2× = sahne çözünürlüğünde ek renk/depth örneği + resolve
maliyeti; mobil orta-alt segment için makul varsayılandır. MSAA 4× istendiğinde yalnız
bu değer `2` yapılır (GPU doldurma/bellek maliyeti yaklaşık ikiye katlanır).

## 2. Toon shader yumuşatma — `assets/shaders/toon.gdshader`

- `light()` içindeki keskin `step(...)` bant geçişleri `smoothstep` + `fwidth` ile
  değiştirildi. Geçişin yarım genişliği `fwidth(illumination) * band_smoothness` ile
  ekran pikseli cinsinden hesaplanır → her çözünürlükte ~1 px ince geçiş, merdiven yok.
- Yeni `band_smoothness` uniform'u (varsayılan `1.0`) geçiş inceliğini ayarlar.
- Gölge rengi (`shadow_color` = `44446b`) ve üç bant (koyu/orta/parlak) **stil A'da
  kaldı**; yalnız bant sınırları yumuşadı. Rim zaten `pow` tabanlı yumuşaktı, korundu.

**Maliyet notu:** `fwidth`/`smoothstep` sabit maliyetlidir ve `step` ile aynı sınıfta
ucuzdur; fragment başına ek doku örneği yok.

## 3. Anahat yumuşatma — `assets/shaders/outline.gdshader` + `outline.tres`

- **Ekran-sabit kalınlık:** genişlik artık kamera derinliğiyle ölçeklenir
  (`depth / reference_distance`, `reference_distance=6.0`). Böylece anahat yaklaşık
  sabit piksel kalınlığında kalır; uzakta kaybolmaz, yakında devleşmez.
- **Dikiş/kopukluk:** flat-shaded V1 modellerde (GLB'ler ve BoxMesh'ler ayrık normal
  taşır) ters-kabuk köşelerde yüz ayrışıyordu. Geometrik normal `normal_smooth=0.5`
  ile nesne-merkezli radyal yöne karıştırılır; paylaşılan köşedeki çoklu yüz normali
  tek yönde birleşir, dikiş kapanır. `0.5` ince/uzun nesnelerde (kalem) kalınlığı
  korurken kompakt nesnelerde (gövde/tekerlek/sepet) kopukluğu büyük ölçüde giderir.
- **Renk:** anahat rengi saf siyah değil koyu lacivert **#20263A** yapıldı
  (`ink_color`). `outline.tres` da aynı renge güncellendi.

> Not: `scripts/gameplay/style_a.gd` içindeki çalışma-zamanı anahat malzemesi
> (`INK_COLOR = "20283e"`, kapsam dışı) hâlâ çok yakın bir koyu laciverttir; saf siyah
> değildir. Kapsam gereği bu sabit değiştirilmedi; lider isterse tek satırla #20263A'ya
> çekilebilir.

**Maliyet notu:** vertex başına bir `normalize`/`mix` + bir `length`; önemsiz. Kabuk
ikinci geçiş olduğu için mevcut draw maliyeti değişmedi (yalnız ofset hesabı eklendi).

## 4. Gölgeler — `project.godot` + sahne ışığı

- `lights_and_shadows/directional_shadow/soft_shadow_filter_quality` masaüstü `3`
  (Soft Medium), `.mobile` `2` (Soft Low). `.mobile` varsayılanı `0` (sert) idi; telefon
  sert/merdivenli gölge üretiyordu, artık yumuşak PCF.
- Yön ışığı (`Sun`) sahnelerde zaten `shadow_blur=1.5` taşıyor; PCF ile birlikte gölge
  kenarı yumuşar. `shadow_bias`/`shadow_normal_bias` motor varsayılanlarında bırakıldı
  (acne/ayrılma gözlenmedi; değiştirmek peter-panning riski taşır).
- Gölge haritası çözünürlüğü varsayılan (4096 masaüstü / 2048 mobil) "makul" kabul
  edildi; `directional_shadow_max_distance=30` ile robot ölçeğinde yeterli.

## 5. Doğrulama

- Önce/sonra görüntüler: `docs/art/f79_before_*.png`, `docs/art/f79_after_*.png`
  (gerçek pencere, `--resolution 1080x1920`, `tools/scene_shot.gd`).
- Yakın kırpmalar 3× büyütülerek tırtığın azaldığı kontrol edildi (Pillow).
- `tools/verify.sh` yeşil; 6 korumalı probe çıkış 0 ve ölçümler aynı.
