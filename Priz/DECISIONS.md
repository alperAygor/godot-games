# Priz — kararlar, varsayımlar, ertelenenler

Her aşamada buraya eklenir. Biçim: tarih, karar, neden, geri dönüş yolu.

## Aşama 0 (2026-11-14) — kuruluş

- **Motor ve çizici:** Godot 4.7.2, gerçek 3B, **Mobile** çizici. Neden: tasarım alan derinliği, parlama
  ve yumuşak gölge istiyor; Compatibility çizicide alan derinliği yok. Risk: orta sınıf Android'de 60 FPS.
  Geri dönüş: kalite kademeleri (alan derinliği ve parlama kapatılabilir, gölge çözünürlüğü düşer).
- **Varlıklar:** tümü Blender 5.2 betikleriyle üretilir (`tools/blender/`), GLB olarak dışa aktarılır.
  Dışarıdan model ya da doku indirilmez. Sesler ElevenLabs ile.
- **Ekran:** dikey 1080x1920; diorama ekranın üst ~2/3'ünde, cihaz tepsisi ve sigorta kutusu başparmak
  bölgesinde.
- **"Rakam yok" kuralının kapsamı (AÇIK SORU):** oyun ekranında kesin olarak uygulanır. Meta ekranlardaki
  jeton bakiyesi ve fiyatların nasıl gösterileceği aşama 5'e ertelendi; o zamana dek varsayım: jeton da
  görsel yığın/kese olarak gösterilir, sayı yazılmaz. Kullanıcıya dikey kesit gösterilirken sorulacak.
- **Seviye 1-14 ("düz" kip):** gün döngüsü yok, tüm cihazlar aynı anda çalışır, sigorta hakkı yok; hattı
  taşıracak cihaz prize oturmaz (geri sektirilir). Seviye, tüm cihazlar takılınca kazanılır.
- **Seviye 15+ ("gün" kipi):** planlamada taşma engellenmez; oyuncu "Günü başlat"a basar, dilimler
  sırayla oynar. İlk taşan dilimde sigorta atar, bir hak gider, plana dönülür (plan korunur).
  Kazanmak için tüm cihazların takılı olması gerekir (aksi hâlde "Günü başlat" etkin olmaz).
- **Çoklu priz (seviye 10):** tek bir priz noktasına birden çok cihaz takılabilen uzatma; hepsi aynı hatta
  yük bindirir.
- **Oda kısıtı (seviye 6):** cihaz yalnız kendi odasındaki prizlere takılabilir.
- **Zor seviye:** her 5. seviye (5, 10, 15, ...) zordur; çözüm sayısı hedefi daha düşüktür, ödül fazladır.
- **Şablon:** oyundan bağımsız altyapı (kayıt, reklam, dil, arayüz takımı) `studio-kit/template-mobile`
  hazır olunca aşama 2-3'te projeye taşınır; çekirdek ve görsel işler bunu beklemez.

## Aşama 2 — görsel (2026-11-14, `p2-art`)

- **Malzeme ad ile taşınır, doku GLB'ye gömülmez.** Blender yüzeye malzeme adı verir; Godot içe aktarma
  betiği (`assets/models/priz_post_import.gd`) yüzeyi `assets/materials/<ad>.tres` ile değiştirir. Neden:
  dokular tek kopya, malzemeler tüm modellerde ortak, ayar Godot'da tek dosyada. Geri dönüş: GLB'ye doku
  gömmek için `export_image_format="AUTO"` ve Blender'da doku düğümleri.
- **Prosedürel Blender malzemesi pişirilmez; dokular doğrudan numpy ile üretilir** (`make_textures.py`).
  Neden: hızlı, tohumlu, tekrarlanabilir ve kusursuz döşenir. Pişirme yalnız AO için (Cycles → köşe rengi).
- **Ortam örtmesi köşe rengine pişer** (Mobile çizicide SSAO yok). Duvar/zemin AO için 10 cm ızgaradır.
  Cihazların yerine geçici kutular konarak duvarda temas gölgesi alınır.
- **Renk-yalnız malzemeler ortak "vc_*" malzemelere toplanır** (renk × AO köşe renginde). Neden: çizim
  çağrısı 194 → 108 yüzey. Bedel: bu yüzeylerde malzeme başına normal haritası farkı yok (küçük nesneler).
- **Görünmez gölge kutusu:** tavan, ön ve sağ duvar yalnız gölge atar (`ShadowBox_shadowonly`). Neden:
  güneş yalnız pencereden girsin, sabah/akşam uzun ışık lekeleri ve pencere kayıtlarının gölgesi oluşsun.
  Öğle lekesi için gölgesiz bir "sekme" omni ışığı lekenin üstünü izler.
- **Hacimsel sis yerine ışık hüzmesi kabuğu** (`light_shafts.gd` + `light_shaft.gdshader`): zemine/oda
  kenarına kırpılmış, kenarları yumuşak, toz zerrecikli, düşük şiddet. LOW kademesinde kapalı.
- **Paralaks kamerayı döndürür, dioramayı değil.** Ekranda aynı görünür; gölgeler güneşe göre sabit kalır.
- **Kablolar ve priz işaretleri tek ağ + dizi parametreli gölgelendirici.** Hat/priz kimliği köşe rengi
  (FLOAT) ile kodlanır; hat başına parlama/vurgu/solukluk tek malzemeden sürülür (3 + 7 çizim yerine 2).
- **Renk körlüğü:** hat 1 kırmızı/daire, 2 mavi/üçgen, 3 sarı/kare, 4 mor/elmas — prizde, sigorta kutusu
  levhasında ve şalter kolunda aynı. Kablo kılıfı da hat renginde.
- **Sigorta göstergesi = blok dizisi** (tüp/ibre yerine). Neden: tasarım kapasiteyi "blok" ile anlatıyor;
  telefonda sayılabilir, rakamsız. Blok sayısı = hat kapasitesi (gölgelendirici parametresi).
- **Minyatür abartısı:** prizler ve fiş %30 büyük, hat kabloları 14 mm çaplı (gerçekte ~8 mm) — telefonda
  okunurluk için. Odanın geri kalanı gerçek ölçüdedir.
- **Kalite kademeleri tek yerde** (`QualityTiers`): DoF, parlama, gölge atlası/filtresi, hüzmeler, MSAA,
  yansıma sondası. `project.godot` değiştirilmedi; ayarlar çalışma anında verilir.
- **Ertelenen (görsel):** çizim çağrısını ~80'e indirmek için doku atlası; fiş oturma toz/tık efekti
  (`p2-slice`); başka oda düzenleri için veri odaklı priz/hat tablosu; gerçek cihazda performans ölçümü.

## Ertelenenler

- Gerçek cihazda performans ölçümü (aşama 6; o zamana dek masaüstü ölçümleri yalnız oran verir).
- Gerçek reklam SDK'sı (sahte servisle çalışılır; AdMob aşama 6).
