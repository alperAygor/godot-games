# Çamaşır İpi — Arayüz Rehberi

Hedef: **premium, modern, yumuşak, sade.** Düz yüzeyler, çizgi/kenarlık yok, küçük ikonlar, neredeyse
hiç yazı, sakin (ASMR) hareket. Tek kaynak: `data/theme.json`. `python3 tools/build_theme.py` bunu
`assets/theme/ui_theme.tres` (Godot teması) ve `scripts/ui/kit/ui_tokens.gd` (`UiTokens` sabitleri)
olarak üretir; `UiKit` bu sabitleri rol adlarıyla sunar. Ekranlarda sihirli sayı yazılmaz.

## Aralık ölçeği (px, 1080 genişlik)
`xs 8` · `sm 12` · `md 16` · `lg 24` · `xl 32` · `xxl 48` → `UiKit.SPACE_XS … SPACE_XXL`.
Ayırıcı çizgi yok: bölümleri **boşluk** ayırır. Sayfa iç boşluğu 48; sayfa yan boşluğu 32.

## Köşe yarıçapları
Sayfa 56 · Kart 40 · Karo 32 · Hap/düğme 63 · Çip 40 (`UiKit.RADIUS_*`, `UiTokens.RADIUS_*`).

## Yazı ölçeği (Baloo 2)
| rol | px | kullanım |
|---|---|---|
| display | 84 | ödül sayısı, haftalık sayı |
| numeric | 56 / 40 | büyük sayı / çip ve HUD sayısı |
| title | 52 | her sayfanın başlığı (hepsi aynı) |
| heading | 44 | tam ekran başlıkları (mağaza, koleksiyon) |
| body | 34 | satır metni, düğme altı |
| caption | 28 | ikincil / sönük metin |
| micro | 24 | yalnız rozet rakamı |
| button | 46 / 38 | birincil / ikincil düğme |

Sayılar **sabit genişlikli rakamla** (`tnum`, `UiKit.numeric_label`) yazılır: sayarken basamaklar
oynamaz. Binlik ayracı `UiKit.fmt_int` (tr/es `12.480`, en `12,480`). Uzun EN/ES metin için
`UiKit.wrap_label` (kelime sınırında kırar).

## Renk rolleri
| rol | değer | token |
|---|---|---|
| surface (sayfa) | `#FBF8F0` | `UiKit.SHEET` |
| surface-soft (kart) | `#F3EFE3` | `UiKit.SURFACE_SOFT` |
| ink | `#2F3A36` | `UiKit.TEXT` |
| ink-muted | `#7C8580` | `UiKit.TEXT_MUTED` |
| accent / positive | `#38A276` | `UiKit.ACCENT` |
| accent-soft | `#DCEFE3` | `UiKit.ACCENT_SOFT` |
| warning (alev/zincir) | `#F5894A` | `UiKit.FLAME` |
| danger | `#F08A78` | `UiKit.DANGER` |
| coin | `#F2B63D` (+ soft `#FBEBC6`) | `UiKit.GOLD`, `COIN_SOFT` |
| star | `#E9A62A` | `UiKit.STAR` |

Jeton ve yıldız **her yerde** bu iki altın tonla çizilir. Yeşil dışında vurgu rengi yoktur
(eski turkuaz `#2EC4A6` kaldırıldı).

## Yükseltme (elevation)
Tek, çok yumuşak seviye: yalnız alt sayfada `shadow_size 40`, alfa 0.10, yukarı doğru. Kartlar ve
düğmeler gölgesiz. Sayfa arkası koyu-yeşilimsi %46 ton (gerçek bulanıklık yok, ucuz).

## İkon ve düğme boyları
İkon: `sm 32` · `md 44` (düğme içi) · `lg 56` · disk `88` (düğme) / `112` (sayfa tepesi).
Düğme yüksekliği: **birincil 132** · **ikincil 126** · **kompakt 126** (satır içi). Dokunma hedefi
her zaman ≥ 126 (görsel daha küçük olabilir: `UiIconButton`, dil hapları, güçlendirici çubuğu).
Birincil düğmenin üst yarısında çok hafif iç ışık vardır (`SHEEN`).

## Hareket
Süreler `Motion`/`UiTokens`'tan: basma ölçeği 0.96 (0.10 sn, bırakınca yaylanır), pop 1.07,
sayma 0.6 sn, sayfa girişi `Motion.OVERLAY_*` (yumuşak yükselme + solma), çıkış 0.22 sn.
Ortak: `UiKit.attach_press_scale`, `UiKit.pop`, `UiKit.count_up`, `Sheet.play_intro/close`.

## Sayfa anatomisi
`Sheet` → **başlık** (`add_title`, ortalı, 52, altı `lg` boşluk) → **içerik** (kartlar `SURFACE_SOFT`,
aralarında `lg`) → `xl` boşluk → **tek birincil eylem** altta, başparmak bölgesinde (`add_action`).
İkincil eylem (Tamam/Tekrar dene) sakin `SecondaryButton`. Reklam düğmesi ile devam arası ≥
`UiKit.AD_BUTTON_GAP`. Tutamaç (grabber) yok: sayfa sürüklenmiyor, karartmaya dokununca kapanır.

## Durumlar
- **Boş / kilitli:** küçük ikon diski + tek kısa sönük satır (`UiKit.empty_state`).
- **Kapalı (disabled):** %50 soluk (`UiKit.set_enabled`), gölge/çerçeve yok.
- **Sıfır adet güçlendirici:** sönük gri rozet; `ad_enabled` açılırsa sarı rozet + oynat işareti.

## Ayar anahtarları (başka sistemler okur)
- `Progress.module_value("settings", "notifications", true)` — bildirim tercihi (Notifier ileride okur).
- `Progress.module_value("settings", "patterns", false)` — renk desenleri (`ColorPatterns.set_enabled`).
- Gizlilik seçenekleri satırı yalnız `AdManager.has_method("show_privacy_options")` ise görünür.

## Öğretici kartı verisi (`data/tutorials.json`)
Ek alanlar (hepsi isteğe bağlı): `sprite` (tek görsel) · `frames` (sırayla değişen kareler) ·
`falling` (bulutun altından süzülen damla) · `sprite_height` · `typed_kind` (türlü sepet rozeti) ·
`booster` (oyun çubuğundaki aynı simge). Hiçbiri yoksa eski `demo`/`icon` davranışı sürer.
