extends Control

## Ana ekran: bahçe arka planı, yumuşak başlık, büyük "Seviye N" düğmesi (başparmak bölgesi),
## jeton/yıldız sayaçları, seri göstergesi, ayarlar ve 3 sekmeli alt çubuk.
## Her şey kodla kurulur; düz, çizgisiz, az metinli (kullanıcı tercihi).

const SKY_TOP: Color = Color("aee0ff")
const SKY_BOTTOM: Color = Color("eef8e6")
const ROPE_COLOR: Color = Color("8a6a4a")
const ROPE_INSET: float = 100.0
const ROPE_Y: float = 700.0
const ROPE_SAG: float = 10.0
const ROPE_STEPS: int = 24
const ROPE_WIDTH: float = 5.0
## Arka plan askısının yüksekliği: alt çubuğun ve düğmenin arkasında kalmasın.
const BACKDROP_RACK_Y: float = 1130.0
const GARMENT_SIZE: float = 200.0
const GARMENT_SPACING: float = 190.0
const GARMENT_KINDS: Array[int] = [0, 1, 5, 3, 2]
const GARMENT_COLORS: Array[Color] = [
	Color("3e8ef7"), Color("9b59d0"), Color("f5c02e"), Color("e5484d"), Color("3dbb6e"),
]
const TITLE_Y: float = 250.0
const TITLE_SIZE: int = 112
const PLAY_WIDTH: float = 700.0
const PLAY_HEIGHT: float = 150.0
const PLAY_CENTER_Y: float = 1560.0
const PLAY_BREATH_SCALE: float = 0.022
const PLAY_BREATH_SECONDS: float = 2.4
const STREAK_CENTER_Y: float = 1400.0
const FLAME_PIXELS: float = 48.0
const BAR_GAP: float = 40.0
const FADE_IN_SECONDS: float = 0.5
const STAR_COLOR: Color = Color("f2b63d")
const UNLIT_FLAME: Color = Color(0.48, 0.52, 0.5, 0.35)
const TAB_SHOP: int = 0
const TAB_HOME: int = 1
const TAB_COLLECTION: int = 2

var _coin_chip: UiChip = null
var _star_chip: UiChip = null
var _play_button: Button = null
var _flames: Array[TextureRect] = []
var _sheet: Sheet = null


const SIDE_BUTTON_STEP: float = 132.0
const BADGE_SIZE: float = 22.0
const BADGE_COLOR: Color = Color("f2705f")
var _daily_button: UiIconButton = null
var _calendar_button: UiIconButton = null
var _laundromat_button: UiIconButton = null
## Açık meta ekranı (çamaşırhane/koleksiyon): geri tuşu önce onu kapatır.
var _meta: Node = null


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.MENU)
	GameManager.back_requested.connect(_on_back)
	var view: Vector2 = get_viewport_rect().size
	var insets: Vector4 = UiKit.safe_insets(view)
	_build_backdrop(view)
	_build_garments(view)
	_build_title(view)
	_build_counters(view, insets)
	_build_play(view)
	_build_tabs(view, insets)
	UiData.connect_changed(_refresh)
	_refresh()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_IN_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _build_backdrop(view: Vector2) -> void:
	var sky_layer: CanvasLayer = CanvasLayer.new()
	sky_layer.layer = -10
	add_child(sky_layer)
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, SKY_TOP)
	gradient.set_color(1, SKY_BOTTOM)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	var sky: TextureRect = TextureRect.new()
	sky.texture = texture
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky_layer.add_child(sky)
	var garden_layer: CanvasLayer = CanvasLayer.new()
	garden_layer.layer = -5
	add_child(garden_layer)
	var backdrop: GardenBackdrop = GardenBackdrop.new()
	garden_layer.add_child(backdrop)
	backdrop.setup(view, BACKDROP_RACK_Y)


## Boş ipte birkaç renkli çamaşır asılı durur: sahneye canlılık, oyunun diliyle aynı görsel.
func _build_garments(view: Vector2) -> void:
	var world: Node2D = Node2D.new()
	world.z_index = -1
	add_child(world)
	var rope: Line2D = Line2D.new()
	rope.width = ROPE_WIDTH
	rope.default_color = ROPE_COLOR
	rope.antialiased = true
	for step: int in range(ROPE_STEPS + 1):
		var t: float = float(step) / float(ROPE_STEPS)
		rope.add_point(Vector2(lerpf(ROPE_INSET, view.x - ROPE_INSET, t),
			ROPE_Y - 6.0 + ROPE_SAG * sin(PI * t)))
	world.add_child(rope)
	for index: int in range(GARMENT_KINDS.size()):
		var garment: GarmentView = GarmentView.new()
		garment.setup(index, GARMENT_COLORS[index], GARMENT_SIZE, GARMENT_KINDS[index], 0)
		garment.position = Vector2(view.x * 0.5 + (float(index) - 2.0) * GARMENT_SPACING, ROPE_Y)
		garment.set_open(true)
		world.add_child(garment)


func _build_title(view: Vector2) -> void:
	var title: Label = UiKit.label(UiStrings.GAME_TITLE, TITLE_SIZE)
	title.position = Vector2(0.0, TITLE_Y)
	title.size = Vector2(view.x, TITLE_SIZE * 1.4)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(title)


func _build_counters(view: Vector2, insets: Vector4) -> void:
	var row_top: float = insets.y
	var chips: HBoxContainer = HBoxContainer.new()
	chips.add_theme_constant_override("separation", 20)
	chips.position = Vector2(insets.x + UiKit.SIDE_MARGIN, row_top + (UiKit.MIN_TOUCH - UiChip.HEIGHT) * 0.5)
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chips)
	_coin_chip = UiChip.new()
	_coin_chip.setup("lucide/coins", UiKit.GOLD)
	chips.add_child(_coin_chip)
	_star_chip = UiChip.new()
	_star_chip.setup("lucide/star", STAR_COLOR)
	chips.add_child(_star_chip)
	var settings: UiIconButton = UiIconButton.new()
	settings.setup("lucide/settings")
	settings.position = Vector2(view.x - insets.z - UiKit.SIDE_MARGIN - UiKit.MIN_TOUCH \
		+ (UiKit.MIN_TOUCH - UiIconButton.DISC_DIAMETER) * 0.5, row_top)
	settings.pressed.connect(_open_settings)
	add_child(settings)
	# Günlük bulmaca ve günlük ödül takvimi: ayarların altında iki küçük düğme; bugün için
	# alınacak bir şey varsa köşesinde küçük bir nokta yanar.
	_daily_button = _side_button("lucide/trophy", settings.position + Vector2(0.0, SIDE_BUTTON_STEP),
		func() -> void: DailyPuzzle.open_card(self))
	_calendar_button = _side_button("lucide/clock", settings.position + Vector2(0.0, SIDE_BUTTON_STEP * 2.0),
		func() -> void: DailyCalendar.open(self))
	# Çamaşırhane onarımı: yıldızlar burada harcanır; onarılabilecek bir şey varsa nokta yanar.
	_laundromat_button = _side_button("lucide/house", settings.position + Vector2(0.0, SIDE_BUTTON_STEP * 3.0),
		func() -> void: _meta = MetaLaundromat.open(self))


func _side_button(icon: String, at: Vector2, action: Callable) -> UiIconButton:
	var button: UiIconButton = UiIconButton.new()
	button.setup(icon)
	button.position = at
	button.pressed.connect(action)
	add_child(button)
	var dot: Panel = Panel.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = BADGE_COLOR
	box.set_corner_radius_all(int(BADGE_SIZE))
	box.anti_aliasing = true
	dot.add_theme_stylebox_override("panel", box)
	dot.size = Vector2(BADGE_SIZE, BADGE_SIZE)
	dot.position = Vector2(UiIconButton.DISC_DIAMETER - BADGE_SIZE, 0.0)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.name = "Badge"
	button.add_child(dot)
	return button


func _build_play(view: Vector2) -> void:
	# Seri göstergesi: üç alev; yananlar turuncu, sönükler soluk. Yarı saydam hapın içinde.
	var streak_chip: PanelContainer = PanelContainer.new()
	streak_chip.theme_type_variation = &"ChipPanel"
	streak_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var flames: HBoxContainer = HBoxContainer.new()
	flames.add_theme_constant_override("separation", 14)
	flames.mouse_filter = Control.MOUSE_FILTER_IGNORE
	streak_chip.add_child(flames)
	for index: int in range(UiData.MAX_STREAK):
		var flame: TextureRect = UiKit.tinted_icon("lucide/flame", FLAME_PIXELS, UiKit.FLAME)
		flames.add_child(flame)
		_flames.append(flame)
	add_child(streak_chip)
	var streak_size: Vector2 = streak_chip.get_combined_minimum_size()
	streak_chip.size = streak_size
	streak_chip.position = Vector2((view.x - streak_size.x) * 0.5, STREAK_CENTER_Y - streak_size.y * 0.5)
	_play_button = UiKit.button(UiStrings.LEVEL % 1, &"", "lucide/play", PLAY_HEIGHT)
	_play_button.size = Vector2(PLAY_WIDTH, PLAY_HEIGHT)
	_play_button.custom_minimum_size = Vector2(PLAY_WIDTH, PLAY_HEIGHT)
	_play_button.position = Vector2((view.x - PLAY_WIDTH) * 0.5, PLAY_CENTER_Y - PLAY_HEIGHT * 0.5)
	_play_button.pivot_offset = _play_button.size * 0.5
	_play_button.pressed.connect(_on_play)
	add_child(_play_button)
	# Çok hafif "nefes": dikkat çeker ama sakin kalır.
	var breath: Tween = _play_button.create_tween().set_loops()
	breath.tween_property(_play_button, "scale", Vector2.ONE * (1.0 + PLAY_BREATH_SCALE), PLAY_BREATH_SECONDS * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breath.tween_property(_play_button, "scale", Vector2.ONE, PLAY_BREATH_SECONDS * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _build_tabs(view: Vector2, insets: Vector4) -> void:
	var bar: PanelContainer = PanelContainer.new()
	bar.theme_type_variation = &"ChipPanel"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", int(BAR_GAP))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)
	var icons: Array[String] = ["lucide/shopping-bag", "lucide/house", "lucide/shirt"]
	for index: int in range(icons.size()):
		var tab: UiIconButton = UiIconButton.new()
		tab.setup(icons[index])
		var selected: bool = index == TAB_HOME
		tab.disc_color = UiKit.ACCENT_SOFT if selected else Color(0.0, 0.0, 0.0, 0.0)
		tab.icon_color = UiKit.ACCENT if selected else UiKit.TEXT_MUTED
		tab.pressed.connect(_on_tab.bind(index))
		row.add_child(tab)
	add_child(bar)
	var bar_size: Vector2 = bar.get_combined_minimum_size()
	bar.size = bar_size
	bar.position = Vector2((view.x - bar_size.x) * 0.5, view.y - insets.w - bar_size.y)


func _refresh() -> void:
	if _daily_button != null:
		(_daily_button.get_node("Badge") as Control).visible = DailyPuzzle.available_today()
		(_calendar_button.get_node("Badge") as Control).visible = DailyStore.calendar_available()
		(_laundromat_button.get_node("Badge") as Control).visible = MetaStore.new().can_renovate()
	_coin_chip.set_value(UiData.coins())
	_star_chip.set_value(UiData.stars())
	UiKit.set_button_text(_play_button, UiStrings.LEVEL % UiData.level())
	var streak: int = UiData.streak()
	for index: int in range(_flames.size()):
		_flames[index].modulate = UiKit.FLAME if index < streak else UNLIT_FLAME


func _on_play() -> void:
	GameManager.start_game()


func _on_tab(index: int) -> void:
	if index == TAB_SHOP:
		_open_sheet(InfoSheet.soon(self, "lucide/shopping-bag"))
	elif index == TAB_COLLECTION:
		_meta = MetaCollection.open(self)


func _open_settings() -> void:
	_open_sheet(InfoSheet.settings(self))


func _open_sheet(sheet: Sheet) -> void:
	if _sheet != null and is_instance_valid(_sheet):
		_sheet.queue_free()
	_sheet = sheet


func _on_back() -> void:
	if is_instance_valid(_meta):
		return
	if _sheet != null and is_instance_valid(_sheet):
		_sheet.close()
		return
	get_tree().quit()
