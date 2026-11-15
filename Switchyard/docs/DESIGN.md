# Switchyard — tasarım (lider belgesi)

Çalışma adı ve yayın adı adayı: **Switchyard** (mağaza: "Switchyard: Train Puzzle"). Mobil (Android), dikey, Godot 4.7.
Tür: manevra sahası bulmacası. Oyuncu tek bir lokomotifi sürer; vagonları iter, çeker, ayırır ve her vagonu kendi
işaretli yerine bırakır. Kural ilk seviyede okumadan anlaşılır; zorluk hat uzunluklarından, makas yönlerinden ve
"nereden ayıracağım" kararından gelir.

Kullanıcının istediği (2026-11-15): **gerçekten zorlaşan** bir oyun ("zorlanmalıyız"), seviyeler iyi olmalı, ajanlar
oyunu test etmeli. Snip & Ship'in zayıflığı: seviyede 1-4 karar, zorluk ölçülemiyordu. Burada her şey ayrık ve
belirlenimci: her seviye çözücüyle taranır, zorluk SAYIYLA ölçülür ve seviyeler ölçüme göre sıralanır.

## 1. Model

Saha bir **hücre çizgesidir**. Her hücre en çok bir araç taşır. Her hücrenin iki **yanı** vardır: `a` ve `b`.
Her yanın 0, 1 ya da 2 komşusu olur:
- 0 komşu: hat sonu (tampon).
- 1 komşu: düz hat.
- 2 komşu: **makas** (o yan dallanır; öbür yan makasın gövdesidir).

Araç bir hücreden geçerken bir yanından girer, öbür yanından çıkar (yerinde dönemez, keskin dönemez).
Komşuluk simetriktir: p, q'yu bir yanında sayıyorsa q da p'yi bir yanında sayar.

**Araçlar:** bir lokomotif (`loco`) ve vagonlar (`wagon`, renk + simge). Her araç bir hücre kaplar.
**Bağlar (kanca):** komşu hücrelerdeki iki araç arasında bağ olabilir. Bir aracın her yanında en çok bir bağ olur;
yani bağlı araçlar hep bir **dizi** (zincir) oluşturur, ağaç olmaz. Lokomotifin bağlı olduğu diziye **katar** denir.
Lokomotifsiz diziler kendiliğinden hareket etmez.

**Hedefler:** bazı hücreler işaretlidir (renk + simge; lokomotif için ayrı işaret olabilir). Bütün hedef
hücrelerinde eşleşen araç **dururken** seviye çözülür.

## 2. Hamleler

Oyuncunun iki eylemi vardır.

**Sürüş.** Lokomotifi bir yöne sürükler: lokomotifin `a` ya da `b` yanına doğru. Katar o yönde birer hücre ilerler
(yılan gibi: baştaki araç sıradaki hücreye girer, her araç öndekinin eski hücresine geçer). Adım kuralları:
1. Katarın o yöndeki ucundaki araç **baş**tır. Başın serbest yanındaki komşu hedef hücredir. Serbest yan dallanıyorsa
   (baş bir makasın dal tarafına bakıyor) oyuncu dalı seçer.
2. Hedef hücre boşsa katar bir hücre ilerler.
3. Hedef hücrede bir araç varsa: o araç başa **bağlanır** (kendiliğinden kanca) ve onun dizisi katara katılır; aynı
   adım yeni başla yeniden denenir. Yani öndeki her şey itilir ve bağlanır.
4. Hedef yoksa (tampon), ya da hedefteki araç katarın kendisiyse (halka hatta kuyruğunu ısırma) adım yapılmaz.
5. Çekerken yalnız bağlı araçlar gelir; bağsız komşu yerinde kalır.

**Ayırma.** Oyuncu iki bağlı aracın arasındaki kancaya dokunur; bağ kalkar. Araçlar yerinde kalır. Aynı ikili yeniden
ancak itilerek (kural 3) bağlanır.

**Sayım.** Bir **hamle** = aynı yönde kesintisiz sürüş (kaç hücre olursa olsun). Yön değişince ya da araya ayırma
girince sonraki sürüş yeni hamledir. Ayırma hamle sayılmaz. Seviyenin **par**ı çözücünün bulduğu en az hamle sayısıdır.
Yıldız: çözmek 1; `par x 1,5` içinde 2; par (ya da par+1; denge verisi) içinde 3.

Geri al sınırsız ve ücretsizdir (zor bulmacada dürüstlük şartı). Baştan başlat anındadır.

## 3. Zorluk nereden gelir

- Kör hatların uzunluğu (kaç araç sığar), çekme hattının (makasın gövde tarafı) uzunluğu.
- Lokomotif vagonların yalnız bir ucuna ulaşabilir; öbür uca geçmek için dolaşma hattı gerekir ya da yoktur.
- Sıra: hedefler vagonların sırasını dayatır; araya giren vagonu başka hatta park etmek gerekir.
- Mekanikler (dünya dünya eklenir; bkz. §6).

Hamlelerin çoğu geri alınabilir (it, sonra çek), bu yüzden zorluk "geri dönüşsüz tuzak"tan değil **plan derinliğinden**
gelir (kayar bulmaca ailesi). Ölçütler (her seviye için hesaplanır, `data/levels/*.json` içinde saklanır):
- `par`: en az hamle; `min_cells`: o çözümdeki hücre adımı.
- `states`: erişilebilir durum sayısı; `depth_hist`: hedefe uzaklık dağılımı.
- `detours`: en iyi çözümde bir vagonun hedefinden UZAKLAŞTIĞI hamle sayısı (sezgiye aykırılık).
- `solutions_at_par`: par uzunluğundaki farklı çözüm sayısı (az = dar kapı).
- Ajan oyun testi sonucu (bkz. §7).

Seviye sırası bu ölçütlerle kurulur; her dünyada eğri yükselir, yeni mekanik gelince bir-iki seviye nefes verilir.

## 4. Seviye üretimi

Elle çizilen saha şablonları + üreteç. Hamleler büyük oranda tersinir olduğu için üreteç **çözülmüş durumdan geriye**
bütün durum çizgesini tarar ve hedefe EN UZAK başlangıçları bulur: bir saha için kanıtlanabilir en zor dizilişler.
Sonra ölçütlere göre seçilir, elle gözden geçirilir. Çözülemeyen seviye yayına girmez: her seviye dosyası çözümünü
taşır ve oyunun kendi kural sınıfı testte o çözümü yeniden oynatır.

Çözücü ve üreteç Python'dadır (`tools/yard/`, yalnız standart kitaplık; hız için). Oyunun kuralları GDScript'tedir.
İkisi aynı kuralları uygular; ayrışmayı **uygunluk vektörleri** önler: Python `tests/data/yard_vectors.json` üretir
(durum + eylem → beklenen durum), GDScript testi hepsini doğrular; ayrıca her seviyenin çözümü GDScript'te oynatılır.

## 5. Para kazanma (kullanıcı kararı, 2026-11-15)

| Yerleşim | Tür | Kural |
|---|---|---|
| İpucu | ödüllü reklam | Her ipucu bir reklam. İpucu sıradaki doğru hamleyi sahada gösterir |
| Seviyeyi atla | ödüllü reklam | Reklam biterse seviye "atlandı" sayılır, sıradaki açılır (yıldız yok) |
| Geçiş reklamı | interstitial | İlk 3 seviyede yok; sonra her 3 seviye bitişinde bir (yalnız seviye arasında, oyun sırasında asla) |
| Reklamları kaldır | ücretli (tek seferlik) | Geçiş reklamlarını kapatır; ipucu ve atlama ödüllü kalır |

Jeton ekonomisi yok. Sayılar `data/ads.json` içinde. Reklam hazır değilse/çevrimdışıysa düğme nedenini söyler, takılmaz.
İlk 3 seviyede ipucu/atlama düğmesi de görünmez (öğrenme seviyeleri kısa).
Yorum notu: kullanıcı "2-3 leveldan sonra geçiş reklamı" dedi; "ilk 3 seviyeden sonra başlar, sonra her 3 seviyede bir"
olarak uygulandı (ikisi de veri: `first_level`, `every_n`).

## 6. Mekanik yol haritası

Çekirdek (dünya 1): düz hat, makas, kör hat, hedef, ayırma.
Adaylar (çekirdek işçisi çözücüyle dener, en derin bulmaca verenleri önerir; ilk kilometre taşına 3 tanesi girer):
- **Çekiş gücü:** lokomotif en çok N araç hareket ettirir.
- **Yaylı makas:** dal tarafından gelince hep aynı dala verir (tek yönlü geçiş).
- **Döner köprü:** tek araç alır, çevrilince başka hatlara bağlanır.
- **Kapı + basınç plakası:** bir araç plakada dururken kapı açık.
- **Kırılgan vagon:** itilemez, yalnız çekilir.
- **Zıt vagonlar:** iki belirli vagon yan yana duramaz.
- **Yükleme:** vagon hedefe gitmeden önce vinç hücresine uğramalı.
- **İkinci lokomotif:** dokunarak etkin lokomotif değişir.
- **Makaslı kesişme (çapraz):** iki hat bir hücreyi paylaşır.

## 7. Test (kullanıcı şartı: "ajanlar oyunları test etsin")

1. **Çözücü kanıtı:** her seviye çözülebilir, par doğru, ölçütler kayıtlı.
2. **Kör oyun testi:** oyun testi ajanları seviyeleri ÇÖZÜMÜ GÖRMEDEN metin arayüzünden oynar
   (`python3 tools/yard/cli.py`; çözümsüz kopya `build/playtest/levels/`). Kayıt: çözdü mü, kaç hamle, kaç deneme,
   nerede takıldı, kural kafa karıştırdı mı. Sınır: dil modeli uzamsal bulmacada insandan farklı zorlanır; bu test
   sıralama sinyali ve "bozuk/saçma seviye" yakalayıcıdır, insan zorluğunun kanıtı değildir.
3. **Gerçek oyun probu:** başsız Godot, seviyeyi gerçek girdi yolundan (sürükleme, dokunma) çözümle oynatır:
   kazanma algısı, sayaç, sonuç sayfası, reklam akışı (sahte sağlayıcı).
4. **Görsel denetim:** ekran görüntüleri (her dünya, küçük/büyük saha) bir ajan ve lider tarafından gözden geçirilir.

## 8. Görünüm (kullanıcı kararı 2026-11-15: modeller Blender'da, kaliteli; arka plan ve çevre de iyi olmalı)

**Minyatür saha dioraması, 3B.** Lokomotif, vagonlar, ray parçaları ve çevre Blender'da (betikle, `tools/blender/`)
modellenir, GLB olarak Godot'a girer. Kural 1 geçerli: low-poly ve pikselli görüntü YOK; yuvarlatılmış kenarlar,
pürüzsüz yüzeyler, temiz malzemeler. Kamera sabit, ortografik, kuşbakışına yakın eğik (bulmaca okunurluğu önce gelir:
her hücre, her kanca, her hedef tek bakışta seçilmeli). Işık: sıcak gün ışığı, yumuşak gölge; mümkün olan her şey
Blender'da dokuya pişirilir (sabit kamera sayesinde ucuz ve kaliteli; hedef düşük-orta Android cihazda 60 kare).
Raylar yumuşak eğrilerle bağlanır, araçlar ray teğetine döner, hareket hücreler arasında akıcıdır.
Vagon rengi her zaman bir simgeyle birlikte gelir (renk körlüğü). Hedef hücre: yerde aynı renk ve simgeyle işaret.

**Çevre:** saha boş zeminde durmaz; her dünyanın bir yeri vardır (1: kır deposu; 2: liman; 3: dağ/kar; 4: fabrika;
sonrakiler işçi önerisiyle). Çevre oyun alanını çerçeveler ama rakip olmaz (doygunluk ve kontrast sahada, çevrede değil).

**Arayüz:** şablonun UI kiti (minimal, düz, premium, küçük simgeler). Ana ekranda arka planda **canlı saha** oynar:
gerçek saha görünümü bir seviyenin çözümünü döngüde kendi kendine oynatır (`LevelSession.start_demo`); ayrı bir
"tanıtım canlandırması" yazılmaz, oyunun kendisi gösterilir.

**Platform:** Android (kullanıcı: "mobil derken Android"). iOS kapsam dışı.

**Sıra (kullanıcı):** oyun + arayüz + seviyeler → Android SDK işi (derleme şablonu, AdMob, satın alma, APK) → en son
optimizasyon işçileri.

## 9. Katmanlar ve sözleşmeler

| Klasör | İçerik | Sahibi |
|---|---|---|
| `scripts/core/yard/` | Saf kurallar (RefCounted, sahnesiz, testli) | çekirdek |
| `tools/yard/` | Python: kural aynası, çözücü, üreteç, metin arayüzü | çekirdek |
| `data/levels/` | Seviye dosyaları + `index.json` | çekirdek |
| `scripts/game/` | Saha görünümü (3B), girdi, canlandırma; `LevelSession` uygulaması | görünüm |
| `tools/blender/`, `assets/models/`, `assets/textures/` | Blender betikleri, GLB modeller, pişmiş dokular | sanat |
| `scripts/ui/`, `scripts/autoload/`, `scripts/services/` | Kabuk: menü, seviye haritası, sonuç, reklam, satın alma | kabuk |
| `scripts/game/level_session.gd`, `scripts/core/level_catalog.gd` | SÖZLEŞME (yalnız lider değiştirir) | lider |

Ayrıntı: `docs/CORE_API.md`.
