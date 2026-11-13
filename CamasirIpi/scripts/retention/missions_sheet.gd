class_name MissionsSheet
extends RetentionSheet

## Günlük görevler sayfası: 3 görev satırı (ikon, kısa metin, ilerleme çubuğu, ödül) ve hepsi
## bitince açılan bonus sandık. Mantık `Missions`ta, kayıt/ödül `RetentionFlow`da.

const ICON_FALLBACK: String = "lucide/check"
const BAR_HEIGHT: float = 14.0
const CLAIM_HEIGHT: float = 100.0
const CLAIM_MIN_WIDTH: float = 230.0
const SIDE_MIN_WIDTH: float = 190.0
const ROW_GAP: int = 16
const DONE_DISC: float = 76.0

var _list: VBoxContainer = null
var _state: Dictionary = {}
var _cfg: Dictionary = {}
var _first_build: bool = true


static func open(parent: Node) -> Node:
	var sheet: MissionsSheet = MissionsSheet.new()
	sheet._setup(parent)
	sheet._fill()
	sheet.play_intro()
	AnalyticsLog.record("ret_sheet_open", {"kind": "missions"})
	return sheet


func _fill() -> void:
	_cfg = RetentionData.missions()
	var unlock: int = Missions.unlock_level(_cfg)
	if not RetentionFlow.missions_unlocked():
		_fill_locked(RetentionStrings.missions_title(), unlock)
		return
	_add_title(RetentionStrings.missions_title())
	_add_gap(RetentionUi.GAP * 0.3)
	var streak: int = Comeback.streak_position(RetentionFlow.comeback_state(), RetentionData.comeback())
	if streak > 0:
		content().add_child(RetentionUi.flame_row(streak))
	_add_gap(RetentionUi.GAP * 0.9)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", ROW_GAP)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content().add_child(_list)
	_add_gap(RetentionUi.GAP * 1.2)
	_add_ok()
	_rebuild()


func _rebuild() -> void:
	_state = RetentionFlow.sync_missions(_today)
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var list: Array[Dictionary] = Missions.items(_state)
	for index: int in range(list.size()):
		_list.add_child(_mission_row(index, list[index]))
	_list.add_child(_chest_row())
	_first_build = false


func _mission_row(index: int, item: Dictionary) -> Control:
	var def: Dictionary = Missions.definition(_cfg, String(item["id"]))
	var target: int = int(item["target"])
	var progress: int = int(item["progress"])
	var done: bool = Missions.is_done(item)
	var claimed: bool = bool(item.get("claimed", false))
	var card: PanelContainer = RetentionUi.row_card()
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var icon_name: String = String(def.get("icon", ICON_FALLBACK))
	row.add_child(RetentionUi.disc(icon_name, UiKit.ACCENT_SOFT if done else Color(1, 1, 1, 0.7),
		UiKit.ACCENT if done else UiKit.TEXT_MUTED))
	var middle: VBoxContainer = VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	middle.add_theme_constant_override("separation", 14)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(middle)
	var title: Label = RetentionUi.left_label(RetentionStrings.mission_text(def, target), RetentionUi.BODY_SIZE)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(120.0, 0.0)
	middle.add_child(title)
	var bar: RetBar = RetBar.new()
	bar.setup(BAR_HEIGHT)
	bar.fill_color = UiKit.GOLD if done and not claimed else UiKit.ACCENT
	middle.add_child(bar)
	bar.set_fraction(float(progress) / float(maxi(target, 1)), false)
	row.add_child(_side(index, item, done, claimed, progress, target))
	return card


## Sağ sütun: ilerleme + ödül / "Al" düğmesi / onay.
func _side(index: int, item: Dictionary, done: bool, claimed: bool, progress: int, target: int) -> Control:
	var reward: Dictionary = RetentionUi.preview(item.get("reward", {}) as Dictionary)
	if claimed:
		var holder: CenterContainer = CenterContainer.new()
		holder.custom_minimum_size = Vector2(SIDE_MIN_WIDTH, 0.0)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var check: Panel = RetentionUi.disc(RetentionUi.CHECK_ICON, UiKit.ACCENT_SOFT, UiKit.ACCENT, DONE_DISC, 36.0)
		holder.add_child(check)
		return holder
	if done:
		var button: Button = UiKit.button(RetentionUi.reward_text(reward), &"", RetentionUi.COIN_ICON, CLAIM_HEIGHT)
		button.custom_minimum_size = Vector2(CLAIM_MIN_WIDTH, CLAIM_HEIGHT)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_on_claim.bind(index, button))
		return button
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(SIDE_MIN_WIDTH, 0.0)
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(UiKit.label("%d/%d" % [progress, target], RetentionUi.BODY_SIZE, UiKit.TEXT_MUTED))
	column.add_child(RetentionUi.reward_chips(reward, RetentionUi.SMALL_SIZE, UiKit.TEXT_MUTED))
	return column


func _chest_row() -> Control:
	var done_count: int = Missions.done_count(_state)
	var total: int = Missions.items(_state).size()
	var ready: bool = Missions.chest_ready(_state)
	var opened: bool = bool(_state.get(Missions.KEY_CHEST, false))
	var reward: Dictionary = RetentionUi.preview(_cfg.get("chest", {}) as Dictionary)
	var card: PanelContainer = RetentionUi.row_card()
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	row.add_child(RetentionUi.disc(RetentionUi.CHEST_ICON, RetentionUi.WARM_SOFT if not opened else UiKit.ACCENT_SOFT,
		UiKit.GOLD if not opened else UiKit.ACCENT))
	var middle: VBoxContainer = VBoxContainer.new()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	middle.add_theme_constant_override("separation", 14)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(middle)
	middle.add_child(RetentionUi.left_label(RetentionStrings.chest_bonus(), RetentionUi.BODY_SIZE))
	var bar: RetBar = RetBar.new()
	bar.setup(BAR_HEIGHT)
	bar.fill_color = UiKit.GOLD
	middle.add_child(bar)
	bar.set_fraction(float(done_count) / float(maxi(total, 1)), false)
	if opened:
		var holder: CenterContainer = CenterContainer.new()
		holder.custom_minimum_size = Vector2(SIDE_MIN_WIDTH, 0.0)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(RetentionUi.disc(RetentionUi.CHECK_ICON, UiKit.ACCENT_SOFT, UiKit.ACCENT, DONE_DISC, 36.0))
		row.add_child(holder)
	elif ready:
		var button: Button = UiKit.button(RetentionUi.reward_text(reward), &"", RetentionUi.CHEST_ICON, CLAIM_HEIGHT)
		button.custom_minimum_size = Vector2(CLAIM_MIN_WIDTH, CLAIM_HEIGHT)
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.pressed.connect(_on_chest.bind(button))
		row.add_child(button)
	else:
		var column: VBoxContainer = VBoxContainer.new()
		column.custom_minimum_size = Vector2(SIDE_MIN_WIDTH, 0.0)
		column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		column.add_theme_constant_override("separation", 6)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(UiKit.label("%d/%d" % [done_count, total], RetentionUi.BODY_SIZE, UiKit.TEXT_MUTED))
		column.add_child(RetentionUi.reward_chips(reward, RetentionUi.SMALL_SIZE, UiKit.TEXT_MUTED))
		row.add_child(column)
	return card


func _on_claim(index: int, button: Button) -> void:
	var reward: Dictionary = RetentionFlow.claim_mission(index, _today)
	if reward.is_empty():
		return
	_celebrate_at(button, reward)
	_rebuild()


func _on_chest(button: Button) -> void:
	var reward: Dictionary = RetentionFlow.claim_chest(_today)
	if reward.is_empty():
		return
	_celebrate_at(button, reward)
	_rebuild()
