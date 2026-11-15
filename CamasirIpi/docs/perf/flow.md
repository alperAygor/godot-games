# Akış: hızlı oyun, seviye geçişi, ana ekran yerleşimi (ci-flow, 2026-11-15)

Oyuncunun telefonda bildirdiği üç sorun (öncelik sırasıyla):
1. Hızlı oynayınca animasyonlar oyunu yavaşlatıyor.
2. Seviyeler arası düğmeye basınca bekletiyor.
3. Ana menüde Oyna düğmesi telefonda iyi yerde değil.

Ölçüm aracı: `tools/speed_probe.gd` (başsız, gerçek zamanlı, 60 fps sınırı). Ana ekran görüntüleri:
`tools/home_shot.gd` (gerçek pencere). Önce değerleri aynı probun, değişiklikten önceki kodu taşıyan bir
kopyada koşturulmasıyla alındı (aynı ölçüt).

## 1. Hızlı oyun: tahta önde, animasyon arkadan yetişir

### Sorunun kökü
Dokunuş tahtaya zaten anında işleniyordu; ama görsel olay kuyruğu SIRALIYDI ve bazı olaylar kuyruğu
uzun süre tutuyordu: her sepet tamamlanması tüm uçuşların inmesini + basma/çökme (~0.5 sn) bekliyor,
yeni sepet ondan sonra geliyordu; rüzgâr, boya, yağmur, makine çıkışı, patron ekranı da bekliyordu.
Hızlı oyuncunun dokunduğu çamaşır, önceki dokunuşların bütün dizisi oynanana dek KIPIRDAMIYORDU
(10 hızlı dokunuşta 2.4-3.3 sn; sakin 1.5 sn aralıkta bile sepet tamamlanırken 1.5 sn).

### Tasarım (game.gd başındaki not ile aynı)
- **Tahta tek doğruluk kaynağı.** Yasallık her zaman güncel `LaundryBoard` durumundan; dokunma testi
  çamaşırın ekrandaki yerinden değil MANTIKSAL yerinden (`GarmentView.line_home`): kayma, rüzgâr,
  ekran geçişi sürerken de parmak hedef yerde sınanır.
- **Varlık başına tek kanal.**
  - *Çamaşır:* tek uçuş Tween'i. Yeni komut eskisini yeniden hedefler (`fly_to` mevcut yerden yeni
    yaya başlar), eski uçuşun iniş tepkisi bağlantıları koparılır (askıya giderken sepete yönlenen
    parça "askıya indi" sesi çalmaz). İpte yer değiştirme (`move_on_line`, rüzgâr) ayrı bir Tween'dir ve
    uçuş başlarken öldürülür: iki Tween aynı konumu yazıp parçayı yanlış yere bırakamaz. Askı genişlerse
    uçan parça `retarget` ile yeni kancaya kıvrılır. Makineden çıkışta kapıya uçuş kesilir (`stop_flight`).
  - *Sepet:* sepet başına sıralı iş kanalı (`_basket_jobs`): tamamlanma -> yeni sepet -> joker rengi.
    Kanal kuyruğu bekletmez. Her tamamlanmada sepetin MANTIKSAL nesli artar; inen parça kendi neslini
    taşır (`BasketView.land(piece, index, gen)`). Sepet kapanıyor/gidiyor/geliyorsa ya da nesil tutmuyorsa
    parça bekler ve yeni sepet yerine oturunca TEK zıplamayla katılır (iniş nabızları birleşir). Neden
    nesil: hızlı oyunda yeni neslin parçası eski neslin son parçasından önce inebiliyordu ve eski yığınla
    birlikte taşınıp siliniyordu (stres probu yakaladı).
- **Kuyruk hiç uzun beklemez.** Uçuşlar hemen başlar; aynı dokunuşun art arda uçuşları arasında küçük
  sıra aralığı kalır. Süs beklemeleri (`_beat`: boya akması, rüzgâr, yağmur damlası, sıra aralığı) YENİ
  bir dokunuş gelince biter. Patron ekran geçişi kuyruktan bağımsız oynar (`_detached`). Yalnız seviye
  sonu (kazanma/kayıp) tüm uçuşları ve sepet kanallarını bekler — dokununca o da atlanır.
- **Uyarlanır tempo (`Motion.pace`).** Ekran durgunken tempo 1: premium süreler aynen. Ekran hâlâ
  hareketliyken art arda dokunulursa dokunuş aralığından (yumuşatılmış) tempo: 650 ms ve üstü -> 1,
  150 ms ve altı -> 3x, arası doğrusal. `Motion.track` ile kaydedilen tüm oynanış Tween'leri (uçuş,
  iniş, sepet tepkileri, geliş/gidiş, mandal düşüşü) tempo değişince SÜRERKEN de hızlanır; bekleyişler
  aynı tempoyla kısalır. 1.6x üstünde iniş tozu ve tamamlanma "tutuşu" atlanır. Ekran durulunca 1'e döner.
- **Ses kapısı (`SoundGate`, yalnız AudioService API'si).** Aynı ses 45 ms içinde tekrarlanmaz; 260 ms
  içinde tekrar ederse perde %3.5 adımla yükselir (en çok 4 adım) ve 1.5 dB kısılır; 150 ms'de en çok 5
  ses (6 oynatıcılık havuz taşıp çalan sesi kesmez). Nota/kazanma/jeton perde adımı almaz.
- **Zincir hapı:** sepet kanalları sırasız bitebilir; hap kopmadan sonraki en büyük adımı gösterir;
  geri al sonrası istatistikle eşitlenir.
- **Güvenlik ağı:** tamamlanma 4 sn içinde parçalarını alamazsa parçalar oturtulur (`push_warning`);
  stres probunun son koşusunda hiç tetiklenmedi.

### Stres probu (`tools/speed_probe.gd`, son koşu: PROBE SONUC: gecti)
33 seviye (2..124), 1894 dokunuş (1816'sı gerçek girdi yolundan `_unhandled_input`, 78'i görünmeyen/örtülü
parçaya doğrudan), kare başına 1-3 işlem + rastgele 1-4 karelik aralık, %12 engelli dokunuş, %10 geri al,
+1 askı, mandal sökücü (L40/58/100, ardından rastgele yasal oyun), seviye sonu atlatma. 229 "görünüm ==
tahta" denetimi: hata yok; sahipsiz düğüm artışı 0; süren kayıtlı Tween 0; sonuçlar saf tahta tekrarıyla
birebir; L9 ve L23 gerçek sahnede yavaş (her işlemde durularak) tekrarla aynı sonuç; 30 "Devam" geçişinde
düğüm/nesne büyümesi yok. Kapsanan mekanikler: ıslak, gizemli, kilit, çarşaf, çorap, boya, leke, zincir,
rüzgâr, kayan ip, joker, büyük sepet, hamle sınırı, kısa askı, patron (2 ekran), sipariş, çift renk,
güneş, yaprak, don, polen, çamaşır/kurutma makinesi, çamur, türlü sepet, kuş, yağmur, kedi.
İlk koşular iki gerçek hata buldu (düzeltildi): yeni neslin erken inen parçası eski yığınla siliniyordu
(-> nesil etiketi) ve geri al yarıda kalan tamamlanmayı düşürünce zincir hapı eksik kalıyordu.

### Hâlâ bekleten anlar (bilinçli)
- Seviye sonu (kazanma/kayıp): son uçuşlar + son sepetin kapanışı + 0.45/0.6 sn — dokunuş atlatır.
- Mandal sökücü hedef seçimi (iki adımlı güçlendirici), öğretici kartı açıkken (`input_blocked`).
- Patron ekranı: ikinci ekranın parçaları kaymaya başlamadan (ilk ekranın son uçuşu + 0.35 sn) dokunulamaz
  (görünmeyen parçaya dokunulmasın diye).

### Önce / sonra (M4, başsız, 60 fps sınırı, seviye 12, çözücü yolu)
"Geri bildirim" = dokunulan çamaşırın konum/ölçek/dönmesi ilk değiştiği kare. "Durulma" = kuyruk boş,
uçuş yok, sepet yerinde (aynı ölçüt önce ve sonra).

| Senaryo | Önce: geri bildirim en kötü | Sonra | Önce: son dokunuştan durulma | Sonra |
|---|---|---|---|---|
| Tek sakin dokunuş | 1 kare / 15 ms | 1 kare / 17 ms | 910 ms | 916 ms |
| 10 dokunuş, 100 ms aralık | 146 kare / 2428 ms | 1 kare / 22 ms | 3434 ms | 615 ms |
| 10 dokunuş, aynı karede | 201 kare / 3346 ms | 1 kare / 14 ms | 4350 ms | 729 ms |
| 10 dokunuş, 1500 ms (sakin) | 1 kare / 19 ms (*) | 1 kare / 18 ms | 947 ms | 914 ms |
| Seviye sonu (L2 / L9 / L65, her karede bir dokunuş) | 5.1 / 9.7 / 26.4 sn | 1.0 / 1.9 / 2.5 sn | | |
| Seviye sonu dokunuşla atlanınca | — | 80-250 ms | | |

(*) Ölçütün ilk sürümü yalnız konuma bakıyordu ve sakin tempoda 1533 ms gösteriyordu (sıkılan parça yerinde
kalır); ölçek/dönme de sayılınca önce de 1 kare. Asıl fark sepet tamamlanırken: önce dokunulan parça
tamamlanma bitene dek bekliyordu (100 ms aralıkta 2.4 sn), şimdi aynı karede kalkar.
Tüm Tween'ler (iniş ezilmesi, sepet yaylanması) bitene dek sayılınca "sonra" değerleri: tek dokunuş 1115 ms,
10x100 ms 1152 ms, 10x aynı kare 1257 ms — yani hızlı patlamanın sonu, tek sakin dokunuşla aynı sürede durulur.

## 2. Seviye geçişi

### Ölçüm (önce)
"Devam"dan oynanabilir ilk kareye (yeni tahta, sayfa yok, öğretici girdiyi tutmuyor):

| Geçiş | Önce | Sonra |
|---|---|---|
| 2 -> 3 (reklam zamanı değil) | 13-19 ms | 16-19 ms |
| 3 -> 4, 9 -> 10, 65 -> 66 (geçiş reklamı zamanı) | **1196-1210 ms** | **16-31 ms** (makine boşta) |
| Sonraki 1 sn içinde en kötü kare | 24-36 ms | 24-31 ms (boşta); başka prob paralel koşarken 65->66'da 39 ms |

Parçalar: sonuç sayfasının kapanış animasyonu yok (anında silinir); sahne değişmiyor (yerinde yeniden
kurulum, 30 geçişte düğüm 303 -> 332 -> 280, nesne 2473 -> 2567 -> 2422: büyüme yok); seviye `LevelPrefetch`
ile oyun sırasında üretilmiş; sonraki mekânın dokuları zaten iş parçacığında isteniyor; giriş animasyonu
girdiyi tutmuyor. **Tüm gecikme geçiş reklamı beklemesiydi:** 4. seviyeden itibaren her "Devam"da seviye
ancak reklam bittikten sonra kuruluyordu. Hata ayıklama derlemesinde AdMob eklentisi yoksa `MockAdsProvider`
ekranda HİÇBİR ŞEY göstermeden 1.2 sn bekliyor: oyuncu düğmeye basıyor, kazanma sayfası 1.2 sn donuk kalıyordu.

### Değişiklik
`EcoFlow.maybe_interstitial`: reklam kararı (kural aynı, `AdPacing`) önce verilir, sonra sonraki seviye
HEMEN kurulur, reklam gerekiyorsa kurulmuş tahtanın üstünde gösterilir. Reklam yoksa ek gecikme sıfır;
reklam bekleyişi bir solmayla üst üste binmez (sayfa anında kalkar). Reklam kapanınca seviye süresi
(analitik) sıfırlanır, reklam süresi sayılmaz.

## 3. Ana ekran Oyna düğmesi

`HomeLayout.compute` (saf, `tests/unit/test_flow_layout.gd`): kullanılabilir alan = görünür alan − güvenli
alan payları (çentik, sistem çubuğu). Alt çubuk alt kenara, Oyna alt-ortaya (üst kenar ile alt çubuk
arasındaki yolun %74'ü, alt çubuğa en az 96 px), seri göstergesi Oyna'nın hemen üstüne, başlık/ip/askı
aynı yolun oranlarına yerleşir. Oyna'nın kendisi yatayda ortalı (eskiden harita diskiyle birlikte
ortalanıp 75 px sola kayıyordu).

| Görünür alan (expand) | Oyna merkezi x farkı | dikey oran (güvenli alanda) | güvenli alanda |
|---|---|---|---|
| 1080x1920 (9:16; 720x1280 aynı) | 0 | 0.679 | evet |
| 1080x2340 (9:19.5) | 0 | 0.691 | evet |
| 1080x2400 (9:20) | 0 | 0.692 | evet |
| 1080x2520 (9:21) | 0 | 0.695 | evet |
| 1440x1920 (tablet 3:4) | 0 | 0.679 | evet |

Önce: Oyna her ekranda y=1560'ta sabitti — 9:16'da alt çubuğa yakın (%81), 9:21'de ekran ortasının
üstünde (%62), yatayda 75 px solda.

## Gerçek telefonda kontrol edilecekler
1. Çok hızlı dokunuşta (iki parmak) uçuşların 3x hızda okunur kalması; tempo eşikleri (650/150 ms) his
   olarak doğru mu.
2. Ses kapısı: art arda sepet dolarken yükselen perde hoş mu, kesilme var mı (gerçek ses sürücüsü).
3. AdMob gerçek geçiş reklamı: tahta reklamın altında kurulur; reklam kapanınca tahta hazır. Reklam
   etkinliği sırasında oyun döngüsünün (öğretici zamanlayıcıları) davranışı.
4. Ana ekran: gerçek çentik/gezinme çubuğu paylarıyla (`DisplayServer.get_display_safe_area`) yerleşim.
5. Seviye kurulumu karesi (masaüstünde 16-31 ms): orta sınıf Android'de ilk saniyede takılma.
