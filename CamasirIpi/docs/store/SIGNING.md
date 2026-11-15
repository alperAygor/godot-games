# Yükleme anahtarı (upload key) ve imzalama

Play **Play App Signing** kullanır: sen bir **yükleme anahtarı** üretirsin, Google asıl uygulama anahtarını saklar. Yükleme anahtarı kaybolursa
Play Console'dan sıfırlatılabilir; yine de yedekle. **Bu repoda hiçbir anahtar/şifre bulunmaz ve bu işçi anahtar üretmedi.**

## 1. Anahtar üret (sahip, kendi makinende)
JDK 17'nin `keytool`'u (`/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home/bin/keytool`):
```bash
mkdir -p ~/secure-keys            # PROJE KLASÖRÜNÜN DIŞINDA
keytool -genkeypair -v -storetype PKCS12 \
  -keystore ~/secure-keys/clothesline-upload.keystore \
  -alias upload -keyalg RSA -keysize 2048 -validity 10000
```
- Şifre: yalnız harf+rakam, **anahtar şifresi = depo şifresi** (Godot tek şifre kullanır). Şifreyi parola yöneticisine yaz.
- Dosyayı ve şifreyi **parola yöneticisine/şifreli yedeğe** koy (iki ayrı yer).

## 2. Nereye KOYMA
- Proje klasörüne, `android/`, `build/`, `docs/` altına, e-postaya, sohbete, ekran görüntüsüne. `.gitignore` `*.keystore`/`*.jks`'ı engeller ama
  buna güvenme. `export_presets.cfg` içindeki `keystore/release*` alanlarını **boş bırak** (dolu olması `release_check`'te hata: `signing_secret_in_preset`).

## 3. Derleme sırasında ver (ortam değişkenleri; Godot belgesi)
```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$HOME/secure-keys/clothesline-upload.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="upload"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="<şifre — geçmişe yazılmasın: `read -s` ile gir>"
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
godot --headless --path . --export-release "Android (release)" build/release/camasiripi-release.aab
bash tools/release_check.sh build/release/camasiripi-release.aab
```
Anahtar yoksa Godot şunu basar (denendi): `Kod İmzalama: Sürüm anahtar deposu bulunamadı, dışa aktarılamıyor.` — yani imzasız release üretilemez.

## 4. İmza doğrulama notu (DOĞRULANMADI)
Godot 4.7.2 Gradle AAB dışa aktarımında **debug** AAB imzasız çıktı (Gradle komutuna `release_keystore_file` ancak release dışa aktarımında geçer;
debug AAB'ye hata ayıklama anahtarı geçmedi). Release AAB'nin gerçekten imzalanıp imzalanmadığı anahtar olmadan sınanamadı. `tools/release_check.sh`
imzasız AAB'yi `aab_unsigned` olarak reddeder. İmzasız çıkarsa elle imzala:
```bash
jarsigner -keystore "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" -storepass:env GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD \
  build/release/camasiripi-release.aab "$GODOT_ANDROID_KEYSTORE_RELEASE_USER"
jarsigner -verify -verbose build/release/camasiripi-release.aab | tail -3
```
