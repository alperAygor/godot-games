# Priz — aşamalar

Her aşama çalışan bir yapı bırakır. Durum: [ ] bekliyor, [~] sürüyor, [x] bitti.

## Aşama 1 — çekirdek mantık ve çözücü (arayüzsüz)
- [~] `p1-core` (Opus): seviye verisi, tahta kuralları, gün benzetimi, çözücü, üretici, öğe kayıt
      sistemi, birim testleri, `docs/CORE_API.md`.

## Aşama 2 — tek odalı dikey kesit (nihai kalite) → DUR, göster
- [~] `p2-art` (Opus): Blender hattı, tek oda dioraması, 8 cihaz, dört dilim ışığı, görünüm sahnesi.
- [x] `p2-shell`: şablon altyapısının projeye taşınması (kayıt, dil, ses servisi, arayüz takımı, reklam politikası, rakamsız arayüz, `digit_probe`). Ayrıntı: `DECISIONS.md` "Aşama 2 — kabuk", `docs/ARCHITECTURE.md`.
- [ ] `p2-sfx`: ElevenLabs ile fiş, tık, sigorta, cihaz döngüleri, uğultu, kazanma müziği.
- [x] `p2-slice`: sürükle-bırak, mıknatıs, fiziksel kablo, sigorta kutusu arayüzü, düz kip seviyeleri (7 kesit seviyesi,
      `tools/slice_probe.gd`, `tools/slice_shot.gd`; ayrıntı `DECISIONS.md` "Aşama 2 — dikey kesit").
- [ ] Ekran görüntüsü ve video ile kullanıcıya göster; "rakam yok" kapsamını sor.

## Aşama 3 — gün döngüsü, test, sigorta, kazanma/kaybetme akışı
## Aşama 4 — içerik öğeleri ve 60 seviye
## Aşama 5 — mahalle, yenileme, koleksiyon, günlük seviye
## Aşama 6 — reklam/analitik, performans, Android paketi

## Yeniden başlatıldı (kullanıcı, 2026-11-15)
Proje 2026-11-14'te iptal edilmişti; kullanıcı "kaldığımız yerden komple bitirelim, Google Play'e hazır hâle
getirelim" dedi. Ana dalda: aşama 1 (çekirdek, 60 seviye), kabuk, sesler, görsel hat. Yarım kalan dikey kesit
`_work/p2-slice` çalışma kopyasında commit edilmemiş duruyor (19 dosya) — oradan devam edilecek.
Sıra: dikey kesit (aşama 2) → kullanıcıya göster → aşama 3-6 → Google Play hazırlığı.
Not: sesler ElevenLabs'in ücretsiz planında üretilmişti; yayın öncesi ücretli planla yeniden üretilecek.

