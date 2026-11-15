"""Ses ölçüm yardımcıları (ffmpeg + numpy). `make_el_sfx.py` ve `audio_report.py` kullanır.

Ağ erişimi YOK; yalnız yerel dosyaları ölçer. Ölçüler: bütünleşik ses yüksekliği (LUFS-I),
gerçek tepe (dBTP), örnek tepesi, RMS, baş/son sessizlik ve döngü dikişi.
"""
import re
import subprocess

import numpy as np

RATE = 44100


def decode(path, channels=None, rate=RATE):
    """Dosyayı float32 [örnek, kanal] olarak çözer (ffmpeg ile; biçim fark etmez)."""
    cmd = ["ffmpeg", "-loglevel", "error", "-i", path]
    if channels:
        cmd += ["-ac", str(channels)]
    cmd += ["-ar", str(rate), "-f", "f32le", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries",
                            "stream=channels", "-of", "csv=p=0", path], capture_output=True, text=True).stdout.strip()
    count = channels or int(probe or 1)
    return np.frombuffer(raw, dtype="<f4").reshape(-1, count).copy()


def decode_filtered(path, filters, channels=None, rate=RATE):
    """`decode` ile aynı, ama önce ffmpeg süzgeci uygulanır (ör. yüksek geçiren)."""
    cmd = ["ffmpeg", "-loglevel", "error", "-i", path, "-af", filters]
    if channels:
        cmd += ["-ac", str(channels)]
    cmd += ["-ar", str(rate), "-f", "f32le", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    count = channels or 1
    return np.frombuffer(raw, dtype="<f4").reshape(-1, count).copy()


def lufs(path, pad_s=1.0):
    """(LUFS-I, gerçek tepe dBTP). Çok kısa seslerde 400 ms bloğu için sonuna sessizlik eklenir."""
    flt = "apad=pad_dur=%.2f,ebur128=peak=true" % pad_s if pad_s else "ebur128=peak=true"
    out = subprocess.run(["ffmpeg", "-nostats", "-i", path, "-af", flt, "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    summary = out.split("Summary:")[-1]
    integrated = re.search(r"I:\s+(-?[\d.]+|-inf)\s+LUFS", summary)
    peak = re.search(r"Peak:\s+(-?[\d.]+|-inf)\s+dBFS", summary)
    to_f = lambda m: float(m.group(1)) if m else float("nan")
    return to_f(integrated), to_f(peak)


def db(value):
    return 20.0 * np.log10(max(float(value), 1e-9))


def stats(path):
    """Tek dosyanın tüm ölçüleri (sözlük)."""
    data = decode(path)
    mono = data.mean(axis=1)
    length = len(mono) / RATE
    floor = 10 ** (-50 / 20.0)
    above = np.where(np.abs(data).max(axis=1) > floor)[0]
    head = above[0] / RATE if len(above) else length
    tail = (len(mono) - 1 - above[-1]) / RATE if len(above) else length
    integrated, true_peak = lufs(path, pad_s=max(0.0, 0.5 - length))  # olay süresi üzerinden; 400 ms bloğu için en az 0,5 sn
    return {
        "duration_s": round(length, 3),
        "lufs_i": round(integrated, 1),
        "true_peak_db": round(true_peak, 1),
        "peak_db": round(db(np.abs(data).max()), 1),
        "rms_db": round(db(np.sqrt(np.mean(data ** 2))), 1),
        "head_silence_ms": round(head * 1000),
        "tail_silence_ms": round(tail * 1000),
    }


def seam(data, rate=RATE):
    """Döngü dikişi: son örnekten ilk örneğe sıçrama, çevresindeki tipik örnek farkıyla kıyaslanır.

    Dönüş: (oran, ZAR dB). oran ≈ 1 ise dikiş yürüyen sinyalden ayırt edilemez; > 4 ise tık riski.
    `level_step_db`: dikişin iki yanındaki 200 ms RMS düzeyi farkı (müzikal süreklilik).
    """
    mono = data.mean(axis=1) if data.ndim > 1 else data
    window = int(rate * 0.2)
    ring = np.concatenate([mono[-window:], mono[:window]])
    typical = float(np.sqrt(np.mean(np.diff(ring) ** 2))) + 1e-9
    jump = abs(float(mono[0] - mono[-1]))
    before = db(np.sqrt(np.mean(mono[-window:] ** 2)))
    after = db(np.sqrt(np.mean(mono[:window] ** 2)))
    return {"jump_ratio": round(jump / typical, 2), "level_step_db": round(after - before, 2),
            "jump_abs": round(jump, 5)}


def spectrum_sanity(data, rate=RATE):
    """Kaba tayf denetimi: enerji oranları (düşük <200 Hz, orta 200-4k, yüksek >4k) ve 8 kHz üstü payı."""
    mono = data.mean(axis=1) if data.ndim > 1 else data
    length = min(len(mono), 1 << 20)
    window = np.hanning(length)
    spec = np.abs(np.fft.rfft(mono[:length] * window)) ** 2
    freqs = np.fft.rfftfreq(length, 1.0 / rate)
    total = float(spec.sum()) + 1e-12
    band = lambda lo, hi: round(float(spec[(freqs >= lo) & (freqs < hi)].sum()) / total, 3)
    return {"low": band(0, 200), "mid": band(200, 4000), "high": band(4000, 8000), "air": band(8000, 22050)}


def event_level(data, rate=RATE):
    """Kısa olay yüksekliği (dBFS): 150 Hz üstü sinyalin en yüksek 100 ms RMS'i. Darbeli sesler (damga) için LUFS-I'dan daha anlamlıdır
    (LUFS-I yalnız 0,4 sn bloklarla ve sessizlikle sulanır). `data`: float [örnek] ya da [örnek, kanal] (150 Hz üstü süzgeç `event_level_of` ile)."""
    mono = data.mean(axis=1) if data.ndim > 1 else data
    window = int(0.1 * rate)
    if len(mono) < window:
        mono = np.pad(mono, (0, window - len(mono)))
    energy = np.convolve(mono ** 2, np.ones(window) / window, "valid")
    return db(np.sqrt(float(energy.max())))


def event_level_of(path):
    return event_level(decode_filtered(path, "highpass=f=150", channels=1))
