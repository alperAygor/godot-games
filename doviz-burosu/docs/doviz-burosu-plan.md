# Döviz Bürosu — baştan sona geliştirme planı (kodlayıcı ajan için)

> Bu belge, yeni bir Godot projesini sıfırdan Play Store'a kadar götürmek için yazıldı.
> Fazlar sırayla yapılır. Her faz kendi içinde **çalışır ve testli** bir durumda biter.
> Kod yazmadan önce bu belgenin tamamını oku. Bir kararı belge söylemiyorsa en basit, veriye dayalı seçeneği seç ve faz sonu raporunda belirt.

---

## 0. Özet

| | |
|---|---|
| **Tür** | Papers, Please tarzı "tek iş" oyunu: döviz bürosunda gişe memurusun. |
| **Platform** | Android, dikey (portrait), telefon. Sonra iOS olabilir; kod buna engel olmamalı. |
| **Motor** | Godot 4.7.2 stable, GDScript, `mobile` renderer, 720x1280, `canvas_items` / `expand`. **2D** oyun (3D yok). |
| **Diller** | Türkçe + İngilizce, ilk günden. |
| **Oturum** | Bir gün (vardiya) ≈ 4–5 dk gerçek zaman. Hikaye 15 gün ≈ 75–100 dk. |
| **Para modeli** | Oyunun tamamı ücretsiz. İsteğe bağlı ödüllü reklamlar, günler arasında seyrek geçiş reklamı, Günün Kuru ve Sonsuz modlar, tek seferlik **Reklamları Kaldır** satın alımı. |

### Oyunun cümlesi
Hayali **Pahalistan**'da enflasyon her sabah kuru değiştiriyor. Sen küçük bir döviz bürosunda gişedesin. Müşterinin getirdiği parayı incele (sahte mi, çalıntı mı, kara para mı?), doğru kurdan hesapla, öde. Akşam da aileni geçindir. Patron kâr ister, müfettiş kural ister, "Tilki" rüşvet teklif eder. Hangisini dinleyeceksin?

### Kullanıcıya sorulacak açık kararlar
Ajan bunları kendisi seçmez. Faz 0'da kullanıcıya sorar; yanıt gelene kadar varsayılanla devam eder.

1. **Oyun adı** — Varsayılan: "Döviz Bürosu" (EN: "Exchange Desk").
2. **Paket adı** — Örnek: `com.<kullanıcı>.dovizburosu`. Play'e ilk yüklemeden sonra bir daha değişemez. Varsayılan: `com.example.dovizburosu` (yer tutucu).
3. **Reklamları Kaldır fiyatı** — Varsayılan: 2.99 USD. Fiyat Play Console'da girilir, kodda değil.
4. **Reklamları Kaldır kapsamı** — Varsayılan: geçiş reklamlarını kaldırır. Ödüllü reklamlar isteğe bağlı olduğu için kalır. Alıcıya "Destekçi" masa süsü verilir.
5. **Görsel stil** — Faz 8'de Figma'da 2 seçenek gösterilir, kullanıcı seçer.
6. **Liderlik tablosu** — Google Play Games Services ile mi olsun (Faz 11, isteğe bağlı), yoksa yalnızca yerel en iyi skor mu? Varsayılan: önce yerel.

---

## 1. Kurallar (ajan için değişmez)

Bu proje `~/Games/mobile-game` şablonundan türetilir. Oradaki `CLAUDE.md` kuralları burada da geçerlidir. En önemlileri:

- **Veri kodda değil `data/*.json` içinde.** Kurlar, kurallar, banknot özellikleri, gün içerikleri, ekonomi sayıları, reklam sıklığı: hepsi JSON.
- **Mantık ve arayüz ayrı.**
  - Her kural önce `scripts/core/` altında, Node'a bağlı olmayan saf bir sınıf olarak yazılır (`RefCounted`) ve test edilir.
  - Sonra `scripts/ui/` bu sınıftan beslenir; arayüz hesap yapmaz.
- **SDK doğrudan çağrılmaz.** Reklam için `Ads`, satın alma için `IAP`, analitik için `Analytics` autoload'u kullanılır.
- **Sahne geçişi yalnızca `SceneManager` ile.**
  - Geri tuşu `handle_back()` ile ele alınır.
  - Her tam ekran sahne `SafeAreaContainer` içine kurulur.
- **Ekrandaki her metin `assets/translations/*.csv` içinde anahtardır.** Test, tanımsız anahtarı ve boş çeviriyi yakalar.
- **Gizli bilgi yok.** API anahtarı, keystore ve şifre hiçbir dosyaya veya commit'e yazılmaz. Release keystore'u kullanıcı oluşturur.
- **Dosya silmeden ve internetten bir şey indirmeden önce kullanıcıya sor.** Sorarken dosya adını, kaynağı, boyutu ve lisansı belirt.
- **Commit yalnızca kullanıcı onayıyla.**
  - Her faz sonunda `tools/verify.sh` geçmelidir.
  - Sonra ekran görüntüleri incelenir ve kullanıcıya faz raporu verilir.
  - Kullanıcı isterse küçük, mantıksal commit'ler atılır.
- Emin olmadığın Godot API'si için Context7 (`/godotengine/godot-docs`) kullan. Tahmin etme.

---

## 2. Oyun tasarımı

### 2.1 Dünya ve para birimleri (tamamen hayali)
Gerçek banknot görselleri **kullanılmaz**: hukuki risk taşır, mağaza incelemesinde de sorun çıkabilir. Tüm paralar ve ülkeler uydurmadır.

| Kod | Ad (TR) | Ülke | Kupürler | Ne zaman girer |
|---|---|---|---|---|
| `PL` | Pahalistan Lirası | Pahalistan (yerel) | 5, 10, 20, 50, 100, 200 | Gün 1 (ödeme parası) |
| `FED` | Federal Dolar | Birleşik Federasyon | 1, 5, 10, 20, 50, 100 | Gün 1 |
| `AVR` | Avrin | Avrasya Birliği | 5, 10, 20, 50, 100, 200 | Gün 2 |
| `STR` | Kral Sterlini | Kuzey Krallığı | 5, 10, 20, 50 | Gün 6 |
| `DNR` | Altın Dinar | Çöl Emirliği | 1, 5, 10, 50 | Gün 9 |
| `KRN` | Buz Kronu | Buzadası | 50, 100, 200, 500 | Gün 13 |

Her para biriminin `data/currencies.json` içinde şu özellikleri vardır:
- **Görünüm:** temel renk, desen kimliği, portre kimliği, boyut (mm, kupüre göre).
- **Seriler:** her serinin geçerlilik başlangıç ve bitiş tarihi (`valid_from`, `valid_until`) ve seri numarası biçimi. Biçim örneği: `"AA0000000"`.
- **Güvenlik özellikleri:** UV şerit rengi ve konumu, filigran şekli, mikro yazı.

### 2.2 Bir gün nasıl akar

```
SABAH (gazete)  →  VARDİYA (gişe, süreli)  →  AKŞAM (hesap + ev)  →  [geçiş reklamı?]  →  sonraki SABAH
```

1. **Sabah — gazete ekranı** (tek ekran, kaydırılabilir)
   - Manşet: hikaye ve enflasyon mizahı.
   - **Kur tablosu:** her para birimi için ALIŞ ve SATIŞ.
   - **Yeni kural** kutusu: bugün eklenen kural, kısa ve görselli.
   - **Bülten:** çalıntı seri numaraları, aranan kişiler. Belirli günlerden itibaren açılır.
   - Ailenin durumu (tek satır).
   - "Mesaiye başla" butonu.

2. **Vardiya — gişe masası** (oyunun %80'i burada geçer)
   - Oyun saati 09:00'dan 17:00'ye akar; gerçek süre `data/balance.json → shift_seconds` (varsayılan 270 sn).
   - Müşteriler sırayla gelir. Kapanış saatinde ekrandaki müşteri bitirilir, yeni müşteri gelmez.
   - **Bir müşteriyle işlem:**
     1. Müşteri pencerede belirir ve isteğini söyler (konuşma balonu). Örnek: "200 Federal bozdurmak istiyorum."
     2. Banknotları ve varsa belgeleri tezgâha koyar: kimlik, kaynak beyanı.
     3. Oyuncu bir banknota dokunur; **inceleme görünümü** açılır. Bu görünümde:
        - Büyüteçle bakılabilir: mikro yazı, seri numarası.
        - UV lambası açılabilir.
        - Banknota basılı tutulunca arkadan ışık verir ve filigran görünür.
        - Katalog ile yan yana karşılaştırma yapılabilir.
     4. Her banknot için oyuncunun üç seçeneği vardır:
        - **Kabul:** tezgâhta bırak.
        - **İade:** müşteriye geri sürükle (ör. yırtık banknot).
        - **El koy:** "SAHTE" damgası vurur.
     5. **Ödeme:**
        - Oyuncu kasadan (çekmece) yerel parayı ödeme tepsisine sürükler. Tepsi toplamı her zaman gösterilir.
        - Masadaki hesap makinesi kullanılabilir.
     6. **Karar butonları** (alt çubuk):
        - **Tamamla:** ödemeyi ver.
        - **Reddet:** her şeyi geri ver. Altta bir neden seçicisi açılır; nedenler o güne kadar açılmış kuralların listesidir.
        - **Polis:** tutanak tut; sahte para, aranan kişi veya kara para için.
   - Her işlemden sonra kısa bir geri bildirim gelir: doğruysa "ding", yanlışsa Papers, Please'teki gibi bir **uyarı fişi** basılır ve nedeni yazar.
   - **Hata payı:** günde ilk 2 hata yalnızca uyarıdır. 3. hatadan itibaren her hata maaştan kesilir (`balance.json → fine`).

3. **Akşam — hesap ve ev ekranı**
   - **Günün özeti:** işlem sayısı, doğru ve yanlış sayısı, maaş, prim, ceza, (varsa) kesinti.
   - **Ev giderleri:** kira (5 günde bir), yemek, ısınma, ilaç (hikaye durumuna bağlı). Her biri ödenir ya da ödenmez; Papers, Please'teki gibi onay kutusuyla seçilir. Ödenmeyen gider aile durumunu kötüleştirir.
   - **Birikim:** oyuncu birikimini PL olarak tutabilir ya da gün sonunda FED'e çevirebilir. Bu, enflasyona karşı korunma demektir ve oyunun meta mekaniğidir.
   - Ödüllü reklam teklifleri burada çıkar (2.6).
   - "Eve git" butonuna basılınca sonraki güne geçilir. Geçiş reklamı varsa burada gösterilir.

#### 2.2.1 Faz 3'te kesinleşen vardiya ve ev ekonomisi (kod: `shift.gd`, `household.gd`, `career.gd`)
- **Vardiya:** 270 gerçek sn = 09:00-17:00 oyun saati. Müşteri gittikten 2 sn sonra yenisi gelir; süre dolunca ekrandaki müşteri bitirilir, yeni müşteri gelmez. Müşterinin hükmü **geldiği andaki** kurla hesaplanır (13:00'ten sonra gelen gün ortası kurunu kullanır).
- **Hata sayımı İŞLEM başınadır:** bir işlemde birden çok hata olsa bile tek hatalı işlem sayılır. Günde ilk 2 hatalı işlem uyarıdır, 3.'den itibaren her hatalı işlem 30 PL ceza. Doğru işlem 15 PL prim. Maaş 305 PL; net ödeme 0'ın altına inmez. Bir günde 8 hatalı işlem = kovulursun.
- **Kasa her sabah başlangıç sayımına döner** (`balance.json → till.start_counts`); yabancı para stoğu gün İÇİNDE müşterilerle değişir. Kasa, oyuncunun GERÇEK hamlesine göre güncellenir (yanlışlıkla fazla ödenen para kasadan çıkar). Ödenemeyen hamle `till_short` hatasıdır.
- **Patronun kesintisi (8. günden):** kabul edilirse her "PL ödeyen" işlemde 5 PL eksik ödemek hata sayılmaz, gizli kâr olur (`skim_minor`). Müfettiş 14. günün sonunda yakalar: olasılık = min(%90, kesinti sayısı x %2), sonuç salt'a göre sabit tohumla verilir.
- **Giderler** (`data/household.json`): yemek 110 PL/gün, ısınma 50 PL/gün (3. günden), ilaç 70 PL/gün (anne 6. günde hastalanınca), kira 1.100 PL/5 günde bir (5., 10., 15. gün). Fiyatlar günde %1,5 bileşik artar, 5 PL'ye yukarı yuvarlanır; maaş sabit kalır. Ödenmeyen gider ruh halini düşürür (yemek -15, ısınma -10, ilaç -20); eksiksiz günde +5. Kira 2 kez ödenmezse **evden atılırsın**, ruh hali 0 olursa **aile köye gider**.
- **Döviz birikimi:** SATIŞ kuruyla alınır, ALIŞ kuruyla bozdurulur (makas kadar kayıp; enflasyona karşı koruma).
- **Denge sonucu** (`tools/balance_sim.gd`, 15 gün): mükemmel bot ~450-500 PL artırır ve hiçbir gideri aksatmaz; dikkatsiz bot (%15 hata) ~50 PL ile zor geçinir, bazen gider ödeyemez; hilekar bot ~170 PL fazla kazanır, 14. günde yaklaşık yarı yarıya yakalanır.

#### 2.2.2 Faz 4'te kesinleşen gişe masası arayüzü (kod: `scripts/ui/desk_screen.gd`, `scripts/core/desk_model.gd`)
- **Yerleşim (dikey):** üst çubuk (gün, saat, hata sayacı, bugünkü maaş) → müşteri penceresi (yüz, ad, isteği) → tezgâh (banknot kutuları + İade / Kabul / El koy bölgeleri) → ödeme butonları → araçlar (Kurlar & kurallar, Hesap, Katalog, UV lamba) → karar butonları (Tamamla / Reddet / Polis).
- **Banknotun kaderi:** her banknot varsayılan olarak KABUL (tezgâhta). Banknota dokununca inceleme sayfası açılır (büyük çizim, seri, boyut mm, portre; kabul/iade/el koy butonları; UV lambası); ya da banknot İade/Kabul/El koy bölgelerine **sürüklenir**. Karar → kader sadeleştirmesi `DeskModel.build_move`'da: Reddet = hepsi iade; Polis = kabul görünenler iade, el konulanlar kalır.
- **Ödeme = "hızlı ödeme" (plan 6. madde riski):** tutarı tuş takımıyla yazarsın (tam PL, 7 haneye kadar); kasa otomatik dizer, hesabı oyuncu yapar. Döviz alan müşteri için ayrıca döviz satırı çıkar. Tek tek banknot sayarak ödeme prototipte yok; M1 geri bildirimine göre eklenir.
- **Uyarı fişi:** karardan sonra müşteri penceresinin üstünde 4 sn (ya da dokunana kadar) görünür: doğruysa yeşil "Doğru! +15 PL"; ilk 2 hatada sarı UYARI + kalan cezasız hak; sonrasında kırmızı CEZA. Satırlar `Slip` sınıfından: yanlış karar (doğrusu), yanlış banknot kaderi, ödeme farkı, ilgili kural.
- **Araçlar:** Kurlar & kurallar (bugünün ALIŞ/SATIŞ kurları, açık kuralların listesi), Hesap (4 işlem), Katalog (para birimi başına kupür: renk, boyut, portre, UV rengi/konumu), UV lamba (3. günden; yalnızca doğru UV şerit parlar).
- **Reddet** önce "neden" sayfası açar (açık kuralların listesi); Polis nedensiz çağrılır (neden opsiyonel).
- **Prototip sınırı:** Gün 1-3 sonunda "prototip burada bitiyor" sayfası çıkar (`PROTOTYPE_LAST_DAY`). Gün sonu sayfası kısa bir özettir; giderler otomatik ödenir (`Career.affordable_expense_ids`). Sabah gazetesi, akşam evi ve kayıt Faz 5'te.
- **Henüz yok:** iki parmakla yakınlaştırma (inceleme sayfasında büyük çizim sabit), kimlik/beyan belgeleri (Faz 6), gerçek desen/portre/yüz görselleri (Faz 8), ses/titreşim.

#### 2.2.3 Faz 5'te kesinleşen gün akışı ve kayıt (kod: `game_session.gd`, `morning_screen.gd`, `evening_screen.gd`, `game_over_screen.gd`)
- **Akış:** Ana menü (Devam / Yeni oyun) → **Sabah** (gazete) → **Masa** (vardiya) → "Akşama geç" → **Akşam** → "Eve git" → sonraki **Sabah**. Hepsi `SceneManager.goto` ile (geçmiş tutulmaz).
- **Kayıt:** `GameSession` autoload'u kariyeri taşır. Her SABAH ekranı açılınca ve her akşam "Eve git"te `SaveManager.data["career"]` yazılır. Vardiya ya da akşam ortasında uygulama kapanırsa oyun o günün sabahına döner (kazanç/harcama kaydedilmez). Yeni oyun, kayıt varsa onay ister.
- **Sabah gazetesi** (`Newspaper.build`): manşet (15 günlük şaka metni; hikaye içeriği Faz 7'de değişecek), kurlar (ALIŞ/SATIŞ + dünkü değişim %), yeni kural kutusu (bugün açılan kurallar, yoksa "yeni kural yok") + bugün verilen araç, bülten (çalıntı seri aralıkları, aranan yüzler; ilgili kural açılınca), aile durumu (ruh haline göre tek satır), nakit, kira günüyse kira tutarı, dün ödenmeyen giderler. Kurlar ve bülten vardiyayla aynı tohumdan gelir.
- **Akşam** (`EveningPlan`): günün özeti (müşteri, hata, maaş, prim, ceza, varsa patron kesintisi), ev giderleri (her biri seçilir; nakdi yetmeyen seçilemez; varsayılan: yetenleri öncelik sırasıyla seçili), döviz birikimi (100 / 500 / 1.000 PL'yi FED'e çevir, tümünü bozdur; makas kadar kayıp), aile ruh hali. Maaş akşam başlayınca nakde girer (bir kez). "Eve git" giderleri öder, kovulma/müfettiş/ev kontrolünü yapar, günü ilerletir.
- **Geri tuşu:** ana menü = çık; sabah = "Ana menüye dönülsün mü?" onayı; masa = vardiyayı duraklatma sayfası (kapatınca devam; "Ana menü" bu sabaha döner); mesai bitti ve akşam = bir şey yapmaz; oyun bitti = ana menü.
- **Oyun bitti ekranı:** kovuldu / evden atıldın / aile köye gitti / müfettiş. Sabah anlık görüntüsü varsa "Günü tekrar oyna" (Faz 10'da arkasına ödüllü reklam gelecek). Prototip sınırı: Gün 3 akşamından sonra "Devamı gelecek" ekranı (`GameSession.LAST_PLAYABLE_DAY`; Faz 6-7'de büyür).

#### 2.2.4 Faz 6'da kesinleşen araçlar, belgeler ve kural arayüzleri (kod: `desk_screen.gd`, `banknote_view.gd`, `doc_tile.gd`, `document_views.gd`)
- **Araç çubuğu** (2 satır): Kurlar & kurallar, Hesap, Katalog her zaman; **UV lamba** 3. günden (patron verir); **Kasa** (kupür sayıları) R_SELL_FOREIGN açılınca (4. gün, ücretsiz); **Büyüteç** (60 PL, 7. günden) ve **Kur hesaplayıcı** (200 PL, 4. günden) akşam dükkanından alınınca; **Para sayma makinesi** (120 PL, 4. günden) alınınca ayrı düğme yok, tezgâhta "Sayılan: 110 DNR" toplamı görünür. Satın alınmamış araç **görünmez**.
- **Banknot çizimi:** yırtık banknotun kopuk kısmı eksik (tırtıklı) çizilir; bantlı banknotta üst üste bant şeridi ve çatlak çizgisi vardır. UV lambası yalnızca (varsa, doğru renkte) UV şeridi parlatır. **Filigran:** inceleme sayfasında "Işığa tut" düğmesi BASILI TUTULUNCA arka ışık yanar ve (varsa) filigran şekli görünür (R_WATERMARK açıkken). **Büyüteç:** mikro yazıyı okunur yapar; kapalıyken yalnızca noktalı çizgi görünür; metin ayrıca sayfada da yazılıdır. Seri numarası büyüteçsiz de okunur (7. gün kuralı için).
- **Belgeler:** müşterinin kimliği ve kaynak beyanı tezgâhta sarı kutu olarak durur; dokununca ayrıntı sayfası açılır (fotoğraf = yüz numarası, ad, numara, imza, son geçerlilik günü / beyan edilen tutar). Oyuncu kendi karşılaştırır; hiçbir kontrol otomatik yapılmaz. Kimlik no kuralı kural metninde yazılı: "son hane = ilk on hanenin toplamının son hanesi".
- **Bülten:** "Kurlar & kurallar" sayfasında üçüncü sekme (çalıntı seri aralıkları, aranan yüzler); bülten boşken sekme yoktur.
- **Katalog** artık seri geçerlilik günlerini, filigran şeklini ve doğru mikro yazıyı da gösterir.
- **Gün ortası kur bildirimi:** R_MIDDAY_RATE açıkken saat 13:00'ü geçince üstte "13:00 — Kurlar güncellendi!" şeridi 4 sn görünür; kurlar sayfası yeni kurları gösterir.
- **Döviz alan müşteri:** konuşma balonu "X FED satın almak istiyorum"; ödeme satırları PL (para üstü) ve döviz.
- **Akşam dükkanı:** bugün alınabilecek araçlar "Satın al" düğmesiyle listelenir; nakit yetmeyenler pasif; alınca nakit azalır ve gerekirse en düşük öncelikli gider seçimleri düşer.
- **Tezgâh düzeni:** banknot sayısına göre 2 / 3 / 4 sütun ve küçülen boyut; tezgâh kaydırılabilir (kararlar ve araçlar hep ekranda kalır). Neden listesi 13 kurala kadar uzar; sığmayan kısım kaydırılır.
- **Denge:** mükemmel bot tüm araçları (380 PL) alıp 15 günü gider aksatmadan bitirir, sonunda ~70-115 PL kalır (araçsız ~450-500 PL).
- **Oynanabilir son gün:** 13 (`GameSession.LAST_PLAYABLE_DAY`); 14-15 (müfettiş, final) hikaye içeriğiyle Faz 7'de.

#### 2.2.5 Faz 7'de kesinleşen hikaye (kod: `story_*.gd`, `endings.gd`, `shift.gd`, `desk_screen.gd`; veri: `data/story/`)
- **Olay (beat)** = gün dosyasındaki bir sahne: `after` kadar müşteri servis edildikten sonra (0 = vardiya başı; en çok 5) çıkar, vardiyada bir kez. Olay müşteriden ÖNCE oynanır: masada `StorySheet` açılır, zaman durur, geri tuşu kapatmaz. İçeriği: konuşan karakter (yüz + ad), 1-3 satır, ya "Devam" ya da seçenekler. Koşullu olaylar (`requires`: bayrak/sayaç) aynı günde alternatif sahneler verir (örn. Hayri'nin hediyesi ya da soğukluğu).
- **Senaryolu müşteri:** olay `customer: {scenario, expect}` taşırsa o gün normal senaryo üretici (aynı doğruluk garantisi) sabit karakter kimliğiyle (ad, yüz 900+, kimlik/beyan belgesi dahil) müşteri kurar; `expect` verilen hükme çıkana dek denenir. Olay müşterisinin doğru cevabı hep kurallardan gelir; hikaye kuralı DEĞİŞTİRMEZ, oyuncuya kuralı eğme cazibesi sunar.
- **Seçenek / sonuç etkileri:** seçim müşteriden önce yapılır (`choice.options`: etki, etiket `bribe|skim|ally|evidence|escape|honest`, istenirse `requires` + `savings_min`; kilitli seçenek "(olanaksız)" ile pasif görünür; her seçimde koşulsuz bir seçenek zorunlu). `on_decision` etkileri oyuncunun KARARINA göre işler (complete/reject/police). Etkiler: `flags`, `counters`, `cash_pl` (zarf: akşam maaşla nakde girer, akşam özetinde "Zarf" satırı), `savings` (döviz birikimi), `mood`. Patronun kesintisi kabul edilince aynı vardiyada işlemeye başlar.
- **Hikaye çizgisi (15 gün):** 1 Rıza karşılar · 2 Hayri Amca (enflasyon) · 3 UV lamba · 4 Deniz (gazeteci) tanışır · **5 Tilki, 200 PL zarf** (kimliksiz müşteri; tamamlarsan `tilki_helped`) · **6 Hayri'nin eski seri banknotu** (kuralı eğersen `hayri_helped`; anne hastalanır) · 7 bülten · **8 Rıza'nın 5 PL kesintisi** · **9 Deniz: seri numaralarını not et** (`deniz_ally`) · **10 Tilki, 350 PL zarf** (imzası uymayan beyan, polis gerekir; polisi ararsan `tilki_reported`) · 11 Hayri teşekkür eder (+60 PL, müfettiş sinyali) ya da soğuk · **12 Deniz: kanıt** (`deniz_evidence`; seçenek için `tilki_reported ≥ 1` gerekir) · 13 patron huzursuz, Tilki pasaportu duyurur (zarf aldıysan) · **14 şapkalı müşteri = müfettiş Nalan** (bantlı banknot, doğru hüküm = `complete`; doğru yaparsan `inspector_pleased`) · **15 Tilki'nin pasaportu** (10 FED + `tilki_money ≥ 1`), Deniz'in son fırsatı, final. Her gün 1 akşam mektubu (Selma); ilk koşulu sağlanan mektup gösterilir, son mektup koşulsuz.
- **Müfettiş (14. gün akşamı):** yakalanma olasılığı = min(90, `skim_count` x 2 + `tilki_helped` x 40 + `tilki_money` x 20); `deniz_evidence` varsa Tilki terimleri silinir (tanık); `inspector_pleased` varsa yarıya iner. Sonuç salt'a bağlı sabit tohumla çekilir (aynı oyun aynı sonucu verir). Sayılar `data/balance.json` `story`.
- **Sonlar** (`data/story/endings.json`, ilk eşleşen kazanır; oyun içi bitişler `game_over`'a bakar): `fired` (kovuldun / evden atıldın / aile köye gitti, "Günü tekrar oyna" sunulur) · `arrested` (müfettiş yakaladı) · `informant` (`deniz_evidence`) · `escape` (`passport`) · `honest` (kesinti kabul edilmedi, `tilki_money` ve `tilki_helped` 0) · `muddle` (yedek: **Gri Memur** — planda olmayan 6. son; kesinti/zarf alıp yakalanmayanlar için, "Dürüst Memur" yalan olmasın diye eklendi). Görülen sonlar kayıttan bağımsız tutulur (`SaveManager.data["endings_seen"]`); son ekranında "Bulunan sonlar: n / 6" yazar.
- **Botlar:** `perfect` → honest, `ally` → informant, `escaper` (zarflar + 14. akşam FED alır + pasaport) → escape, `helper` (zarf alır, Tilki ve Hayri'ye kuralı eğer) → muddle ya da arrested (olasılık), `cheater` → muddle/arrested. Kusursuz bot hikayeli oyunda da hatasız, ~115 PL nakitle biter.
- **Denetçi:** `StoryValidator` (`tools/validate_content.gd`, `test_story`): yapı, karakter, TR+EN metin, koşul/etki anahtarları, her olay müşterisinin 5 farklı tuzla beklenen hükümle kurulabilmesi ve motorla örtüşmesi, koşulsuz mektup/son/seçenek.
- **Bilinçli sınırlar:** olaylar vardiyadan 5 müşteri sonrasına kadar gelir (çok yavaş oyuncu da görsün); "devalüasyon" 15. günde yalnızca manşet esprisidir (kur mekaniği değişmedi); karakter yüzleri hâlâ prototip daireleri (Faz 8).

#### 2.2.6 Faz 8'de kesinleşen görsel kimlik ve his (kod: `build_theme.py`, `feel.gd`, `face_view.gd`, `banknote_view.gd`)
- **Seçilen stil: A · Kâğıt Ofis** (Figma: [Döviz Bürosu — Arayüz](https://www.figma.com/design/bYH8tUCWaIUEYPmCL0sGav), B "Gece Vardiyası" elendi). Krem kâğıt zemin (#F1E7D3), mürekkep metin (#2B2A33), onay yeşili (#3F7D4E), reddet sarısı (#E0A93B), polis kırmızısı (#B8362E), mürekkep mavisi (#2E5B8A); müşteri camı koyu yeşil çerçeveli, tezgâh yeşil keçe, kimlik/beyan sarı kâğıt. Köşeler küçük (10-16 px), düğmelerde sert "damga" gölgesi, kartlarda ince kâğıt kenarı. Font Baloo 2 (Türkçe tam). Figma'daki iki kusur (B menüsünde gerçek ₺, 100'lük rakam taşması) A'yı etkilemedi; Figma'da düzeltilmedi (MCP çağrı sınırı).
- **Yüzler:** resim değil, kimlikten türeyen çizim (ten 5, saç rengi 6, saç biçimi 4, gözlük, bıyık, ağız, göz aralığı). Aynı yüz kimliği her yerde aynı yüzü verir (müşteri, kimlik fotoğrafı, aranan listesi). `#numara` altyazısı karşılaştırma anahtarı olarak kalır. `make_faces.py`/SVG üretimi gerekmedi.
- **Banknot:** iç çerçeve, portre çevresinde kılcal halkalar ve para birimine özgü zemin deseni (PL yatay çizgi, FED çapraz, AVR nokta, STR dalga, DNR baklava, KRN kafes). Desenler ince; UV/filigran/mikro yazı gözlemi (`observe`) değişmedi. Gerçek portre çizimleri yok (portre = "pN" etiketi).
- **His:** müşteri gelişinde zil + banknot/belge sırayla "pat" (alfa+ölçek, yerleşimi bozmaz); karar damgası (ONAYLANDI / RED / POLİS) + hafif ekran sarsıntısı (hatada daha güçlü) + damga sesi + titreşim (doğruda 25 ms, hatada 70 ms) + doğruysa "+prim" yazısı ve para sesi, hatada hata sesi; ana menüde banknot ve KABUL damgalı amblem; gazetede kâğıt dokusu. Sesler ElevenLabs'ten (`bell, note_drop, stamp, coin, error, page`; `page` henüz bağlı değil). Müzik yok.
- **Bilinçli sınırlar:** gazete başlığı Baloo 2 (Figma'daki Fraunces başlık için font indirmek gerekir, kullanıcı onayı bekler); modüler SVG portre/ikon seti yok; menüde Günün Kuru / Sonsuz / Market yer tutucu (Faz 9-10); Figma'da yalnızca 2 stil önerisi var, A'nın son hâli oyunda.

#### 2.2.7 Gişe sahnesi ve fiziksel etkileşim (kullanıcı isteği: Papers, Please / Buckshot Roulette atmosferi)
- **Atmosfer:** masa ekranı artık loş ve kasvetli: yeşilimsi gri duvar, çelik pencere çerçevesi, kehribar LCD üst çubuk, pirinç isim plakası, yıpranmış ahşap masa üstünde tezgâh lambasının sıcak ışık havuzu, kenar kararması (vinyet), ara sıra titreyen floresan, havada toz, cam parlaması ve çizikler. Menü, gazete, akşam, son, mod sonucu, market ve ayarlar ekranları da aynı koyu havaya taşındı (kullanıcı onayıyla): `ScreenBackdrop` (loş duvar, tavandan sarkan lamba ve sıcak ışık havuzu, süzülen toz) üstünde kartlar/gazete "masadaki kâğıtlar" olarak krem kalır; doğrudan zemine yazılan metinler `BoothTitle/BoothHeading/BoothBody/BoothMuted` (kehribar/krem). Gazete künyesine kâğıt dokusu, ortam uğultusu tüm ekranlarda sürekli çalar (`Feel.start_ambience`).
- **Müşteri:** kapıdan sağdan yürüyerek gelir (adım sallantısı + ayak sesi), pencerenin ardında durur; konuşma balonu harf harf yazılır, her iki harfte müşteriye özgü tizlikte "ses" bipi çalar (kodla üretilen kısa dalga; dosya yok), ağzı konuşurken oynar; balona dokunmak cümleyi bitirir. Karar verilince sola yürüyüp gider, kâğıtlar yuvaya geri kayıp silinir.
- **Fiziksel nesneler:** banknot/belge pencere yuvasından kayarak gelir ("pat"), hafif çarpık ve kaymış durur; sürüklenince kalkar, yatar, üstte durur, bırakıldığı yerde kalır (masa dışına çıkamaz). Tepsiler (İade / Kabul / El koy) masanın altında; banknotu tepsiye bırakmak kaderini belirler ve banknot küçülerek tepsiye oturur; tepsiden alıp masaya bırakmak kabul eder. Belgeler taşınır ama karar vermez. Dokunma hâlâ inceleme sayfasını açar.
- **Damgalar:** Tamamla/Reddet/Polis artık masanın önündeki üç fiziksel damga (ahşap tutamaklı); basınca kalkıp iner, fişe mühür izi (ONAYLANDI/RED/POLİS) basılır, ekran sarsılır, damga sesi çalar. Ödeme düğmeleri fişin içinde. Reddet yine neden sayfasını açar.
- **Ses:** ortam uğultusu (döngü), ayak sesi, kâğıt sürtme, banknot düşme, damga, nakit kayması, zil, para, hata; hepsi ElevenLabs (anahtar yazdırılmaz). Müzik yok.
- **Test/performans:** `Feel.instant` (ekransız = true) animasyonları anında bitirir, böylece oyun testleri deterministik kalır; gerçek zamanlı animasyonlar `test_booth` içinde `Feel.instant = false` ile ayrıca sınanır. Atmosfer her karede yalnızca ~25 daire ve 4 şerit çizer.
- **Bilinçli sınırlar:** müşteri figürü tek parça çizim (yüz + palto), el/kol animasyonu yok; damgayı sürükleyerek fişe vurma yok (dokunma = vurma, mobil güvenilirliği için); Figma'daki A/B önerilerine bu gişe sahnesi eklenmedi (Figma çağrı sınırı), kaynağı kod ve ekran görüntüleridir (`tools/style_shots.gd`).

### 2.3 Kurallar (her gün biri eklenir)
Her kural `data/rules.json` içinde bir kayıttır: `id`, `from_day`, `check` (motorun bildiği kontrol türü), parametreler, metin anahtarları, neden metni, gerekli araç.

| Gün | Kural kimliği | Ne ister | Hile türü (sahte üretici) |
|---|---|---|---|
| 1 | `R_EXCHANGE` | FED'i ALIŞ kurundan boz. Ödeme 5 PL'ye aşağı yuvarlanır. | — (tüm paralar gerçek; öğretici gün) |
| 2 | `R_CATALOG` | Renk, boyut ve desen kataloğa uymalı. AVR eklenir. | yanlış renk tonu, yanlış boyut, yanlış portre |
| 3 | `R_UV` | UV şerit yoksa ya da yanlış renkteyse sahtedir. | UV şerit eksik veya yanlış renk |
| 4 | `R_SELL_FOREIGN` | Müşteri PL verip döviz alabilir (SATIŞ kuru). Kasada yetecek döviz yoksa "kasada yok" nedeniyle reddet. | hesap tuzakları |
| 5 | `R_ID_LIMIT` | 1.000 PL karşılığını aşan işlemde kimlik gerekir. Kimliğin süresi geçmemiş, fotoğrafı müşteriye uymalı. | sahte kimlik, süresi geçmiş kimlik, başkasının kimliği |
| 6 | `R_SERIES` | AVR'nin eski serisi bugünden itibaren geçersiz. STR eklenir. | eski seri |
| 7 | `R_STOLEN` | Bültendeki seri numarası aralıkları el konulur, polis çağrılır. | çalıntı seri |
| 8 | `R_TORN` | Yarıdan azı kalmış banknot iade edilir. Bantlı ama tam banknot geçerlidir. | yırtık, bantlı |
| 9 | `R_WATERMARK` | Filigran şekli kataloğa uymalı. DNR eklenir. | filigran yok veya yanlış |
| 10 | `R_SOURCE` | 5.000 PL üzeri işlemde kaynak beyanı şart: tutar ve imza kimlikle uyuşmalı. | eksik beyan, tutar uyuşmazlığı |
| 11 | `R_MIDDAY_RATE` | Saat 13:00'te kur güncellenir; işlem saatindeki kur kullanılır. | eski kurla hesap tuzağı |
| 12 | `R_WANTED` | Bültendeki aranan yüz gelirse polis çağrılır. | aranan kişi |
| 13 | `R_MICROTEXT` | Mikro yazı büyüteçle okunur, hatalıysa sahtedir. KRN eklenir. | mikro yazı hatası |
| 14 | — | Müfettiş günü: kılık değiştirmiş müfettişler gelir. Kural yok, hepsi birden test edilir. | hepsi |
| 15 | — | Final: devalüasyon günü ve hikayenin doruğu. | hepsi |

**Ajan için not:** `RuleEngine` her müşteri için **beklenen sonucu** üretir:
- her banknotun kaderi: kabul, iade ya da el koy;
- işlem kararı: tamamla, reddet ya da polis;
- doğru ödeme miktarı;
- karar neden(ler)i.

Oyuncunun hamlesi bu beklenen sonuçla karşılaştırılır. Böylece her müşteri **kesin doğru cevabı olan bir bulmaca** olur ve botla test edilebilir.

#### 2.3.1 Faz 2'de kesinleşen motor kararları (kod: `scripts/core/rule_engine.gd`)
Plan bazı noktaları açık bırakmıştı; motor şöyle davranır ve testlerle sabittir:

- **Öncelik:** banknot başına el koy > iade > kabul; işlem başına polis > reddet > tamamla.
- **Polis** (ödeme yok; sahte/çalıntı banknota el konur, kalanlar iade): sahte para (`R_CATALOG`/`R_UV`/`R_WATERMARK`/`R_MICROTEXT`), çalıntı seri (`R_STOLEN`), aranan yüz (`R_WANTED`), **sahte kimlik** (kontrol hanesi tutmayan numara, `R_ID_LIMIT`), kaynak beyanı **uyuşmazlığı** (tutar, imza ya da ad, `R_SOURCE`). Polis kararında yalnızca polis nedenleri listelenir.
- **Reddet** (her şey iade, neden seçmek zorunlu): kimlik yok / süresi geçmiş / başkasının (`R_ID_LIMIT`), kaynak beyanı yok (`R_SOURCE`), kasa tutarı tam ödeyemiyor (`R_SELL_FOREIGN`), kabul edilebilir banknot kalmadı (iade kuralları `R_TORN`/`R_SERIES`; döviz alan müşterinin PL'si yetmezse `R_EXCHANGE`).
- **Tamamla:** kabul edilen banknotlar üzerinden ödeme; iade kaderli banknotlar (eski seri, yırtık) müşteriye geri verilir. Tutar tüm banknotların toplamından hesaplanır, tek tek değil.
- **Eşikler** (`R_ID_LIMIT` 1.000 PL, `R_SOURCE` 5.000 PL) işlem değeri bu sınırı **aşarsa** devreye girer (eşit değilse gerekmez). İşlem değeri, banknotların hepsinin (sahte olanlar dahil) kuruna göre PL karşılığıdır.
- **Kimlik** son geçerli günü dahil geçerlidir (`expiry_day >= bugün`). **Yırtık:** `remaining_percent < 50` iade; tam 50 geçerli; bantlı ama tam banknot geçerli.
- **Kasa:** `R_SELL_FOREIGN` açıkken ödemeler, kabul edilen banknotlar kasaya girdikten sonra eldeki kupürlerle TAM tutar olarak yapılabilmeli (3 FED için 1'lik yoksa ödenemez). Yabancı para stoğu bilerek az: müşterilerin sattığı döviz kasayı doldurur (`balance.json → till.start_counts`).
- **Kapalı kural görmezden gelinir:** henüz açılmamış kuralın yakalayacağı sahtelik tek başına suç sayılmaz (banknot kabul edilir).
- **Gün ortası kur** yalnızca `R_MIDDAY_RATE` açıkken (11. gün) ve saat 13:00'ten sonra geçerlidir.

### 2.4 Araçlar (oyun içi parayla açılır, gerçek parayla **satılmaz**)

| Araç | Nasıl gelir | İşlev |
|---|---|---|
| Hesap makinesi | Başta var | Basit dört işlem |
| Katalog | Başta var | Banknotların doğru görünüşü |
| UV lamba | Hikaye, Gün 3 (patron verir) | UV katmanını açar ve kapatır |
| Büyüteç | Gün 7, 60 PL | Mikro yazı, net seri numarası |
| Para sayma makinesi | Akşam dükkanından 120 PL | Tezgâhtaki dövizin toplamını gösterir |
| Kur hesaplayıcı | Akşam dükkanından 200 PL | Döviz tutarını girince PL karşılığını hesaplar |

Fiyatlar `data/tools.json` dosyasındadır ve botla dengelenir.

### 2.5 Hikaye, karakterler ve sonlar
Hikaye **veriyle** kurulur: `data/story/day_01.json` … `day_15.json`. Her gün dosyası şunları tanımlar:
- o günün rastgele müşteri sayısı ve zorluğu;
- belirli sıraya konmuş **senaryolu müşteriler**: kim, ne getiriyor, ne söylüyor, hangi seçim neyi tetikliyor;
- gazete manşeti ve haberleri;
- olaylar: patron mesajı, akşam mektubu.

**Karakterler:**
- **Rıza Bey (patron):** kâr ister. Gün 8'de "her işlemden 5 PL kes, kimse anlamaz" diye önerir. Kabul edersen gizli kâr kazanırsın, ama Gün 14'teki müfettiş yakalayabilir.
- **Tilki:** kara para ağı. Gün 5, 10 ve 15'te büyük işlem ve rüşvet teklif eder. Gün 15'te "yurt dışı pasaportu" teklif eder.
- **Nalan Hanım (müfettiş):** Gün 14'te kılık değiştirip gelir.
- **Deniz (gazeteci):** Tilki'yi araştırıyor ve kanıt ister. Seri numaralarını not edip ona verebilirsin.
- **Hayri Amca (emekli):** her hafta maaşını bozdurur, enflasyondan dertlidir. Duygusal ikilemleri o taşır.
- **Aile:** eş, çocuk (Ece) ve anne. Anne Gün 6'da hastalanır ve ilaç gideri başlar.

**Sonlar** (`data/endings.json`). Her son, hikaye bayraklarına ve sayaçlara bakan koşullarla seçilir:
1. **Dürüst Memur:** kural dışına çıkmadın, ailen ayakta.
2. **Kaçış:** yeterince FED biriktirdin ve Tilki'nin pasaportunu aldın.
3. **Tutuklandı:** patronun kesintisine ya da Tilki'ye yardım ettin, müfettiş yakaladı.
4. **Muhbir:** Deniz'e kanıt verdin, ağ çöktü, kahraman oldun.
5. **Kovuldu:** hikaye ortasında "oyun bitti" durumu. Çok fazla ceza aldın ya da kira 2 kez ödenmedi ve evden atıldın. Bu sonda "Günü tekrar oyna" teklif edilir.

Ton: kara mizah, ama ölüm ve şiddet yok. Mağaza yaş derecelendirmesi düşük kalmalı (hedef PEGI 7–12). Aile en kötü durumda "köye, anneanneye gitti" olur.

### 2.6 Para kazanma (kullanıcının seçtiği model)

**Ödüllü reklamlar** — hepsi isteğe bağlı, hiçbiri ilerlemek için şart değil:

| Yer (`placement`) | Nerede | Ödül | Sınır |
|---|---|---|---|
| `rate_tip` | Akşam | "Bankadaki tanıdığı ara": yarın FED'in yükseleceği mi düşeceği mi ve yaklaşık yüzdesi | Günde 1 |
| `double_pay` | Akşam | Günün maaş ve primini 2 katına çıkarır (cezaları değil) | Günde 1 |
| `overtime` | Vardiyada, son 60 sn'de | +45 sn mesai | Günde 1 |
| `retry_day` | Oyun bitti veya kovuldu ekranı | Günü baştan oyna (sabah durumuna dön) | Sınırsız |
| `daily_retry` | Günün Kuru sonucu | İkinci resmi deneme | Günde 1 |
| `endless_continue` | Sonsuz mod, can bitince | +1 can | Koşu başına 1 |

**Geçiş reklamları** — ayarlar `data/ads.json` dosyasında:
- Yalnızca **akşam → sabah** geçişinde, Günün Kuru sonrasında ve Sonsuz koşu bitiminde gösterilir.
- **Vardiya ortasında asla** çıkmaz.
- Gösterim koşullarının hepsi sağlanmalı:
  - Reklamları Kaldır alınmamış.
  - Hikaye günü ≥ 3.
  - Son geçiş reklamından bu yana ≥ 2 gün geçmiş.
  - Herhangi bir reklamdan bu yana ≥ 180 sn geçmiş.
  - Bu oturumda ≥ 120 sn oynanmış.
  - İlk oturum değil.
- Bu karar saf bir sınıfta verilir: `AdPolicy` (`scripts/core/ad_policy.gd`), tam testli.

**Banner reklam yok.** Dikey ekranda oynanışı bozar.

**Satın alma** (`data/products.json`):
- `no_ads`: non-consumable, varsayılan 2.99 USD.
  - Geçiş reklamlarını kalıcı olarak kapatır.
  - "Destekçi" masa süsü verir (küçük bir saksı ve isim plakası).
  - Ödüllü reklamlar isteğe bağlı olarak kalır (karar 4).
- **Geri yükleme:**
  - Açılışta mağazadaki sahiplikler sorgulanır.
  - Market ve Ayarlar ekranlarında "Satın alımları geri yükle" butonu bulunur.
  - Sahiplik kayıt dosyasına da yazılır, ama doğruluk kaynağı mağazadır.
- **Google Play Billing kuralı:** satın alma **3 gün içinde acknowledge edilmezse iade edilir.** Gerçek sağlayıcı bunu yapmak zorunda (Faz 11).

**Denge kuralı (test edilir):** reklam hiç izlemeyen, kurallara uyan iyi bir oyuncu hikayeyi aileyi kaybetmeden bitirebilmelidir. Reklamlar rahatlık sağlar, zorunluluk yaratmaz.

#### 2.6.1 Faz 10'da kesinleşen para kazanma kararları (kod: `monetization.gd`, `ad_policy.gd`, `market_screen.gd`)
- **Geçiş reklamı** yalnızca "oyun birimi" aralarında sorulur: hikayede akşam → sabah ("Eve git"), Günün Kuru/Sonsuz sonuç ekranı. Oyun bitti ekranının önüne konmaz, vardiya ortasında asla. Koşullar (hepsi): `no_ads` yok · hikayede ≥3. güne ulaşılmış · son geçiş reklamından bu yana ≥2 oyun birimi (biten hikaye günü ya da mod koşusu) · herhangi bir reklamdan (ödüllü dahil) ≥180 sn · bu oturumda ≥120 sn · ilk oturum değil (uygulama ≥2. açılış). Test için: ilk açılışta ve ilk 2 dakikada geçiş reklamı görünmez; ödüllü reklamlar hemen çalışır.
- **Ödüllü yerler ve sınırlar:** `rate_tip` (akşam: FED'in yarınki yönü ve yaklaşık %, günde 1), `double_pay` (maaş + prim 2 kat, ceza bir kez düşer, günde 1), `overtime` (+45 sn; son 60 sn'de masada düğme, mesai bitince sayfada; günde 1; modlarda yok), `retry_day` (oyun bitti ekranında "Günü tekrar oyna" artık reklam arkasında, sınırsız; iptal olursa ekran kalır), `daily_retry` (resmi deneme tükenince, tarih başına 1 ek), `endless_continue` (canlar bitince +1 can, koşu başına 1). Reklam hazır değilse düğme pasif "Reklam şu an yok" yazar; sınır dolunca teklif hiç görünmez; hata gösterilmez. İptal edilen ya da başarısız reklam ödül vermez ve teklif durur.
- **Satın alma:** `no_ads` (non-consumable, mock fiyat $2.99): geçiş reklamını kalıcı kapatır, masaya Destekçi saksısı koyar; ödüllü reklamlar kalır. Sahiplik `SaveManager.data["purchases"]`'a yazılır, açılışta `IAP.restore_purchases()` ile mağazadan birleştirilir (mağaza doğruluk kaynağı; yerel kayıt silinse geri gelir). Market ve Ayarlar'da "Satın alımları geri yükle".
- **Dev sağlayıcılar:** debug sürümde sahte reklam penceresi çıkar ("TEST REKLAMI"; ödüllü: Ödülü al / İptal) ve sahte mağaza anında onaylar; headless testlerde anında ve etkileşimsizdir. Yayın sürümünde (Faz 11) gerçek sağlayıcılar takılacak; o zamana dek release derlemede reklam/satın alma çalışmaz (taban sınıflar).
- **Denge:** reklam hiç izlemeyen mükemmel bot hikayeyi hâlâ bitirir (`test_bot_balance`, `test_story`). `double_pay` günlük maaşı ikiye katladığı için ekonomiyi reklam izleyenler lehine esnetir; bilinçli bir rahatlık, zorunluluk değil.
- **Analytics olayları:** `day_start`, `day_end`, `mistake`, `ending`, `ad_offer_shown`, `ad_rewarded`, `interstitial_shown`, `iap_purchase`, `mode_start`. Onay (`consent_given`) yoksa gönderilmez; `Analytics.recent` yalnızca bellekte tutulur.

#### 2.6.2 Faz 11'de kesinleşen gerçek SDK kararları (kod: `admob_ads_provider.gd`, `playbilling_iap_provider.gd`, `monetization.gd`, `consent_sheet.gd`)
- **Eklentiler** (kullanıcı onayıyla indirildi, MIT): AdMob v7.0 (27.05.2026, Godot 4.7 ile test edilmiş; Android zip ~266 KB) ve Google Play Billing 3.3.0 (Billing Library 9.1.0, Godot 4.2+, ~43 KB). Gradle bağımlılıkları (play-services-ads 24.9.0, billing-ktx 9.1.0, UMP) ilk derlemede Google Maven'dan gelir. APK ~99 MB'a çıktı. Manifeste AD_ID, ACCESS_NETWORK_STATE, `com.android.vending.BILLING` izinleri birleşir; `permissions/internet` üç preset'te açıldı.
- **Test reklamları:** `mode=test` iken yalnızca Google'ın herkese açık test kimlikleri (uygulama `...~3347511713`, ödüllü `.../5224354917`, geçiş `.../1033173712`). Emülatörde (API 36) SDK başlatıldı, ödüllü ve geçiş test reklamları yüklendi (logcat). Gerçek kimlikler yalnızca kullanıcıdan gelir; boşken `mode=real` sessizce test'e düşer ve `sync_ads_config.py` hata verir.
- **Onay (UMP):** açılışta `update_consent_info`; gerekliyse form yüklenip gösterilir, kapanınca (ya da hata olursa) SDK başlar. Kişiselleştirme kullanıcının kararına bağlı (ret = kişiselleştirilmemiş reklam). Bizim `ConsentSheet` (anonim analitik + kişiselleştirme) ilk açılışta bir kez sorulur, Ayarlar > Gizlilik seçenekleri'nden değiştirilir.
- **Play Billing:** `no_ads` INAPP ürünü; PURCHASED → acknowledge → ödül (PENDING'de ödül yok); açılışta ve "geri yükle"de sahiplik sorgusu, onaysız satın almalar onaylanır; `ITEM_ALREADY_OWNED` başarı sayılır; fiyat `formatted_price`'tan. **Gerçek satın alma denemesi için kullanıcının Play Console'u gerekir** (uygulama + `no_ads` ürünü + lisans test kullanıcısı + dahili test kanalına yüklenmiş imzalı derleme); yan yüklenen debug APK'da mağaza çalışmaz, bu yüzden `providers.play_billing` şimdilik false.
- **Yayın öncesi (kullanıcı):** gerçek AdMob uygulama + reklam birimi kimlikleri, Play Console'da veri güvenliği formu (reklam kimliği kullanımı, anonim analitik), gizlilik politikası URL'si, hedef kitle/yaş derecelendirmesi (çocuklara yönelik DEĞİL; içerik sınıfı PG), paket adı kesinleşmesi, release keystore.
- **Bilinen sınır:** Play Games liderlik tablosu yapılmadı (isteğe bağlıydı). `tools/android_run.sh`'ın `monkey` ile tek rastgele dokunuşu menüde bir düğmeye basabilir.

### 2.7 Modlar

- **Hikaye:** 15 gün, sürekli kayıt. Her sabah otomatik kaydedilir. Ana menüde "Devam" ve "Yeni oyun" vardır.
- **Günün Kuru:**
  - Hikayede Gün 5'ten sonra açılır.
  - Tohum UTC tarihten üretilir: `FNV-1a("daily-" + "YYYY-MM-DD")`. Kendi FNV fonksiyonumuzu `scripts/core/seed.gd` içine yaz; `String.hash()`'e güvenme.
  - Gün 10 seviyesinde kurallar ve 12 müşteri vardır.
  - Puan:
    - doğru işlem × 100;
    - kalan süre bonusu;
    - hata × −150.
  - Günde 1 resmi deneme yapılır, `daily_retry` ile +1 deneme alınabilir. Sonrasında yalnızca puansız alıştırma oynanabilir.
  - Yerel en iyi skor tarih bazında saklanır.
  - "Paylaş" metni üretilir, örnek: "Günün Kuru 26.10 — 1840 puan 💱".
- **Sonsuz:**
  - Hikayede Gün 10'dan sonra açılır.
  - 3 kuralla başlar, her 5 müşteride rastgele bir kural eklenir.
  - 3 can vardır (hata = can kaybı).
  - Puan, hizmet verilen müşteri sayısıdır.

#### 2.7.1 Faz 9'da kesinleşen mod kararları (kod: `mode_run.gd`, `daily_challenge.gd`, `endless_run.gd`, `mode_store.gd`, `game_session.gd`)
- **Kilit:** "Gün N'den sonra" = hikayede N. gün GEÇİLİP N+1. günün sabahına ulaşılmış olması (`max_day > N`). Yeni oyun açılmış modu geri kilitlemez; en ileri gün hikaye kaydından ayrı tutulur. Kilitliyken menüde düğme pasif ve açıklamalı ("Günün Kuru (5. günden sonra)").
- **Günün Kuru:** tarih UTC. Kurallar/para birimleri 10. gün, tüm araçlar elde, hikaye kapalı. 12 müşteri baştan üretilir; kasa stoğu x6 (müşteriler kasa durumuna bağlı olmasın, "aynı tarih aynı müşteri" kesin olsun). Süre 180 sn; müşteriler bitince ya da süre dolunca biter. Puan formülü ve skor tabanı 0. Günde 1 resmi deneme BAŞLARKEN harcanır (yarıda çıkmak da harcar, hile yok); sonrası "Alıştırma (puansız)": oynanır, skor kaydedilmez, paylaşılmaz. En iyi skor tarih bazında saklanır, 60 tarih tutulur. Paylaş: "Günün Kuru 26.10 — 1840 puan 💱" panoya kopyalanır.
- **Sonsuz:** kural günü 13; başlangıç kuralları R_EXCHANGE, R_CATALOG, R_UV; havuz 9 kural (R_MIDDAY_RATE yok: saat ilerlemiyor). Her 5 müşteride havuzdan tohumlu rastgele kural eklenir; masada "Yeni kural: …" şeridi çıkar, araç düğmeleri yenilenir; çalıntı/aranan kuralı gelince bülten üretilir. 3 can, hatalı her işlem 1 can; süre sınırı yok; puan = hizmet verilen müşteri; canlar bitince koşu biter. Kusursuz oyuncu 40 müşteride can kaybetmez (test).
- **Denge/sınır:** kusursuz bot 12 farklı tarihte Günün Kuru'nu hatasız bitirir (1200 + süre bonusu). Ödüllü reklam bağları (`daily_retry`, `endless_continue`) çekirdekte hazır (`grant_bonus_attempt`, `continue_with_life`); arayüz düğmeleri Faz 10'da sahte sağlayıcıyla eklenecek. Skor tablosu (liderlik) yok; Faz 11 kararı.

#### 2.7.2 Performans, rehber ve ikonlu arayüz (Faz 12'nin ilk turu; kod: `icons.gd`, `icon_view.gd`, `icon_button.gd`, `guide_sheet.gd`, `glow.gd`, `audio_manager.gd`)
- **Ölçüm (`tools/perf_probe.gd --part=cpu|frames`)**: çekirdek mantık işlem başına ≤ 5 ms, çizim CPU ~0,2-0,4 ms/kare → **iş parçacığına (thread) gerek yok**; yalnızca masa sahnesinin ilk açılışındaki takılma için `GameSession` açılışta `WARM_PATHS` sahnelerini `ResourceLoader.load_threaded_request` ile arka planda ısıtır. 15 sahne gidiş-dönüşte düğüm sızıntısı yok (`test_performance`).
- **Bellek/pil**: renderer `gl_compatibility` (tüm platformlar; Android'de Vulkan'a göre daha az bellek, emülatör dahil geniş cihaz desteği), `max_fps = 60`, atmosfer 30 Hz, parlama/vinyet için büyük yarı saydam dikdörtgenler yerine gradyan dokular (`Glow`, `overdraw` azaltır), ses akışları `AudioManager` önbelleğinde (`stop_all` temizler), JSON `JsonIO.read_shared` ile paylaşılır.
- **Android yaşam döngüsü**: uygulama arka plana geçince masa duraklar (`_notification`), kare süresi `MAX_FRAME_DELTA` ile kırpılır (arka plandan dönüşte saat haksız sıçramaz; kırpma `_process`'te, `tick()` testlerde serbest).
- **Rehber ("Nasıl oynanır")**: `GuideSheet`, 7 sayfa (gişe, inceleme, damgalar, ödeme, hatalar, akşam, hikaye), ikonlu çipler; ilk YENİ OYUNDA otomatik (bitince/atlanınca sabaha geçer, `SettingsManager game/guide_seen`), ana menü (?) "Rehber" düğmesinden her zaman açılır; geri tuşu sayfa geri / kapatır. Metinler `GUIDE_*` (TR+EN).
- **İkonlu arayüz**: `Icons.SHAPES` (el çizimi ince çizgi ikonlar, 36 adet; `tools/icon_sheet.gd` galeri), `IconView` (tek ikon), `IconButton` (dikey: üstte ikon altta kısa etiket, açık/kapalı iken dolu daire; satır içi: ikon + metin, ince çerçeve; `locked`; `text` tam metni test/erişilebilirlik için tutar, `label_text` ekranda gösterilen kısa etiket; metin kırpılır, satır içinde sığması için küçülür). Masada araç çubuğu tek satır ikon, menü kısayolları (Günün Kuru, Sonsuz, Market, Ayarlar, Rehber) tek satır, ikincil eylemler (geri, geri yükle, gizlilik, paylaş, reklam) çerçeveli satır içi ikon düğmeleri, kart başlıklarının solunda küçük ikon (`UiKit.card(..., ikon)`). Tema yumuşatıldı (gölge soluk, yarıçaplar büyük; `tools/build_theme.py`).
- Görüntü almak: `tools/style_shots.gd` (`--guide` rehber sayfalarını da çeker). macOS'ta pencere örtülünce eski kareyi verebilir; betik `window_move_to_foreground` + `force_draw` kullanır.

#### 2.7.3 Faz 12b: iki mod, derin hikaye, ofis, kılavuz, piksel görünümü, müzik (kod: `directives.gd`, `office_memos.gd`, `rule_book.gd`, `fx.gd`, `pixel_filter.gdshader`)
- **İki ana mod**: menüde "Hikaye" kartı (Devam / Yeni oyun) ve "Sonsuz"; Günün Kuru ve Market/Ayarlar/Rehber alt ikon satırında. Sonsuz ve Günün Kuru baştan açık (`data/modes.json` `unlock_after_day: -1`).
- **Hikaye derinleşti** (`data/story/`, `story.csv`): radyo haberleri (güne atmosfer), küçük Kerem (kumbara, G3→G9), Barış (git/kal, G7→G14), Nurten Hanım (eşinin kimliği, G8), Rıza'nın borcu (G11), annenin eski banknotları (G12), son gün Ece'nin damgası (G15). Merhamet bir MALİYETTİR: seçenek kuralı bozmaz, kendi cebinden (`cash_pl` negatif) öder; `kind` sayacı artar. **Yeni son "Merhametli Memur"** (`kind` ≥ 3, rüşvet/kesinti yok); toplam 7 son. Müşterisiz olaylar zincirlenir (`Shift.resolve_beat`). Çıkış para (negatif) akşam nakdinden düşer (0'ın altına inmez). `ClerkBot` `merciful` profili.
- **Merkez talimatları** (`data/office.json`, `Directives`): günün hedefi (en az N müşteri / en çok N ret / hata yok / polis kotası...), prim ya da kesinti maaşa işler; doğru kararı DEĞİŞTİRMEZ, yalnızca neyin kazandırdığını (ahlaki baskı: "en çok 2 ret" gibi). G1-2 eğitim, G14 müfettiş günü hep "hata yok". `Career.office_enabled` (oyun oturumu açar; modlar/testler kapalı).
- **Tüple notlar ve telefon** (`OfficeMemos`): günde 1-2 not, planı gün+tuzdan deterministik: `flavor` (mizah/duygu), `stolen_add` (acil bülten: ÇALINTI seri aralığı bültene eklenir, okunmasa da; kılavuzda "YENİ"), `directive_change`, `call` (telefon: para/ruh hali/iyilik seçenekli; cevapsız arama akşam ruh halini düşürür). Masada köşede "Ofis" düğmesi (talimat ilerlemesi + okunmamış rozeti); tüp düşünce kapsül animasyonu + ses.
- **Kılavuz**: Kurallar bölümü sayfa sayfa (`RuleBook`): kuralın ne dediği, NASIL denetlendiği (adımlar), gereken araç, "YENİ" damgası, kaydırma/ileri-geri, **masaya iğneleme** (en çok 3, sağ altta yapışkan notlar; dokununca o sayfa açılır).
- **Piksel görünümü**: tema keskin köşe + kalın koyu kenar + sert kayık gölge + mat palet (`build_theme.py` `PIXEL`); ekran en üstte `pixel_filter.gdshader` (2 px blok, posterize, hafif Bayer ve tarama çizgisi), Ayarlar'dan kapatılır (`game/pixel_filter`). Yazı tipi **VT323** (OFL, `assets/fonts/VT323.ttf`, `vt_regular/vt_bold.tres`): piksel terminal, rakamları net. Dar olduğundan tema boyutları `FONT_SCALE` 1.32 ile büyütülür (`build_theme.py`) ve kodda çizilen yazılar (`banknote_view`, `icon_button`, `stamp_button`, `face_view`, `menu_emblem`) elle büyütüldü. Pixelify Sans denendi ama 5/S, 2/Z, 8/B aynı çizildiği için bırakıldı (dosyaları `assets/fonts/` altında duruyor, kullanılmıyor).
- **Müzik** (ElevenLabs Music, `tools/make_music.py`): `theme_main`, `morning`, `desk_calm`/`desk_tense` (son 70 sn), `evening`, `ending_warm|dark|escape`, kısa `stinger_*`. `AudioManager.play_track` çapraz geçişli; sahne→parça `SCENE_TRACKS`; oda uğultusu ayrı kısık katman. 18 yeni efekt (`make_sfx.py`: tube, typewriter, phone, siren, drawer, uv_on, lens, ...).
- **Efektler** (`Fx`): madeni para saçılması, mürekkep sıçraması, hata parlaması, konfeti (sıcak sonlar), tüp kapsülü, akşam özeti satır satır (daktilo sesi).

### 2.8 Erişilebilirlik ve rahatlık
- **Sahte para ipucu yalnızca renge dayanmaz.** Renk farkı olan her sahtede ayrıca desen veya portre farkı da vardır. Ayarlarda "renk körü modu" bulunur: katalogda renk adları yazılır ve UV parlaması desenli gösterilir.
- Yazı boyutu ayarı vardır: normal veya büyük.
- Dokunma hedefleri ≥ 88 px. Sürüklemenin alternatifi de vardır: banknota dokunup hedefe dokunmak.
- Titreşim aç/kapa ayarı: hatada kısa titreşim.

---

## 3. Teknik mimari

### 3.1 Yeni depo
`~/Games/doviz-burosu` (yeni git deposu). `~/Games/mobile-game` içinden **kopyalanacaklar**:

| Kopyala | Not |
|---|---|
| `project.godot` | Ad, autoload'lar, dikey ekran, renderer, `rendering_method.emulator` override'ı, çeviri listesi. Yurt'a özgü ayarları temizle. |
| `scripts/autoload/*` | Hepsi aynen kalır. |
| `scripts/services/*` | `AdsProvider`, `IapProvider`, `MockAdsProvider`, `MockIapProvider`. |
| `scripts/core/` | Yalnızca `json_io.gd`, `number_format.gd`, `safe_area_math.gd`, `scenes.gd` (sahne listesi yeniden yazılır). |
| `scripts/ui/` | `safe_area_container.gd`, `settings_screen.gd`, `main_screen.gd` (yeniden yazılacak). |
| `scenes/` | `main.tscn`, `settings.tscn` (uyarlanır). |
| `tests/` | `run_tests.gd`, `test_case.gd`, genel testler: autoloads, json_io, localization, number_format, safe_area, scene_manager, test_case. |
| `tools/` | `verify.sh`, `screenshot.gd`, `touch_input.gd`, `hooks/`, `emulator_start.sh`, `android_run.sh`, `build_theme.py`, `make_sfx.py`. |
| `assets/fonts/` | Baloo 2 (Türkçe tam) ve lisansı. |
| `assets/theme/`, `assets/translations/strings.csv` | Yalnızca genel anahtarlar (MENU_*, SETTINGS_*, COMMON_*). |
| `export_presets.cfg` | Paket adı, uygulama adı ve dosya yolları değişir. |
| `.gitignore`, `.claude/settings.json`, `.mcp.json` | Aynen. |
| `CLAUDE.md` | Genel bölümler aynen kalır; "Yurt oyunu" bölümü silinip yerine "Döviz Bürosu" bölümü yazılır. |

**Kopyalanmayacaklar:** `dorm*`, `assets/models`, `assets/third_party`, `tools/blender`, `tools/dorm_pacing.gd`, yurt verileri ve testleri.

`.env` **kopyalanmaz**. ElevenLabs anahtarı gerekirse kullanıcıdan yeni projenin `.env` dosyasına koyması istenir; ya da `make_sfx.py` bir ortam değişkeninden okur.

### 3.2 Klasör yapısı (hedef)
```
data/
  balance.json        # vardiya süresi, maaş, prim, ceza, yuvarlama, enflasyon, gider tabanları
  currencies.json     # 2.1
  rules.json          # 2.3
  tools.json          # 2.4
  household.json      # giderler, aile durumu geçişleri
  story/day_01..15.json
  characters.json     # senaryolu karakterler: yüz parçaları, ad anahtarı
  endings.json
  ads.json            # 2.6 sınırları ve geçiş reklamı koşulları
  products.json       # no_ads
  modes.json          # günün kuru / sonsuz parametreleri
  languages.json
scripts/core/
  seed.gd             # FNV-1a, tohumlu RNG yardımcıları
  money.gd            # tam sayı kuruş aritmetiği, yuvarlama
  currency_book.gd    # currencies.json okuma, katalog sorguları
  banknote.gd         # bir banknotun tüm özellikleri + kusur listesi
  note_factory.gd     # gerçek veya sahte banknot üretimi (tohumlu, kurala göre kusur)
  documents.gd        # kimlik, kaynak beyanı (alanlar + kusurlar)
  customer.gd         # istek, banknotlar, belgeler, diyalog, etiketler
  customer_factory.gd # rastgele + senaryolu müşteri üretimi
  rate_table.gd       # günlük kurlar, gün ortası güncelleme, alış/satış, quote()
  rule_engine.gd      # aktif kurallar → beklenen sonuç (Verdict)
  verdict.gd          # beklenen ile oyuncu hamlesini karşılaştırma, hata nedenleri
  till.gd             # kasa: kupür sayıları, ödeme tepsisi
  shift.gd            # vardiya durum makinesi, saat, kuyruk, işlem kaydı
  household.gd        # giderler, aile durumu, birikim, döviz birikimi
  story_state.gd      # bayraklar, sayaçlar, son seçimi
  career.gd           # gün, araçlar, açık modlar, istatistik (kayıt kökü)
  daily_challenge.gd
  endless_run.gd
  ad_policy.gd        # 2.6 kararları
  clerk_bot.gd        # test botu: mükemmel / dikkatsiz / hilekar oyuncu
scripts/ui/
  main_menu.gd, morning_screen.gd, desk_screen.gd, inspect_view.gd,
  banknote_view.gd (banknotu veriden çizer), customer_view.gd (modüler portre),
  till_view.gd, rulebook_view.gd, evening_screen.gd, ending_screen.gd,
  daily_result.gd, endless_result.gd, shop_screen.gd, settings_screen.gd
scenes/  (her ui script'ine bir .tscn)
assets/
  ui/icons/*.svg, banknotes/ (desen + portre SVG parçaları), faces/ (modüler yüz SVG),
  shaders/uv.gdshader, shaders/backlight.gdshader, audio/sfx/*, audio/music/*
  translations/strings.csv (arayüz), translations/story.csv (diyaloglar)
tests/unit/test_*.gd
tools/ verify.sh, screenshot.gd, touch_input.gd, balance_sim.gd, validate_content.gd, make_faces.py, make_sfx.py, build_theme.py
```

### 3.3 Önemli teknik kararlar
- **Para hesabı tam sayıyla yapılır.** Kuruş birimi kullanılır: 1 PL = 100. Kurlar `int` olarak 10.000 ile çarpılıp saklanır. `float` kullanma; yuvarlama hatası "doğru cevap" tartışması yaratır. Yuvarlama kuralı `balance.json → payout_round_to` (5 PL, aşağı).
- **Banknotlar resim dosyası değildir, veriden çizilir.**
  - `banknote_view.gd` bir `Control`'dür. Çizim sırası: arka plan rengi, desen (SVG doku), portre (SVG), kupür yazısı, seri numarası, mikro yazı.
  - UV katmanı ayrı bir `CanvasItem` ve `uv.gdshader` ile çizilir.
  - Filigran katmanı `backlight.gdshader` ile çizilir.
  - Sahte banknot = farklı parametreler. Böylece sonsuz çeşit ve tutarlı kurallar elde edilir.
- **Müşteri yüzleri modülerdir.** `tools/make_faces.py` SVG parçaları üretir: yüz şekli, ten, saç, göz, kaş, ağız, aksesuar, kıyafet. `customer_view` bunları katman katman dizer. Kimlik fotoğrafı aynı parçalardan küçük boyutta çizilir. "Başkasının kimliği" kusuru 1–2 parçanın değişmesidir (saç ve gözlük gibi).
- **Sürükle-bırak** Godot'nun `_get_drag_data` / `_can_drop_data` / `_drop_data` mekanizmasıyla yapılır. Dokunma, fare taklidiyle çalışır. Her sürüklemenin "dokun-seç, dokun-bırak" alternatifi vardır.
- **Kayıt** `SaveManager.data` içinde tutulur, `SAVE_VERSION = 1`:
  ```json
  {"career": {...}, "story": {...}, "household": {...}, "tools": [...],
   "modes": {"daily": {"2026-10-26": {"score": 1840, "attempts": 1}}, "endless_best": 42},
   "ads": {"last_interstitial_day": 4, "last_ad_time": 0, "offers_used": {"rate_tip": 5}},
   "purchases": {"no_ads": true}}
  ```
  Format değişirse `_migrate()` güncellenir ve `SAVE_VERSION` artırılır.
- **Hikaye günü başında anlık görüntü** alınır. "Günü tekrar oyna" bu görüntüye döner. `career.morning_snapshot` kaydedilir.
- **Ses:** `AudioManager`. Efektler ElevenLabs ile üretilir (`tools/make_sfx.py`): damga, kasa çekmecesi, kağıt, banknot hışırtısı, zil, uyarı fişi yazıcısı, polis düdüğü, UV vızıltısı, kalabalık ambiyansı. Müzik için kullanıcıya sorulur (CC0 paket ya da üretim).

---

## 4. Fazlar

Her faz için şunlar tanımlıdır: **Amaç**, **İşler**, **Testler**, **Bitti sayılır**.
Her fazın sonunda:
1. `tools/verify.sh` çalıştırılır.
2. Ekran görüntüleri alınır ve okunur.
3. Kullanıcıya 5–10 satırlık bir rapor verilir: ne yapıldı, ne görüldü, ne kaldı.
4. Commit için kullanıcıdan onay istenir.

Kullanıcının kendisinin denemesi gereken **kilometre taşları** M1–M4 olarak işaretlidir.

### Faz 0 — Proje iskeleti
- **Amaç:** Boş ama çalışan yeni depo.
- **İşler:**
  - 3.1'deki kopyalama ve temizlik.
  - Yeni `CLAUDE.md`.
  - `project.godot` adı.
  - `export_presets.cfg`: paket yer tutucusu `com.example.dovizburosu`. "Android" ve "Android Emulator" presetleri korunur. Play için AAB'li ayrı bir "Android Release" preseti eklenir (`gradle_build/export_format=1`).
  - Ana menü iskeleti: Hikaye, Günün Kuru (kilitli), Sonsuz (kilitli), Market, Ayarlar.
  - 0. bölümdeki açık kararlar kullanıcıya sorulur.
- **Testler:** Kopyalanan genel testler geçer. Yurt'a ait hiçbir dosya ya da başvuru kalmaz (grep ile kontrol).
- **Bitti sayılır:**
  - `verify.sh` yeşil.
  - Ana menünün ekran görüntüsü alındı.
  - `godot --headless --path . --export-debug "Android" ...` ile APK derleniyor.

### Faz 1 — Para, banknot ve kur çekirdeği
- **Amaç:** Oyunun "fizik kuralları".
- **İşler:** `seed.gd`, `money.gd`, `currency_book.gd`, `banknote.gd`, `note_factory.gd`, `rate_table.gd`; `currencies.json`, `balance.json` (ilk değerler).
- **Testler:**
  - FNV aynı girdiye aynı çıktıyı verir.
  - Para yuvarlaması doğru.
  - Alış/satış tutarlıdır: satış > alış.
  - `quote()` örnek tablosu doğru.
  - `note_factory`: istenen kusur türüyle sahte üretilir, gerçek banknotta kusur yoktur.
  - Aynı tohum aynı banknotları üretir.
  - Kupür ve seri biçimleri veriye uyar.
- **Bitti sayılır:** Çekirdek testler yeşil, ekran yok.

### Faz 2 — Kural motoru, belgeler, müşteri
- **Amaç:** Her müşteri için kesin doğru cevap.
- **İşler:**
  - `documents.gd`, `customer.gd`, `customer_factory.gd`, `rule_engine.gd`, `verdict.gd`, `till.gd`.
  - `rules.json`: 2.3'teki 13 kural.
- **Testler:**
  - Her kural için en az 3 test: geçen, kalan ve sınırdaki durum.
  - Birden fazla kusur varsa öncelik sırası belirgindir. Örnek: çalıntı + yırtık = el koy (polis), iade değil.
  - `verdict` yanlış ödemeyi (fazla ya da eksik) ayrı nedenlerle raporlar.
  - Kasada döviz yetmezse beklenen karar "reddet (kasada yok)" olur.
- **Bitti sayılır:** `RuleEngine`, Gün N'nin kurallarıyla rastgele 1.000 müşteri için hatasız beklenen sonuç üretir. Bu bir "kendi kendini doğrulama" testidir: kusurları bilinen üretici ile motorun kararı uyuşur.

### Faz 3 — Vardiya, ev ekonomisi, test botu
- **Amaç:** Bir gün baştan sona arayüzsüz oynanabilsin.
- **İşler:** `shift.gd`, `household.gd`, `career.gd`, `story_state.gd` (iskelet), `clerk_bot.gd` (mükemmel, dikkatsiz %15 hata ve hilekar profilleri), `tools/balance_sim.gd`.
- **Testler:**
  - Saat akışı doğru; kapanış kuralı çalışır.
  - 3. hatadan itibaren ceza kesilir.
  - Giderlerin enflasyonla artışı doğru.
  - Ödenmeyen gider aile durumunu kötüleştirir.
  - Evden atılma koşulu çalışır.
  - **Denge testleri:**
    - Mükemmel bot, reklamsız 15 günü aileyi kaybetmeden bitirir; kalan para pozitif ama küçük olmalı.
    - Dikkatsiz bot en az 1 kez zorlanır.
    - Hilekar bot (patronun kesintisi) daha zengindir ama Gün 14'te yakalanma olasılığı vardır.
- **Bitti sayılır:** `balance_sim.gd --days=15 --bot=perfect` raporu: günlük gelir/gider, birikim ve aile durumu tablosu.

### Faz 4 — Gişe masası prototipi (gri kutular)  ⟶ **M1: kullanıcı dener**
- **Amaç:** Oyunun eğlenceli olup olmadığını ilk kez görmek.
- **İşler:**
  - `desk.tscn` dikey yerleşimi:
    - Üstte pencere (müşteri ve balon) ile saat.
    - Ortada tezgâh: banknotlar ve belgeler.
    - Altında araç çubuğu: katalog, hesap makinesi; UV ve büyüteç sonra gelecek.
    - En altta kasa çekmecesi, ödeme tepsisi ve karar butonları (Tamamla / Reddet / Polis).
  - `inspect_view`: banknotu büyütme ve iki parmakla yakınlaştırma.
  - Sürükle-bırak ve "dokun-seç, dokun-bırak".
  - Reddet nedeni seçicisi.
  - Uyarı fişi animasyonu.
  - Banknotlar bu fazda düz renkli kutu + yazı olabilir.
  - Yalnızca Gün 1–3 kuralları.
- **Testler:** `TouchInput` ile bir müşteriyi doğru bozdurma, yanlış ödeme sonrası uyarı fişi, sahteyi el koyma akışı.
- **Bitti sayılır:**
  - Ekran görüntüleriyle Gün 1–3 oynanabilir.
  - Kullanıcıya Mac'te çalıştırma komutu verilir ve geri bildirim istenir. Örnekler: "Para sürüklemek zahmetli mi?", "Süre yetiyor mu?"

### Faz 5 — Gün akışı, sabah ve akşam, kayıt
- **İşler:**
  - `morning_screen` (gazete).
  - `evening_screen`: özet, giderler, birikim ve FED'e çevirme.
  - Sabah anlık görüntüsü, "Devam" ve "Yeni oyun".
  - Oyun bitti ekranı.
  - Geri tuşunun davranışı:
    - Vardiyada duraklatma menüsü açar.
    - Akşamda bir şey yapmaz.
    - Sabahta ana menüye döner (onaylı).
- **Testler:**
  - Kaydet/yükle tur testi.
  - Uygulama kapanıp açılınca aynı sabaha dönülür.
  - Geri tuşu akışları.
- **Bitti sayılır:** Gün 1 → Gün 3, ara ekranlarıyla kesintisiz oynanır.

### Faz 6 — Araçlar ve kalan kurallar
- **İşler:**
  - UV shader'ı, filigran (basılı tutunca arka ışık), büyüteç ve mikro yazı.
  - Bülten sekmesi: çalıntı seri numaraları ve aranan yüzler.
  - Kimlik ve kaynak beyanı görünümleri.
  - Gün ortası kur güncellemesi bildirimi.
  - Akşam dükkanı: sayma makinesi ve kur hesaplayıcı.
  - 2.3'teki kuralların hepsi arayüzde çalışır.
- **Testler:**
  - Her araç için açma/kapama.
  - Kilitli araç görünmez.
  - Her kural türü için en az bir arayüz akış testi.
- **Bitti sayılır:** Gün 1–13 rastgele müşterilerle oynanabilir.

### Faz 7 — Hikaye içeriği  ⟶ **M2: kullanıcı hikayeyi oynar**  ✅ tamam (bkz. 2.2.5)
- **İşler:**
  - `story/day_01..15.json`, `characters.json`, `endings.json`.
  - `story.csv`: TR ve EN diyaloglar.
  - Senaryolu müşteri desteği, seçimlerin bayrakları, akşam mektupları ve olaylar.
  - Son ekranı.
  - `tools/validate_content.gd`, şunları kontrol eder:
    - her gün dosyası geçerli kural, karakter ve metin anahtarlarına başvuruyor;
    - her senaryolu müşterinin beklenen sonucu motorla üretilebiliyor;
    - her sona en az bir yoldan ulaşılabiliyor (bot + seçim kombinasyonları).
- **Testler:** `validate_content` testlere bağlıdır. Her son için bot senaryosuyla ulaşılabilirlik testi.
- **Bitti sayılır:** 15 gün baştan sona oynanır ve 5 son görülebilir. Metinler TR ve EN dolu.

### Faz 8 — Görsel kimlik ve "his" (juice)  ✅ uygulandı, kullanıcı onayı bekliyor (bkz. 2.2.6)
- **İşler:**
  - Figma'da yeni dosyada 2 stil seçeneği hazırlanır (kullanıcı seçer, 0. bölüm karar 5). Ekranlar: masa, inceleme, gazete, akşam, menü, market. Kullanıcı stili seçince `build_theme.py` PALETTE güncellenir.
  - Banknot desenleri ve portre SVG'leri her para birimine özgü olur.
  - `make_faces.py` modüler yüzleri üretir. İkonlar.
  - Animasyonlar:
    - müşteri gelir ve gider;
    - banknot tezgâha "pat" diye düşer;
    - damga vuruşu ekranı hafif sallar;
    - para tepsiye kayar.
  - Sesler (ElevenLabs) ve titreşim.
  - Gazete kağıt dokusu.
- **Testler:** Görsel testi otomatik değildir. Her ekranın ekran görüntüsü 720x1280'de ve çentikli simülasyonda (`--simulate-safe-area=88,0,68,0`) incelenir. Yerelleştirme testi geçer.
- **Bitti sayılır:** Kullanıcı Figma ve ekran görüntülerini onaylar.

### Faz 9 — Günün Kuru ve Sonsuz  ✅ tamam (bkz. 2.7.1)
- **İşler:**
  - `daily_challenge.gd`, `endless_run.gd`, `modes.json`.
  - Sonuç ekranları ve paylaş metni (`DisplayServer.clipboard_set` ve Android paylaşım; paylaşım eklentisi gerekirse kullanıcıya sor).
  - Kilit açma koşulları.
- **Testler:**
  - Aynı tarih aynı müşterileri üretir.
  - Farklı tarih farklı müşteri üretir.
  - Deneme hakkı sayımı doğru.
  - Sonsuzda kural ekleme ve can sistemi çalışır.
- **Bitti sayılır:** Her iki mod menüden oynanır, skorlar kaydedilir.

### Faz 10 — Para kazanma (sahte sağlayıcılarla)  ⟶ **M3: kullanıcı tüm oyunu dener**  ✅ tamam (bkz. 2.6.1)
- **İşler:**
  - `ad_policy.gd` ve `ads.json`.
  - 2.6'daki 6 ödüllü reklam yeri arayüze eklenir. Reklam hazır değilse buton gizlenir ya da "Reklam şu an yok" yazar; hata gösterilmez.
  - Geçiş reklamı akşam → sabah geçişine bağlanır.
  - `products.json`: `no_ads`.
  - Market ekranı: Reklamları Kaldır, geri yükle.
  - Destekçi süsü.
  - Debug sürümünde `MockAdsProvider` ve `MockIapProvider` kullanılır (yurt projesindeki `_use_dev_providers` deseni).
  - `Analytics` olayları: `day_start`, `day_end`, `mistake`, `ending`, `ad_offer_shown`, `ad_rewarded`, `interstitial_shown`, `iap_purchase`, `mode_start`. Hepsi onay yoksa gönderilmez.
- **Testler:**
  - `AdPolicy` için her koşulun ayrı testi.
  - `no_ads` sahibi asla geçiş reklamı görmez.
  - Günlük sınırlar çalışır.
  - Satın alma, geri yükleme ve kayıt tur testi.
  - Ödüllü reklam iptal edilince ödül verilmez.
- **Bitti sayılır:** Sahte reklamlarla tüm teklifler uçtan uca çalışır; denge testi (reklamsız mükemmel bot) hâlâ geçer.

### Faz 11 — Gerçek SDK'lar ve onay  ✅ kod tamam; AdMob test reklamları emülatörde doğrulandı; Play Billing Play Console bekliyor (bkz. 2.6.2)
Her indirme öncesinde kullanıcıya sorulur: eklenti adı, kaynak, sürüm, boyut, lisans.
- **İşler:**
  - **AdMob:** Godot 4.x için Android eklentisi (v2, `addons/` altında). Önce `godot-sdk-integrations` organizasyonundaki eklentiye bakılır; 4.7 uyumluluğu README ve Context7 ile doğrulanır.
    - `AdMobAdsProvider extends AdsProvider` yazılır.
    - Geliştirmede **yalnızca Google'ın herkese açık test reklam birimi kimlikleri** kullanılır.
    - Gerçek uygulama ve reklam birimi kimliklerini kullanıcı verir. Bunlar gizli değildir ama `data/ads_ids.json` içinde tutulur; debug sürümü onları kullanmaz.
  - **Onay (GDPR/UMP):** Google User Messaging Platform ile ilk açılışta onay sorulur. `Analytics.set_consent` ve reklam kişiselleştirmesi bu onaya bağlanır. Ayarlar'da "Gizlilik seçenekleri" butonu bulunur.
  - **Google Play Billing:** resmi `godot-google-play-billing` eklentisi (4.x sürümü).
    - `PlayBillingIapProvider extends IapProvider` yazılır.
    - Satın alma sonrası **acknowledge** yapılır.
    - Açılışta sahiplikler sorgulanır.
    - `get_price_text` mağaza fiyatını döner.
  - İsteğe bağlı: Play Games Services liderlik tablosu (0. bölüm karar 6).
- **Testler:**
  - Birim test sahte sağlayıcılarla yapılır.
  - Gerçek SDK'lar emülatörde ve **gerçek cihazda** elle test edilir: test reklamı görünür, ödül gelir, geçiş reklamı kapanır.
  - Satın alma, Play Console'daki "lisans test kullanıcısı" ile denenir. Bu, kullanıcının Play Console'u açmasını gerektirir.
- **Bitti sayılır:** Gerçek cihazda test reklamları ve test satın alma uçtan uca çalışır.

### Faz 12 — Cila, performans, cihaz testi  ⟶ **M4: kapalı test**
- **İşler:**
  - `tools/android_run.sh` ile gerçek cihazda oynanır (Vulkan).
  - FPS ve bellek ölçülür; banknot çizimleri gerekirse önbelleğe alınır.
  - Uzun oturum testi yapılır: 15 gün boyunca sızıntı olmamalı.
  - Uygulama ikonu ve açılış ekranı.
  - İlk açılış öğreticisi Gün 1 içinde ve atlanabilir.
  - Ayarlar: ses, müzik, titreşim, dil, yazı boyutu, renk körü modu, gizlilik seçenekleri, geri yükle.
- **Bitti sayılır:** Gerçek cihazda 30 dk kesintisiz oynanır, hata logu temizdir.

### Faz 13 — Play Store yayını
Bu işlerin bir kısmı **kullanıcı tarafından** yapılır; ajan yalnızca hazırlar ve rehberlik eder.
- Paket adını kesinleştir. Kullanıcı ilk AAB yüklemesinden önce son kez onaylar.
- Release keystore'u kullanıcı oluşturur. Export, `GODOT_ANDROID_KEYSTORE_RELEASE_*` ortam değişkenleriyle yapılır.
- `Android Release` preseti ile **AAB** üretilir.
- Mağaza materyalleri (ajan hazırlar):
  - kısa ve uzun açıklama, TR ve EN;
  - 512 px ikon;
  - 1024x500 öne çıkan görsel;
  - telefon ekran görüntüleri.
- **Gizlilik politikası** (reklam ve analitik olduğu için zorunlu): ajan metni hazırlar, kullanıcı bir URL'de yayınlar.
- Play Console formları (kullanıcı doldurur, ajan cevapları hazırlar):
  - Veri güvenliği formu: AdMob reklam kimliği toplar.
  - İçerik derecelendirme anketi: kumar yok; suç/rüşvet teması mizahi.
  - Hedef kitle: 13+ önerilir. Çocuklara yönelik değil; bu, Families politikası yükünü önler.
- Dahili test → kapalı test → üretim. **Not:** Yeni kişisel geliştirici hesaplarında Google üretimden önce belirli sayıda testçiyle belirli süre kapalı test şartı koyuyor. Güncel şartı Play Console'dan kontrol et.
- **Bitti sayılır:** Uygulama kapalı test kanalında. Kullanıcı ve testçiler Play'den indirebilir.

---

## 5. Test stratejisi (özet)

| Katman | Ne test edilir | Nasıl |
|---|---|---|
| Çekirdek | Para, kur, banknot, kural, karar, vardiya, ekonomi, reklam politikası | `tests/unit/test_*.gd`, headless |
| İçerik | Gün dosyaları, metin anahtarları, sonlara ulaşılabilirlik | `validate_content.gd` testlerden çağrılır |
| Denge | Reklamsız mükemmel oyuncu bitirir; dikkatsiz zorlanır | `clerk_bot` + `balance_sim.gd`, sınırlar testte |
| Arayüz akışı | Dokun, sürükle, geri tuşu, ekran geçişleri | `TouchInput` (headless) |
| Görsel | Her ekran, çentikli ekran | `tools/screenshot.gd` (pencereli), PNG okunur |
| Cihaz | Vulkan, performans, gerçek SDK | `tools/android_run.sh`, gerçek telefon |

Kural: **yeni bir kural, ekran ya da reklam yeri ekleyen her değişiklik testiyle birlikte gelir.**

## 6. Riskler ve önlemler

| Risk | Önlem |
|---|---|
| Para sürüklemek telefonda zahmetli | M1'de kullanıcı testi yapılır. Ödeme için "hızlı ödeme" butonu eklenebilir: tutarı yazınca kasa otomatik dizer, ama hesabı oyuncu yapar. |
| Kurallar küçük ekranda okunmuyor | Kural kitabı tam ekran sekme olur; inceleme görünümü yakınlaştırılır; yazı boyutu ayarı vardır. |
| Hikaye metni çok uzun, çeviri yükü ağır | Diyaloglar kısa tutulur (balon başına ≤ 90 karakter). `story.csv` ayrı dosyadadır, çeviri toplu yapılır. |
| Rastgele müşteriler tekdüze | Kusur kombinasyonları, karakter etiketleri (acele eden, pazarlıkçı, şakacı) ve kısa espri havuzu (`story.csv`) kullanılır. |
| Reklam deneyimi bozar | `AdPolicy` sınırları testlidir, vardiyada reklam yoktur, ilk oturum reklamsızdır. |
| Gerçek SDK eklentisi Godot 4.7 ile uyumsuz | Faz 11 öncesi uyumluluk araştırılır; uyumsuzsa kullanıcıya alternatif sunulur. Oyun mantığı sağlayıcı arayüzüne bağlı olduğu için değiştirmesi kolaydır. |

## 7. Faz bitiş raporu şablonu (ajan → kullanıcı)
```
Faz N — <ad>: bitti / kısmen
- Yapılanlar: ...
- Testler: X geçti, 0 kaldı (verify.sh yeşil)
- Ekran görüntüleri: tools/screenshots/<önek>_*.png
- Kararlar (belgede olmayan): ...
- Bilinen eksikler: ...
- Kullanıcıdan istenen: (onay / deneme / karar)
```
