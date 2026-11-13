class_name LevelMap
extends CanvasLayer

## Seviye haritası ekranı: dikey kaydırılan, kıvrılan bir çamaşır ipi üzerinde mandallı seviyeler.
## En yeni seviye ÜSTTE (tırmanış hissi; başparmak aşağıdan kaydırır), mevcut seviye açılışta
## ekranın alt-orta bölgesine getirilir. Bitmiş seviyeye dokunmak "Tekrar oyna" kartı açar,
## mevcut seviyeye dokunmak onu başlatır; ileri seviyeler sönüktür. Zen kartı sağ üstten açılır.
## Ana ekranın diğer meta ekranlarıyla aynı sözleşme: `closed`, `covering_changed`, geri tuşu.

signal closed
signal covering_changed(covering: bool)

const SCENE_PATH: String = "res://scenes/map/LevelMap.tscn"
const BG_TOP: Color = Color("f7f3ea")
const BG_BOTTOM: Color = Color("eef4ea")
const FADE_TOP_HEIGHT: float = 330.0
const FADE_BOTTOM_HEIGHT: float = 220.0
const LOCATE_DIAMETER: float = 100.0
const LOCATE_MARGIN: float = 56.0
## Alt kenardan yukarı kaldırma payı: alt solmanın üstünde, başparmak erişiminde.
const LOCATE_LIFT: float = 40.0
const LOCATE_ACCENT: Color = Color("38a276")
const ZEN_ICON: float = 40.0
const ZEN_FONT: int = 38
const ZEN_PAD_WIDTH: float = 22.0

var _root: Control = null
var _canvas: MapCanvas = null
var _locate: MapDiscButton = null
var _zen_pill: PanelContainer = null
var _card: Sheet = null
var _closing: bool = false


## Tam ekran katman olarak açar; geri düğmesi/tuşu ile kapanır ve `closed` yayar.
static func open(parent: Node) -> LevelMap:
	var node: LevelMap = (load(SCENE_PATH) as PackedScene).instantiate() as LevelMap
	parent.add_child(node)
	return node


func _ready() -> void:
	layer = MetaUi.LAYER
	AnalyticsLog.record(MapFlow.EVENT_MAP_OPEN, {"level": Progress.level()})
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var view: Vector2 = _root.get_viewport_rect().size
	var insets: Vector4 = UiKit.safe_insets(view)
	_root.add_child(_gradient(BG_TOP, BG_BOTTOM, Vector2.ZERO, view))
	_canvas = MapCanvas.new()
	_canvas.position = Vector2.ZERO
	_canvas.size = view
	_root.add_child(_canvas)
	_canvas.setup(Progress.level())
	_canvas.level_tapped.connect(_on_level_tapped)
	_canvas.current_visibility_changed.connect(_on_current_visibility)
	# Üst ve alt yumuşak solma: kayan içerik başlık düğmelerinin altında temiz kaybolur.
	_root.add_child(_fade(BG_TOP, true, Vector2(view.x, FADE_TOP_HEIGHT), Vector2.ZERO))
	_root.add_child(_fade(BG_BOTTOM, false, Vector2(view.x, FADE_BOTTOM_HEIGHT),
		Vector2(0.0, view.y - FADE_BOTTOM_HEIGHT)))
	_build_header(view, insets)
	_build_locate(view, insets)
	_canvas.focus_level(Progress.level(), false)
	MetaUi.connect_back(_on_back)
	_root.modulate.a = 0.0
	var intro: Tween = create_tween()
	intro.tween_property(_root, "modulate:a", 1.0, Motion.OVERLAY_FADE_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro.tween_callback(_on_intro_done)


func _gradient(top: Color, bottom: Color, at: Vector2, area: Vector2) -> TextureRect:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, top)
	gradient.set_color(1, bottom)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	var rect: TextureRect = TextureRect.new()
	rect.texture = texture
	rect.position = at
	rect.size = area
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Tek renkten saydamlığa inen yumuşak şerit (`from_top`: üstte opak, alta doğru saydam).
func _fade(color: Color, from_top: bool, area: Vector2, at: Vector2) -> TextureRect:
	var clear: Color = Color(color, 0.0)
	return _gradient(color if from_top else clear, clear if from_top else color, at, area)


func _build_header(view: Vector2, insets: Vector4) -> void:
	var back: UiIconButton = MetaUi.back_button(view, insets)
	back.pressed.connect(close)
	_root.add_child(back)
	_zen_pill = PanelContainer.new()
	_zen_pill.theme_type_variation = &"ChipPanel"
	_zen_pill.mouse_filter = Control.MOUSE_FILTER_STOP
	_zen_pill.custom_minimum_size = Vector2(0.0, UiChip.HEIGHT)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zen_pill.add_child(row)
	var unlocked: bool = ZenMode.is_unlocked(Progress.level())
	row.add_child(MapIcons.rect("leaf" if unlocked else "lock", ZEN_ICON,
		UiKit.ACCENT if unlocked else UiKit.TEXT_MUTED))
	row.add_child(UiKit.label(Loc.t("ZEN_TITLE"), ZEN_FONT, UiKit.TEXT if unlocked else UiKit.TEXT_MUTED))
	_zen_pill.gui_input.connect(_on_zen_input)
	_root.add_child(_zen_pill)
	var pill_size: Vector2 = _zen_pill.get_combined_minimum_size()
	_zen_pill.size = pill_size
	_zen_pill.position = Vector2(view.x - insets.z - UiKit.SIDE_MARGIN - pill_size.x,
		insets.y + (UiKit.MIN_TOUCH - pill_size.y) * 0.5)


func _build_locate(view: Vector2, insets: Vector4) -> void:
	_locate = MapDiscButton.new()
	_locate.setup("navigation", LOCATE_DIAMETER)
	_locate.disc_color = LOCATE_ACCENT
	_locate.icon_color = Color.WHITE
	_locate.position = Vector2(view.x - insets.z - LOCATE_MARGIN - UiKit.MIN_TOUCH \
		+ (UiKit.MIN_TOUCH - LOCATE_DIAMETER) * 0.5, view.y - insets.w - UiKit.MIN_TOUCH - LOCATE_LIFT)
	_locate.pressed.connect(_on_locate)
	_locate.visible = false
	_root.add_child(_locate)


func _on_current_visibility(on_screen: bool) -> void:
	if _locate != null:
		_locate.visible = not on_screen


func _on_locate() -> void:
	_canvas.focus_level(Progress.level(), true)


func _on_zen_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		UiKit.tap_sound()
		_open_card(ZenCard.open(_root))


func _on_level_tapped(level: int) -> void:
	if _card != null and is_instance_valid(_card):
		return
	var current: int = Progress.level()
	if level == current:
		UiKit.tap_sound()
		MapFlow.start_current()
	elif level < current:
		UiKit.tap_sound()
		var card: MapCard = MapCard.open(_root, level)
		_open_card(card)


func _open_card(card: Sheet) -> void:
	_card = card


func _on_intro_done() -> void:
	if not _closing:
		covering_changed.emit(true)


func close() -> void:
	if _closing:
		return
	_closing = true
	# Solarak kapanırken arkası görünür: ana ekran önce yeniden çizilmeye başlasın.
	covering_changed.emit(false)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween: Tween = create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, Motion.OVERLAY_FADE_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(_finish_close)


func _finish_close() -> void:
	closed.emit()
	queue_free()


func _on_back() -> void:
	if not is_inside_tree() or _closing:
		return
	if _card != null and is_instance_valid(_card):
		_card.close()
		return
	close()
