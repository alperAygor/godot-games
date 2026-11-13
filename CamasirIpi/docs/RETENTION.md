# Tutundurma katmanı (retention)

Amaç: "oyuncuyu nasıl daha uzun tutarız?" sorusuna dört küçük, tutarlı sistemle cevap.
Hepsi `scripts/retention/` altındadır; saf mantık + test + kompakt arayüz + analitik olayı.
Durum `Progress` modül bölümü **"retention"** altında tutulur (ayrı kayıt dosyası yok).
Sayılar `data/retention_*.json` dosyalarındadır; kod içinde denge değeri yoktur.

| Sistem | Mantık (saf) | Sayfa | Veri |
|---|---|---|---|
| Günlük görevler | `missions.gd` | `missions_sheet.gd` | `retention_missions.json` |
| Ödül yolu | `milestones.gd` | `milestone_sheet.gd` | `retention_milestones.json` |
| Haftalık etkinlik | `weekly_event.gd` | `weekly_sheet.gd` | `retention_weekly.json` |
| Geri dönüş + seri | `comeback.gd` | `comeback_sheet.gd` | `retention_comeback.json` |
| Bildirim | `notify_plan.gd`, `notifier.gd` | - | `retention_core.json` |

Yapıştırıcılar: `retention_events.gd` (olay yolu), `retention_flow.gd` (kayıt + ödül + analitik),
`retention_hooks.gd` (game.gd kancalarının hedefi), `retention_hub.gd` (Home giriş noktası),
`retention_entry_row.gd` (üç ikonlu satır), `retention_store.gd` (Progress sarmalayıcısı).

## 1. Günlük görevler (seviye 5'te açılır)

* Her takvim günü **3 görev**, `retention_missions.json` havuzundan, gün numarasından türeyen sabit
  tohumla çekilir (aynı gün = aynı liste). Ağırlıklı çekim; **aynı gruptan en çok bir** görev
  (ör. "3 yıldız" ve "az askı" aynı gün gelmez). Çekilen liste kayda yazılır.
* Havuz: seviye bitir, sepet doldur, x3 zincir (`max` kipi), 3 yıldızla bitir, en çok 3 askıyla bitir,
  günlük bulmacayı çöz, güçlendirici kullan, kuş kov, kediyi sev.
* **Hedef seviyeyle hafifçe büyür:** `taban + (seviye / 10) * adım`, `tavan`ı geçmez
  (ör. "seviye bitir": 2 → 5).
* **Başka işçilerin özellikleri:** `bird_shooed`, `cat_petted` görevleri `optional`. Olay hiç
  yayınlanmadıysa çekilmez (ölü görev takılmaz); özellik `RetentionEvents.declare_live("bird_shooed")`
  dediğinde ya da olayı ilk yayınladığında havuza girer. Tanınmayan olay hiçbir göreve işlemez.
* Ödül: görev başına 15-30 jeton. Üçü bitince **bonus sandık**: 30 jeton + 1 güçlendirici.
* **Gün devri:** yeni gün ilk açılışta yeni görevler gelir; dünün *tamamlanmış ama alınmamış*
  ödülleri (ve sandık) **otomatik verilir** (oyuncu "kaybettim" hissetmesin). Analitik:
  `ret_mission_autogrant`.

## 2. Ödül yolu (herkese açık)

* Kilometre taşları: **5, 10, 15, 20, 30, 40, 50**, sonra her 10 seviyede bir (her 50'de büyük sandık).
  Tümü veri dosyasında (`list` + `repeat`). "Tamamlanan seviye" = `Progress.level() - 1`.
* Her sandıkta görünür ödül önizlemesi: jeton, güçlendirici ve yuvarlak sayılarda (10, 20, 30...)
  **yıldız paketi** (5 / 8 / 10 / 12 / 20).
* Sayfa: "N seviye kaldı", 5 düğümlü yol (alınmış / alınabilir / sıradaki / kilitli), alınabilir
  sandık nabız atar, alınca yumuşak kıvılcım + yukarı süzülen "+N".
* Birden çok bekleyen sandık "Al" ile sırayla alınır.

## 3. Haftalık çamaşır etkinliği (seviye 10'da açılır)

* ISO hafta (Pazartesi başlar). Tema hafta numarasıyla sırayla döner: Mavi, Zincir, Kırmızı, Sepet,
  Yeşil, Yıldız, Sarı, Mor haftası (8 tema, `retention_weekly.json`).
* 5 kademeli yol. Renk haftalarında sayaç, o renkteki sepetlerin **çamaşır sayısıdır**
  (`basket_completed` -> `data.color`, `data.count`); Zincir haftası zincir halkaları
  (`chain >= 2`), Sepet haftası sepet sayısı, Yıldız haftası kazanılan yıldızdır.
* Kalan gün **yalnız sayfada** görünür (oyun içi geri sayım yok).
* **Hafta devri:** yeni hafta sıfırlanır; alınmamış ulaşılmış kademeler otomatik verilir
  (`ret_weekly_autogrant`) ve sayfa bir kez "geçen haftanın ödülleri verildi" notu gösterir.

## 4. Geri dönüş + oturum serisi

* Son oturum gününden bugüne **≥ 2 gün** geçtiyse (Pazartesi -> Çarşamba = 2) ve seviye ≥ 4 ise
  "Tekrar hoş geldin" sayfası: 2-6 gün **30 + 15·gün jeton + 1 güçlendirici** (60-120 jeton);
  7+ gün **200 jeton + 3 yıldız + 2 güçlendirici**. Açık güçlendirici yoksa (düşük seviye) 40 jeton/adet
  olarak ödenir.
* **Oturum serisi:** art arda günlerde uygulamayı açmak 1..7 döngüsünde sayılır (8. gün yine 1).
  Yalnız **3. gün: +15, 7. gün: +40 jeton** (7 günlük takvimle çakışmaz). Seri küçük alev + sayı
  olarak görev sayfasının başlığında görünür.
* Hediye "bekleyen" olarak saklanır ve tek dokunuşla alınır (uygulama arada kapansa kaybolmaz,
  iki kez verilmez).

### Yerel bildirimler (`notifier.gd`)

`Notifier.schedule(id, saniye, başlık_anahtarı, gövde_anahtarı)` / `Notifier.cancel(id)`.
Masaüstünde no-op (`NoopProvider`, planı bellekte tutar). Android için
`AndroidProvider` **belgelenmiş taslaktır**: `Engine.has_singleton("CamasirIpiLocalNotifications")`
varsa onu çağırır; eklenti beklenen yöntemler `schedule(id, delay_seconds, title, body)` ve
`cancel(id)`. **Eklenti indirilmedi.** İzin (Android 13+ POST_NOTIFICATIONS) eklentinin işidir.
Plan (`notify_plan.gd`, saat enjekte edilir): *günlük hediye hazır* (ertesi yerel sabah 09:00),
*görevlerin bekliyor* (24 sa boşta; sessiz saat 22-08'e denk gelirse 09:00'a kayar),
*haftalık etkinlik yarın bitiyor* (Cumartesi 18:00). Her seviye başı/sonu ve her Home açılışında
aynı kimlikler üzerine yazılarak yeniden kurulur, bu yüzden "24 sa boşta" doğal çalışır.
Bildirim açma/kapama ayarı için Ayarlar sayfasına satır eklemek director'ın işidir
(şimdilik hep açık).

## Olay yolu

`RetentionEvents.emit(event_id: String, amount: int = 1, data: Dictionary = {})`

| Olay | amount | data |
|---|---|---|
| `level_started` | 1 | level, daily |
| `level_won` | 1 | level, stars, rack_total, rack_max, best_chain, boosters_used, daily |
| `basket_completed` | 1 | color (renk kimliği), count (çamaşır), chain (zincir adımı) |
| `daily_won` | 1 | level_won ile aynı |
| `booster_used` | kullanılan sayı | level_won ile aynı |
| `bird_shooed`, `cat_petted` | 1 | (başka işçiler yayınlar) |

Görev/tema tanımındaki `where` (`min`/`max`/`equals`), `amount_key` ve `mode` (`sum`/`max`) ile
yeni olaylar kod değişmeden eşlenir.

## game.gd kancaları (3 satır, `# [RETENTION]`)

```
_start_level  : RetentionHooks.level_started(_level_number, not _daily_level.is_empty())  # [RETENTION]
_show_win     : RetentionHooks.level_won(_level_number, _run_stats, _board, not _daily_level.is_empty())  # [RETENTION]
_play_event   : RetentionHooks.basket_done(event, _basket_items[int(event["basket"])].size())  # [RETENTION]
```

Bilinen sınır: `booster_used` yalnız **kazanılan** seviyede, `RunStats.boosters_used` üzerinden
sayılır (kaybedilen seviyedeki kullanım sayılmaz).

## Director için entegrasyon (home.gd)

```gdscript
# _ready sonunda, giriş satırı (üç ikon + nokta rozeti; konum varsayılan: başlık altı, ortalı)
RetentionHub.build_entry_row(self)
# Home her göründüğünde (en fazla BİR sayfa açar: geri dönüş > ödül yolu > görevler > haftalık)
RetentionHub.on_home_shown(self)
# İsteğe bağlı tek rozet: RetentionHub.badge_count() -> int (alınabilir her şey)
```

Her sayfa tek başına da açılır: `MissionsSheet.open(parent)`, `MilestoneSheet.open(parent)`,
`WeeklySheet.open(parent)`, `ComebackSheet.open(parent)` (hepsi `Node` döner).
Satırdaki rozetler `Progress.changed` ile kendiliğinden tazelenir. Pop-up sıklığı: kilometre taşı
başına bir, görevler günde bir, haftalık kademe başına bir.

## Ekonomi (mevcut gelir: seviye başı ~20-47 jeton; güçlendirici 60-100)

Hepsi **tam katılımla** (her şeyi alan oyuncu) üst sınırdır; JSON'dan ayarlanır.

| Kaynak | Jeton | Yıldız | Güçlendirici |
|---|---|---|---|
| Günlük görevler (3 görev) | ~65-90 / gün | - | - |
| Bonus sandık | 30 / gün | - | 1 / gün (açık değilse +40 jeton) |
| Haftalık etkinlik (5 kademe) | 255 / hafta (~36/gün) | 8 / hafta | 3 / hafta |
| Oturum serisi | 55 / 7 gün (~8/gün) | - | - |
| Ödül yolu (50. seviyeye dek) | 580 toplam (~12/seviye) | 55 | 8 |
| Ödül yolu (60+) | 120 / 10 seviye | 8 | 1 |
| Geri dönüş (nadir) | 60-120 (2-6 gün), 200 (7+) | 0 / 3 | 1 / 2 |

Günlük toplam (görev + sandık + haftalık + seri) ≈ **140-165 jeton + ~1.4 güçlendirici**; günde
10 seviye oynayan oyuncunun ~300-450 jetonluk geliriyle kıyaslanınca ~%35-45, **yalnız her gün her
şeyi alan** oyuncu için. Orta oyuncu (günde ~5 seviye, 2 görev) ≈ 60-90 jeton/gün. Güçlendirici
girişi (maliyet 60-100) oyuncunun harcamasını ikame etmeye başlarsa önce `chest.count`'u 1'den
"her 2 günde bir"e (kod değişmeden: sandık şablonundan `booster` alanını çıkarıp jetona çevirerek),
sonra haftalık 3. ve 5. kademe güçlendiricilerini azaltın.

## İzlenecek analitik olayları (`AnalyticsLog.record`)

| Olay | Anlamı / D1-D7 vekili |
|---|---|
| `ret_sheet_open {kind}` | missions/milestones/weekly/comeback: hangi sayfa ne kadar açılıyor |
| `ret_mission_done {done}` | görev tamamlama hızı (günde kaç görev biter) |
| `ret_mission_claim {id,level,coins}` | **görev alma oranı** = claim / done; hangi görev tipi sevilmiyor |
| `ret_mission_chest` | üç görevi bitirme oranı (günlük bağlılık) |
| `ret_mission_autogrant {coins}` | alınmadan gün geçen ödül (sayfa keşfi düşükse artar) |
| `ret_milestone_claim {milestone,coins,stars}` | **kilometre taşı alımları**; hangi seviyede takılınıyor |
| `ret_weekly_tier_reached {theme,tier}` / `ret_weekly_claim {theme,tier}` | **haftalık kademe dağılımı**, tema başına |
| `ret_weekly_autogrant {coins}` | hafta devrinde alınmayan kademe |
| `ret_comeback_pending {away,streak}` / `ret_comeback_claim {away,streak,coins}` | **geri dönüş hediyesi**: kaç gün sonra dönülüyor; D7+ dönüşü |
| `ret_notify_*` | bildirim sağlayıcı bağlandığında eklenecek (şimdilik no-op) |

Yorum: D1 ≈ ertesi gün `level_start` (var olan olay) ile `ret_mission_*` birlikte; D7 için
`ret_comeback_claim.away` dağılımı ve seri 7'ye ulaşan oyuncu oranı (`ret_comeback_claim.streak = 7`).

## Doğrulama

* Testler: `tests/unit/test_retention_*.gd` (görev, kilometre taşı, haftalık, geri dönüş/bildirim,
  yapıştırıcı katman, metinler).
* Prob: `godot --headless --path . -s res://tools/retention_probe.gd` iki seviyeyi gerçek Game
  sahnesinde oynar; görev ilerlemesi, kilometre taşı alımı, haftalık ilerleme, gün/hafta devri ve
  geri dönüşü enjekte edilen tarihlerle doğrular.
* Ekran görüntüleri: `godot --path . --resolution 1080x1920 -s res://tools/retention_shot.gd -- --shot=missions_progress --lang=tr --out=docs/art/retention_missions_progress_tr.png`
  (`--shot`: missions_fresh/progress/claim/fx, milestones_*, weekly_fresh/progress/claim/chain, comeback, streak, entry, locked).
