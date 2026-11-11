class_name DeliveryReward
extends RefCounted

## Saf mantık: hasar oranı + kargo profili -> teslimat ödülü.
## RunScoring (yıldız/çarpan) bozulmadan kullanılır.
## Sözleşme: ARCHITECTURE.md §4.4.


static func compute(damage: float, profile: Dictionary, bonus: Dictionary = {}) -> Dictionary:
	var clamped: float = clampf(damage, 0.0, 1.0)
	var multiplier: float = RunScoring.multiplier_for_damage(clamped)
	var stars: int = RunScoring.stars_for_damage(clamped)
	var gold_pct: float = float(bonus.get("gold_pct", 0.0))
	var base_gold: int = int(profile.get("reward_gold", 0))
	var base_scrap: int = int(profile.get("reward_scrap", 0))
	var gold: int = int(round(float(base_gold) * multiplier * (1.0 + gold_pct)))
	var scrap: int = int(round(float(base_scrap) * (1.0 - clamped)))
	if clamped >= 1.0:
		scrap = 0
	var success: bool = clamped < 1.0
	return {
		"damage": clamped,
		"stars": stars,
		"multiplier": multiplier,
		"gold": gold,
		"scrap": scrap,
		"success": success,
	}
