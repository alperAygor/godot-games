# Cable Knot: Current Master — ajan kuralları

Yüksek voltajlı renkli kabloları düğümden çözüp **doğru renkli prizlere** bağladığın,
ASMR hissi veren 3D fizik ve bulmaca oyunu. Android, dikey (portrait), `gl_compatibility`,
Godot 4.7.2, GDScript. Oyun adı **İngilizce** kimlikle sabittir; TR metinler yerelleştirilir.

Bu dosya projenin anayasasıdır. Kural ile sezgi çatışırsa **kural kazanır**.
Oyun tasarımı: `PROJECT_SPEC.md`. Modül sözleşmeleri: `ARCHITECTURE.md`.

---

## 1. Sürümler, platform, performans

- **Godot 4.7.2 stable**, dil **GDScript** (C# yok). Godot 3 API'si yasak.
- Renderer **`gl_compatibility`** (düşük segment Android / siyah ekran riski).
- Ekran **1080x1920 portrait**, `canvas_items` / `expand`. UI 1080 genişlikte tasarlanır.
- Girdi: dokunma (`InputEventScreenTouch`, `InputEventScreenDrag`); masaüstünde fare dokunma taklidi.
- Hedef **60 FPS**; tek karede ağır allocation yapma (kablo mesh'i yenilenirken GC baskısına dikkat).
- Emin olmadığın API'yi **tahmin etme**: `studio-kit/tools/fetch_docs.sh` çıktısına bak.

## 2. Statik tip (pazarlıksız)

`project.godot` içinde `untyped_declaration=2` (hata). Her fonksiyon parametre ve dönüş tipi taşır;
dönüş yoksa `-> void`. Her değişken tiplidir; koleksiyonlar tiplidir (`Array[Node3D]`).
`Variant` yalnızca JSON/save sınırında. `Node` dönen API'lerde `as` ile daralt, `is` ile doğrula.

```gdscript
# DOĞRU
func apply_contact(count: int) -> void:
	var rate: float = _fill_rate(count)

# YANLIŞ
func apply_contact(count):   # tipsiz
	var rate = _fill_rate(count)
```

## 3. Klasörler (tek yönlü bağımlılık: ui → gameplay → core)

| Klasör | İçerik | Kural |
|---|---|---|
| `scenes/` | `.tscn` sahneleri | script yalnızca `scripts/` altında |
| `scripts/autoload/` | GameManager, AudioService, AdManager, GameData | global servis |
| `scripts/core/` | Saf mantık: seviye üretimi, aşırı yük, skor, kayıt, geometri | `get_node` yasak, test edilir |
| `scripts/gameplay/` | Sahne/fizik düğümleri: kablo, priz, pano, ışın | UI yok |
| `scripts/ui/` | Ekran/HUD script'leri | sadece gösterir, core'a delege eder |
| `scripts/services/` | `AdsProvider` sınırı | SDK sadece burada |
| `data/` | JSON denge tabloları | sihirli sayı yok |
| `tests/` | `test_*.gd` birim testleri | üretim kodu yok |

## 4. Sahne/akış kuralları

- Sahne geçişi **yalnızca** `GameManager.goto_scene()` / `start_level()` / `complete_level()`.
- Ses **yalnızca** `AudioService.play("ad")`; adlar `data/sounds.json` içinde tanımlıdır.
- Reklam **yalnızca** `AdManager`; ödül sadece `rewarded_finished(placement, true)` sonrası verilir (idempotent).
- Pause: `get_tree().paused = true`; arayüz düğümleri ve servisler `PROCESS_MODE_ALWAYS`.
  Tween'ler `set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)`.
- `.tscn` elle yazılırken GOTCHAS #12'ye uy: `unique_name_in_owner` olmadan `%Düğüm` çalışmaz.

## 5. Oyun kuralları (özet — ayrıntı PROJECT_SPEC.md)

- Farklı **renkteki** iki kablo `contact_distance` içine girerse **kısa devre**: kıvılcım + aşırı yük barı dolar.
- Aynı renk teması **güvenli**. Yalıtım kalkanı aktifken temas **bar doldurmaz** (yine de kıvılcım görseli oynar).
- Bar %100 → sigorta atar → bölüm başarısız; "Yedek Sigorta" (ödüllü reklam) ile devam.
- Fiş yalnızca **kendi rengindeki** boş prize snap olur; yanlış renk → ark + bar cezası + fiş geri seker.
- Tüm fişler doğru prizlere oturunca bölüm tamamlanır; yıldızlar süre + kısa devre sayısı + tepe yükten.
- Denge sayıları `data/balance.json`; seviyeler `data/levels.json`.

## 6. Görsel/ses dili

- Stilize low-poly: koyu gri endüstriyel pano, neon parlayan fiş/priz, pastel ama yüksek kontrast.
- Glow `gl_compatibility`'de çalışıyor (ölçüldü, GOTCHAS #4) — abartma, mobilde pahalı.
- Environment `adjustment_color_correction` LUT'u **kullanılmaz** (GOTCHAS #3); renk düzeltme tam ekran shader.
- ASMR: kablo çekme (whoosh), kıvılcım (crackle), prize oturma (clack), zafer (chime).

## 7. Doğrulama ve "bitti"

```bash
bash tools/verify.sh        # import + açılış dumanı + birim testleri (çıkışta SCRIPT ERROR taraması)
python3 tools/build_theme.py --check
```

Godot script hatasında da 0 döner → çıktı taranır. Kırmızıysa iş bitmedi.
**"Bitti" tanımı:** (1) verify yeşil, (2) yeni davranışın testi var ya da neden yok yazılı,
(3) `TASKS.md` + `CHANGELOG.md` güncel, (4) ekran görüntüsüyle gözle doğrulandı.

## 8. Commit

Conventional Commits, kapsam proje adı: `feat(KabloDugumu): ...`, `fix(...): ...`.
Bir mantıksal değişiklik = bir commit. `.godot/`, `build/`, `.env`, `tests/results/` commit edilmez.

---

## 9. v0.2 "ASMR redesign" kuralları

1. **Yerelleştirme:** kullanıcıya görünen hiçbir metin koda gömülmez → `Loc.t("anahtar")`.
   Yeni anahtar **her iki** `data/i18n/en.json` ve `tr.json` dosyasına eklenir (parite zorunlu).
   Bölüm adı/ipucu: `level.<n>.name` / `level.<n>.hint`. Oyun adı: `game.title` / `game.subtitle`.
2. **İngilizce kimlik:** `project.godot config/name = "Cable Knot: Current Master"`. Menü ve
   başlıklarda İngilizce ad kullanılır; TR'de yerelleştirilmiş karşılığı gösterilebilir.
3. **UI tasarım token'ları** (ARCHITECTURE §15): sade, ikon-öncelikli, buton yüksekliği 88–100
   tasarım px, ekran başına ≤ 3 ana eylem, panoyu örtmeyen HUD, Manrope fontu, 8 px grid.
4. **Performans bütçesi** (ARCHITECTURE §14): p95 kare süresi < 16.7 ms (M4), drag sırasında da.
   Halat mesh'i olay-tabanlı yeniden kurulur; tam ekran ekstra render yok.
5. **ASMR yönergeleri** (ARCHITECTURE §16): yumuşak geçişler, düşük kontrast, sıcak-koyu palet,
   sert beyaz/kırmızı flaş yok, ambient hum/pad sürekli ve kısık, sakin kutlama.
6. **Bölüm modifier'ları** (ARCHITECTURE §12): veri odaklı (`data/levels.json -> modifiers`);
   yoksa eski davranış korunur. Yeni mekanik eklerken önce core (saf + testli), sonra görsel.
7. **Ölçüm olmadan iddia yok:** perf iddiası `tools/perf_probe.gd` çıktısıyla, davranış iddiası
   `tools/verify.sh` + ekran görüntüsüyle kanıtlanır.

