# Priz — kararlar, varsayımlar, ertelenenler

Her aşamada buraya eklenir. Biçim: tarih, karar, neden, geri dönüş yolu.

## Aşama 0 (2026-11-14) — kuruluş

- **Motor ve çizici:** Godot 4.7.2, gerçek 3B, **Mobile** çizici. Neden: tasarım alan derinliği, parlama
  ve yumuşak gölge istiyor; Compatibility çizicide alan derinliği yok. Risk: orta sınıf Android'de 60 FPS.
  Geri dönüş: kalite kademeleri (alan derinliği ve parlama kapatılabilir, gölge çözünürlüğü düşer).
- **Varlıklar:** tümü Blender 5.2 betikleriyle üretilir (`tools/blender/`), GLB olarak dışa aktarılır.
  Dışarıdan model ya da doku indirilmez. Sesler ElevenLabs ile.
- **Ekran:** dikey 1080x1920; diorama ekranın üst ~2/3'ünde, cihaz tepsisi ve sigorta kutusu başparmak
  bölgesinde.
- **"Rakam yok" kuralının kapsamı (AÇIK SORU):** oyun ekranında kesin olarak uygulanır. Meta ekranlardaki
  jeton bakiyesi ve fiyatların nasıl gösterileceği aşama 5'e ertelendi; o zamana dek varsayım: jeton da
  görsel yığın/kese olarak gösterilir, sayı yazılmaz. Kullanıcıya dikey kesit gösterilirken sorulacak.
- **Seviye 1-14 ("düz" kip):** gün döngüsü yok, tüm cihazlar aynı anda çalışır, sigorta hakkı yok; hattı
  taşıracak cihaz prize oturmaz (geri sektirilir). Seviye, tüm cihazlar takılınca kazanılır.
- **Seviye 15+ ("gün" kipi):** planlamada taşma engellenmez; oyuncu "Günü başlat"a basar, dilimler
  sırayla oynar. İlk taşan dilimde sigorta atar, bir hak gider, plana dönülür (plan korunur).
  Kazanmak için tüm cihazların takılı olması gerekir (aksi hâlde "Günü başlat" etkin olmaz).
- **Çoklu priz (seviye 10):** tek bir priz noktasına birden çok cihaz takılabilen uzatma; hepsi aynı hatta
  yük bindirir.
- **Oda kısıtı (seviye 6):** cihaz yalnız kendi odasındaki prizlere takılabilir.
- **Zor seviye:** her 5. seviye (5, 10, 15, ...) zordur; çözüm sayısı hedefi daha düşüktür, ödül fazladır.
- **Şablon:** oyundan bağımsız altyapı (kayıt, reklam, dil, arayüz takımı) `studio-kit/template-mobile`
  hazır olunca aşama 2-3'te projeye taşınır; çekirdek ve görsel işler bunu beklemez.

## Aşama 2 — kabuk (p2-shell)

Şablon (`studio-kit/template-mobile`) projeye taşındı; Priz kurallarına uyarlandı. Varsayımlar:

- **Yerleşim:** şablonun genel çekirdek yardımcıları `scripts/shell/` altında (oyun kuralları `scripts/core/` ile çakışmasın);
  testleri `tests/unit/test_shell_*.gd`. `tests/run_tests.gd` şablonunki alındı (Priz'dekinin üst kümesi: `Progress.persist=false`
  koruması ekli); `test_case.gd` aynıydı; `test_smoke.gd` korundu. `tools/verify.sh` şablonunkiyle DEĞİŞTİRİLDİ (+ `digit_probe`).
- **Rakam yok (kabuk):** seviye numarası, jeton sayısı, süre, "2×" yok. Jeton = `UiChip` içinde jeton SİMGELERİ (her 10 jeton = 1 simge,
  en çok 5, 100 ve üstünde "yığın" simgesi; `balance.json coin_display`). Seviye = 5'li bloklarda noktalar (4 normal + zor seviye
  yıldız noktası). Yıldız ve sigorta hakkı da nokta. Ana düğme "Oyna". Bu geçici bir görünümdür; sayısız ilke aynı kalarak yeniden
  biçimlenecek. Bekleyen AÇIK SORU (meta ekranlarda fiyat/bakiye gösterimi) hâlâ aşama 5/kullanıcıya.
  Koruma: `test_shell_no_digits` + `tools/digit_probe.gd` (Home, Game, tüm sayfalar, 3 dil), `verify.sh`'a bağlı.
- **Geçiş reklamı yorumu:** "seviye 5'ten sonra" = 5. seviye BİTİNCE (tamamlanan seviye ≥ 5) ilk geçiş reklamı olabilir. "2-3 seviyede bir"
  = belirlenimci döngü 2,3,2,3 (reklamlar 5, 7, 10, 12, 15 ...), rastgele değil (tekrarlanabilir test için). Aralık ve eşikler
  `data/ads.json`'dadır. 90 sn koşulu gerçek saat (unix) ile; ödüllü izlenen geçişte reklam atlanır ve bir SONRAKİ geçişte uygun kalır.
- **Sessiz dönem:** ilk 3 seviyede (oynanan seviye ≤ 3) reklam yok, ödüllü düğme sunulmaz, banner yok, mağaza/açılır pencere de
  olmamalı (`Progress.is_quiet_period()` tek soru; mağaza ve pencereler henüz yok, ileride bunu sorar).
- **Banner:** politika veri güdümlü (`ads.json banner.screens`: `neighbourhood`, `collection`); mock yalnız kaydeder. Gerçek AdMob
  banner'ı aşama 6. Ana ekran = mahalle ekranı sayıldı.
- **Sigorta hakkı:** seviye başına, kaydedilmez (`Progress.begin_level_fuses`, varsayılan `balance.json fuses_per_level` = 3).
  Düz kipte (seviye 1-14) sigorta yok; kullanılıp kullanılmayacağına oyun sahnesi karar verir. Yer tutucu oyun hakları kullanır.
- **Kalite kademesi:** kayıtta `quality_tier` (high/medium/low) var; ayarlar sayfasında seçici YOK (art/performans işi kademeyi
  tanımlayınca eklenir). Dil ayarı `Loc`un `settings.language` modülünde kaldı.
- **Titreşim:** `Haptics.tick/thud/success` (süreler `balance.json haptics`); masaüstünde ve ayar kapalıyken no-op.
- **Paket kimliği:** `com.priz.game` / `com.priz.game.test`, ad "Priz" (yer tutucu; yayın öncesi kesinleştirilir).
- **Şablon varsayılanları kaldırıldı:** 4. seviyeden her geçişte geçiş reklamı, "kayıpta devam" (artık `extra_fuse`), `first_level`.
- **Ertelenen:** AdMob banner uygulaması, kalite seçici arayüzü, `collection` ekranı (yalnız politika kimliği), arayüzün diorama dünyasına
  (sigorta kutusu/şalter) uyarlanması, `strings.csv` yeni dil/sözlük genişlemeleri.

## Ertelenenler

- Gerçek cihazda performans ölçümü (aşama 6; o zamana dek masaüstü ölçümleri yalnız oran verir).
- Gerçek reklam SDK'sı (sahte servisle çalışılır; AdMob aşama 6).
