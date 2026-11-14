# Neon Arena 3D — Durum Değerlendirmesi

Tarih: 2026-11-15 · Godot 4.7.2 · dal `orch/na-assess` · yalnız okuma/ölçme yapıldı, oyun kodu değişmedi.
Kanıt yolları repo köküne göredir. "Ölçtüm" = komutu çalıştırdım; "çıkarım" = koddan akıl yürüttüm.

## 0. Tek paragraf özet

Teknik olarak sağlam, içerik olarak ince bir oyun. Çekirdek döngü (tepeden bakış, çift çubuklu neon arena, dalga + kart seçimi +
kalıcı atölye) çalışıyor, 3B görüntü (bloom, ızgara zemin, MultiMesh mermi/kıvılcım) beklenenden iyi ve mobil performans için bilinçli
tasarlanmış. Testler ve probelar yeşil. Ama: tek bir sonsuz mod, 20 kart, 7 düşman, 3 boss, 3 harita; yeni kazanım/hedef yok; ilk
30 saniyede oyuncuya "neden bir daha oynayayım" cevabı verilmiyor; çekirdek ekonomisi (toplam 3750 + 1400 çekirdek) birkaç düzine
koşuda biter; hiç reklam/satın alma/analitik yok; Play için gradle/AAB/imza/AdMob hattı yok. Yani "oynanabilir dikey dilim", henüz
"yayınlanabilir ürün" değil. Çoğu eksik AI ajanlarıyla kapatılabilir (sistem, veri, shader, parçacık); el yapımı karakter animasyonu
gerektiren bir şey gerekmiyor.

## 1. Proje özeti

| Konu | Bulgu | Kanıt |
|---|---|---|
| Tür | Tepeden bakış, çift çubuklu (twin-stick) arena hayatta kalma + roguelite (seviye atlayınca 3 karttan biri) + koşular arası kalıcı atölye/gemi | `README.md`, `scripts/ui/game3d.gd` |
| Platform | Masaüstü (fare/klavye) + Android (dokunmatik), yatay | `project.godot` `window/handheld/orientation=4` (sensör yatay) |
| Çekirdek döngü | Düşman öldür → kombo (×6'ya kadar) + XP → kart → her 5. dalga boss → yeni sektör (harita) → ölünce `çekirdek` kazan → Atölye/Hangar'da harca | `scripts/core/run_state.gd`, `scripts/core/meta_progress.gd` |
| Sonu | Yok: sonsuz dalga, 3 harita döner, bosslar "MK-2" olur. Kazanma ekranı/hedef yok | `run_state.gd` (`PHASE_OVER` yalnız ölümde) |
| Boyut | ~10 bin satır (10.079 satır: GDScript + araç betikleri), 49 birim test, 5 autoload | `wc -l` |
| Kod geçmişi | Tek commit (`9cf9a22`, 2026-11-10) | `git log` |

### Kontroller
- Masaüstü: WASD/yön tuşları, fare nişan+ateş, Boşluk/Shift atılma, Q/E/F veya sağ tık nova, 1/2/3 kart, ESC/P duraklat, M sessiz (`scripts/autoload/game_data.gd` `ACTIONS`).
- Dokunmatik: sol yüzen çubuk = hareket, sağ yüzen çubuk = nişan+ateş (bırakınca otomatik nişan + otomatik ateş), ATIL ve NOVA düğmeleri, ⏸ (`scripts/ui/touch_controls.gd`). Çoklu dokunuş `tools/dev/touch_probe.gd` ile sınanıyor (13 kontrol geçti).
- Tek el oyunu: YOK. İki başparmak gerekir (hareket + atıl/nova); otomatik nişan/ateş yükü azaltıyor ama atılma ve nova ikinci eli ister. Sol-el yerleşimi yok.

### Sistemler ve içerik miktarı
| Sistem | Miktar | Kanıt |
|---|---|---|
| Düşman | 7 tür (kovalayıcı, nişancı, sürü ×3 paket, yörüngeci, tank, keskin nişancı, bombacı) + elit (4. dalgadan, %5→%16) | `data/balance.json` `enemies`, `elite` |
| Boss | 3 (Sentinel, Kızıl Dev, Buz Hükümdarı), 2 faz, "MK-2" döngüsü | `data/balance.json` `boss_kinds`, `scripts/entities3d/boss3d.gd` (352 satır) |
| Harita | 3 tema (renk/prop değişir; mekanik değişmez) | `data/maps.json` |
| Gemi | 4 (Vektör, Kasırga, Mızrak, Şahin; farklı silah tipi) | `data/ships.json` |
| Kart | 20 normal (common/rare/epic) + 6 sinerji, sınırlı üst üste alma | `data/cards.json`, `scripts/core/loadout.gd` |
| Atölye | 9 yükseltme, 28 seviye, toplam 3750 çekirdek; gemiler 1400 → toplam sink ≈ 5150 | `data/upgrades.json`, `data/ships.json` |
| Güç-up | Can, kalkan, aşırı yük (3 tür, %15 düşme) | `data/balance.json` `pickups` |
| Ses | 48 SFX + 3 müzik, tamamı numpy ile sentez | `tools/make_audio.py` (1047 satır), `assets/audio/` |
| Dil | TR + EN (EN: `data/lang_en.json`, 120 anahtar + JSON'larda `*_en`) | `scripts/autoload/i18n.gd`, `tests/unit/test_i18n.gd` |
| Kayıt | `ConfigFile` → `user://neon_arena_3d.cfg` (ayar + rekor + meta) | `scripts/autoload/settings.gd` |
| Eksikler (kodda yok) | günlük meydan okuma, görev/başarım, skor tablosu, zorluk modu, arena tehlikesi/olay, koşu içi seçim (kart dışında), analitik, reklam, IAP | `grep daily\|achiev\|mission` boş |

### Ekonomi ve eğri (çıkarım + bot)
- Koşu ödülü = `puan/150 + 3·(dalga−1) + 20·boss`, atölye çarpanı (`MetaProgress.run_reward`). Bot 9. dalgada ≈5.300 puan → ≈80 çekirdek. Tüm atölye+gemi ≈5150 → yaklaşık 60–70 koşu sonra "alınacak bir şey kalmaz". Sonrası: hiçbir hedef yok.
- Zorluk: dalga başına +%12 HP, +%7 hasar, hız tavanı ×1.45, canlı üst sınır 44 (`balance.json` `difficulty`, `waves`). Eğri doğrusal; yüksek dalgada "kalabalık artar, tavan 44" — yeni davranış gelmediği için 10. dalgadan sonra yeni bir şey öğrenilmiyor.
- Bot (smoke) 40 sn × 3 hız: 9. dalgaya, boss ve elit görerek ulaştı, hayatta (`tools/smoke_test.gd` çıktısı aşağıda).

## 2. Çalıştırma sonuçları (headless, ölçtüm)

| Komut | Sonuç |
|---|---|
| `godot --headless --path . --import` ×2 | Betik hatası yok (`SCRIPT ERROR`/`Parse Error` = 0). 1. çalıştırmada temiz klonda beklenen "Exo2.ttf fontdata açılamadı" (henüz içe aktarılmamış önbellek) satırları; 2. çalıştırma temiz. Gürültü: `cannot connect to daemon at tcp:5037` (adb yok; zararsız) |
| `tools/verify.sh` | `✓ betikler derlendi` · `49 test geçti, 0 başarısız, 1151 doğrulama` · `✓ temiz açılış` · `✓ doğrulama geçti`. Küçük hata: son satırda `echo "\n..."` bash'te `\n` yazdırıyor |
| `tools/dev/meta_probe.gd --no-save` | 9/9 ✓ (SONUÇ: geçti) |
| `tools/dev/synergy_probe.gd --no-save` | 6/6 sinerji ✓ |
| `tools/dev/touch_probe.gd --no-save` | 13/13 ✓ |
| `tools/dev/lang_probe.gd --no-save` | Hata yok (yalnız bilgi basar, doğrulama içermez) |
| `tools/smoke_test.gd --demo --ship=sahin --seconds=40` | `dalga=9 öldürme=120 puan=5292 seviye=11 boss=true elit=true mermi_maks=104 canlı_maks=10`, betik hatası yok |
| `tools/probe_models.gd` | Model boyut/malzeme dökümü basıyor, hata yok |
| Android paketi (`--export-pack "Android"`, SDK gerektirmez) | **PCK = 7.416.924 bayt (7,4 MB)**; çıktı depo dışına yazıldı. APK/AAB üretmedim (gradle şablonu kurulu değil; çıkarım: arm64-only AAB ≈ 30–40 MB, **ölçülmedi**) |

Not: probelar `--no-save` ile çalıştı; `Settings.save()` ayrıca `DisplayServer.get_name()=="headless"` veya `--demo/--no-save` iken hiç yazmaz (`settings.gd` satır `save()` ilk iki satır). Oyuncunun `user://neon_arena_3d.cfg` dosyası değişmedi (mtime 10 Kas). `verify.sh` probeları içermiyor — kapıda yalnız birim test + açılış var.

### Gerçek pencere
`tools/screenshot.gd --demo --touch --wave=3` ile 1 kare aldım (başarılı); menü karesi bu çalıştırmada üretilemedi (75 sn sınırında kendi PID'imi sonlandırdım). Ayrıca repodaki `docs/screen_*.png` karelerine baktım.
Gözlem: koyu lacivert ızgara zemin, güçlü bloom, parlayan mavi gemi, renkli yer ışıkları, temiz Exo 2/Oxanium tipografi, köşeli "neon-HUD" paneller; Atölye ekranı düzenli ve okunaklı. Boss karesinde (Kızıl Dev) yer uyarı daireleri ve boşluklu şok dalgası çok okunaklı. Zayıf yönler: düşman/gemi silueti küçük ve blokluk, kare başına çok sayıda beyaz mermi + yer parıltısı "bulanık" bir bütün oluşturuyor; dokunmatik karede minimap sağ üstte combo yazısıyla iç içe; modeller "düşük detaylı procedural" (Blender betiği ile üretilmiş) — sevimli ama marka kimliği zayıf. Genel cilâ seviyesi: **orta-iyi**; ilk izlenim güçlü, derinlik zayıf.

## 3. Mobil oyun olarak tasarım eleştirisi

**İlk 30 saniye.** Menü → OYNA tek dokunuş (iyi). Ardından 9 sn'lik metin ipucu ("SOL: HAREKET · SAĞ: NİŞAN…", `game3d.gd` `_hint_time`) — okuma gerektiriyor, etkileşimli öğretim yok; ilk kartta ne seçeceğini oyuncuya söyleyen bir şey yok. İlk dalga 6 kovalayıcı: güvenli ve sıkıcı; ilk "vay" anı (ilk kart/sinerji, ilk boss) 5. dalgadan önce gelmiyor. Kıl payı kurtulma/ödül anı erken tasarlanmamış.

**Okunabilirlik.** Neon + bloom tepeden görünümde iyi; bosslar için yer uyarıları örnek niteliğinde. Telefonda: 1280×720 mantıksal alan, `ui_scale` 1.3, güvenli alan kodu var (`game3d.gd` `_update_layout`). Mermi ve parıltı yoğun sahnelerde düşman/tehdit ayrımı zorlaşabilir (çıkarım); renk körlüğü seçeneği yok.

**Seans uzunluğu.** Koşu ≈ 5–12 dk (çıkarım; dalga/boss süreleri). Mobil için uzun; "bir kahve molası" 3–5 dk koşu ve gün içi kısa hedef yok. Duraklat + otomatik duraklama var (`menus.gd` `_notification`).

**Zorluk.** Doğrusal ölçekleme + 44 tavan; yeni davranış yok → 10+ dalga tekrar. Atölye çarpanları sonsuz güç kazandırdığı için eski oyuncu için zorluk tırmanmıyor (zorluk modu yok). Ölüm cezası düşük; ikinci şans yalnız kart olarak (`ikincisans`), reklamla veya başka yolla yok.

**His (juice).** Var: ekran sarsıntısı, titreşim, vinyet, yavaşlatma (ölümde `Engine.time_scale=0.3`), kıvılcım, halka, hasar sayıları, yer uyarıları, boss intro. Yok: vuruş duraklaması (hit-stop), öldürme zinciri/kombo tepkisi (kombo yalnız sayı), seviye atlamada yavaşlatma, ses katmanlı kombo yükselişi, gelişmiş silah izi/rün. Yani "iyi, ama tavan değil".

**Tek el.** Yok (bkz. kontroller). Dikey mod yok.

**Derinlik/tekrar oynanabilirlik.** Zayıf nokta. 26 kart, 6 sinerji hoş (`synergy_probe` doğruluyor) ama: evrim yok, kart nadirliği yalnız ağırlık, "lanetli/risk-ödül" seçim yok, koşular arası "ya şu kombinasyonu denesem" çeşitliliği 4 gemi × ~20 kart; harita mekaniği aynı; seed'li/günlük koşu yok.

**Tutma (retention).** Günlük giriş/ödül, görev, başarım, koleksiyon, skor tablosu, bildirim: hiçbiri yok. Tek kanca = atölye alışverişi + rekor sayısı. D1/D7 için yetersiz.

**Jenerik olan.** Tür "neon arena shooter" çok kalabalık; ayrıştırıcı yok (kimlik: gemi çeşitliliği + sinerji kartları + boss desenleri). Bunlar vurgulanmalı: sinerji/evrim sistemi ve boss mekanikleri marka kimliği olabilir.

## 4. Kod sağlığı

| Konu | Durum |
|---|---|
| Tip kullanımı | İyi: 362 fonksiyonun 361'i dönüş tipli; `class_name` ile saf çekirdek (`RunState`, `Loadout`, `MetaProgress`, `ArenaSpace`) sahneden bağımsız ve testli |
| Katmanlar | Veri → çekirdek (saf) → varlıklar/dünya → UI ayrımı net. **Ama** `scripts/ui/game3d.gd` 1950 satır "tanrı nesne": çarpışma, hasar, spawn, boss olayları, kamera, otomatik nişan, bot, kart akışı hepsi içinde; yeni özelliklerin hepsi buraya dokunur → paralel işçiler çakışır. `menus.gd` 1124 satır (tüm ekranlar tek dosyada) |
| Veri odaklılık | İyi: `balance.json`, `cards.json`, `ships.json`, `upgrades.json`, `maps.json`; testler JSON alan eksiğini yakalıyor. `balance.json` tek büyük dosya (çakışma riski) |
| Test | 6 dosya / 49 test / 1151 doğrulama (denge, run_state, loadout, meta, i18n, ses varlıkları). Savaş mantığı (çarpışma, hasar, spawn) yalnız probe/smoke ile dolaylı sınanıyor; probelar `verify.sh` kapısında değil |
| Araçlar | `tools/verify.sh`, `smoke_test.gd` (bot), `screenshot.gd` (girdi simülasyonlu), `dev/*_probe.gd`, `make_audio.py`, `audio_report.py` (LUFS/tepe/dikiş), `blender/*.py`. Dengesizlik simülasyonu (çok tohum × gemi) yok |
| Bitmemiş/stub | Dokunmatik mod yalnız otomatik algılanıyor (elle geçiş yok); "ÇIKIŞ" yalnız masaüstü/mobilde `quit()`; analitik yok; `.command` yalnız macOS; kayıt sürüm numarasız |
| Küçük hatalar | `verify.sh` son satır `\n`; ana menüde Android geri tuşu doğrudan `get_tree().quit()` (`menus.gd` `_go_back`) — onay yok |

## 5. Ses ve görsel üretim, lisans/kökeni (madde: "origin obviously project's own" olmayanlar)

| Varlık | Üretim | Lisans/köken | Not |
|---|---|---|---|
| `assets/audio/*.wav` (48) | `tools/make_audio.py` (numpy sentez, sabit tohum 20261109) | Kendi aracı | Bu repo bu 48 dosyanın üretimini **yeniden üretilebilir** tutuyor; `.wav` 28 MB ham, Godot QOA'ya çeviriyor (içe aktarılmış `.sample` toplamı ≈5,7 MB) |
| `assets/models/*.glb` (20) | `tools/blender/make_models.py` (Blender CLI, procedural) | Kendi aracı | 1,0 MB |
| `assets/shaders/*.gdshader` (8) | El yazımı | Kendi | |
| `assets/fonts/Oxanium.ttf` | Üçüncü taraf | SIL OFL 1.1, lisans metni `assets/fonts/Oxanium-OFL.txt` yanında | Telif satırı: "The Oxanium Project Authors" |
| `assets/fonts/Exo2.ttf` | Üçüncü taraf | SIL OFL 1.1, `Exo2-OFL.txt` yanında | "The Exo 2 Project Authors"; OFL metinleri `export_presets.cfg` `include_filter` ile pakete giriyor (`assets/fonts/*.txt`) |
| `assets/icons/icon_192.png`, `icon_512.png`, `adaptive_fg_432.png`, `adaptive_bg_432.png`, `splash.png`, kök `icon.svg` | **Üreten betik repoda yok** | Köken kanıtlanamıyor (muhtemelen yerel üretim; `icon.svg` elle yazılmış basit SVG) | Yayından önce yeniden üretilebilir hale getirilmeli veya yeniden çizilmeli |
| `docs/*.png`, `docs/audio/ses_vitrini.wav` | Ekran/render çıktıları, ses vitrini | Kendi | Pakete girmez (`exclude_filter docs/*`, `.gdignore`) |

Başka üçüncü taraf varlık/eklenti yok (`addons/` yok). Ticari lisans sorusu yaratan hiçbir dosya yok; tek eylem: font OFL metinlerinin oyun içi "Hakkında" ekranında anılması (şu an yok) ve ikon kökeninin belgelenmesi.

## 6. Google Play teknik hazırlık boşlukları (yalnız teknik; politika matrisi başka işçide)

| Madde | Mevcut durum | Kanıt | Boşluk |
|---|---|---|---|
| Export biçimi | `use_gradle_build=false` → yalnız APK; **AAB üretilemez** | `export_presets.cfg` `gradle_build/use_gradle_build=false`, `export_format=0` | Gradle + Android build şablonu + `export_format=1` (AAB). `android/` klasörü yok |
| Mimari | Yalnız arm64-v8a | `architectures/arm64-v8a=true` diğerleri false | İyi (Play 64-bit şartı); x86_64 emülatör için isteğe bağlı |
| Paket kimliği | `com.neonarena.arena3d` | `package/unique_name` | Yayından sonra değişmez → **sahip kararı**, marka adıyla uyumlu seçilmeli |
| Sürüm | code 2 / "1.2.0" | `version/code`, `version/name`, `project.godot` `config/version` | Her yüklemede kod artırılmalı; otomasyon yok |
| Min/hedef SDK | Boş → Godot 4.7.2 varsayılanı: min 24, hedef 36 (şablonun `config.gradle`: `minSdk 24`, `targetSdk 36`, `compileSdk 36`) | `export_presets.cfg` `min_sdk=""` `target_sdk=""`; `~/Library/Application Support/Godot/export_templates/4.7.2.stable/android_source.zip` | Açıkça yazılmamış; Play'in güncel hedef şartı kontrolü politika işçisinde |
| İmza | `package/signed=true`, ön ayarda keystore alanı yok; README debug imzası anlatıyor | `export_presets.cfg`, `README.md` Android bölümü | Üretim keystore'u yok (`*.keystore`, `*.jks` `.gitignore`'da). Sahip: keystore + Play App Signing kararı |
| İzinler | Yalnız `VIBRATE`; `INTERNET=false` | `permissions/vibrate=true`, `permissions/internet=false` | AdMob/IAP için `INTERNET`, `ACCESS_NETWORK_STATE` (+ reklam kimliği beyanı) gerekecek; sürümde beyan formlarına yansımalı |
| Yedekleme | `user_data_backup/allow=false` | `export_presets.cfg` | Cihaz değişince ilerleme kaybolur; **sahip kararı** (kayıt küçük, yedek açmak çoğu zaman yararlı) |
| Renderer | `mobile` (Vulkan), cihazda Vulkan yoksa GL'e düşüş notu | `project.godot` `rendering_method="mobile"`, README Notlar | README'nin "Vulkan yoksa OpenGL'e düşer" iddiası doğrulanmadı; Vulkan'sız eski cihazda açılış/görünüm (shader'lar, glow) sınanmadı. Gerçek cihaz testi şart |
| Perf tasarımı (çıkarım) | Mermi ve kıvılcım tek `MultiMesh` (2 çizim çağrısı), `ModelCache` ile modeller 3-4 yüzeye birleştirilmiş, kalite 3 kademe (render ölçeği 0.67/0.82/1.0, MSAA 0/2x/4x, gölge, parçacık bütçesi), canlı düşman ≤44, ışık ≤4 dinamik OmniLight + 1 yönlü | `scripts/world/bullet_field.gd`, `sparks.gd` (`MAX_SPARKS 520`, `MAX_LIGHTS 4`), `model_cache.gd`, `game3d.gd` `_apply_quality`, `map_builder.gd` `apply_quality` | Çizim çağrısı/FPS **ölçülemedi** (gerçek telefon yok; Apple M4'te ölçüm anlamsız). Riskler: glow/bloom Mali/Adreno orta sınıf, 2048 yönlü gölge, MSAA 2x ORTA varsayılan, ~44 ayrı düşman düğümü + 14–30 prop; tavan FPS ayarı yok (`Engine.max_fps` kullanılmıyor) |
| Dokunmatik kalitesi | Yüzen çubuklar, 3 ayrı düğme, çoklu dokunuş testli; güvenli alan hesabı var; `emulate_mouse_from_touch=true` | `touch_controls.gd`, `game3d.gd` `_update_layout`, `touch_probe` | Sol-el düzeni, düğme boyutu/konumu ayarı, titreşim şiddeti yok; çentik/jest alanı (gesture area) gerçek cihazda sınanmadı |
| Geri tuşu / duraklat | `NOTIFICATION_WM_GO_BACK_REQUEST` ve `APPLICATION_PAUSED/FOCUS_OUT` işleniyor; oyunda duraklatıyor | `menus.gd` `_go_back`, `_notification` | Ana menüde geri = anında çık (onay yok); `auto_accept_quit` ayarı kontrol edilmedi |
| Ses odağı | Özel kod yok; Godot'nun yerleşik Android ses odağına güveniyor; duraklatmada müzik boğuklaştırma var | `scripts/autoload/sound.gd` | Telefon araması/başka uygulama senaryosu cihazda sınanmalı |
| Kayıt sağlamlığı | `ConfigFile.save()` doğrudan üzerine yazar (atomik değil, yedek yok), sürüm alanı yok; bozuk/eksik dosyada `load()!=OK` ise varsayılana düşer ve bir sonraki `save()` onu ezer | `settings.gd` `_load`/`save` | Atomik yazım (`.tmp`→yeniden adlandır), `.bak`, `schema_version`, ayrı `meta` bölümü doğrulama |
| Simge/açılış | 192/512 PNG, adaptif ön/arka 432, açılış 384 var | `assets/icons/*`, `export_presets.cfg` `launcher_icons/*` | Adaptif güvenli bölge doğrulaması yok; monokrom (themed) ikon yok; mağaza ikonu 512 var; öne çıkan grafik (1024×500), ekran görüntüleri yok; köken belirsiz (bkz. §5) |
| Yerelleştirme | TR + EN; metin anahtarı = Türkçe cümle (`tr("...")`) ve `data/lang_en.json` | `i18n.gd`, 99 `tr(` çağrısı kodda | Yeni dil = yeni JSON; Türkçe anahtar kırılgan (metin düzeltmesi tüm dilleri bozar). Sistem dili tr değilse EN (`settings.gd`): İspanyolca/Portekizce vb. yok |
| Çevrimdışı | Tam çevrimdışı çalışır; ağ çağrısı yok | `grep HTTPRequest\|OS.shell_open` boş | Reklam gelince "reklam yoksa akış sürer" kuralı şart |
| Çökme güvenliği | Açılış logunda `ERROR`/`SCRIPT ERROR` yok (verify açılış testi, smoke) | `tests/results/boot.log` | Çökme raporlama yok (Play Console vitals yeter); `JSON.parse_string` hataları `push_error` ile sessiz yutuluyor (`game_data.gd`) |
| Gizlilik | Analitik/ağ/kimlik yok | grep | Reklam eklenince veri güvenliği formu ve UMP gerekir (politika işçisi) |
| Paket boyutu | PCK 7,4 MB (ölçtüm); `exclude_filter` tests/tools/docs/*.md | `na.pck` (depo dışı) | AAB ≈ motor (arm64) + PCK; ölçülmedi. 28 MB ham WAV depoyu şişiriyor ama pakete QOA olarak giriyor |
| Üçüncü taraf lisans | Yalnız 2 OFL font | §5 | İkon kökeni belirsiz |

## 7. Güçlü yönler (korunacak)
- Sahneden bağımsız, testli çekirdek; veri odaklı denge; `--demo/--no-save/--wave/--give/--boss` gibi hata ayıklama bayrakları; ekran görüntüsü + girdi simülasyonu aracı → ajan işçiler için çok değerli doğrulama zemini.
- Mobil için akıllı render tasarımı (MultiMesh, yüzey birleştirme, 3 kalite kademesi, güvenli alan).
- Ses yeniden üretilebilir ve ölçülmüş (LUFS/tepe/dikiş raporu).
- Okunaklı boss yer uyarıları, sinerji sistemi.

## 8. Kontrol edemediklerim
Gerçek cihaz FPS/ısınma/pil; AAB/APK üretimi ve imza; Android'de ses odağı/geri tuşu/çentik davranışı; Vulkan'sız cihaz davranışı; gerçek oynanış hissi (yalnız bot + ekran görüntüsü); menü ekran görüntüsü (bu çalıştırmada üretilemedi); Play politikaları (başka işçi).
