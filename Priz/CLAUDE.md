# Priz — proje kuralları

Android için reklam gelirli, dikey (1080x1920) minyatür diorama bulmaca oyunu. Godot 4.7.2 (gerçek 3B,
Mobile renderer), varlıklar Blender 5.2 ile üretilir. Tasarımın tamamı: `docs/DESIGN.md` (kullanıcının
belgesi; değiştirilmez). Kararlar ve ertelenenler: `DECISIONS.md`. Aşamalar: `TASKS.md`.
Varlık listesi: `ASSETS.md`.

## Değişmez kurallar

1. **Görsel kural 1:** low-poly, düz renkli ya da prototip görünüm YOK. Yumuşatılmış kenarlar, gerçekçi
   oranlar, ayırt edilebilir malzemeler (ahşap, kumaş, metal, cam), dekorla dolu odalar. Işık oyunun
   yıldızıdır.
2. **Ekranda rakam yok.** Yük ve kapasite blok, tüp, ibre gibi görsel öğelerle anlatılır.
3. Her dokunuş 100 ms içinde görsel ve işitsel karşılık verir.
4. Çözülemeyen seviye yayına girmez; bunu birim testi garanti eder.
5. Telifli ya da lisansı belirsiz varlık kullanılmaz. Her şey Blender betikleriyle ya da ElevenLabs ile
   üretilir; dışarıdan dosya indirmek kullanıcının açık onayını ister.

## Kod

- GDScript tümüyle tipli (`untyped_declaration` hatadır). Tanımlayıcılar İngilizce, yorumlar ve belgeler Türkçe.
- Çekirdek mantık `scripts/core/` altında, `RefCounted`, sahneden bağımsız, iş parçacığı güvenli ve birim
  testli. Sahne kodu çekirdeğe yalnız belgelenmiş arayüzle (`docs/CORE_API.md`) dokunur.
- İçerik öğeleri veri odaklıdır: yeni öğe = yeni kaynak dosyası (`data/elements/`), çekirdeğe dokunmadan.
- Kullanıcıya görünen metin `data/i18n/strings.csv` içindedir (tr, en, es); dosya yalnız sona eklenir.

## Doğrulama (kabul kapısı)

- `godot --headless --path . --import` (betik eklendiyse iki kez), sonra `tools/verify.sh`.
- Başsız denemeler `tools/*_probe.gd`: çıktıda `SONUC: gecti` aranır, `SCRIPT ERROR` olmamalı.
- Görsel işler gerçek pencere ister; öndeki başka pencere aracı asabilir. Her gerçek pencere çalıştırması
  sert zaman aşımıyla yapılır. Gerçek zamanlı deneme yavaş olabilir: yavaş ≠ asılı.
- Ekran görüntüleri `build/shots/` altına yazılır (depoya girmez).

## İşçi kuralları

- İşçiler yalnız Claude modelleridir; Fable yönetir, Haiku/Sonnet/Opus zorluğa göre atanır.
- Her işçi kendi çalışma kopyasında (`orchestra/wt.sh new <görev> godot-games/Priz`) ve yalnız kendisine
  verilen dosyalarda çalışır. Ortak dosyalara küçük, işaretli kancalar eklenir.
- Asla `pkill`/`killall` (yalnız kendi başlattığın PID). Asla `git stash`, `git checkout --`, `git reset`,
  `git clean`. İşçi commit atmaz, dal değiştirmez; commit ve birleştirme liderindir. Push yalnız kullanıcı
  isteyince.
- `.env*` dosyaları okunmaz, yazdırılmaz. Anahtarlar koda girmez.
- Araçlar oyuncunun gerçek kaydına yazmaz (`Progress.persist = false`).
- Doğrulama çalışırken ana dala birleştirme yapılmaz.

## Ses

Sesler ve müzik ElevenLabs ile, anahtarı `.env.local` dosyasından yükleyen bir betikle üretilir.

## Kabuk (p2-shell)

Oyundan bağımsız uygulama kabuğu şablondan geldi; ayrıntı `docs/ARCHITECTURE.md` (Game ↔ kabuk sözleşmesi dahil).

- Yerler: `scripts/autoload/` (GameManager, AudioService, AdManager, GameData, Progress), `scripts/shell/` (Loc, AdPacing, ProgressData,
  Quantity, Haptics, AnalyticsLog, Motion, Juice, Icons; testleri `tests/unit/test_shell_*.gd`), `scripts/ui/` (ekranlar, `UiKit`, sayfalar,
  `UiChip`, `UiPips`), `scripts/services/` (reklam sağlayıcıları), `scripts/net/`, `data/` (`ads.json`, `balance.json`, `theme.json`,
  `i18n/strings.csv`). Rehberler: `docs/UI_GUIDE.md`, `docs/I18N.md`, `docs/MONETIZATION.md`.
- **Rakam yok** kuralı otomatik korunur: `strings.csv` değerleri rakamsızdır, `tools/digit_probe.gd` ekranları gezer. Miktar = simge/nokta.
- Reklam politikası yalnız `data/ads.json` + `AdPacing`; ilk 3 seviye sessiz (`Progress.is_quiet_period()`), banner yalnız mahalle/koleksiyon.
- Tema: `data/theme.json` → `python3 tools/build_theme.py` (`ui_tokens.gd` ve `ui_theme.tres` elle düzenlenmez; `verify.sh` günceli denetler).
- **Prob tuzakları:** `-s` ile çalışan araç/prob betiği autoload'lardan ÖNCE derlenir; autoload'a değen sınıfları (ResultSheet, RunFlow,
  PauseSheet, SettingsSheet...) tür olarak anmaz — `Node`/`Control` tutup `call`/`emit_signal` kullan. Autoload `_ready`leri betiğin
  `_initialize`ından sonra çalışır: `Progress.persist=false` hemen, ama `reset_state` ve `AdManager.set_provider` ilk kareden SONRA.
  Godot betik hatasında da 0 döner: çıktıda `SCRIPT ERROR` / `Parse Error` / `PROBE HATA` aranır (verify.sh yapar).
- Yeni autoload/çeviri/girdi ayarı `project.godot`'ta işaretli bölümlere eklenir; çizici ayarlarına dokunulmaz.
