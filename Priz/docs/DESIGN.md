<!-- Kullanıcının verdiği tasarım belgesi; aynen korunur, değiştirilmez. -->

# GÖREV: "Priz" adlı mobil bulmaca oyununu geliştir

## Rolün ve bağlam
Sen bu projenin baş geliştiricisi ve teknik sanat yönetmenisin. Tek kişilik bir
stüdyo için, Android'de yayınlanacak, reklam gelirli bir hybrid-casual bulmaca
oyunu yapıyorsun. Hedef kitle sıradan mobil oyuncu: oyunu sessiz bir ortamda,
tek elle, 1-3 dakikalık oturumlarla oynar. Oyunun başarısı iki şeye bağlı:
(1) ilk 10 saniyede "bu çok tatmin edici" dedirten görsel-işitsel his,
(2) oyuncuyu günlerce geri getiren ilerleme katmanı. Kararsız kaldığın her
yerde bu ikisini önceliklendir.

## Oyunun özü
Oyuncu bir dairenin elektrik planını yapar. Cihazları prizlere takar. Her priz
bir hatta bağlıdır, her hattın taşıyabileceği yük sınırlıdır. Plan hazır olunca
oyuncu günü başlatır: cihazlar saatine göre açılıp kapanır. Hiçbir hat taşmazsa
daire aydınlanır ve seviye kazanılır.

## Kurallar
- Dairede 2-4 hat vardır. Her hattın bir rengi, bir şekli (renk körlüğü için)
  ve blok cinsinden bir kapasitesi vardır (ör. 6 blok).
- Her priz tek bir hatta bağlıdır. Bir hat birden fazla odaya uzanabilir.
- Her cihazın yükü (1-5 blok), ait olduğu oda ve çalıştığı gün dilimleri vardır.
- Gün 4 dilimdir: sabah, öğle, akşam, gece.
- Bir hattın bir dilimdeki yükü, o dilimde çalışan takılı cihazların toplamıdır.
- Oyuncu "Günü başlat"a basınca dilimler sırayla oynatılır. Bir dilimde bir hat
  kapasiteyi aşarsa sigorta atar, oyuncu 3 sigorta hakkından birini kaybeder ve
  plana döner. Planı silinmez.
- 3 hak biterse seviye kaybedilir. Tüm dilimler sorunsuz geçerse kazanılır.
- Ekranda hiçbir yerde rakam gösterme. Yük ve kapasite her zaman blok, dolan
  tüp veya ibre gibi görsel öğelerle anlatılır. Oyun matematik sorusu gibi
  hissettirmemeli.
- Seviye 1-14: gün döngüsü yok, tüm cihazlar aynı anda çalışır, sigorta hakkı
  yok, taşan cihaz prize oturmaz. Seviye 15'ten itibaren gün döngüsü ve test.

## İçerik öğeleri (sırayla açılır)
Oda kısıtı (6), çoklu priz (10), gün döngüsü (15), düşük kapasiteli eski kablo
(25), topraklı priz zorunluluğu (35), öğlen ek kapasite veren güneş paneli (50),
yükü dilime göre değişen komşu hattı (65), cihazın dilimini kaydıran
zamanlayıcılı priz (80), belirli dilimde kapalı hat (95). Her öğeyi veri
odaklı tasarla; yeni öğe eklemek yeni bir kaynak dosyası kadar kolay olmalı.

## Görsel yön (en önemli bölüm)
Low-poly, düz renkli veya prototip görünümlü bir oyun İSTEMİYORUM.
Hedef: "sıcak minyatür diorama". Kesiti alınmış, bebek evi gibi görünen,
zengin detaylı bir daire.
- Modeller: yumuşatılmış kenarlar, gerçekçi oranlar, ahşap, kumaş, metal, cam
  gibi ayırt edilebilir malzemeler. Mobilya, halı, perde, bitki, raf gibi
  dekorla dolu odalar.
- Işık oyunun yıldızıdır. Dört dilimin her birinin kendi ışık atmosferi olsun:
  sabah pencereden giren serin gün ışığı, öğle parlak, akşam altın sarısı,
  gece koyu mavi ve içeride sıcak lamba ışıkları. Dilimler arası geçiş yumuşak
  olsun.
- Çalışan her cihaz ışık ve hareket üretir: fırının içi kızarır, çamaşır
  makinesinin tamburu döner, çaydanlıktan buhar çıkar, televizyon ekranı
  odaya renkli ışık yansıtır, vantilatör döner, abajur yanar.
- Kablolar fiziksel: fiş sürüklenirken kablo sarkar ve sallanır, duvardaki
  hat kabloları akım geçtikçe hafifçe parlar.
- Minyatür hissi için alan derinliği, hafif parlama ve yumuşak gölge kullan;
  performans bütçesini aşan efekti kapat, görünümü bozan ucuz taklitle
  doldurma.
- Arayüz de aynı dünyaya ait olsun: hat sayaçları gerçek bir sigorta kutusu,
  düğmeler şalter ve anahtar gibi görünür ve fiziksel tepki verir.

## His ve ASMR
- Fiş prize yaklaşınca mıknatıs gibi çekilir ve net bir "tık" ile oturur;
  küçük bir sarsıntı, toz parçacığı ve hafif titreşim eşlik eder.
- Ses katmanlıdır: her cihazın kendi döngü sesi vardır (buzdolabı uğultusu,
  tambur, fokurdama). Cihazlar açıldıkça ev sesleri üst üste biner.
- Hat doldukça elektrik uğultusunun perdesi yükselir, sınıra yaklaşınca
  lambalar titrer.
- Sigorta atması: sert bir "çat", anlık karanlık, sönen cihaz sesleri, sonra
  sessizlik. Rahatsız edici değil, dramatik olmalı.
- Kazanma: gece diliminde pencereler ve lambalar tek tek yanar, kamera yavaşça
  geri çekilir, müzik yükselir. Bu sahne oyunun ödülüdür, 3-4 saniye sürsün ve
  dokununca atlanabilsin.
- Her dokunuş 100 ms içinde görsel ve işitsel karşılık versin.

## Kontroller
- Tek parmak. Cihazı tepsiden sürükle, prize bırak. Tutulan cihazın
  takılabileceği prizler parlar, diğerleri solar.
- Takılı cihaza dokununca tepsiye döner. Planlama aşamasında her şey sınırsız
  geri alınabilir.
- Bir prize dokununca o hattın tüm prizleri, kablosu ve sayacı birlikte parlar.
- Dokunma alanları en az 48x48 dp. Tek elle, başparmakla oynanabilmeli.
- Parmağı hafif kaydırınca diorama birkaç derece döner (paralaks). Sadece
  görsel zenginlik içindir, oynanışı etkilemez.

## Oyuncuyu tutan katman
- Mahalle: her seviye bir dairedir. Tamamlanan dairelerin pencereleri ana
  ekrandaki gece mahalle manzarasında yanar. Bina bitince sokak lambaları ve
  yeni bina açılır.
- Yenileme: seviyelerden kazanılan yıldızlarla bina cephesi, bahçe ve çatı
  yenilenir; her adımda 3 görünüm seçeneği.
- Cihaz kataloğu: yeni ve nadir (eski tip) cihazlar koleksiyona eklenir.
- Galibiyet serisi, 7 günlük giriş ödülü, her gün yenilenen tek bir "günün
  dairesi" seviyesi.
- 4 normal seviyeden sonra 1 zor seviye gelir; zor seviye fazla ödül verir.

## Reklam ve gelir noktaları (sahte servisle çalışsın)
- Ödüllü: sigortalar bitince +1 hak, seviye sonu jetonu ikiye katlama, ipucu
  (bir cihazın doğru prizi), gün önizleme (dilimleri elle gezme), yenileme
  parçasını erken açma.
- Geçiş reklamı: seviye 5'ten sonra, 2-3 seviyede bir, en az 90 sn arayla,
  sadece seviye geçişinde. Ödüllü reklam izlenen geçişte gösterme.
- Banner sadece mahalle ve koleksiyon ekranında. Oyun ekranında asla.
- İlk 3 seviyede reklam, mağaza veya açılır pencere yok.

## Seviye üretimi
Seviyeleri veri dosyası olarak tut. Bir üretici ve bir çözücü yaz:
üretici önce geçerli bir çözüm kurar, sonra boş kapasiteyi zorluk hedefine
göre kısar; çözücü çözüm sayısını sayarak zorluğu doğrular. Çözülemeyen seviye
asla yayına girmemeli; bunu otomatik testle garanti et. İlk teslimde 60 seviye.

## Görsel varlıklar
Model, doku ve ses üretme araçların varsa (3B modelleme, görsel üretimi, ses
kütüphanesi) onları kullan. Yoksa şunu yap: görünümü shader, ışık ve
parçacıklarla olabildiğince zenginleştir, ve ihtiyaç duyulan her varlığı
ASSETS.md dosyasında listele (ad, boyut, stil tarifi, kullanıldığı yer), ki
sonradan gerçek varlıklarla değiştirilebilsin. Telifli ya da lisansı belirsiz
varlık kullanma.

## Çalışma şekli
Aşamalar halinde ilerle ve her aşamanın sonunda çalışan bir yapı bırak:
1. Çekirdek mantık ve çözücü, arayüzsüz, birim testleriyle.
2. Tek odalı oynanabilir dikey kesit: nihai kalitede ışık, ses ve his.
   Burada dur ve ekran görüntüsü/video ile ilerlemeyi göster.
3. Gün döngüsü, test aşaması, sigorta, kazanma ve kaybetme akışı.
4. İçerik öğeleri ve 60 seviye.
5. Mahalle, yenileme, koleksiyon, günlük seviye.
6. Reklam/analitik arayüzleri, performans ayarı, Android paketi.
Her aşamada yaptığın varsayımları ve ertelediğin işleri DECISIONS.md dosyasına
yaz. Bir kural belirsizse en basit yorumu seç, not düş ve devam et.

## Kabul kriterleri
- Hiç oyun oynamamış biri, yazı okumadan ilk 3 seviyeyi geçebiliyor.
- Ekranda rakam yok.
- Fiş takma, sigorta atması ve kazanma anı sesi kapalıyken bile tatmin edici.
- Orta seviye Android cihazda 60 FPS, oyun ekranında takılma yok.
- Tüm seviyeler çözücü testinden geçiyor.
- Görünüm low-poly veya prototip izlenimi vermiyor.
