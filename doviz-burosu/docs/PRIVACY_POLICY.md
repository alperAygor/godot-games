# Privacy Policy — Exchange Desk (Döviz Bürosu)

> **Sahip için not (bu kutu yayımlanan metne girmez).**
> - Bu bir **taslaktır** (T-S1, 2026-11-15), hukuki tavsiye değildir. Yayımlamadan önce sahip okumalı; gerekirse avukat/uzman (KVKK, GDPR) görmelidir. Türkçe karşılığı: `docs/PRIVACY_POLICY.tr.md` (anlam eşdeğeri; ikisini birlikte yayımla ve birlikte güncelle).
> - Play politikası: gizlilik politikası **aktif, herkese açık, coğrafi kısıtsız, PDF olmayan, düzenlenemez** bir URL'de durmalı; Play Console'da **ve uygulama içinde** bağlanmalı; veri türleri, güvenli işleme, saklama/silme ve geliştirici iletişimini içermelidir (https://support.google.com/googleplay/android-developer/answer/10144311).
> - Köşeli parantezli yerleri doldur: `[DEVELOPER NAME]`, `[POSTAL ADDRESS]`, `[CONTACT EMAIL]`, `[EFFECTIVE DATE]`, `[POLICY URL]`. Uydurma bilgi yazma.
> - Yayımlanan URL'yi yalnızca `data/ads_ids.json` içindeki `privacy_policy_url` alanına yaz (oyun içi bağlantı ve yayın kapısı oradan okur); yer tutucu (`example.`) kalırsa yayın kapısı başarısız olur ve oyun içi düğme gizlenir.
> - **Her cümle koddaki gerçeğe karşılık gelir** (kanıtlar aşağıda "Kanıt tablosu"nda). Oyuna yeni SDK/özellik (analitik, bildirim, hesap, başka reklam ağı) eklenirse politika, Play "Veri güvenliği" formu (`docs/store/DATA_SAFETY_ANSWERS.md`) ve oyun içi onay metinleri (`MON_NOTICE_TEXT`, `MON_FORM_TEXT`) **birlikte** güncellenir.
> - Bu taslak Veri güvenliği cevaplarıyla **tutarlı** olmalıdır (Play, tutarsızlığı politika ihlali sayar — answer/10787469).

**Kanıt tablosu (sahip/gözden geçiren için; yayımlanan metne girmez)**

| Politikadaki cümle | Koddaki karşılığı |
|---|---|
| Hesap/giriş yok | Oyunda hesap/kimlik doğrulama kodu yok (`scripts/**`); ASSESSMENT §11 |
| Analitik yok, hiçbir şey cihazdan çıkmaz (kendi kodumuzdan) | `scripts/autoload/analytics.gd`: yalnız bellekte son 50 olay, gönderim yolu yok; `HTTPRequest` yok (ASSESSMENT §10) |
| İlerleme yalnız cihazda | `SaveManager` `user://save.json`, `SettingsManager` `user://settings.cfg`, öğretici durumu dosyası; sunucu yok |
| Reklam: Google AdMob; geçiş + ödüllü; banner yok | `scripts/services/admob_ads_provider.gd`, `data/ads.json`, `data/ads_ids.json` |
| Onay: AB/UK'de Google UMP formu; diğer bölgelerde oyun içi kısa bilgi + kişiselleştirme seçimi | `scripts/core/consent_flow.gd`, `scripts/ui/consent_sheet.gd`, `docs/MONETIZATION.md` §2 |
| Reklam içerik derecesi en çok PG | `data/ads_ids.json` `ads.max_ad_content_rating` |
| Tek satın alma: Reklamları kaldır, Google Play | `data/products.json` (`no_ads`), `scripts/services/playbilling_iap_provider.gd` |
| "Paylaş" düğmesi panoya yazar, ağa göndermez | `scripts/ui/mode_result_screen.gd` `DisplayServer.clipboard_set` |
| Günün Kuru cihaz saatinin UTC tarihini kullanır, sunucu yok | `scripts/core/daily_challenge.gd` |
| Konum/kişi/kamera/mikrofon/fotoğraf izni yok | `export_presets.cfg` izinleri: INTERNET, ACCESS_NETWORK_STATE, VIBRATE (+ SDK'ların kendi izinleri: reklam kimliği, faturalandırma) — `docs/store/RELEASE_STATUS.md` |
| Çocuklara yönelik değil (13+) | Karar O9 (`docs/RELEASE_ROADMAP.md`); `DATA_SAFETY_ANSWERS.md` |

---

# Privacy Policy — Exchange Desk (Döviz Bürosu)

**Effective date:** [EFFECTIVE DATE]
**Developer / data controller:** [DEVELOPER NAME], [POSTAL ADDRESS]
**Contact:** [CONTACT EMAIL]
**Policy URL:** [POLICY URL]

This policy explains what happens to your information when you play "Exchange Desk" (in Turkish: "Döviz Bürosu"), a free simulation game for Android ("the Game"). The Game is a game: all countries, currencies and exchange rates in it are fictional, and the in-game money has no real value.

## 1. The short version

- The Game has **no accounts, no sign-in, no chat and no user-generated content.**
- We do **not** ask for your name, email address, phone number, location, contacts, photos, camera or microphone, and the Game does not request permissions for them.
- Your progress and settings are stored **only on your device**. We do not run a server that receives them.
- The Game shows ads provided by **Google AdMob**. Google's ad software collects some device information to show and measure ads (section 3).
- You can remove the ads shown between game days with a **one-time purchase** processed by **Google Play**.
- The Game contains **no analytics service** of its own. It does not send usage statistics anywhere.
- The Game is **not designed for children under 13.**

## 2. Information stored on your device

The Game saves, locally on your device: your story progress, your in-game money and tools, scores for the Daily Rate and Endless modes, tutorial progress, your settings (sound, text size, language and similar), your choice about personalised ads, and whether you bought "Remove ads". This data stays on your device. It is deleted when you clear the Game's storage or uninstall the Game. We cannot access it and we cannot recover it for you. (If Android's device backup is enabled for the Game, your device backup service may copy it under Google's own terms.)

The Daily Rate mode picks the day's customers from your device's current date (UTC). This is calculated on your device; no date or result is sent to us. The "Share" button on a result screen only copies a short text to your device clipboard; nothing is sent by the Game.

## 3. Ads (Google AdMob)

The Game uses Google AdMob (Google Mobile Ads SDK) to show short ads at the end of a game day and optional rewarded ads that you choose to watch (for example, to double a day's in-game pay). The Game does not show banner ads. We ask AdMob to show ads with a content rating of up to "PG". To serve and measure ads, prevent fraud and keep the service running, the SDK automatically collects and shares with Google, according to Google's published guidance for the SDK:

- IP address (which may be used to estimate the general location of a device);
- user interactions with the Game and ads (for example, launching the Game, taps and video views);
- diagnostic information (for example, start-up time, hang rate, energy use);
- device and account identifiers, including the **Android advertising ID** and the app set ID.

Source: Google's data safety guidance for the Google Mobile Ads SDK — https://developers.google.com/admob/android/privacy/play-data-disclosure . According to that guidance, the data the SDK collects is encrypted in transit.

**Your choices.**
- *In the Game, regions with Google's consent form (for example the European Economic Area, the United Kingdom and Switzerland):* the Game shows Google's consent message (Google User Messaging Platform) the first time you play. **Settings > Privacy options** lets you review or change your choice at any time. Without consent, only non-personalised or limited ads may be shown.
- *In the Game, other regions:* the first time you play, a short notice explains the ads and asks whether the ads you see may be tailored to you ("Personalised ads" or "Non-personalised ads"). Your choice is stored on your device and passed to AdMob. You can change it at any time in **Settings > Privacy options**.
- *Android settings:* you can reset or delete your advertising ID, or opt out of ads personalisation, in your device's Settings (Google > Ads). If you delete the ID, apps receive a string of zeros instead.
- *United States state laws:* where applicable, you can use the same privacy options to limit use of your data for personalised advertising.

Google acts as an independent controller for its advertising purposes. How Google handles data is described in the Google Privacy Policy (https://policies.google.com/privacy ) and in "How Google uses information from sites or apps that use our services" (https://policies.google.com/technologies/partner-sites ).

## 4. Purchases (Google Play)

"Remove ads" is a one-time in-app purchase processed by **Google Play**. Payment details are handled by Google and **never reach us**. The Game receives from Google Play only the information needed to know whether you own the product (for example, product ID and purchase state) and to restore it if you reinstall (Settings > "Restore purchases"). We do not receive your name, card number or address. Refunds and billing questions are handled by Google Play. The Game has no other purchases. Nothing you can buy in the Game gives a chance-based reward, and in-game money cannot be bought.

## 5. Permissions

The Game asks Android for internet access (to load ads and talk to Google Play), network state, and vibration (the optional vibration feedback, which you can switch off in Settings). The advertising and billing software libraries add their own permissions, such as access to the advertising ID and the Google Play billing permission. The Game does not request permissions for location, contacts, calendar, camera, microphone, photos, files or phone calls.

## 6. Information we do not collect

We do not collect or sell your personal information. We have no accounts, no backend server for the Game, no analytics service, no location data, no contacts and no user-generated content. We do not sell personal information.

## 7. Children

The Game is **not designed for or directed at children under 13**, and Google Play's target audience for the Game is set accordingly. We do not knowingly collect personal information from children. The story includes themes such as bribery, forged documents and police, in a darkly humorous tone. If you believe a child has used the Game in a way that involves personal information, contact us at [CONTACT EMAIL].

## 8. Legal bases and your rights

- **Türkiye (KVKK, Law No. 6698):** [DEVELOPER NAME] is the data controller for any personal data we ourselves process (currently, only e-mails you send us). Google, as an independent controller, processes advertising data as described in section 3. You may apply to us about your rights under Article 11 of the law (information, access, correction, deletion, objection) at [CONTACT EMAIL]. *[Owner: have this section reviewed by a Turkish data-protection professional; the KVKK official site was not read for this draft. Delete this paragraph if you are not established in Türkiye.]*
- **EEA / United Kingdom / Switzerland (GDPR):** our own processing is limited to correspondence you initiate (legitimate interest / your request). Advertising processing is based on your **consent** collected through Google's consent message, which you can withdraw at any time through "Privacy options". You may ask us for access, correction or deletion of data we hold and lodge a complaint with your local supervisory authority.
- **Other places:** where local law gives you additional rights, you can use them by contacting us.

## 9. International transfers

Google operates globally; your data may be processed in countries other than your own, under Google's own safeguards.

## 10. Retention and deletion

The Game has no accounts, so there is no account to delete. Local data is removed by clearing the Game's storage or uninstalling it. Messages you send us are kept only as long as needed to answer them. Advertising data held by Google is governed by Google's retention practices; you can delete your advertising ID in Android settings.

## 11. Security

Data the Game sends to Google (through the advertising and billing software) is encrypted in transit. Data stored on your device is protected by your device's security.

## 12. Changes

We may update this policy when the Game changes (for example, if analytics or notifications are ever added). The effective date above will change, and in-app notice will be given for material changes.

## 13. Contact

[DEVELOPER NAME] — [CONTACT EMAIL] — [POSTAL ADDRESS]
