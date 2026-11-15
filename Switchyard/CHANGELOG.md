# Changelog

Format [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/), sürümleme [SemVer](https://semver.org/lang/tr/).

## [Unreleased]

### Eklendi
- Şablondan ilk iskelet: Boot → Home → Game → sonuç sayfası akışı, yer tutucu oyun (`PlaceholderRun`).
- Autoload'lar (GameManager, AudioService, AdManager, GameData, Progress), reklam sağlayıcı arayüzü + sahte sağlayıcı
  + AdMob köprüsü, geçiş reklamı kuralı (`AdPacing`, `data/ads.json`), çevrimiçi kapısı.
- UI kiti (`UiKit`, `UiTokens`, tema üreticisi), Sheet'ler, HUD, ayarlar sayfası (ses/müzik/titreşim/dil).
- Yerelleştirme (tr/en/es), testler, `tools/verify.sh`, `play_probe`, `lang_probe`, ekran görüntüsü aracı.
