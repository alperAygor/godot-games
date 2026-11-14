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
