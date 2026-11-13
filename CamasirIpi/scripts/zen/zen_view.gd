class_name ZenView
extends Control

## Zen kipinin oyun içi katmanı: çıkış düğmesi, temiz tahta sayacı, "✓" anı, yumuşak geçiş örtüsü
## ve küçük bilgi notu. Normal HUD'un duraklat düğmesi ve jeton hapı gizlenir (zen'de jeton yok).
## Hepsi düz, çizgisiz, sakin; metin yalnız kurtarma notunda.

signal exit_pressed

const COVER_COLOR: Color = Color("f4f1e6")
const PILL_ICON: float = 40.0
const PILL_FONT: int = 40
const CHECK_DISC: float = 220.0
const CHECK_ICON: float = 110.0
const CHECK_IN_SECONDS: float = 0.3
const CHECK_OUT_SECONDS: float = 0.5
const TOAST_FONT: int = 34
const TOAST_Y_RATIO: float = 0.62
const TOAST_FADE_SECONDS: float = 0.35
const TOAST_HOLD_SECONDS: float = 2.4
const BUMP_SCALE: float = 1.18
const BUMP_SECONDS: float = 0.2

var _cover: ColorRect = null
var _count_label: Label = null
var _pill: PanelContainer = null
var _check: Control = null
var _toast: PanelContainer = null
var _toast_label: Label = null
var _toast_tween: Tween = null
var _hint_generation: int = 0
var _view_size: Vector2 = Vector2(1080.0, 1920.0)


## Oyun arayüz katmanına kurar ve normal HUD'un zen'e uymayan parçalarını gizler.
static func attach(ui: CanvasLayer, hud: Control) -> ZenView:
	var view: ZenView = ZenView.new()
	ui.add_child(view)
	view._hide_hud_parts(hud)
	return view


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var view: Vector2 = get_viewport_rect().size
	var insets: Vector4 = UiKit.safe_insets(view)
	_cover = ColorRect.new()
	_cover.color = COVER_COLOR
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.modulate.a = 0.0
	add_child(_cover)
	var exit_button: UiIconButton = UiIconButton.new()
	exit_button.setup("lucide/x")
	exit_button.position = Vector2(insets.x + UiKit.SIDE_MARGIN - (UiKit.MIN_TOUCH - UiIconButton.DISC_DIAMETER) * 0.5,
		insets.y)
	exit_button.pressed.connect(exit_pressed.emit)
	add_child(exit_button)
	_pill = PanelContainer.new()
	_pill.theme_type_variation = &"ChipPanel"
	_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.custom_minimum_size = Vector2(0.0, UiChip.HEIGHT)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill.add_child(row)
	row.add_child(MapIcons.rect("leaf", PILL_ICON, UiKit.ACCENT))
	_count_label = UiKit.label("0", PILL_FONT)
	row.add_child(_count_label)
	add_child(_pill)
	_pill.resized.connect(_place_pill.bind(view, insets))
	_place_pill(view, insets)
	_build_check(view)
	_build_toast(view)


func _place_pill(view: Vector2, insets: Vector4) -> void:
	var pill_size: Vector2 = _pill.get_combined_minimum_size()
	_pill.size = pill_size
	_pill.position = Vector2(view.x - insets.z - UiKit.SIDE_MARGIN - pill_size.x,
		insets.y + (UiKit.MIN_TOUCH - pill_size.y) * 0.5)
	_pill.pivot_offset = pill_size * 0.5


## HUD'un duraklat düğmesi ve jeton hapı zen'de yoktur (çıkış düğmesi ve sayaç onların yerinde).
func _hide_hud_parts(hud: Control) -> void:
	for child: Node in hud.get_children():
		if child is UiIconButton or child is UiChip:
			(child as CanvasItem).visible = false


func _build_check(view: Vector2) -> void:
	_check = Control.new()
	_check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_check.size = Vector2(CHECK_DISC, CHECK_DISC)
	_check.position = (view - _check.size) * 0.5 - Vector2(0.0, view.y * 0.06)
	_check.pivot_offset = _check.size * 0.5
	_check.modulate.a = 0.0
	var disc: Panel = Panel.new()
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(1.0, 1.0, 1.0, 0.9)
	box.set_corner_radius_all(int(CHECK_DISC * 0.5))
	box.anti_aliasing = true
	disc.add_theme_stylebox_override("panel", box)
	disc.size = _check.size
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_check.add_child(disc)
	var icon: TextureRect = UiKit.tinted_icon("lucide/check", CHECK_ICON, UiKit.ACCENT)
	icon.position = (_check.size - Vector2(CHECK_ICON, CHECK_ICON)) * 0.5
	_check.add_child(icon)
	add_child(_check)


func _build_toast(view: Vector2) -> void:
	_toast = PanelContainer.new()
	_toast.theme_type_variation = &"ChipPanel"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	_toast_label = UiKit.label("", TOAST_FONT, UiKit.TEXT_MUTED)
	_toast.add_child(_toast_label)
	add_child(_toast)
	_view_size = view


func set_count(value: int, bump: bool = true) -> void:
	_count_label.text = str(value)
	if not bump:
		return
	var tween: Tween = create_tween()
	tween.tween_property(_pill, "scale", Vector2.ONE * BUMP_SCALE, BUMP_SECONDS * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_pill, "scale", Vector2.ONE, BUMP_SECONDS)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Tahta temizlendi: yumuşak "✓" belirir ve söner. Süre `hold` sonunda biter (await edilir).
func show_check(hold: float) -> void:
	_check.scale = Vector2.ONE * 0.8
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_check, "modulate:a", 1.0, CHECK_IN_SECONDS).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_check, "scale", Vector2.ONE, CHECK_IN_SECONDS * 1.5)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(maxf(hold - CHECK_IN_SECONDS - CHECK_OUT_SECONDS, 0.0))
	tween.chain().tween_property(_check, "modulate:a", 0.0, CHECK_OUT_SECONDS).set_trans(Tween.TRANS_SINE)
	await tween.finished


## Örtü yumuşakça kapanır (tahta değişimi görünmesin) ya da açılır.
func fade_cover(to_alpha: float, seconds: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_cover, "modulate:a", to_alpha, seconds)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


## Küçük, solan bilgi notu (kurtarma: "Bir adım geri aldık").
func toast(text: String) -> void:
	_toast_label.text = text
	var toast_size: Vector2 = _toast.get_combined_minimum_size()
	_toast.size = toast_size
	_toast.position = Vector2((_view_size.x - toast_size.x) * 0.5, _view_size.y * TOAST_Y_RATIO)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, TOAST_FADE_SECONDS)
	_toast_tween.tween_interval(TOAST_HOLD_SECONDS)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, TOAST_FADE_SECONDS * 1.5)


## Önerilen çamaşırı birkaç kez yumuşakça parlatır (tahta yeniden kurulursa durur).
func pulse_hint(target: GarmentView, flashes: int, interval: float) -> void:
	_hint_generation += 1
	var generation: int = _hint_generation
	for _index: int in range(flashes):
		if generation != _hint_generation or not is_instance_valid(target):
			return
		target.flash()
		await get_tree().create_timer(interval).timeout


func cancel_hint() -> void:
	_hint_generation += 1
