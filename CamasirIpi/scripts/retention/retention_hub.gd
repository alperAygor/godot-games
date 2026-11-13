class_name RetentionHub
extends RefCounted

## Home'un (ve director'ın) tek giriş noktası: rozet sayısı, açılışta tek pop-up, giriş satırı,
## bildirim planı. Home yalnız bu sınıfı çağırır; sistemler birbirini bilmez.

const KIND_MISSIONS: String = "missions"
const KIND_MILESTONES: String = "milestones"
const KIND_WEEKLY: String = "weekly"
const DEFAULT_VIEW_WIDTH: float = 1080.0
## Başlık (~y 250-330) ile çamaşır ipi (~y 600) arasındaki boşluk.
const ENTRY_ROW_Y: float = 372.0


## Bu türde alınmayı bekleyen şey sayısı (kilitliyse 0).
static func badge_for(kind: String) -> int:
	var today: String = RetentionStore.today()
	match kind:
		KIND_MISSIONS:
			if not RetentionFlow.missions_unlocked():
				return 0
			return Missions.claimable_count(RetentionFlow.sync_missions(today))
		KIND_MILESTONES:
			return Milestones.claimable(RetentionFlow.milestone_state(), RetentionStore.level(),
				RetentionData.milestones()).size()
		KIND_WEEKLY:
			if not RetentionFlow.weekly_unlocked():
				return 0
			var cfg: Dictionary = RetentionData.weekly()
			var state: Dictionary = RetentionFlow.sync_weekly(today)
			return WeeklyEvent.claimable_tiers(state,
				WeeklyEvent.theme_by_id(cfg, String(state.get(WeeklyEvent.KEY_THEME, "")))).size()
	return 0


## Alınabilir her şey (bekleyen geri dönüş hediyesi dahil).
static func badge_count() -> int:
	var total: int = badge_for(KIND_MISSIONS) + badge_for(KIND_MILESTONES) + badge_for(KIND_WEEKLY)
	if Comeback.has_pending(RetentionFlow.comeback_state()):
		total += 1
	return total


static func is_unlocked(kind: String) -> bool:
	match kind:
		KIND_MISSIONS:
			return RetentionFlow.missions_unlocked()
		KIND_WEEKLY:
			return RetentionFlow.weekly_unlocked()
	return true


static func open_sheet(kind: String, parent: Node) -> Node:
	match kind:
		KIND_MISSIONS:
			return MissionsSheet.open(parent)
		KIND_MILESTONES:
			return MilestoneSheet.open(parent)
		KIND_WEEKLY:
			return WeeklySheet.open(parent)
	return null


## Üç küçük ikon düğmesi (görevler, ödül yolu, haftalık) + nokta rozetleri. `parent`e eklenir;
## konumu çağıran verir (ör. `row.position = ...`).
static func build_entry_row(parent: Control) -> Control:
	var row: RetentionEntryRow = RetentionEntryRow.new()
	parent.add_child(row)
	# Varsayılan konum: başlığın altında, yatayda ortalı. Director isterse `position`ı değiştirir.
	var width: float = parent.get_viewport_rect().size.x if parent.is_inside_tree() else DEFAULT_VIEW_WIDTH
	row.position = Vector2((width - row.get_combined_minimum_size().x) * 0.5, ENTRY_ROW_Y)
	return row


## Ana ekran her gösterildiğinde çağrılır. Oturumu işler, bildirimleri yeniler ve EN FAZLA BİR
## sayfa açar (öncelik: geri dönüş/seri hediyesi > ödül yolu > görevler > haftalık).
## Aynı şey için pop-up günde/kilometre taşında bir kez çıkar; sürekli rahatsız etmez.
static func on_home_shown(parent: Node) -> void:
	var today: String = RetentionStore.today()
	RetentionFlow.touch_session(today)
	RetentionFlow.sync_missions(today)
	RetentionFlow.sync_weekly(today)
	refresh_notifications()
	if Comeback.has_pending(RetentionFlow.comeback_state()):
		ComebackSheet.open(parent)
		return
	var popups: Dictionary = RetentionStore.get_dict(RetentionFlow.KEY_POPUPS)
	var ready: Array[int] = Milestones.claimable(RetentionFlow.milestone_state(), RetentionStore.level(),
		RetentionData.milestones())
	if not ready.is_empty() and int(popups.get(KIND_MILESTONES, 0)) != ready[ready.size() - 1]:
		popups[KIND_MILESTONES] = ready[ready.size() - 1]
		RetentionStore.put(RetentionFlow.KEY_POPUPS, popups)
		MilestoneSheet.open(parent)
		return
	if badge_for(KIND_MISSIONS) > 0 and String(popups.get(KIND_MISSIONS, "")) != today:
		popups[KIND_MISSIONS] = today
		RetentionStore.put(RetentionFlow.KEY_POPUPS, popups)
		MissionsSheet.open(parent)
		return
	if badge_for(KIND_WEEKLY) > 0:
		var week_key: String = WeeklyEvent.week_start(today) + ":" + str(badge_for(KIND_WEEKLY))
		if String(popups.get(KIND_WEEKLY, "")) != week_key:
			popups[KIND_WEEKLY] = week_key
			RetentionStore.put(RetentionFlow.KEY_POPUPS, popups)
			WeeklySheet.open(parent)


## Yerel bildirimleri yeniden kurar (aynı kimlik üstüne yazar). Bildirim kapalıysa iptal eder.
static func refresh_notifications() -> void:
	var clock: Dictionary = Time.get_datetime_dict_from_system(false)
	var now: Dictionary = {"day": RetentionStore.today(), "hour": int(clock["hour"]),
		"minute": int(clock["minute"]), "second": int(clock["second"])}
	var flags: Dictionary = {"missions": RetentionFlow.missions_unlocked(), "weekly": RetentionFlow.weekly_unlocked()}
	var planned: Array[Dictionary] = RetentionNotifyPlan.plan(now, flags, RetentionData.core().get("notify", {}) as Dictionary)
	var ids: Array[String] = [RetentionNotifyPlan.ID_DAILY_GIFT, RetentionNotifyPlan.ID_MISSIONS,
		RetentionNotifyPlan.ID_WEEKLY_END]
	for id: String in ids:
		Notifier.cancel(id)
	for entry: Dictionary in planned:
		Notifier.schedule(String(entry["id"]), int(entry["seconds"]), String(entry["title_key"]),
			String(entry["body_key"]))
