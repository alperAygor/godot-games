#!/usr/bin/env python3
"""data/licenses.json üretir: oyunun "Hakkında" ekranının gösterdiği, pakete giren üçüncü taraf yazılım/yazı tipi lisansları.

Kullanım: python3 tools/build_licenses.py
Neden JSON: export yalnızca `data/*.json` dosyalarını ham dosya olarak pakete alır (assets/fonts/*.txt ve addons/*/LICENSE girmez);
lisans metinleri bu yüzden BİREBİR kopyalanır. tests/unit/test_about.gd kopyanın kaynak dosyalarla aynı olduğunu denetler.
Yeni yazı tipi/eklenti paketlenirse buraya ekle; paketten çıkan bileşenin kaydını sil.
"""
import json
import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def read(path):
    with open(os.path.join(ROOT, path), "rb") as f:  # bayt bayt: satır sonları dahil BİREBİR (newline çevirisi yok)
        return f.read().decode("utf-8").removeprefix("\ufeff")


MIT_BODY = read("addons/GodotGooglePlayBilling/LICENSE").split("\n\n", 2)[2]  # "Permission is hereby..." bölümünden itibaren

COMPONENTS = [
    {
        "id": "vt323", "name": "VT323 (pixel font)", "kind": "font", "version": "", "license": "SIL Open Font License 1.1",
        "copyright": "Copyright 2011, The VT323 Project Authors", "url": "https://fonts.google.com/specimen/VT323",
        "files": ["assets/fonts/VT323.ttf"], "text": read("assets/fonts/OFL_VT323.txt"), "used": True,
    },
    {
        "id": "baloo2", "name": "Baloo 2 (font)", "kind": "font", "version": "", "license": "SIL Open Font License 1.1",
        "copyright": "Copyright 2019 The Baloo 2 Project Authors", "url": "https://github.com/EkType/Baloo2",
        "files": ["assets/fonts/Baloo2.ttf"], "text": read("assets/fonts/OFL_Baloo2.txt"), "used": False,
    },
    {
        "id": "pixelify", "name": "Pixelify Sans (font)", "kind": "font", "version": "", "license": "SIL Open Font License 1.1",
        "copyright": "Copyright 2021 The Pixelify Sans Project Authors", "url": "https://github.com/eifetx/Pixelify-Sans",
        "files": ["assets/fonts/PixelifySans.ttf"], "text": read("assets/fonts/OFL_PixelifySans.txt"), "used": False,
    },
    {
        "id": "admob", "name": "Godot AdMob plugin", "kind": "plugin", "version": "7.0", "license": "MIT",
        "copyright": "Copyright (c) 2024-present cengiz-pz", "url": "https://github.com/godot-sdk-integrations/godot-admob",
        "files": ["addons/AdmobPlugin", "addons/GMPShared"],
        # Pakette LICENSE dosyası yok; telif satırı plugin.cfg'den, metin standart MIT metnidir (sahip: yukarı akıştaki LICENSE ile değiştir).
        "text": "MIT License\n\nCopyright (c) 2024-present cengiz-pz\n\n" + MIT_BODY, "used": True,
    },
    {
        "id": "billing", "name": "Godot Google Play Billing plugin", "kind": "plugin", "version": "3.3.0", "license": "MIT",
        "copyright": "Copyright (c) 2020 Godot Engine contributors", "url": "https://github.com/godot-sdk-integrations/godot-google-play-billing",
        "files": ["addons/GodotGooglePlayBilling"], "text": read("addons/GodotGooglePlayBilling/LICENSE"), "used": True,
    },
]

out = {
    "_comment": "tools/build_licenses.py üretir; elle düzenleme. Godot Engine lisansı çalışma zamanında Engine.get_license_text() ile gelir.",
    "components": COMPONENTS,
}
with open(os.path.join(ROOT, "data", "licenses.json"), "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=1)
    f.write("\n")
print("data/licenses.json yazıldı (%d bileşen)" % len(COMPONENTS))
