#!/usr/bin/env python3
"""Ses kalite olcumu: QOA (Godot'un .sample ice aktarimi) ve lossy adaylar icin SNR + bant bazli spektral uzaklik.

Kullanim:
  python3 tools/audio_quality.py qoa  <orijinal.wav> <dump.qoa>        # QOA kodunu cozer, SNR basar
  python3 tools/audio_quality.py lossy <orijinal.wav>                   # ffmpeg vorbis/mp3 adaylari + dongu sureksizligi
QOA dokumu: Godot'ta AudioStreamWAV.data (FORMAT_QOA) baytlari = standart .qoa dosyasi.
"""
import struct, sys, subprocess, tempfile, os, wave
import numpy as np

_SF = [int(round((s + 1) ** 2.75)) for s in range(16)]
_MUL = [0.75, -0.75, 2.5, -2.5, 4.5, -4.5, 7, -7]
DEQ = [[int(np.sign(m) * np.floor(abs(m) * sf + 0.5)) for m in _MUL] for sf in _SF]


def decode_qoa(data: bytes) -> np.ndarray:
    assert data[:4] == b"qoaf"
    total = struct.unpack(">I", data[4:8])[0]
    pos = 8
    chans_out = None
    out = []
    while pos < len(data):
        ch = data[pos]; rate = int.from_bytes(data[pos+1:pos+4], "big")
        fs, fsize = struct.unpack(">HH", data[pos+4:pos+8]); pos += 8
        hist = []; wts = []
        for c in range(ch):
            h = list(struct.unpack(">4h", data[pos:pos+8])); w = list(struct.unpack(">4h", data[pos+8:pos+16])); pos += 16
            hist.append(h); wts.append(w)
        buf = np.zeros((fs, ch), dtype=np.int32)
        slices = (fs + 19) // 20
        for s in range(slices):
            for c in range(ch):
                sl = struct.unpack(">Q", data[pos:pos+8])[0]; pos += 8
                sf = (sl >> 60) & 15
                h = hist[c]; w = wts[c]
                n = min(20, fs - s * 20)
                for i in range(n):
                    p = (w[0]*h[0] + w[1]*h[1] + w[2]*h[2] + w[3]*h[3]) >> 13
                    q = (sl >> (57 - 3 * i)) & 7
                    r = DEQ[sf][q]
                    smp = max(-32768, min(32767, p + r))
                    d = r >> 4
                    for k in range(4):
                        w[k] += -d if h[k] < 0 else d
                    h[0], h[1], h[2], h[3] = h[1], h[2], h[3], smp
                    buf[s * 20 + i, c] = smp
        out.append(buf)
    return np.concatenate(out)[:total].astype(np.float64)


def read_wav(path):
    with wave.open(path) as w:
        raw = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(np.float64)
        return raw.reshape(-1, w.getnchannels()), w.getframerate()


def snr(a, b):
    n = min(len(a), len(b)); a = a[:n]; b = b[:n]
    return 10 * np.log10((a ** 2).sum() / max(((a - b) ** 2).sum(), 1e-9))


def band_report(a, b, rate):
    a = a[:, 0]; b = b[:min(len(a), len(b)), 0]; a = a[:len(b)]
    edges = [0, 250, 1000, 4000, 8000, 12000, 16000, 20000]
    n = 4096
    win = np.hanning(n)
    fa = np.zeros(n // 2 + 1); fb = np.zeros(n // 2 + 1); fe = np.zeros(n // 2 + 1)
    for i in range(0, len(a) - n, n // 2):
        A = np.fft.rfft(a[i:i+n] * win); B = np.fft.rfft(b[i:i+n] * win)
        fa += abs(A) ** 2; fb += abs(B) ** 2; fe += abs(A - B) ** 2
    freqs = np.fft.rfftfreq(n, 1 / rate)
    rows = []
    for lo, hi in zip(edges[:-1], edges[1:]):
        m = (freqs >= lo) & (freqs < hi)
        rows.append((lo, hi, 10 * np.log10(fa[m].sum() / max(fe[m].sum(), 1e-12)),
                     10 * np.log10(max(fb[m].sum(), 1e-12) / max(fa[m].sum(), 1e-12))))
    return rows


def loop_jump(x):
    """Dongu sinirindaki surekli sizlik: |x[0]-x[-1]| / tipik komsu fark."""
    x = x[:, 0]
    typ = np.abs(np.diff(x)).mean()
    return abs(x[0] - x[-1]), typ, abs(x[0] - x[-1]) / max(typ, 1e-9)


if __name__ == "__main__":
    mode = sys.argv[1]
    if mode == "qoa":
        ref, rate = read_wav(sys.argv[2]); dec = decode_qoa(open(sys.argv[3], "rb").read()).reshape(-1, 1)
        print(f"SNR {snr(ref[:,0], dec[:,0]):.1f} dB  n={len(dec)}")
        for lo, hi, s, lvl in band_report(ref, dec, rate):
            print(f"  {lo:5d}-{hi:5d} Hz  SNR {s:6.1f} dB  level diff {lvl:+.2f} dB")
        print("  loop jump (orig / qoa): %.1f/%.1f  ratio %.2f/%.2f" % (loop_jump(ref)[0], loop_jump(dec)[0], loop_jump(ref)[2], loop_jump(dec)[2]))
    elif mode == "lossy":
        src = os.path.abspath(sys.argv[2])
        ref, rate = read_wav(src)
        tmp = tempfile.mkdtemp()
        cands = {
            "vorbis-exp 96k": ["-ac", "2", "-c:a", "vorbis", "-strict", "-2", "-b:a", "96k", "x.ogg"],
            "vorbis-exp 128k": ["-ac", "2", "-c:a", "vorbis", "-strict", "-2", "-b:a", "128k", "x.ogg"],
            "vorbis-exp 192k": ["-ac", "2", "-c:a", "vorbis", "-strict", "-2", "-b:a", "192k", "x.ogg"],
            "mp3 lame 128k": ["-c:a", "libmp3lame", "-b:a", "128k", "x.mp3"],
            "mp3 lame V2 (~190k)": ["-c:a", "libmp3lame", "-q:a", "2", "x.mp3"],
        }
        print(f"{src}: PCM {os.path.getsize(src)/1024:.0f} KB")
        for name, a in cands.items():
            enc = os.path.join(tmp, a[-1])
            subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", src] + a[:-1] + [enc], check=True, cwd=tmp)
            dec = os.path.join(tmp, "d.wav")
            subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", enc, "-ac", "1", "-ar", str(rate), "-sample_fmt", "s16", dec], check=True)
            d, _ = read_wav(dec)
            # gecikmeyi hizala (kodlayici gecikmesi): 0..3000 ornek arasi en iyi SNR
            best = max(range(0, 3000, 1) if False else range(0, 2600, 13), key=lambda k: snr(ref[:200000, 0], np.roll(d[:, 0], -k)[:200000]))
            for k in range(max(0, best - 13), best + 14):
                if snr(ref[:200000, 0], np.roll(d[:, 0], -k)[:200000]) > snr(ref[:200000, 0], np.roll(d[:, 0], -best)[:200000]):
                    best = k
            dd = np.roll(d[:, 0], -best).reshape(-1, 1)
            n = min(len(ref), len(dd))
            print(f"  {name:22s} {os.path.getsize(enc)/1024:6.0f} KB  delay {best:4d} smp  SNR {snr(ref[:n,0], dd[:n,0]):5.1f} dB  decoded len {len(d)} vs {len(ref)} (gap {len(d)-len(ref):+d})")
