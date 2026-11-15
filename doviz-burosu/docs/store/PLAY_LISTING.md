# Google Play ilan taslağı — Döviz Bürosu / Exchange Desk (T-S1)

Taslaktır; yayın öncesi sahip onaylar. Dil: belgenin kendisi Türkçe, **mağaza metinleri** İngilizce (birincil, en-US) ve Türkçe (tr-TR). Karakter sayıları Python `len()` ile (Unicode karakter) hesaplandı; Play Console'un aynı şekilde saydığı ÇIKARIMDIR, konsol sayacına bak.
Limitler (kaynak: `~/Desktop/Games/godot-games/CamasirIpi/docs/store/PLAY_REQUIREMENTS.md` §3.14, §4.1; Play Console yardım sayfaları answer/9898842 ve answer/9866151): başlık **30**, kısa açıklama **80**, uzun açıklama **4000** (4000 sınırı o belgede "bu oturumda resmi sayfada doğrulanamadı" notuyla anılır; metinler çok altında kalır).
Oyuna özgü politika bölümü: aynı belge G2 (finans/döviz temalı oyunlar, kumar). Burada tekrar edilmez; aşağıdaki "Politika kontrolü" bölümü projeye uyarlanmıştır.

## 0. Karar özeti (sahibe)

| Konu | Öneri |
|---|---|
| Mağaza başlığı (EN) | **Pahalistan Exchange Desk** (24/30) — gerekçe §1 |
| Mağaza başlığı (TR) | **Döviz Bürosu: Damga ve Say** (26/30) |
| Uygulama etiketi (cihazda) | "Döviz Bürosu" (`export_presets.cfg package/name`, mevcut karar); EN cihazda "Exchange Desk" için yerelleştirilmiş etiket T-R1/lider kararı |
| Tür / kategori | **Oyun › Simülasyon** (Finans DEĞİL) — gerekçe §6 |
| Hedef kitle | 13+ (çocuklara yönelik değil) |
| İlanda vurgulanacak 3 şey | kurgusal ülke/para; damga-incele-öde oyun döngüsü; 15 gün/7 son hikâye |
| İlanda KULLANILMAYACAK | forex, ticaret, yatırım, kâr, "gerçek para kazan", kumar/bahis, "en iyi/#1/ücretsiz/yeni" gibi sıralama-promosyon iddiaları, gerçek banknot/ülke/banka/döviz piyasası adı, "Papers, Please" adı |

## 1. Başlık seçenekleri (≤ 30 karakter)

### İngilizce (en-US)

| Seçenek | Karakter | Not |
|---|---:|---|
| `Pahalistan Exchange Desk` | 24 | Önerilen. Uydurma ülke adı hem özgün (aranabilir, markalaşır) hem 'gerçek forex/döviz uygulaması' yanılgısını azaltır. Pahalistan, Türkçe 'pahalı' sözcüğüne gönderme yapan bir kelime oyunudur; İngilizce okura yalnız özel ad görünür (zararsız). |
| `Stamp & Count: Exchange Desk` | 28 | Eylem odaklı (damga + say), oyun/simülasyon beklentisi kurar. Ayırt edici marka yok; 'Exchange Desk' tek başına kalırsa finans aramalarıyla karışır. Yedek seçenek. |
| `Counterfeit Counter` | 19 | Akılda kalıcı söz oyunu, ama 'exchange/döviz' geçmediği için aramada zayıf, sahte para çağrışımı öne çıkar ve genel isim çakışması riski yüksek. Üçüncü seçenek. |

**Öneri: `Pahalistan Exchange Desk`** (24/30). Neden: (1) roadmap §5'in önerisiyle aynı; (2) kurgusal ülke adı, mağaza kartında bile oyunun hayali bir dünyada geçtiğini söyler → "gerçek döviz/forex uygulaması" yanılgısı ve buna bağlı olumsuz yorum/politika riski azalır; (3) özgün sözcük aranabilir ve markalaşır; (4) oyun içi ad (`APP_TITLE` = "Exchange Desk") ile uyumlu. Sahip: ad müsaitlik/marka taramasını kendisi yapar (çevrimiçi kontrol bu çalışmada yapılmadı). 
Yedek: `Stamp & Count: Exchange Desk` (28/30). Not: başlıkta emoji, tümü büyük harf, "&" dışında özel karakter yok; tek `&` başlıkta gereksiz/yinelenen özel karakter sayılmamalı (ÇIKARIM; Console doğrular); sorun çıkarsa "and" kullan (`Stamp and Count: Exchange Desk` = 30/30).

### Türkçe (tr-TR)

| Seçenek | Karakter | Not |
|---|---:|---|
| `Döviz Bürosu: Damga ve Say` | 26 | Tür beklentisi (damga, say) başlıkta; oyun içi ad 'Döviz Bürosu' ile uyumlu. |
| `Pahalistan Döviz Bürosu` | 23 | EN önerisinin Türkçe karşılığı; marka tutarlılığı için EN başlıkla aynı kurgusal ülke adı. |
| `Döviz Bürosu` | 12 | En sade; uygulama etiketiyle aynı. Tek başına yalnız 'döviz' aramalarıyla yarışır (finans uygulamalarıyla karışma riski). |

**Öneri: `Döviz Bürosu: Damga ve Say`** (26/30) — oyun türünü ("damga, say") başlıkta verir; oyun içi/etiket adıyla aynı kök.

## 2. Kısa açıklama (≤ 80)

- EN: `Run a made-up country's exchange desk: spot fakes, stamp, pay. Play money only.` — **79/80**
- TR: `Hayali ülkede döviz bürosu yönet: sahteyi bul, damgala, öde. Oyun parasıyla.` — **76/80**

Bilinçli seçimler: "made-up country" / "hayali bir ülke" + "Play money only" / "Oyun parasıyla" → ilk 80 karakterde gerçek para olmadığı söylenir; "kazan/yatırım/ticaret" yok.

## 3. Uzun açıklama (≤ 4000)

### EN — 2679 karakter

```
Exchange Desk is a pixel-art simulation game about one clerk behind one counter in the made-up country of Pahalistan.

Customers step up to your window with banknotes, ID cards and a story. Check every note and paper, decide what the rules say, press the right stamp, and pay out the correct amount. Make a mistake and it shows on your payslip. Do it right, and the line keeps moving.

Everything in the game is fictional: the country, the six currencies (PL, FED, AVR, STR, DNR, KRN), the exchange rates and the money. The in-game money has no real value and cannot be cashed out. This is a game, not a finance app, and nothing in it is financial or investment advice.

HOW IT PLAYS
- Inspect banknotes, IDs and declarations. Use the UV lamp, the magnifier, the catalog and your calculator to spot forged notes, stolen serial numbers, torn or expired notes and fake IDs.
- Press one of three stamps: Approved, Rejected or Police. Then drag each note to Return, Accept or Confiscate.
- Work out each payout from the day's exchange rates, count it from the till and hand it over.
- A new rule can arrive with the morning paper. There are 13 rules, introduced gradually.
- Evenings are about the family budget: rent, food, heating, medicine. A shortfall hurts the people at home.

STORY AND MODES
- Story: 15 days at the counter, 11 characters, dark-humored choices (a bribe in an envelope, a boss who wants a little extra, a visiting inspector) and 7 different endings.
- Daily Rate: the same 12 customers for everyone on the same date. Beat your own best score.
- Endless: three lives, and a new rule every few customers. How long can you keep the line moving?

THINGS YOU MIGHT LIKE
- A dim, lamp-lit booth, hand-drawn paper props, retro pixel look (you can switch the screen filter off).
- Music and sound effects for the booth, the office and the evening.
- English and Turkish.
- Accessibility options: larger text, a colour-blind friendly mode, reduced motion, master volume and vibration controls.

CONTENT NOTE
The story has bribery, forged documents and police. There is no violence, gore, strong language, drugs or gambling.

ADS AND PURCHASES
Exchange Desk is free to play and contains ads from Google AdMob. A short ad may appear at the end of a day. You can also choose to watch optional rewarded ads, for example to double a day's pay. You can also replay a day: one replay per day is free, further ones cost a little in-game money or a rewarded ad. One optional one-time purchase, "Remove ads", removes the ads between days; optional rewarded ads stay available. There is no account, no sign-in and no analytics.

Questions or feedback? Write to [DEVELOPER EMAIL].
```

### TR — 2584 karakter

```
Döviz Bürosu, Pahalistan adlı hayali bir ülkede tek gişenin başındaki tek memuru anlatan, piksel görünümlü bir simülasyon oyunudur.

Müşteriler camına banknotlarla, kimlik kartlarıyla ve bir hikâyeyle gelir. Her banknota ve belgeye bak, kurallar ne diyorsa ona karar ver, doğru damgayı bas ve doğru tutarı öde. Hata yaparsan maaş fişinde görünür. Doğru yaparsan kuyruk akmaya devam eder.

Oyundaki her şey kurgusaldır: ülke, altı para birimi (PL, FED, AVR, STR, DNR, KRN), kurlar ve para. Oyundaki paranın gerçek değeri yoktur ve bozdurulamaz. Bu bir oyundur, finans uygulaması değildir; içindeki hiçbir şey finansal ya da yatırım tavsiyesi değildir.

NASIL OYNANIR
- Banknotları, kimlikleri ve beyanları incele. Sahte banknotu, çalıntı seri numarasını, yırtık ya da süresi geçmiş banknotu ve sahte kimliği bulmak için UV lambayı, büyüteci, kataloğu ve hesap makinesini kullan.
- Üç damgadan birini bas: Onaylandı, Red ya da Polis. Sonra her banknotu İade, Kabul ya da El koy bölgesine sürükle.
- Günün kurlarına göre ödemeyi hesapla, kasadan say ve ver.
- Sabah gazetesiyle yeni bir kural gelebilir. Toplam 13 kural var; kademeli olarak açılır.
- Akşamlar aile bütçesine ayrılır: kira, yemek, ısınma, ilaç. Açık, evdekilere zarar verir.

HİKÂYE VE MODLAR
- Hikâye: gişede 15 gün, 11 karakter, kara mizahlı seçimler (zarfta rüşvet, biraz fazlasını isteyen patron, gelen müfettiş) ve 7 farklı son.
- Günün Kuru: aynı tarihte herkese aynı 12 müşteri. Kendi en iyi puanını geç.
- Sonsuz: üç can ve birkaç müşteride bir yeni kural. Kuyruğu ne kadar akıtabilirsin?

HOŞUNA GİDEBİLECEKLER
- Loş, lambayla aydınlanan bir gişe, elle çizilmiş kâğıt eşyalar, retro piksel görünüm (ekran filtresini kapatabilirsin).
- Gişe, ofis ve akşam için müzik ve ses efektleri.
- Türkçe ve İngilizce.
- Erişilebilirlik seçenekleri: büyük yazı, renk körlüğü dostu kip, hareketi azaltma, ana ses ve titreşim ayarları.

İÇERİK NOTU
Hikâyede rüşvet, sahte belge ve polis var. Şiddet, kan, ağır küfür, uyuşturucu ve kumar yok.

REKLAM VE SATIN ALMA
Döviz Bürosu ücretsiz oynanır ve Google AdMob reklamları içerir. Bir günün sonunda kısa bir reklam çıkabilir. İstersen isteğe bağlı ödüllü reklam izleyebilirsin; örneğin bir günün maaşını ikiye katlamak için. Günü yeniden de oynayabilirsin: günde bir tekrar ücretsiz, sonrakiler biraz oyun içi paraya ya da ödüllü reklama mal olur. Tek seferlik, isteğe bağlı bir satın alma olan "Reklamları kaldır", günler arasındaki reklamları kaldırır; isteğe bağlı ödüllü reklamlar kalır. Hesap, giriş ve analitik yoktur.

Soru ve geri bildirim için: [GELİŞTİRİCİ E-POSTASI]
```

## 4. "Yenilikler" (What's new, ≤ 500)

- EN (140): `First release. Run the exchange desk in the made-up country of Pahalistan: 15 story days, Daily Rate and Endless modes, English and Turkish.`
- TR (115): `İlk sürüm. Pahalistan'da döviz bürosunu yönet: 15 günlük hikâye, Günün Kuru ve Sonsuz modları, Türkçe ve İngilizce.`

## 5. Metindeki her iddianın kodda karşılığı (yayın sürümünde doğrula)

| İddia | Kanıt (dosya) | Not |
|---|---|---|
| Piksel görünüm, ekran filtresi kapatılabilir | `assets/shaders/pixel_filter.gdshader`, Ayarlar > Piksel görünümü | — |
| 6 kurgusal para birimi PL/FED/AVR/STR/DNR/KRN | `data/currencies.json` | — |
| 13 kural, kademeli açılır | `data/rules.json`, `docs/doviz-burosu-plan.md` | sayı: `RuleSet` 13 kural |
| 15 gün, 11 karakter, 7 son | `data/story/` (`day_01..15`, `characters.json`, `endings.json`); ASSESSMENT §1 | "7 son": `GUIDE_B7` metni hâlâ "altı" diyor (T-L1/T-C1 düzeltir) — ilan yedi der |
| UV lamba, büyüteç, katalog, hesap makinesi, kur hesaplayıcı, kasa | `data/tools.json`, `TOOL_*` anahtarları | araçlar kademeli açılır; ilan "kullan" der, hepsinin ilk günden açık olduğunu söylemez |
| Günün Kuru (aynı tarih = aynı 12 müşteri), Sonsuz (3 can) | `data/modes.json` | — |
| Erişilebilirlik: büyük yazı, renk körü kipi, hareketi azalt, ana ses, titreşim | T-A2 (Ayarlar) | **bu ilan T-A2 birleştirilince doğrudur**; birleşmezse bu satırı sil |
| Reklam: gün sonunda geçiş reklamı, isteğe bağlı ödüllü reklam | `data/ads.json`, `AdPolicy` | banner yok |
| Günde 1 ücretsiz tekrar, sonrası oyun içi bedel ya da ödüllü reklam | `data/ads.json free_retry`, `DayRetry` | T-B1 birleştirilince doğru |
| "Reklamları kaldır" tek seferlik | `data/products.json` (`no_ads`) | fiyat sahibin kararı (varsayılan $2,99; metinde fiyat YOK) |
| Hesap, giriş, analitik yok | `Analytics` yalnız bellekte; oyunda hesap kodu yok | — |
| TR + EN | `data/languages.json` | yeni diller eklenince bu satır ve ilan dilleri güncellenir |
| "Oyun parası gerçek değer taşımaz ve bozdurulamaz" | oyunda para çıkışı/transferi yok (ASSESSMENT §10) | — |

İnternet gerekliliği: oyun çevrimdışı oynanır (ağ yalnız reklam/satın alma SDK'ları). Cihazda uçak modunda deneyip doğrulamadan "çevrimdışı oynanır" cümlesi ilana **konmadı**.

## 6. Kategori ve etiketler

- **Tür:** Oyun (Game). **Kategori: Simülasyon (Simulation).** Gerekçe: oyun, bir gişede kural uygulama ve kaynak (kasa/aile bütçesi) yönetimi simülasyonudur; Strateji/Bulmaca ikinci tercih. **Finans (Finance) kategorisi seçilmez**: gerçek finansal hizmet yok; Finans kategorisi hem yanlış beklenti hem Finansal Hizmetler politikası incelemesi doğurur (PLAY_REQUIREMENTS G2.1). Console'daki gerçek kategori adları formda doğrulanır.
- **Etiket önerisi** (Console'un sunduğu listeden, yakın olanlar; tam liste konsolda): Simulation, Management, Story-rich / Narrative, Pixel art / Retro, Single player, Casual değil. **Seçilmeyecek:** Finance, Trading, Investing, Money, Casino, Gambling, Offline (cihazda doğrulanana dek).
- Anahtar kelime notu: ilan metni doğal akar; başlıkta/kısa açıklamada tekrarlı anahtar kelime yok; "exchange desk" ifadesi başlıkta bir kez, açıklamada oyun bağlamında geçer. Aramada "forex/ticaret" çağrışımı yaratacak sözcük bilinçli kullanılmadı.

## 7. Ekran görüntüsü planı (telefon; 9:16, ≥ 1080×1920, alfasız PNG/JPEG, 2-8 adet)

Görüntüler T-R2'nin `tools/store_shots.gd` aracıyla **gerçek oyun sahnelerinden** (cihaz çerçevesi yok), TR ve EN ayrı alınır. Altyazı oyun görüntüsünün üstüne tasarım katmanı olarak eklenecekse oyun ekranındaki metin (yerelleştirme) ile uyumlu olmalı; "#1, ödüllü, yeni" rozeti yok.

| # | Sahne | EN altyazı | TR altyazı | Politika/Doğruluk notu |
|---|---|---|---|---|
| 1 | Gişe: müşteri + konuşma balonu + masa (Gün 1-2) | Every customer has a story | Her müşterinin bir hikâyesi var | Hayali ülke vurgusu: yüz/figür gerçek kişi değil |
| 2 | İnceleme sayfası: banknot + seri no + UV lamba | Spot the fakes | Sahteyi bul | Banknot kurgusal (PL/AVR…), gerçek para yok |
| 3 | Damga anı (Onaylandı / Polis) | Stamp your decision | Kararını damgala | — |
| 4 | Sabah gazetesi: "Pahalistan Gazetesi" + yeni kural | A new rule every morning | Her sabah yeni bir kural | "Pahalistan" kurgusal ülke adı görünür |
| 5 | Kur hesaplayıcı/kasa: ödeme sayma | Count it out right | Doğru tutarı say | **Kur tablosu kurgusal para birimleriyle**; "yatırım/kâr" altyazısı yok |
| 6 | Akşam: aile bütçesi (kira, yemek, ısınma) | Rent, food, family | Kira, yemek, aile | "Bütçe" kurgusal PL; gerçek tavsiye çağrışımı yok |
| 7 | Hikâye olayı/son ekranı | 15 days, 7 endings | 15 gün, 7 son | Rüşvet temasının dürüst gösterimi (zarf olayı) — sansürleme, abartma |
| 8 | Günün Kuru sonucu | A new challenge every day | Her gün yeni bir meydan okuma | — |

Ek: ilan açıklamasındaki "kurgusal" vurgusunu ekran görüntüsü 1 veya 5 üstünde de okunur kıl (ör. kur tablosunda "FED/AVR" kod adları görünür, gerçek para birimi adı görünmez).
Tablet görüntüsü isteğe bağlı (en az 4 görüntü gerekir, 1080-7680 px); ilk sürümde yok.

## 8. Grafikler (T-R2)

| Varlık | Ölçü | Not |
|---|---|---|
| Simge | 512×512, 32-bit PNG (alfalı), ≤ 1024 KB | gerçek banknot/ülke/banka sembolü yok; "Papers, Please" benzetmesi yok |
| Öne çıkan grafik | 1024×500, JPEG/24-bit PNG alfasız | üzerinde sıralama/fiyat/Play rozeti yok |
| Video (isteğe bağlı) | tek YouTube URL | ilk sürümde yok |

## 9. Politika kontrolü (çelişki listesi; her satır geçmeden gönderme)

| Politika | Bu oyun | Durum |
|---|---|---|
| Finansal hizmetler (gerçek para/yatırım/kredi/kripto) | Hiçbiri yok; kurlar `data/currencies.json` + sürüklenme ile üretilir, ağ çağrısı yok | Uyumlu → Finansal özellikler beyanı: "yok" |
| Gerçek paralı kumar / simüle kumar / loot box | Yok; tek ücretli ürün `no_ads`; rastgele ödüllü satış yok | Uyumlu |
| Yanıltıcı metadata (başlık/ikon/açıklama gerçek finansal hizmet gibi) | Başlıkta kurgusal ülke, açıklamada "kurgusal, oyun parası, finansal tavsiye değil" | Uyumlu (ilan metni korunduğu sürece) |
| Metadata: ≤ 30/80, emoji yok, TÜMÜ BÜYÜK yok, sıralama/promosyon iddiası yok | Bu taslakta sayıları yukarıda | Uyumlu |
| Reklam politikası: gün sonu dışında geçiş yok; ödüllü yalnız oyuncu onayıyla; sahte kapatma yok | `AdPolicy`, `data/ads.json`; banner yok | Cihazda doğrulanmalı (T-Q1) |
| Hedef kitle 13+; çocuğa yönelik anlatım yok | İlanda "çocuk/aile" ifadesi yok; hikâye rüşvet/polis içerir | Uyumlu |
| Kullanıcı verisi: gizlilik politikası + Veri güvenliği + uygulama içi bağlantı | `docs/PRIVACY_POLICY.md`, `DATA_SAFETY_ANSWERS.md`, `Monetization.privacy_policy_url` | Sahip URL'yi barındırınca |
| Fikri mülkiyet: gerçek banknot/marka/ülke yok; "Papers, Please" adı kullanılmaz | `CLAUDE.md`; banknotlar veriden çizilir | Uyumlu |
| AdMob: finans/kumar reklam kategorileri engellenir | Sahip AdMob konsolunda uygular (bkz. `OWNER_CHECKLIST.md`) | Sahip |

## 10. Diğer ilan alanları

- İletişim: geliştirici e-postası, **web sitesi** (gizlilik politikası ve `app-ads.txt` burada), gizlilik politikası URL'si — hepsi sahip (yer tutucular: `[DEVELOPER EMAIL]`, `[POLICY URL]`).
- Varsayılan dil en-US; ek: tr-TR. Diğer diller (es, pt, de, ja, ko) oyun içi çeviriler (T-L1/L2/L3) bitince; başlık her dilde 30'u aşmamalı.
