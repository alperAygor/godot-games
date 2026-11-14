class_name Motion
extends RefCounted

## Hareketin tek zamanlama/eğri kaynağı. Neden tek yerde: "premium his" ince ayardır;
## süreleri betiklere dağıtırsak ayar yapmak imkânsızlaşır. Değerler kasıtlı yumuşaktır;
## girdi yine anında işlenir, yalnız görsel olay kuyruğu süre alır.
## Düğme/pop/sayma süreleri `UiTokens.MOTION_*` (data/theme.json); burada sayfa ve tur akışı var.
## Oyuna özgü hareket sabitleri (uçuş, iniş...) bu dosyaya, bölümlenmiş olarak eklenir.

# --- Katman (sonuç sayfası, ayarlar) ---
const OVERLAY_FADE_SECONDS: float = 0.35
const OVERLAY_RISE_SECONDS: float = 0.5
const OVERLAY_RISE_DISTANCE: float = 80.0

# --- Tur sonu ---
## Kazanma/kayıp anından sonuç sayfasına kadar bekleme (son animasyon bitsin).
const WIN_DELAY_SECONDS: float = 0.45
const LOSE_DELAY_SECONDS: float = 0.6

# --- Sahne açılışı ---
const SCREEN_FADE_SECONDS: float = 0.5


## Yumuşak başla-yumuşak bitir (kübik).
static func ease_in_out(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	if c < 0.5:
		return 4.0 * c * c * c
	var f: float = -2.0 * c + 2.0
	return 1.0 - f * f * f * 0.5


## Hızlı başla, yumuşak otur.
static func ease_out(t: float) -> float:
	var f: float = 1.0 - clampf(t, 0.0, 1.0)
	return 1.0 - f * f * f


## Smoothstep: Tween'siz kullanımda yumuşak geçiş.
static func smooth(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)
