# PROJECT_SPEC — Cable Knot: Current Master

Durum: **v0.1 — uygulanıyor**. Bu belge oyunun ne olduğunu ve neden böyle olduğunu tanımlar.

## 1. Tek cümle

Karmaşık şekilde düğümlenmiş yüksek voltajlı renkli kabloların fişlerini sürükleyip
**kendi rengindeki** prizlere, farklı renkli kablolara temas ettirmeden taktığın;
kıvılcım, aşırı yük barı ve ASMR geri bildirimleriyle dolu dikey mobil bulmaca oyunu.

## 2. Hedef oyuncu ve his

- Hyper-casual / puzzle kitlesi; 30–90 saniyelik bölümler, tek elle, dikey.
- Hissiyat: "gerilim dolu ama tatmin edici" — kablo çekişinde tok sürtünme, temasta cızırtı,
  prize oturunca keskin clack, bölüm sonunda rahatlatan zafer.
- Zorluk kaynağı refleks değil **planlama**: kabloyu hangi sırayla ve hangi koridordan geçireceksin.

## 3. Çekirdek döngü (bir bölüm ≈ 45–100 sn)

1. **Analiz**: Pano yüklenir. Üstte ana pano (kaynak terminaller), altta priz şeridi.
   Kablolar renkli ve düğümlü; fişler panonun ortasında mıknatısla tutulu.
2. **Sürükle**: Fişe dokun → fiş öne (kameraya) kalkar, kablo gövdesi verlet fizikle peşinden gelir.
   Parmağı gezdirirken kablo diğer kabloların arasından sıyrılır.
3. **Teması kes**: Farklı renkli kablo gövdesi diğerine `contact_distance` kadar yaklaşırsa
   kıvılcım + cızırtı + **aşırı yük barı** dolar. Temas kesilirse bar boşalır.
4. **Tak**: Fişi kendi rengindeki prizin üstüne bırak → snap + clack + priz parlar.
   Yanlış renk prizin üstüne bırakırsan ark oluşur (bar cezası) ve fiş geri seker.
5. **Dengele**: Tüm fişler doğru prizlerde → devre tamam, voltmetre sakinleşir, zafer.
6. **Sigorta atarsa**: bar %100 → bölüm başarısız; ödüllü "Yedek Sigorta" ile +15 sn kalkan.

## 4. Kurallar (kesin)

| Kural | Değer / kaynak |
|---|---|
| Renkler & voltaj | kırmızı 220V, mavi 110V, sarı 50V, yeşil 24V, mor 12V (`data/levels.json`) |
| Kısa devre | farklı renk + mesafe < `contact_distance` (`data/balance.json`) |
| Aynı renk | güvenli, bar dolmaz |
| Bar dolum | `overload_fill_per_second`; her ek temas `overload_extra_per_contact` ile hızlanır |
| Bar boşalım | `overload_drain_per_second` |
| Yalıtım kalkanı | temas bar doldurmaz; süre `shield_seconds` |
| Snap yarıçapı | `snap_radius`; sadece kendi rengi + boş priz |
| Yanlış priz | ark, bar += `wrong_socket_penalty`, fiş 0.25 m yukarı seker |
| Bölüm sonu | tüm fişler bağlı |
| Yenilgi | bar >= 1.0 (sigorta atar) |
| Yıldız | 3: temiz + par süre içinde; 2: ≤2 kısa devre + 1.6×par; 1: tamamlandı |

## 5. Seviye yapısı

- 12 bölüm: 3 → 7 kablo. Renk havuzu genişler. Tohumla üretilen düzen (`data/levels.json`).
- Üretim garantileri: kablo uzunluğu kendi prizine ulaşır; başlangıçta hiçbir farklı renkli
  kablo temas etmez; fişler birbirine ve prizlere çok yakın değildir; kaynak ile priz aynı hizada değildir.
- Bölüm açılımı sıralı: bölüm N, N-1 tamamlanınca açılır. Yıldızlar ve en iyi süre kaydedilir.

## 6. Para kazanma kancaları (ödüllü reklam)

| Yerleşim | Ne zaman | Ödül |
|---|---|---|
| `FUSE_RESCUE` | Sigorta attığında (fail ekranı) | Yükü sıfırlar, +15 sn yalıtım kalkanı, kaldığı yerden devam |
| `GOLDEN_CUTTER` | Bölüm içi buton (bölüm başına 1) | En çok dolaşan kablonun fişini altın ışınla otomatik bağlar |
| `INSULATION_SPRAY` | Bölüm içi buton (bölüm başına 1) | 10 sn kalkan: temas barı doldurmaz |

Kurallar: ödül yalnızca sağlayıcı `rewarded` döndükten sonra; limitler `data/ads.json`;
SDK yoksa `MockAdsProvider` (1.2 sn simülasyon, %8 başarısız) kullanılır.

## 7. Atmosfer / görsel stil

- Koyu gri (#0D1117) endüstriyel pano, sarı-siyah uyarı şeritleri, neon fişler ve priz halkaları.
- Pastel-neon kablo renkleri; emissive uçlar; hafif bloom; kıvılcım partikülleri; kamera sarsıntısı.
- Kamera: panoya bakan sabit perspektif; sürüklemede hafif paralaks; kısa devrede shake.
- UI: koyu panel + neon vurgu; devre şeması çizgileri; analog voltmetre.

## 8. Ses (ElevenLabs hattı, anahtar yoksa deterministik sentez)

`ui_tap`, `cable_pull` (whoosh), `spark` (crackle), `clack` (thud), `wrong_socket`,
`fuse_pop`, `level_start`, `shield_on`, `cutter`, `success`, `win`, `fail`, `hum`.

## 9. Ekranlar

- **Boot** (0.9 sn) → **Menu** (oyna / bölümler / ayar) → **LevelSelect** (12 bölüm, yıldız/kilit)
  → **Game** (3D pano + HUD) → **Result** (yıldız, süre, kısa devre, en iyi) → menü/sonraki.
- Fail/pause/ad overlay'leri Game içinde (HUD) yaşar; sahne geçişi yapmaz.

---

## 10. v0.2 — "ASMR redesign" tasarım kararları (2026-11-11)

Kullanıcı geri bildirimi sonrası yön: **rahatlatıcı (ASMR) his**, sade-modern UI, aşamalı
zorluk, çoklu dil. Ayrıntılı iş planı: `ROADMAP.md`; teknik sözleşmeler `ARCHITECTURE.md` §10–§16.

### 10.1 Kimlik ve dil
- Oyun adı **İngilizce**: **Cable Knot: Current Master** (menüde başlık; TR'de yerelleştirilmiş
  karşılığı "Kablo Düğümü / Akım Ustası" gösterilir).
- Diller: **EN** (varsayılan) + **TR**. Tüm UI metinleri ve bölüm adı/ipuçları yerelleştirilir;
  ilk açılışta sistem diline göre seçilir, menüden değiştirilir, `user://settings.cfg`'de saklanır.

### 10.2 Hissiyat: gerilim var, panik yok
- Hareketler yavaş ve yumuşak: easing SINE/EASE_OUT, süre 0.25–0.6 sn; kamera nefes alır.
- Kısa devre: sert beyaz/kırmızı flaş yerine sıcak amber vinyet + kısa, yumuşak sarsıntı.
- Başarı: sakin parıltı + sıcak chime; kutlama abartısız.
- ASMR mikro-geri bildirimler: kablo sürtünmesi, prize oturma "clack", yumuşak elektrik uğultusu
  (ambient hum/pad), toz partikülleri, panoda nefes alan ışıklar.

### 10.3 UI/UX
- Sade, ikon-öncelikli, nazik; ekran başına ≤3 ana eylem; butonlar 88–100 tasarım px;
  HUD panoyu örtmez; tipografi Manrope (OFL); TR/EN dil değiştirici her yerde erişilir.
- Ana menüde animasyonlu 3D atölye arka planı (fan/lamba/konveyör/buhar), oyun içinde panonun
  arkasında aynı canlı çevre; düşük maliyet (SubViewport 540×960, gölge yok).

### 10.4 Aşamalı zorluk ve yeni mekanikler
| Bölüm | Yeni unsur |
|---|---|
| 1–4 | Temel: kablo sayısı 3→4, öğretici ipuçları |
| 5+ | **sway**: panoda yavaşça salınan canlı/çıplak hatlar (temas = kısa devre) |
| 7+ | **locked_socket**: kapaklı prizler; fişi 0.6 sn priz yanında tutunca açılır |
| 9+ | **blackout**: pano ışıkları yumuşakça söner/yanar (görsel zorluk) |
| 10+ | **fast_overload**: aşırı yük barı 1.5× hızda dolar |
| 12 | Yedi hat + tüm modifier'lar + en sıkı par süresi |

Yıldız kuralı aynı: temiz + par süre = 3 yıldız; ≤2 kısa devre + 1.6×par = 2; tamamlandı = 1.

### 10.5 Performans hedefi
- Masaüstü 60 fps; düşük segment Android ≥30 fps. p95 kare süresi < 16.7 ms (M4, 540×960),
  drag sırasında da. Halat mesh'i olay-tabanlı güncellenir; tam ekran ekstra render yok.

