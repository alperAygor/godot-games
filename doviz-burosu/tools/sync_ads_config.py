#!/usr/bin/env python3
"""data/ads_ids.json -> addons/AdmobPlugin/android_export.cfg (AdMob'un manifest uygulama kimliği için export yapılandırması).

Kullanım: python3 tools/sync_ads_config.py          (mode=test: Google test kimlikleri, is_real=false)
          python3 tools/sync_ads_config.py --check  (yalnızca doğrular: dosya güncel mi, gerçek kimlikler dolu mu)
mode=real ama real_* alanları boşsa HATA verir (yayına yanlışlıkla boş kimlikle çıkılmasın).

Doğrulamalar (hem üretimde hem --check ile; hata = çıkış kodu 1):
  * kimlik biçimi: uygulama kimliği ca-app-pub-<16 hane>~<10 hane>, reklam birimi ca-app-pub-<16 hane>/<10 hane>;
  * mode=real iken HİÇBİR real_* alanı Google'ın herkese açık TEST yayıncı kimliğini (ca-app-pub-3940256099942544) taşıyamaz;
  * test kimliği SIZINTISI: Google test kimliği data/ads_ids.json'daki test_* alanları dışında hiçbir kaynak/veri/sahne dosyasında geçemez
    (kodda sabit test kimliği = gerçek kimliğe geçildiğinde sessizce test reklamı çıkar);
  * AD_ID: AdMob açıkken reklam kimliği izni birleşik manifestte KALMALI (android/ şablonunda tools:node="remove" ile silinmişse Android 13+'ta
    reklamlar bozulur) ve Play Console "Reklam kimliği" beyanı = EVET olmalı (docs/MONETIZATION.md). Biçimsiz/çelişkili bildirimde hata.
"""
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
GOOGLE_TEST_PUBLISHER = "ca-app-pub-3940256099942544"
# Gerçek bir test KİMLİĞİ (yayıncı + ~/ + rakamlar); tek başına yayıncı öneki (kara liste sabiti) sızıntı sayılmaz.
TEST_ID_RE = re.compile(re.escape(GOOGLE_TEST_PUBLISHER) + r"[~/][0-9]{6,}")
APP_ID_RE = re.compile(r"^ca-app-pub-[0-9]{16}~[0-9]{10}$")
UNIT_ID_RE = re.compile(r"^ca-app-pub-[0-9]{16}/[0-9]{10}$")
SCAN_DIRS = ("scripts", "scenes", "data", "tools", "assets", "export_presets.cfg", "project.godot")
SCAN_SKIP = {os.path.join("data", "ads_ids.json"), os.path.join("tools", "sync_ads_config.py"),
             os.path.join("tools", "release_guard.gd")}
SCAN_EXT = (".gd", ".tscn", ".tres", ".json", ".cfg", ".godot", ".csv", ".py", ".sh", ".md")
SOURCE = os.path.join(ROOT, "data", "ads_ids.json")
TARGET = os.path.join(ROOT, "addons", "AdmobPlugin", "android_export.cfg")


def validate(data):
    """Hata mesajlarının listesi (boş = geçti)."""
    errors = []
    android = data.get("android", {})
    mode = data.get("mode")
    if mode not in ("test", "real"):
        errors.append("mode 'test' ya da 'real' olmalı (şu an: %r)" % (mode,))
    for key in ("test_app_id", "test_rewarded_unit", "test_interstitial_unit"):
        if not android.get(key):
            errors.append("%s boş (test kipinin kimlikleri her zaman dolu kalmalı)" % key)
    if mode == "real":
        for key in ("real_app_id", "real_rewarded_unit", "real_interstitial_unit"):
            value = android.get(key, "")
            if not value:
                errors.append("mode=real ama %s boş: data/ads_ids.json'u doldur." % key)
            elif GOOGLE_TEST_PUBLISHER in value:
                errors.append("%s Google TEST kimliği taşıyor (%s)" % (key, GOOGLE_TEST_PUBLISHER))
            elif not (APP_ID_RE if key == "real_app_id" else UNIT_ID_RE).match(value):
                errors.append("%s biçimi geçersiz (%s)" % (key, "ca-app-pub-<16 hane>~<10 hane>" if key == "real_app_id" else "ca-app-pub-<16 hane>/<10 hane>"))
    errors.extend(find_test_id_leaks())
    errors.extend(check_ad_id(data))
    url = data.get("privacy_policy_url", "")
    if not isinstance(url, str) or (url and not url.startswith("https://")):
        errors.append("privacy_policy_url boş ya da https:// ile başlamalı")
    return errors


def find_test_id_leaks():
    """Google test yayıncı kimliği, ads_ids.json test_* alanları dışında geçmemeli."""
    leaks = []
    for entry in SCAN_DIRS:
        base = os.path.join(ROOT, entry)
        paths = [base] if os.path.isfile(base) else [os.path.join(d, f) for d, _, fs in os.walk(base) for f in fs]
        for path in paths:
            rel = os.path.relpath(path, ROOT)
            if rel in SCAN_SKIP or not path.endswith(SCAN_EXT) or "tests/results" in rel or "/build/" in rel or "tools/screenshots" in rel:
                continue
            try:
                text = open(path, encoding="utf-8").read()
            except (UnicodeDecodeError, OSError):
                continue
            if TEST_ID_RE.search(text) and not rel.startswith("addons"):
                leaks.append("Google test kimliği SIZINTISI: %s (yalnızca data/ads_ids.json test_* alanlarında olmalı)" % rel)
    # addons/AdmobPlugin/android_export.cfg test kimliğini YALNIZ mode=test iken [Debug] app_id'de taşır; real kipte Release'te olamaz (build() denetler).
    return leaks


def check_ad_id(data):
    """AD_ID izninin silinmediğini doğrular (varsa üretilmiş Gradle şablonunun manifestlerinde)."""
    errors = []
    if not data.get("providers", {}).get("admob", False):
        return errors
    build_dir = os.path.join(ROOT, "android", "build")
    pattern = re.compile(r"AD_ID[^>]*tools:node\s*=\s*\"remove\"|tools:node\s*=\s*\"remove\"[^>]*AD_ID")
    if os.path.isdir(build_dir):
        for d, _, files in os.walk(build_dir):
            if os.sep + "build" + os.sep + "intermediates" in d or os.sep + ".gradle" in d:
                continue
            for f in files:
                if f == "AndroidManifest.xml":
                    path = os.path.join(d, f)
                    try:
                        text = open(path, encoding="utf-8").read()
                    except (UnicodeDecodeError, OSError):
                        continue
                    if pattern.search(text):
                        errors.append("AD_ID izni manifestte tools:node=\"remove\" ile silinmiş (%s): AdMob Android 13+'ta reklam kimliği ister" % os.path.relpath(path, ROOT))
    return errors


def build():
    data = json.load(open(SOURCE, encoding="utf-8"))
    errors = validate(data)
    if errors:
        raise SystemExit("data/ads_ids.json doğrulaması başarısız:\n  - " + "\n  - ".join(errors))
    android = data["android"]
    real = data["mode"] == "real"
    return "\n".join([
        "; Otomatik üretilir (tools/sync_ads_config.py). Elle düzenleme.",
        "[General]",
        "is_real=%s" % ("true" if real else "false"),
        "",
        "[Debug]",
        'app_id="%s"' % android["test_app_id"],
        "",
        "[Release]",
        'app_id="%s"' % (android["real_app_id"] if real else android["test_app_id"]),
        "",
    ])


def main():
    text = build()
    if "--check" in sys.argv:
        current = open(TARGET, encoding="utf-8").read() if os.path.exists(TARGET) else ""
        if current != text:
            raise SystemExit("android_export.cfg güncel değil: python3 tools/sync_ads_config.py")
        print("android_export.cfg güncel; kimlik/AD_ID/sızıntı denetimleri geçti")
        return
    with open(TARGET, "w", encoding="utf-8") as f:
        f.write(text)
    print("yazıldı:", os.path.relpath(TARGET, ROOT))


if __name__ == "__main__":
    main()
