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

## Aşama 1 (2026-11-14) — çekirdek mantık, çözücü, üretici

- **Düz kipte dilimler:** seviye 1-14'te cihazlar dört dilimde de çalışır (dosyada dört dilim yazılı);
  taşma denetimi her dilimde yapılır. Düz kipte dilime göre değişen öğe olmadığından tek "an" gibidir.
- **Zor seviye ile öğe açılışı çakışması:** 10, 15, 25, 35, 50, 65, 80, 95 hem 5'in katı (zor) hem
  açılış seviyesi. Etiket "hard" kalır (ödül ritmi bozulmaz), ama zorluk aralığı "hard_intro"
  (2-8 çözüm; normalle zor arası) ve öğe en yumuşak hâliyle (tek örnek, en küçük değer) gelir.
- **Zorluk ölçüsü:** çözücünün *ayrık* çözüm sayısı: eş prizler (aynı hat, oda, props) ve birebir
  aynı davranan cihazların yer değiştirmesi tek sayılır. Aralıklar: 1-3 öğretici (1-1000, bol boş
  kapasite), 4-14 normal 3-24, 15+ normal 2-16, zor <20: 2-6, zor 20+: 1-4. Seviye 4'ten itibaren
  "kapasite hiçbir şeyi elemiyor" seviyeleri reddedilir. Tek çözümlü seviye yalnız zor 20+'da olabilir.
- **Gün kipi bir öğedir:** `day_cycle` öğesi (15) seviyeyi "day" kipine alır, 3 sigorta hakkı verir ve
  cihaz dilimlerini katalogdan seçer. Tahta kipi seviye dosyasından okur.
- **Aynı dilimde birden çok hat taşarsa** her hat için sigorta olayı gelir ama tek hak düşer.
- **Ek hak (ödüllü reklam):** kayıptan sonra +1 hak ve plana dönüş; planlamada çağrılırsa hak eklenir.
- **Eski kablo:** hattın taban kapasitesinden `old_cable` blok düşer; sahne bunları tüpte kullanılamaz
  bloklar olarak çizer (taban − etkin). Mekanik olarak düşük kapasiteli hat; en basit yorum.
- **Güneş paneli:** işaretli hatta öğlen +1-2 blok. Üretici öğlen yükü en yüksek hattı seçer.
- **Komşu hattı:** hatta dilim başına dış yük (`neighbour: [s, ö, a, g]`), cihazlardan bağımsız.
- **Zamanlayıcılı priz:** takılı cihazın dilimleri `timer` kadar ileri kayar (gece → sabaha sarar).
- **Kapalı hat:** `off_slice` diliminde hat kapasitesi 0; o dilimde çalışan cihaz o hatta olursa
  sigorta atar (cihazın sessizce kapanması yerine kısıt yorumu seçildi; bulmaca için anlamlı olan).
- **Topraklı priz:** topraklı priz her cihazı alır; `needs_ground` cihaz yalnız topraklıya takılır.
- **Çoklu priz:** aynı odadaki tekli prizler bir uzatmada birleşir (toplam yuva korunur, seçenek azalır).
- **Oda kısıtı öncesi (1-5):** tek oda. 6-19 iki, 20-39 üç, 40+ dört oda.
- **Günlük seviye:** tarih → sanal seviye 16-44 (5'in katları atlanır, zor değil), tohum tarihten.
  Oyuncu ilerlemesine bağlı değildir (her yerde aynı). Arayüz günlüğü seviye 15'ten sonra açar.
- **Cihaz kataloğu** `data/balance/devices.json` içinde (tür, yük aralığı, oda, olası dilimler, toprak).
- **Kimlikler:** hat `L0..`, priz `s0..` (oda sırasıyla), cihaz `d0..`; anchor `"<oda>_<sıra>"`.
- **Ret kodları StringName:** öğe dosyaları yeni kod tanımlayabilsin diye (`params.reason`).
- **Kural kancaları statik:** `check_plug` yalnız cihaz ve prizin hat/oda/props alanına bakar; çözücü
  eş prizleri bu varsayımla sınıflar. Tahta durumuna bağlı kural türü gerekirse çözücü genişletilmeli.
- **İş parçacığı:** öğe kural betikleri `PrizContent.load_default()` ile ana iş parçacığında yüklenir;
  sonrası salt okunur paylaşılır.
- **Ertelenen:** dışa aktarmada `*.json` dosyalarının pakete girmesi için export filtresine
  `data/*.json` eklenmeli (aşama 6). `data/i18n/strings.csv` içine öğe kartı anahtarları
  (`element_<id>_title/_body`) arayüz aşamasında eklenecek.

## Aşama 2 — kabuk (p2-shell)

Şablon (`studio-kit/template-mobile`) projeye taşındı; Priz kurallarına uyarlandı. Varsayımlar:

- **Yerleşim:** şablonun genel çekirdek yardımcıları `scripts/shell/` altında (oyun kuralları `scripts/core/` ile çakışmasın);
  testleri `tests/unit/test_shell_*.gd`. `tests/run_tests.gd` şablonunki alındı (Priz'dekinin üst kümesi: `Progress.persist=false`
  koruması ekli); `test_case.gd` aynıydı; `test_smoke.gd` korundu. `tools/verify.sh` şablonunkiyle DEĞİŞTİRİLDİ (+ `digit_probe`).
- **Rakam yok (kabuk):** seviye numarası, jeton sayısı, süre, "2×" yok. Jeton = `UiChip` içinde jeton SİMGELERİ (her 10 jeton = 1 simge,
  en çok 5, 100 ve üstünde "yığın" simgesi; `balance.json coin_display`). Seviye = 5'li bloklarda noktalar (4 normal + zor seviye
  yıldız noktası). Yıldız ve sigorta hakkı da nokta. Ana düğme "Oyna". Bu geçici bir görünümdür; sayısız ilke aynı kalarak yeniden
  biçimlenecek. Bekleyen AÇIK SORU (meta ekranlarda fiyat/bakiye gösterimi) hâlâ aşama 5/kullanıcıya.
  Koruma: `test_shell_no_digits` + `tools/digit_probe.gd` (Home, Game, tüm sayfalar, 3 dil), `verify.sh`'a bağlı.
- **Geçiş reklamı yorumu:** "seviye 5'ten sonra" = 5. seviye BİTİNCE (tamamlanan seviye ≥ 5) ilk geçiş reklamı olabilir. "2-3 seviyede bir"
  = belirlenimci döngü 2,3,2,3 (reklamlar 5, 7, 10, 12, 15 ...), rastgele değil (tekrarlanabilir test için). Aralık ve eşikler
  `data/ads.json`'dadır. 90 sn koşulu gerçek saat (unix) ile; ödüllü izlenen geçişte reklam atlanır ve bir SONRAKİ geçişte uygun kalır.
- **Sessiz dönem:** ilk 3 seviyede (oynanan seviye ≤ 3) reklam yok, ödüllü düğme sunulmaz, banner yok, mağaza/açılır pencere de
  olmamalı (`Progress.is_quiet_period()` tek soru; mağaza ve pencereler henüz yok, ileride bunu sorar).
- **Banner:** politika veri güdümlü (`ads.json banner.screens`: `neighbourhood`, `collection`); mock yalnız kaydeder. Gerçek AdMob
  banner'ı aşama 6. Ana ekran = mahalle ekranı sayıldı.
- **Sigorta hakkı:** seviye başına, kaydedilmez (`Progress.begin_level_fuses`, varsayılan `balance.json fuses_per_level` = 3).
  Düz kipte (seviye 1-14) sigorta yok; kullanılıp kullanılmayacağına oyun sahnesi karar verir. Yer tutucu oyun hakları kullanır.
- **Kalite kademesi:** kayıtta `quality_tier` (high/medium/low) var; ayarlar sayfasında seçici YOK (art/performans işi kademeyi
  tanımlayınca eklenir). Dil ayarı `Loc`un `settings.language` modülünde kaldı.
- **Titreşim:** `Haptics.tick/thud/success` (süreler `balance.json haptics`); masaüstünde ve ayar kapalıyken no-op.
- **Paket kimliği:** `com.priz.game` / `com.priz.game.test`, ad "Priz" (yer tutucu; yayın öncesi kesinleştirilir).
- **Şablon varsayılanları kaldırıldı:** 4. seviyeden her geçişte geçiş reklamı, "kayıpta devam" (artık `extra_fuse`), `first_level`.
- **Ertelenen:** AdMob banner uygulaması, kalite seçici arayüzü, `collection` ekranı (yalnız politika kimliği), arayüzün diorama dünyasına
  (sigorta kutusu/şalter) uyarlanması, `strings.csv` yeni dil/sözlük genişlemeleri.

## Ertelenenler

- Gerçek cihazda performans ölçümü (aşama 6; o zamana dek masaüstü ölçümleri yalnız oran verir).
- Gerçek reklam SDK'sı (sahte servisle çalışılır; AdMob aşama 6).

## Aşama 2 — ses

- **Üretim:** tümü ElevenLabs (SFX v3 + Music), `tools/make_sfx.py`; ham çıktı `build/sfx_raw` önbelleğinde, istek sayacı
  `requests.json` (üst sınır 45, bu aşamada 31 kullanıldı). `--force` yalnız ad verilerek çalışır. Kabuktan gelen `coin`, `ui_soft`,
  `win` yeniden üretilmedi.
- **Fiş "tık":** üç ayrı istek (`plug_seat_1..3`), `play_variant` ile dönüşümlü; PCM içe aktarma, tepe -1.5 dB (oyunun en net sesi).
- **Döngüler:** kuyruk başa eşit-güçlü çapraz geçişle bağlanır (sarma noktası süreksizliği ölçülür, `--report`). Döngüler 32 kHz,
  ortamlar 22.05 kHz mono (depo küçük); QOA içe aktarma. Müzik OGG.
- **Bus'lar kodla kurulur** (`AudioService._ensure_buses`), `default_bus_layout.tres` ve `project.godot` değişmedi. Master'da
  `AudioEffectHardLimiter` (tavan -1 dB). `duck()` Loops/Ambience/Music'i kısar, efektleri değil.
- **Kimlikler:** `music_main` / `ambience_main` (otomatik başlayanlar) KASITLI olarak yok; sahne `play_music("music_plan")` ve
  `play_ambience("ambience_*")` çağırır. Kazanma parçası döngüsüz: `play_jingle("music_win")`.
- **Açık:** `hum_mains` ~105 Hz çıktı (50 Hz değil); telefon hoparlöründe daha iyi duyulduğu için tutuldu, insan kulağı onaylamalı.
