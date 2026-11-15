# Changelog

Format [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/), sürümleme [SemVer](https://semver.org/lang/tr/).

## [Unreleased]

### Google Play yayın hazırlığı (orch/ci-release)
- Gradle Android şablonu (`android/`, 4.7.2.stable; AGP 8.6.1, hedef/derleme API 36, min 24); yayın ön ayarı: `com.clotheslinesort.game`, 1 / "1.0.0",
  AAB arm64, kenardan kenara, yalnız INTERNET + ACCESS_NETWORK_STATE; uygulama simgesi (adaptif + tek renk) `tools/make_app_icons.py`; debug AAB üretimi kanıtlandı.
- `ReleaseGuard` + `tools/release_check.sh` + `tools/aab_inspect.py`: yer tutucu/test AdMob kimliği, test modu, debug imza, sürüm kodu, izin, 16 KB ELF hizası, AAB manifest taraması.
- Reklam: UMP onayı çözülmeden reklam isteği/SDK başlatma yok (zaman aşımı artık başlatmaz); Ayarlar'da gizlilik seçenekleri (UMP gerektiriyorsa) ve gizlilik politikası düğmesi (`data/store.json`);
  `ConsentRules`, `StoreConfig`; yerleşim yapısal testi.
- Billing: `PlayBillingProvider` resmi eklenti v3.x `BillingClient` API'sine yeniden yazıldı (acknowledge, geri yükleme, PENDING, hata eşleme) + sahte istemci testleri; `docs/MONETIZATION.md` güncellendi.
- Belgeler: `docs/store/{RELEASE_STATUS,PENDING_APPROVALS,SIGNING}.md`; mağaza görselleri `docs/store/assets/`, `tools/store_shots.sh`.

### Ses yeniden yapımı (orch/ci-audio)
- Tüm müzik ve sesler ElevenLabs Starter planıyla yeniden üretildi (`docs/AUDIO_LICENSE.md`); 5 müzik parçası (menü, bahçe, sahil, çatı, gece),
  seviye hedefleri ölçülü miks (`docs/AUDIO.md`), Master sınırlayıcı, bus'lar, çapraz geçiş, kısma, dönüş sonrası toparlama.
- `MusicRouter` (saf mantık) + `tests/unit/test_music_router.gd`; `tools/audio_lib.py`, `tools/audio_report.py`.
### Akış (orch/ci-flow) — hızlı oyun, seviye geçişi, Oyna düğmesi (`docs/perf/flow.md`)
- Hızlı oyun animasyonla engellenmez: uçuşlar dokunuş anında başlar (yeni komut eski uçuşu yeniden
  hedefler), sepet tamamlanma/geliş dizileri sepet başına ayrı kanalda ve nesil etiketiyle oynar, süs
  beklemeleri yeni dokunuşla biter; dokunma mantıksal yerden sınanır (`GarmentView.line_home`).
- Uyarlanır tempo `Motion.pace` (sakin oyunda 1, hızlı oyunda 3x'e kadar; kayıtlı Tween'ler sürerken de
  hızlanır); seviye sonu dizisi dokununca atlanır; `SoundGate` ses tekrarını/kesilmesini sınırlar.
- Seviye geçişi: sonraki seviye geçiş reklamını beklemeden kurulur, reklam (kural aynı) üstünde gösterilir;
  "Devam"dan oynanabilir kareye 1.2 sn -> 16-31 ms.
- Ana ekran yerleşimi `HomeLayout` (kullanılabilir alandan oranla): Oyna her telefonda ortalı ve alt-ortada.
- Araçlar: `tools/speed_probe.gd` (ölçüm + stres + görünüm==tahta denetimi; `verify.sh` kısa kipini koşar),
  `tools/home_shot.gd`; testler `test_flow_layout.gd`, `test_flow_pace.gd`.

### Yerelleştirme (orch/ci-i18n) — Türkçe / İngilizce / İspanyolca
- Tek kaynak tablo `data/i18n/strings.csv` (`keys,tr,en,es`; Godot CSV içe aktarımı -> `.translation`,
  `project.godot` `locale/translations`, `locale/fallback="tr"`). Anahtarlar sabit UPPER_SNAKE.
- `Loc` (scripts/core/loc.gd): `t/f/n` (çoğul duyarlı), cihaz dilinden otomatik seçim (tr/en/es, diğer -> en),
  kayıt `Progress` `settings.language`; `Boot` ilk ekrandan önce uygular.
- `UiStrings/TutorialStrings/DailyStrings/MetaStrings` anahtar sarmalayıcıları oldu; serbest metinler tabloya taşındı.
- Ayarlar sayfasında TR/EN/ES hap düğmeleri (`UiLanguageRow`); dil değişince sahne baştan kurulur.
- Araçlar `--lang=tr|en|es` alır; `tests/unit/test_loc.gd` tablo/yer tutucu/kullanılmayan anahtar denetimi yapar.

### Dil genişlemesi (orch/ci-i18n) — pt, de, ja, ko
- 245 anahtar x 4 yeni dil; oyun adı tr dışında "Clothesline Sort". Dil seçici yerel adlarla (Português, Deutsch, 日本語, 한국어).
- `LocFonts`: ja/ko için SystemFont yedek zinciri (paket +0 bayt, Android cihazda doğrulanmadı); Korece kelime bağlama.
- `Loc`: cihaz dili eşleme (`language_for_locale`), yedek zinciri en -> tr, `locale/fallback="en"`.
- `tools/lang_probe.gd` yedi dil + ekran sığma denetimi; `test_loc` genişledi; `subset_font.py --check`.
- İnceleme listesi: `docs/I18N.md` "Native gözden geçirme listesi".

### Eklenecek
- Oyun mekaniği

### Son başarım turu (orch/r-perf) — ölçümler `docs/perf/final_baseline.md` / `docs/perf/final_after.md`
- Ölçüm aracı `tools/perf_probe2.gd`: açılış (Boot emülasyonu), ana ekran, harita (boşta + kaydırma),
  mağaza/koleksiyon (soğuk + ılık), oyun L5/L70/L88/L100, Devam, zen; kare/CPU süresi, takılma kareleri,
  işlenen düğümler, kaplama (overdraw vekili); `--leak` kipinde 12 Devam + 12 tam sahne döngüsü.
- `LevelPrefetch`: hiç alınmayan istek (tekrar oynanan seviyenin sonrakisi, yarım zen tahtası) önbellek
  sınırını kilitliyordu; biten görevler artık toplanır, sınır gerçekten 4 (12 döngüde 25 -> 4 sonuç).
- `GardenBackdrop`: sahneler arası doku önbelleği budanır (canlı arka planlar + kayıtlı seviyenin mekânı);
  önceki sahnenin mekân/mevsim dokuları artık kalıcı kalmıyor.
- `GameManager.preload_scene`: Boot beklemesinde ana ekran ve oyun sahnesi (betik derlemesiyle) iş
  parçacığında yüklenir; `goto_scene` hazır kaynağı alır (`change_scene_to_packed`).
- Boşta işleme: gizli öğretici eli (`TutorialHand`) ve ipucu verilmeyen seviyelerde `TutorialDirector`
  artık her kare işlenmiyor.
- `season_grade.gdshader`: tam saydam pikselde HSV/gürültü/kar hesabı atlanır (görüntü bit bit aynı).

### Başarım (orch/ci-perf) — ölçümler `docs/perf/baseline.md` / `docs/perf/after.md`
- `LevelPrefetch` (scripts/core): seviye üretimi WorkerThreadPool'da; sonraki seviye oynarken
  üretilir, Boot/ana ekran oyuncunun seviyesini önceden ister, günlük bulmaca kart açıkken kurulur.
  Sonuç eşzamanlı üretimle birebir aynı (`test_level_prefetch.gd`). "Devam" karesi 1017 ms -> ~25 ms.
- Doku belleği: büyük bahçe katmanları + 47 çamaşırhane katmanı VRAM sıkıştırmalı (mobil ASTC 4x4,
  masaüstü BPTC); çamaşırhane katmanları 4'ün katına dolduruldu (yeniden ölçeklemesin, bulanmasın;
  `make_meta.py` de öyle kırpar); 6 çamaşır dokusu 384 px içe aktarılır (havlu/çarşaf 768 kalır).
- Çamaşırhane isabet testi tam RGBA kopya yerine 1 bit maske (`BitMap`) tutar.
- Ana ekran, opak meta ekranı (çamaşırhane/koleksiyon) açıkken kendi katmanlarını gizler/durdurur.
- `game.gd`: `_draw` artık her kare değil tahta değişince; gökyüzü gradyanı yalnız görünür değişimde
  yeniden üretilir. Bahçe/gökyüzü: durağan tonlar yalnız görünüm değişince yazılır.
- Bahçe dokuları uygulama boyunca bir kez yüklenir (Boot beklemesinde iş parçacığında başlar).
- Çıkış sızıntıları giderildi (ses akışları, eco_probe sahte düğmeleri, yarım doku yüklemeleri);
  sıkma parçacıkları bitince silinir; hızlı oyunda silinmiş görünüme olay gelmesi (`_live`) düzeltildi.
- `physics_ticks_per_second` 60 -> 30 (fizik kullanılmıyor). Yeni araç: `tools/perf_probe.gd`.

---

## [0.1.0] — 2026-11-13

### Eklendi
- studio-kit şablonundan iskelet: Boot/Menu/Game/Result, autoload dörtlüsü,
  tema + OFL font, `RunScoring` ve birim testleri, `tools/verify.sh`.
