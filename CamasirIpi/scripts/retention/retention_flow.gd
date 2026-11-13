class_name RetentionFlow
extends RefCounted

## Saf mantık sınıflarını (Missions, Milestones, WeeklyEvent, Comeback) kayda (`RetentionStore`),
## ödüle ve analitiğe bağlayan yapıştırıcı. UI yalnız bunları çağırır; kararlar mantık sınıflarındadır.
## Sıra kuralı (DailyStore ile aynı): ÖNCE durum yazılır, SONRA ödül verilir; yarıda kapanırsa çift ödül olmaz.

const KEY_MISSIONS: String = "missions"
const KEY_MILESTONES: String = "milestones"
const KEY_WEEKLY: String = "weekly"
const KEY_COMEBACK: String = "comeback"
const KEY_POPUPS: String = "popups"
const KEY_WEEKLY_NOTE: String = "weekly_note"


static func missions_unlocked() -> bool:
	return RetentionStore.level() >= Missions.unlock_level(RetentionData.missions())


static func weekly_unlocked() -> bool:
	return RetentionStore.level() >= WeeklyEvent.unlock_level(RetentionData.weekly())


## Olay girişi (RetentionEvents.emit buraya gelir).
static func handle(event_id: String, amount: int, data: Dictionary, today: String) -> void:
	RetentionStore.mark_event_seen(event_id)
	if event_id == RetentionEvents.LEVEL_STARTED:
		touch_session(today)
	if missions_unlocked():
		var cfg: Dictionary = RetentionData.missions()
		var state: Dictionary = sync_missions(today)
		var result: Dictionary = Missions.apply_event(state, event_id, amount, data, cfg)
		if bool(result["changed"]):
			var next: Dictionary = result["state"] as Dictionary
			RetentionStore.put(KEY_MISSIONS, next)
			if Missions.done_count(next) > Missions.done_count(state):
				AnalyticsLog.record("ret_mission_done", {"done": Missions.done_count(next),
					"level": RetentionStore.level()})
	if weekly_unlocked():
		var weekly_cfg: Dictionary = RetentionData.weekly()
		var week: Dictionary = sync_weekly(today)
		var applied: Dictionary = WeeklyEvent.apply_event(week, event_id, amount, data, weekly_cfg)
		if bool(applied["changed"]):
			var week_next: Dictionary = applied["state"] as Dictionary
			RetentionStore.put(KEY_WEEKLY, week_next)
			var theme: Dictionary = WeeklyEvent.theme_by_id(weekly_cfg, String(week_next["theme"]))
			if WeeklyEvent.reached_count(week_next, theme) > WeeklyEvent.reached_count(week, theme):
				AnalyticsLog.record("ret_weekly_tier_reached", {"theme": String(week_next["theme"]),
					"tier": WeeklyEvent.reached_count(week_next, theme)})


# --- Görevler ----------------------------------------------------------------

## Bugünün görev durumu (gün değiştiyse yeni liste + dünün tamamlanmışları otomatik verilir).
static func sync_missions(today: String) -> Dictionary:
	var state: Dictionary = RetentionStore.get_dict(KEY_MISSIONS)
	if not missions_unlocked():
		return state
	var result: Dictionary = Missions.sync(state, today, RetentionStore.level(),
		RetentionData.missions(), RetentionStore.live_events())
	var next: Dictionary = result["state"] as Dictionary
	if bool(result["rolled"]):
		RetentionStore.put(KEY_MISSIONS, next)
		var carried: Dictionary = RetentionRewards.empty()
		for template: Dictionary in result["carry"] as Array[Dictionary]:
			carried = RetentionRewards.merge(carried, RetentionStore.resolve(template, DailyDate.day_index(today)))
		if not RetentionRewards.is_empty(carried):
			RetentionStore.grant(carried)
			AnalyticsLog.record("ret_mission_autogrant", {"coins": int(carried["coins"])})
	return next


static func claim_mission(index: int, today: String) -> Dictionary:
	var state: Dictionary = sync_missions(today)
	var result: Dictionary = Missions.claim(state, index)
	if not bool(result["ok"]):
		return {}
	RetentionStore.put(KEY_MISSIONS, result["state"])
	var reward: Dictionary = RetentionStore.resolve(result["template"] as Dictionary,
		index + DailyDate.day_index(today))
	RetentionStore.grant(reward)
	var item: Dictionary = Missions.items(state)[index]
	AnalyticsLog.record("ret_mission_claim", {"id": String(item["id"]), "level": RetentionStore.level(),
		"coins": int(reward["coins"])})
	return reward


static func claim_chest(today: String) -> Dictionary:
	var state: Dictionary = sync_missions(today)
	var result: Dictionary = Missions.claim_chest(state, RetentionData.missions())
	if not bool(result["ok"]):
		return {}
	RetentionStore.put(KEY_MISSIONS, result["state"])
	var reward: Dictionary = RetentionStore.resolve(result["template"] as Dictionary,
		DailyDate.day_index(today))
	RetentionStore.grant(reward)
	AnalyticsLog.record("ret_mission_chest", {"level": RetentionStore.level(), "coins": int(reward["coins"])})
	return reward


# --- Kilometre taşları -------------------------------------------------------

static func milestone_state() -> Dictionary:
	return RetentionStore.get_dict(KEY_MILESTONES)


static func claim_milestone(level: int) -> Dictionary:
	var result: Dictionary = Milestones.claim(milestone_state(), level, RetentionStore.level(),
		RetentionData.milestones())
	if not bool(result["ok"]):
		return {}
	RetentionStore.put(KEY_MILESTONES, result["state"])
	var reward: Dictionary = RetentionStore.resolve(result["template"] as Dictionary, level)
	RetentionStore.grant(reward)
	AnalyticsLog.record("ret_milestone_claim", {"milestone": level, "coins": int(reward["coins"]),
		"stars": int(reward["stars"])})
	return reward


# --- Haftalık etkinlik -------------------------------------------------------

## Güncel hafta durumu; hafta bittiyse yenisi kurulur, alınmamış kademeler otomatik verilir.
static func sync_weekly(today: String) -> Dictionary:
	var state: Dictionary = RetentionStore.get_dict(KEY_WEEKLY)
	if not weekly_unlocked():
		return state
	var result: Dictionary = WeeklyEvent.sync(state, today, RetentionData.weekly())
	var next: Dictionary = result["state"] as Dictionary
	if bool(result["rolled"]):
		RetentionStore.put(KEY_WEEKLY, next)
		var carried: Dictionary = RetentionRewards.empty()
		for template: Dictionary in result["carry"] as Array[Dictionary]:
			carried = RetentionRewards.merge(carried, RetentionStore.resolve(template, DailyDate.day_index(today)))
		if not RetentionRewards.is_empty(carried):
			RetentionStore.grant(carried)
			# Sayfa açılınca tek seferlik bilgi satırı için not düşülür.
			RetentionStore.put(KEY_WEEKLY_NOTE, {"coins": int(carried["coins"])})
			AnalyticsLog.record("ret_weekly_autogrant", {"coins": int(carried["coins"])})
	return next


static func claim_weekly_tier(tier: int, today: String) -> Dictionary:
	var state: Dictionary = sync_weekly(today)
	var result: Dictionary = WeeklyEvent.claim(state, tier, RetentionData.weekly())
	if not bool(result["ok"]):
		return {}
	RetentionStore.put(KEY_WEEKLY, result["state"])
	var reward: Dictionary = RetentionStore.resolve(result["template"] as Dictionary,
		tier + DailyDate.day_index(today))
	RetentionStore.grant(reward)
	AnalyticsLog.record("ret_weekly_claim", {"theme": String(state["theme"]), "tier": tier + 1,
		"coins": int(reward["coins"])})
	return reward


# --- Geri dönüş + oturum serisi ---------------------------------------------

static func comeback_state() -> Dictionary:
	return RetentionStore.get_dict(KEY_COMEBACK)


## Bugünkü oturumu işler (idempotent). Yeni bekleyen hediye oluştuysa analitik yazar.
static func touch_session(today: String) -> void:
	var state: Dictionary = comeback_state()
	var ctx: Dictionary = {"level": RetentionStore.level(), "unlock_levels": RetentionStore.unlock_levels(),
		"fallback_coins": RetentionStore.fallback_coins()}
	var next: Dictionary = Comeback.touch(state, today, RetentionData.comeback(), ctx)
	if next == state:
		return
	RetentionStore.put(KEY_COMEBACK, next)
	if Comeback.has_pending(next) and not Comeback.has_pending(state):
		var info: Dictionary = Comeback.pending(next)
		AnalyticsLog.record("ret_comeback_pending", {"away": int(info.get("away", 0)),
			"streak": int(info.get("streak", 0))})


static func claim_comeback() -> Dictionary:
	var result: Dictionary = Comeback.claim_pending(comeback_state())
	if not bool(result["ok"]):
		return {}
	var info: Dictionary = Comeback.pending(comeback_state())
	RetentionStore.put(KEY_COMEBACK, result["state"])
	var reward: Dictionary = result["reward"] as Dictionary
	RetentionStore.grant(reward)
	AnalyticsLog.record("ret_comeback_claim", {"away": int(info.get("away", 0)),
		"streak": int(info.get("streak", 0)), "coins": int(reward["coins"])})
	return reward
