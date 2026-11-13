class_name OnlineSheet
extends CanvasLayer

## "Bağlantı gerekli" tam ekran sayfası: sakin, tek bir tekrar dene düğmesi; birkaç saniyede bir
## kendiliğinden de dener. Bağlantı gelince `passed` yayar ve kapanır. Düz, çizgisiz, az metin.
## Katman yüksek: oyun/ana ekran HUD'unun ve diğer sayfaların üstünde kalır (seviye başlamaz).

signal passed

const LAYER_INDEX: int = 120
const RETRY_SECONDS: float = 4.0
const BG_TOP: Color = Color("f7f3ea")
const BG_BOTTOM: Color = Color("eef4ea")
const DISC_DIAMETER: float = 200.0
const ICON_PIXELS: float = 92.0
const TITLE_SIZE: int = 60
const BODY_SIZE: int = 36
const STATUS_SIZE: int = 30
const BUTTON_WIDTH: float = 620.0
const BUTTON_HEIGHT: float = 132.0
const GAP: float = 36.0
const FADE_SECONDS: float = 0.35
const STATUS_ALPHA: float = 0.7

var _checker: OnlineChecker = null
var _busy: bool = false
var _done: bool = false
var _status: Label = null
var _button: Button = null
var _timer: Timer = null


static func open(host: Node, checker: OnlineChecker) -> OnlineSheet:
	var sheet: OnlineSheet = OnlineSheet.new()
	sheet._checker = checker
	host.add_child(sheet)
	return sheet


func _ready() -> void:
	layer = LAYER_INDEX
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.add_child(_background())
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(column)
	column.add_child(_icon_disc())
	column.add_child(UiKit.spacer(GAP))
	column.add_child(UiKit.label(Loc.t("NET_TITLE"), TITLE_SIZE))
	column.add_child(UiKit.spacer(GAP * 0.4))
	var body: Label = UiKit.label(Loc.t("NET_BODY"), BODY_SIZE, UiKit.TEXT_MUTED)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(BUTTON_WIDTH, 0.0)
	column.add_child(body)
	column.add_child(UiKit.spacer(GAP * 1.6))
	_button = UiKit.button(Loc.t("NET_RETRY"), &"", "lucide/rotate-ccw", BUTTON_HEIGHT)
	_button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	_button.pressed.connect(_attempt.bind(true))
	column.add_child(_button)
	column.add_child(UiKit.spacer(GAP * 0.6))
	_status = UiKit.label(Loc.t("NET_CHECKING"), STATUS_SIZE, UiKit.TEXT_MUTED)
	_status.modulate.a = 0.0
	column.add_child(_status)
	# Kendiliğinden yeniden deneme: oyuncu düğmeye basmadan bağlantı gelince devam eder.
	_timer = Timer.new()
	_timer.wait_time = RETRY_SECONDS
	_timer.one_shot = false
	_timer.timeout.connect(_attempt.bind(false))
	add_child(_timer)
	_timer.start()
	root.modulate.a = 0.0
	create_tween().tween_property(root, "modulate:a", 1.0, FADE_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _background() -> TextureRect:
	var gradient: Gradient = Gradient.new()
	gradient.set_color(0, BG_TOP)
	gradient.set_color(1, BG_BOTTOM)
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	var back: TextureRect = TextureRect.new()
	back.texture = texture
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return back


func _icon_disc() -> CenterContainer:
	var wrap: CenterContainer = CenterContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc: Panel = Panel.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = UiKit.ACCENT_SOFT
	box.set_corner_radius_all(int(DISC_DIAMETER * 0.5))
	box.anti_aliasing = true
	disc.add_theme_stylebox_override("panel", box)
	disc.custom_minimum_size = Vector2(DISC_DIAMETER, DISC_DIAMETER)
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: TextureRect = MapIcons.rect("wifi-off", ICON_PIXELS, UiKit.ACCENT)
	icon.position = Vector2(DISC_DIAMETER - ICON_PIXELS, DISC_DIAMETER - ICON_PIXELS) * 0.5
	disc.add_child(icon)
	wrap.add_child(disc)
	return wrap


## Bir deneme: elle (düğme) ya da kendiliğinden. Aynı anda tek deneme.
func _attempt(manual: bool) -> void:
	if _busy or _done:
		return
	_busy = true
	AnalyticsLog.record(OnlineGate.EVENT_RETRY, {"manual": manual})
	_status.modulate.a = STATUS_ALPHA
	var online: bool = await _checker.check(true)
	if not is_instance_valid(self):
		return
	_busy = false
	_status.modulate.a = 0.0
	if online:
		_finish()


func _finish() -> void:
	_done = true
	_timer.stop()
	passed.emit()
	queue_free()
