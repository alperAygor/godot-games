class_name RunScoring
extends RefCounted

## Saf mantık: hasar oranı -> yıldız, ücret çarpanı, itibar cezası.
## Sahneye bağımlı değil; birim testle sabitlenir.
##
## Eşikler bir oyun kuralıdır (kodda), ücret tabanı dengedir (`data/balance.json`).

const DAMAGE_TWO_STARS: float = 0.25
const DAMAGE_ONE_STAR: float = 0.60
const DAMAGE_BROKEN: float = 1.0

const MULTIPLIER_PERFECT: float = 1.2
const MULTIPLIER_TWO: float = 1.0
const MULTIPLIER_ONE: float = 0.6
const MULTIPLIER_ZERO: float = 0.2
const MULTIPLIER_BROKEN: float = 0.0


static func stars_for_damage(damage: float) -> int:
	if damage <= 0.0:
		return 3
	if damage <= DAMAGE_TWO_STARS:
		return 2
	if damage <= DAMAGE_ONE_STAR:
		return 1
	return 0


static func multiplier_for_damage(damage: float) -> float:
	if damage >= DAMAGE_BROKEN:
		return MULTIPLIER_BROKEN
	if damage <= 0.0:
		return MULTIPLIER_PERFECT
	if damage <= DAMAGE_TWO_STARS:
		return MULTIPLIER_TWO
	if damage <= DAMAGE_ONE_STAR:
		return MULTIPLIER_ONE
	return MULTIPLIER_ZERO


static func reputation_penalty(damage: float) -> int:
	if damage >= DAMAGE_BROKEN:
		return -2
	if damage > DAMAGE_ONE_STAR:
		return -1
	return 0


## Tek giriş noktası: {damage, stars, multiplier, fee, reputation}.
static func compute(damage: float, base_fee: int) -> Dictionary:
	var clamped: float = clampf(damage, 0.0, 1.0)
	var multiplier: float = multiplier_for_damage(clamped)
	return {
		"damage": clamped,
		"stars": stars_for_damage(clamped),
		"multiplier": multiplier,
		"fee": int(round(float(base_fee) * multiplier)),
		"reputation": reputation_penalty(clamped),
	}
