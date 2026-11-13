class_name Motion
extends RefCounted

## Tüm hareketin tek zamanlama/eğri kaynağı. Neden tek yerde: "premium his" ince ayardır;
## süreleri oyun/çamaşır/sepet betiklerine dağıtırsak ayar yapmak imkânsızlaşır.
## Değerler kasıtlı yavaş ve yumuşaktır (ASMR hissi); girdi yine anında işlenir, yalnız
## görsel olay kuyruğu süre alır.

# --- Çamaşır: mandal ve hazırlık ---
## Uçuştan önce çamaşır hafifçe kalkıp "çekilir"; mandallar bu sırada fırlar.
const ANTICIPATE_SECONDS: float = 0.12
const ANTICIPATE_LIFT: float = 16.0
const ANTICIPATE_STRETCH: float = 0.05
const PIN_POP_HEIGHT: float = 26.0
const PIN_POP_SECONDS: float = 0.12
const PIN_FALL_DISTANCE: float = 190.0
const PIN_FALL_SECONDS: float = 0.45
const PIN_SPIN_DEGREES: float = 220.0

# --- Uçuş ---
const FLIGHT_SECONDS: float = 0.46
const FLIGHT_ARC_MIN: float = 90.0
const FLIGHT_ARC_MAX: float = 230.0
const FLIGHT_ARC_PER_DISTANCE: float = 0.28
const FLIGHT_SCALE_BUMP: float = 0.07
## Uçarken yöne doğru yatma ve geride kalan kumaş (gecikmeli sallanma).
const FLIGHT_LEAN_DEGREES_PER_SPEED: float = 0.012
const FLIGHT_LEAN_MAX_DEGREES: float = 12.0
const FLIGHT_LAG_RATE: float = 7.0
const FLIGHT_KICK_PER_SPEED: float = 0.00012
const FLIGHT_KICK_MAX: float = 0.9

# --- İniş ---
const LAND_SQUASH_SECONDS: float = 0.09
const LAND_SETTLE_SECONDS: float = 0.24
const LAND_SQUASH: Vector2 = Vector2(1.10, 0.88)
const LAND_TOTAL_SECONDS: float = LAND_SQUASH_SECONDS + LAND_SETTLE_SECONDS

# --- Katlama (uçuşun içinde) ---
## Uçuş süresinin hangi diliminde katlanır: yanlar içeri, sonra alt yukarı.
const FOLD_START: float = 0.16
const FOLD_END: float = 0.78
const FOLD_SIDES_SHARE: float = 0.42
const FOLD_SIDES_SCALE_X: float = 0.58
const FOLD_SIDES_SCALE_Y: float = 1.06
const FOLD_BOTTOM_SCALE_Y: float = 0.36
const FOLD_CROSSFADE_FROM: float = 0.45
## Sprite'ta çamaşırın görsel ağırlık merkezi (boyutun oranı): katlanırken eksen buradan kayar.
const FOLD_CENTER_RATIO: float = 0.45
const FOLDED_POP_FROM: float = 0.78

# --- Sıra / yığılma ---
const STAGGER_SECONDS: float = 0.1
const STAGGER_MIN_SECONDS: float = 0.05
const STACK_TILT_DEGREES: float = 4.0
const STACK_SHADE: float = 0.07

# --- Sepet tepkisi ---
const BASKET_BOUNCE_SQUASH: Vector2 = Vector2(1.05, 0.93)
const BASKET_BOUNCE_IN_SECONDS: float = 0.1
const BASKET_BOUNCE_OUT_SECONDS: float = 0.3
const BASKET_HOP_SCALE: float = 1.1
const BASKET_BREATH: float = 0.008
const BASKET_BREATH_SPEED: float = 1.9

# --- Sepet tamamlanma ---
const COMPLETE_PRESS_SECONDS: float = 0.2
const COMPLETE_PRESS_RATIO: float = 0.45
const COMPLETE_HOLD_SECONDS: float = 0.08
const COMPLETE_ABSORB_SECONDS: float = 0.24
const COMPLETE_BAND_GLOW: float = 0.45
const COMPLETE_BAND_SECONDS: float = 0.7
const BASKET_SLIDE: float = 330.0
const BASKET_SLIDE_OUT_SECONDS: float = 0.35
const BASKET_ARRIVE_DELAY: float = 0.1
const BASKET_ARRIVE_SECONDS: float = 0.55
const BASKET_ARRIVE_FROM_SCALE: float = 0.9

# --- Parçacıklar (düşük sayı, yumuşak) ---
const PUFF_COUNT: int = 7
const PUFF_LIFETIME: float = 0.7
const PUFF_POOL: int = 6
const SPARKLE_COUNT: int = 14
const SPARKLE_LIFETIME: float = 1.0
const SPARKLE_POOL: int = 2

# --- Sallanma / fırtına ---
const SWAY_CALM: float = 1.0
const SWAY_STORM: float = 3.4
const SWAY_UPDATE_STEP: float = 0.03
const NEIGHBOUR_KICK: float = 0.55
const NEIGHBOUR_RADIUS: float = 420.0
const NEIGHBOUR_DECAY: float = 2.6
const NEIGHBOUR_FREQUENCY: float = 7.0
const NEIGHBOUR_EPSILON: float = 0.005

# --- Tehlike nabzı ---
const DANGER_PULSE_SPEED: float = 0.0042
const DANGER_BLEND_RATE: float = 4.0

# --- Katman (kazandın/kaybettin) ---
const OVERLAY_FADE_SECONDS: float = 0.35
const OVERLAY_RISE_SECONDS: float = 0.5
const OVERLAY_RISE_DISTANCE: float = 80.0
const WIN_DELAY_SECONDS: float = 0.45
const LOSE_DELAY_SECONDS: float = 0.6

# --- Kural çeşitlemeleri (joker, leke, zincir, rüzgâr, kipler) ---
## Gösterge/rozet nabzı (sayaç azaldı, sipariş tamam).
const RULES_PULSE_SCALE: float = 1.18
const RULES_PULSE_IN_SECONDS: float = 0.1
const RULES_PULSE_OUT_SECONDS: float = 0.26
## Rüzgârla savrulan çamaşır komşusunun üstüne yumuşakça kayar (yolun bu oranı kadar).
const WIND_FLIP_SECONDS: float = 0.5
const WIND_FLIP_SHARE: float = 0.55
const WIND_FLIP_DROP: float = 26.0
## Patron: ikinci tahta sağdan kayarak gelir.
const SCREEN_SLIDE_DELAY: float = 0.35
const SCREEN_SLIDE_SECONDS: float = 0.8
## Joker sepet rengini alırken gökkuşağı söner.
const JOKER_FADE_SECONDS: float = 0.3
## Leke kuruyunca rozet yavaşça solar.
const STAIN_DRY_SECONDS: float = 0.45
## "Hamle bitti" duyurusu kayıp sayfasından önce kısa süre görünür.
const ANNOUNCE_SECONDS: float = 1.1


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


## Hafif aşan varış (sepet gelişi gibi yerlerde Tween'siz kullanım için).
static func smooth(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


## Kuyruk uzadıkça bekleme kısalır: hızlı oynayan oyuncunun animasyonu geride kalmaz.
static func stagger(queued: int) -> float:
	return maxf(STAGGER_MIN_SECONDS, STAGGER_SECONDS / (1.0 + 0.6 * float(queued)))


## Uçuşun yay yüksekliği mesafeyle büyür (kısa yolda küçük, uzakta zarif kavis).
static func arc_height(distance: float) -> float:
	return clampf(distance * FLIGHT_ARC_PER_DISTANCE, FLIGHT_ARC_MIN, FLIGHT_ARC_MAX)


## Uçuş + hazırlık + iniş: kuyruğun "bu çamaşır ne zaman tamamen oturur" hesabı.
static func total_fly_seconds() -> float:
	return ANTICIPATE_SECONDS + FLIGHT_SECONDS + LAND_TOTAL_SECONDS
