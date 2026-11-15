# Döviz Bürosu — Google Play Yayın Yol Haritası

Tarih: 2026-11-15 · Girdi: `docs/ASSESSMENT.md` (kanıtlar orada). Hedef: "her anlamda" yayına hazır (teknik + ürün + mağaza + yasal). Politika gereklilikleri `~/Desktop/Games/godot-games/CamasirIpi/docs/store/PLAY_REQUIREMENTS.md` ve `PLAY_RELEASE_PLAN.md`'den alınır (B1–B14, G2 finans/kumar eki); bu belge onları tekrarlamaz, projeye uyarlar. Doğrulanmış şartlar: hedef API 36 (şablonda var); 16 KB hiza 1 Şub 2027'den zorunlu; yeni kişisel hesapta kapalı test ≥12 test kullanıcısı × 14 ardışık gün, sonra üretim başvurusu (~7 gün inceleme); PBL ≥8 (burada 9.1.0 var); Finansal özellikler beyanı zorunlu (finansal özellik yok cevabı); kategori Finans değil.

## 0. Genel kurallar (her görev için)

- Doğrulama kapısı: `tools/verify.sh` yeşil (526+ test) **ve** temiz klonda `godot --headless --path . --import` iki kez (ilki `.translation` eksik hatası verir; bkz. ASSESSMENT §8). Çıktıda `SCRIPT ERROR`/`Parse Error` olmayacak. `CLAUDE.md` kuralları bağlayıcı (veri JSON'da, çekirdek/arayüz ayrımı, SDK doğrudan çağrılmaz, gizli bilgi yok).
- Her görev kendi dalında, listedeki **sahip olduğu dosyalara** dokunur; "dokunmaz" listesi yasak. Ortak dosyalar için kural:
  - `assets/translations/strings.csv` / `story.csv`: yeni anahtar **görevin kendi önek bloğuyla dosya sonuna** eklenir (örn. `REL_`, `ACC_`); birleştirmede çakışma sondaki bloklardır, sırayla çözülür. Mevcut satırları yalnız yerelleştirme görevi (T-L1) değiştirir.
  - `project.godot` ve `export_presets.cfg`: yalnız belirtilen görev; başka görev gerekirse "istek" olarak lidere yazar.
  - `scripts/ui/desk_screen.gd` (1638 satır) yalnız **T-D1**.
- Commit yalnız lider/sahip onayıyla (CLAUDE.md kural 5); işçi commit atmaz, diff bırakır.
- Model önerisi: **Opus** = riskli çekirdek/akış/birden çok dosya kararı; **Sonnet** = iyi tanımlı, ölçülebilir iş; Haiku = yalnız mekanik biçim/çeviri kontrolü.
- Gizli bilgi: anahtar/keystore/parola dosyaya yazılmaz; `.env*` okunmaz (yalnız sahibin çalıştırdığı araçlar okur).

## 1. Sahibe ait olanlar (işçi yapamaz) — erken başlatılırsa takvimi kısaltır

| # | İş | Neden / not |
|---|---|---|
| O1 | **Play Console geliştirici hesabı** (kimlik doğrulama, ücret, ödeme profili) | Yeni kişisel hesapta kapalı test: **≥12 test kullanıcısı × 14 ardışık gün** (PLAY_REQUIREMENTS §1.7; Play Console'da yeniden teyit et); en uzun bekleme burada → tester bulmayı hemen başlat. Satıcı hesabı (IAP) açılırsa adres herkese açık görünür (§1.6). |
| O2 | **Paket kimliği kararı** (örn. `com.<sahip>.exchangedesk`) | `com.example.*` kabul edilmez; ilk yüklemeden sonra değişmez. Diğer oyunlar `com.<ad>.game` kalıbında. |
| O3 | **Mağaza adı** (§5) ve kategori kararı | Başlık ≤ 30 karakter; kategori seçimi (Oyun › Simülasyon/Bulmaca/Strateji) politika işçisinin notuyla. |
| O4 | **AdMob hesabı**: uygulama + 2 reklam birimi (ödüllü, geçiş) ve gerçek kimlikler | `data/ads_ids.json` `real_*` alanları sahipten gelir; ajan uydurmaz. Play'e uygulama bağlandıktan sonra app-ads.txt gerekebilir (politika matrisine bak). |
| O5 | **Release keystore** (veya Play App Signing yükleme anahtarı) | Ortam değişkenleri `GODOT_ANDROID_KEYSTORE_RELEASE_{PATH,USER,PASSWORD}`; asla depoya girmez. Kaybedilirse yedek: Play App Signing önerilir. |
| O6 | **Gizlilik politikası URL'si** (metni T-S1 hazırlar, sahip barındırır) ve destek e-postası | Play zorunlu (reklam/AD_ID var). |
| O7 | **Play Console ürünü `no_ads`** (tek seferlik, fiyat) + **lisans test kullanıcıları** | Gerçek billing denemesi buna bağlı; fiyat kararı (varsayılan $2,99, bölgesel fiyat Play'de). |
| O8 | **Karar: kovuldun/oyun bitti akışı** (§3 T-B1): ücretsiz "günü tekrar oyna" hakkı verilsin mi? | Önerim: günde 1 ücretsiz + ek haklar ödüllü reklamla. |
| O9 | **Karar: yaş derecelendirme/hedef kitle** (13+ önerildi, çocuklara yönelik değil) | Politika matrisi + IARC anketi cevapları T-S1'de hazırlanır; sahip gönderir. |
| O10 | **ElevenLabs anahtarını yerelde çalıştırma** (T-A1 betikleri) | Ücretli Starter planında yeniden üretim; anahtar sahipte kalır. |
| O11 | **En az bir gerçek Android telefon** (mümkünse orta segment) + gerçek cihaz test turu | Faz 12 hiç yapılmadı; ana tehlike. |
| O12 | **Vergi/ödeme bilgileri** (Play + AdMob) | IAP/reklam geliri için. |

## 2. Aşamalar

```
Faz 1  Yayın temelleri (paralel, 6 görev)  ──┐
Faz 2  Ürün cilası ve içerik (paralel, 5)   ─┤→ içerik dondurma
Faz 3  Yerelleştirme (es pt de ja ko)        ┘→ son metin
Faz 4  Aday sürüm → dahili test → kapalı test → üretim
```

Faz 1 ve Faz 2 aynı anda başlayabilir (dosya sahipleri ayrık, bkz. matris §4). Faz 3'ün çeviri işçileri Faz 2'nin metin dondurmasından sonra son turu yapar; ama altyapı (T-L1) hemen başlayabilir.

### Faz 1 — Yayın temelleri

**T-R1 · Android derleme/imza hattı** (Opus)
- Amaç: sahip keystore'unu verince tek komutla imzalı AAB; o zamana kadar CI'da imzasız/debug-imzalı doğrulama AAB'si.
- Yapılacaklar: `package/unique_name` placeholder → sahip kararı (O2) tek yerden (sürüm/kimlik script'i); `version/code` otomatik artırma + `version/name` tek kaynak (`config/version` ile eşitleme, sahibin onayıyla); `permissions/vibrate=true` ekle ve cihazda titreşim doğrula; kullanılmayan izin taraması (merge'lenmiş manifest listesi); `screen/immersive_mode`/edge-to-edge hedef API 36 davranışı; 16 KB sayfa hizası kontrolü (`libgodot_android.so`, `zipalign -c -P 16` veya ELF kontrolü) ve rapor; `Android Release` AAB (`gradle_build/export_format=1`) yerel üretimi (ağ gerekir: Gradle bağımlılıkları); boyut ölçümü (AAB, `bundletool` ile indirme tahmini); ProGuard/R8 `minify` durumu kontrolü; ekran dönüşü kilidi (dikey) doğrulaması; `profileable` etiketinin release'te gereği (kaldırma kararı raporu).
- Gate: gerçek-reklam/IAP bayrakları (`mode=real`, `providers.play_billing`) için **release kapısı betiği** `tools/release_check.sh` (yeni): `mode=real` ve üç gerçek id dolu mu, `package` `com.example` mi, `version/code` önceki yüklemeden büyük mü, keystore env var var mı, debug sağlayıcı sızıntısı yok mu → hepsi geçmeden AAB üretme.
- Sahip olduğu: `export_presets.cfg`, `tools/android_run.sh`, `tools/emulator_start.sh`, `tools/release_check.sh` (yeni), `tools/release_build.sh` (yeni), `docs/RELEASE_BUILD.md` (yeni), `.gitignore` (yalnız eklenti).
- Dokunmaz: `scripts/**`, `assets/**`, `data/**` (boyut için özel şablon önerisi rapora yazılır, kendisi üretmez), `project.godot` (ihtiyaç varsa istek).
- Kabul: `tools/verify.sh` yeşil; `tools/release_check.sh` bilerek bozuk girdiyle (placeholder paket/test id) **başarısız**, doğru girdiyle başarılı; AAB üretilir, yolu/boyutu/SHA-256 raporlanır; AAB'de `com.android.vending.BILLING`, `AD_ID`, `VIBRATE`, `INTERNET`, `ACCESS_NETWORK_STATE` ve başka izin yok.

**T-R2 · Marka ve mağaza grafikleri** (Sonsuz Sonnet; ikon tasarımı sahibin onayıyla)
- Amaç: ikon/açılış/mağaza varlıkları.
- Yapılacaklar: oyunun kendi çizim koduyla (banknot + damga) **adaptif ikon** katmanları (ön plan 432x432 güvenli bölgeli, arka plan, monokrom) + 192 px eski ikon + 512x512 Play ikonu; `boot_splash` (düz zemin + logo, "Godot logosu" yok); 1024x500 öne çıkan görsel; telefon ekran görüntüsü üretici aracı (`tools/store_shots.gd`, geçici kayıtla, TR ve EN, her biri 1080x1920 veya 1080x2160 dikey, 6–8 kare: gişe, inceleme, damga, akşam, kur tablosu, sonlar).
- Sahip olduğu: `assets/branding/**` (yeni), `icon.svg`, `tools/store_shots.gd` (yeni), `store/graphics/**` (yeni, çıktı klasörü).
- Dokunmaz: `export_presets.cfg` ve `project.godot` (ikon yollarını T-R1/lider ekler; T-R2 yolları raporda listeler); `scripts/**`.
- Kabul: PNG'ler boyut/oran kurallarına uygun (alfa yok 512 ikon; 1024x500 tam); ekran görüntüleri gerçek oyun sahnelerinden (cihaz çerçevesi/metin eklenmemiş); gerçek ülke/banknot yok; `verify.sh` yeşil.

**T-M1 · Para kazanma sertleştirme ve onay akışı** (Opus)
- Amaç: gerçek reklam/IAP'ye güvenli geçiş; onay çift gösterimini ve yanlış beyanı düzelt.
- Yapılacaklar: `providers.play_billing=true` yolunun etkinleştirilmesi (kapı: Play Console ürünü var — O7; kod hazır olsun, bayrak lider/sahip tarafından açılır); `uses_real_ids()` ve `mode=real` sessiz düşme yerine **release'te hata** (kapı betiği ile bağlı, T-R1); UMP ile `ConsentSheet` birleştirme: bölgeye göre yalnız gereken form (EEA/UK: UMP; diğer: kısa bilgi); `CONSENT_TEXT` gerçeği yansıtsın (analitik SDK yok) — metin T-S1 ile mutabık; reklam kişiselleştirme ve analitik onayını ayrı anahtarlara ayır; Market ekranı billing bağlantı gecikmesinde yeniden dener (`purchases_restored`/`connected` sinyaliyle `_refresh`); `AD_ID` ve test-id sızıntısı için `tools/sync_ads_config.py` doğrulaması; gerçek cihaz test listesi yazımı (test reklamı + lisans test satın alması); ödüllü reklamın zaman aşımı ve "reklam yok" akışlarının sağlamlığı; `retry_day` için ücretsiz yol hazır arayüz kancası (karar O8 → uygulaması T-B1).
- Sahip olduğu: `scripts/autoload/{monetization,ads,iap,analytics}.gd`, `scripts/services/**`, `scripts/ui/{consent_sheet,market_screen,fake_ad}.gd`, `data/{ads,ads_ids,products}.json`, `tools/sync_ads_config.py`, `addons/AdmobPlugin/android_export.cfg`, `tests/unit/{test_monetization,test_real_providers,test_consent}.gd`, `scenes/market.tscn`.
- Dokunmaz: `settings_screen.gd` (privacy düğmesi çağrısı değişirse arayüz sözleşmesini `Monetization` üzerinde tut, ekranı T-A2 günceller), `game_over_screen.gd` (T-B1), `desk_screen.gd`.
- Kabul: `verify.sh` yeşil; `test_consent`/`test_real_providers` yeni durumlarla genişler (EEA/EEA dışı, onay reddi, billing gecikmesi, test→real geçişi); `mode=real` + boş id → **hata** (test_real_providers); `Analytics` metni ile uyumlu; gerçek id olmadan kod hiçbir gerçek kimlik içermez.

**T-V1 · Kayıt sağlamlığı ve yaşam döngüsü** (Opus)
- Amaç: oyuncu ilerlemesini asla kaybetmeyen kayıt; Android yaşam döngüsü.
- Yapılacaklar: `save.json` için `.bak` (yazmadan önce önceki iyi kopyayı sakla), bozuk/kesik JSON'da yedekten yükle + kullanıcıya bildirmeden sessiz kurtarma, kurtarılamıyorsa bozuk dosyayı `save.corrupt.<ts>` olarak sakla (üzerine yazma); gerçek `_migrate()` zinciri (v1→v2 örnek test), sürüm yükseltme/düşürme kuralı; `Career.SAVE_VERSION` ile birleştirme; kaydın `NOTIFICATION_APPLICATION_PAUSED/FOCUS_OUT` ve vardiya içi güvenli yazması (şu an sabah anlık görüntüsü); ses odağı: duraklat/devam (`AudioManager` pause/resume, telefon araması simülasyonu notu); testlerin gerçek `user://settings.cfg` dosyasına yazmasını kapat (test izolasyonu: `SettingsManager` yolu değiştirilebilir).
- Sahip olduğu: `scripts/autoload/{save_manager,settings_manager,audio_manager,game_session}.gd` (yalnız kayıt/yaşam döngüsü bölümleri), `scripts/core/json_io.gd`, `scripts/core/career.gd` (yalnız `to_dict/load_dict/SAVE_VERSION`), `tests/unit/{test_json_io,test_game_session,test_autoloads}.gd` + yeni `test_save_recovery.gd`, `test_save_migration.gd`.
- Dokunmaz: `scene_manager.gd` (T-P1), `desk_screen.gd`, `data/**`.
- Kabul: `verify.sh` yeşil; yeni testler: yarım yazılmış dosya, boş dosya, geçersiz JSON, yedek kurtarma, eski sürüm migrasyonu, gelecek sürüm; gerçek `user://save.json` ve `settings.cfg` testlerde dokunulmaz (test sonunda mtime değişmez).

**T-P1 · Performans ve cihaz hazırlığı** (Sonnet; cihaz turu sahip/Opus)
- Amaç: orta segment telefonda akıcılık ve boyut.
- Yapılacaklar: `pixel_filter.gdshader` maliyet ölçümü ve **otomatik kapatma** (kare süresi eşiği/ilk açılışta cihaz sınıfı; varsayılanı mid-range'de kapalı yapma önerisi), düğüm sayısı/çizim bütçesi (`tools/perf_probe.gd --part=frames` genişletme: P95 kare süresi, bellek), kullanılmayan `Baloo2.ttf`/`PixelifySans.ttf` dışarıda bırakma önerisi (silme sahibin onayıyla, CLAUDE.md kural 6), `exclude_filter` önerileri, özel dışa aktarma şablonu (3D/kullanılmayan modüller kapalı) boyut kazanımı **raporu** (üretimi sahip kararı); `SceneManager` geçiş/geri tuşu davranış testleri; 30 dk gerçek cihaz kesintisiz oturum betiği ve kontrol listesi.
- Sahip olduğu: `assets/shaders/pixel_filter.gdshader`, `scripts/autoload/scene_manager.gd` (pixel filtre bölümü), `tools/perf_probe.gd`, `tools/perf_*` (yeni), `docs/PERF_REPORT.md` (yeni), `tests/unit/test_performance.gd`, `tests/unit/test_scene_manager.gd`.
- Dokunmaz: `desk_screen.gd`, `data/**`, `export_presets.cfg` (öneri raporda).
- Kabul: `verify.sh` yeşil; rapor (Mac sayıları + varsa gerçek cihaz sayıları: ortalama/P95 kare süresi, bellek tepe, soğuk açılış süresi) hedefleri karşılıyor: orta segment cihazda masa sahnesi ≥ 55 fps ortalama, P95 kare ≤ 25 ms, soğuk açılış ≤ 3 sn (hedefler başlangıç önerisi; ölçüm sonrası sahip onaylar).

**T-S1 · Gizlilik, mağaza metni, politika belgeleri** (Sonnet; `PLAY_REQUIREMENTS.md`/`PLAY_RELEASE_PLAN.md` hazır, doğrudan kullan)
- Amaç: mağaza listesi ve yasal metinlerin taslakları (TR+EN).
- Yapılacaklar: gizlilik politikası metni (reklam kimliği, AdMob/UMP, kayıtlar cihazda, çocuklara yönelik değil, veri silme: uygulamayı kaldırma; analitik SDK yok), Veri güvenliği formu cevapları, IARC/içerik derecelendirme anketi cevapları (olgular: ASSESSMENT §10), hedef kitle ve reklam beyanları, kısa (≤80 karakter) ve uzun açıklama TR/EN, "Yenilikler" metni, mağaza adı seçeneklerine göre anahtar kelime notları (spam anahtar kelimesiz; "forex/ticaret" çağrışımı yok), uygulama kategorisi gerekçesi, `docs/store/` yapısı. Politika matrisiyle çelişki kontrol listesi; **Finansal özellikler beyanı** cevabı; ilan ve oyun içi "simülasyondur, finansal tavsiye değildir" ibaresi (oyun içi yer: T-A2 Hakkında + ilk açılış rehber sayfası T-D1); AdMob'da finans/kumar reklam kategorisi engel listesi (sahip konsolda uygular).
- Sahip olduğu: `docs/store/**` (yeni), `docs/PRIVACY_POLICY.md` (yeni).
- Dokunmaz: tüm kod/veri/varlık dosyaları.
- Kabul: her cümle koddaki gerçeğe karşılık gelir (ör. "analitik göndermiyoruz" yalnız `Analytics._send()` no-op iken); belge sahibin yayınlayacağı URL için tek başına okunabilir; TR/EN anlam eşdeğeri.

### Faz 2 — Ürün cilası ve içerik

**T-D1 · Masa ekranı, öğretici ve ilk dakika** (Opus)
- Amaç: yeni oyuncu 60 sn içinde ilk müşteriyi doğru işlemeyi öğrensin; masa ekranı bakımı.
- Yapılacaklar: etkileşimli Gün 1 öğreticisi (ok/halka + tek seferde bir eylem: "banknota dokun" → "İnceleme" → "Tamamla damgası"; atlanabilir; `GuideSheet` metin sayfalarını kısalt/arka plana al), gazete sayfasında özet satırı ("bugün yeni: ...") ve "Mesaiye başla"yı sayfa uzun olsa da görünür tut, **`desk_screen.gd` bölme** (1638 satır → panel/sheet/tool sınıfları; davranış değişmeden, düğüm adları TouchInput testleri için aynı kalır), küçük yazılar için telefon okunabilirliği taraması (en küçük yazı boyutu eşiği; kur tablosu, `Hata 0/2`), başparmak erişimi (alt damga düğmeleri/ödeme alanı), boş durumlar (Market/Son ekranı tipografik/boşluk düzeni — yalnız sahnelerini kendisi yapıyorsa; Market T-M1'de, o yüzden yalnız `game_over`/`mode_result` boşluk düzeni T-B1).
- Sahip olduğu: `scripts/ui/{desk_screen,booth_view,booth_frame,desk_surface,customer_figure,speech_bubble,stamp_button,note_tile,doc_tile,document_views,banknote_view,face_view,draggable_item,fate_zone,guide_sheet,rule_book,morning_screen}.gd` (+ bölmede yeni dosyalar), `scenes/{desk,morning}.tscn`, `tests/unit/{test_desk_screen,test_desk_tools,test_guide,test_rule_book,test_booth,test_story_screens}.gd`, `tests/session_case.gd` (gerekirse).
- Dokunmaz: `data/**`, `scripts/core/**` (kural değişikliği gerekirse istek), `monetization.gd`, `evening_screen.gd` (T-B1).
- Kabul: `verify.sh` yeşil (düğüm adları değişmedi, mevcut testler geçer); yeni öğretici testi: `TouchInput` ile yeni oyun → ilk müşteri doğru işlenir; öğretici "atla" ve geri tuşu; öğretici yalnız ilk yeni oyunda; ekran görüntüsü karşılaştırması (`style_shots`) önce/sonra raporda.

**T-B1 · Denge, kayıp durumu ve akşam/oyun bitti akışı** (Opus; veri ayarı Sonnet)
- Amaç: gerilimi artır, adaleti koru, `retry_day`'i ücretsiz alternatifle düzelt.
- Yapılacaklar: ASSESSMENT §8 sinyalleri: dikkatsiz bot mükemmelden zengin çıkıyor, mükemmelin nakdi hiç kritik düşmüyor, rüşvet cazibesiz. `data/balance.json`, `household.json`, `office.json` ayarları + `balance_sim` hedef tabloları: perfect bot kenarda ama hayatta (örn. en düşük nakit < kira × 0,3 bir kez), careless bot ≥1 kez ağır ceza/kovulma riski, cheater kısa vadede kazançlı ama müfettiş riskli; reklam izlemeyen mükemmel oyuncu bitirir (plan kuralı); **kovuldun/oyun bitti**: günde 1 ücretsiz tekrar + ek haklar ödüllü reklamla (O8), reklam yokken "Yeni oyun"dan başka çıkış (en azından "gün başı"na dön); `no_ads` sahibi için reklamsız alternatif sorusu (politika notu); akşam ekranı sadeleştirme; `mode_result`/`game_over` boş alan düzeni.
- Sahip olduğu: `data/{balance,household,office,modes,tools}.json`, `scripts/core/{shift,household,career(yalnız denge),directives}.gd`, `scripts/ui/{evening_screen,game_over_screen,mode_result_screen}.gd`, `scenes/{evening,game_over,mode_result}.tscn`, `tools/balance_sim.gd`, `tests/unit/{test_bot_balance,test_household,test_shift,test_career,test_office,test_day_flow,test_modes}.gd`.
- Dokunmaz: `data/story/**`, `customers.json`, `rules.json` (T-C1), `desk_screen.gd`, `monetization.gd`.
- Kabul: `verify.sh` yeşil; `balance_sim` 6 bot × ≥5 tohum tablo çıktısı rapora; "careless" ≤ "perfect" nakit, perfect nakit alt sınırı ≥ 1 kira kadar dalgalanma; fail akışı testi (ücretsiz hak harcanır → ödüllü reklam → yeni oyun).

**T-C1 · İçerik çeşitliliği ve hikaye denetimi** (Sonnet; yaratıcı yazım Opus)
- Amaç: tekrar hissini azalt, hikaye açıklarını kapat, 15. gün sonrası motivasyon.
- Yapılacaklar: `data/customers.json` çeşitlilik denetimi (kusur kombinasyonu, karakter etiketi, espri havuzu; sayısını ölçüp rapor), her kural için ≥ N farklı senaryo/anlatım; Gün 1–6 olay yoğunluğu; iki dilde (TR+EN) yeni metin; `StoryValidator` kapsamının yeni içerik için genişlemesi; Günün Kuru/Sonsuz için müşteri havuzu dengesi. İsteğe bağlı küçük keşif: başarım/rozet listesi (sadece öneri).
- Sahip olduğu: `data/{customers,rules(yalnız metin sayıları değil mekanik değişmez)}.json`, `data/story/**`, `assets/translations/story.csv` (yeni anahtarlar `S_`/`C_` önekli), `scripts/core/{story_validator,customer_factory}.gd`, `tests/unit/{test_story,test_customer_factory}.gd`.
- Dokunmaz: `balance.json` (T-B1), UI dosyaları, `strings.csv`.
- Kabul: `verify.sh` yeşil; `validate_content.gd` sağlam; üretici "kendi kendini doğrulama" testi (motor kararı = `truth`) yeni senaryolarda geçer; çeşitlilik tablosu (rapor): rastgele 200 müşteride tekrar oranı.

**T-A1 · Ses yeniden üretimi ve üretim kaydı** (Sonnet; sahip O10)
- Amaç: ücretli plan altında tüm sesi yeniden üret ve lisans izini bırak.
- Yapılacaklar: `make_sfx.py`/`make_music.py`'ye **üretim manifestosu** (`assets/audio/PROVENANCE.md`: dosya, tarih, plan, istem, süre, SHA-256) yazma; `--force` ile tümünün yeniden üretimi (sahip çalıştırır; işçi anahtarı okumaz); loop dikişi kontrolü (müzik/ambient başı-sonu aynı genlik, çapraz geçiş), LUFS normalizasyonu (hedef: müzik ≈ −20 LUFS, SFX tepe ≈ −3 dBFS, Master seviyesi), boyut (mp3 bit hızı), Godot loop işaretleri; ses ayarına Master kaydırıcısı için kanca **yok** (T-A2); eski dosyaların yedeği silme **sahibin onayıyla** (CLAUDE.md kural 6).
- Sahip olduğu: `assets/audio/**`, `tools/make_sfx.py`, `tools/make_music.py`, `tools/audio_check.py` (yeni), `assets/audio/PROVENANCE.md` (yeni).
- Dokunmaz: `audio_manager.gd` (T-V1), `scripts/**`.
- Kabul: tüm 38 dosya yeni; `verify.sh` yeşil (importta hata yok); loop kontrol raporu; PROVENANCE tam; paket boyutu rapor (≤ ~9 MB ses).

**T-A2 · Ayarlar, erişilebilirlik, hakkında/lisanslar** (Sonnet)
- Amaç: plan §2.8'in vaat ettiği ama kodda olmayan ayarlar + yasal ekran.
- Yapılacaklar: yazı boyutu (normal/büyük: `FONT_SCALE` / tema çarpanı; `build_theme.py` yeniden üretim), Master ses kaydırıcısı, **renk körü modu** (sahte ipuçlarının renk dışı desen/etiket eşdeğeri; `banknote_view.observe` sözleşmesi korunur — bu dosya T-D1'de, o yüzden değişiklik yalnız tema/ayar bayrağı ve sözleşme önerisiyle T-D1'e istek), "Hakkında": sürüm, yazı tipi/eklenti lisansları (VT323 OFL, AdMob/Billing MIT, Google SDK bildirimleri), gizlilik politikası bağlantısı (`OS.shell_open(URL)` yalnız sahibin verdiği URL), "Satın alımları geri yükle" ve gizlilik düğmeleri düzeni, ayar ekranı boş alan düzeni.
- Sahip olduğu: `scripts/ui/settings_screen.gd`, `scenes/settings.tscn`, `scripts/autoload/settings_manager.gd` (yalnız yeni ayar anahtarları; kayıt bölümü T-V1'de — çakışırsa T-V1 önce), `tools/build_theme.py`, `assets/theme/main_theme.tres` (üretilir), `assets/fonts/` (kullanılmayan fontların kaldırılması **sahip onayıyla**), `tests/unit/test_autoloads.gd` (yalnız ayar testi eklemek), yeni `scripts/ui/about_sheet.gd`.
- Dokunmaz: `banknote_view.gd`, `desk_screen.gd`, `monetization.gd`.
- Kabul: `verify.sh` yeşil; ayarlar kalıcı; büyük yazıda hiçbir ana ekranda taşma yok (`style_shots` ile 5 ekran karşılaştırma); lisans metinleri paketle gelen dosyalarla birebir.

### Faz 3 — Yerelleştirme (es, pt, de, ja, ko)

Çeviri yükü küçük (EN kaynak ≈ 25 bin karakter, 589 anahtar). Diğer oyunlarda kurulu 7 dil düzeniyle uyumlu olmak için: sözlük belgesi, anahtar kuralları, bütçe testleri (`CamasirIpi/docs/I18N.md` örnek).

**T-L1 · Yerelleştirme altyapısı** (Opus)
- Amaç: dilleri tek betikle birleştiren altyapı + font.
- Yapılacaklar: dil başına ayrı dosya (`assets/translations/lang/<xx>.csv`, `keys,<xx>`) → `tools/merge_translations.py` ile `strings.csv`/`story.csv` sütunlarına birleştirme (paralel çevirmenler çakışmaz); `data/languages.json` + `project.godot` `locale/translations` listesi; **es/pt/de**: VT323 Latin-1'i kapsıyor (doğrulandı), taşma bütçeleri/uzun metin testi; **ja/ko**: piksel görünümüyle uyumlu CJK font seçimi (lisans OFL/serbest, boyut ≤ ~4 MB alt küme), `FONT_SCALE`/elle ölçekli çizimler için dil bazlı ölçek, yedek font zinciri; çoğul/sayı biçimi ve sayı gösterimi (`number_format.gd`) yerel ayarlar; `test_localization` boş çeviri/yer tutucu uyumu (`%d`/`%s`) dil başına; cihaz dili → desteklenen dil eşlemesi (pt-BR/pt-PT, zh gelirse yok); Play listesi dilleri.
- Sahip olduğu: `assets/translations/**` (birleştirme), `data/languages.json`, `project.godot` (`[internationalization]` bölümü), `scripts/core/number_format.gd`, `tests/unit/test_localization.gd`, `tools/merge_translations.py`, `assets/fonts/` (yeni CJK, **indirme sahibin onayıyla**: ad/kaynak/boyut/lisans belirtilerek).
- Dokunmaz: tüm UI dosyaları (taşma bulgusu raporlanır; düzeltme T-D1/T-A2'ye istek).
- Kabul: `verify.sh` yeşil; 7 dilde `test_localization` geçer; `style_shots` her dilde menü/masa/akşam/ayar ekranı taşma kontrol raporu (PNG'ler).

**T-L2 · es + pt + de çevirileri** (Sonnet) — **T-L3 · ja + ko çevirileri** (Sonnet; ikincil gözden geçirme Opus)
- Amaç: `strings` ve `story` çevirileri, tutarlı sözlükle (para birimleri adları — PL/FED/AVR/STR/DNR/KRN — dillerde aynı kalır; karakter adları: Rıza, Tilki, Nalan, Deniz, Hayri; "kuruş" → `cent`-benzeri yerel karşılık kararı sözlükte).
- Sahip olduğu: `assets/translations/lang/{es,pt,de}.csv` (L2) ve `lang/{ja,ko}.csv` (L3), `docs/I18N_GLOSSARY.md` (yeni; L2 yazar, L3 uyar).
- Dokunmaz: her şey diğer.
- Kabul: anahtar kümesi `strings.csv`/`story.csv` ile birebir, boş yok; `%d/%s` yer tutucu aynı; kısıtlar: düğme ≤ 20 karakter, balon ≤ 90 karakter (TR/EN ile aynı bütçe); ES `¿/¡` açılış işaretleri; JA/KO ağır kısaltma yok; anadilden gözden geçirme sahibe bırakılır (makine/model çevirisi uyarısı belgelenir).

### Faz 4 — Aday sürüm

**T-Q1 · Entegrasyon ve cihaz QA** (Opus + sahip) — Faz 1–3 birleştikten sonra seri
- Temiz klonda iki import + `verify.sh`; `tools/release_check.sh`; imzalı AAB (O5); dahili test kanalına yükleme (sahip); gerçek cihaz 30 dk kesintisiz oturum + her ekran; geri tuşu/arama/uygulama değiştirme/pil tasarrufu/yatay döndürme kilidi; gerçek ödüllü + geçiş test reklamı; lisans test kullanıcısıyla satın alma + geri yükleme + iade; kayıt kurtarma; 3 farklı ekran en-boy (20:9, 16:9, katlanabilir/tablet) ve çentik.
- Çıktı: `docs/QA_REPORT.md`, bilinen sorunlar listesi, versiyon `1.0.0` / `version/code` kararı.
- Sonra: kapalı test (sayı/süre Play Console'daki güncel şarta göre) → üretim erişimi başvurusu → aşamalı yayın (%20 → %100) → ilk hafta vitals/ANR/crash izleme.

## 3. Önerilen ilk üç görev (hemen başlat)

1. **T-R1 Android derleme/imza hattı** — en uzun ve en riskli bilinmeyenler (AAB hiç üretilmedi, 16 KB hiza, izinler, sürüm/paket kapısı); sahip O2/O5 kararlarıyla paralel.
2. **T-V1 Kayıt sağlamlığı ve yaşam döngüsü** — kullanıcıyı kaybettiren tek sessiz hata (bozuk kayıt) ve migrasyon altyapısı; başka birçok görevin (T-A2 ayarlar, T-B1 akış) güvenle ilerlemesi için erken olmalı.
3. **T-D1 Masa ekranı + ilk dakika öğreticisi** — en büyük elde tutma riski (yeni oyuncu kaybı) ve `desk_screen.gd` bölmesi; tek sahibi olduğu için diğer masa işlerini engellemez, uzun sürdüğü için erken başlar.

(Hemen ardından paralel: T-M1, T-R2, T-S1; sahip tarafında O1, O2, O4, O11.)

## 4. Dosya sahipliği matrisi (çakışma kontrolü)

| Dosya/klasör | Tek sahip |
|---|---|
| `export_presets.cfg`, `tools/android_*.sh`, `tools/release_*` | T-R1 |
| `assets/branding/**`, `icon.svg`, `store/graphics/**` | T-R2 |
| `scripts/autoload/{monetization,ads,iap,analytics}.gd`, `scripts/services/**`, `consent_sheet.gd`, `market_screen.gd`, `data/ads*.json`, `data/products.json` | T-M1 |
| `save_manager.gd`, `settings_manager.gd` (kayıt), `audio_manager.gd`, `json_io.gd`, `game_session.gd` | T-V1 |
| `scene_manager.gd`, `pixel_filter.gdshader`, `tools/perf_*` | T-P1 |
| `docs/store/**`, `docs/PRIVACY_POLICY.md` | T-S1 |
| `desk_screen.gd` + masa UI dosyaları, `guide_sheet.gd`, `rule_book.gd`, `morning_screen.gd` | T-D1 |
| `data/{balance,household,office,modes,tools}.json`, `evening/game_over/mode_result` UI | T-B1 |
| `data/story/**`, `customers.json`, `rules.json` metinleri, `story.csv` yeni anahtarlar | T-C1 |
| `assets/audio/**`, `tools/make_*.py` | T-A1 |
| `settings_screen.gd`, `about_sheet.gd`, `build_theme.py`, tema | T-A2 |
| `assets/translations/**` birleştirme, `languages.json`, `project.godot [internationalization]` | T-L1 (çeviri dosyaları `lang/`: L2/L3) |
| `project.godot` diğer bölümleri (`[application]` ikon/splash/sürüm) | Lider (T-R1/T-R2 isteği ile) |

Zaman çizelgesi (tahmin; paralel işçilerle): Faz 1 ≈ 1 hafta, Faz 2 ≈ 1–1,5 hafta (T-D1 en uzun), Faz 3 ≈ 3–4 gün (altyapı Faz 1 ile başlar), Faz 4 aday sürüm ≈ 2–3 gün + **kapalı test süresi (Play'in güncel şartı)** + incelemeler. Sahip tarafı gecikmeleri (hesap doğrulama, kapalı test) toplam takvimi belirler.

## 5. İngilizce mağaza adı — 3 öneri (çevrimiçi kontrol yapılmadı; sahibin ad müsaitlik/marka taraması gerekir)

1. **Pahalistan Exchange Desk** (24 kr.) — özgün sözcük "Pahalistan" aranabilir ve ayrıştırıcı; kurgusal ülke, gerçek finans/forex çağrışımını ve "gerçek para" yanlış algısını azaltır; oyun içi `APP_TITLE` "Exchange Desk" ile uyumlu.
2. **Stamp & Count: Exchange Desk** (28 kr.) — eylem odaklı (damga + say), tür beklentisini netleştirir ("exchange desk" anahtarı korunur), finans uygulaması sanılma riski düşük.
3. **Counterfeit Counter** (19 kr.) — kısa ve akılda kalıcı söz oyunu (counter = gişe/sayaç); sahte banknot temasını öne çıkarır, ancak "exchange" geçmediği için aramada zayıf ve genel isim çakışma riski yüksek.

Öneri: 1 numara (dil-bağımsız marka + açıklayıcı alt ad); simgede/ekran görüntülerinde gerçek banknot/ülke imgesi ve "Papers, Please" adı kullanılmaz.

## 6. Yayın kapısı kontrol listesi (özet)

- [ ] `verify.sh` yeşil, temiz klonda iki import.
- [ ] `release_check.sh` yeşil: paket ≠ `com.example`, `mode=real` + gerçek id, `play_billing=true`, `version/code` artmış, keystore env var'ları mevcut.
- [ ] AAB imzalı; izin listesi doğru; 16 KB hiza; boyut raporu.
- [ ] İkon (adaptif + 512), splash, öne çıkan görsel, ekran görüntüleri, TR/EN (+ yeni diller) metinler.
- [ ] Gizlilik politikası URL'si canlı; Veri güvenliği/IARC/hedef kitle formları gönderildi (politika matrisiyle uyumlu).
- [ ] UMP (AB/UK) gerçek id ile test; ödüllü/geçiş reklamı; `no_ads` satın alma + geri yükleme + iade (lisans testçisi).
- [ ] Kayıt bozulma/migrasyon testleri yeşil; 30 dk cihaz oturumu temiz logla.
- [ ] Ses yeniden üretimi (ücretli plan) ve `PROVENANCE.md`; lisans/hakkında ekranı.
- [ ] Kapalı test koşulu karşılandı; aşamalı yayın planı ve vitals izleme.
