class_name MilestoneSheet
extends RetentionSheet

## Ödül yolu: seviye kilometre taşlarındaki sandıklar. Sayfa "şu an neredeyim, sıradaki sandık
## ne, kaç seviye kaldı" sorusunu tek bakışta cevaplar. Mantık `Milestones`ta.

const NODE_DISC: float = 112.0
const NODE_ICON: float = 52.0
const LINE_HEIGHT: float = 10.0
const BIG_TEXT_SIZE: int = 56
const CLAIM_HEIGHT: float = 132.0
const STRIP_HEIGHT: float = 372.0
const PULSE_SCALE: float = 1.07
const PULSE_SECONDS: float = 0.9

var _strip_host: VBoxContainer = null
var _head_host: VBoxContainer = null
var _foot_host: VBoxContainer = null
var _cfg: Dictionary = {}
var _claim_nodes: Dictionary = {}


static func open(parent: Node) -> Node:
	var sheet: MilestoneSheet = MilestoneSheet.new()
	sheet._setup(parent)
	sheet._fill()
	sheet.play_intro()
	AnalyticsLog.record("ret_sheet_open", {"kind": "milestones"})
	return sheet


func _fill() -> void:
	_cfg = RetentionData.milestones()
	_add_title(RetentionStrings.milestones_title())
	_add_gap(RetentionUi.GAP)
	_head_host = VBoxContainer.new()
	_head_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content().add_child(_head_host)
	_add_gap(RetentionUi.GAP * 1.2)
	_strip_host = VBoxContainer.new()
	_strip_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content().add_child(_strip_host)
	_add_gap(RetentionUi.GAP * 1.2)
	_foot_host = VBoxContainer.new()
	_foot_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content().add_child(_foot_host)
	_rebuild()


func _rebuild() -> void:
	for host: VBoxContainer in [_head_host, _strip_host, _foot_host]:
		for child: Node in host.get_children():
			host.remove_child(child)
			child.queue_free()
	_claim_nodes.clear()
	var level: int = RetentionStore.level()
	var state: Dictionary = RetentionFlow.milestone_state()
	var ready: Array[int] = Milestones.claimable(state, level, _cfg)
	_head_host.add_child(_head(level, ready))
	_strip_host.add_child(_strip(state, level))
	if ready.is_empty():
		_add_ok_to(_foot_host)
	else:
		var claim: Button = UiKit.button(RetentionStrings.claim(), &"", RetentionUi.CHEST_ICON, CLAIM_HEIGHT)
		claim.pressed.connect(_on_claim.bind(ready[0], claim))
		_foot_host.add_child(claim)


func _add_ok_to(host: VBoxContainer) -> void:
	var ok: Button = UiKit.button(UiStrings.ok(), &"SecondaryButton", "", OK_HEIGHT)
	ok.pressed.connect(close)
	host.add_child(ok)


## Büyük sayı: sıradaki sandığa kaç seviye var (alınacak sandık varsa onu müjdeler).
func _head(level: int, ready: Array[int]) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var togo: int = Milestones.levels_to_go(level, _cfg)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	var chest: Panel = RetentionUi.disc(RetentionUi.CHEST_ICON, RetentionUi.WARM_SOFT, UiKit.GOLD, 96.0, 46.0)
	row.add_child(chest)
	row.add_child(UiKit.label(RetentionStrings.to_go(togo), BIG_TEXT_SIZE))
	return column


func _strip(state: Dictionary, level: int) -> Control:
	var entries: Array[Dictionary] = Milestones.window(state, level, _cfg, int(_cfg.get("visible", Milestones.DEFAULT_VISIBLE)))
	var holder: Control = Control.new()
	holder.custom_minimum_size = Vector2(0.0, STRIP_HEIGHT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: Control = Control.new()
	line.set_anchors_preset(Control.PRESET_FULL_RECT)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(line)
	var fill_to: float = _line_fill(entries, level)
	line.draw.connect(_draw_line.bind(line, entries.size(), fill_to))
	var row: HBoxContainer = HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(row)
	for entry: Dictionary in entries:
		row.add_child(_node(entry))
	return holder


## Çizginin dolu kısmı (0..1, düğüm merkezleri arası): ulaşılmışlar tam, sıradaki ilerleme oranı kadar.
func _line_fill(entries: Array[Dictionary], level: int) -> float:
	if entries.size() < 2:
		return 0.0
	var reached: int = 0
	for index: int in range(entries.size()):
		var status: int = int(entries[index]["status"])
		if status == Milestones.STATUS_CLAIMED or status == Milestones.STATUS_CLAIMABLE:
			reached = index + 1
	if reached == 0:
		return 0.0
	if reached >= entries.size():
		return 1.0
	# Son ulaşılan düğümün merkezinden sıradakine doğru, gerçek ilerleme oranı kadar.
	var gaps: float = float(entries.size() - 1)
	return clampf((float(reached - 1) + Milestones.progress_fraction(level, _cfg)) / gaps, 0.0, 1.0)


func _draw_line(line: Control, count: int, fill_to: float) -> void:
	if count < 2:
		return
	var cell: float = line.size.x / float(count)
	var y: float = NODE_DISC * 0.5
	var from_x: float = cell * 0.5
	var to_x: float = line.size.x - cell * 0.5
	var back: StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = Color("e6e2d5")
	back.set_corner_radius_all(int(LINE_HEIGHT * 0.5))
	line.draw_style_box(back, Rect2(Vector2(from_x, y - LINE_HEIGHT * 0.5), Vector2(to_x - from_x, LINE_HEIGHT)))
	if fill_to > 0.0:
		var front: StyleBoxFlat = StyleBoxFlat.new()
		front.bg_color = UiKit.ACCENT
		front.set_corner_radius_all(int(LINE_HEIGHT * 0.5))
		line.draw_style_box(front, Rect2(Vector2(from_x, y - LINE_HEIGHT * 0.5),
			Vector2(maxf((to_x - from_x) * fill_to, LINE_HEIGHT), LINE_HEIGHT)))


func _node(entry: Dictionary) -> Control:
	var status: int = int(entry["status"])
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc_bg: Color = Color("e9e6dc")
	var disc_fg: Color = UiKit.TEXT_MUTED
	var icon_name: String = RetentionUi.CHEST_ICON
	match status:
		Milestones.STATUS_CLAIMED:
			disc_bg = UiKit.ACCENT_SOFT
			disc_fg = UiKit.ACCENT
			icon_name = RetentionUi.CHECK_ICON
		Milestones.STATUS_CLAIMABLE:
			disc_bg = UiKit.GOLD
			disc_fg = Color.WHITE
		Milestones.STATUS_NEXT:
			disc_bg = RetentionUi.WARM_SOFT
			disc_fg = UiKit.GOLD
	var holder: CenterContainer = CenterContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc: Panel = RetentionUi.disc(icon_name, disc_bg, disc_fg, NODE_DISC, NODE_ICON)
	holder.add_child(disc)
	column.add_child(holder)
	if status == Milestones.STATUS_CLAIMABLE:
		_pulse(disc)
		_claim_nodes[int(entry["level"])] = disc
	var level_color: Color = UiKit.TEXT if status != Milestones.STATUS_LOCKED else UiKit.TEXT_MUTED
	column.add_child(UiKit.label(str(int(entry["level"])), 40, level_color))
	var reward: Dictionary = RetentionUi.preview(entry.get("reward", {}) as Dictionary)
	var reward_column: VBoxContainer = VBoxContainer.new()
	reward_column.alignment = BoxContainer.ALIGNMENT_BEGIN
	reward_column.add_theme_constant_override("separation", 2)
	reward_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_column.modulate = Color(1, 1, 1, 0.45) if status == Milestones.STATUS_CLAIMED else Color.WHITE
	column.add_child(reward_column)
	_reward_lines(reward_column, reward)
	return column


## Ödülü alt alta küçük satırlar halinde yazar (5 sütuna yatay sığması için).
func _reward_lines(host: VBoxContainer, reward: Dictionary) -> void:
	if int(reward.get("coins", 0)) > 0:
		host.add_child(_line(RetentionUi.COIN_ICON, UiKit.GOLD, int(reward["coins"])))
	if int(reward.get("stars", 0)) > 0:
		host.add_child(_line(RetentionUi.STAR_ICON, RetentionUi.STAR_COLOR, int(reward["stars"])))
	for id: Variant in (reward.get("boosters", {}) as Dictionary).keys():
		host.add_child(_line(RetentionUi.booster_icon(String(id)), UiKit.ACCENT, int((reward["boosters"] as Dictionary)[id])))


func _line(icon_name: String, tint: Color, amount: int) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: TextureRect = UiKit.tinted_icon(icon_name, 28.0, tint)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	row.add_child(UiKit.label(str(amount), 28, UiKit.TEXT_MUTED))
	return row


## Alınabilir sandık yumuşakça nabız atar (dikkat çeker ama sakin kalır).
func _pulse(node: Control) -> void:
	node.pivot_offset = Vector2(NODE_DISC, NODE_DISC) * 0.5
	var tween: Tween = node.create_tween().set_loops()
	tween.tween_property(node, "scale", Vector2.ONE * PULSE_SCALE, PULSE_SECONDS * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, PULSE_SECONDS * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_claim(level: int, button: Button) -> void:
	var reward: Dictionary = RetentionFlow.claim_milestone(level)
	if reward.is_empty():
		return
	var origin: Control = _claim_nodes.get(level, button) as Control
	_celebrate_at(origin if is_instance_valid(origin) else button, reward)
	_rebuild()
