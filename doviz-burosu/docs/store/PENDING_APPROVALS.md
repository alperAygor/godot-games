# Sahibin onayını bekleyen adımlar (indirme / SDK / lisans) — T-R1

T-R1 yalnız Gradle'ın standart depolarından kendiliğinden çektiklerini indirdi (Gradle 8.x dağıtımı, AndroidX, Google Mobile Ads SDK, Play Billing). Aşağıdakiler **yapılmadı**.

## 1. Android NDK (yalnız release strip adımı gerekirse)
- Neden: şablon `ndkVersion 29.0.14206865` yazar; **debug AAB NDK olmadan üretildi**. Release AAB imzasız denenemediği için (anahtar yok) strip adımının NDK isteyip istemediği
  **doğrulanamadı**. İlk gerçek release derlemesi "NDK ... not found" derse:
  `~/Library/Android/sdk/cmdline-tools/latest/bin/sdkmanager "ndk;29.0.14206865"` (~1 GB; lisans kabulü sahibe aittir). Onaysız çalıştırılmadı.

## 2. bundletool (isteğe bağlı: indirme boyutu tahmini + BundleConfig 16 KB bayrağı)
- Roadmap T-R1 "bundletool ile indirme tahmini" ister; araç SDK'da yok. Kaynak: https://github.com/google/bundletool/releases (Apache-2.0, ~30 MB jar). Onay verilirse:
  `java -jar bundletool.jar get-size total --apks=...` / `dump config --bundle=build/release/doviz-burosu-release.aab`.
- Gerekmedi: `tools/aab_inspect.py` AAB'deki `.so` dosyalarının ELF `PT_LOAD` hizasını (16384) doğrudan okur.

## 3. Lisans kabulü
- `sdkmanager --licenses` çalıştırılmadı; mevcut `~/Library/Android/sdk/licenses/` yeterli oldu.

## 4. Sahip işleri (işçi yapamaz)
Bkz. `docs/store/RELEASE_STATUS.md` "Sahibin sıralı kalan işleri" ve `docs/store/SIGNING.md`.
