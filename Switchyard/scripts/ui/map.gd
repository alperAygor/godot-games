extends Control

## Seviye haritası: her dünya bir yer (amblem, ad, toplanan/toplam yıldız) ve altında kendi karo ızgarası.
## Şimdiki seviye vurgulu açılır ve yumuşakça görünür kaydırılır; kilitli ve atlanan karolar bir bakışta ayrılır.
## Karolar `WorldGrid` ile dünya başına TEK düğümde çizilir: 200+ seviyede düğüm sayısı dünya sayısı kadar kalır.

const WORLD_GAP: float = UiKit.SPACE_XL
const HEADER_ICON: float = float(UiTokens.ICON_EMBLEM)
const HEADER_DISC: float = 96.0
const HEADER_GAP: int = UiTokens.SPACE_LG
const HEADER_LOCKED_ALPHA: float = 0.55
const BAR_TITLE_SIZE: int = UiKit.TYPE_HEADING
const SCROLL_FOCUS_RATIO: float = 0.38
const SCROLL_LEAD: float = 360.0
const SCROLL_SECONDS: float = 0.6
const TOAST_BOTTOM: float = 220.0
const EMBLEMS: Array[String] = ["ux/emblem-meadow", "ux/emblem-harbour", "ux/emblem-mountain", "ux/emblem-factory"]
const WORLD_COLORS: Array[Color] = [UiTokens.C_WORLD_1, UiTokens.C_WORLD_2, UiTokens.C_WORLD_3, UiTokens.C_WORLD_4]

var _content: Control = null
var _scroll: ScrollContainer = null
var _grids: Array[WorldGrid] = []
var _ids: Array[String] = []
var _progress: LevelProgress = null
var _scroll_tween: Tween = null


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.HOME)
	GameManager.back_requested.connect(_on_back)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var view: Vector2 = get_viewport_rect().size
	var insets: Vector4 = UiKit.safe_insets(view)
	var back: ColorRect = ColorRect.new()
	back.color = UiTokens.C_BACKGROUND
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	_content = Control.new()
	_content.name = "Content"
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	var safe: MarginContainer = MarginContainer.new()
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", int(insets.x + UiKit.SIDE_MARGIN))
	safe.add_theme_constant_override("margin_right", int(insets.z + UiKit.SIDE_MARGIN))
	safe.add_theme_constant_override("margin_top", int(insets.y))
	safe.add_theme_constant_override("margin_bottom", 0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(safe)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", int(UiKit.SPACE_MD))
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(column)
	_progress = LevelProgress.load_saved()
	_ids = LevelProgress.ids_of(LevelCatalog.entries())
	column.add_child(_build_bar())
	_scroll = ScrollContainer.new()
	_scroll.name = "Scroll"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	var inner: float = view.x - insets.x - insets.z - UiKit.SIDE_MARGIN * 2.0
	if _ids.is_empty():
		var empty: Control = UiKit.empty_state("lucide/grid-2x2", UiStrings.map_empty())
		empty.name = "Empty"
		var holder: CenterContainer = CenterContainer.new()
		holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		holder.add_child(empty)
		column.add_child(holder)
	else:
		_scroll.add_child(_build_worlds(inner, insets.w))
	ScreenFx.fade_in(_content)
	# Düzen oturunca (iki kare sonra) şimdiki karoya kaydır. Sinyalle bağlanır: sahne erken silinirse bağ kendiliğinden düşer.
	get_tree().process_frame.connect(_focus_wait, CONNECT_ONE_SHOT)


func _exit_tree() -> void:
	if GameManager.back_requested.is_connected(_on_back):
		GameManager.back_requested.disconnect(_on_back)


func _build_bar() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, UiKit.MIN_TOUCH)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back_button: UiIconButton = UiIconButton.new()
	back_button.name = "BackButton"
	back_button.setup("lucide/arrow-left")
	back_button.pressed.connect(_on_back)
	row.add_child(back_button)
	var title: Label = UiKit.label(UiStrings.levels(), BAR_TITLE_SIZE)
	title.name = "Title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	var chip_holder: CenterContainer = CenterContainer.new()
	chip_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip_holder.custom_minimum_size = Vector2(UiKit.MIN_TOUCH, 0.0)
	row.add_child(chip_holder)
	var chip: UiChip = UiChip.new()
	chip.setup("shell/star-fill", UiKit.STAR)
	chip.set_value(_progress.total_stars(_ids))
	chip_holder.add_child(chip)
	return row


func _build_worlds(width: float, bottom_inset: float) -> Control:
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", int(WORLD_GAP))
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var entries: Array[Dictionary] = LevelCatalog.entries()
	var frontier: int = _progress.frontier(_ids)
	# Dünya başına sıralı gruplar (index.json zaten sıralıdır).
	var group: Array[Dictionary] = []
	var current_world: int = -1
	for index: int in entries.size():
		var world: int = int(entries[index].get("world", 1))
		if world != current_world and not group.is_empty():
			_add_world(content, current_world, group, width)
			group = []
		current_world = world
		var level_id: String = _ids[index]
		group.append({
			"id": level_id, "number": index + 1, "mode": _mode_of(index, frontier),
			"stars": _progress.stars(level_id), "difficulty": int(entries[index].get("difficulty", 1)),
		})
	if not group.is_empty():
		_add_world(content, current_world, group, width)
	var footer: Label = UiKit.wrap_label(UiStrings.map_more(), UiKit.TYPE_CAPTION, UiKit.TEXT_MUTED)
	footer.name = "Footer"
	content.add_child(footer)
	content.add_child(UiKit.spacer(maxf(bottom_inset, UiKit.MIN_BOTTOM_MARGIN)))
	return content


func _add_world(parent: Control, world: int, group: Array[Dictionary], width: float) -> void:
	var accent: Color = WORLD_COLORS[(world - 1) % WORLD_COLORS.size()] if world >= 1 else UiKit.ACCENT
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "World_%d" % world
	box.add_theme_constant_override("separation", int(UiKit.SPACE_MD))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	var collected: int = 0
	var unlocked: bool = false
	for entry: Dictionary in group:
		collected += int(entry["stars"])
		unlocked = unlocked or entry["mode"] != LevelTile.Mode.LOCKED
	box.add_child(_build_header(world, accent, collected, group.size() * LevelProgress.MAX_STARS, unlocked))
	var grid: WorldGrid = WorldGrid.new()
	grid.name = "Grid_%d" % world
	grid.setup(group, accent, width)
	grid.tile_pressed.connect(_on_tile_pressed.bind(grid))
	box.add_child(grid)
	_grids.append(grid)


func _build_header(world: int, accent: Color, collected: int, available: int, unlocked: bool) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Header"
	row.add_theme_constant_override("separation", HEADER_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var emblem: String = EMBLEMS[(world - 1) % EMBLEMS.size()] if world >= 1 else EMBLEMS[0]
	row.add_child(UiKit.disc(emblem, accent.lerp(UiKit.SHEET, 0.78), accent, HEADER_DISC, HEADER_ICON))
	var names: VBoxContainer = VBoxContainer.new()
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.add_theme_constant_override("separation", 0)
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(names)
	var caption: Label = UiKit.label(UiStrings.world(world), UiKit.TYPE_CAPTION, UiKit.TEXT_MUTED)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	names.add_child(caption)
	var title: Label = UiKit.label(UiStrings.world_name(world), UiTokens.TYPE_WORLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.name = "WorldName"
	names.add_child(title)
	var stars: UiChip = UiChip.new()
	stars.name = "WorldStars"
	stars.setup("shell/star-fill", UiKit.STAR)
	stars.set_text_value("%d / %d" % [collected, available])
	stars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(stars)
	if not unlocked:
		row.modulate.a = HEADER_LOCKED_ALPHA
	return row


func _mode_of(index: int, frontier: int) -> LevelTile.Mode:
	var level_id: String = _ids[index]
	if _progress.is_solved(level_id):
		return LevelTile.Mode.SOLVED
	if _progress.is_skipped(level_id):
		return LevelTile.Mode.SKIPPED
	if not _progress.is_unlocked(_ids, index):
		return LevelTile.Mode.LOCKED
	return LevelTile.Mode.CURRENT if index == frontier else LevelTile.Mode.OPEN


## Probe/test: seviyenin karo durumu (`LevelTile.Mode`); bulunamazsa -1.
func tile_mode(level_id: String) -> int:
	for grid: WorldGrid in _grids:
		var index: int = grid.index_of_id(level_id)
		if index >= 0:
			return int(grid.mode_at(index))
	return -1


## Probe/test: seviye karosuna dokunulmuş gibi davranır.
func press_level(level_id: String) -> void:
	for grid: WorldGrid in _grids:
		var index: int = grid.index_of_id(level_id)
		if index >= 0:
			_on_tile_pressed(index, grid)
			return


func grid_count() -> int:
	return _grids.size()


func _focus_wait() -> void:
	get_tree().process_frame.connect(_focus_current, CONNECT_ONE_SHOT)


## Şimdiki karo görünür alanın üst-orta bölgesine gelecek biçimde yumuşakça kaydırılır.
func _focus_current() -> void:
	for grid: WorldGrid in _grids:
		var index: int = grid.current_index()
		if index < 0:
			continue
		var tile_y: float = grid.global_position.y - _scroll.global_position.y + float(_scroll.scroll_vertical) \
			+ grid.tile_rect(index).position.y
		var target: int = maxi(int(tile_y - _scroll.size.y * SCROLL_FOCUS_RATIO), 0)
		if UiData.reduced_motion() or target <= 0:
			_scroll.scroll_vertical = target
			return
		_scroll.scroll_vertical = maxi(target - int(SCROLL_LEAD), 0)
		_scroll_tween = create_tween()
		_scroll_tween.tween_property(_scroll, "scroll_vertical", target, SCROLL_SECONDS)\
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		return


func _on_tile_pressed(index: int, grid: WorldGrid) -> void:
	if grid.mode_at(index) == LevelTile.Mode.LOCKED:
		UiToast.show_text(self, UiStrings.map_locked(), TOAST_BOTTOM, "lucide/lock")
		return
	var level_id: String = grid.id_at(index)
	if OnlineGate.passes_now():
		ScreenFx.leave(_content, GameManager.start_level.bind(level_id))
	else:
		GameManager.start_level(level_id)


func _on_back() -> void:
	ScreenFx.leave(_content, GameManager.goto_scene.bind(&"home"))
