# Düşmanlar (C2) — 6 yeni davranış + 4 elit ön eki

Veri: `data/balance/enemies.json` · davranış: `scripts/entities3d/enemy3d.gd` (durum makinesi) + `scripts/game/spawner.gd` (dünyaya dokunan eylemler)
· saf kurallar: `scripts/game/enemy_data.gd` · prob: `tools/dev/enemy_probe.gd` (kapıda) · performans: `tools/dev/enemy_perf_probe.gd`
· İngilizce metinler: `data/lang/en_c2.json`.

## Yeni türler

| Tür | Ne yapar | Uyarı (telegraf) | Oyuncunun cevabı |
|---|---|---|---|
| `charger` HÜCUMCU (sarı) | oyuncuya yaklaşır; menzile girince durur, yerde **uyarı çizgisi** çizer, yönü kilitler, hızla atılır, sonra yorulur | 0,9 sn çizgi (genişleyerek dolar); uyarıda ve yorgunlukta temas hasarı **yok** | çizgiden yana çık; yorgunken (×1,5 hasar alır) vur |
| `shielder` KALKANCI (mavi) | yavaş yaklaşır; önünde kavisli kalkan, kalkan oyuncuya **yavaş** döner (1,4 rad/sn) | kalkan modelde fiziksel olarak görünür; engellenen vuruşta mavi parlama | yandan/arkadan vur (önden %12 hasar); nova/raylı top (≥40 hasar) ve zincir şimşeği kalkanı deler |
| `medic` ONARICI (yeşil) | uzaktan durur; yaralı müttefik yakındaysa **yeşil halka** şarj eder, sonra menzildeki müttefiklerin canını %45 doldurur | 0,85 sn genişleyen halka; yaralı yoksa şarj hiç başlamaz | öncelikli hedef: zayıf (30 can), önce onu vur |
| `minelayer` MAYINCI (macenta) | oyuncunun çevresinde döner; 3,2 sn'de bir oyuncunun gideceği yere + yakınına 2 gecikmeli mayın bırakır | 1,3 sn dolan kırmızı daire (boss yer tehlikesiyle aynı sistem; otopilot de kaçınır) | daireden çık; hasar yalnız süre dolunca ve daire içindeyse |
| `blinker` SIÇRAYICI (beyaz) | 4,6 sn'de bir kaybolur, oyuncunun 120 px yanına iner, iniş noktasında yer halkası patlatır | 0,7 sn kaybolma (küçülen halka) + 0,9 sn iniş halkası | halkadan çık (atılma ile de olur); iniş yeri öngörülür |
| `brooder` KULUÇKA (turuncu) | uzak durur, 3,8 sn'de bir şişer ve 2 `swarmer` yavrular (en çok 4 kez) | 0,9 sn şişme + genişleyen halka | yavrulamadan önce vur; yavrular kalabalık baskısı yaratır |

Tüm uyarılar ≥ 0,6 sn (`EnemyData.MIN_WARNING`; veri doğrulaması bunu zorlar).

## Elit ön ekleri (`elite.prefixes`)

Elit olma şansı ve dalga ölçeği eskisi gibi (`elite.chance*`); elit olunca uygun bir ön ek ağırlıklı seçilir (`EnemyData.pick_prefix`).
İşaret: ön ek renginde yer halkası + gövde parıltısı + doğarken "ELİT DÜŞMAN · ÖNEK" bildirimi. Ödül: `points_mult` (zırhlı ×5, çevik ×3, bölünen ×4, emici ×4), her elit garantili ganimet düşürür, emici ek bir ganimet daha.

| Ön ek | min dalga | Etki | Cevap |
|---|---|---|---|
| ZIRHLI `armored` | 4 | can ×2,4, gelen hasar ×0,5, yavaş | ağır vuruş / zincir / patlama |
| ÇEVİK `swift` | 4 | hız ×1,55, can ×1,8 | kısa mesafe kontrolü, atılma |
| BÖLÜNEN `splitting` | 8 | ölünce 2 küçük parça (can %45, tekrar bölünmez) | alan hasarı; parçaları kovalama |
| EMİCİ `vampiric` | 10 | yakın dövüşçüler (chaser/charger/tank/shielder) temas vuruşunda maks canın %25'ini geri alır | temasa girmeden öldür |

## Zamanlama verisi (C1 için)

Dalga tabloları değişmeden çalışır: `RunState.unlocked_kinds/_pick` zaten `enemies.json` içindeki **`unlock`** (ilk dalga) ve **`weight`**
(ağırlık) alanlarını okur. Yeni türler 4–13. dalgalar arasında kademeli açılır (1–3. dalga değişmedi).
Spawner doğma anında ek olarak (hepsi veri; `EnemyData.resolve_kind`, kural çiğnenirse `fallback` türü doğar):

| Alan | Anlamı |
|---|---|
| `sectors` | türün görüneceği harita sırası listesi (`map_index % harita sayısı`); boş = her yerde |
| `max_alive` | aynı anda canlı en çok bu kadar |
| `fallback` | kural çiğnenince yerine doğacak tür |
| `threat` | tehdit puanı (bilgi amaçlı; dalga planlayıcı bütçe tutmak isterse kullanabilir) |
| `name`, `hint` | oyuncuya görünen ad ve ilk görünümde bir kez çıkan ipucu (Türkçe anahtar; İngilizcesi `en_c2.json`) |

C1 isterse: tür başına `unlock`/`weight`'i değiştirmek yeterlidir; sektör başına farklı karışım için `sectors`; boss dalgalarında zaten
elit yok (`Spawner.spawn_enemy`). `RunState.plan_wave` elit ön eki ya da `fallback` bilmez — hepsi doğma anında çözülür, dolayısıyla
plan listesi (`pending`) değişmez.

## Bilinen sınırlar

- Düşmanlar havuzlanmaz (mevcut tasarım: doğur / `queue_free`); probe "havuza dönüş"ü liste çıkışı + düğümün serbest kalması olarak sınar.
- Mayın ve sıçrayıcı iniş bölgeleri boss'un `ctx.hazards` sistemini kullanır: patlama efekti/sarsıntı boss yer tehlikesiyle aynıdır (`BossEvents.tick_hazards`).
- (Entegrasyonda giderildi) Kalkanın engellediği vuruşta artık gerçek hasar sayısı (küçük, mavi) + seyrek "ENGEL" işareti gösterilir
  (`enemy3d.take_damage` verilen hasarı döner; `Feedback.enemy_damage_number`).
- Entegrasyon: elit eşiği/şansı/önek `min_wave` artık `run.difficulty_wave(n)` ile (hızlı mod); sektör karışımı `run.sector_mix`
  (waves.json) S2/S3'e kendi türlerini verir; kuluçka `sectors` [0,1,2].
