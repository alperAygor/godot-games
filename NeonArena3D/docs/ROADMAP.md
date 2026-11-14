# Neon Arena 3D — Yol Haritası (işçi boyutlu görevler)

Girdi: `docs/ASSESSMENT.md` (durum), `docs/IDEAS.md` (fikirler + para kazanma). Hedef: daha derin oyun → reklam/IAP → Google Play yayını.
İşçi modeli: Opus = tasarım ağırlıklı/riskli çekirdek; Sonnet = iyi tanımlı iş. Her görev kendi dalında ("worktree") çalışır, birleştirme sırası
aşağıdaki bağımlılıklara uyar. "Dokunma" listesi paralel çakışmayı önler.

## 0. Altın kurallar (her görev için)
- Kapı: `tools/verify.sh` (F1 sonrası genişletilmiş hâli) yeşil olmadan birleştirme yok; `SCRIPT ERROR`/`Parse Error` taraması zorunlu (Godot hata verse de 0 döner).
- Oyuncu kaydı: araçlar `--no-save`/`--demo` ile çalışır; `user://` kaydı sürücüyle yazılmaz.
- Tipli GDScript korunur (dönüş tipi zorunlu), yeni mantık mümkünse saf `RefCounted` sınıfı + birim test.
- Veri JSON'da, sabit sayı koda gömülmez.

## 1. Bağımlılık özeti

```
Faz 0 (paralel): F1 kapı+sim · F2 game3d bölme · F3 menü bölme · F4 kayıt · F5 reklam servisleri · F6 ikon/marka
        └─ F2+F3+F4 birleşince →
Faz 1 (paralel): C1 koşu yapısı · C2 düşman · C3 kartlar · C4 tehlikeler · C5 juice · C6 onboarding/erişilebilirlik · C7 günlük/görev · C8 reklam akışı
Faz 2 (paralel, F5 + C8 sonrası): A1 Android/AAB/AdMob yerel · A2 Faturalandırma · A4 mağaza kayıtları · A5 yerelleştirme
Faz 3: A3 cihazda performans · C9–C14 içerik genişletme · denge turu (sim) · kapalı test (sahip) · yayın
```
Faz 0 görevleri birbirinin dosyasına dokunmaz (sahiplik tablosu aşağıda). Faz 1'e geçiş koşulu: F2, F3, F4 birleşmiş ve `docs/ARCHITECTURE.md`
(F2 üretir) modül sınırlarını tanımlamış olmalı.

## 2. Faz 0 — Temel (hemen paralel)

### F1 · Doğrulama kapısı v2 + denge simülasyonu — Sonnet
- Amaç: sonraki tüm işçilerin ölçebilmesi. `verify.sh`'a probeları (meta/synergy/touch/lang + `smoke_test` kısa) ekle, `\n` yazdırma hatasını düzelt,
  PCK boyut kapısı (`tools/pck_check.py` şablondan uyarlanır), `--export-pack` ile paket denetimi; `tools/sim/balance_sim.gd`: N tohum × gemi × (yapı: `--give`) ×
  sektör headless bot koşusu → JSON (medyan dalga, ölüm nedeni, çekirdek/koşu, sim süresi, tavan mermi/düşman sayısı); `tools/sim/report.py` özet tablo.
  `RunState` tohum desteğini kullan; bot `player.autopilot`.
- Sahip: `tools/**`, `tests/run_tests.gd`, yeni `tests/sim/**`. Dokunma: `scripts/**`, `data/**`, `project.godot`.
- Kabul: `tools/verify.sh` hâlâ yeşil ve probeları içeriyor; `balance_sim` 4 gemi × 20 tohum 10 dakikadan kısa sürede biter ve aynı tohumla aynı JSON'u üretir; hata durumunda sıfırdan farklı çıkış.
- Not: simülasyon oynanış kodu (`game3d.gd`) taşındığında F2 ile arayüz sözleşmesi: bot ve sahne `scenes/main.tscn` + komut satırı bayrakları üzerinden çalışır, iç yapıya bağlanmaz.

### F2 · `game3d.gd` bölme + denge verisini dosyalara ayırma — Opus (riskli)
- Amaç: 1950 satırlık tanrı nesneyi bölmek: `scripts/game/` altında `combat.gd` (çarpışma/hasar), `spawner.gd`, `boss_events.gd`, `cards_flow.gd`,
  `camera_rig.gd`, `autopilot.gd`, `feedback.gd` (juice kancaları), `run_flow.gd` (durum makinesi menü/oyun/ölü/duraklat) ve `game3d.gd` ince orkestratör.
  Olay arayüzü (sinyal) ile: `enemy_killed`, `player_hurt`, `run_ended`, `card_picked`… (ads/mission/juice bunları dinler). `data/balance.json` → `data/balance/{player,enemies,bosses,waves,scoring,pickups}.json`
  (`GameData.value()` yolu API'si aynı kalır). `docs/ARCHITECTURE.md` modül sınırı + sahiplik haritası.
- Sahip: `scripts/ui/game3d.gd`, yeni `scripts/game/**`, `scripts/autoload/game_data.gd`, `data/balance*`, `tests/unit/test_balance.gd`, `docs/ARCHITECTURE.md`. Dokunma: `menus.gd`, `settings.gd`, `meta_progress.gd`, `touch_controls.gd`, `hud.gd` (arayüzleri aynı kalır).
- Kabul: Davranış eşdeğeri: `smoke_test` (aynı tohum) sonuç alanları ±küçük sapma, tüm probelar yeşil, `verify.sh` yeşil, F1 sim ile önceki/sonraki medyan dalga farkı ≤ %5; `game3d.gd` < 400 satır; her yeni modül tipli.
- Risk: davranış kayması. Önlem: F1 sim çıktısı "önce/sonra" olarak PR'a eklenir.

### F3 · `menus.gd` bölme — Sonnet
- Amaç: 1124 satırlık dosyayı ekran başına dosyaya ayır: `scripts/ui/screens/{main,hangar,workshop,settings,howto,pause,cards,gameover}.gd` + ortak `menus.gd` yönlendirici; mevcut sinyaller (`play_pressed`, `card_picked`, …) aynı kalır.
- Sahip: `scripts/ui/menus.gd`, yeni `scripts/ui/screens/**`, `scripts/ui/ui_kit.gd`. Dokunma: `game3d.gd`, `hud.gd`, `touch_controls.gd`.
- Kabul: `lang_probe`, `touch_probe` yeşil; her ekran ekran görüntüsü (`screenshot.gd --screen=...`) önce/sonra piksel farkı yok (kabul eşiği: gözle aynı); `verify.sh` yeşil.

### F4 · Kayıt sağlamlaştırma + sürümlü şema — Sonnet
- Amaç: atomik yazım (`.tmp` → yeniden adlandır), `.bak` geri dönüş, `schema_version` + göç fonksiyonları, bozuk dosyada yedekten yükleme, `Settings.flags` (sözlük: `ads_removed`,
  `tutorial_done`, günlük bonus tarihi, koşu sayacı, son geçiş zamanı) ve `Settings.entitlements`; saat/tarih kaydı. API geriye uyumlu (F2/F5 bunu kullanır).
- Sahip: `scripts/autoload/settings.gd`, `scripts/core/meta_progress.gd`, `tests/unit/test_meta_progress.gd`, yeni `tests/unit/test_settings_save.gd` (geçici dosya yolu enjeksiyonu). Dokunma: diğer `scripts/**`.
- Kabul: testler: yarım yazılmış dosya, boş dosya, bozuk değer, eski sürüm göçü (mevcut `neon_arena_3d.cfg` biçimi) → ilerleme kaybı yok; `verify.sh` yeşil.

### F5 · Reklam servisleri portu (mock'lu) — Sonnet
- Amaç: `IDEAS.md` C.2'deki dosyaların şablondan (`/Users/alperaygorduler/Desktop/Games/studio-kit/template-mobile`, salt okunur) kopyalanması ve uyarlanması:
  `scripts/services/*`, `AdManager.gd` (yeni yerleşimler: REVIVE, DOUBLE_CORES, REROLL, DAILY_BONUS, INTERSTITIAL), koşu/süre tabanlı `ad_pacing.gd`, `data/ads.json`, testler. `project.godot`: yalnız `[autoload]` altına `AdManager`. Çevrimiçi kapısı alınmaz. Eklenti KOPYALANMAZ (A1).
- Sahip: `scripts/services/**`, `scripts/autoload/AdManager.gd`, `scripts/core/ad_pacing.gd`, `data/ads.json`, `tests/unit/test_ad_*.gd`, `project.godot` (yalnız bu autoload satırı). Dokunma: oyun akış dosyaları (C8 bağlar).
- Kabul: pacing tablo testleri (3. koşu yok / 4. var / 179 sn yok / 180 var / remove-ads asla / revive sonrası yok), ödül yalnız `rewarded` ile, zaman aşımı akışı serbest bırakıyor; `mode=test` kimlikleri; release+`REPLACE_` iken test kimliğine düşme testi; `verify.sh` yeşil.
- Bağ: F4'ün `Settings.flags` sözleşmesini kullanır; F4 birleşmeden önce bir saplama (stub) ile test edilir.

### F6 · Marka kimliği + ikon üretimi — Sonnet
- Amaç: ikon/adaptif/açılış/öne çıkan grafiği yeniden üretilebilir betikten üret (`tools/blender/render_icon.py` veya shader); adaptif güvenli bölge, monokrom (themed) ikon, 512 mağaza ikonu, 1024×500 öne çıkan grafik. Köken belgesi (`assets/icons/README.md` yok; betik başlığında). Ad metni sahibin kararına kadar yer tutucu.
- Sahip: `assets/icons/**`, `tools/brand/**`, `store/graphics/**`. Dokunma: `export_presets.cfg` (A1 bağlar), kod.
- Kabul: tüm PNG'ler betikle yeniden üretiliyor; adaptif ikon 66 dp güvenli alan içinde; `import` temiz.

## 3. Faz 1 — Oynanış ve akış (F2+F3+F4 sonrası paralel)

Veri dosyaları F2 sonrası ayrık olduğu için çakışmaz.

| Görev | Model | Amaç (IDEAS ref.) | Sahip | Dokunma | Kabul |
|---|---|---|---|---|---|
| **C1** Koşu yapısı | Opus | #1: 3 sektör×5 dalga, zafer, sektör kapıları (iyileş/lanetli kart/zor mod), hızlı mod, sonsuz mod | `scripts/core/run_state.gd`, `scripts/game/run_flow.gd`, `data/balance/waves.json`, `scripts/ui/screens/{victory,gate}.gd` (yeni), `tests/unit/test_run_state.gd` | `enemy3d.gd`, `cards.json`, `settings.gd` | Aşama makinesi testleri; sim: bot'un 3 sektörü bitirme oranı %25–45; `verify.sh` |
| **C2** Düşmanlar | Sonnet | #2: 6 yeni davranış + 4 elit ön eki | `scripts/entities3d/enemy3d.gd`, `data/balance/enemies.json`, `scripts/game/spawner.gd`, `tools/blender/make_models.py` (yalnız yeni model fonksiyonları), `tests/unit/test_balance.gd`, yeni `tools/dev/enemy_probe.gd` | `run_state.gd`, `cards.json` | `enemy_probe` her tür için davranış; sim: tür başına süre/hasar payı; boss yoksa sim bozulmaz |
| **C3** Kartlar/evrim | Opus (denge) | #3: 25 kart, evrim, banish, lanetli | `data/cards.json`, `scripts/core/loadout.gd`, `scripts/game/card_effects.gd`, `tests/unit/test_loadout.gd`, `tools/dev/synergy_probe.gd` | `enemy3d.gd`, `run_state.gd` | Her kart/evrim için etki ölçümü; sim: kırık kombinasyon taraması raporu (en iyi/ort. medyan dalga oranı ≤ 1.6) |
| **C4** Tehlikeler | Sonnet | #5: sektöre özgü tehlike + dalga modifikatörleri | `scripts/world/map_builder.gd`, yeni `scripts/world/hazards.gd`, `data/maps.json`, `assets/shaders/**` (yeni), yeni `tools/dev/hazard_probe.gd` | `enemy3d.gd`, `game3d.gd` | `hazard_probe` (uyarı süresi ≥ 0,8 sn, hasar alanı doğru); kalite DÜŞÜK'te çizim maliyeti artmaz (sayaç kontrolü) |
| **C5** Juice | Sonnet | #6: hit-stop, kombo tepkisi, kamera/ışık, erişilebilir azaltma | `scripts/autoload/{fx,sound}.gd`, `scripts/world/sparks.gd`, `scripts/game/feedback.gd`, `tools/make_audio.py` (yeni ses ekleri), `assets/audio/**` (yeni), `tests/unit/test_audio_assets.gd` | `enemy3d.gd`, ekran dosyaları | `fx_probe` (zaman ölçeği her zaman geri döner, hit-stop toplamı sınırlı); `audio_report.py` LUFS/tepe sınırları |
| **C6** Onboarding/erişilebilirlik | Sonnet | #7: etkileşimli öğretim, tek el, sol-el, renk körü paleti, düğme boyutu | `scripts/ui/{touch_controls,hud}.gd`, `scripts/ui/screens/{settings,howto}.gd`, yeni `scripts/ui/tutorial.gd`, `data/lang_en.json` (yalnız yeni anahtarlar, birleştirme sırası ile) | `game3d.gd`, `gameover.gd`, `cards.gd` | `touch_probe` genişletmesi (sol-el); öğretim probe'u sentetik girdiyle sona ulaşır; ekran görüntüsü kontrolü |
| **C7** Günlük/görev/başarım | Sonnet | #4 | yeni `scripts/core/{daily,missions}.gd`, `data/missions.json`, `scripts/ui/screens/missions.gd`, `tests/unit/test_{daily,missions}.gd`, `scripts/ui/screens/main.gd` (yalnız menü düğmesi) | `gameover.gd`, `settings.gd` (F4 sonrası yalnız `flags` anahtarı ekler) | Aynı tarih → aynı tohum/modifikatör; ilerleme/ödül tek sefer; kayıt gidiş-dönüşü; sim günlük koşu bot sonucu tutarlı |
| **C8** Reklam akışını bağlama | Opus | C.1: revive, çift çekirdek, reroll, günlük sandık, koşu sonu geçiş | yeni `scripts/game/monetization_hooks.gd`, `scripts/ui/screens/{gameover,cards}.gd`, yeni `tools/dev/ads_flow_probe.gd` | `ad_pacing.gd` mantığı (F5 sahibi), `main.gd` | `ads_flow_probe` (Mock): revive → canlanır; reklam hata → ödül yok; remove-ads → geçiş yok; ilk 3 koşuda geçiş yok; masaüstünde Mock ile oyun sorunsuz; sağlayıcı yoksa düğmeler gizli |

Çakışma notu: `data/lang_en.json` ortak; yeni anahtarlar için her görev kendi dosyasına (`data/lang/<görev>.json`, F2/F3 ile
`I18n` birleştirme eklenir) yazar — bu birleştirmeyi C6 yapar, diğerleri ona göre; aksi hâlde sırayla birleştirin.

## 4. Faz 2 — Android ve Play hattı

### A1 · Android Gradle/AAB + AdMob yerel + imza hattı — Opus (riskli, sahip gerekli)
- Amaç: Android derleme şablonu (`android/build`), `use_gradle_build=true`, `export_format=1` (AAB), `min_sdk`/`target_sdk` açık yazılı, izinler (`INTERNET`, `ACCESS_NETWORK_STATE`), Poing AdMob eklentisi (şablon `docs/MONETIZATION.md` §2 adımları), `[admob]` ayarları + `admob/general/android/app_id`, UMP,
  `tools/build_aab.sh` (sürüm kodu otomatik artırma, çıktıyı `build/` altına), keystore yolu `export_credentials.cfg` (git dışı), test APK ön ayarı (Gradle'sız).
- Sahip: `export_presets.cfg`, `project.godot` (`[admob]`, `[editor_plugins]`), `android/**`, `addons/admob/**`, `tools/build_aab.sh`, `docs/ANDROID.md`. Dokunma: oyun/servis kodu (hata bulursa F5'e bildirir).
- Kabul: `godot --headless --export-release "Android (release)"` AAB üretir (sahip keystore'u ile yerelde); logcat'te "Native plugin not found" yok; AAB boyutu raporlanır; `pck_check` test kimliği/sır sızmadığını doğrular.
- Sahip girdisi: AdMob hesabı + uygulama/birim kimlikleri; eklenti indirme onayı; keystore (bkz. §6).

### A2 · Faturalandırma (reklamları kaldır) — Sonnet/Opus
- Amaç: `IapProvider` arayüzü + `MockIapProvider` + Play Billing sağlayıcısı (Godot yerel eklenti), açılışta sahiplik doğrulama, "satın alımı geri yükle", çevrimdışı yerel bayrak; UI düğmesi ana menü/ayarlar. Başlangıç paketi ertelenmiş.
- Sahip: `scripts/services/iap_*.gd`, `tests/unit/test_iap_*.gd`, `scripts/ui/screens/store.gd` (yeni). Dokunma: `main.gd` (tek satırlık düğme için C7/C8 sonrası sırayla).
- Kabul: Mock ile satın alma → `ads_removed` kalıcı, restore testi, hata yolları; cihazda lisans test hesabı (sahip).
- Sahip girdisi: ürün kimliği ve fiyat kararı; Play Console'da ürün.

### A4 · Mağaza kayıtları ve uyum belgeleri — Sonnet
- Amaç: `store/` altında kısa/uzun açıklama TR+EN, ekran görüntüleri (`screenshot.gd` ile 5–8 kare, telefon oranı), öne çıkan grafik (F6), gizlilik politikası taslağı, Veri Güvenliği formu yanıtları (politika matrisi işçisinin çıktısına göre), içerik derecelendirme cevap taslağı, sürüm notları.
- Sahip: `store/**`, `docs/PRIVACY.md`. Dokunma: kod. Not: politika kuralları başka işçinin matrisinden alınır, burada araştırılmaz.
- Kabul: karakter sınırlarına uyum, tüm ekran görüntüleri betikle yeniden üretilebilir, politika URL'si sahip tarafından barındırılana dek yer tutucu.

### A5 · Yerelleştirme genişletme — Sonnet
- Amaç: #14: `tr()` anahtarlarını kimlik tabanlı tabloya (CSV/JSON) taşı, ES/PT-BR/DE/FR ekle (sahip incelemesi için işaretli), taşma kontrolü.
- Sahip: `scripts/autoload/i18n.gd`, `data/lang*`, `tests/unit/test_i18n.gd`. Dokunma: ekran dosyaları (anahtar adları değişirse C-görevleri bittikten sonra çalıştır).
- Kabul: her dilde eksik anahtar 0, ekran görüntüsü taşma taraması.

## 5. Faz 3 — Cihaz, içerik genişletme, yayın

| Görev | Model | Amaç | Not |
|---|---|---|---|
| **A3** Cihazda performans | Opus | gerçek telefon (orta sınıf Android): FPS, ısınma, çizim çağrısı, kare süresi; kalite kademelerini ve `Engine.max_fps` kararını ölç; `tools/perf_probe.gd` (şablondan) | **Sahip cihaz/USB hata ayıklama gerekir**; ölçüm raporu `docs/PERF.md` |
| **C9** Boss/mini-boss | Opus | #10 | `boss3d.gd`, `data/balance/bosses.json`, yeni glb |
| **C10** Meta derinliği | Sonnet | #9 | `meta_progress.gd`, `upgrades.json`, workshop ekranı |
| **C11** Gemiler | Sonnet | #8 | `ships.json`, `player3d.gd`, glb |
| **C12** Zorluk modları | Sonnet | #11 | `waves.json`, ana menü seçici |
| **C13** Koşu içi olaylar | Sonnet | #12 | `scripts/game/events.gd` |
| **C14** QoL/istatistik | Sonnet | #13 | `screens/gameover.gd` (C8 sonrası) |
| **Denge turu** | Opus | F1 sim ile hedef: ilk koşu medyan dalga 4–6, 20. koşu 8–12, tam atölye 15+; çekirdek ekonomisi 150–250 koşu | `data/**` yalnız sayılar |
| **Kapalı test + yayın** | Sahip | Play Console dahili/kapalı test, çökme/ANR izleme | bkz. §6 |

## 6. Sahip gerektiren maddeler
| Madde | Ne gerekiyor |
|---|---|
| Yayın adı | Aşağıdaki 3 öneriden biri veya kendi adın (kullanılabilirlik **kontrol edilmedi**) |
| Paket kimliği | `com.neonarena.arena3d` mevcut; yayından sonra **değişmez**. Ad kararıyla birlikte netleştir |
| Google Play geliştirici hesabı + uygulama kaydı | Hesap açma, uygulama oluşturma, Play Uygulama İmzalama |
| Keystore | Yükleme anahtarı oluştur ve güvenle sakla (depoya konmaz: `.gitignore`'da `*.keystore`) |
| AdMob hesabı | Uygulama kimliği + ödüllü + geçiş birim kimlikleri; GDPR/UMP iletisi yayını |
| Faturalandırma | "Reklamları kaldır" ürün kimliği ve fiyatı |
| Eklenti indirme onayı | Poing AdMob eklentisi, Play Billing eklentisi (bu görevlerde ağ gerekir) |
| Gizlilik politikası URL'si | Barındırma (A4 taslağı yazar) |
| Hedef kitle / içerik derecelendirme / veri güvenliği | Beyanlar sahibin hesabı üzerinden (politika matrisine göre) |
| Kayıt yedeği (`user_data_backup/allow`) | Açma kararı |
| Ürün kararları | Para kazanma seviyesi (IDEAS C.1 öneri varsayılan), zorluk/ödül hedefleri, hangi fikirlerin kapsamda olduğu |
| Cihaz | A3 için orta sınıf Android telefon ve USB hata ayıklama; kapalı test kullanıcıları |

### Yayın adı önerileri (ticari marka/mağaza çakışması **kontrol edilmedi**)
1. **Neon Siege: Arena Survivor** — "neon arena" kalabalık bir arama terimi; "Siege" kuşatılma hissini ve boss dalgalarını verir, "Survivor" türü söyler.
2. **Voidlight Arena** — kısa, akılda kalır, neon/uzay temasını verir, "arena" kategori aramalarında çıkar.
3. **Hexpulse: Neon Survivors** — benzersiz tek kelimelik marka + tür açıklaması; ikon/logo tasarımı kolay.

## 7. Önerilen başlangıç (ilk üç görev)
1. **F1** (kapı + simülasyon): hiçbir koda dokunmadan ölçülebilirlik sağlar.
2. **F2** (`game3d.gd` bölme + veri ayırma): Faz 1'in önünü açan tek darboğaz; F1 sim ile kayma kontrolü.
3. **F5** (reklam servisleri, mock'lu) — yeni dosyalardan oluştuğu için F1/F2/F3/F4 ile çakışmadan paralel koşar; F3, F4, F6 aynı anda başlatılabilir.
Sonra: C1, C2, C3, C8 öncelikli; A1 için sahip kararları (hesap, kimlikler, keystore) paralelde toplanmaya başlanmalı.

## 8. Bilinen riskler
- Davranış kayması (F2): sim önce/sonra raporu zorunlu.
- Gerçek cihaz perf. bilinmiyor (A3 gelene kadar kalite varsayılanı ORTA; yeni tehlike/parçacık eklemeleri çizim bütçesini aşmamalı: `sparks.gd` `MAX_*`, düşman ≤44).
- AdMob yerel eklentisi Gradle ister: A1 ile mevcut APK hattı (README) değişir; test APK ön ayarı korunur.
- İçerik büyüdükçe `balance` kırılganlığı: C3 ve denge turu sim'e bağlıdır.
