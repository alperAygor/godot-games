# TASKS — Çanta Fiziği

| Bölüm | Durum |
|---|---|
| v1.0.0 dikey dilim (oynanabilir oyun) | ✅ Tamam |
| **Faz 1 — Sağlamlaştırma** | ✅ **Tamam** |
| Faz 2 — Oyun kabuğu | ⬜ Sırada |
| Faz 3–8 | ⬜ Bekliyor |

---

## Tamamlanan — v1.0.0 dikey dilim

Oyun baştan sona oynanıyor: paketle → sarsıntılı teslimat → kırılma/erime →
ödüllü kurtarma. Ayrıntılı kayıt `CHANGELOG.md`'de.

| Alan | Ne var |
|---|---|
| Proje | `gl_compatibility`, 1080x1920 portrait, dokunmatik, 60 Hz, statik tip hataları açık |
| Sahneler | `Main.tscn`, `BackpackGrid.tscn`, `HUD.tscn` |
| Autoload | `GameManager`, `AudioService`, `AdManager` |
| Oynanış | 4x5 ızgara, sürükle-bırak, squash & stretch, hücre parıltısı |
| Fizik | 5 sn sinüs sarsıntısı, cam kırılması, buz erimesi + komşu etkisi |
| Ses | ElevenLabs ile 4 SFX (drop / cam / buz / başarı) |
| Reklam | "Ekstra Cep Aç" (4x5→5x5), "Paketi Bandıyla Kurtar" (revive) |
| Görsel | Bloom, SSAO, sıcak renk düzeltme shader'ı, stylized ışıklar |

---

## Faz 1 — Sağlamlaştırma ✅

**Hedef:** Yeni özellik eklemeden önce mevcut dilimi kilitle.

- [x] `tests/test_case.gd` — assert tabanı (`assert_true/eq/almost_eq/greater/not_null`)
- [x] `tests/run_tests.gd` — koşucu; çıkış kodu 0/1/2, `--filter=` desteği
- [x] `tests/unit/test_package_physics.gd` — 9 test: cam eşiği, kırılma sonrası stres kilidi, buz erimesi, sarsıntının erimeyi hızlandırması, komşu stresi, onarım
- [x] `tests/unit/test_shake.gd` — 6 test: süre, şiddet aralığı, zarf rampası, eve dönüş, stop/resume ilerleme koruması
- [x] `tests/unit/test_ad_limits.gd` — 6 test: limitler, idempotent ödül, yerleşim bağımsızlığı, tur sıfırlama
- [x] `tests/unit/test_grid.gd` — 7 test: footprint taşması, doluluk, genişlemenin hücre kaydırmaması, yeni sütuna yerleştirme
- [x] `tools/verify.sh` — içe aktarma + açılış dumanı + testler, `SCRIPT ERROR` taraması
- [x] Tohumsuz rastgelelik kaldırıldı (`GridController._nudge`, `AudioService` pitch) — `RandomNumberGenerator`, sabit tohum
- [x] Denge sayıları `data/packages.json`'a taşındı + `GameData` autoload'u
- [x] **Bulunan gerçek hata:** `melt_seconds` "tam erime süresi" diye belgelenmişti ama formül 2 katını veriyordu; formül belgeye uyduruldu

**Bitti kriteri:** `tools/verify.sh` 0 döner; 27 test / 78 doğrulama geçer; `.gd` dosyalarında çıplak `randf_range` kalmaz. ✅
**Doğrulama:** `tools/verify.sh` → `SONUÇ: geçti`, 27 test, 0 başarısız.

---

## Faz 2 — Oyun kabuğu

**Hedef:** Uygulama doğrudan oyuna açılmasın; tur döngüsü kapansın.

- [ ] `scenes/boot.tscn` — logo, 0.4 sn, menüye geçiş
- [ ] `scenes/menu.tscn` — Oyna / Yükselt / Ayarlar
- [ ] `scenes/result.tscn` — yıldızlar, paket bazında hasar raporu, ödül
- [ ] `scripts/core/scoring.gd` — hasar → yıldız + ücret (`PROJECT_SPEC.md` §2 tablosu) + test
- [ ] `GameManager.goto_scene()` — sahne geçişi tek yerden
- [ ] Android geri tuşu: popup kapatır, menüde çıkış onayı

**Bitti kriteri:** boot → menü → oyun → sonuç → menü tam turu; her adımda geri tuşu doğru; yıldız hesabı testle sabit.

---

## Faz 3 — Kalıcılık ve ekonomi

- [ ] `scripts/core/player_profile.gd` — şema v1 + `_migrate()`
- [ ] `GameManager.save()/load()` — atomik yazma, bozuk dosya kurtarma
- [ ] Odak kaybında otomatik kayıt
- [ ] `scripts/core/economy.gd` — para, itibar
- [ ] `data/upgrades.json` + yükseltme ekranı (kapasite, bant stoğu, kasko)
- [ ] Testler: round-trip, bozuk JSON, migrasyon

**Bitti kriteri:** Kapatıp açınca para/yükseltme/ayarlar korunur; bozuk kayıt oyunu kilitlemez.

---

## Faz 4 — Karar noktası: gerçek fizik

**4A — `RigidBody3D`'ye geç:** paketler fizik gövdesi, çanta içi 6 `StaticBody3D` duvar,
sürükleme `freeze` ile, hasar temas impulsundan, 12 gövde için performans bütçesi.
Ayrı dalda çalışmalı; snap/squash mantığı yeniden yazılır.

**4B — Mevcut stres modeliyle devam:** daha hızlı yayın, ama "fizik komedisi" vaadi zayıf.

**Bitti kriteri:** Seçilen yol `ARCHITECTURE.md` karar kaydına yazılır; Faz 1 testleri yeni modelde de geçer.

---

## Faz 5 — Oynanış derinliği

- [ ] Sürükleme sırasında 90° döndürme (2x2 kasa bir yöne sığmaz)
- [ ] Bant/köpük: kırılgan camın eşiğini yükseltir, stok tüketir
- [ ] Eriyen buzun komşu etkisini mekanikleştir (kaygan hücre)
- [ ] HUD'da ağırlık merkezi / inklinometre
- [ ] Testler: döndürmeden 2x2 sığmaz, bantlı cam bir turu atlatır

**Bitti kriteri:** Tur, yalnızca paket seçimiyle değil yön ve bant kararıyla kazanılır.

---

## Faz 6 — Sürüş fazı

- [ ] `truck_01.glb` + 3 yol segmenti (düz / tümsekli / virajlı)
- [ ] `truck.gd` — gaz/fren/şerit, tümsek teması → sarsıntı girdisi
- [ ] `ShakeSimulator` sabit sinüs yerine fiziksel olayla beslenir
- [ ] `road.gd` — segment havuzu
- [ ] Kamera takip ritmi + sarsıntı azaltma ayarı

**Bitti kriteri:** Turun tamamı (paketle → sür → teslim) oynanır; hızlı tümsek geçişi ölçülebilir hasar verir.

---

## Faz 7 — Yayın hattı

- [ ] `export_presets.cfg` — `com.alperaygor.cantafizigi`, minSdk 24, targetSdk 36
- [ ] Debug APK → emülatör → gerçek cihazda fizik/perf
- [ ] Gizlilik politikası, veri güvenliği formu, yaş derecelendirmesi
- [ ] Gerçek `AdMobProvider` (`AdsProvider` arayüzü sayesinde tek dosya)
- [ ] Internal → closed testing

**Bitti kriteri:** APK cihazda 10 dakika çökmeden oynanır; crash-free ≥ %99.

---

## Faz 8 — Cila

- [ ] `assets/translations/strings.csv` TR/EN + `locale/translations`
- [ ] Müzik döngüsü (`Music` bus'ı hazır, parça yok)
- [ ] Haptik + kamera sarsıntısı azaltma seçeneği
- [ ] Güvenli alan (çentik) — HUD şu an sabit offset kullanıyor
- [ ] Dokunma hedefi ≥ 88 px denetimi

**Bitti kriteri:** Ekranda sabit metin kalmaz; müzik geçişinde pop yok; çentikli cihazda buton kesilmez.

---

## Bilinçli olarak yapılmayanlar

IAP, gerçek AdMob SDK'sı, Play Console yayını ve cihaz üstü performans ölçümü bu
makinede mümkün değil (hesap/imzalama/cihaz kullanıcıya ait). Ayrıca `scripts/core/`
katmanı ilk fazlarda boş bırakıldı; Faz 2–3 ile birlikte saf mantık oraya taşınacak.
