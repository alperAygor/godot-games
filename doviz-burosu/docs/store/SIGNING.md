# Yükleme anahtarı (upload key) ve imzalama — Döviz Bürosu

Play **Play App Signing** kullanır: sen bir **yükleme anahtarı** üretirsin, Google asıl uygulama anahtarını saklar. Yükleme anahtarı kaybolursa
Play Console'dan sıfırlatılabilir; yine de yedekle. **Bu repoda hiçbir anahtar/şifre yoktur; hiçbir işçi anahtar üretmedi.**

## 1. Anahtar üret (sahip, kendi makinende)
JDK 17'nin `keytool`'u:
```bash
mkdir -p ~/secure-keys            # PROJE KLASÖRÜNÜN DIŞINDA
/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home/bin/keytool -genkeypair -v -storetype PKCS12 \
  -keystore ~/secure-keys/doviz-burosu-upload.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000
```
- Şifre: yalnız harf+rakam; **anahtar şifresi = depo şifresi** (Godot tek şifre kullanır). Dosyayı ve şifreyi iki ayrı güvenli yerde yedekle.
- Yol/ad içinde `debug` geçmesin (`release_check` bunu debug imzası sayıp reddeder).

## 2. Nereye KOYMA
Proje klasörüne, `android/`, `build/`, `docs/`, e-postaya, sohbete, ekran görüntüsüne. `.gitignore` `*.keystore`/`*.jks`'ı engeller ama buna güvenme.
`export_presets.cfg` içindeki `keystore/release*` alanları **boş kalır** (dolu olursa `release_check`: `signing_secret_in_preset`).

## 3. Derleme sırasında ver (ortam değişkenleri)
```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$HOME/secure-keys/doviz-burosu-upload.keystore"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="upload"
read -s GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD; export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD   # geçmişe yazılmaz
tools/release_build.sh      # kapı -> export-release -> AAB kapısı; kapı geçmeden AAB üretilmez
```
Anahtar yokken Godot `Kod İmzalama: Sürüm anahtar deposu bulunamadı, dışa aktarılamıyor.` basar (bu işçi denedi: imzasız release üretilemez).

## 4. Doğrulanmadı: release AAB'nin gerçekten imzalanması
Godot 4.7.2 Gradle debug AAB'si imzasız çıkıyor (bu projede de doğrulandı: `META-INF/*.RSA` yok). Release imzasını anahtar olmadan sınayamadık.
`release_check` imzasız AAB'yi `aab_unsigned` ile reddeder. İmzasız çıkarsa elle imzala ve yeniden denetle:
```bash
jarsigner -keystore "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" -storepass:env GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD \
  build/release/doviz-burosu-release.aab "$GODOT_ANDROID_KEYSTORE_RELEASE_USER"
jarsigner -verify build/release/doviz-burosu-release.aab | tail -3
bash tools/release_check.sh build/release/doviz-burosu-release.aab
```
