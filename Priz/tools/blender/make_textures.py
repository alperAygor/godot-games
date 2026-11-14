"""Priz — prosedürel doku üretici (yalnız numpy; bpy gerekmez).

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


# ---------------------------------------------------------------- ahşap

def wood_field(n, seed, rings=22, warp=0.9, pore_density=0.6):
    """Ahşap lifi: v (satır) boyunca uzanan halkalar. Dönüş: (ring 0..1, pores 0..1, big 0..1)."""
    x = np.arange(n)[None, :] / n
    warp_big = fnoise(n, n, 2.2, seed, sx=1.0, sy=6.0) - 0.5
    warp_mid = fnoise(n, n, 1.6, seed + 1, sx=1.0, sy=10.0, lo=2) - 0.5
    t = x * rings + warp_big * warp * 3.0 + warp_mid * warp * 0.8
    ring = t - np.floor(t)
    # Geç odun (koyu, sert) halkanın sonunda keskin; erken odun yumuşak geçişli.
    late = smoothstep(0.55, 0.92, ring) * (1.0 - smoothstep(0.95, 1.0, ring))
    pores = fnoise(n, n, 0.6, seed + 2, sx=1.0, sy=24.0, lo=24)
    pores = smoothstep(1.0 - pore_density * 0.45, 1.0, pores)
    big = fnoise(n, n, 2.0, seed + 3, sx=1.0, sy=3.0)
    return late, pores, big


def make_wood(name, n, seed, light, dark, rings, rough_base=0.55, warp=0.9):
    late, pores, big = wood_field(n, seed, rings=rings, warp=warp)
    light = hexc(light)
    dark = hexc(dark)
    shade = 0.82 + 0.3 * big
    col = lerp(light, dark, late * 0.85 + pores * 0.35)
    col = col * shade[:, :, None]
    fleck = fnoise(n, n, 0.3, seed + 9, sx=1.0, sy=8.0, lo=60)
    col *= (0.96 + 0.08 * fleck)[:, :, None]
    height = late * 0.35 - pores * 0.6 + big * 0.2
    rough = np.clip(rough_base + pores * 0.25 - late * 0.08, 0, 1)
    ao = 1.0 - pores * 0.35
    save_set(name, col, height, 3.0, rough, ao)


def make_floor(n=1024, seed=40):
    """Lamine/masif tahta döşeme: 16 sütun tahta (v boyunca), karışık boylar, derzler."""
    cols = 16
    pw = n // cols
    late, pores, big = wood_field(n, seed, rings=40, warp=1.2)
    rng = np.random.default_rng(seed)
    base_light = hexc("#b48f6b")
    base_dark = hexc("#7e5d43")
    albedo = np.zeros((n, n, 3))
    height = np.zeros((n, n))
    rough = np.zeros((n, n))
    ao = np.ones((n, n))
    yy = np.arange(n)
    for c in range(cols):
        x0 = c * pw
        # Bu sütunda tahta uç derzleri (sarmal, tile korunur).
        cuts = []
        pos = rng.integers(0, n)
        while len(cuts) < 3:
            cuts.append(pos % n)
            pos += rng.integers(n // 3, n // 2 + n // 5)
        cuts = sorted(cuts)
        # Her tahtaya ayrı ton ve lif kaynağı.
        seg_id = np.searchsorted(cuts, yy, side="right") % len(cuts)
        for s in range(len(cuts)):
            mask_rows = seg_id == s
            src_x = rng.integers(0, n - pw)
            flip = rng.random() < 0.5
            tint = 0.9 + rng.random() * 0.18
            warm = rng.random() * 0.05
            sl = slice(x0, x0 + pw)
            l_strip = late[:, src_x:src_x + pw]
            p_strip = pores[:, src_x:src_x + pw]
            if flip:
                l_strip = l_strip[::-1, ::-1]
                p_strip = p_strip[::-1, ::-1]
            colp = lerp(base_light, base_dark, l_strip * 0.55 + p_strip * 0.3)
            colp *= tint
            colp[:, :, 0] *= 1.0 + warm
            colp[:, :, 2] *= 1.0 - warm
            albedo[mask_rows, sl] = colp[mask_rows]
            height[mask_rows, sl] = (l_strip * 0.3 - p_strip * 0.5)[mask_rows]
            rough[mask_rows, sl] = (0.42 + p_strip * 0.25 + rng.random() * 0.08)[mask_rows]
        # Uç derzleri: yükseklikte V oluk.
        for cut in cuts:
            for d in range(-3, 4):
                r = (cut + d) % n
                k = 1.0 - abs(d) / 3.5
                height[r, x0:x0 + pw] -= 0.9 * k * k
                ao[r, x0:x0 + pw] *= 1.0 - 0.45 * k * k
                albedo[r, x0:x0 + pw] *= 1.0 - 0.35 * k * k
    # Uzun derzler (sütun kenarları): yuvarlatılmış pah.
    xx = np.arange(n) % pw
    edge = np.minimum(xx, pw - 1 - xx).astype(np.float64)
    bevel = 1.0 - smoothstep(0.0, 3.5, edge)
    height -= bevel[None, :] * 1.0
    ao *= (1.0 - bevel * 0.5)[None, :]
    albedo *= (1.0 - bevel * 0.4)[None, :, None]
    shade = 0.92 + 0.16 * big
    albedo *= shade[:, :, None]
    save_set("floor_planks", albedo, height, 3.0, np.clip(rough, 0, 1), ao)


# ---------------------------------------------------------------- kumaş

def make_fabric(n=512, seed=60, threads=64):
    """Düz dokuma (bez ayağı) + ipliklerde kalınlık/ton farkı. Albedo gri; malzemede renklenir."""
    y, x = np.mgrid[0:n, 0:n] / n
    u = x * threads
    v = y * threads
    iu = np.floor(u).astype(int)
    iv = np.floor(v).astype(int)
    fu = u - iu
    fv = v - iv
    over = ((iu + iv) % 2 == 0)
    warp_profile = np.sin(np.pi * fu) ** 0.7  # dikey iplik kesiti
    weft_profile = np.sin(np.pi * fv) ** 0.7
    # Üstte olan iplik yükselir; altta olan basık.
    along_warp = 0.6 + 0.4 * np.sin(np.pi * fv)
    along_weft = 0.6 + 0.4 * np.sin(np.pi * fu)
    h_warp = warp_profile * along_warp
    h_weft = weft_profile * along_weft
    height = np.where(over, h_warp, h_weft)
    slub_u = fnoise(n, n, 1.0, seed, sx=1.0, sy=8.0)  # iplik başına ton
    slub_v = fnoise(n, n, 1.0, seed + 1, sx=8.0, sy=1.0)
    heather = fnoise(n, n, 0.8, seed + 2, lo=8)
    tone = np.where(over, slub_u, slub_v)
    fuzz = fnoise(n, n, 0.2, seed + 3, lo=100)
    g = 0.72 + 0.12 * (tone - 0.5) + 0.06 * (heather - 0.5) + 0.05 * (fuzz - 0.5)
    g *= 0.86 + 0.14 * height
    albedo = np.stack([g, g, g], axis=-1)
    rough = np.clip(0.88 + 0.08 * (fuzz - 0.5), 0, 1)
    ao = 0.75 + 0.25 * height
    save_set("fabric", albedo, height * 0.6 + fuzz * 0.15, 2.5, rough, ao)


def make_linen(n=512, seed=70):
    """Keten perde: seyrek, düzensiz kalınlıkta iplikler (albedo gri)."""
    y, x = np.mgrid[0:n, 0:n] / n
    ux = fnoise(n, n, 1.0, seed, sx=1.0, sy=40.0, lo=30)
    vy = fnoise(n, n, 1.0, seed + 1, sx=40.0, sy=1.0, lo=30)
    slubs = fnoise(n, n, 1.2, seed + 2, sx=1.0, sy=12.0)
    height = 0.5 * ux + 0.5 * vy + 0.3 * slubs
    g = 0.80 + 0.10 * (height - 0.6) + 0.05 * (fnoise(n, n, 1.5, seed + 3) - 0.5)
    albedo = np.stack([g, g * 0.985, g * 0.95], axis=-1)
    save_set("linen", albedo, height, 1.6, np.full((n, n), 0.92), 0.85 + 0.15 * height)


def make_kilim(n=1024, seed=80):
    """Kilim desenli halı: basamaklı kenarlı göbekler ve bordürler (yazı/rakam yok)."""
    rng = np.random.default_rng(seed)
    cells = 160  # basamaklı (dokuma ızgarası) görünüm için kuantize
    y, x = np.mgrid[0:n, 0:n] / n
    qx = (np.floor(x * cells) + 0.5) / cells
    qy = (np.floor(y * cells) + 0.5) / cells
    red = hexc("#9a2f28")
    indigo = hexc("#2c3b5e")
    saffron = hexc("#d29a3c")
    cream = hexc("#e6d8bc")
    brown = hexc("#3a2820")
    teal = hexc("#3d6f6a")
    rose = hexc("#c46a5a")
    col = np.zeros((n, n, 3)) + red
    # Bordür bantları
    ex = np.minimum(qx, 1 - qx)
    ey = np.minimum(qy, 1 - qy)
    e = np.minimum(ex, ey)
    col[e < 0.035] = brown
    band = (e >= 0.035) & (e < 0.095)
    col[band] = cream
    # Bordürde zikzak
    zz_phase = np.where(ex < ey, qy, qx) * 22.0
    zz = np.abs((zz_phase % 1.0) - 0.5) * 2.0
    zig = band & (np.abs((e - 0.035) / 0.06 - zz) < 0.28)
    col[zig] = indigo
    col[(e >= 0.095) & (e < 0.11)] = saffron
    # Alan: üç basamaklı göbek
    field = e >= 0.11
    for cy, scale, c1, c2 in [(0.27, 1.0, indigo, saffron), (0.5, 1.15, teal, cream), (0.73, 1.0, indigo, saffron)]:
        d = np.abs(qx - 0.5) * 1.15 + np.abs(qy - cy) * 1.0
        r = 0.16 * scale
        m1 = field & (d < r)
        col[m1] = c1
        m2 = field & (d < r * 0.72)
        col[m2] = c2
        m3 = field & (d < r * 0.45)
        col[m3] = red
        m4 = field & (d < r * 0.2)
        col[m4] = cream
        # Kanca motifleri (göbeğin iki yanında)
        for sx in (-1, 1):
            hx = 0.5 + sx * r * 1.25
            dh = np.abs(qx - hx) + np.abs(qy - cy) * 1.4
            col[field & (dh < 0.045)] = c2
            col[field & (dh < 0.022)] = brown
    # Köşe üçgenleri
    for cx_, cy_ in [(0.11, 0.11), (0.89, 0.11), (0.11, 0.89), (0.89, 0.89)]:
        dc = np.abs(qx - cx_) + np.abs(qy - cy_)
        col[field & (dc < 0.13)] = rose
        col[field & (dc < 0.08)] = brown
    # Dokuma dokusu + abrash (yatay ton bantları) + aşınma
    weave = fnoise(n, n, 0.5, seed + 1, lo=120)
    abrash = fnoise(n, n, 1.5, seed + 2, sx=12.0, sy=1.0)
    wear = fnoise(n, n, 1.8, seed + 3)
    k = 0.86 + 0.12 * (abrash - 0.5) * 2 + 0.06 * (weave - 0.5)
    col = col * k[:, :, None]
    col = lerp(col, np.full(3, 0.75) * col.mean(axis=(0, 1)), smoothstep(0.7, 1.0, wear) * 0.25)
    # İplik çizgileri (atkı yönünde)
    rows = np.sin(y * n * np.pi / 3.0) * 0.5 + 0.5
    col *= (0.93 + 0.07 * rows)[:, :, None]
    height = rows * 0.5 + weave * 0.5
    save_set("rug_kilim", col, height, 2.0, np.full((n, n), 0.95), 0.8 + 0.2 * rows)


# ---------------------------------------------------------------- duvar, karo, taş

def make_plaster(n=512, seed=100):
    h1 = fnoise(n, n, 1.9, seed)
    h2 = fnoise(n, n, 1.0, seed + 1, lo=20)
    h3 = fnoise(n, n, 0.4, seed + 2, lo=120)
    height = h1 * 0.5 + h2 * 0.35 + h3 * 0.15
    g = 0.9 + 0.08 * (h1 - 0.5) + 0.04 * (h2 - 0.5)
    albedo = np.stack([g, g, g], axis=-1)
    rough = 0.82 + 0.12 * (h2 - 0.5)
    save_set("plaster", albedo, height, 1.2, rough, 0.92 + 0.08 * height)


def make_wallpaper(n=512, seed=110):
    """Sanat-deko yelpaze motifli duvar kâğıdı (albedo renkli, iki tonlu)."""
    y, x = np.mgrid[0:n, 0:n] / n
    rows = 6
    cols = 4
    gy = y * rows
    gx = x * cols + (np.floor(gy) % 2) * 0.5
    fx = gx - np.floor(gx) - 0.5
    fy = gy - np.floor(gy)
    r = np.sqrt(fx * fx + fy * fy)
    ang = np.arctan2(fx, fy)
    inside = r < 0.62
    rays = (np.abs(np.sin(ang * 7.0)) < 0.25) & inside & (r > 0.12)
    arcs = (np.abs(r - 0.5) < 0.02) | (np.abs(r - 0.35) < 0.015)
    motif = (rays | (arcs & inside)).astype(np.float64)
    motif = blur(motif, 1)
    base = hexc("#d9c9a8")
    ink = hexc("#b89c6c")
    paper = fnoise(n, n, 0.9, seed, lo=30)
    col = lerp(base, ink, motif * 0.85)
    col *= (0.96 + 0.06 * (paper - 0.5))[:, :, None]
    height = paper * 0.4 + motif * 0.4
    save_set("wallpaper", col, height, 1.0, 0.75 - motif * 0.2, None)


def make_tiles(n=512, seed=120, tx=4, ty=8):
    """Metro karo (yarım kaydırmalı), sırlı yüzey, derz ve pahlı kenar. Albedo kremsi-gri."""
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:n, 0:n] / n
    gy = y * ty
    row = np.floor(gy).astype(int)
    gx = x * tx + (row % 2) * 0.5
    col_i = np.floor(gx).astype(int) % tx
    fx = gx - np.floor(gx)
    fy = gy - np.floor(gy)
    # Karo içinden kenara uzaklık (karo boyutuna göre normalize: en-boy 2:1)
    dx = np.minimum(fx, 1 - fx) * 2.0
    dy = np.minimum(fy, 1 - fy)
    d = np.minimum(dx, dy)
    grout = d < 0.035
    bevel = smoothstep(0.035, 0.12, d)
    tile_id = (row * 31 + col_i * 17) % 97
    tint = (np.sin(tile_id * 12.9898) * 43758.5453) % 1.0
    glaze = fnoise(n, n, 1.6, seed)
    pool = smoothstep(0.1, 0.5, d) * (0.6 + 0.4 * glaze)  # sır havuzlanması
    base = 0.9 + 0.06 * (tint - 0.5)
    g = base * (0.96 + 0.04 * pool)
    albedo = np.stack([g, g * 0.99, g * 0.96], axis=-1)
    albedo[grout] = hexc("#8f877a") * 1.0
    height = np.where(grout, 0.0, 0.3 + 0.7 * bevel + 0.08 * glaze)
    rough = np.where(grout, 0.9, 0.12 + 0.08 * glaze)
    ao = np.where(grout, 0.55, 0.85 + 0.15 * bevel)
    save_set("tiles", albedo, height, 4.0, rough, ao)


def make_brushed(n=512, seed=140):
    streak = fnoise(n, n, 0.7, seed, sx=1.0, sy=60.0, lo=20)
    swirl = fnoise(n, n, 2.0, seed + 1)
    g = 0.78 + 0.1 * (streak - 0.5) + 0.04 * (swirl - 0.5)
    albedo = np.stack([g, g, g * 1.01], axis=-1)
    rough = np.clip(0.3 + 0.18 * (streak - 0.5) + 0.06 * swirl, 0, 1)
    save_set("brushed", albedo, streak * 0.6, 0.8, rough, None, metal=1.0)


def make_orange_peel(n=256, seed=150):
    """Boyalı metal/plastik için ince portakal kabuğu dokusu; tek normal + ORM."""
    peel = fnoise(n, n, 1.3, seed, lo=6, hi=60)
    fine = fnoise(n, n, 0.4, seed + 1, lo=60)
    height = peel * 0.8 + fine * 0.2
    write_png(os.path.join(OUT, "peel_normal.png"), height_to_normal(height, 0.6))
    rough = 0.32 + 0.1 * (fine - 0.5) + 0.06 * (peel - 0.5)
    write_png(os.path.join(OUT, "peel_orm.png"), orm(np.ones_like(rough), rough, 0.0))


def make_leather(n=512, seed=160):
    cells = fnoise(n, n, 0.9, seed, lo=25, hi=90)
    crease = np.abs(fnoise(n, n, 1.4, seed + 1, lo=6) - 0.5) * 2
    crease = 1.0 - smoothstep(0.0, 0.08, crease)
    height = cells * 0.8 - crease * 0.6
    g = 0.7 + 0.12 * (cells - 0.5) - crease * 0.15
    save_set("leather", np.stack([g, g, g], -1), height, 2.0, 0.45 + 0.15 * cells, 0.9 + 0.1 * cells)


# ---------------------------------------------------------------- atlaslar

def make_books(n=512, seed=170):
    """Kitap sırtı atlası: 12 sırt sütunu (32 px), sayfa kenarı (64 px), kapak bezi (64 px). Yazı yok."""
    rng = np.random.default_rng(seed)
    img = np.zeros((n, n, 3))
    colors = ["#7b2d26", "#2f4a63", "#c9a14a", "#3f5e4a", "#d8cfbf", "#5a3a5e", "#9c5b2e",
              "#20262e", "#b8473a", "#6c7f8f", "#e2b98a", "#4b6b6f"]
    gold = hexc("#c9a85a")
    cloth = fnoise(n, n, 0.4, seed, lo=80)
    for i, c in enumerate(colors):
        x0 = i * 32
        base = hexc(c)
        col = np.zeros((n, 32, 3)) + base
        style = rng.integers(0, 4)
        yy = np.arange(n)[:, None] / n
        # Sırt bombesi (yuvarlak sırt gölgesi)
        xx = (np.arange(32)[None, :] + 0.5) / 32
        bulge = 0.78 + 0.22 * np.sin(np.pi * xx)
        col *= bulge[:, :, None]
        if style in (0, 1):  # altın şeritler
            for b in (0.08, 0.12, 0.88, 0.92):
                m = (np.abs(yy - b) < 0.008)[:, 0]
                col[m] = gold * bulge[0][None, :, None][0]
        if style == 1:  # sırt etiketi bloğu (boş, yazısız)
            m = ((yy > 0.3) & (yy < 0.42))[:, 0]
            col[m] = lerp(base, hexc("#efe6d2"), 0.8)
        if style == 2:  # iki renkli sırt
            m = (yy > 0.7)[:, 0]
            col[m] = lerp(base, hexc("#1d1d1d"), 0.5)
        if style == 3:  # sırt kabartma halkaları
            for b in (0.2, 0.35, 0.5, 0.65, 0.8):
                m = (np.abs(yy - b) < 0.006)[:, 0]
                col[m] *= 0.7
        img[:, x0:x0 + 32] = col
    # Sayfa kenarı
    yy = np.arange(n)[:, None] / n
    pages = 0.86 + 0.06 * np.sin(np.arange(64)[None, :] * 2.6) * fnoise(n, 64, 0.3, seed + 3, lo=4)
    img[:, 384:448] = np.stack([pages, pages * 0.97, pages * 0.88], -1)
    # Kapak bezi (nötr, malzemede değil; kitap kapakları sırt rengini kullanır)
    img[:, 448:512] = hexc("#8a6f55")[None, None, :] * (0.9 + 0.1 * fnoise(n, 64, 0.5, seed + 4))[:, :, None]
    img *= (0.95 + 0.05 * cloth)[:, :, None]
    write_png(os.path.join(OUT, "books_albedo.png"), img)


def painterly(n, seed):
    """Fırça darbesi modülasyonu (yönlü gürültü)."""
    s1 = fnoise(n, n, 0.8, seed, sx=1.0, sy=5.0, lo=10)
    s2 = fnoise(n, n, 0.8, seed + 1, sx=5.0, sy=1.0, lo=10)
    return 0.5 * s1 + 0.5 * s2


def make_art(n=1024, seed=180):
    """2x2 tablo atlası: manzara, soyut, botanik, deniz. Yazı/rakam yok."""
    h = n // 2
    atlas = np.zeros((n, n, 3))
    y, x = np.mgrid[0:h, 0:h] / h
    brush = painterly(h, seed)
    # (a) gün batımı tepeleri
    sky = lerp(hexc("#f3c98b"), hexc("#d9805a"), smoothstep(0.0, 0.55, y))
    sun = smoothstep(0.11, 0.09, np.sqrt((x - 0.62) ** 2 + (y - 0.33) ** 2))
    a = lerp(sky, hexc("#fbe8c0"), sun)
    hills = [(0.52, "#b0675a", 1), (0.62, "#7d4d52", 2), (0.75, "#4b3a4a", 3), (0.86, "#2d2a38", 4)]
    for base_y, c, s in hills:
        ridge = base_y + 0.06 * np.sin(x[0] * (2.5 + s) * np.pi + s) + 0.03 * (fnoise(1, h, 1.8, seed + s)[0] - 0.5) * 3
        m = y > ridge[None, :]
        a[m] = hexc(c)
    a *= (0.9 + 0.2 * brush)[:, :, None]
    atlas[0:h, 0:h] = a
    # (b) yüzyıl ortası soyut
    b = np.zeros((h, h, 3)) + hexc("#efe4cf")
    shapes = [((0.35, 0.4), 0.22, "#d39a3a"), ((0.62, 0.58), 0.25, "#c0573e"), ((0.45, 0.72), 0.14, "#2f5d62"),
              ((0.7, 0.28), 0.1, "#2b2b33")]
    for (cx, cy), r, c in shapes:
        m = (x - cx) ** 2 + (y - cy) ** 2 < r * r
        b[m] = lerp(b[m], hexc(c), 0.92)
    stripe = (np.abs(x - 0.25) < 0.012) & (y > 0.15) & (y < 0.85)
    b[stripe] = hexc("#2b2b33")
    arc = np.abs(np.sqrt((x - 0.5) ** 2 + (y - 1.0) ** 2) - 0.42) < 0.012
    b[arc] = hexc("#2f5d62")
    b *= (0.93 + 0.12 * brush)[:, :, None]
    atlas[0:h, h:n] = b
    # (c) botanik yapraklar
    c_img = np.zeros((h, h, 3)) + hexc("#f1ece0")
    rng = np.random.default_rng(seed + 5)
    for i in range(7):
        cx, cy = 0.3 + rng.random() * 0.4, 0.25 + rng.random() * 0.55
        ang = rng.random() * np.pi
        L = 0.18 + rng.random() * 0.14
        u = (x - cx) * np.cos(ang) + (y - cy) * np.sin(ang)
        v = -(x - cx) * np.sin(ang) + (y - cy) * np.cos(ang)
        shape = (u / L) ** 2 + (v / (L * 0.42 * (1 - np.clip(u / L, -1, 1) ** 2 + 0.1))) ** 2 < 1
        green = hexc(["#4f6b4a", "#6e8a5a", "#33503f", "#8aa070"][i % 4])
        c_img[shape] = green
        vein = shape & (np.abs(v) < 0.004)
        c_img[vein] = green * 1.3
    c_img *= (0.93 + 0.12 * brush)[:, :, None]
    atlas[h:n, 0:h] = c_img
    # (d) deniz ve kayalık
    d = lerp(hexc("#cfe0e6"), hexc("#a9c4cf"), smoothstep(0.0, 0.5, y))
    sea = y > 0.55
    d[sea] = lerp(hexc("#4f7f93"), hexc("#2a4a5e"), smoothstep(0.55, 1.0, y))[sea]
    waves = sea & (np.sin(y * 140 + np.sin(x * 20) * 2) > 0.85)
    d[waves] = lerp(d[waves], hexc("#dfeef2"), 0.5)
    cliff = (x > 0.62 + 0.25 * (y - 0.3) - 0.04 * np.sin(y * 25)) & (y > 0.3)
    d[cliff] = lerp(hexc("#8b7a68"), hexc("#4e4238"), smoothstep(0.3, 1.0, y))[cliff]
    d *= (0.92 + 0.14 * brush)[:, :, None]
    atlas[h:n, h:n] = d
    write_png(os.path.join(OUT, "art_albedo.png"), atlas)


def make_leaf(n=256, seed=190):
    """Tek yaprak (u: sap→uç, v: genişlik). Orta damar ve yan damarlar; albedo + normal."""
    y, x = np.mgrid[0:n, 0:n] / n
    mid = np.abs(x - 0.5)
    vein_main = 1.0 - smoothstep(0.0, 0.012, mid)
    side = np.abs(((y * 9.0 - mid * 6.0) % 1.0) - 0.5)
    vein_side = (1.0 - smoothstep(0.0, 0.05, side)) * smoothstep(0.03, 0.08, mid) * (1 - smoothstep(0.3, 0.5, mid))
    mott = fnoise(n, n, 1.4, seed)
    base = lerp(hexc("#2f5a32"), hexc("#5e8a44"), 0.35 + 0.4 * mott + 0.25 * (1 - y))
    col = lerp(base, hexc("#a8c47a"), vein_main * 0.8 + vein_side * 0.35)
    edge = smoothstep(0.38, 0.5, mid)
    col *= (1.0 - 0.25 * edge)[:, :, None]
    height = vein_main * 0.6 + vein_side * 0.3 - mott * 0.1
    save_set("leaf", col, height, 2.0, 0.55 - 0.1 * vein_main, None)


def make_city(w=1024, h=512, seed=200):
    """Pencere dışı manzara maskeleri (RGBA):
    R = uzak silüet (tepe + uzak binalar), G = yakın binalar, B = pencere ışıkları, A = ağaçlar.
    Renkler gölgelendiricide dilime göre verilir."""
    rng = np.random.default_rng(seed)
    y, x = np.mgrid[0:h, 0:w]
    yn = y / h
    R = np.zeros((h, w))
    G = np.zeros((h, w))
    B = np.zeros((h, w))
    A = np.zeros((h, w))
    # Uzak tepeler
    ridge = 0.58 + 0.05 * np.sin(np.arange(w) / w * np.pi * 3 + 1) + 0.04 * (fnoise(1, w, 1.8, seed)[0] - 0.5) * 2
    R[yn > ridge[None, :]] = 1.0
    # Uzak binalar (kısa, sık)
    xpos = 0
    while xpos < w:
        bw = rng.integers(18, 46)
        top = 0.5 + rng.random() * 0.1
        R[(yn > top) & (x >= xpos) & (x < xpos + bw)] = 1.0
        xpos += bw + rng.integers(0, 10)
    # Yakın binalar (apartmanlar, çatı ve pencere ızgarası)
    xpos = rng.integers(-40, 0)
    while xpos < w:
        bw = rng.integers(90, 170)
        top = 0.30 + rng.random() * 0.16
        x0, x1 = max(xpos, 0), min(xpos + bw, w)
        body = (yn > top) & (x >= x0) & (x < x1)
        G[body] = 1.0
        # Çatı çıkıntısı
        G[(yn > top - 0.012) & (yn <= top) & (x >= x0 - 3) & (x < x1 + 3)] = 1.0
        # Pencereler
        ww, wh = 12, 16
        gx = 26
        gy = 30
        for wy in np.arange(top * h + 18, h - 20, gy):
            for wx in np.arange(x0 + 12, x1 - 18, gx):
                lit = rng.random()
                wyi, wxi = int(wy), int(wx)
                B[wyi:wyi + wh, wxi:wxi + ww] = 0.25 + 0.75 * lit
        xpos += bw + rng.integers(6, 30)
    # Yakın ağaçlar (yumuşak taç bulutları)
    tree_noise = fnoise(h, w, 1.6, seed + 3)
    for i in range(9):
        cx = rng.random() * w
        cy = h * (0.72 + rng.random() * 0.1)
        rx = 60 + rng.random() * 70
        ry = 70 + rng.random() * 50
        dx = np.minimum(np.abs(x - cx), w - np.abs(x - cx))
        d = (dx / rx) ** 2 + ((y - cy) / ry) ** 2
        A = np.maximum(A, smoothstep(1.05, 0.85, d + (tree_noise - 0.5) * 0.6))
    A[yn > 0.9] = 1.0
    B *= (1 - A)
    img = np.stack([blur(R, 1), blur(G, 1), B, blur(A, 1)], -1)
    write_png(os.path.join(OUT, "city_masks.png"), img)


def make_noise(n=256, seed=210):
    """Gölgelendiriciler için genel gürültü: R, G fbm; B ince; A yönlü."""
    r = fnoise(n, n, 1.6, seed)
    g = fnoise(n, n, 1.2, seed + 1, lo=3)
    b = fnoise(n, n, 0.6, seed + 2, lo=16)
    a = fnoise(n, n, 1.0, seed + 3, sx=1.0, sy=6.0)
    write_png(os.path.join(OUT, "noise_rgba.png"), np.stack([r, g, b, a], -1))


def make_paint_wood(n=512, seed=220):
    """Boyalı ahşap: boya altından hafifçe seçilen lif + fırça izi (yalnız normal + ORM)."""
    late, pores, big = wood_field(n, seed, rings=14)
    brush = fnoise(n, n, 0.9, seed + 4, sx=1.0, sy=20.0, lo=8)
    height = late * 0.25 - pores * 0.2 + brush * 0.25
    write_png(os.path.join(OUT, "paintwood_normal.png"), height_to_normal(height, 1.6))
    rough = 0.42 + 0.12 * (brush - 0.5) + pores * 0.1
    write_png(os.path.join(OUT, "paintwood_orm.png"), orm(1.0 - pores * 0.15, rough, 0.0))


def make_soil(n=256, seed=230):
    g1 = fnoise(n, n, 0.6, seed, lo=20)
    g2 = fnoise(n, n, 1.5, seed + 1)
    col = lerp(hexc("#3a2a1f"), hexc("#5c4331"), g2 * 0.7 + g1 * 0.3)
    col[smoothstep(0.8, 0.9, g1) > 0.5] = hexc("#8a7a66")
    save_set("soil", col, g1 * 0.7 + g2 * 0.3, 3.0, np.full((n, n), 0.95), 0.8 + 0.2 * g1)


def make_dial(n=512):
    """Gün dilimi kadranı: dört çeyrek (sabah sol, öğle üst, akşam sağ, gece alt),
    her birinde piktogram. Rakam/yazı yok. UV: kadran merkezi (0.5, 0.5)."""
    y, x = np.mgrid[0:n, 0:n] / n
    dx = x - 0.5
    dy = 0.5 - y  # yukarı +
    r = np.sqrt(dx * dx + dy * dy)
    ang = np.arctan2(dx, dy)  # 0 = yukarı, saat yönü +
    img = np.zeros((n, n, 3)) + hexc("#efe6d2")
    # Çeyrek renkleri (yumuşak geçişli)
    q_cols = [hexc("#f2cf6a"), hexc("#e98a4e"), hexc("#2f3d66"), hexc("#9cc4de")]  # üst, sağ, alt, sol
    q = ((ang + np.pi / 4) % (2 * np.pi)) / (np.pi / 2)
    qi = np.floor(q).astype(int) % 4
    qf = q - np.floor(q)
    base = np.zeros((n, n, 3))
    for k in range(4):
        base[qi == k] = q_cols[k]
    # Çeyrek sınırında ince ayraç
    sep = (np.minimum(qf, 1 - qf) < 0.012) & (r < 0.43) & (r > 0.1)
    face = r < 0.43
    img[face] = base[face]
    img[sep] = hexc("#efe6d2")
    # Merkez göbek
    img[r < 0.1] = hexc("#c9a35b")
    img[r < 0.06] = hexc("#8a6a34")
    # Dış halka ve çentikler (rakamsız)
    ring = (r > 0.43) & (r < 0.47)
    img[ring] = hexc("#c9a35b")
    ticks = (r > 0.44) & (r < 0.465) & (np.abs(((ang / (2 * np.pi) * 16) % 1.0) - 0.5) > 0.44)
    img[ticks] = hexc("#6e5226")

    def disc(cx, cy, rad):
        return (x - cx) ** 2 + (y - cy) ** 2 < rad * rad

    ink = hexc("#fff7e0")
    # Öğle: tam güneş + ışınlar (üst)
    cx, cy = 0.5, 0.24
    img[disc(cx, cy, 0.05)] = ink
    ra = np.arctan2(x - cx, y - cy)
    rr = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
    rays = (rr > 0.065) & (rr < 0.095) & (np.abs(((ra / (2 * np.pi) * 8) % 1.0) - 0.5) > 0.38)
    img[rays] = ink
    # Akşam: ufukta batan güneş (sağ)
    cx, cy = 0.76, 0.52
    hz = (y > cy) & (y < cy + 0.012) & (np.abs(x - cx) < 0.09)
    half = disc(cx, cy, 0.05) & (y < cy)
    img[half] = hexc("#fff0d0")
    img[hz] = hexc("#fff0d0")
    ra = np.arctan2(x - cx, cy - y)
    rr = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
    rays = (rr > 0.065) & (rr < 0.09) & (y < cy - 0.01) & (np.abs(((ra / (2 * np.pi) * 10) % 1.0) - 0.5) > 0.38)
    img[rays] = hexc("#fff0d0")
    # Gece: hilal + yıldızlar (alt)
    cx, cy = 0.5, 0.77
    moon = disc(cx, cy, 0.055) & ~disc(cx + 0.028, cy - 0.018, 0.048)
    img[moon] = hexc("#f6eccc")
    for sx, sy, sr in [(0.43, 0.70, 0.009), (0.585, 0.73, 0.007), (0.57, 0.83, 0.006)]:
        img[disc(sx, sy, sr)] = hexc("#f6eccc")
    # Sabah: doğan güneş, yarım + kısa ışın (sol), serin ton
    cx, cy = 0.24, 0.52
    half = disc(cx, cy, 0.045) & (y < cy)
    img[half] = hexc("#fffbe8")
    hz = (y > cy) & (y < cy + 0.012) & (np.abs(x - cx) < 0.09)
    img[hz] = hexc("#fffbe8")
    ra = np.arctan2(x - cx, cy - y)
    rr = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
    rays = (rr > 0.06) & (rr < 0.08) & (y < cy - 0.01) & (np.abs(((ra / (2 * np.pi) * 10) % 1.0) - 0.5) > 0.38)
    img[rays] = hexc("#fffbe8")
    img = blur(img, 1)
    paper = fnoise(n, n, 0.6, 77, lo=30)
    img *= (0.97 + 0.05 * paper)[:, :, None]
    write_png(os.path.join(OUT, "dial_albedo.png"), img)


def main():
    os.makedirs(OUT, exist_ok=True)
    make_dial()
    print("make_textures ->", OUT)
    make_wood("wood_oak", 1024, 10, "#d6a874", "#9a6a3e", rings=18)
    make_wood("wood_walnut", 1024, 20, "#8a5a3a", "#3e2618", rings=24, rough_base=0.5)
    make_floor()
    make_fabric()
    make_linen()
    make_kilim()
    make_plaster()
    make_wallpaper()
    make_tiles()
    make_brushed()
    make_orange_peel()
    make_leather()
    make_books()
    make_art()
    make_leaf()
    make_city()
    make_noise()
    make_paint_wood()
    make_soil()
    print("make_textures tamam")


if __name__ == "__main__":
    main()
