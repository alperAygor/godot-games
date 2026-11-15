# Changelog

Format [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/), sürümleme [SemVer](https://semver.org/lang/tr/).

## [Unreleased]

### Kabuk (sy-shell)
- Yer tutucu oyun ve jeton ekonomisi kaldırıldı (`PlaceholderRun`, jeton hapı, 2x ve devam et, `PH_*` kullanımı, `coin` sesi).
- Akış: Boot -> Ana ekran (devam + Seviyeler) -> Seviye haritası (dünya grupları, yıldız, kilit, atlandı) -> Oyun
  (HUD: seviye, hamle, par; geri al, baştan, ipucu, atla, duraklat) -> Sonuç sayfası (1-3 yıldız, hamle/par, Sonraki/Tekrar/Seviyeler).
- `LevelSession` sözleşmesi: oyun sahnesi sahaya yalnız bunun üzerinden konuşur; tek bağlanma noktası `Game._create_session()`
  (KANCA). Kabuk probeleri için `StubSession`.
- `LevelProgress` (saf, testli): en iyi hamle, yıldız (çözmek 1, <= ceil(par x 1,5) 2, <= par + `three_star_slack` 3),
  atlandı, kilit, "devam" hedefi; kayıt `Progress` modül verisi "levels".
- Reklam politikası (`AdPacing`, `data/ads.json`): ipucu ve atla = ödüllü reklam, 1-3. seviyede düğme yok; geçiş reklamı
  3, 6, 9, 12. seviye bitişlerinde, en az 60 sn aralık, ödüllü izlenen seviyede ve "reklamları kaldır" varken yok.
- Satın alma: `IapProvider` / `MockIapProvider` / `IapService` (kardeş proje ile aynı arayüz), "Reklamları kaldır" satırı
  (ayarlar + ana ekran sayfası). Eklenti KURULMADI.
- Dil kuralı: `LanguagePick` (kayıtlı seçim > cihaz dili > İngilizce), `locale/fallback=en`; testler dili sabitler.
- `play_probe` gerçek akışı 12 seviye boyunca sahte saha ve sahte reklamla sürer; `screenshot` boyut ve etiket alır.

### Değişti
- `AdManager.Placement` artık `HINT, SKIP, INTERSTITIAL` (INTERSTITIAL sırası aynı). `Progress`tan jeton/seviye API'si kalktı.
- `strings.csv`: eski `WIN_*`, `LOSE_*`, `PH_*` satırları (append-only olduğu için) tabloda kaldı, kullanılmıyor.

### Eklendi
- Şablondan ilk iskelet: Boot → Home → Game → sonuç sayfası akışı, yer tutucu oyun (`PlaceholderRun`).
- Autoload'lar (GameManager, AudioService, AdManager, GameData, Progress), reklam sağlayıcı arayüzü + sahte sağlayıcı
  + AdMob köprüsü, geçiş reklamı kuralı (`AdPacing`, `data/ads.json`), çevrimiçi kapısı.
- UI kiti (`UiKit`, `UiTokens`, tema üreticisi), Sheet'ler, HUD, ayarlar sayfası (ses/müzik/titreşim/dil).
- Yerelleştirme (tr/en/es), testler, `tools/verify.sh`, `play_probe`, `lang_probe`, ekran görüntüsü aracı.
