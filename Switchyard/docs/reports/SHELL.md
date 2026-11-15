# SHELL raporu (sy-shell)

Durum: **bitti, `bash tools/verify.sh` yeşil.** Gerçek cihazda ve gerçek reklamla doğrulanmadı (bkz. "Doğrulanmayanlar").

```
== 3/5 birim testleri ==   152 test, 1298 doğrulama — 0 başarısız, 0 dosya hatası
== 4/5 tema guncel mi ==   tema guncel
== 5/5 probelar ==         + play_probe gecti   + lang_probe gecti
SONUC: gecti
```

## Görev durumu
1. Yer tutucu oyun + jeton ekonomisi kaldırıldı (PlaceholderRun, jeton hapı, 2x, devam et, `PH_*` kullanımı, `coin` sesi, testleri) — **bitti**
2. Akış Boot -> Home -> Map -> Game -> Sonuç — **bitti**
3. `LevelSession` sözleşmesi + `StubSession` + tek kanca — **bitti**
4. İlerleme (`LevelProgress`, testli) — **bitti**
5. Reklam politikası (`AdPacing`, `data/ads.json`, `docs/MONETIZATION.md`) — **bitti**
6. Satın alma arayüzü + mock + "Reklamları kaldır" satırı — **bitti** (eklenti kurulmadı)
7. Dil kuralı (`LanguagePick`, fallback `en`, testler dili sabitler) — **bitti**
8. Probelar — **bitti**
9. Ekran görüntüleri — **bitti** (aşağıda)

## Akış
- **Home:** üstte yıldız hapı (toplam yıldız), reklam kaldırma ikonu (sahip olununca kalkar), ayarlar; ortada ad; altta büyük
  "Seviye N" (ilk tamamlanmamış seviyeden devam) ve sakin "Seviyeler". Yerleşim kapsayıcıyla: uzun/kısa ekranda alt düğmeler alta oturur.
- **Map:** dünyaya göre gruplu 4 sütun karo; çözülmüş (yeşil + yıldızlar), şimdiki (dolu vurgu), açık, kilitli (kilit ikonu), atlandı
  (amber + ileri-atla işareti). Kilitliye dokununca "önce önceki seviyeyi bitir". Şimdiki karo görünür kaydırılır. Karolar tek `_draw`.
- **Game:** üstte duraklat, "Seviye N", harita; altında Hamle / Par; saha alanı (`LevelSession`); altta geri al, baştan, ipucu, atla
  (ipucu ve atla video rozetli, 1-3. seviyede yok). Geri tuşu duraklatır. Duraklatma: ses/müzik/titreşim, Seviyeler, Ana ekran, Devam.
- **Sonuç sayfası:** 1-3 yıldız (sırayla belirir), başlık (Mükemmel / Çok iyi / Çözüldü), "Hamle X · Par Y", gerekirse "Yeni rekor",
  büyük Sonraki (son seviyede Seviyeler), ikincil Tekrar ve Seviyeler.
- Dokunma hedefleri >= 126; her ekran güvenli alanı (`UiKit.safe_insets`) ve alt boşluğu kullanır.

## Seviye ilerlemesi
Kayıt: `Progress` modül "levels", anahtar seviye kimliği, `{best, stars, solved, skipped}` (kimlikle: dizin sırası değişse bozulmaz).
Yıldız: çözmek 1; hamle <= ceil(par x 1,5) 2 (tamsayı: `2 x hamle <= 3 x par + 1`); hamle <= par + `three_star_slack` 3
(`data/balance.json`, varsayılan 0). En iyi hamle ve yıldız kötü denemeyle düşmez. n+1, n çözülünce ya da atlanınca açılır.
"Devam" = ilk tamamlanmamış (ne çözülmüş ne atlanmış) seviye.

## Reklam sıklığı (tam kural)
`data/ads.json`: `first_level 4`, `every_n 3`, `min_gap_seconds 60`, `suppress_after_rewarded true`, `rewarded.buttons_from_level 4`.
Geçiş reklamı bir seviye **ilk kez** tamamlandığında (çözme ya da atlama), oyuncu sonuç sayfasından **Sonraki ya da Seviyeler** ile
çıkarken, ve yalnız şu hepsi doğruysa: sıra gelmişse (sıradaki seviye numarası >= `first_level` ve `(sıradaki - first_level) % every_n == 0`),
reklamlar kaldırılmamışsa, o seviyede ödüllü reklam (ipucu/atla) izlenmemişse, son geçiş reklamından >= 60 sn geçmişse, sağlayıcı
hazırsa. Atlanan reklam ertelenmez. Oyun sırasında asla.

12 seviye örneği (hep ilk kez, >= 60 sn aralık, ödüllü yok): reklam **3, 6, 9, 12. seviye bitişinde** (3->4, 6->7, 9->10, 12->13).
1, 2, 4, 5, 7, 8, 10, 11 bitişinde yok. 6'da ipucu izlendiyse 6'daki yok, 9'daki gelir; 9 atlandıysa 9'daki yok;
6'daki 3'ten 30 sn sonra gelirse yok; "reklamları kaldır" varsa hiçbiri.

## Oturum kancası
`scripts/ui/game.gd` içinde tek fonksiyon: yorum satırı `# KANCA: gerçek saha görünümü (YardSession) burada bağlanır` hemen
`func _create_session() -> LevelSession:` üstünde; gövde şimdi `return StubSession.new()`. Gerçek görünüm gelince gövde
`return YardSession.new()` olur. Game sahaya yalnız `load_level`, `undo`, `restart`, `show_hint`, `set_input_enabled` ve
`move_count_changed`, `can_undo_changed`, `solved`, `hint_finished` ile dokunur (hamle/par HUD'a, undo düğmesine, çözüm sonuç sayfasına gider).
`YardSession` Control olarak `Board` alanına tam dolgu eklenir (anchor tam ekran). Seviye başına yeni oturum kurulmaz: aynı oturuma `load_level`.

## Mock olanlar
- Reklamlar: `MockAdsProvider` (debug) / `NoAdsProvider` (release). Probelar kendi anında biten sağlayıcısını kullanır. Gerçek AdMob yok.
- Satın alma: `MockIapProvider` ($2.99). Gerçek Play Billing yok.
- Saha: `StubSession`. Seviye dizini 8 yer tutucu (probelar ve ekran görüntüleri sentetik katalog kurar, gerçek dizine bağlı değil).

## Brief'ten sapmalar
- **`BillingService` adı yerine `IapProvider` / `MockIapProvider` / `IapService`.** Kardeş projedeki (CamasirIpi) adlar ve sinyallerle
  birebir aynı; gerçek `play_billing_provider.gd` olduğu gibi kopyalanır. Ek olarak sahiplik `Progress.remove_ads_owned()` ile okunur.
- **Geçiş reklamı sırası:** "ilk 3 seviyede yok, sonra her 3 seviye bitişinde bir" şöyle yorumlandı: 3, 6, 9, 12. bitişte
  (`first_level 4` = önünde reklam gelebilecek ilk seviye). Alternatif okuma (6, 9, 12...) istenirse `first_level`'ı 7 yap (veri).
- **Reklam, sonuçtan Seviyeler'e çıkarken de gelir** (yalnız Sonraki'de gelseydi harita üzerinden kaçılırdı); Tekrar'da gelmez.
- **İpucu da "o seviyede ödüllü izlendi" sayılır** ve o seviyenin geçiş reklamını bastırır (`suppress_after_rewarded`; `false` yaparsan yalnız atlama bastırır).
- **Yalnız ilk tamamlamada reklam** (tekrar oynayarak reklam toplama/atlama yok). Brief'te yoktu.
- **"Devam" hedefi = ilk tamamlanmamış seviye** (atlanan seviyeye otomatik dönülmez; haritadan seçilir). Brief "ilk çözülmemiş" diyordu.
- **Atla için onay sayfası** eklendi (yanlışlıkla reklam açılmasın). Reklam hazır değilken onay açılmaz, neden hemen söylenir.
- **Cihaz dili kayda yazılmaz** (şablon yazıyordu): kayıt yalnız oyuncunun elle seçimi; cihaz dili sonradan değişirse oyun izler.
- **`strings.csv` satırları silinmedi** (append-only): `WIN_*`, `LOSE_*`, `PH_*` tabloda kaldı; `test_loc` bunları `RETIRED_KEYS` ile kullanılmayan-anahtar denetiminden muaf tutar. Silmek istersen lider yapar.
- Ek ikonlar (indirme yok, Lucide yollarından elle yazıldı): `undo-2`, `lightbulb`, `skip-forward`, `ban`, `chevron-right`; `arrow-left`, `grid-2x2` kardeş projeden kopyalandı; dolgulu yıldız `assets/icons/shell/star-fill.svg` (Lucide yıldız yoluna dolgu). `assets/icons/LICENSES.md` güncellenmedi (kapsam dışı).
- `AdManager.Placement` = `HINT, SKIP, INTERSTITIAL` (INTERSTITIAL hâlâ 2: sağlayıcı katmanı değişmedi).

## Bitmemiş / lidere not
- Gerçek saha görünümü (`YardSession`), gerçek seviyeler: kancaya bağlanacak. Görünüm `Board` alanında (üstte HUD, altta çubuk) çizilir.
- Play Billing eklentisi ve gerçek AdMob kurulumu (ayrı görev).
- Elle güncellenmesi gerekenler (bende değil): `CLAUDE.md` §1-3 ve §6 hâlâ `PlaceholderRun`/jeton/`scripts/ui/game.gd YER TUTUCU` anlatıyor;
  `docs/I18N.md` "fallback tr" ve `PH_` diyor; `docs/UI_GUIDE.md` jeton rengini anıyor; `TASKS.md` işaretleri; `tools/verify.sh` değişmedi.
- İlerleme kaydı biçimi `SAVE_VERSION 2` (eski `level`/`coins` alanları okunurken yok sayılır, kayıt bozulmaz).
- Ses: "coin" sesi `data/sounds.json`'dan çıktı, `assets/audio/sfx/coin.wav` dosyası yerinde (silmek lider işi). Yıldız belirişi `ui_soft` ses perdesi artarak çalar; özel yıldız sesi yok.
- Ana ekran sade/seyrek: oyun görseli (saha önizlemesi) gelince başlık bloğu yeniden dengelenebilir.

## Doğrulanmayanlar
Gerçek cihaz (dokunma hissi, çentik/güvenli alan değerleri, Android geri tuşu), gerçek reklam (AdMob, UMP onayı, zaman aşımı),
gerçek Play Billing, gerçek saha girdisi, saha ile HUD'un birlikte yerleşimi, İspanyolca ekran görüntüsü (yalnız metin probu ve tablo denetimi var),
çevrimdışı kapısının cihazdaki davranışı (headless'ta kapı kapalı). Probe zamanı: sahte saat ve sahte sağlayıcı; geçiş aralığı gerçek zamanda denenmedi.

## Testler ve probelar
- Birim: `test_ad_pacing` (12 seviye dizisi, aralık, istisnalar), `test_level_progress`, `test_language_pick`, `test_iap_service`,
  `test_stub_session`, `test_run_flow` (ödüllü neden kodları, zaman aşımı, aralık, kaldırıldı), güncellenen `test_ad_manager`, `test_loc`,
  `test_progress_*`. `tests/run_tests.gd` dili `en`'e sabitler (bu Mac Türkçe).
- `play_probe`: sentetik 13 seviyeli katalogla beş geçiş: temiz 12 seviye (reklam tam [3,6,9,12], yıldız 3/2/1, ipucu, atlama onayı + vazgeç + onay,
  kilitler, harita karoları), aralık, reklamları kaldır (ipucu hâlâ reklam ister), ödüllü baskılama, reklam yok/yarım; duraklatma, ayarlar satırı;
  gerçek kayıt dosyasının özeti başta ve sonda aynı. Mutasyon denemesi: `every_n` 2 yapılınca prob kırmızı.
- `lang_probe`: tr -> en -> es, oyun içi dil değişimi, tablodaki 53 anahtar x 3 dil.

## Ekran görüntüleri
`build/shots/shell/` (gerçek pencere; `--size=540x1200` uzun 20:9, `--size=540x960` kısa 16:9; ad: `NN_ekran_dil_boy.png`).
Diller en ve tr; boylar tall/short. Ekranlar: 01_home, 02_settings, 03_map, 04_map_top, 05_game_empty, 06_game_moves, 07_skip_sheet,
08_toast, 09_pause, 10_result, 11_game_early (ilk 3 seviye: ipucu/atla yok).
Örnek: `build/shots/shell/01_home_en_tall.png`, `03_map_en_tall.png`, `06_game_moves_en_tall.png`, `10_result_tr_short.png`.
Gördüklerim ve düzeltmeler: atlandı karosu kilitliyle karışıyordu (amber yapıldı); toast gereğinden genişti (metne göre daraltıldı).
Komut: `godot --path . -s res://tools/screenshot.gd -- --out-dir=build/shots/shell --lang=en --size=540x1200 --tag=tall`.

## Dosyalar
Yeni: `scripts/core/{level_progress,language_pick}.gd`, `scripts/game/stub_session.gd`, `scripts/services/{iap_provider,mock_iap_provider,iap_service}.gd`,
`scripts/ui/{map,level_tile,star_row,toast,game_bar,skip_sheet,shop_row,shop_sheet}.gd`, `scenes/Map.tscn`, `assets/icons/{lucide,shell}/*.svg`, yeni testler.
Silinen: `scripts/core/placeholder_run.gd`, `tests/unit/test_placeholder_run.gd` (+ `.uid`). Değişen: ad_pacing, progress_data, loc, AdManager, GameManager, Progress,
home, game, game_hud, result_sheet, run_flow, pause_sheet, settings_sheet, boot, strings, ui_data, project.godot (`locale/fallback=en`), data/*, docs, CHANGELOG, probelar, testler.
