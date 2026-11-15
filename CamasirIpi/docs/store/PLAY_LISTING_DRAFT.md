# Google Play ilan taslağı — Clothesline Sort (Çamaşır İpi)

Taslaktır; yayın öncesi sahip onaylar. Karakter sayıları Python `len()` ile (Unicode karakter) hesaplandı; Play Console aynı şekilde sayar varsayımı ÇIKARIMDIR.
Limitler: başlık **30**, kısa açıklama **80** (kaynak: https://support.google.com/googleplay/android-developer/answer/9898842 ve .../answer/9866151, okuma 2026-11-15). Uzun açıklama sınırı (Play'de 4000) resmi sayfada **bu oturumda doğrulanamadı**; taslak çok altında kalır.

## 0. Önemli: başlık sığmıyor

Sahibin isteği "Clothesline Sort" + alt başlık "Laundry Color Puzzle". **"Clothesline Sort: Laundry Color Puzzle" = 38 karakter > 30 → Play başlık sınırını aşar.** Seçenekler:

| Seçenek | Karakter | Not |
|---|---:|---|
| A (öneri) `Clothesline Sort: Color Puzzle` | 30 | Sınır tam 30; tür bilgisi başlıkta |
| B `Clothesline Sort` | 16 | En temiz; alt başlık kısa açıklamada |
| C `Clothesline Sort: Laundry` | 25 | Anahtar kelime-şişirme riski düşük ama tür belirsiz |

"Laundry Color Puzzle" ibaresi kısa açıklamanın başında kullanılabilir (aşağıda). Başlıkta emoji, tümü büyük harf, "#1/En iyi/Ücretsiz" yok (metadata politikası).

## 1. İngilizce (birincil, en-US)

**Başlık** (30/30): `Clothesline Sort: Color Puzzle`

**Kısa açıklama** (75/80): `Tap laundry on the line into matching color baskets. A calm sorting puzzle.`

**Uzun açıklama** (1387 karakter):

```
Clothesline Sort is a calm color-sorting puzzle about laundry day.

Garments hang on a clothesline. Tap them one by one and send each to the basket that matches its color. Fill every basket before the waiting rack runs out of space, and the level is clean and done.

HOW IT PLAYS
- Tap a garment to move it to its matching basket.
- Plan ahead: the waiting rack has only a few spots.
- Each level is a new arrangement, and levels get trickier step by step.
- New obstacles appear along the way: wet garments, mystery garments and locked pegs.

THINGS YOU CAN ENJOY
- Soft, hand-finished artwork and gentle, relaxing sounds.
- Different places to hang your washing: a garden, a seaside line and a rooftop terrace.
- Boosters such as undo and a peg remover to help with a tricky line.
- Rope and peg looks to customize your clothesline, unlocked with coins you earn by playing. Coins are never sold.
- Daily tasks and rewards for coming back.

ADS AND PURCHASES
Clothesline Sort is free to play and contains ads. Short ads may appear between levels. You can also choose to watch an optional rewarded ad to get one extra rack spot after a failed attempt, or to double your coins after a win. A one-time purchase removes the ads between levels; optional rewarded ads stay available.

CONNECTION
An internet connection is required to play.

Questions or feedback? Write to [DEVELOPER EMAIL].
```

## 2. Türkçe (tr-TR)

**Başlık** (27/30): `Çamaşır İpi: Renk Bulmacası`

**Kısa açıklama** (77/80): `İpteki çamaşırlara dokun, renklerine uygun sepetlere ayır. Sakin bir bulmaca.`

**Uzun açıklama** (1344 karakter):

```
Çamaşır İpi, çamaşır gününü konu alan sakin bir renk ayırma bulmacasıdır.

Çamaşırlar ipte asılı. Her birine dokun ve rengine uyan sepete gönder. Bekleme askısı dolmadan tüm sepetleri doldur; seviye tertemiz biter.

NASIL OYNANIR
- Bir çamaşıra dokun, rengine uygun sepete gitsin.
- Önceden planla: bekleme askısında yalnızca birkaç yer var.
- Her seviye yeni bir düzen; seviyeler adım adım zorlaşır.
- Yolda yeni engeller çıkar: ıslak çamaşırlar, gizemli çamaşırlar ve kilitli mandallar.

KEYFİNE VARACAKLARIN
- Yumuşak, elle işlenmiş görseller ve rahatlatıcı sesler.
- Çamaşır asmak için farklı yerler: bahçe, sahil ipi ve çatı terası.
- Zor bir ipte yardımcı olacak güçlendiriciler: geri al, mandal çıkarıcı gibi.
- İpini ve mandallarını özelleştiren görünümler; oynayarak kazandığın jetonlarla açılır. Jeton satılmaz.
- Geri dönmen için günlük görevler ve ödüller.

REKLAM VE SATIN ALMA
Çamaşır İpi ücretsiz oynanır ve reklam içerir. Seviyeler arasında kısa reklamlar çıkabilir. İstersen kaybettikten sonra bir ek askı yeri için ya da kazandıktan sonra jetonlarını ikiye katlamak için isteğe bağlı ödüllü reklam izleyebilirsin. Tek seferlik bir satın alma seviyeler arasındaki reklamları kaldırır; isteğe bağlı ödüllü reklamlar kalır.

BAĞLANTI
Oynamak için internet bağlantısı gerekir.

Soru ve geri bildirim için: [GELİŞTİRİCİ E-POSTASI]
```

## 3. Doğrulanması gereken iddialar (ilana koymadan önce kodda/oyunda var mı?)

İlan yalnız **yayın sürümünde gerçekten bulunan** özellikleri anlatmalı (metadata politikası: yanıltıcı/abartılı yasak). `TASKS.md`'ye göre şunlar henüz bitmemiş/entegre edilmemiş olabilir; sahip/yönetmen onaylamadan metinde kalmamalı ya da silinmeli:

| Metindeki iddia | Durum kaynağı | Onay gerek |
|---|---|---|
| Islak / gizemli çamaşır, kilitli mandal | TASKS P4a ✅ | hayır |
| Bahçe, sahil, çatı terası | TASKS P1 (Dalga 1, işaretsiz) | **evet** |
| Geri al, mandal çıkarıcı | `docs/I18N.md` sözlüğü | hayır (yayında var mı kontrol) |
| İp/mandal görünümleri, jeton ile | `docs/MONETIZATION.md` kaplamalar | hayır |
| Günlük görevler | `docs/RETENTION.md` R1 | **evet** (dalga 2 birleştirme) |
| Mevsimler, Zen modu, renk körlüğü desenleri | TASKS Q1/Q4/Q6 (işaretsiz) | metne **eklenmedi**; yayınlanırsa eklenebilir |
| "İnternet bağlantısı gerekir" | TASKS Q5, `scripts/net/online_gate.gd` | evet (dürüstlük için zorunlu) |

## 4. Ekran görüntüsü fikirleri (9:16, ≥ 1080×1920, PNG/JPEG alfasız; en az 2, en çok 8 — kaynak: .../answer/9866151)

Altyazı metinleri kısa ve gerçek oyun ekranını yansıtmalı (görsele eklenen metin yerelleştirilir). Ekran görüntüleri `tools/` içindeki ekran aracıyla gerçek oyundan alınır; "Play'de #1/ödüllü" gibi rozet yok.

| # | Sahne | EN altyazı | TR altyazı |
|---|---|---|---|
| 1 | Bahçe ipi, renkli çamaşırlar + sepetler (ilk seviye, öğretici eli yok) | Tap to sort | Dokun, ayır |
| 2 | Tek hamle anı: çamaşır havada sepete giderken | Match every color | Her rengi eşleştir |
| 3 | Bekleme askısı dolmaya yakın, düşündüren bir ip | Plan your rack spots | Askı yerlerini planla |
| 4 | Engeller: ıslak + gizemli + kilitli mandal bir arada | New twists, step by step | Adım adım yeni zorluklar |
| 5 | Sahil ipi (gece/gün) | A seaside line | Sahilde bir ip |
| 6 | Çatı terası | A rooftop terrace | Çatı terasında |
| 7 | Mağaza/koleksiyon: ip ve mandal görünümleri | Make the line yours | İpini kişiselleştir |
| 8 | Kazanma ekranı (jeton, yıldız) | Clean and done | Tertemiz bitti |

Ekran 5-6 yalnız mekânlar yayında varsa. Tablet görüntüleri (N1) isteğe bağlı: tablet için en az 4, 1080-7680 px.

## 5. Grafikler

| Varlık | Ölçü | Not |
|---|---|---|
| Simge | 512×512, 32-bit PNG (alfalı), ≤ 1024 KB | Yanıltıcı sembol (bildirim noktası, indirme oku) yok |
| Öne çıkan grafik | 1024×500, JPEG/24-bit PNG alfasız | Üzerinde sıralama/fiyat/Play rozeti yok |
| Video (isteğe bağlı) | YouTube tek URL, herkese açık/liste dışı, reklamsız | İlk 30 sn otomatik oynar |

## 6. Kategori ve etiket önerisi

- **Uygulama türü:** Oyun. **Kategori:** Bulmaca (Puzzle). (ÇIKARIM: Play Console'daki kesin kategori adı formda doğrulanır; kategori seçimi: .../answer/9859454.)
- **Etiket önerileri** (Play Console'un sunduğu listeden en fazla yakın olanlar): Puzzle, Casual, Offline değil (İnternet gerekiyor — "Offline" etiketi **seçilmez**), Single player, Relaxing/Stylized varsa. Etiketlerde anahtar kelime şişirme yok.

## 7. Diğer ilan alanları

- İletişim: geliştirici e-postası, **geliştirici web sitesi** (app-ads.txt ve gizlilik politikası burada barındırılır), gizlilik politikası URL'si.
- Varsayılan dil: en-US (birincil). Diğer: tr-TR, es-ES ve/veya es-419, pt-BR, de-DE, ja-JP, ko-KR (kodlar: https://support.google.com/googleplay/android-developer/answer/3125566).
- Çevrilmemiş dilde Play otomatik çeviri sunar; yerelleştirilmemiş grafikler varsayılan dilden gelir (aynı sayfa).

## 8. Çeviriler

**pt / de / ja / ko / es ilan çevirileri, oyun içi çeviriler (`docs/I18N.md`, `ci-i18n` işi) incelendikten sonra yapılır.** Terminoloji oyun içi sözlükle (çamaşır/sepet/mandal/askı...) tutarlı olmalı; Japonca ve Korece için ana dili konuşan biri gözden geçirmeli. Başlık her dilde 30 karakteri aşmamalı (CJK'de karakter sayımı farklı görünür; Console sayacına bak).
