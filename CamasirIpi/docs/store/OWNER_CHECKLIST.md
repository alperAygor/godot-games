# Sahip yapılacaklar listesi — yalnız senin yapabileceklerin (sırayla)

Okuma 2026-11-15. Bu listeyi kod işçisi yapamaz (hesap, kimlik, ödeme, imza parolası, indirme onayı). Ayrıntı ve kaynaklar: `PLAY_REQUIREMENTS.md`, `PLAY_RELEASE_PLAN.md`. Hukuki tavsiye değildir.

## 0. Önce karar ver
- [ ] **Paket adı**: öneri `com.camasiripi.game` (Play'de sonradan değişmez).
- [ ] **Hedef kitle**: 13+ (çocuk değil) — `DATA_SAFETY_ANSWERS.md` B.
- [ ] **ElevenLabs**: Starter ($6/ay, ilk ay $1 — https://elevenlabs.io/pricing) ya da üstü planı al **ve** ticari yayın öncesi kararı ver: şartlar ücretsiz kullanımda yalnız ticari olmayan amaca izin veriyor (https://elevenlabs.io/terms-of-use, Bölüm 1(c), güncelleme 9 Ekim 2026). Ücretli plan öncesi üretilen seslerin sonradan ticari olup olmadığı şartlarda yazılı değil → en güvenlisi ücretli planda **yeniden üretmek** ya da ElevenLabs desteğinden yazılı teyit almak. Müzik ayrı şartlara bağlı olabilir. Üretim tarihlerini/faturaları sakla.
- [ ] İndirme onayları (kod işçisine ver): JDK 17, Android SDK paketleri, GodotGooglePlayBilling 3.3.0 zip, bundletool.

## 1. Google Play geliştirici hesabı
- [ ] https://play.google.com/console/signup — **kişisel** hesap aç (kayıt ücreti vardır; tutar resmi sayfada yazmıyor, ödeme ekranında görürsün). Kimlik/ödeme profili: yasal ad ve adres, iletişim e-postası/telefonu/geliştirici e-postası parolayla doğrulanır (https://support.google.com/googleplay/android-developer/answer/13628312).
- [ ] **Satıcı (merchant) hesabı + ödeme profili + banka bilgisi** (Türkiye destekli: https://support.google.com/googleplay/android-developer/answer/9306917); doğrulama "en çok beş gün".
- [ ] Vergi bilgileri (Google ödeme merkezi → Ayarlar; Türkiye için vergi ikamet belgesi istenebilir: https://support.google.com/paymentscenter/answer/13401799) — muhasebecine danış.
- [ ] Bil: para kazanan hesapta **tam adresin Google Play'de herkese açık görüneceği** (https://support.google.com/googleplay/android-developer/answer/13634081). Play developer profile sayfasından neyin göründüğünü kontrol et.
- [ ] Geliştirici web sitesi gerekli (kişisel hesap iletişim alanı + AdMob app-ads.txt).

## 2. Web sitesi ve gizlilik politikası
- [ ] Bir alan adı/sayfa barındır (herkese açık, coğrafi kısıtsız, PDF değil).
- [ ] `PRIVACY_POLICY_DRAFT.md`'yi gözden geçir, `[DEVELOPER NAME]`, `[CONTACT EMAIL]`, `[POSTAL ADDRESS]`, tarihi doldur; (isteğe bağlı) avukat/KVKK uzmanına göster; yayımla; URL'yi kod işçisine ver (`data/` içine yazılacak).
- [ ] Kökte `https://<alan>/app-ads.txt` (içeriği AdMob verecek).

## 3. AdMob (https://admob.google.com)
- [ ] Hesap aç / bağla (AdMob koşulları ve ödeme bilgisi sende).
- [ ] Uygulama ekle (Android, paket adı), **2 reklam birimi**: Rewarded, Interstitial. Kimlikleri (uygulama kimliği `ca-app-pub-…~…`, birim kimlikleri `ca-app-pub-…/…`) kod işçisine ver.
- [ ] Gizlilik ve mesajlaşma: **GDPR iletisi oluştur ve yayınla** (Google'ın sertifikalı CMP'si; EEA/UK/İsviçre için şart — https://support.google.com/admob/answer/13554116) ve ABD eyalet iletisini aç (öneri).
- [ ] Reklam içerik derecesi/engelleme ayarları.
- [ ] Kendi canlı reklamına **tıklama** (geçersiz tıklama). Testte yalnız test kimlikleri / test cihazı.
- [ ] Uygulama Play'de yayınlanınca AdMob'da mağazaya bağla; ilan değişikliği AdMob'a 24 saate dek yansır (https://support.google.com/admob/answer/9363762).

## 4. İmza anahtarı (upload key)
- [ ] Anahtarı **sen** üret (kod işçisi parolayı bilmemeli): `keytool -v -genkey -keystore camasiripi-upload.keystore -alias camasiripi -keyalg RSA -keysize 2048 -validity 10000` — parola yalnız harf-rakam, anahtar parolası keystore parolasıyla aynı (Godot belgesi).
- [ ] Dosyayı ve parolayı **en az iki ayrı güvenli yere** yedekle (parola yöneticisi + şifreli yedek). Depoya koyma. Kaybolursa Play Console'dan "Request upload key reset" ile sıfırlanır (https://support.google.com/googleplay/android-developer/answer/9842756).
- [ ] Derleme için ortam değişkenlerini yalnız kendi makinende ver (`GODOT_ANDROID_KEYSTORE_RELEASE_*`).

## 5. Play Console — uygulama oluştur ve doldur
- [ ] Uygulamayı oluştur (Oyun, Ücretsiz); Play Uygulama İmzalama şartlarını kabul et.
- [ ] **App content**: gizlilik politikası URL, Reklamlar = Evet, uygulama erişimi, hedef kitle (13+), İçerik derecelendirme anketi, Veri güvenliği, Reklam Kimliği, Finansal özellikler "yok" — cevaplar: `DATA_SAFETY_ANSWERS.md`.
- [ ] Mağaza ilanı: `PLAY_LISTING_DRAFT.md` (başlık **30 karakter** sınırı!), simge/öne çıkan/ekran görüntüleri, iletişim, web sitesi.
- [ ] **Uygulama içi ürün**: `remove_ads`, tek seferlik (yönetilen/tüketilmeyen), ad "Reklamları kaldır", fiyat, **Etkin**. Lisans testi hesaplarını ekle (Ayarlar → Lisans testi).

## 6. Testler
- [ ] **Dahili test** kanalı: AAB'yi (kod işçisinden) yükle; kendini ekle.
- [ ] **Kapalı test**: **en az 12 test kullanıcısı**, **14 ardışık gün** sürekli katılım (https://support.google.com/googleplay/android-developer/answer/14151465). 15-20 kişi davet et; hepsi Google Hesabı ile katılsın ve çıkmasın. Sonra Dashboard → **Apply for production** (inceleme genelde ≤ 7 gün).
- [ ] Pre-launch raporunu oku (https://support.google.com/googleplay/android-developer/answer/7002270).

## 7. Yayın
- [ ] Üretim sürümünü gönder; inceleme "7 güne dek" sürebilir (https://support.google.com/googleplay/android-developer/answer/9859751). Aşamalı yayın öner; Android vitals izle.
- [ ] Pt/de/ja/ko/es ilan çevirileri, oyun içi çeviriler incelendikten sonra.
