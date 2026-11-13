class_name MapCanvas
extends Control

## Haritanın çizim + kaydırma yüzeyi. TEK Control: düğüm başına sahne düğümü yok; yalnız ekranda
## görünen seviyeler `_draw` içinde çizilir (500+ seviye de akıcı kayar). Kare başına yeni nesne
## üretilmez: metinler, stil kutuları, nokta dizileri ve yıldız çokgeni önceden/bir kez kurulur.
## Çizim yalnız kaydırma değişince yenilenir (`queue_redraw`); durağan haritada iş yok.
## Dokunuş: sürükle = kaydır (+ atalet), kısa dokunuş = seviye seçimi (`level_tapped`).

signal level_tapped(level: int)
signal current_visibility_changed(on_screen: bool)

const ROPE_PAST: Color = Color("a98b68")
const ROPE_FUTURE: Color = Color(0.66, 0.55, 0.41, 0.38)
const ROPE_SHADOW: Color = Color(0.25, 0.2, 0.12, 0.09)
const ROPE_WIDTH: float = 7.0
const ROPE_SAMPLES_PER_LEVEL: int = 8
const ROPE_SHADOW_OFFSET: Vector2 = Vector2(0.0, 7.0)
const REGION_ALPHA: float = 0.32
const DROP: float = 56.0
const NODE_RADIUS: float = 50.0
const CURRENT_RADIUS: float = 66.0
const HALO_EXTRA: float = 26.0
const HALO_ALPHA: float = 0.2
const SHADOW_ALPHA: float = 0.08
const SHADOW_OFFSET: float = 7.0
const NODE_FONT: int = 42
const CURRENT_FONT: int = 54
const DIVIDER_FONT: int = 30
const CLEARED_FILL: Color = Color("dcefe3")
const CLEARED_INK: Color = Color("2c8a60")
const CURRENT_FILL: Color = UiKit.ACCENT
const FUTURE_FILL: Color = Color("ebe7da")
const FUTURE_INK: Color = Color(0.49, 0.52, 0.5, 0.85)
const FUTURE_ALPHA: float = 0.72
const PEG_COLOR: Color = Color("c9a468")
const PEG_SIZE: Vector2 = Vector2(22.0, 52.0)
const PEG_TOP: float = 16.0
const PEG_RADIUS: int = 8
const STAR_RADIUS: float = 15.0
const STAR_STEP: float = 38.0
const STAR_DROP: float = 28.0
const BADGE_RADIUS: float = 21.0
const BADGE_ICON: float = 26.0
const BADGE_ALPHA_FUTURE: float = 0.6
const CHEST_SIZE: float = 74.0
const CHEST_GAP: float = 54.0
const CHEST_RADIUS: int = 24
const CHEST_ICON: float = 40.0
const CHEST_FILL: Color = Color("f8e6b4")
const CHEST_INK: Color = Color("d99a1f")
const CHEST_DONE_FILL: Color = Color("e9e6dc")
const CHEST_DONE_INK: Color = Color("a8aca6")
const PILL_HEIGHT: float = 64.0
const PILL_PAD: float = 30.0
const PILL_DOT: float = 13.0
const PILL_FILL: Color = Color(1.0, 1.0, 1.0, 0.82)
const HIT_RADIUS: float = 96.0
const TAP_SLOP: float = 22.0
const WHEEL_STEP: float = 180.0
const FRICTION: float = 4.2
const MIN_VELOCITY: float = 14.0
const VELOCITY_SMOOTH: float = 0.35
const FLING_MAX_AGE_MSEC: int = 90
const MS_PER_SECOND: float = 1000.0
const TOP_PAD: float = 300.0
const BOTTOM_PAD: float = 420.0
const CURRENT_ANCHOR: float = 0.58
const FOCUS_SECONDS: float = 0.6
## Mevcut seviye harita en alttayken ekranın bu oranından aşağıdaysa (erken oyun) alt konuma oturulur.
const EARLY_VIEW_RATIO: float = 0.25
const DRAW_MARGIN_LEVELS: int = 2
const BADGE_COLORS: Dictionary = {
	MapModel.Kind.HARD: Color("f5894a"),
	MapModel.Kind.BOSS: Color("9b59d0"),
	MapModel.Kind.MOVES: Color("3e8ef7"),
	MapModel.Kind.SHORT_RACK: Color("e5484d"),
	MapModel.Kind.ORDERS: Color("3dbb6e"),
}
const BADGE_ICONS: Dictionary = {
	MapModel.Kind.HARD: "lucide/flame",
	MapModel.Kind.BOSS: "lucide/shield",
	MapModel.Kind.MOVES: "lucide/clock",
	MapModel.Kind.SHORT_RACK: "lucide/zap",
	MapModel.Kind.ORDERS: "lucide/shirt",
}

var scroll_top: float = 0.0
var _current: int = 1
var _max_level: int = 60
var _font: Font = null
var _numbers: PackedStringArray = PackedStringArray()
var _kinds: PackedByteArray = PackedByteArray()
var _chests: Dictionary[int, bool] = {}
var _dividers: PackedInt32Array = PackedInt32Array()
var _divider_texts: PackedStringArray = PackedStringArray()
var _divider_widths: PackedFloat32Array = PackedFloat32Array()
var _region_tints: PackedColorArray = PackedColorArray()
var _rope_past: PackedVector2Array = PackedVector2Array()
var _rope_future: PackedVector2Array = PackedVector2Array()
var _peg_style: StyleBoxFlat = null
var _chest_style: StyleBoxFlat = null
var _chest_done_style: StyleBoxFlat = null
var _pill_style: StyleBoxFlat = null
var _icons: Dictionary[int, Texture2D] = {}
var _chest_icon: Texture2D = null
var _claimed: Array[int] = []
var _pressed: bool = false
var _moved: bool = false
var _press_position: Vector2 = Vector2.ZERO
var _last_msec: int = 0
var _velocity: float = 0.0
var _focus_tween: Tween = null
var _was_on_screen: bool = true


func setup(current_level: int) -> void:
	_current = maxi(current_level, 1)
	_max_level = MapModel.total_levels(_current)
	_font = get_theme_default_font()
	_numbers.resize(_max_level + 1)
	for level: int in range(_max_level + 1):
		_numbers[level] = str(level)
	_kinds.resize(_max_level + 1)
	_kinds.fill(MapModel.KIND_UNKNOWN)
	_chests = MapModel.chest_levels(_max_level)
	_claimed = Milestones.claimed_levels(RetentionFlow.milestone_state())
	_build_dividers()
	_peg_style = _flat_box(PEG_COLOR, PEG_RADIUS)
	_chest_style = _flat_box(CHEST_FILL, CHEST_RADIUS)
	_chest_done_style = _flat_box(CHEST_DONE_FILL, CHEST_RADIUS)
	_pill_style = _flat_box(PILL_FILL, int(PILL_HEIGHT * 0.5))
	for kind: int in BADGE_ICONS.keys():
		_icons[kind] = MapIcons.texture(String(BADGE_ICONS[kind]))
	_chest_icon = MapIcons.texture("lucide/package")
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	set_process(false)


func _flat_box(color: Color, radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.anti_aliasing = true
	return box


func _build_dividers() -> void:
	_dividers = MapModel.dividers(_max_level)
	_divider_texts.clear()
	_divider_widths.clear()
	_region_tints.clear()
	for level: int in _dividers:
		var text: String = MapModel.divider_label(level)
		_divider_texts.append(text)
		var measured: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, DIVIDER_FONT).x
		_divider_widths.append(measured + PILL_PAD * 2.0 + PILL_DOT * 2.0 + PILL_PAD * 0.5)
		_region_tints.append(MapModel.tint_for(level))


# --- Kaydırma -------------------------------------------------------------------------------

func top_limit() -> float:
	return MapModel.world_y(float(_max_level)) - TOP_PAD


func bottom_limit() -> float:
	return MapModel.world_y(1.0) + BOTTOM_PAD - size.y


func set_scroll(value: float) -> void:
	var low: float = top_limit()
	var high: float = maxf(bottom_limit(), low)
	var clamped: float = clampf(value, low, high)
	if is_equal_approx(clamped, scroll_top):
		return
	scroll_top = clamped
	queue_redraw()
	_notify_visibility()


## Seviyeyi ekranda `anchor` (0 üst, 1 alt) oranına getirir; animasyonlu ya da anında.
func focus_level(level: int, animated: bool, anchor: float = CURRENT_ANCHOR) -> void:
	var target: float = MapModel.world_y(float(level)) - size.y * anchor
	# Başlangıçta (ilk birkaç seviye) harita en alta oturur: 1. seviye ve ilk ayraç görünür kalsın.
	if MapModel.world_y(float(level)) - bottom_limit() > size.y * EARLY_VIEW_RATIO:
		target = bottom_limit()
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	_velocity = 0.0
	if not animated:
		set_scroll(target)
		return
	_focus_tween = create_tween()
	_focus_tween.tween_method(set_scroll, scroll_top, clampf(target, top_limit(), maxf(bottom_limit(), top_limit())),
		FOCUS_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func current_on_screen() -> bool:
	var y: float = MapModel.world_y(float(_current)) - scroll_top
	return y > -DROP and y < size.y - CURRENT_RADIUS


func _notify_visibility() -> void:
	var on_screen: bool = current_on_screen()
	if on_screen != _was_on_screen:
		_was_on_screen = on_screen
		current_visibility_changed.emit(on_screen)


func _process(delta: float) -> void:
	if absf(_velocity) < MIN_VELOCITY:
		_velocity = 0.0
		set_process(false)
		return
	var before: float = scroll_top
	set_scroll(scroll_top + _velocity * delta)
	if is_equal_approx(before, scroll_top):
		_velocity = 0.0
	_velocity *= exp(-FRICTION * delta)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			focus_stop()
			set_scroll(scroll_top - WHEEL_STEP)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			focus_stop()
			set_scroll(scroll_top + WHEEL_STEP)
		elif button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_begin_press(button.position)
			else:
				_end_press(button.position)
	elif event is InputEventMouseMotion and _pressed:
		_drag((event as InputEventMouseMotion).position, (event as InputEventMouseMotion).relative)


func focus_stop() -> void:
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	_velocity = 0.0


func _begin_press(at: Vector2) -> void:
	focus_stop()
	_pressed = true
	_moved = false
	_press_position = at
	_last_msec = Time.get_ticks_msec()


func _drag(at: Vector2, relative: Vector2) -> void:
	if not _moved and at.distance_to(_press_position) > TAP_SLOP:
		_moved = true
	if not _moved:
		return
	var now: int = Time.get_ticks_msec()
	var dt: float = maxf(float(now - _last_msec) / MS_PER_SECOND, 0.001)
	_last_msec = now
	_velocity = lerpf(_velocity, -relative.y / dt, VELOCITY_SMOOTH)
	set_scroll(scroll_top - relative.y)


func _end_press(at: Vector2) -> void:
	if not _pressed:
		return
	_pressed = false
	if not _moved:
		var hit: int = level_at_point(at)
		if hit > 0:
			level_tapped.emit(hit)
		return
	# Parmak durup bırakıldıysa atalet yok (eski hız geçersiz).
	if Time.get_ticks_msec() - _last_msec > FLING_MAX_AGE_MSEC:
		_velocity = 0.0
	if absf(_velocity) >= MIN_VELOCITY:
		set_process(true)


## Ekran noktasındaki seviye numarası (disklere yakınlık); yoksa 0.
func level_at_point(point: Vector2) -> int:
	var estimate: int = int(round(MapModel.level_at(point.y + scroll_top - DROP)))
	var best: int = 0
	var best_distance: float = HIT_RADIUS
	for level: int in range(maxi(estimate - 1, 1), mini(estimate + 1, _max_level) + 1):
		var center: Vector2 = Vector2(MapModel.world_x(float(level)), MapModel.world_y(float(level)) - scroll_top + DROP)
		var distance: float = center.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = level
	return best


# --- Çizim ----------------------------------------------------------------------------------

func _draw() -> void:
	if _font == null:
		return
	var span: Vector2i = MapModel.visible_range(scroll_top, scroll_top + size.y, _max_level, DRAW_MARGIN_LEVELS)
	_draw_regions(span)
	_draw_rope(span)
	_draw_dividers(span)
	for level: int in range(span.x, span.y + 1):
		if _chests.has(level):
			_draw_chest(level)
	for level: int in range(span.x, span.y + 1):
		if level != _current:
			_draw_node(level)
	if _current >= span.x and _current <= span.y:
		_draw_node(_current)


## Bölge zeminleri: her bölge kendi hafif tonuyla (mekân gökyüzü + mevsim) ayrışır.
func _draw_regions(span: Vector2i) -> void:
	var first: int = _region_index(span.x)
	var last: int = _region_index(span.y)
	for index: int in range(first, last + 1):
		var start_y: float = _boundary_y(_dividers[index]) - scroll_top
		var end_y: float = (_boundary_y(_dividers[index + 1]) - scroll_top) if index + 1 < _dividers.size() \
			else -size.y
		var top: float = maxf(minf(start_y, end_y), -1.0)
		var bottom: float = minf(maxf(start_y, end_y), size.y + 1.0)
		if bottom <= top:
			continue
		var tint: Color = _region_tints[index]
		tint.a = REGION_ALPHA
		draw_rect(Rect2(0.0, top, size.x, bottom - top), tint)


func _region_index(level: int) -> int:
	return clampi(_dividers.bsearch(level, false) - 1, 0, _dividers.size() - 1)


## Bölge sınırının dünya y'si: başlangıç seviyesinin biraz altı (iki seviye arası).
func _boundary_y(level: int) -> float:
	return MapModel.world_y(float(level)) + MapModel.STEP * 0.5


func _draw_rope(span: Vector2i) -> void:
	var from_level: float = float(maxi(span.x - 1, 1))
	var to_level: float = float(mini(span.y + 1, _max_level))
	var samples: int = int((to_level - from_level) * float(ROPE_SAMPLES_PER_LEVEL)) + 1
	var past_count: int = 0
	var future_count: int = 0
	_rope_past.resize(samples + 1)
	_rope_future.resize(samples + 1)
	for index: int in range(samples):
		var level: float = from_level + float(index) / float(ROPE_SAMPLES_PER_LEVEL)
		var point: Vector2 = Vector2(MapModel.world_x(level), MapModel.world_y(level) - scroll_top)
		if level <= float(_current):
			_rope_past[past_count] = point
			past_count += 1
		else:
			# Geçiş noktası: iki çizgi arasında boşluk kalmasın diye gelecek çizgi mevcut düğümden başlar.
			if future_count == 0 and past_count > 0:
				_rope_future[0] = _rope_past[past_count - 1]
				future_count = 1
			_rope_future[future_count] = point
			future_count += 1
	if past_count > 1:
		_rope_past.resize(past_count)
		draw_set_transform(ROPE_SHADOW_OFFSET, 0.0, Vector2.ONE)
		draw_polyline(_rope_past, ROPE_SHADOW, ROPE_WIDTH + 2.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_polyline(_rope_past, ROPE_PAST, ROPE_WIDTH, true)
	if future_count > 1:
		_rope_future.resize(future_count)
		draw_polyline(_rope_future, ROPE_FUTURE, ROPE_WIDTH, true)


func _draw_dividers(span: Vector2i) -> void:
	var first: int = _region_index(span.x)
	var last: int = mini(_region_index(span.y) + 1, _dividers.size() - 1)
	for index: int in range(first, last + 1):
		var y: float = _boundary_y(_dividers[index]) - scroll_top
		if y < -PILL_HEIGHT or y > size.y + PILL_HEIGHT:
			continue
		var width: float = _divider_widths[index]
		var rect: Rect2 = Rect2(Vector2((size.x - width) * 0.5, y - PILL_HEIGHT * 0.5), Vector2(width, PILL_HEIGHT))
		draw_style_box(_pill_style, rect)
		var tint: Color = _region_tints[index]
		tint.a = 1.0
		draw_circle(Vector2(rect.position.x + PILL_PAD + PILL_DOT, y), PILL_DOT, tint.darkened(0.08), true, -1.0, true)
		var baseline: float = y + (_font.get_ascent(DIVIDER_FONT) - _font.get_descent(DIVIDER_FONT)) * 0.5
		draw_string(_font, Vector2(rect.position.x + PILL_PAD + PILL_DOT * 2.0 + PILL_PAD * 0.5, baseline),
			_divider_texts[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, DIVIDER_FONT, UiKit.TEXT_MUTED)


func _draw_chest(level: int) -> void:
	var center_x: float = MapModel.world_x(float(level))
	var side: float = 1.0 if center_x < MapModel.CENTER_X else -1.0
	var y: float = MapModel.world_y(float(level)) - scroll_top + DROP
	var x: float = center_x + side * (NODE_RADIUS + CHEST_GAP + CHEST_SIZE * 0.5)
	var done: bool = _claimed.has(level)
	var rect: Rect2 = Rect2(Vector2(x, y) - Vector2(CHEST_SIZE, CHEST_SIZE) * 0.5, Vector2(CHEST_SIZE, CHEST_SIZE))
	draw_style_box(_chest_done_style if done or level > _current else _chest_style, rect)
	if _chest_icon != null:
		var half: float = CHEST_ICON * 0.5
		draw_texture_rect(_chest_icon, Rect2(Vector2(x, y) - Vector2(half, half), Vector2(half, half) * 2.0), false,
			CHEST_DONE_INK if done or level > _current else CHEST_INK)


func _kind_at(level: int) -> int:
	var cached: int = _kinds[level]
	if cached == MapModel.KIND_UNKNOWN:
		cached = MapModel.kind_for(level)
		_kinds[level] = cached
	return cached


func _draw_node(level: int) -> void:
	var rope_y: float = MapModel.world_y(float(level)) - scroll_top
	var x: float = MapModel.world_x(float(level))
	var is_current: bool = level == _current
	var cleared: bool = level < _current
	var radius: float = CURRENT_RADIUS if is_current else NODE_RADIUS
	var center: Vector2 = Vector2(x, rope_y + DROP + (radius - NODE_RADIUS) * 0.5)
	var fade: float = 1.0 if level <= _current else FUTURE_ALPHA
	if is_current:
		draw_circle(center, radius + HALO_EXTRA, Color(CURRENT_FILL, HALO_ALPHA), true, -1.0, true)
	draw_circle(center + Vector2(0.0, SHADOW_OFFSET), radius, Color(0.0, 0.0, 0.0, SHADOW_ALPHA * fade), true, -1.0, true)
	var fill: Color = CURRENT_FILL if is_current else (CLEARED_FILL if cleared else FUTURE_FILL)
	var ink: Color = Color.WHITE if is_current else (CLEARED_INK if cleared else FUTURE_INK)
	draw_circle(center, radius, fill, true, -1.0, true)
	var font_size: int = CURRENT_FONT if is_current else NODE_FONT
	var baseline: float = center.y + (_font.get_ascent(font_size) - _font.get_descent(font_size)) * 0.5
	draw_string(_font, Vector2(center.x - radius, baseline), _numbers[level], HORIZONTAL_ALIGNMENT_CENTER,
		radius * 2.0, font_size, ink)
	# Mandal: sicimi ve diskin üstünü kavrar (diskten SONRA çizilir, kıskaç görünümü).
	draw_style_box(_peg_style, Rect2(Vector2(x - PEG_SIZE.x * 0.5, rope_y - PEG_TOP), PEG_SIZE))
	if cleared:
		var best: int = Progress.best_stars(level)
		var star_y: float = center.y + radius + STAR_DROP
		for index: int in range(StarRating.MAX_STARS):
			MapDraw.star(self, Vector2(x + (float(index) - 1.0) * STAR_STEP, star_y), STAR_RADIUS,
				MapDraw.STAR_COLOR if index < best else MapDraw.STAR_OFF)
	var kind: int = _kind_at(level)
	if kind != MapModel.Kind.NORMAL:
		_draw_badge(kind, center + Vector2(radius, -radius) * 0.74, fade)


func _draw_badge(kind: int, at: Vector2, fade: float) -> void:
	var color: Color = BADGE_COLORS[kind] as Color
	color.a = 1.0 if fade >= 1.0 else BADGE_ALPHA_FUTURE
	draw_circle(at, BADGE_RADIUS, color, true, -1.0, true)
	var icon: Texture2D = _icons.get(kind) as Texture2D
	if icon != null:
		var half: float = BADGE_ICON * 0.5
		draw_texture_rect(icon, Rect2(at - Vector2(half, half), Vector2(half, half) * 2.0), false, Color.WHITE)
