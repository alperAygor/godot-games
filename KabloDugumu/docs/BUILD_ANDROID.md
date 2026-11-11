# Android Build — Cable Knot: Current Master

Debug APK bugüne kadar üretildi: `build/android/cableknot-debug.apk` (31 MB, debug imzalı).
Paket: `com.studiokit.cableknot` · versionName 0.2.0 · minSdk 24 · targetSdk 36 · arm64-v8a.

## Gereksinimler (bu makinede kurulu ve doğrulandı)

- Godot **4.7.2** + aynı sürüm **export templates** (`android_debug.apk` dahil)
- **JDK 17** — Godot editor ayarı: `export/android/java_sdk_path`
  (`/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`)
- **Android SDK** — `export/android/android_sdk_path` (`~/Library/Android/sdk`),
  build-tools 36.1.0, platform android-36, platform-tools (adb)
- **Debug keystore** — Godot editor ayarı: `export/android/debug_keystore`
  (`~/Library/Application Support/Godot/keystores/debug.keystore`, şifre `android`)

## Debug APK üretimi

```bash
cd godot-games/KabloDugumu
mkdir -p build/android
export ANDROID_HOME="$HOME/Library/Android/sdk"
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

godot --headless --path . --export-debug "Android" build/android/cableknot-debug.apk
```

Çıktı: `build/android/cableknot-debug.apk` (+ `.idsig`). `build/` git'e girmez.

## Cihaza kurma / test

```bash
adb devices                          # cihaz görünmeli
adb install -r build/android/cableknot-debug.apk
adb logcat -s godot:V                # oyun log'u
```

Bu makinede bağlı cihaz/emülatör yok; APK imzası ve manifest doğrulandı
(`aapt dump badging`, `apksigner verify`) ama **fiziksel cihaz testi yapılmadı**.

## Release (mağaza) sürümü

Release APK/AAB için gerekli olanlar (henüz yapılmadı, kullanıcı girdisi gerekir):

1. **Release keystore** oluştur ve Godot editor ayarlarına gir:
   `export/android/release_keystore`, kullanıcı/şifre (repoya **girmez**).
2. `export_presets.cfg` → `package/signed=true` sudah; release export:
   `godot --headless --path . --export-release "Android" build/android/cableknot-release.apk`
3. Mağaza için AAB: preset options → `gradle_build/export_format=1` (AAB) ve
   `gradle_build/use_gradle_build=true`; JDK 17 + Android SDK hazır.
4. Play Console: imzalama, data safety, reklam beyanı (gerçek AdMob eklendiğinde),
   ekran görüntüleri (`docs/screenshots/`), açıklama, TR/EN dil listesi.

## Preset özeti (`export_presets.cfg`)

- platform Android, debug `gradle_build/use_gradle_build=false` (hızlı export)
- `architectures/arm64-v8a=true` (armeabi-v7a kapalı — APK boyutu)
- `package/unique_name=com.studiokit.cableknot`, `package/name=Cable Knot`
- `version/name=0.2.0`, `version/code=1`
- immersive mode, tüm ekran boyutları destekli, GL Compatibility
