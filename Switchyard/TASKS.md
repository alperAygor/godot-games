# TASKS — Switchyard

| Faz | Konu | Durum |
|---|---|---|
| 0 | Şablon iskeleti (Boot/Home/Game/sonuç, autoload'lar, tema, i18n, testler, probelar) | ✅ |
| 1 | Oyun mekaniği | ⬜ |
| 2 | Derinlik / içerik | ⬜ |
| 3 | Performans | ⬜ |
| 4 | 3 dil (TR/EN/ES) cilası | ⬜ |
| 5 | Boyut küçültme + yayın (AdMob kimlikleri, imza, mağaza) | ⬜ |

## Faz 0 — Şablon iskeleti ✅

- [x] `project.godot` — portre, `gl_compatibility`, ASTC/ETC2, statik tip hataları açık
- [x] Autoload'lar: `GameManager`, `AudioService`, `AdManager`, `GameData`, `Progress`
- [x] Akış: Boot → Home → Game → sonuç sayfası; yer tutucu oyun
- [x] Tema + UI kiti + OFL font (Baloo 2), ayarlar (ses/müzik/titreşim/dil)
- [x] Reklam: sağlayıcı arayüzü + sahte sağlayıcı + AdMob köprüsü (eklenti kurulmadan etkin değil)
- [x] Testler, `verify.sh`, `play_probe`, `lang_probe`

---

## Faz 1 — Oyun mekaniği

**Hedef (kilometre taşı 1):** oynanabilir manevra bulmacası; 2 dünya / 40 ölçülmüş seviye; ipucu, atlama, geçiş
reklamı ve "reklamları kaldır" akışları (sahte sağlayıcıyla); ajan oyun testi raporu; deneme APK'sı.

- [ ] `sy-core` (Opus): kurallar (GDScript) + Python aynası, çözücü, üreteç, uygunluk vektörleri, metin arayüzü, ilk seviyeler
- [ ] `sy-shell` (Sonnet): kabuk — seviye haritası, HUD, sonuç, reklam politikası, satın alma arayüzü, dil kuralı
- [ ] `sy-view` (çekirdek birleşince): saha görünümü, girdi, canlandırma (`LevelSession` uygulaması)
- [ ] `sy-playtest` (seviyeler gelince): kör oyun testi ajanları
- [ ] `sy-android`: derleme şablonu, AdMob ve faturalandırma eklentileri, deneme APK'sı

- [ ] `PlaceholderRun` yerine gerçek kural sınıfı (saf, testli)
- [ ] `game.gd` YER TUTUCU bölümlerinin değişimi
- [ ] `play_probe.gd` oynama döngüsünün güncellenmesi

**Bitti kriteri:** ...
