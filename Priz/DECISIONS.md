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

## Ertelenenler

- Gerçek cihazda performans ölçümü (aşama 6; o zamana dek masaüstü ölçümleri yalnız oran verir).
- Gerçek reklam SDK'sı (sahte servisle çalışılır; AdMob aşama 6).
