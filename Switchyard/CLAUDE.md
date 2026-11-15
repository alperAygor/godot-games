# Switchyard — ajan kuralları

Godot 4.7, GDScript (C# yok), `gl_compatibility`, dikey 1080x1920, mobil (Android).
Bu dosya projenin anayasasıdır; kural ile sezgi çatışırsa kural kazanır.
Bu proje `studio-kit/template-mobile` şablonundan üretildi; şablon boş bir iskelettir
(Boot → Home → Game → sonuç sayfası, kayıt, jeton, reklam sahte sağlayıcısı, dil, ayarlar).
Oyun mekaniği YOKTUR: `PlaceholderRun` ve `scripts/ui/game.gd` içindeki "YER TUTUCU" bölümler gerçek oyunla değiştirilir.

## 0. Sabit kurallar (kullanıcı kararları, değişmez)

1. **Görsel kural #1:** low-poly YOK. Pürüzsüz, yüksek kaliteli model/sprite; asla piksel piksel görünmez.
   Arayüz: minimal, modern, düz (flat), çizgisiz, küçük ikonlar, yumuşak ve "premium" (bkz. `docs/UI_GUIDE.md`).
2. **İşçiler yalnız Claude modelleridir.** Yönetmen Fable'dır; Haiku/Sonnet/Opus zorluğa göre atanır, dış işçi yok.
   Her işçinin **dosya sahipliği katıdır** (başkasının dosyasına dokunmaz). Ortak dosyalara (`game.gd`,
   `GameManager.gd`, `project.godot`...) yalnız küçük, işaretli kancalar eklenir. `strings.csv` **yalnız sona satır eklenir**
   (append-only; `.gitattributes` `merge=union` çakışmayı korur).
3. **İşçi güvenliği:**
   - `pkill` / `killall` ASLA; yalnız kendi başlattığın PID'leri öldür.
   - `git stash`, `git checkout --`, `git reset`, `git clean` ASLA.
   - Kullanıcı onayı olmadan indirme yok (ağ, paket, model, varlık).
   - `.env*` dosyalarını okuma/yazdırma yok.
   - Oyuncunun gerçek kaydına yazma: araç/prob/test koşarken `Progress.persist = false` (ilk iş).
   - Doğrulama (verify/probe) koşusu sürerken `main`'e birleştirme yok.
   - Commit'i yalnız lider (yönetmen) atar; kullanıcı istemedikçe push yok.
4. **Sesler/müzik ElevenLabs ile** `tools/make_sfx.py` üzerinden üretilir; anahtar `.env.local`'den yüklenir
   (asla yazdırılmaz, asla koda girmez, dosya asla commit edilmez).
5. **Saf mantık çekirdeği** `RefCounted`, sahnesiz ve birim testlidir. **Kabul kapısı:** headless probelar +
   `tools/verify.sh`. Gerçek pencere araçları başka bir pencere öndeyken takılabilir ve gerçek zamanda çalışır
   (oynanış probu gerçek zamanlı akar): **yavaş ≠ asılı**.
6. **Para kazanma (kullanıcı kararı 2026-11-15; değerler `data/ads.json`):** ipucu = ödüllü reklam; seviyeyi atla =
   ödüllü reklam; geçiş reklamı ilk 3 seviyede yok, sonra her 3 seviye bitişinde bir (oyun sırasında asla); ücretli
   "reklamları kaldır" yalnız geçiş reklamını kapatır. Jeton ekonomisi YOK. **Çevrimdışı oynamak yasak**
   (`data/balance.json` → `require_online`, `OnlineGate`). Ayrıntı: `docs/DESIGN.md` §5.
7. **Varsayılan dil İngilizce:** cihaz dili destekleniyorsa o, değilse İngilizce; eksik anahtar İngilizceye düşer.
8. **Oyun:** manevra sahası bulmacası. Tasarım `docs/DESIGN.md`, sözleşmeler `docs/CORE_API.md`. Sözleşme dosyaları
   (`scripts/game/level_session.gd`, `scripts/core/level_catalog.gd`) ve bu iki belge yalnız lider tarafından değişir.
   Çözülemeyen seviye yayına girmez: her seviye çözümünü taşır, testte oyunun kendi kurallarıyla yeniden oynatılır.

## 1. Kod kuralları

- **Tam statik tip.** `project.godot` içinde `untyped_declaration=2` (hata). Her fonksiyon parametre ve dönüş
  tipi taşır (`-> void` dahil); `for i: int in ...`; lambda `func() -> void:`. Koleksiyonlar tiplidir.
- **Sahne geçişi yalnızca `GameManager.goto_scene()`** ile (sahne anahtarları `GameManager.SCENES`).
- **Ses yalnızca `AudioService`** ile; sesler `data/sounds.json`'da tanımlıdır.
- **Reklam yalnızca `AdManager`** üzerinden; SDK çağrısı sadece `AdsProvider` uygulamasında.
- **Sihirli sayı yok.** Denge `data/*.json` + `GameData`/`ProgressData.load_balance()`; arayüz ölçüleri `data/theme.json` →
  `UiTokens`; hareket süreleri `Motion`.
- **Kayıt yalnızca `Progress`** üzerinden. Oyuna özgü kayıt `Progress.set_module_value("modül", ...)` ile (ProgressData'ya alan eklenmez).
- Metinler yalnızca `Loc`/`UiStrings` üzerinden (`data/i18n/strings.csv`); kodda ham kullanıcı metni yok (bkz. `docs/I18N.md`).
- Yorum "ne" değil "neden" yazar; Türkçe yazılır, tanımlayıcılar İngilizce. `print()` üretimde yasak
  (`push_warning`/`push_error`; probelar istisna).
- **`-s` betiği tuzağı:** `-s` ile çalışan araç/prob betiği autoload'lardan ÖNCE derlenir; autoload'a değen sınıfları
  (ResultSheet, RunFlow...) tür olarak anarsa "Identifier not found" verir. `Node`/`Control` kullan, `call`/`emit_signal` ile çağır.
  Autoload `_ready`leri betiğin `_initialize`ından sonra çalışır: kayıt/sağlayıcı ayarını ilk kareden sonra yap.

## 2. Klasörler

| Klasör | İçerik |
|---|---|
| `scenes/` | `.tscn` (Boot, Home, Game) |
| `scripts/autoload/` | GameManager, AudioService, AdManager, GameData, Progress |
| `scripts/core/` | Saf mantık: Loc, AdPacing, ProgressData, AnalyticsLog, Motion, Juice, Icons, PlaceholderRun |
| `scripts/ui/` | Ekranlar, UiKit, Sheet'ler, HUD; yalnız gösterir (`kit/ui_tokens.gd` ÜRETİLİR) |
| `scripts/services/` | Dış SDK sınırı: AdsProvider, Mock/NoAds, AdMob sağlayıcı + köprü |
| `scripts/net/` | OnlineGate (bağlantı kapısı) |
| `data/` | JSON tabloları, `theme.json`, `i18n/strings.csv` |
| `tests/` | `test_case.gd`, `run_tests.gd`, `unit/test_*.gd` |
| `tools/` | verify, probelar, ekran görüntüsü, tema/font/boyut araçları |
| `docs/` | Rehberler (`.gdignore`'lu; pakete girmez) |

## 3. Akış

`Boot` → `Home` → `Game` (sonuç sayfası Game üstünde `ResultSheet` olarak açılır) → Devam / Tekrar / Ana ekran.
Tur sonucu `GameManager.last_result`. Geri tuşu `GameManager.back_requested`. Ayrıntı: `docs/ARCHITECTURE.md`.

## 4. Doğrulama (commit öncesi zorunlu)

```bash
bash tools/verify.sh
```

İçe aktarma (iki geçiş) + açılış dumanı + birim testleri + tema güncelliği + `play_probe` + `lang_probe`.
Godot **script hatasında da 0 döndürür**, bu yüzden çıktı ayrıca taranır. Kırmızıysa commit atılmaz.
Görsel QA: `godot --path . -s res://tools/screenshot.gd -- --out-dir=build/shots --lang=tr` (gerçek pencere).

## 5. "Bitti" tanımı

1. `verify.sh` yeşil,
2. yeni davranışın testi var (ya da neden yok yazılı),
3. yeni metinler 3 dilde (`strings.csv`, sona eklenerek),
4. `TASKS.md` ve `CHANGELOG.md` güncel.

## 6. Yeni oyuna başlarken

`TASKS.md`'deki "Faz 1" hedefini yaz → `PlaceholderRun`'ı gerçek kural sınıfıyla değiştir → `game.gd`'nin YER TUTUCU
bölümlerini değiştir → `play_probe.gd` oynama döngüsünü güncelle → `PH_*` metinlerini ve `PlaceholderRun` testini sil.
Paket kimliği/AdMob/imza: `docs/MONETIZATION.md`.
