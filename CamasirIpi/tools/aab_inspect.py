#!/usr/bin/env python3
"""AAB/APK statik denetimi — bundletool/aapt2 GEREKTİRMEZ (yalnız Python standart kitaplığı).

AAB içindeki `base/manifest/AndroidManifest.xml` aapt2 protobuf (Resources.proto: XmlNode) biçimindedir;
burada küçük bir protobuf çözücüyle okunur. Düz APK'da manifest ikili AXML'dir: o durumda
yalnız lib/ELF denetimi yapılır ve manifest için SDK'daki `aapt2 dump badging` önerilir.

Kullanım:
  python3 tools/aab_inspect.py <dosya.aab> [--json]
Çıktı: paket, versionCode/Name, min/target SDK, izinler, uygulama meta-verileri (AdMob kimliği),
appCategory/isGame, yerel kitaplıklar (ABI) ve her .so için ELF PT_LOAD hizası (16 KB = 2**14),
AAB boyutu, BundleConfig.pb içindeki sayfa hizası alanı, REPLACE_ / Google test kimliği taraması.
Çıkış kodu her zaman 0'dır (denetim kararını release_check.sh verir); --json makine okunur çıktı verir.
"""
import json
import os
import re
import struct
import sys
import zipfile

ANDROID_NS = "http://schemas.android.com/apk/res/android"


def _varint(buf: bytes, pos: int):
    result = shift = 0
    while True:
        b = buf[pos]
        pos += 1
        result |= (b & 0x7F) << shift
        if not b & 0x80:
            return result, pos
        shift += 7


def _fields(buf: bytes):
    """(alan_no, tel_tipi, değer) üçlüleri; tel 2 için bytes, 0 için int."""
    pos = 0
    while pos < len(buf):
        key, pos = _varint(buf, pos)
        num, wire = key >> 3, key & 7
        if wire == 0:
            val, pos = _varint(buf, pos)
        elif wire == 2:
            ln, pos = _varint(buf, pos)
            val = buf[pos:pos + ln]
            pos += ln
        elif wire == 1:
            val = buf[pos:pos + 8]
            pos += 8
        elif wire == 5:
            val = buf[pos:pos + 4]
            pos += 4
        else:
            raise ValueError("desteklenmeyen tel tipi %d" % wire)
        yield num, wire, val


def parse_node(buf: bytes):
    """XmlNode -> {'name', 'attrs': {ad: değer}, 'children': [...]} (metin düğümleri atlanır)."""
    for num, _w, val in _fields(buf):
        if num == 1:  # element
            el = {"ns": "", "name": "", "attrs": {}, "children": []}
            for en, _ew, ev in _fields(val):
                if en == 2:
                    el["ns"] = ev.decode("utf-8", "replace")
                elif en == 3:
                    el["name"] = ev.decode("utf-8", "replace")
                elif en == 4:
                    attr = {"ns": "", "name": "", "value": ""}
                    for an, _aw, av in _fields(ev):
                        if an == 1:
                            attr["ns"] = av.decode("utf-8", "replace")
                        elif an == 2:
                            attr["name"] = av.decode("utf-8", "replace")
                        elif an == 3:
                            attr["value"] = av.decode("utf-8", "replace")
                    el["attrs"][attr["name"]] = attr["value"]
                elif en == 5:
                    child = parse_node(ev)
                    if child:
                        el["children"].append(child)
            return el
    return None


def walk(node, name):
    if node["name"] == name:
        yield node
    for child in node["children"]:
        yield from walk(child, name)


def elf_load_alignments(data: bytes):
    """64 bit ELF PT_LOAD p_align değerlerinin en küçüğü (16 KB için >= 16384 olmalı)."""
    if data[:4] != b"\x7fELF" or data[4] != 2:
        return None
    e_phoff = struct.unpack_from("<Q", data, 0x20)[0]
    e_phentsize, e_phnum = struct.unpack_from("<HH", data, 0x36)
    aligns = []
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        p_type = struct.unpack_from("<I", data, off)[0]
        if p_type == 1:  # PT_LOAD
            aligns.append(struct.unpack_from("<Q", data, off + 48)[0])
    return min(aligns) if aligns else None


def inspect(path: str) -> dict:
    out = {"file": path, "errors": []}
    with zipfile.ZipFile(path) as z:
        names = z.namelist()
        out["size_bytes"] = os.path.getsize(path)
        manifest_name = next((n for n in names if n.endswith("manifest/AndroidManifest.xml")), None)
        out["manifest"] = {}
        if manifest_name:
            root = parse_node(z.read(manifest_name))
            m = out["manifest"]
            m["package"] = root["attrs"].get("package")
            m["versionCode"] = root["attrs"].get("versionCode")
            m["versionName"] = root["attrs"].get("versionName")
            uses = next(walk(root, "uses-sdk"), None)
            m["minSdkVersion"] = uses["attrs"].get("minSdkVersion") if uses else None
            m["targetSdkVersion"] = uses["attrs"].get("targetSdkVersion") if uses else None
            m["permissions"] = sorted({n["attrs"].get("name", "") for n in walk(root, "uses-permission")})
            app = next(walk(root, "application"), None)
            m["appCategory"] = app["attrs"].get("appCategory") if app else None
            m["isGame"] = app["attrs"].get("isGame") if app else None
            m["debuggable"] = app["attrs"].get("debuggable") if app else None
            m["label"] = app["attrs"].get("label") if app else None
            m["meta_data"] = {n["attrs"].get("name", ""): n["attrs"].get("value", "")
                              for n in walk(root, "meta-data")
                              if not n["attrs"].get("name", "").startswith("org.godotengine.plugin")}
            m["appId"] = m["meta_data"].get("com.google.android.gms.ads.APPLICATION_ID")
        libs = {}
        for n in names:
            if n.endswith(".so"):
                abi = n.split("/lib/")[1].split("/")[0] if "/lib/" in n else n.split("/")[1]
                data = z.read(n)
                libs.setdefault(abi, {})[n.rsplit("/", 1)[-1]] = {
                    "min_load_align": elf_load_alignments(data), "bytes": len(data)}
        out["native_libs"] = libs
        cfg = "BundleConfig.pb"
        out["bundle_config_strings"] = []
        if cfg in names:
            raw = z.read(cfg)
            out["bundle_config_strings"] = sorted(set(
                s.decode() for s in re.findall(rb"[A-Za-z0-9_.\-]{4,}", raw)))
            out["page_alignment_16k"] = b"PAGE_ALIGNMENT_16K" in raw or b"16K" in raw
        # Sızıntı taraması yalnız manifest + gönderilen data/ads.json üzerinde yapılır: dex içinde
        # üçüncü taraf kitaplıklar "REPLACE_" geçirebilir (gürültü). Üretim kararı için gönderilen
        # ads.json bütünüyle okunup ReleaseGuard'a verilir (release_check.gd).
        out["shipped_ads_json"] = None
        for n in names:
            if n.endswith("data/ads.json"):
                try:
                    out["shipped_ads_json"] = json.loads(z.read(n).decode("utf-8"))
                except ValueError:
                    out["errors"].append("ads.json okunamadi")
        leaks = {}
        if manifest_name and b"ca-app-pub-3940256099942544" in z.read(manifest_name):
            leaks["ca-app-pub-3940256099942544"] = [manifest_name]
        out["leaks"] = leaks
        # İmza sertifikası: META-INF/*.RSA|DSA|EC DER içinde konu adı düz ASCII görünür.
        sigs = [n for n in names if n.startswith("META-INF/") and n.endswith((".RSA", ".DSA", ".EC"))]
        out["signature_files"] = sigs
        out["debug_certificate"] = any(b"Android Debug" in z.read(n) for n in sigs)
    return out


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    info = inspect(sys.argv[1])
    if "--json" in sys.argv:
        print(json.dumps(info, indent=2, ensure_ascii=False))
        return 0
    m = info["manifest"]
    print("dosya:", info["file"], "(%.1f MiB)" % (info["size_bytes"] / 1048576))
    for k in ("package", "versionCode", "versionName", "minSdkVersion", "targetSdkVersion", "appCategory", "isGame", "debuggable", "label", "appId"):
        print("  %-17s %s" % (k, m.get(k)))
    print("  izinler:", ", ".join(m.get("permissions", [])))
    for abi, libs in sorted(info["native_libs"].items()):
        worst = min((v["min_load_align"] or 0) for v in libs.values())
        print("  abi %-12s %d .so, en kucuk PT_LOAD hizasi = %s (16 KB icin >= 16384)" % (abi, len(libs), worst))
    print("  BundleConfig 16K alani:", info.get("page_alignment_16k"))
    print("  manifestte Google test kimligi:", info["leaks"] or "yok")
    print("  imza dosyalari:", info["signature_files"] or "YOK (imzasiz)", "| hata ayiklama sertifikasi:", info["debug_certificate"])
    print("  gonderilen data/ads.json admob.mode:", (info["shipped_ads_json"] or {}).get("admob", {}).get("mode"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
