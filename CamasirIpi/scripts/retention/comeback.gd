class_name Comeback
extends RefCounted

## Geri dönüş hediyesi + oturum serisi (saf mantık; saat/Progress yok).
## Durum: {"last_day": "YYYY-MM-DD", "run": int, "pending": {reward, away, streak}}.
## Neden hediye "bekleyen" olarak saklanır: sessizce jeton eklemek yerine oyuncu bir sayfada
## görüp tek dokunuşla alır; uygulama arada kapanırsa hediye kaybolmaz, çift de verilmez.
## Seri 1..7 döngüdür (8. gün yine 1): hediye yalnız 3. ve 7. günde (takvimden ayrı, küçük).
## "Uzakta" = son oyun gününden bugüne gün farkı (Pazartesi'den Çarşamba'ya 2 gün).

const KEY_LAST_DAY: String = "last_day"
const KEY_RUN: String = "run"
const KEY_PENDING: String = "pending"
const DEFAULT_CYCLE: int = 7
const DEFAULT_MIN_AWAY: int = 2


static func cycle(cfg: Dictionary) -> int:
	return maxi(int((cfg.get("streak", {}) as Dictionary).get("cycle", DEFAULT_CYCLE)), 1)


## Serinin döngü içindeki konumu (1..7); hiç oynanmadıysa 0.
static func streak_position(state: Dictionary, cfg: Dictionary) -> int:
	var run: int = int(state.get(KEY_RUN, 0))
	return 0 if run <= 0 else (run - 1) % cycle(cfg) + 1


static func gift_for_away(away_days: int, cfg: Dictionary) -> Dictionary:
	for gift: Variant in cfg.get("gifts", []) as Array:
		var tier: Dictionary = gift as Dictionary
		if away_days >= int(tier.get("from", 0)) and away_days <= int(tier.get("to", 0)):
			var template: Dictionary = {
				"coins": int(tier.get("coins_base", 0)) + int(tier.get("coins_per_day", 0)) * away_days,
				"stars": int(tier.get("stars", 0)),
				"booster": String(tier.get("booster", "")),
				"count": int(tier.get("count", 0)),
			}
			return template
	return {}


static func streak_bonus(position: int, cfg: Dictionary) -> int:
	var table: Variant = (cfg.get("streak", {}) as Dictionary).get("bonus", {})
	return int((table as Dictionary).get(str(position), 0)) if table is Dictionary else 0


static func pending(state: Dictionary) -> Dictionary:
	var raw: Variant = state.get(KEY_PENDING, {})
	return raw as Dictionary if raw is Dictionary else {}


static func has_pending(state: Dictionary) -> bool:
	return not pending(state).is_empty()


## Bugünkü oturumu işler (aynı gün tekrar çağrı etkisizdir). `ctx`: {level, unlock_levels, fallback_coins}.
static func touch(state: Dictionary, today: String, cfg: Dictionary, ctx: Dictionary) -> Dictionary:
	var last_day: String = String(state.get(KEY_LAST_DAY, ""))
	if last_day == today:
		return state
	var next: Dictionary = state.duplicate(true)
	var gap: int = DailyDate.days_between(last_day, today) if not last_day.is_empty() else DailyDate.NO_DATE
	if gap == DailyDate.NO_DATE:
		next[KEY_RUN] = 1
	elif gap < 0:
		# Saat geri alınmış: seriyi bozma, günü de ilerletme.
		return state
	elif gap == 1:
		next[KEY_RUN] = int(state.get(KEY_RUN, 0)) + 1
	else:
		next[KEY_RUN] = 1
	next[KEY_LAST_DAY] = today
	var reward: Dictionary = RetentionRewards.empty()
	var away: int = 0
	var level: int = int(ctx.get("level", 1))
	var min_away: int = int(cfg.get("min_away_days", DEFAULT_MIN_AWAY))
	if gap != DailyDate.NO_DATE and gap >= min_away and level >= int(cfg.get("min_level", 1)):
		away = gap
		reward = RetentionRewards.resolve(gift_for_away(gap, cfg), level, gap,
			ctx.get("unlock_levels", {}) as Dictionary, int(ctx.get("fallback_coins", 0)))
	var position: int = streak_position(next, cfg)
	var bonus: int = streak_bonus(position, cfg)
	if bonus > 0:
		reward = RetentionRewards.merge(reward, {"coins": bonus})
	if not RetentionRewards.is_empty(reward):
		var previous: Dictionary = pending(state)
		var merged: Dictionary = RetentionRewards.merge(
			RetentionRewards.normalize(previous.get("reward", {})), reward)
		next[KEY_PENDING] = {"reward": merged, "away": maxi(away, int(previous.get("away", 0))),
			"streak": position if bonus > 0 else int(previous.get("streak", 0))}
	return next


## Dönen: {"ok", "state", "reward"}.
static func claim_pending(state: Dictionary) -> Dictionary:
	if not has_pending(state):
		return {"ok": false, "state": state, "reward": RetentionRewards.empty()}
	var next: Dictionary = state.duplicate(true)
	next.erase(KEY_PENDING)
	return {"ok": true, "state": next,
		"reward": RetentionRewards.normalize(pending(state).get("reward", {}))}
