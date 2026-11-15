extends Control

## Seviye haritası: dünyalara göre gruplu karolar (numara, yıldız, kilit, "atlandı" işareti).
## Şimdiki seviye vurgulu açılır ve görünür kaydırılır. Kilitli karoya dokununca nedeni söylenir.
## Karolar tek `_draw` ile çizilir (LevelTile): çok seviyede de hafif kalır.

const COLUMNS: int = 4
const TILE_GAP: int = UiTokens.SPACE_MD + 4
const TILE_HEIGHT: float = 176.0
const HEADER_SIZE: int = UiKit.TYPE_BODY
const WORLD_GAP: float = UiKit.SPACE_XL
const BAR_TITLE_SIZE: int = UiKit.TYPE_HEADING
const SCROLL_FOCUS_RATIO: float = 0.38
const TOAST_BOTTOM: float = 220.0

var _scroll: ScrollContainer = null
var _current_tile: LevelTile = null
var _ids: Array[String] = []
var _progress: LevelProgress = null


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
	var safe: MarginContainer = MarginContainer.new()
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.add_theme_constant_override("margin_left", int(insets.x + UiKit.SIDE_MARGIN))
	safe.add_theme_constant_override("margin_right", int(insets.z + UiKit.SIDE_MARGIN))
	safe.add_theme_constant_override("margin_top", int(insets.y))
	safe.add_theme_constant_override("margin_bottom", 0)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)
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
	_scroll.add_child(_build_worlds(insets.w))
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, Motion.SCREEN_FADE_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
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


func _build_worlds(bottom_inset: float) -> Control:
	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", int(WORLD_GAP))
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var entries: Array[Dictionary] = LevelCatalog.entries()
	var frontier: int = _progress.frontier(_ids)
	# Dünya başına sıralı gruplar (index.json zaten sıralıdır).
	var world_box: VBoxContainer = null
	var grid: GridContainer = null
	var current_world: int = -1
	var view_width: float = get_viewport_rect().size.x
	var inner: float = view_width - UiKit.safe_insets(get_viewport_rect().size).x \
		- UiKit.safe_insets(get_viewport_rect().size).z - UiKit.SIDE_MARGIN * 2.0
	var tile_width: float = floorf((inner - float(TILE_GAP * (COLUMNS - 1))) / float(COLUMNS))
	for index: int in entries.size():
		var world: int = int(entries[index].get("world", 1))
		if world != current_world:
			current_world = world
			world_box = VBoxContainer.new()
			world_box.add_theme_constant_override("separation", int(UiKit.SPACE_MD))
			world_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			content.add_child(world_box)
			var header: Label = UiKit.label(UiStrings.world(world), HEADER_SIZE, UiKit.TEXT_MUTED)
			header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			world_box.add_child(header)
			grid = GridContainer.new()
			grid.columns = COLUMNS
			grid.add_theme_constant_override("h_separation", TILE_GAP)
			grid.add_theme_constant_override("v_separation", TILE_GAP)
			grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
			world_box.add_child(grid)
		var level_id: String = _ids[index]
		var tile: LevelTile = LevelTile.new()
		tile.name = "Tile_%s" % level_id
		tile.setup(level_id, index + 1, _mode_of(index, frontier), _progress.stars(level_id),
			Vector2(tile_width, TILE_HEIGHT))
		tile.pressed.connect(_on_tile_pressed.bind(tile))
		grid.add_child(tile)
		if index == frontier:
			_current_tile = tile
	content.add_child(UiKit.spacer(maxf(bottom_inset, UiKit.MIN_BOTTOM_MARGIN)))
	return content


func _mode_of(index: int, frontier: int) -> LevelTile.Mode:
	var level_id: String = _ids[index]
	if _progress.is_solved(level_id):
		return LevelTile.Mode.SOLVED
	if _progress.is_skipped(level_id):
		return LevelTile.Mode.SKIPPED
	if not _progress.is_unlocked(_ids, index):
		return LevelTile.Mode.LOCKED
	return LevelTile.Mode.CURRENT if index == frontier else LevelTile.Mode.OPEN


func _focus_wait() -> void:
	get_tree().process_frame.connect(_focus_current, CONNECT_ONE_SHOT)


## Şimdiki karo görünür alanın üst-orta bölgesine gelecek biçimde kaydırılır.
func _focus_current() -> void:
	if _current_tile == null or not is_instance_valid(_current_tile):
		return
	var offset: float = _current_tile.global_position.y - _scroll.global_position.y + float(_scroll.scroll_vertical)
	_scroll.scroll_vertical = maxi(int(offset - _scroll.size.y * SCROLL_FOCUS_RATIO), 0)


func _on_tile_pressed(tile: LevelTile) -> void:
	if tile.mode == LevelTile.Mode.LOCKED:
		UiToast.show_text(self, UiStrings.map_locked(), TOAST_BOTTOM)
		return
	GameManager.start_level(tile.level_id)


func _on_back() -> void:
	GameManager.goto_scene(&"home")
