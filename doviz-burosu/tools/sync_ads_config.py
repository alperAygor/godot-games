#!/usr/bin/env python3
"""data/ads_ids.json -> addons/AdmobPlugin/android_export.cfg (AdMob'un manifest uygulama kimliği için export yapılandırması).

Kullanım: python3 tools/sync_ads_config.py          (mode=test: Google test kimlikleri, is_real=false)
          python3 tools/sync_ads_config.py --check  (yalnızca doğrular: dosya güncel mi, gerçek kimlikler dolu mu)
mode=real ama real_* alanları boşsa HATA verir (yayına yanlışlıkla boş kimlikle çıkılmasın).
"""
import json
import os
import sys

ROOT = os.path.join(os.path.dirname(__file__), "..")
SOURCE = os.path.join(ROOT, "data", "ads_ids.json")
TARGET = os.path.join(ROOT, "addons", "AdmobPlugin", "android_export.cfg")


def build():
    data = json.load(open(SOURCE, encoding="utf-8"))
    android = data["android"]
    real = data["mode"] == "real"
    if real and not all(android.get(k) for k in ("real_app_id", "real_rewarded_unit", "real_interstitial_unit")):
        raise SystemExit("mode=real ama real_app_id / real_rewarded_unit / real_interstitial_unit boş: data/ads_ids.json'u doldur.")
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
        print("android_export.cfg güncel")
        return
    with open(TARGET, "w", encoding="utf-8") as f:
        f.write(text)
    print("yazıldı:", os.path.relpath(TARGET, ROOT))


if __name__ == "__main__":
    main()
