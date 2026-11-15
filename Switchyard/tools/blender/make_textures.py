"""Switchyard — prosedürel doku üretici (yalnız numpy; bpy gerekmez).

Tüm dokular burada, tohumlu (deterministik) olarak üretilir ve
`assets/textures/` altına PNG olarak yazılır. Dış kaynak yoktur.

Çalıştırma (Blender'ın gömülü Python'u numpy taşır):
    /Applications/Blender.app/Contents/Resources/5.2/python/bin/python3.13 tools/blender/make_textures.py

Kurallar:
- Tekrarlanan (tile) dokular FFT tabanlı gürültüyle üretilir; kenarları kusursuz birleşir.
- Normal haritaları OpenGL kuralındadır (Godot/glTF): yeşil = görüntüde yukarı.
- ORM: R = ortam örtmesi (çukur), G = pürüzlülük, B = metaliklik.
- Görsellerde rakam/yazı YOK (kitap sırtları, tablolar, ekranlar dahil).
"""

import os
import struct
import sys
import zlib

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "textures")


# ---------------------------------------------------------------- yardımcılar

def write_png(path, img):
    """img: float [0,1], (h, w) / (h, w, 3) / (h, w, 4). 8 bit PNG yazar."""
    a = np.clip(img, 0.0, 1.0)
    if a.ndim == 2:
        a = a[:, :, None]
    h, w, c = a.shape
    color_type = {1: 0, 3: 2, 4: 6}[c]
    data = (a * 255.0 + 0.5).astype(np.uint8)
    raw = b"".join(b"\x00" + data[y].tobytes() for y in range(h))

    def chunk(tag, payload):
        body = tag + payload
        return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, color_type, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(png)
    print("  doku:", os.path.relpath(path, ROOT), f"{w}x{h}")


def fnoise(h, w, beta=1.0, seed=0, sx=1.0, sy=1.0, lo=0.0, hi=1e9):
    """Kusursuz tekrarlanan 1/f^beta gürültü, [0,1] aralığına normalize.

    sx/sy: eksen başına frekans ölçeği (>1 o eksende daha düşük frekans = uzama).
    lo/hi: döngü/piksel cinsinden bant sınırları.
    """
    rng = np.random.default_rng(seed)
    w0 = rng.standard_normal((h, w))
    F = np.fft.fft2(w0)
    fy = np.fft.fftfreq(h)[:, None] * h * sy
    fx = np.fft.fftfreq(w)[None, :] * w * sx
    f = np.sqrt(fx * fx + fy * fy)
    f[0, 0] = 1.0
    amp = f ** (-beta)
    amp[(f < lo) | (f > hi)] = 0.0
    amp[0, 0] = 0.0
    r = np.real(np.fft.ifft2(F * amp))
    r -= r.min()
    r /= max(r.max(), 1e-9)
    return r


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def lerp(a, b, t):
    a = np.asarray(a, dtype=np.float64)
    b = np.asarray(b, dtype=np.float64)
    t = np.asarray(t, dtype=np.float64)
    if t.ndim == 2 and (a.ndim in (1, 3) or b.ndim in (1, 3)):
        t = t[:, :, None]
    return a + (b - a) * t


def hexc(s):
    s = s.lstrip("#")
    return np.array([int(s[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def height_to_normal(hm, strength=2.0):
    """Tekrarlanan yükseklik haritasından OpenGL normal haritası."""
    dx = (np.roll(hm, -1, axis=1) - np.roll(hm, 1, axis=1)) * 0.5
    dy = (np.roll(hm, -1, axis=0) - np.roll(hm, 1, axis=0)) * 0.5
    nx = -dx * strength
    ny = dy * strength
    nz = np.ones_like(hm)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    n = np.stack([nx / ln, ny / ln, nz / ln], axis=-1)
    return n * 0.5 + 0.5


def blur(img, r=1):
    """Tekrarlı kutu bulanıklığı (tile korunur)."""
    out = img.copy()
    for _ in range(r):
        out = (out + np.roll(out, 1, 0) + np.roll(out, -1, 0) + np.roll(out, 1, 1) + np.roll(out, -1, 1)) / 5.0
    return out


def orm(ao, rough, metal):
    return np.stack([ao, rough, metal * np.ones_like(rough)], axis=-1)


def save_set(name, albedo=None, height=None, nstrength=2.0, rough=None, ao=None, metal=0.0):
    if albedo is not None:
        write_png(os.path.join(OUT, f"{name}_albedo.png"), albedo)
    if height is not None:
        write_png(os.path.join(OUT, f"{name}_normal.png"), height_to_normal(height, nstrength))
    if rough is not None:
        if ao is None:
            ao = np.ones_like(rough)
        write_png(os.path.join(OUT, f"{name}_orm.png"), orm(ao, rough, metal))




# ---------------------------------------------------------------- hücresel (Voronoi) — tekrarlanan

def voronoi(n, cells, seed, jitter=0.85):
    """Tekrarlanan jitterli ızgara Voronoi. Dönüş: (F1, F2, id) piksel cinsinden uzaklık + hücre kimliği (0..1)."""
    rng = np.random.default_rng(seed)
    pts = (np.arange(cells)[:, None, None] * 0 + 0.0)
    off = rng.random((cells, cells, 2)) * jitter + (1.0 - jitter) * 0.5
    ids = rng.random((cells, cells))
    step = n / cells
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float64) + 0.5
    ci = np.floor(yy / step).astype(int)
    cj = np.floor(xx / step).astype(int)
    f1 = np.full((n, n), 1e9)
    f2 = np.full((n, n), 1e9)
    fid = np.zeros((n, n))
    for di in (-1, 0, 1):
        for dj in (-1, 0, 1):
            gi = ci + di
            gj = cj + dj
            wi = gi % cells
            wj = gj % cells
            py = (gi + off[wi, wj, 0]) * step
            px = (gj + off[wi, wj, 1]) * step
            d = np.sqrt((yy - py) ** 2 + (xx - px) ** 2)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            fid = np.where(closer, ids[wi, wj], fid)
            f1 = np.where(closer, d, f1)
    del pts
    return f1, f2, fid


def stones(n, cells, seed, round_k=0.55):
    """Taş alanı: yükseklik (kubbeli taşlar, aralarında boşluk), kimlik."""
    f1, f2, fid = voronoi(n, cells, seed)
    step = n / cells
    edge = (f2 - f1) / step            # kenara yakınlık (piksel/hücre)
    e = (f2 - f1) / np.maximum(f2 + f1, 1e-6)   # 0 kenar .. 1 merkez: köşesiz, yuvarlak
    dome = np.clip(e / round_k, 0.0, 1.0)
    dome = np.sqrt(dome * (2.0 - dome))   # yuvarlak taş profili
    h = dome * (0.65 + 0.35 * fid)
    return h, fid, edge


def baked_light(height, strength=3.0, light=(-0.55, 0.55, 0.63)):
    """Yükseklikten yönlü gölgeleme (sol üstten ışık): küçük taşlara hacim verir."""
    nrm = height_to_normal(height, strength) * 2.0 - 1.0
    lx, ly, lz = light
    d = np.clip(nrm[:, :, 0] * lx + nrm[:, :, 1] * ly + nrm[:, :, 2] * lz, 0, 1)
    return d / max(lz, 1e-3)


# ---------------------------------------------------------------- dokular

def tex_ballast():
    n = 512
    h, fid, edge = stones(n, 30, 11)
    h2, fid2, _ = stones(n, 52, 12)
    gap = np.clip(edge * 6.0, 0, 1)
    height = np.maximum(h, h2 * 0.75) + fnoise(n, n, 1.0, 13, lo=40) * 0.08
    tone = np.where(h >= h2 * 0.75, fid, fid2)
    base_a = hexc("#8d8a85")
    base_b = hexc("#b5ada1")
    base_c = hexc("#6f6c68")
    col = lerp(base_a, base_b, tone)
    col = lerp(col, base_c, smoothstep(0.75, 1.0, fnoise(n, n, 1.4, 14)) * 0.5)
    shade = 0.62 + 0.38 * np.clip(height * 1.4, 0, 1)
    col = col * (shade * (0.7 + 0.3 * baked_light(blur(height, 1), 6.0)))[:, :, None]
    # Taşlar arası koyu boşluk (yumuşak, piksel kıyısı yok)
    col = col * (0.62 + 0.38 * smoothstep(0.0, 0.25, gap))[:, :, None]
    save_set("ballast", albedo=col, height=blur(height, 1), nstrength=5.0)


def tex_gravel():
    n = 512
    h, fid, edge = stones(n, 64, 21, round_k=0.7)
    macro = fnoise(n, n, 2.0, 22)
    height = h * 0.8 + fnoise(n, n, 1.0, 23, lo=60) * 0.2
    col = lerp(hexc("#b9a98f"), hexc("#d4c6ad"), fid)
    col = lerp(col, hexc("#9f8d72"), smoothstep(0.55, 0.9, macro) * 0.55)
    col = col * ((0.82 + 0.18 * np.clip(height, 0, 1)) * (0.8 + 0.2 * baked_light(blur(height, 1), 4.0)))[:, :, None]
    col = col * (0.82 + 0.18 * smoothstep(0.0, 0.3, edge * 5))[:, :, None]
    save_set("gravel", albedo=col, height=blur(height, 1), nstrength=3.0)


def tex_grass():
    n = 1024
    macro = fnoise(n, n, 2.4, 31)
    mid = fnoise(n, n, 1.6, 32, lo=6)
    fine = fnoise(n, n, 0.9, 33, lo=80)
    # Kısa çim: hafif yön (rüzgâr) ve ince "tüy" — gürültülü değil, yumuşak benekli.
    blades = fnoise(n, n, 0.8, 34, sx=1.0, sy=0.35, lo=50)
    c0 = hexc("#7fae57")
    c1 = hexc("#97c063")
    c2 = hexc("#6a9a4c")
    col = lerp(c0, c1, smoothstep(0.3, 0.75, macro))
    col = lerp(col, c2, smoothstep(0.55, 0.85, mid) * 0.6)
    col = col * (0.9 + 0.12 * fine + 0.06 * blades)[:, :, None]
    # Küçük çiçek/yonca benekleri (çok seyrek, yumuşak)
    f1, f2, fid = voronoi(n, 40, 35)
    dots = smoothstep(4.0, 1.5, f1) * (fid > 0.93)
    col = lerp(col, hexc("#f3eedb"), dots * 0.7)
    dots2 = smoothstep(3.5, 1.2, f1) * ((fid > 0.86) & (fid < 0.89))
    col = lerp(col, hexc("#f2cf55"), dots2 * 0.7)
    height = blades * 0.5 + fine * 0.5
    save_set("grass", albedo=col, height=blur(height, 1), nstrength=1.6)


def tex_concrete():
    """Liman kaplaması: 1 m'lik beton plaklar (doku 2x2 plak), derzli, lekeli."""
    n = 1024
    slabs = 2
    yy, xx = np.mgrid[0:n, 0:n] / (n / slabs)
    fx = xx - np.floor(xx)
    fy = yy - np.floor(yy)
    d = np.minimum(np.minimum(fx, 1 - fx), np.minimum(fy, 1 - fy))
    joint = smoothstep(0.004, 0.012, d)
    rng = np.random.default_rng(41)
    sid = rng.random((slabs, slabs))[np.floor(yy).astype(int) % slabs, np.floor(xx).astype(int) % slabs]
    macro = fnoise(n, n, 2.2, 42)
    fine = fnoise(n, n, 0.9, 43, lo=60)
    col = lerp(hexc("#bfb9ad"), hexc("#d2ccc0"), sid * 0.6 + macro * 0.4)
    col = col * (0.93 + 0.07 * fine)[:, :, None]
    stain = smoothstep(0.62, 0.9, fnoise(n, n, 1.8, 44))
    col = lerp(col, hexc("#9f9a90"), stain * 0.35)
    col = col * (0.55 + 0.45 * joint)[:, :, None]
    height = joint * 0.8 + fine * 0.2
    save_set("concrete", albedo=col, height=blur(height, 1), nstrength=2.0)


def tex_asphalt():
    n = 512
    fine = fnoise(n, n, 0.7, 51, lo=60)
    macro = fnoise(n, n, 2.0, 52)
    f1, f2, fid = voronoi(n, 90, 53)
    agg = smoothstep(2.5, 0.8, f1) * (fid > 0.6)
    col = lerp(hexc("#4f5256"), hexc("#5d6064"), macro)
    col = col * (0.9 + 0.12 * fine)[:, :, None]
    col = lerp(col, hexc("#8a8c8e"), agg * 0.5)
    save_set("asphalt", albedo=col, height=fine * 0.6 + agg * 0.4, nstrength=1.5)


def tex_sleeper():
    """Ahşap travers: u = boy (256), v = en (64). Lif boyuna."""
    w, h = 256, 64
    grain = fnoise(h, w, 1.2, 61, sx=0.08, sy=1.0, lo=2)
    cracks = smoothstep(0.86, 0.95, fnoise(h, w, 0.9, 62, sx=0.05, sy=1.0, lo=4))
    macro = fnoise(h, w, 2.0, 63)
    col = lerp(hexc("#5b4a3c"), hexc("#7a6552"), grain * 0.7 + macro * 0.3)
    col = col * (1.0 - cracks * 0.35)[:, :, None]
    # Uçlara doğru hafif koyuluk (yağ/kir)
    u = np.arange(w)[None, :] / w
    ends = smoothstep(0.0, 0.12, np.minimum(u, 1 - u))
    col = col * (0.82 + 0.18 * ends)[:, :, None]
    write_png(os.path.join(OUT, "sleeper_albedo.png"), col)
    write_png(os.path.join(OUT, "sleeper_normal.png"), height_to_normal(grain * 0.6 - cracks * 0.6, 2.0))


def tex_water():
    """Su normal haritası (tekrarlanan, yumuşak dalgacıklar); gölgelendirici iki ölçekte kaydırır."""
    n = 512
    h = fnoise(n, n, 2.6, 71, lo=3, hi=60) * 0.7 + fnoise(n, n, 1.8, 72, lo=10, hi=120) * 0.3
    write_png(os.path.join(OUT, "water_normal.png"), height_to_normal(h, 22.0))


def tex_noise():
    """RGBA gürültü: R makro, G orta, B ince, A hücresel — gölgelendiricilerde çeşitleme için."""
    n = 256
    r = fnoise(n, n, 2.4, 81)
    g = fnoise(n, n, 1.6, 82, lo=4)
    b = fnoise(n, n, 1.0, 83, lo=20)
    f1, f2, fid = voronoi(n, 12, 84)
    a = fid
    write_png(os.path.join(OUT, "noise_rgba.png"), np.stack([r, g, b, a], axis=-1))


def tex_soft_shadow():
    """Temas gölgesi: yuvarlak köşeli dikdörtgenin yumuşak lekesi (beyaz, alfa = koyuluk). 128x256."""
    w, h = 128, 256
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    u = (xx + 0.5) / w * 2 - 1
    v = (yy + 0.5) / h * 2 - 1
    # SDF: kutu (0.62 x 0.80) + yarıçap
    qx = np.abs(u) - 0.55
    qy = np.abs(v) - 0.74
    out = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2) + np.minimum(np.maximum(qx, qy), 0)
    a = 1.0 - smoothstep(-0.25, 0.42, out)
    a = a ** 1.6
    img = np.stack([np.ones_like(a), np.ones_like(a), np.ones_like(a), a], axis=-1)
    write_png(os.path.join(OUT, "soft_shadow.png"), img)
    # Yuvarlak leke (ağaç, direk, bitki)
    w = h = 128
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float64)
    r = np.sqrt(((xx + 0.5) / w * 2 - 1) ** 2 + ((yy + 0.5) / h * 2 - 1) ** 2)
    a = (1.0 - smoothstep(0.15, 1.0, r)) ** 1.5
    img = np.stack([np.ones_like(a), np.ones_like(a), np.ones_like(a), a], axis=-1)
    write_png(os.path.join(OUT, "soft_blob.png"), img)


def main():
    os.makedirs(OUT, exist_ok=True)
    only = [a.split("=", 1)[1] for a in sys.argv[1:] if a.startswith("--only=")]
    fns = dict(ballast=tex_ballast, gravel=tex_gravel, grass=tex_grass, concrete=tex_concrete, asphalt=tex_asphalt,
               sleeper=tex_sleeper, water=tex_water, noise=tex_noise, shadow=tex_soft_shadow)
    for k, fn in fns.items():
        if only and k not in only[0].split(","):
            continue
        fn()
    print("make_textures: tamam")


if __name__ == "__main__":
    main()
