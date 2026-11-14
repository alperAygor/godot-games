# Priz — sanat hattı (Blender → Godot) ve görünüm arayüzü

Bu belge aşama 2 görsel işinin (`p2-art`) hattını, adlandırma kurallarını ve oyun işçisinin çağıracağı
kamu fonksiyonlarını anlatır. Varlık listesi: `ASSETS.md`. Kararlar: `DECISIONS.md` → "Aşama 2 — görsel".

## 1. Yeniden üretim

```bash
tools/blender/build_all.sh            # dokular → malzemeler → oda → cihazlar → sigorta kutusu → .import (~1 dk)
tools/blender/build_all.sh --no-bake  # hızlı önizleme (AO pişirmesiz)
godot --headless --path . --import    # iki kez (ilk geçişte yeni GLB'lere bağlı .tres uyarı verebilir)
```

| Betik | Ne üretir |
|---|---|
| `tools/blender/make_textures.py` | `assets/textures/*.png` (numpy, tohumlu; Blender'ın gömülü Python'u ile çalışır, bpy gerekmez) |
| `tools/blender/priz_mats.py` | Malzeme tablosu (tek kaynak) → `assets/materials/*.tres` |
| `tools/blender/make_room.py` | `assets/models/room/room_studio.glb` |
| `tools/blender/make_appliances.py` | `assets/models/appliances/*.glb` (8 cihaz + fiş); `-- --only=fan,lamp` |
| `tools/blender/make_fusebox.py` | `assets/models/fusebox/fusebox.glb` |
| `tools/blender/write_imports.py` | Eksik `.import` dosyaları (GLB içe aktarma betiği, normal haritası sıkıştırması) |
| `tools/blender/priz_bl.py`, `priz_decor.py` | Ortak geometri (pahlı kutu, döndürme gövdesi, tüp süpürme, ızgara duvar), UV, AO pişirme, dekor üreticileri |

Dış dosya yoktur; her şey bu betiklerden üretilir. Blender 5.2, Godot 4.7.2.

## 2. Sözleşmeler

**Eksenler.** Blender Z yukarı, metre. glTF ihracı Y-yukarı yapar: `Godot (x, y, z) = Blender (x, z, -y)`.
Blender'da **-Y = ön yüz** → Godot'da **+Z = ön yüz**.

**Oda koordinatı (Godot).** İç köşe (0,0,0); arka duvar iç yüzü z=0 (x 0..5.4), sol duvar iç yüzü x=0
(z 0..4.15), duvar yüksekliği 2.7 m, zemin y=0. Kamera +x,+z çeyreğinden bakar.

**Orijinler.** Cihazlar: taban merkezi. Hareketli parçalar: dönme/kayma ekseninde (pivot).
Sigorta kutusu: duvara değen arka yüzün merkezi.

**UV.** Kutu izdüşümü dünya ölçekli (1 UV = 1 m; malzeme `tile` ile ölçeklenir). glTF V'yi ters çevirir;
el ile UV yazarken Godot'da "UV.y = 0 üst" diye düşünülüp `P.gv(v)` kullanılır (kadran, TV, pencere,
gösterge, fırın haznesi, tablolar bu yoldan geçer).

**Normaller.** Pürüzsüz gölgeleme + açıya göre keskin kenar + Ağırlıklı Normal değiştiricisi; pahlar
uygulanmış geometridir (Godot tarafında ek işlem yok).

**AO.** Cycles ile köşe rengine pişirilir (`bake_vertex_ao`); oda için duvar/zemin yoğun ızgaradır
(10 cm). Pişirmede cihazların yerine geçici kutular konur ki duvarda temas gölgesi olsun.

## 3. Malzeme hattı

1. Blender yüzeye yalnız malzeme **adı** verir (`P.mat("wood_oak")`), dokular GLB'ye gömülmez.
2. `assets/models/priz_post_import.gd` içe aktarmada her yüzeyi `res://assets/materials/<ad>.tres` ile
   değiştirir; ayrıca adı `_noshadow` ile bitenlerin gölgesini kapatır, `_shadowonly` olanları yalnız gölge yapar.
3. **Ortak "vc_*" malzemeler (çizim çağrısı):** yalnız rengi farklı malzemeler (seramikler, emayeler, kumaş
   renkleri, boyalar, krom/pirinç...) `priz_mats.VC_MEMBERS` ile ortak malzemeye toplanır; renk
   (doğrusal) × AO köşe rengine yazılır (`P.collapse_materials`). Yeni bir renk eklemek: `MATERIALS`'a
   `albedo` ile ekle, uygun gruba yaz — Godot tarafında dosya gerekmez.
4. Yeni doku seti: `make_textures.py` içinde `save_set(ad, albedo, height, …)` → `<ad>_albedo/_normal/_orm.png`,
   `MATERIALS`'a `tex="<ad>"` ile ekle.
5. Doku içe aktarma: VRAM sıkıştırma + mipmap; `_normal` dosyaları normal haritası modunda;
   `noise_rgba`, `city_masks`, `dial_albedo` kayıpsız.

## 4. Adlandırma

### Oda (`room_studio.glb`)

| Düğüm | Tür | Anlam |
|---|---|---|
| `Socket_01` … `Socket_07` | Node3D (boş) | Priz yeri, duvar yüzünde. **Yerel +Z duvardan dışarı** (fişin geldiği yön). Fiş dönüşümü = priz dönüşümü → pimler duvara girer. |
| `SocketMarkers` | Mesh | Tüm prizlerin hat şekil işaretleri (tek ağ). Priz/hat kimliği köşe renginde. |
| `Cables_noshadow` | Mesh | Üç hattın duvar kabloları (tek ağ). Hat kimliği köşe renginde. |
| `Anchor_Fridge`, `_Oven`, `_Washer`, `_Kettle`, `_Toaster`, `_TV`, `_Fan`, `_Lamp` | Node3D | Cihaz yerleri (taban merkezi; yerel +Z cihazın ön yüzü). Cihazın `global_transform`'u buna eşitlenir. |
| `Anchor_FuseBox` | Node3D | Sigorta kutusu yeri (duvar yüzü, +Z dışarı). |
| `LightAnchor_Kitchen`, `LightAnchor_Hood` | Node3D | İç mekân ışık yerleri (RoomView ışık ekler). |
| `WindowView_noshadow`, `WindowGlass_noshadow`, `KitchenStrip_noshadow`, `ShadowBox_shadowonly`, `Decor` | Mesh | Manzara, cam, raf altı şerit, görünmez gölge kutusu, durağan her şey. |

Priz → hat: `Socket_01, 02` → hat 1 (kırmızı, daire) · `Socket_03, 06, 07` → hat 2 (mavi, üçgen) ·
`Socket_04, 05` → hat 3 (sarı, kare). Hat 4 (mor, elmas) yalnız sigorta kutusunda hazır.

### Cihazlar (`appliances/*.glb`)

Hepsinde `Body` (durağan gövde) ve `PlugAnchor` (kablonun çıktığı nokta) var.

| Cihaz | Hareketli/efekt düğümleri (Godot ekseni) |
|---|---|
| fridge | `Indicator` |
| oven | `Interior` (fx_oven_glow), `Glass`, `Knob_L` / `Knob_R` (yerel Z'de döner), `Indicator`, `LightAnchor` |
| washer | `Drum` (yerel Z'de döner; çamaşırlar içinde), `Glass`, `Dial` (yerel Z), `Indicator` |
| kettle | `Indicator`, `SteamAnchor` |
| toaster | `Coils` (fx_coil), `Toast` ve `Lever` (yerel Y'de aşağı kayar), `Knob` |
| tv | `Screen` (fx_tv_screen), `Indicator`, `LightAnchor` |
| fan | `Head` (yerel Y'de salınır) → `Blades` (yerel Z'de döner), `BladeBlur_noshadow` |
| lamp | `Shade` (fx_lamp_shade), `Bulb` (fx_bulb), `LightAnchor` |
| plug | `Body`, `CableAnchor` (kablo ucu, arka), `PinTip`; pimler yerel **-Z** yönünde |

### Sigorta kutusu (`fusebox.glb`)

`Body`, `Dial` + `DialGlass_noshadow`, `DialNeedle` (yerel Z), `Module_1..4` (levha + gösterge çerçevesi +
şalter gövdesi) → çocukları `Gauge_N` (fx_gauge) ve `Breaker_N` (yerel X; yukarı = açık), `MainLever` (yerel X).

## 5. Kamu arayüzü (oyun işçisi bunları çağırır)

Tüm betikler tipli GDScript, `class_name` ile kayıtlı.

### `RoomView` — `scripts/lookdev/room_view.gd` (Node3D)
Ortam, güneş + dolgu ışığı, yansıma sondası, kamera, gün ışığı yöneticisi ve odayı kurar.
```
get_socket(id: String) -> Node3D          # "Socket_01"..
get_socket_ids() -> PackedStringArray
line_of_socket(id: String) -> int         # 1..3
get_anchor(name: String) -> Node3D        # "Anchor_Fridge" .. "Anchor_FuseBox", "LightAnchor_*"
place_at_anchor(node: Node3D, anchor: String)
set_line_glow(line: int, glow: float)     # 0 sönük, 1 akım akıyor, 2+ sınırda (daha parlak)
set_line_highlight(line: int, v: float)   # dokununca hattın kablosu + prizleri parlar
set_line_dim(line: int, v: float)         # sürüklemede takılamayan hat solar
set_socket_highlight(id: String, v: float)
set_socket_dim(id: String, v: float)
set_quality(tier: int)                    # QualityTiers.Tier.LOW/MEDIUM/HIGH
day_light: DayLight ; camera_rig: DioramaCamera ; environment ; sun ; appliances_root
```

### `DayLight` — `scripts/lookdev/day_light.gd`
```
set_slice(slice: int, duration: float = 1.6)   # 0 sabah, 1 öğle, 2 akşam, 3 gece; 0 = anında
flicker(strength: float, duration: float = 1.2) # sınıra yaklaşan hat: iç lambalar titrer
blackout(recover_after: float = 1.4)           # sigorta attı: anlık karanlık → titreyerek dönüş
play_win(duration: float = 3.6)                # gece; ışıklar tek tek yanar; kamera geri çekilir
skip_win()                                     # dokununca sona atla
signals: slice_changed(slice), blackout_finished, win_finished
```
Karartma, `"priz_mains"` grubundaki her düğüme `set_mains(factor)` yollar (tüm `Appliance`'lar bu grupta).

### `DioramaCamera` — `scripts/lookdev/diorama_camera.gd`
```
set_parallax(v: Vector2)   # v ∈ [-1,1]²: ±4° yaw, ±2.5° pitch, yumuşatılmış (kamera odak etrafında döner)
pull_back(duration) / finish_pull_back() / reset_view()
frame_focus(point, dist, yaw, pitch)   # yakın plan (görünüm aracı)
set_dof(far_on, near_on)               # kalite kademesi çağırır
```
Kadraj: dikey ekran, diorama üst ~2/3'te (`screen_offset`), `KEEP_WIDTH` ile yatay kadraj sabit.

### `Appliance` (taban) — `scripts/fx/appliance.gd`
Alt sınıflar: `FridgeFx`, `OvenFx`, `WasherFx`, `KettleFx`, `ToasterFx`, `TvFx`, `FanFx`, `LampFx`
(`scripts/fx/*_fx.gd`; her biri kendi GLB'sini yükler).
```
var fan: FanFx = FanFx.new(); room_view.place_at_anchor(fan, "Anchor_Fan")
set_running(on: bool, ramp: float = -1.0)   # yumuşak rampa (fırın ~3 sn ısınır, lamba 0.3 sn)
is_running() -> bool ; get_level() -> float ; get_plug_anchor() -> Node3D
set_mains(factor: float)                    # karartma
signal running_changed(on)
```
Çalışırken: fırın içi kızarır + turuncu ışık, tambur döner (ileri/durak/geri) + gövde titrer, buhar,
TV sahneleri + renkli oda ışığı, vantilatör döner + salınır, abajur yanar, buzdolabı LED + uğultu titremesi,
ekmek kızartma telleri kızarır + kol/ekmek iner (kapanınca fırlar).

### `FuseBox` — `scripts/fx/fuse_box.gd`
```
set_line_count(n)                    # 2..4 modül görünür, ortalanır
set_line_capacity(line, blocks)      # gösterge blok sayısı = hat kapasitesi
set_line_fill(line, ratio)           # yük/kapasite; >1 taşma (kırmızı yanıp söner); yumuşak dolar
set_breaker(line, on) ; trip(line)   # kol çevrilir; trip kutuyu sarsar
set_line_highlight(line, v)
set_main_lever(on, animate := true)  # "günü başlat"; signal main_lever_changed(on)
set_slice_dial(slice, duration)      # sabah sol, öğle üst, akşam sağ, gece alt
```
Rakam yok: yük = yanan blok sayısı; sınıra yakın üst blok turuncu, taşma kırmızı.

### `PlugCable` — `scripts/fx/plug_cable.gd` (MeshInstance3D)
```
start_node / end_node: Node3D   # örn. cihaz PlugAnchor → fiş CableAnchor
set_endpoints(a, b) ; snap_to_rest() ; slack ; segments (20) ; sides (8) ; floor_y
```
Verlet ip (20 parça, 10 iterasyon, zemin teması) + her karede yeniden kurulan pürüzsüz tüp (320 üçgen).

### `QualityTiers` — `scripts/lookdev/quality.gd`
| | HIGH | MEDIUM | LOW |
|---|---|---|---|
| Alan derinliği | ön + arka (orta kalite) | yalnız arka (düşük) | kapalı |
| Parlama | açık | açık | kapalı |
| Güneş gölgesi | 4096, yumuşak orta | 2048, yumuşak düşük | 1024, sert |
| Işık hüzmeleri | açık | açık | kapalı |
| Kenar yumuşatma | MSAA 4x | MSAA 2x | FXAA |
| Yansıma sondası | açık | açık | kapalı |
Bütçeyi aşan efekt kapatılır; yerine ucuz taklit konmaz.

## 6. Görünüm sahnesi ve çekim aracı

- `scenes/lookdev/Lookdev.tscn` — kendi kendine oynar (36 sn döngü: dilimler, cihazlar, titreme, sigorta
  atması, kazanma). Klavye: `1-4` dilim, `A` cihazlar, `F` titreme, `B` karartma, `W` kazanma, `Q` kalite;
  fare = paralaks.
- `tools/lookdev_shot.gd` (gerçek pencere ister; sert zaman aşımıyla çalıştır):
  ```
  godot --path . -s res://tools/lookdev_shot.gd -- --out=build/shots          # hepsi + perf + temas kâğıdı
  godot --path . -s res://tools/lookdev_shot.gd -- --only=slices|closeups|events|perf|fusebox
  godot --path . -s res://tools/lookdev_shot.gd -- --quality=low
  godot --headless --path . -s res://tools/lookdev_shot.gd -- --check        # başsız API dumanı → SONUC: gecti
  ```
  Bitince `LOOKDEV_DONE` basar (macOS'ta Metal kapanışı bazen asılır; çağıran süreç bu satırı görünce
  kendi PID'ini öldürmelidir). İç çizim 1080x1920 sabit.

## 7. Ölçülen bütçeler (masaüstü, Apple M4, Metal, Mobile çizici, 1080x1920 iç çözünürlük)

| Ölçü | Değer | Hedef |
|---|---|---|
| Kaynak üçgen (görünüm sahnesi) | ≈ 154 k (oda 108 k + cihazlar 35 k + sigorta 8.7 k + fiş 1.2 k + kablo 0.3 k) | ≤ ~150 k |
| Karede çizilen ilkel (ana + gölge geçişi, otomatik LOD sonrası) | ≈ 290 k | — |
| Çizim çağrısı (kare toplamı, gölge geçişi dahil, gece, tüm cihazlar açık) | 100 | ≤ ~80 (aşıldı, bkz. §8) |
| GLB yüzeyleri (malzeme birleştirme sonrası) | 108 (önce 194) | — |
| Doku GPU belleği (ETC2/S3TC + mipmap, kayıpsız maskeler dahil) | ≈ 22 MB | — |
| Varlık dosya boyutu | GLB 9.1 MB + PNG 16 MB | < 40 MB |
| Kare süresi (HIGH, dikey eşitleme kapalı) | 7–8 ms (≥120 fps; MEDIUM/LOW ≥120 fps) | 60 fps orta Android |
| Gerçek zamanlı ışık | 1 gölgeli yönlü (güneş) + 1 gölgesiz yönlü (dolgu) + en çok 7 gölgesiz omni/spot | Mobile: ağ başına ≤ 8 omni |

Masaüstü M4 bu sahnede dikey eşitleme sınırına dayanır; kademeler arası fark ölçülemiyor. Gerçek ölçüm
orta sınıf Android'de (aşama 6). Motorun bildirdiği "doku belleği" (~435 MB) çizim hedeflerini, gölge
atlasını, parlama/DoF tamponlarını ve MSAA'yı içerir; varlık dokuları ≈ 22 MB'tır.

## 8. Bilinen zayıf noktalar

- **Çizim çağrısı 100** (hedef ~80): oda tek ağ ama 30 malzeme yüzeyi; cihazlar ve sigorta kutusu kendi
  parçalarıyla. Sonraki adım: kumaş/ahşap dokularını tek atlasa almak, sigorta kutusu modüllerini kademe
  başına birleştirmek.
- **Işık hüzmeleri** sahte hacimdir (Mobile'da hacimsel sis yok): sabahleyin mutfak önünde hafif "cam levha"
  hissi verebilir; şiddeti düşük tutuldu, LOW kademesinde kapalı.
- **Dolgu ışığı + sabit ortam rengi**: gerçek GI yok; öğle dilimi gece/akşama göre daha düz. Güneş lekesi
  için sekme ışığı (gölgesiz omni) eklendi.
- **Yakın planda** zemin tahtası normal haritası iri görünür; dokular oyun uzaklığına göre ayarlı.
- **Vantilatör** oda ölçeğinde ince kalıyor; puf ve sandalyeler sade.
- Kablo kroşeleri ve priz sayısı oda düzenine sabit (veri odaklı değil): başka oda = `make_room.py`'de yeni
  `SOCKETS`/`LINES` tablosu.
- Yansıma sondası bir kez yakalanır (öğle); gece metal/cam yansımaları biraz aydınlık kalır (yoğunluk düşük).
- Fiş oturma "tık + toz" efekti, sürükle-bırak ve mıknatıs bu işte yok (`p2-slice`).

## 9. `project.godot`

Bu işte **değiştirilmedi**. Kalite ayarları (gölge atlası, yumuşak gölge kalitesi, DoF kalitesi, MSAA)
çalışma anında `RenderingServer`/`Viewport` üzerinden `QualityTiers.apply` ile verilir.
