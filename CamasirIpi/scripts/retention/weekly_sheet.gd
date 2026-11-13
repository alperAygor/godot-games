class_name WeeklySheet
extends RetentionSheet

## Haftalık çamaşır etkinliği: haftanın teması, kalan gün (yalnız burada), 5 kademeli yol.
## Mantık `WeeklyEvent`te; olaylar `RetentionEvents` ile beslenir.

const BIG_SIZE: int = 84
const CLAIM_HEIGHT: float = 132.0
const THEME_DISC: float = 112.0

var _body: VBoxContainer = null
var _cfg: Dictionary = {}
var _track: RetTrack = null


static func open(parent: Node) -> Node:
	var sheet: WeeklySheet = WeeklySheet.new()
	sheet._setup(parent)
	sheet._fill()
	sheet.play_intro()
	AnalyticsLog.record("ret_sheet_open", {"kind": "weekly"})
	return sheet


func _fill() -> void:
	_cfg = RetentionData.weekly()
	if not RetentionFlow.weekly_unlocked():
		_fill_locked(RetentionStrings.weekly_title(), WeeklyEvent.unlock_level(_cfg))
		return
	_body = VBoxContainer.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content().add_child(_body)
	_rebuild()
	play_intro()


func _rebuild() -> void:
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	var state: Dictionary = RetentionFlow.sync_weekly(_today)
	var theme: Dictionary = WeeklyEvent.theme_by_id(_cfg, String(state.get(WeeklyEvent.KEY_THEME, "")))
	if theme.is_empty():
		_body.add_child(UiKit.label("-", RetentionUi.BODY_SIZE))
		return
	var tint: Color = Color(String(theme.get("tint", "38a276")))
	var soft: Color = tint.lerp(Color.WHITE, 0.78)
	var holder: CenterContainer = CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(RetentionUi.disc(String(theme.get("icon", RetentionUi.CHEST_ICON)), soft, tint, THEME_DISC, 52.0))
	_body.add_child(holder)
	_body.add_child(UiKit.spacer(RetentionUi.GAP))
	_body.add_child(UiKit.label(RetentionStrings.theme_title(String(theme["id"])), RetentionUi.TITLE_SIZE))
	_body.add_child(UiKit.spacer(RetentionUi.GAP * 0.4))
	_body.add_child(UiKit.label(RetentionStrings.theme_goal(String(theme["id"])), RetentionUi.BODY_SIZE, UiKit.TEXT_MUTED))
	_body.add_child(UiKit.spacer(RetentionUi.GAP * 0.7))
	_body.add_child(_days_row())
	var note: Dictionary = RetentionStore.get_dict(RetentionFlow.KEY_WEEKLY_NOTE)
	if int(note.get("coins", 0)) > 0:
		_body.add_child(UiKit.spacer(RetentionUi.GAP * 0.5))
		_body.add_child(UiKit.label(RetentionStrings.week_note(int(note["coins"])), RetentionUi.SMALL_SIZE, UiKit.TEXT_MUTED))
		RetentionStore.put(RetentionFlow.KEY_WEEKLY_NOTE, {})
	_body.add_child(UiKit.spacer(RetentionUi.GAP * 1.2))
	_body.add_child(_progress_line(state, theme))
	_body.add_child(UiKit.spacer(RetentionUi.GAP * 0.8))
	_track = _make_track(state, theme, tint)
	_body.add_child(_track)
	_body.add_child(UiKit.spacer(RetentionUi.GAP * 1.0))
	var ready: Array[int] = WeeklyEvent.claimable_tiers(state, theme)
	if ready.is_empty():
		var ok: Button = UiKit.button(UiStrings.ok(), &"SecondaryButton", "", OK_HEIGHT)
		ok.pressed.connect(close)
		_body.add_child(ok)
	else:
		var claim: Button = UiKit.button(RetentionStrings.claim(), &"", RetentionUi.CHEST_ICON, CLAIM_HEIGHT)
		claim.pressed.connect(_on_claim.bind(ready[0], claim))
		_body.add_child(claim)


func _days_row() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: TextureRect = UiKit.tinted_icon(RetentionUi.CLOCK_ICON, RetentionUi.REWARD_ICON, UiKit.TEXT_MUTED)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	row.add_child(UiKit.label(RetentionStrings.days_left(WeeklyEvent.days_left(_today)), RetentionUi.BODY_SIZE, UiKit.TEXT_MUTED))
	return row


## "37" büyük, yanında "/ 60": sıradaki hedefe göre; hepsi bittiyse son hedef.
func _progress_line(state: Dictionary, theme: Dictionary) -> Control:
	var progress: int = WeeklyEvent.progress(state)
	var next_target: int = WeeklyEvent.target_of(theme, WeeklyEvent.tier_count(theme) - 1)
	for tier: int in range(WeeklyEvent.tier_count(theme)):
		if progress < WeeklyEvent.target_of(theme, tier):
			next_target = WeeklyEvent.target_of(theme, tier)
			break
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(UiKit.label(str(progress), BIG_SIZE))
	var total: Label = UiKit.label("/ %d" % next_target, RetentionUi.TITLE_SIZE - 8, UiKit.TEXT_MUTED)
	total.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(total)
	return row


func _make_track(state: Dictionary, theme: Dictionary, tint: Color) -> RetTrack:
	var targets: Array[int] = []
	var coins: Array[int] = []
	var claimed: Array[bool] = []
	for tier: int in range(WeeklyEvent.tier_count(theme)):
		targets.append(WeeklyEvent.target_of(theme, tier))
		coins.append(int(WeeklyEvent.tier_reward(_cfg, tier).get("coins", 0)))
		claimed.append(WeeklyEvent.is_tier_claimed(state, tier))
	var track: RetTrack = RetTrack.new()
	track.setup(targets, coins, claimed, WeeklyEvent.progress(state), tint)
	track.tier_pressed.connect(_on_tier_pressed)
	return track


func _on_tier_pressed(tier: int) -> void:
	_claim_tier(tier, _track.node_global_center(tier))


func _on_claim(tier: int, button: Button) -> void:
	_claim_tier(tier, button.global_position + button.size * 0.5)


func _claim_tier(tier: int, global_center: Vector2) -> void:
	var reward: Dictionary = RetentionFlow.claim_weekly_tier(tier, _today)
	if reward.is_empty():
		return
	RetentionUi.celebrate(self, global_center - global_position, RetentionUi.reward_text(reward))
	AudioService.play_pitched("chest_open", 1.0, -4.0)
	AudioService.play_pitched("coin", 1.0, -6.0)
	_rebuild()
