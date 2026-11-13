# Son başarım turu — SONRA (final_after)

Aynı makine, aynı araç (`tools/perf_probe2.gd`), aynı senaryolar; önce ölçümü `final_baseline.md`.
Ham çıktılar: `docs/perf/final_raw/after_cpu.md`, `after_window.md`, `after_leak.md`.

## Önce / sonra özeti

| Ölçü | Önce | Sonra | Neden |
|---|---|---|---|
| Boot -> ana ekran (0.4 sn bekleme dahil), pencere | 697 ms | **420 ms** | Ana ekran + oyun sahnesi beklemede iş parçacığında yüklenir |
| Boot -> ana ekran, başsız CPU | 699 ms | **419 ms** | aynı (bekleme sonrası eşzamanlı iş ~300 -> ~19 ms) |
| İlk oyun sahnesi açılışı (ilk "Oyna"), pencere / CPU | 137 / 136 ms | **13 / 12 ms** | aynı (`Game.tscn` + betikleri önceden derlendi) |
| Doku belleği, oyun L88 (pencere) | 34.4 MiB | **28.8 MiB** | Önceki sahnelerin mekân dokuları önbellekten atılır |
| Doku belleği, oyun L100 | 39.0 MiB | **27.9 MiB** | aynı |
| Doku belleği, L65 -> 66 Devam | 48.1 MiB | **41.5 MiB** | aynı |
| Doku belleği, zen | 45.5 MiB | **38.2 MiB** | aynı |
| Sızıntı: 12 sahne döngüsü sonu statik bellek | 80.0 MiB | **69.4 MiB** | önbellek sınırları gerçekten uygulanıyor |
| Sızıntı: kaynak sayısı (döngü 12) | 237 | **208** | aynı |
| Sızıntı: LevelPrefetch (döngü 12) | 25 sonuç / 13 görev | **4 / 1** | biten görevler toplanır, sınır kilitlenmez |
| Sızıntı: bahçe doku önbelleği (döngü 12) | 42 | **13** | sahneler arası budama |
| Oyunda boşta `_process` alan düğüm (L5..L100, başsız) | 5-7 | **4-6** | gizli öğretici eli işlenmiyor |
| Oyunda boşta `_process` (pencere, L10+) | 7-8 | **5-6** | + ipucu vermeyen seviyede yönetici işlenmiyor |
| Kare ort / p99, oyun L100 (pencere) | 1.75 / 3.98 ms | 1.76 / 4.17 ms | değişmedi (gürültü içinde; CPU tarafı zaten ~0.04 ms) |
| Çizim çağrısı ana ekran / oyun L88 | 108 / 290 | 107 / 290 | değişmedi (bilinçli, aşağıya bkz.) |

Sonra, tam tablo (pencere):

| Sahne | açılış (ms) | ilk kare (ms) | kare ort / p99 / en kötü (ms) | çizim çağrısı ort / en çok | doku (MiB) | düğüm | kaplama |
|---|---|---|---|---|---|---|---|
| boot -> ana ekran (0.4 sn bekleme dahil) | 420 | 17 | 1.43 / 4.00 / 7.3 | 160 / 160 | 19.7 | 293 | 5.7 |
| home | 3 | 3 | 1.18 / 2.84 / 5.0 | 107 / 107 | 19.7 | 198 | 4.1 |
| harita açılış (soğuk) + boşta | 2 | 5 | 1.01 / 2.85 / 4.0 | 152 / 251 | 20.5 | 210 | 1.3 |
| mağaza açılış (soğuk) | 10 | 26 | 0.91 / 2.72 / 3.5 | 138 / 238 | 22.4 | 455 | 2.0 |
| koleksiyon açılış (soğuk) | 15 | 11 | 0.85 / 2.59 / 3.2 | 84 / 182 | 22.3 | 366 | 2.2 |
| harita kaydırma | 0 | 4 | 1.54 / 3.66 / 4.4 | 128 / 257 | 20.9 | 211 | 1.3 |
| oyun L5 | 13 | 9 | 1.17 / 2.69 / 8.5 | 86 / 110 | 22.1 | 252 | 5.5 |
| oyun L70 | 39 | 14 | 1.59 / 3.02 / 11.9 | 214 / 311 | 30.2 | 357 | 6.2 |
| oyun L88 | 31 | 6 | 1.70 / 3.23 / 3.9 | 290 / 382 | 28.8 | 389 | 5.6 |
| oyun L100 | 22 | 13 | 1.76 / 4.17 / 10.5 | 239 / 453 | 27.9 | 350 | 5.4 |
| oyun L65 -> 66 (Devam) | 37 | 8 | 1.73 / 3.36 / 20.2 | 267 / 485 | 41.5 | 631 | 6.6 |
| zen (2 tahta) | 26 | 6 | 1.24 / 2.75 / 11.2 | 128 / 157 | 38.2 | 289 | 4.4 |
| oyun L100 (ikinci açılış) | 30 | 7 | 1.75 / 4.05 / 6.5 | 239 / 452 | 33.5 | 350 | 5.4 |

Bedel (bilinçli): prob senaryoları mekândan mekâna atladığı için "Devam" (20 -> 37 ms), zen (11 -> 26 ms) ve
"L100 ikinci açılış" (11 -> 30 ms) açılışları artık önceki mekânın dokularını diskten yeniden yükler; önce bunlar
sonsuza dek bellekte duruyordu. Gerçek akışta oyuncunun KAYITLI seviyesinin mekânı her zaman önbellekte kalır
(ana ekran <-> oyun <-> Devam yeniden yüklemez; `test_backdrop_cache.gd` doku kimliğiyle sınar); yeniden yükleme
yalnız haritadan başka mekândaki eski bir seviyeyi tekrar oynayınca, o mekâna dönüşte olur.

Not: değiştirilen `season_grade` gölgelendiricisi ilk pencere koşusunda bir kez derlendi (L70 ilk karesi 69 ms,
ikinci koşuda 14 ms — sürücü gölgelendirici önbelleği). Telefonda da yalnız ilk açılışta ödenir; önce de öyleydi.

## Ne değişti, neden

1. **`scripts/core/level_prefetch.gd`** — `_touch` önce biten görevleri toplar (`_reap_completed`:
   `is_task_completed` olanlar için `wait_for_task_completion` beklemeden döner ve havuz kaydını siler), sonra en
   eski BİTMİŞ sonuçları atar; üretimi süren anahtarı atlar (eskiden `break` edip tüm evden çıkarmayı durduruyordu).
   Davranış aynı: üretilen sözlükler değişmedi, seviye üretimi bayt bayt aynı (testler 1..15 + arka plan == eşzamanlı).
   Test: `test_level_prefetch.gd::test_untaken_request_does_not_block_eviction`.
2. **`scripts/game/garden_backdrop.gd`** — canlı arka planlar (`_live`) kaydı; yeni arka plan kurulurken ve ilk
   seviyede mekân hemen değişince `_prune_cache()`: önbellekte yalnız canlı setlerin (etkin + sönen) yolları,
   oyuncunun kayıtlı seviyesinin mekân x mevsim yolları ve ortak dokular (bulut, askı) kalır. Budama `_exit_tree`'de
   YAPILMAZ (ana ekran -> oyun geçişinde yeni sahne aynı dokuları hemen ister). İş parçacığında istenmiş "sonraki
   mekân" dokularına (`_requested`) dokunulmaz. Test: `test_backdrop_cache.gd`.
3. **`scripts/autoload/GameManager.gd` + `scripts/ui/boot.gd`** — `preload_scene()` / `scene_resource()`; Boot
   beklemesinde `home` ve `game` sahneleri `ResourceLoader.load_threaded_request` ile yüklenir (betik derlemesi
   dahil, iş parçacığında). `goto_scene` hazır `PackedScene`'i alır (`change_scene_to_packed`; `change_scene_to_file`
   ile aynı yol), bitmemişse bekler, yoksa eskisi gibi eşzamanlı yükler. Düğüm kurulumu (`_ready`) her zaman ana
   iş parçacığında. Çıkışta alınmamış istekler toplanır. Test: `test_scene_preload.gd`. Yarış denemesi: 12 soğuk
   açılışta ana iş parçacığı aynı anda başka sahneler yüklerken (0-250 ms gecikmeyle) kilitlenme/hata yok.
4. **`scripts/game/tutorial_hand.gd`** — `_ready`'de görünmüyorsa `set_process(false)`. Godot `_process` tanımlı
   düğümde işlemeyi hazır olunca kendiliğinden açtığından `_init`'teki kapatma eziliyordu; gizli el her kare
   `queue_redraw` çağırıyordu. Görünür hâli/davranışı aynı (`_begin` işlemeyi açar).
5. **`scripts/game/tutorial_director.gd`** — `_process` yalnız boşta ipucunu sayar ve `below_level` (10) ve
   üstünde hemen dönüyordu; artık o seviyelerde hiç açılmaz.
6. **`scripts/game/season_fx/season_grade.gdshader`** — `tex.a > 0` değilse HSV/gürültü/kar örneklemesi atlanır.
   `blend_mix` alfa 0'da kaynak rengi kullanmaz: çıktı bit bit aynı. Bahçe dokularında mipmap yok
   (`mipmaps/generate=false`), dallanma içindeki doku okumaları LOD açısından güvenli. Kazanç katmanların saydam
   bölgelerinde (gökyüzü vb.) GPU ALU'su — M4'te ölçülemeyecek kadar küçük, telefonda doğrulanmalı.
7. **`tools/perf_probe2.gd`** (yeni) — bu belgedeki tüm ölçümler; yeni testler `tests/unit/test_backdrop_cache.gd`,
   `tests/unit/test_scene_preload.gd`, `test_level_prefetch.gd`'ye 1 test.

## Bilinçli olarak dokunulmayanlar

- **Çizim çağrısı / batching:** her çamaşırın kendi `ShaderMaterial`'ı (sallanma fazı, desen, tekme) var; canvas
  gölgelendiricilerinde örnek başı uniform (`instance uniform`) yok, bu yüzden toplu çizim görüntüyü değiştirmeden
  birleştirilemez. Harita `_draw`'ında daire/yazı/simge sırası batch'i bölüyor (150-250 çağrı); sırayı gruplamak
  üst üste binme sırasını değiştirir. Mobil için 100-300 çağrı kabul edilebilir aralıkta.
- **Aşırı çizim (5-6.6 ekran):** katmanlı bahçe tasarımın kendisi. Dokuların saydam kenar kırpması yalnız %16
  kazandırır ve kış kar-tepesi örneklemesini (silüetin üstünü okur) bozardı. "Saydam ama çizilen" büyük öğe yok (0.00-0.02).
- **Mevsim derecelendirmesini dokuya pişirmek:** gölgelendirici her katmanda çalışıyor (yaz hariç); pişirmek
  ASTC sıkıştırmasını kaybettirir (4x doku belleği) ve hassasiyeti değiştirir. Yalnız saydam piksel erken çıkışı yapıldı.
- **Devam karesi (~12 ms M4):** çoğu yeni mekaniğin dokularının ilk eşzamanlı yüklenmesi; seviye başına doku
  listesi çıkarmak birçok görünüm sınıfına dağılmış bilgi gerektirir. Oturum başına mekanik başına bir kez, sonuç
  sayfası kapanırken oluyor. Telefonda ölçülmeli.
- **Düşük işlemci kipi (menüler):** harita/mağaza/koleksiyonda hiçbir düğüm işlenmiyor ama motor her kare yeniden
  çiziyor. `OS.low_processor_usage_mode` yalnız değişince çizer, fakat kare zamanlamasını (uyku + VSync) değiştirir
  ve ana ekran zaten sürekli canlı; "akıcılık değişmesin" kuralı gereği açılmadı. Telefonda pil ölçümüyle denenebilir:
  yalnız opak meta ekranı açıkken (`Home._set_covered`) açıp kapatmak tek satırlık değişiklik.
- **Ses akışları:** ~3 MB, ilk çalışta eşzamanlı ama küçük (en büyük ortam sesi 384 KB); önbellek kalıcı kalır.
- **Çevrimiçi kapı / reklam / elde tutma:** yoklama yok; `HTTPRequest` yalnız denetim sırasında. Değişiklik gerekmedi.
- `scripts/game/motion.gd` zamanlamaları, seviye üretimi, denge, görseller ve sesler değişmedi.

## Gerçek telefonda kontrol edilecekler

1. Soğuk açılış: Boot ekranından ana ekrana geçişte donma kısaldı mı; arka plan sahne yüklemesiyle ilk açılışta
   hata/kilitlenme yok mu (logcat'te `ResourceLoader`/`GDScript` hatası).
2. İlk "Oyna" anı (oturumun ilk oyun sahnesi) akıcı mı.
3. Haritadan başka mekândaki eski bir seviyeyi tekrar oynayıp ana ekrana dönünce/yeniden aynı mekâna girince
   doku yeniden yüklemesinin süresi (önce bellekte duruyordu; şimdi ~4-9 MiB ASTC diskten okunur).
4. Kış/sonbahar/ilkbahar seviyelerinde GPU kare süresi (`season_grade` en pahalı gölgelendirici); ilk açılışta
   gölgelendirici derleme takılması.
5. Uzun oturumda (30+ seviye, harita tekrarları, zen) bellek sabit kalıyor mu.
