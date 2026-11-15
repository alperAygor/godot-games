# INT — C1 + C2 + C3 entegrasyonu (koşu yapısı × düşmanlar × kartlar)

Dal: `orch/na-int`. Birleştirme (C3) önder tarafından başlatıldı; bu rapor çakışma çözümü + bağlantılar + birleşik ölçümdür.

## 1. Çakışmalar
| Dosya | Çözüm |
|---|---|
| `tests/sim/run_sim.gd` (3) | `VERSION` 3; C1 (`_gate_policy`, `_continue`) ve C3 (kart etkisi durum alanları) değişkenleri birlikte; düşman azami canı tek anahtar `max_hp` (C2 şifacı/can çalma ve C3 infaz aynı anahtarı okur — C3 `max` kullanıyordu, yoksa infaz sessizce kırılırdı), `born` (C2 öldürme süresi) korunur. |
| `tests/sim/sim_model.json` (1) | C2 sabitleri (`shield_front_share`, `charger_hit`, `mine_hit`, `strike_hit`) + C3 `cards`, `scan`, `dash_near` birlikte; geçerli JSON, yinelenen anahtar yok. |
| `tests/sim/sim_report.gd` (1) | C1 mod/sektör denetimleri + C3 kırık kombinasyon denetimi birlikte. Ek: normal dalga hasar payı (`damage_share_normal`, C2) ve ölüm yeri (`deaths`: boss dalgası / normal dalga). |
| `tests/unit/test_i18n.gd` (2) | Tek uygulama: `data/lang/en_*.json` ad sırasıyla, sonraki üstüne yazar (I18n._load_extra_files ile aynı). |

Anlamsal denetim (çakışmasız ama örtüşen): `tools/report.py` C1 sektör tablosu + ölüm yeri + normal dalga hasarı eklendi; `verify.sh` altı probe + taramayı koşturuyor.
Birleşmede bulunan iki hata: (1) `CardEffects.on_hurt` Çelik Gövde iadesi oyuncunun 0'a kırpılmış canına eklendiği için ölümcül vuruşu
diriltmeye çeviriyordu (`player3d.hp_before_hit` ile düzeltildi); (2) `run_probe` İkinci Şans kartı seçildiğinde ölüm adımında takılıyordu
(45 kartlık havuzla bu tohumda seçiliyor; probe diriltme haklarını harcanmış sayar).

## 2. Bağlantılar
1. LANETLİ GÜÇ → gerçek C3 lanetli kartı (`RunState.assign_gate_cards`, `gate_reward_bonus`; kartta ad/etki/bedel/kartın ödülü; `ctx.effects.apply_curse` bir kez; kapının +%15'i yalnız yedekte). Ekran: `docs/screen_int_gate_curse.png`.
2. Elit eşiği/şansı/önek `min_wave` → `run.difficulty_wave(n)` (`EnemyData.elite_chance/prefix_wave`, oyun + sim). Sonsuz mod birebir aynı:
   sim 240 koşu (4 gemi × 3 atölye × 20 tohum) JSON-özdeş; `scene_probe` (artık sabit kare örneklemeli) tohum 7 / 60 sn ve tohum 11 / 150 sn
   (1241 örnek, dalga 10'a kadar) iz dökümleri bayt-özdeş, `trace_md5` iki çalıştırmada aynı. Hızlı mod beklendiği gibi farklı.
3. Sektör tadı: `run.sector_mix` (S1 öğrenme · S2 kalkancı/onarıcı/mayıncı/tank · S3 sıçrayıcı/hücumcu/kuluçka/sürü), kuluçka `sectors` [0,1,2]. Yalnız sektörlü modlarda ve zafere kadar.
4. Kalkancı: gerçek hasar sayısı (küçük mavi) + seyrek "ENGEL"; zırhlı/yorgun hücumcu sayıları da artık gerçek. Ekran: `docs/screen_int_sector2.png`.
5. AŞIRI GERİLİM çarpanları yeni türlere, elit öneklerine, parçalara, yavrulara, mayın/iniş hasarına ve boss'a geçer (hepsi `hp_scale/damage_scale`); sim testi.

## 3. Birleşik ölçüm (60 tohum × 4 gemi = 240 koşu/hücre, rastgele kart politikası, kapı politikası auto)

### Sektör temizleme / zafer
| mod | atölye | S1 / S2 / S3 | zafer | medyan çekirdek | (C1 öncesi zafer) |
|---|---|---|---|---|---|
| standart | boş | 75% / 22% / 17% | **17%** | 103 | 25% (S1 76, S2 32) |
| standart | orta | 97% / 55% / 46% | 46% | 210 | 62% |
| standart | tam | 100% / 68% / 60% | 60% | 300 | 71% |
| hızlı | boş | 79% / 21% / 17% | 17% | 43 | 40% |
| hızlı | orta | 97% / 66% / 58% | 58% | 99 | 71% |
| hızlı | tam | 100% / 85% / 80% | 80% | 117 | 88% |

Ayarsız birleşik oyun (aynı ızgara): standart boş 77/13/7 → zafer **%7**, orta 36, tam 56; hızlı boş 12, orta 50, tam 64.
Sektör karışımı bunun nedeni değil (karışımsız: standart boş zafer %6). Neden: C2 türleri + 45 kartlık havuzun rastgele seçimi seyreltmesi; duvar 2. boss (titan, 10. dalga) — gerçek sahnede de boş atölyeyle ölümlerin %56'sı orada.

### Veri ayarları (en küçük)
- `waves.json → run.modes.standard.wave_scale` 1,0 → **0,85**, `quick.wave_scale` 1,6 → **1,45** (sonsuz mod değişmedi). Taranan: standart 0,9 → %13, 0,85 → %18; hızlı 1,45 → %18.
- `cards.json → vampir` +7 → **+5 can/öldürme** (kırık kombinasyon: tekil vampir IQM oranı 6 tohumda 2,06, 16 tohumda 1,64 > 1,60; +6 ile hâlâ 1,90; +5 ile 6 tohumda en iyi tekil delici 1,58, tarifler 1,56, ikililer 1,29). Sınır yükseltilmedi.

### Ölüm yeri ve hasar payı
Ölümlerin %94–100'ü boss dalgasında (boss + boss dalgasının küçük grubu). Normal dalgada alınan hasar payı (C2 tanımı; tüm modlar):
keskin nişancı 42,1% · hücumcu atılması 18,9% · mayıncı 12,0% · sıçrayıcı inişi 11,6% · nişancı 7,6% · yörüngeci 6,7% · bombacı 0,7%.
(C2 ölçümü sonsuzdaydı: nişancı 19,7, hücumcu 10,4, mayıncı 8,2 — o tablo toplam hasar payıydı; toplamda şimdi nişancı 12,1, hücumcu 7,0, mayıncı 3,8.)

### Kartlar (rastgele politika, 2160 koşu)
Normal havuz (≥100 örnek, İkinci Şans hariç) kazanç aralığı −1,95 (karadelik) … +1,72 (avcı); en zayıflar karadelik −1,95, s_fırtına −1,82,
kalkancarp −1,36, atılma −1,31; en iyiler avcı +1,72, devmermi +1,59, s_hasat +1,58. Evrimler az örnekli (n≈20–75, s.h. 1–2,7).
Sonsuz rastgele ort. dalga 18,2 (C3: 19,0). Atılma tabanlı kartlar hâlâ en altta: bkz. kalibrasyon.

### Kalibrasyon (dash_near)
Gerçek sahneye karşı: `scene_probe` belirlenimli, tohum 1–12 × 4 gemi, sonsuz, boş atölye, otopilot (120 px'te atılma) + rastgele kart, 600 oyun sn.
| | ort. dalga | 1. boss'ta ölüm | 2. boss'ta ölüm | 180 sn'de dalga |
|---|---|---|---|---|
| gerçek (48) | 9,8 | 25% | 56% | 7 |
| sim dash_near 0 (192) | 11,0 | 28% | 49% | 10 |
| sim dash_near 120 (192) | 11,6 | 29% | 45% | 10 |
`dash_near` açmak simi gerçekten uzaklaştırıyor → **kapalı kaldı, yeniden kalibre edilmedi**. Bilinen farklar: sim ~1,4× hızlı ilerliyor;
gemi sırası ters (gerçek: şahin 11,8 > vektör 9,8 > mızrak 9,6 > kasırga 7,9; sim: kasırga 13,6 en iyi, şahin 9,2 en kötü). Gemi başına
temas/isabet kalibrasyonu denge geçişinden önce gerekli (gerçek örnek 12/gemi, gürültülü).

### Ekonomi (3 kariyer/politika, zaferde sonsuza devam)
| kariyer modu | koşu (rastgele / açgözlü) | çekirdek/koşu medyan | oyun süresi |
|---|---|---|---|
| standart | 22 / 19 | 241 / 280 | ~160 dk |
| hızlı | 61 / 63 | 85 / 82 | ~175 dk |
| sonsuz | 28 / 25 | 187 / 212 | ~200 dk |
Hedef 150–250 koşu: hâlâ ~7–10× hızlı (denge geçişi).

## 4. Kapı ve açık kalanlar
- `tools/verify.sh` tam: yeşil (440 sn); simülasyon adımı 301 sn sürdü (sınır 300) → `VERIFY_SIM_TIMEOUT` varsayılanı 480 yapıldı (tarama sınırı 1,60 değişmedi).
- Vampir +5 ile 16 tohumlu tarama tamamlanmadı (yalnız kapının 6 tohumlu taraması: 1,58 / 1,56 / 1,29). +7 ile 16 tohum: tekil 1,64 · tarif 1,53 · ikili 1,13.
- Sim yasaklamayı (banish) modellemez (bot yasaklamaz); `dash_near` kapalı; gemi başına yeniden kalibrasyon yapılmadı.
