# Priz — varlık listesi

Her varlık: ad, boyut/bütçe, stil tarifi, kullanıldığı yer, kaynak (hangi betik üretti).
Tümü projede üretilir; dış kaynak yoktur. İşçiler ürettikçe bu dosyayı doldurur.
Yeniden üretim: `tools/blender/build_all.sh` (ayrıntı: `docs/ART_PIPELINE.md`).

Ortak stil: "sıcak minyatür diorama" — pahlı/yumuşak kenarlar, gerçek oranlar (metre), ağırlıklı
normaller, köşe rengine pişmiş ortam örtmesi (AO), malzemeler ad ile `assets/materials/*.tres`'e bağlanır.

## Modeller (GLB)

| Ad | Tür | Bütçe (üçgen / dosya) | Stil | Kullanıldığı yer | Kaynak |
|---|---|---|---|---|---|
| `assets/models/room/room_studio.glb` | Oda dioraması | 108 k / 6.4 MB | Kesitli stüdyo daire: mutfak köşesi (adaçayı dolaplar, meşe tezgah, metro karo, açık raflar, davlumbaz, lavabo), oturma köşesi (petrol mavisi kanepe, kilim, orta sehpa, puf, TV ünitesi, tablolar), yemek köşesi, lambri, kapı, perdeli pencere + manzara, 7 priz, 3 hat kablosu, bitkiler, kitaplar | Oyun odası, görünüm sahnesi | `tools/blender/make_room.py` |
| `assets/models/appliances/fridge.glb` | Cihaz | 5.1 k / 287 KB | Retro krem buzdolabı, krom kulplar, ızgara, gösterge | Mutfak | `make_appliances.py` |
| `assets/models/appliances/oven.glb` | Cihaz | 5.2 k / 297 KB | Ankastre fırın: siyah cam kapak, pencere, iç hazne + kek, paslanmaz panel, iki düğme | Mutfak | `make_appliances.py` |
| `assets/models/appliances/washer.glb` | Cihaz | 6.2 k / 392 KB | Önden yüklemeli beyaz çamaşır makinesi, krom kapak halkası, cam, dönen tambur + çamaşırlar | Mutfak | `make_appliances.py` |
| `assets/models/appliances/kettle.glb` | Cihaz | 3.8 k / 207 KB | Nane yeşili emaye su ısıtıcı, krom kapak/bant, siyah taban ve kulp | Tezgah | `make_appliances.py` |
| `assets/models/appliances/toaster.glb` | Cihaz | 3.7 k / 213 KB | Kırmızı emaye retro ekmek kızartma, iki yuva, ısıtıcı teller, ekmek dilimleri, kol | Tezgah | `make_appliances.py` |
| `assets/models/appliances/tv.glb` | Cihaz | 1.6 k / 72 KB | İnce çerçeveli TV, oval ayak | TV ünitesi | `make_appliances.py` |
| `assets/models/appliances/fan.glb` | Cihaz | 6.9 k / 462 KB | Krem ayaklı vantilatör, krom kafes, üç nane kanat, salınan kafa | Oturma köşesi | `make_appliances.py` |
| `assets/models/appliances/lamp.glb` | Cihaz | 2.7 k / 155 KB | Hardal seramik gövdeli abajur, keten abajur, pirinç iskelet | Yan sehpa | `make_appliances.py` |
| `assets/models/appliances/plug.glb` | Fiş | 1.2 k / 65 KB | Beyaz Schuko fiş (%30 minyatür abartısı), krom pimler | Sürüklenen fiş | `make_appliances.py` |
| `assets/models/fusebox/fusebox.glb` | Dünya içi arayüz | 8.7 k / 553 KB | Krem emaye kutu, gömme grafit panel, gün dilimi kadranı, 4 hat modülü (şekil levhası + blok gösterge + şalter), kırmızı tutamaklı bıçaklı ana şalter | Sol duvar / alt tepsi | `make_fusebox.py` |

Görünüm sahnesindeki toplam: ≈ 154 k üçgen (oda + 8 cihaz + fiş + sigorta kutusu + fiziksel kablo).

## Dokular (`assets/textures/`, prosedürel numpy, `make_textures.py`)

İçe aktarma: VRAM sıkıştırmalı + mipmap (Android'de ETC2/ASTC); maske/gürültü/kadran kayıpsız.
Toplam GPU belleği ≈ 18 MB (sıkıştırılmış, mipmap dahil) + ≈ 4.5 MB kayıpsız ≈ **22 MB**. PNG kaynak 16 MB.

| Ad | Boyut | Stil | Kullanıldığı yer |
|---|---|---|---|
| `wood_oak_*` (albedo/normal/orm) | 1024² | Açık meşe, halka + gözenek | Tezgah, raflar, masa, sehpa |
| `wood_walnut_*` | 1024² | Koyu ceviz | TV ünitesi, kanepe kasası, ayaklar, tablo çerçevesi |
| `floor_planks_*` | 1024² (2.6 m döşeme) | Karışık boylu tahta döşeme, pah derzleri | Zemin |
| `fabric_*` | 512² | Bez ayağı dokuma, gri (köşe rengiyle renklenir) | Kanepe, kırlent, havlu, paspas, hasır (ölçekli) |
| `linen_*` | 512² | Seyrek keten | Perde, abajur |
| `rug_kilim_*` | 1024² | Basamaklı kilim (göbek, bordür, abrash) | Halı |
| `plaster_*` | 512² | İnce sıva | Duvarlar, kesit yüzü, terakota |
| `wallpaper_*` | 512² | Sanat-deko yelpaze motifi | Oturma köşesi duvarı |
| `tiles_*` | 512² | Metro karo, sır havuzlanması, derz | Mutfak tezgah arası |
| `brushed_*` | 512² | Fırçalanmış çelik | Davlumbaz, lavabo, fırın paneli, metal ortak malzeme normali |
| `peel_normal/orm` | 256² | Portakal kabuğu boya | Emaye/plastik ortak malzeme |
| `paintwood_normal/orm` | 512² | Boya altından lif | Kapı, pencere, süpürgelik, lambri, dolap kapakları |
| `leather_*` | 512² | Deri gözenek/kırışık | Puf |
| `leaf_*` | 256² | Damarlı yaprak | Tüm bitkiler |
| `soil_*` | 256² | Toprak | Saksılar |
| `books_albedo` | 512² | 12 kitap sırtı + sayfa kenarı (yazısız) | Kitaplar |
| `art_albedo` | 1024² | 2×2 tablo atlası (gün batımı, soyut, botanik, deniz; yazısız) | Tablolar, TV ekran içeriği |
| `city_masks` | 1024×512 RGBA | R uzak silüet, G yakın binalar, B pencere ışıkları, A ağaçlar | Pencere manzarası |
| `dial_albedo` | 512² | Dört dilim kadranı (piktogram, rakamsız) | Sigorta kutusu |
| `noise_rgba` | 256² | Tekrarlanan gürültü | Buhar, hüzme, bulut, ısıtıcı titreşimi |

## Malzemeler (`assets/materials/*.tres`, `priz_mats.py`)

41 malzeme dosyası: doku setli PBR (ORM), cam/özel malzemeler ve çizim çağrısını azaltan 8 ortak "vc_*"
malzeme (`vc_plaster`, `vc_paint`, `vc_fabric`, `vc_peel`, `vc_gloss`, `vc_matte`, `vc_metal`, `vc_leaf`).
Tabloda 50'yi aşkın renk tanımı (seramikler, emayeler, kumaşlar, boyalar, meyveler...) Blender'da kaynak
olarak durur; rengi köşe rengine pişip ortak malzemeye toplandığı için ayrı .tres dosyası yoktur.
Efekt malzemeleri `fx_*` (gölgelendirici ya da emisyonlu).

## Gölgelendiriciler (`assets/shaders/`)

| Ad | Ne yapar |
|---|---|
| `cable_lines` | Tüm hat kabloları tek ağ; hat başına renk, akım parlaması (akan dalga), vurgu, solukluk (dizi parametreleri) |
| `socket_marker` | Tüm priz işaretleri tek ağ; priz başına vurgu/solukluk |
| `fuse_gauge` | Rakamsız blok gösterge: dolum, kapasite = blok sayısı, sınırda turuncu, taşmada kırmızı yanıp sönme |
| `oven_glow` | Fırın haznesi ısınma ışıması |
| `heat_coil` | Kara cisim renkli ısıtıcı tel |
| `tv_screen` | Tablo atlasından kayan/karışan sahneler, satır deseni, açılış |
| `window_sky` | Pencere manzarası: gökyüzü, güneş/ay, bulut, yıldız, bina ve pencere ışıkları (dilim renkleri) |
| `backdrop_sky` | Diorama arka fonu degradesi (gökyüzü kaynağı; yumuşak yansıma) |
| `light_shaft` | Pencere ışık hüzmesi (toz zerrecikli, yüzeyde sönen) |
| `steam` | Buhar pufu (billboard, gürültüyle aşınan) |
| `fan_blur` | Vantilatör hareket bulanıklığı diski |

## Henüz olmayanlar (sonraki aşamalar)

- Başka odalar/daireler (aynı hat ve modül kitaplığıyla üretilebilir), mahalle gece manzarası.
- Çoklu priz (uzatma) modeli, topraklı priz farkı, güneş paneli, zamanlayıcılı priz.
- Toz parçacığı / fiş oturma "tık" efekti (FX kancası `p2-slice` işinde).
