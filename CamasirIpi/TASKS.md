# TASKS — Çamaşır İpi

| Faz | Konu | Durum |
|---|---|---|
| 0 | İskelet (Boot/Menu/Game/Result, autoload'lar, tema, testler) | ✅ |
| 1 | Oyun mekaniği | ⬜ |

## Faz 0 — İskelet ✅

- [x] `project.godot` — portre, `gl_compatibility`, statik tip hataları açık
- [x] Autoload dörtlüsü: `GameManager`, `AudioService`, `AdManager`, `GameData`
- [x] Sahneler: Boot → Menu → Game → Result
- [x] Tema + OFL font (Baloo 2)
- [x] `RunScoring` + birim testleri
- [x] `tools/verify.sh`

---

## Faz 1 — Oyun mekaniği

**Hedef:** (buraya yaz)

- [ ] ...
- [ ] ...

**Bitti kriteri:** ...

## Çamaşır İpi — prototip
- [x] **P1** Çekirdek kurallar (`LaundryBoard`), seviye üretici (`LevelGenerator`), çözücü (`LevelSolver`) + birim testleri
- [x] **P2** Oynanabilir oyun ekranı (ipler, askı, sepetler, kuyruk, kazanma/kaybetme, +1 askı) + `tools/play_probe.gd`
- [x] **P3** Yüksek kaliteli çamaşır/sepet/mandal sprite'ları (`tools/blender/make_sprites.py` + `tools/post_sprites.py`)
- [x] **P4a** Engeller: ıslak (sv 8), gizemli (sv 14), kilitli mandal (sv 20); ASMR ses seti; bahçe arka planı; havada katlanma, sepet yığını, parıltı
- [ ] **P4b** Çarşaf, çorap çifti, boya akıtan; güçlendiriciler; renk körlüğü desenleri
- [ ] **P5** Ana ekran (çamaşırhane), ekonomi, reklam yerleşimi
- [x] **P6** Premium geçiş (2.5D): Blender render bahçe katmanları + askı, yeniden yapılan çamaşır/sepet/mandal modelleri (Cycles), yavaş ve yumuşak animasyonlar (`Motion`, kumaş sallanma shader'ı), ElevenLabs ses seti (`tools/make_el_sfx.py`)
- [x] **PERF** Başarım turu: arka plan seviye üretimi (`LevelPrefetch`), VRAM sıkıştırma (ASTC), kare başı işlerin azaltılması, sızıntılar; ölçüm aracı `tools/perf_probe.gd`, sonuçlar `docs/perf/`. Gerçek Android cihazda doğrulanacak: ASTC görüntü kalitesi, kare süresi, açılış süresi.

## Aşama 3 — birleşik plan (2026-11-13)
Kural: her işçi kendi çalışma kopyasında ve yalnız kendi dosyalarında çalışır; ortak dosyalara
(game.gd, strings.csv) yalnız işaretli küçük ekleme yapar; birleştirmeyi yönetmen yapar.

Dalga 1 — paralel (çalışıyor)
- [ ] **E1** Etkileşimler (Opus, `ci-machines`): çamaşır makinesi, kurutma makinesi, makine geliştirmeleri, tür sepetleri, kuşlar, yağmur bulutu, kedi — kural + Blender modelleri + görünümler + tanıtım kartları
- [ ] **M1** Para kazanma (Sonnet, `ci-money`): jetonla devam kalkar, her geçişte reklam (4+), reklam kaldırma, AdMob/Billing sağlayıcıları, mağaza, mandal/ip görünümleri
- [ ] **R1** Oyuncu tutma (Sonnet, `ci-retain`): günlük görevler, kilometre taşı sandıkları, haftalık etkinlik, geri dönüş ödülü, bildirim altyapısı
- [ ] **P1** Mekânlar (Opus, `ci-places`): sahil ve çatı katı arka planları (Blender), mekân döngüsü
- [x] **S1** Sesler (yönetmen): makine, kuş, yağmur, kedi, sandık, satın alma; sahil/çatı/gece ortam sesleri (ElevenLabs)
- [x] **B1** Sepet 3B modeli; **A1** çamaşırhane su birikintisi ve tezgâh

Dalga 2 — birleştirme (yönetmen, sırayla): P1 → R1 → M1 → E1; her birinden sonra test + problar.
Bağlama işleri: yeni seslerin olaylara bağlanması; ana ekrana görev/sandık/haftalık satırı, makine
geliştirme girişi; mekâna göre ortam sesi; AdMob/Billing eklentilerinin indirilmesi (kullanıcı onayı).

Dalga 3 — sırayla (tek yazıcı)
- [ ] **L2** Yeni metinlerin TR/EN/ES denetimi ve taşma kontrolü
- [ ] **Z1** Paket boyutu küçültme
- [ ] **F1** Son performans turu + Android derlemesi — performans kısmı yapıldı (`docs/perf/final_after.md`, `tools/perf_probe2.gd`); Android derlemesi ve gerçek cihaz ölçümü kaldı

## Aşama 4 — kuyruk (kullanıcı kararı 2026-11-13)
SIRA: dalga 1-2 bitince ÖNCE bu aşama, SONRA dalga 3 (L2 çeviri denetimi, Z1 boyut, F1 performans + Android).
Mevsimler seviye bantlarıyla: ör. 1-30 yaz, 31-60 sonbahar, 61-90 kış, 91-120 ilkbahar; her mevsime özel, oynanışı etkileyen olaylar.
- [ ] **Q1** Renk körlüğü desenleri (her renge desen; varsayılan açık)
- [ ] **Q2** Seviye haritası (kaydırılabilir yol, yıldızlar, geri dönüp 3 yıldız alma)
- [ ] **Q3** Çift renkli çamaşır (iki renkten birinin sepetine gider)
- [ ] **Q4** Zen modu (kaybetme yok, sakin sonsuz oyun)
- [ ] **Q5** Çevrimdışı oynamak yasak: bağlantı yoksa "bağlantı gerekli" ekranı
- [ ] **Q6** Mevsim ve kültür temaları: mekânla birlikte değişen görsel/ses seti + temaya özel, oynanışı etkileyen olaylar
