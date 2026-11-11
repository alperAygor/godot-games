# PROJECT_SPEC — Mikro-Kurye: Ev İçi Parkur

> **Tek cümle:** Başparmak boyunda bir kurye robotu sürer, sırtındaki sallanan kargoyu masa, tezgâh ve halı gibi devasa ev parkurlarında
> hasarsız teslim eder; kazandığın hurda ve altınla robotunu geliştirirsin.

| Alan | Değer |
|---|---|
| Platform | Android (Play Store), dikey (portrait) |
| Motor | Godot 4.7.2, `gl_compatibility`, GDScript (Unity önerileri Godot karşılıklarıyla uyarlandı, bkz. §10) |
| Çözünürlük | 1080x1920 referans |
| Tür | Hybrid-casual: fizik/beceri + meta gelişim |
| Oturum | 60–90 sn / teslimat, mikro seanslar |
| Kontrol | Tek başparmak: sanal joystick + sağ altta tek aksiyon düğmesi |
| Para modeli | Ücretsiz + ödüllü reklam (IAP sonra) |
| Görsel | Stylized low-poly, doygun renk, okunaklı (Overcooked / Moving Out tarzı); PBR yok |
| Referanslar | Chibi-Robo, It Takes Two (mikro-dünya atmosferi) |

Bu belge oyun tasarımının tek doğru kaynağıdır. Teknik sözleşmeler `ARCHITECTURE.md`'dedir, iş sırası `TASKS.md`'dedir.

---

## 0. Kararlar (varsayılan; kullanıcı değiştirebilir)

| # | Karar | Gerekçe |
|---|---|---|
| K1 | **3D dünya, arkadan-yukarıdan takip kamerası, dikey ekran** | Tek parmak ve alt joystick dikey ekranı varsayar; kargonun yanal sallanması ve ileri-geri savrulması arkadan net okunur. Diğer oyunlarla (Çanta Fiziği, Kablo Düğümü) aynı proje iskeleti. Yan görünüm (2.5D) ve yatay ekran daha okunaklı rampa/atlayış verir ama tek-parmak ve dikey akıştan vazgeçmek demektir. |
| K2 | **Robot + kargo fiziği özel (raycast tabanlı), `VehicleBody3D` değil** | GDD de bunu önerir: mobilde hesap ucuz, "arcade" his, ayarı kolay. |
| K3 | **MVP tek harita: Çalışma Masası.** Mutfak ve Salon sonra. | Fizik hissini kanıtlamadan içerik üretmek israftır. |
| K4 | **Fizik hissi MVP'nin tek riski.** Önce uçtan uca oynanabilir "robot + sallanan kargo + rampa" prototipi, sonra içerik. | Bkz. §11. |
| K5 | **Kargo hasarı kuvvet/ivme tabanlı, saf mantıkla hesaplanır** (`DamageModel`), fizik motoru yalnızca ölçüm verir. | Test edilebilir; denge `data/*.json` ile ayarlanır. |

---

## 1. Temel oynanış ve kontroller

İlk 5 saniyede anlaşılmalı; ustalaşmak fizikle zevkli olmalı.

- **Sürüş:** Ekranın alt kısmındaki sanal joystick (ya da sağa-sola kaydırma) robotu yönlendirir. Joystick yönü = hedef yön; robot kendi hızlanma/dönme eğrisiyle yaklaşır.
- **Kargo sepeti (asıl gerilim):** Robotun sırtındaki sepet gerçek zamanlı fizik uygular (kütle merkezi, eylemsizlik). Hızlanınca kargo arkaya, frenleyince öne, dönüşte dışa savrulur; rampadan atlayınca havada sallanır.
- **Havada denge:** Robot havadayken oyuncu parmağını kaydırarak robotun jiroskopuyla gövdeyi dengeler (sınırlı tork, bataryadan harcamaz).
- **Modül düğmesi:** Sağ altta tek düğme; o an takılı özel donanımı ateşler (Kanca, Mini-Jet/Drone, Vantuz, Paraşüt). Bekleme süresi ve şarjı vardır.
- **Batarya:** Hız ve modüller bataryadan harcar; bitince robot yavaşlar (reklamla anında şarj, §6).

Kabul: yeni oyuncu, öğretici olmadan ilk bölümü 5 sn içinde hareket ettirebilir.

---

## 2. Core loop

```
 SİPARİŞ SEÇ ─► PARKUR + TESLİMAT ─► HASAR HESABI ─► ÖDÜL ─► GELİŞTİR (GARAJ) ─► (tekrar)
```

1. **Sipariş seçimi (üs / şarj istasyonu):** priz yanındaki mini garajda 3 kargo: Kolay (Kalem Pil), Orta (Kırılgan SD Kart), Zor (çalkalanmaması gereken Sıcak Espresso Kapsülü). Zorluk arttıkça ödül artar.
2. **Parkur ve teslimat:** Masanın bir ucundan diğerine dinamik engelleri aşarak ulaş. Kontrol noktaları vardır (revive için).
3. **Hasar hesabı:** Teslimat noktasında kargonun kalan sağlamlığına göre **Altın** (para) ve **Hurda** (geliştirme parçası) kazanılır. Mevcut `RunScoring` (yıldız ve ücret çarpanı) genişletilir, bozulmaz.
4. **Geliştirme:** Kaynakla şasi, tekerlek, batarya, modül.

Oturum 60–90 sn; oyuncu sıkılmadan "bir tur daha" hisseder.

---

## 3. Kargolar (veri güdümlü: `data/cargo.json`)

| Kargo | Zorluk | Özellik | Hasar karakteri |
|---|---|---|---|
| Kalem Pil | Kolay | Sağlam, hafif | Yüksek eşik, düşük hasar; sallanmaya duyarsız |
| SD Kart | Orta | Kırılgan | Düşük eşik; ani çarpma = büyük hasar; yavaş birikimli titreşim hasarı |
| Espresso Kapsülü | Zor | Sıcak sıvı | **Çalkalanma (slosh) hasarı:** sepetin açısal ivmesi sürekli hasar üretir; yumuşak sürüş ödüllendirilir |

Kargo parametreleri: `mass`, `impact_threshold`, `impact_scale`, `slosh_scale`, `reward_gold`, `reward_scrap`, `fragility` (0..1).

---

## 4. Hasar modeli (özet; ayrıntı `ARCHITECTURE.md`)

Hasar = **çarpma** (kargo-sepet/çevre darbe impulsu, eşik üstü) + **çalkalanma** (kargonun açısal ivmesi, kargoya özgü katsayı) + **düşme** (yükseklik farkı).
Çıktı 0..1 sağlamlık kaybı. 1.0 = kırık (teslimat başarısız / revive teklifi). `DamageModel` saf mantıktır; çarpışma ve ivme ölçümleri dışarıdan beslenir.

---

## 5. Harita tasarımı

Dünya statik değildir: evin içindeki yaşam sürer.

| Harita | Dinamik tehlike | Fırsat / kısayol |
|---|---|---|
| **Çalışma Masası (MVP)** | Aniden basılan mekanik klavye tuşları, dönen kasa fanının rüzgârı, yuvarlanan kalemler | Cetveli rampa yap, monitör kablosunda zipline (v2) |
| Mutfak Tezgâhı | Kaygan yağ/kahve lekeleri, sıcak ocak gözleri, aniden çalışan blender sarsıntısı | Ekmek kızartma makinesini mancınık yap |
| Salon Halısı | **Boss:** devriye gezen Robot Süpürge (yaklaşırsa çeker), uyuyan kedinin kuyruk darbeleri | Koltuk minderlerinden zıpla, oyuncak tren rayıyla hız kazan |

Her bölüm: başlangıç, ≥1 kontrol noktası, teslimat bölgesi, düşme sınırı (masadan düşme = kontrol noktasına dönüş ya da revive).

---

## 6. Meta (garaj) — retention (D1–D30)

| Kategori | İçerik |
|---|---|
| Şasi / süspansiyon | Kargonun aldığı sarsıntı hasarını azaltır |
| Tekerlek | Dişli (halıda hızlı), Silikon (ıslak zeminde tutuş), Manyetik/Vantuzlu palet (duvara tırmanma) |
| Sırt modülleri | **Mıknatıs Kanca** (kenardan son anda tutunma), **Mini-Drone Pervanesi** (süzülme; bataryayı hızlı tüketir), **Şok Emici Jel** (kargo düşerse 1 kez kırılmayı önler) |
| Batarya | Menzil / boost süresi |

Para birimleri: **Altın** (satın alma), **Hurda** (parça/geliştirme). Veriler `data/upgrades.json`.

---

## 7. Reklamla kazanç (`AdManager` yerleşimleri; ZORLAMASIZ)

| Yerleşim | Tetik | Not |
|---|---|---|
| **Kargo Sigortası (revive)** | Masadan düşüş/kargo kırığı | "Reklam izle, Drone seni son kontrol noktasına sağlam bırakır." En yüksek dönüşüm. |
| **Altın Kutu** | Rotadan biraz uzakta parlayan kutu; teslim edilirse açmak için ödüllü reklam | Risk/ödül |
| **Deneme Sürüşü** | Garajda kilitli üst donanım parlar: "1 bölüm ücretsiz dene" | Satın alma isteği yaratır |
| **Batarya / Hızlı Tamir** | Ağır kargoda yarı yolda bitiş: anında %100 şarj + 10 sn boost | |
| Native reklam (v2) | Monitör ekranı, dergi kapağı, kargo kutusu üzerinde dinamik görsel | MVP dışı |

Sıklık limitleri `AdManager` içinde, veriler `data/` altında. Reklam SDK çağrısı yalnızca `AdsProvider`'da.

---

## 8. Ses ve his (UA kancaları)

- **ASMR fizik:** tekerleğin klavye tuşuna basarken "klik" sesi, cetvel üstünde sallanan kargo, yumuşak çarpma sesleri. Ses `AudioService` ve `data/sounds.json`.
- **Okunabilir kaos:** kedi patisi, robot süpürge gibi komik anlar klip üretir; tehlikeler önceden işaret verir (adil başarısızlık).
- **Rage-bait deneyimi:** kaçınılabilir ama çekici tehlike (bariz kahve lekesi).

---

## 9. MVP kapsamı

**İçinde:** tek harita (Masa), 3 kargo, robot + sallanan kargo fiziği, sanal joystick + havada denge, hasar ve ödül, 3 tehlike (klavye/fan/kalem), kontrol noktası + revive reklamı, basit garaj (şasi, tekerlek, batarya), Altın/Hurda, kayıt.
**Dışında (sonra):** Mutfak/Salon, Boss süpürge, kanca/drone/vantuz/paraşüt modülleri (MVP'de en fazla 1), native reklam, IAP, çok dil, bulut kayıt.

---

## 10. Teknik uyarlama (Unity önerisi → Godot)

| GDD (Unity) | Bu projede (Godot 4.7) |
|---|---|
| Configurable/Hinge Joint ile kargo | `RigidBody3D` kargo + `Generic6DOFJoint3D` (yaylı, sınırlı) **ya da** kargoyu robotun alt düğümü yapıp yay-sönüm modeliyle (kod) sallamak; prototipte karşılaştırılır (bkz. TASKS Faz 2) |
| Wheel Collider yerine raycast süspansiyon | `RayCast3D`/`PhysicsDirectSpaceState3D.intersect_ray` ile 4 tekerlek süspansiyonu; robot `RigidBody3D` |
| Stylized low-poly | Düz renkli `StandardMaterial3D`/çok basit shader; `gl_compatibility`; yüksek çokgen yok (GLB sözleşmesi: `validate_glb.py`) |
| 60 FPS orta segment Android | Fizik 60 Hz sabit; aynı karede ağır allocation yok; çarpma olayları sınırlı |

---

## 11. Riskler

1. **Fizik hissi (en büyük risk).** Sepet sallanması çok sert/çok yumuşak olabilir. Çözüm: erken prototip, tüm sabitler `data/balance.json`'da, oyuncu denemesi.
2. **Eklem kararsızlığı** (jitter, patlama). Çözüm: sabit adım, sönüm, açısal limit; saf yay-sönüm yedek planı.
3. **Mobil performans.** Çözüm: raycast sayısı sınırlı, basit çarpışma şekilleri, `perf_probe` ölçümü.
4. **Adalet algısı.** Tehlikeler işaretli olmalı; hata oyuncunun, şansın değil.

---

## 12. Açık sorular (kullanıcı kararı bekliyor)

1. K1 kamera/ekran yönü onaylanıyor mu (3D, arkadan-yukarıdan, dikey)?
2. Ekonomi: Altın ve Hurda ayrımı MVP'de gerekli mi, yoksa tek para birimiyle mi başlayalım?
3. Oyun adı sabit mi ("Mikro-Kurye"), yoksa mağaza adı İngilizce mi olacak?
4. Hangi tek modül MVP'ye girsin (Kanca mı, Şok Jeli mi, Drone mu)?
