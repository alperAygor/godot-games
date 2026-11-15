class_name CoachOverlay
extends Control

## Sözsüz ilk seviye ipucu (kabuk tarafı): sahanın üstünde, ENGELLEMEYEN (fare/dokunma olayları sahaya geçer) bir hareket:
##   "drag"   — parmak noktası sahada yukarı doğru sürüklenir (1. seviye),
##   "tap"    — nabız atan halka: kancaya dokun (2. seviye),
##   "switch" — makas üstünde nabız atan halka (3. seviye).
## Üstte küçük bir metin kartı vardır; karta dokunmak ya da sahada ilk hamle ipucu kapatır (`dismissed`).
## Konumlar şimdilik sahanın GENEL noktalarıdır (`focus`, `target`: kontrol uzayında); gerçek görünüm kesin konum verince
## (bkz. docs/UI_GUIDE.md "Koç") `show_kind` ona verilir. Az harekette hareket yok: yalnız durağan halka.

signal dismissed

const CYCLE_SECONDS: float = 2.4
const DOT_RADIUS: float = float(UiTokens.SIZE_COACH_HAND) * 0.5
const RING_MAX: float = 110.0
const TRAIL_WIDTH: float = 10.0
const CARD_TOP_GAP: float = UiKit.SPACE_XL
const CARD_PAD_X: int = UiTokens.SPACE_XL
const CARD_PAD_Y: int = UiTokens.SPACE_MD
const CARD_FONT: int = UiKit.TYPE_CAPTION + 4
const DISMISS_FONT: int = UiKit.TYPE_MICRO
const CARD_ALPHA: float = 0.86
const FADE_SECONDS: float = 0.3

var kind: String = "drag"
var from_point: Vector2 = Vector2.ZERO
var to_point: Vector2 = Vector2.ZERO
var _phase: float = 0.0
var _card: PanelContainer = null
var _tween: Tween = null
var _gone: bool = false


## `focus`: halka/başlangıç noktası, `target`: sürükleme bitişi (yalnız "drag").
func show_kind(coach_kind: String, focus: Vector2, target: Vector2) -> void:
	kind = coach_kind
	from_point = focus
	to_point = target
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_card()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, FADE_SECONDS)
	if not UiData.reduced_motion():
		_tween = create_tween().set_loops()
		_tween.tween_method(_set_phase, 0.0, 1.0, CYCLE_SECONDS)


func is_gone() -> bool:
	return _gone


func _build_card() -> void:
	_card = PanelContainer.new()
	_card.name = "CoachCard"
	_card.add_theme_stylebox_override("panel", UiKit.card_style(Color(UiKit.TEXT, CARD_ALPHA), UiTokens.RADIUS_PILL,
		CARD_PAD_X, CARD_PAD_Y))
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_card.gui_input.connect(_on_card_input)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(column)
	var text: Label = UiKit.wrap_label(UiStrings.coach(kind), CARD_FONT, Color.WHITE)
	text.name = "CoachText"
	column.add_child(text)
	column.add_child(UiKit.label(UiStrings.coach_dismiss(), DISMISS_FONT, Color(1.0, 1.0, 1.0, 0.6)))
	add_child(_card)
	_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.offset_top = CARD_TOP_GAP
	_card.offset_bottom = CARD_TOP_GAP


func _set_phase(value: float) -> void:
	_phase = value
	queue_redraw()


func _on_card_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if pressed:
		dismiss()


## Kapatır (kart dokunuşu ya da ilk hamle): solup silinir; tek sefer.
func dismiss() -> void:
	if _gone:
		return
	_gone = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	dismissed.emit()
	var out: Tween = create_tween()
	out.tween_property(self, "modulate:a", 0.0, FADE_SECONDS)
	out.tween_callback(queue_free)


func _draw() -> void:
	match kind:
		"drag":
			_draw_drag()
		_:
			_draw_ring()


func _draw_drag() -> void:
	# 0-0.2 belirir ve basar, 0.2-0.75 sürüklenir, 0.75-1 solar.
	var reduced: bool = UiData.reduced_motion()
	var travel: float = 0.0 if reduced else Motion.ease_in_out(clampf((_phase - 0.2) / 0.55, 0.0, 1.0))
	var fade: float = 1.0 if reduced else minf(_phase / 0.2, 1.0) * (1.0 - clampf((_phase - 0.75) / 0.25, 0.0, 1.0))
	var at: Vector2 = from_point.lerp(to_point, travel)
	draw_line(from_point, at, Color(UiKit.ACCENT, 0.35 * fade), TRAIL_WIDTH, true)
	var press: float = 1.0 - clampf(_phase / 0.2, 0.0, 1.0) * 0.18
	draw_circle(at, DOT_RADIUS * press * 1.3, Color(UiKit.ACCENT, 0.22 * fade), true, -1.0, true)
	draw_circle(at, DOT_RADIUS * press, Color(1.0, 1.0, 1.0, 0.92 * fade), true, -1.0, true)
	draw_arc(at, DOT_RADIUS * press, 0.0, TAU, 40, Color(UiKit.ACCENT, fade), 6.0, true)


func _draw_ring() -> void:
	var reduced: bool = UiData.reduced_motion()
	for wave: int in 2:
		var phase: float = 0.35 if reduced else fposmod(_phase + float(wave) * 0.5, 1.0)
		var radius: float = lerpf(DOT_RADIUS * 0.6, RING_MAX, Motion.ease_out(phase))
		draw_arc(from_point, radius, 0.0, TAU, 48, Color(UiKit.ACCENT, (1.0 - phase) * 0.8 + 0.1), 7.0, true)
	draw_circle(from_point, DOT_RADIUS * 0.45, Color(1.0, 1.0, 1.0, 0.9), true, -1.0, true)
	draw_arc(from_point, DOT_RADIUS * 0.45, 0.0, TAU, 28, UiKit.ACCENT, 5.0, true)
