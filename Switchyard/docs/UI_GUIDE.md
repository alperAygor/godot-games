# Switchyard — Arayüz Rehberi

Hedef: **premium, modern, yumuşak, sade.** Düz yüzeyler, çizgi/kenarlık yok, küçük ikonlar, neredeyse
hiç yazı, sakin hareket. Tek kaynak: `data/theme.json`. `python3 tools/build_theme.py` bunu
`assets/theme/ui_theme.tres` (Godot teması) ve `scripts/ui/kit/ui_tokens.gd` (`UiTokens` sabitleri)
olarak üretir (`--check` günceli doğrular; `verify.sh` bunu çalıştırır). `UiKit` bu sabitleri rol adlarıyla sunar.
Ekranlarda sihirli sayı yazılmaz. `ui_tokens.gd` ve `ui_theme.tres` elle DÜZENLENMEZ.

## Aralık ölçeği (px, 1080 genişlik)
`xs 8` · `sm 12` · `md 16` · `lg 24` · `xl 32` · `xxl 48` → `UiKit.SPACE_XS … SPACE_XXL`.
Ayırıcı çizgi yok: bölümleri **boşluk** ayırır. Sayfa iç boşluğu 48.

## Köşe yarıçapları
Sayfa 56 · Kart 40 · Karo 32 · Hap/düğme 63 · Çip 40 (`UiKit.RADIUS_*`, `UiTokens.RADIUS_*`).

## Yazı ölçeği (Baloo 2)
| rol | px | kullanım |
|---|---|---|
| display | 84 | ödül sayısı |
| numeric | 56 / 40 | büyük sayı / çip ve HUD sayısı |
| title | 52 | her sayfanın başlığı (hepsi aynı) |
| heading | 44 | tam ekran başlıkları |
| body | 34 | satır metni |
| caption | 28 | ikincil / sönük metin |
| micro | 24 | yalnız rozet rakamı |
| button | 46 / 38 | birincil / ikincil düğme |

Sayılar **sabit genişlikli rakamla** (`tnum`, `UiKit.numeric_label`) yazılır. Binlik ayracı `UiKit.fmt_int`
(tr/es `12.480`, en `12,480`). Uzun EN/ES metin için `UiKit.wrap_label`. Yazı tipi alt kümelidir
(`tools/subset_font.py`; depodaki tüm metinlerdeki karakterler korunur).

## Renk rolleri
| rol | token |
|---|---|
| zemin | `UiTokens.C_BACKGROUND` |
| sayfa (sheet) | `UiKit.SHEET` |
| kart | `UiKit.SURFACE_SOFT` |
| yazı / sönük yazı | `UiKit.TEXT` / `TEXT_MUTED` |
| vurgu / yumuşak vurgu | `UiKit.ACCENT` / `ACCENT_SOFT` |
| uyarı / tehlike | `UiKit.FLAME` / `DANGER` |
| jeton | `UiKit.GOLD` (+ `COIN_SOFT`) |

Paleti değiştirmek: `data/theme.json` → `python3 tools/build_theme.py`. Jeton **her yerde** aynı altın tonla çizilir.

## Yükseltme (elevation)
Tek, çok yumuşak seviye: yalnız alt sayfada gölge (alfa 0.10, yukarı doğru). Kartlar ve düğmeler gölgesiz.
Sayfa arkası koyu %46 ton (gerçek bulanıklık yok, ucuz).

## İkon ve düğme boyları
İkon: `sm 32` · `md 44` (düğme içi) · `lg 56` · disk `88` / `112`. Düğme yüksekliği: **birincil 132** · **ikincil 126**.
Dokunma hedefi her zaman ≥ 126 (görsel daha küçük olabilir: `UiIconButton`, dil hapları). İkonlar `data/icons.json`
tablosundan (`Icons.texture("lucide/play")`), BEYAZ üretilir, renk `modulate` ile verilir (Lucide, ISC lisansı).

## Hareket
Süreler `UiTokens.MOTION_*` ve `Motion` sabitlerinden: basma ölçeği 0.96 (0.10 sn, yaylanarak döner), pop 1.07, sayma
0.6 sn, sayfa girişi `Motion.OVERLAY_*`, çıkış 0.22 sn. Ortak: `UiKit.attach_press_scale`, `UiKit.pop`, `UiKit.count_up`,
`Sheet.play_intro/close`, `Juice`.

## Sayfa anatomisi
`Sheet` → **başlık** (`add_title`) → **içerik** → `xl` boşluk → **tek birincil eylem** altta, başparmak bölgesinde
(`add_action`). İkincil eylem sakin `SecondaryButton`. Reklam düğmesi ile devam arası ≥ `UiKit.AD_BUTTON_GAP`.
Karartmaya dokununca kapanır (`dismiss_on_dim`).

## Durumlar
- **Boş / kilitli:** küçük ikon diski + tek kısa sönük satır (`UiKit.empty_state`).
- **Kapalı (disabled):** %50 soluk (`UiKit.set_enabled`), gölge/çerçeve yok.

## Ayar anahtarları
- Bayraklar: `Progress.setting("sound"|"music"|"vibration")`.
- Diğer tercihler: `Progress.module_value("settings", anahtar, varsayılan)` (`UiData.module_flag`).
- Gizlilik seçenekleri satırı yalnız `AdManager.has_method("show_privacy_options")` ise görünür.
