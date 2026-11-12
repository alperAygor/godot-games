class_name EndlessReward
extends RefCounted

## Saf mantık: sonsuz modda level ödülü, kasa ödemesi ve puan. Sözleşme: PROJECT_SPEC §14.
## Teslimat ödülü `DeliveryReward`'a dayanır (hasar çarpanı/yıldız bozulmaz).

const LEVEL_REWARD_STEP: float = 0.25
const CARGO_DIFFICULTY_STEP: float = 0.5
## Kargo kırılınca koşunun kasası bu oranda ödenir (kullanıcı kararı: yarısı).
const BREAK_PAYOUT_FRACTION: float = 0.5
const REASON_BROKEN: String = "broken"


## Zor kargo çarpanı: zorluk 1 -> 1.0, 2 -> 1.5, 3 -> 2.0.
static func cargo_multiplier(difficulty: int) -> float:
	return 1.0 + CARGO_DIFFICULTY_STEP * float(maxi(difficulty, 1) - 1)


static func level_factor(level: int) -> float:
	return 1.0 + LEVEL_REWARD_STEP * float(maxi(level, 1) - 1)


## Bir level'ın teslimat ödülü: {damage, stars, multiplier, gold, scrap, success}.
static func level_reward(level: int, damage: float, profile: Dictionary, bonus: Dictionary = {}) -> Dictionary:
	var base: Dictionary = DeliveryReward.compute(damage, profile, bonus)
	var factor: float = level_factor(level)
	var cargo_mult: float = cargo_multiplier(int(profile.get("difficulty", 1)))
	var result: Dictionary = base.duplicate()
	result["gold"] = int(round(float(base["gold"]) * factor * cargo_mult))
	result["scrap"] = int(round(float(base["scrap"]) * factor))
	result["level"] = maxi(level, 1)
	return result


## Koşu kasasının ödemesi. `broken` -> yarısı (aşağı yuvarlanır); diğerleri tam.
static func payout(banked_gold: int, banked_scrap: int, reason: String) -> Dictionary:
	var gold: int = maxi(banked_gold, 0)
	var scrap: int = maxi(banked_scrap, 0)
	if reason == REASON_BROKEN:
		return {
			"gold": int(floor(float(gold) * BREAK_PAYOUT_FRACTION)),
			"scrap": int(floor(float(scrap) * BREAK_PAYOUT_FRACTION)),
			"fraction": BREAK_PAYOUT_FRACTION,
		}
	return {"gold": gold, "scrap": scrap, "fraction": 1.0}


## Puan: katedilen metre x kargo çarpanı (tam sayıya aşağı yuvarlanır).
static func score(distance_m: float, difficulty: int) -> int:
	if not is_finite(distance_m) or distance_m <= 0.0:
		return 0
	return int(floor(distance_m * cargo_multiplier(difficulty)))
