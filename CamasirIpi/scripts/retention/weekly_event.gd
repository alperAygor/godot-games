class_name WeeklyEvent
extends RefCounted

## Haftalık çamaşır etkinliği (saf mantık). Hafta Pazartesi'de başlar (ISO), Pazar bitince sıfırlanır.
## Durum: {"week": "<Pazartesi anahtarı>", "theme": id, "progress": int, "claimed": [0/1 x5]}.
## Neden zaman baskısı yalnız sayfada: oyun içinde geri sayım yok; kalan gün sadece burada görünür.
## Biten haftanın ulaşılmış ama alınmamış kademeleri `sync` ile "carry" olarak döner (otomatik verilir).

const KEY_WEEK: String = "week"
const KEY_THEME: String = "theme"
const KEY_PROGRESS: String = "progress"
const KEY_CLAIMED: String = "claimed"
const DAYS_PER_WEEK: int = 7
## 1970-01-01 Perşembe'ydi; Pazartesi=0 sayımında 3.
const EPOCH_WEEKDAY: int = 3


static func unlock_level(cfg: Dictionary) -> int:
	return int(cfg.get("unlock_level", 10))


## Pazartesi = 0 ... Pazar = 6.
static func weekday(day_key: String) -> int:
	return posmod(DailyDate.day_index(day_key) + EPOCH_WEEKDAY, DAYS_PER_WEEK)


static func week_start(day_key: String) -> String:
	return DailyDate.add_days(day_key, -weekday(day_key))


## Bugün dahil kalan gün (Pazartesi 7 ... Pazar 1).
static func days_left(day_key: String) -> int:
	return DAYS_PER_WEEK - weekday(day_key)


static func themes(cfg: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for theme: Variant in cfg.get("themes", []) as Array:
		result.append(theme as Dictionary)
	return result


static func theme_by_id(cfg: Dictionary, id: String) -> Dictionary:
	for theme: Dictionary in themes(cfg):
		if String(theme.get("id", "")) == id:
			return theme
	return {}


## Haftanın teması deterministik döner: hafta numarası temalar arasında sırayla ilerler.
static func theme_for(week_key: String, cfg: Dictionary) -> Dictionary:
	var list: Array[Dictionary] = themes(cfg)
	if list.is_empty():
		return {}
	var week_number: int = DailyDate.day_index(week_key) / DAYS_PER_WEEK
	return list[posmod(week_number, list.size())]


static func tier_count(theme: Dictionary) -> int:
	return (theme.get("targets", []) as Array).size()


static func target_of(theme: Dictionary, tier: int) -> int:
	var targets: Array = theme.get("targets", []) as Array
	return int(targets[tier]) if tier >= 0 and tier < targets.size() else 0


static func tier_reward(cfg: Dictionary, tier: int) -> Dictionary:
	var rewards: Array = cfg.get("tier_rewards", []) as Array
	return rewards[tier] as Dictionary if tier >= 0 and tier < rewards.size() else {}


static func new_state(today: String, cfg: Dictionary) -> Dictionary:
	var week_key: String = week_start(today)
	var theme: Dictionary = theme_for(week_key, cfg)
	var claimed: Array = []
	for index: int in range(tier_count(theme)):
		claimed.append(0)
	return {KEY_WEEK: week_key, KEY_THEME: String(theme.get("id", "")),
		KEY_PROGRESS: 0, KEY_CLAIMED: claimed}


static func progress(state: Dictionary) -> int:
	return int(state.get(KEY_PROGRESS, 0))


static func is_tier_claimed(state: Dictionary, tier: int) -> bool:
	var claimed: Array = state.get(KEY_CLAIMED, []) as Array
	return tier >= 0 and tier < claimed.size() and int(claimed[tier]) != 0


static func is_tier_reached(state: Dictionary, theme: Dictionary, tier: int) -> bool:
	return progress(state) >= target_of(theme, tier) and target_of(theme, tier) > 0


## Ulaşılmış ve alınmamış kademeler.
static func claimable_tiers(state: Dictionary, theme: Dictionary) -> Array[int]:
	var result: Array[int] = []
	for tier: int in range(tier_count(theme)):
		if is_tier_reached(state, theme, tier) and not is_tier_claimed(state, tier):
			result.append(tier)
	return result


## Ulaşılan kademe sayısı.
static func reached_count(state: Dictionary, theme: Dictionary) -> int:
	var total: int = 0
	for tier: int in range(tier_count(theme)):
		if is_tier_reached(state, theme, tier):
			total += 1
	return total


## Hafta değiştiyse (ya da hiç yoksa) yeni haftayı kurar. "carry": biten haftanın alınmamış ödül şablonları.
static func sync(state: Dictionary, today: String, cfg: Dictionary) -> Dictionary:
	var week_key: String = week_start(today)
	if String(state.get(KEY_WEEK, "")) == week_key:
		return {"state": state, "carry": [] as Array[Dictionary], "rolled": false}
	var carry: Array[Dictionary] = []
	var old_theme: Dictionary = theme_by_id(cfg, String(state.get(KEY_THEME, "")))
	if not old_theme.is_empty():
		for tier: int in claimable_tiers(state, old_theme):
			carry.append(tier_reward(cfg, tier))
	return {"state": new_state(today, cfg), "carry": carry, "rolled": true}


static func apply_event(state: Dictionary, event_id: String, amount: int, data: Dictionary,
		cfg: Dictionary) -> Dictionary:
	var theme: Dictionary = theme_by_id(cfg, String(state.get(KEY_THEME, "")))
	if theme.is_empty() or not RetentionEvents.accepts(theme, event_id, data):
		return {"state": state, "changed": false}
	var gain: int = RetentionEvents.contribution(theme, amount, data)
	if gain <= 0:
		return {"state": state, "changed": false}
	var next: Dictionary = state.duplicate(true)
	next[KEY_PROGRESS] = progress(state) + gain
	return {"state": next, "changed": true}


## Dönen: {"ok", "state", "template"}.
static func claim(state: Dictionary, tier: int, cfg: Dictionary) -> Dictionary:
	var theme: Dictionary = theme_by_id(cfg, String(state.get(KEY_THEME, "")))
	if theme.is_empty() or not is_tier_reached(state, theme, tier) or is_tier_claimed(state, tier):
		return {"ok": false, "state": state, "template": {}}
	var next: Dictionary = state.duplicate(true)
	(next[KEY_CLAIMED] as Array)[tier] = 1
	return {"ok": true, "state": next, "template": tier_reward(cfg, tier)}
