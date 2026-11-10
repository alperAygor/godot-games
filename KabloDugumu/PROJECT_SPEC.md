# PROJECT_SPEC — Kablo Düğümü: Akım Ustası

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
