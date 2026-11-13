class_name RetTrack
extends Control

## Haftalık etkinliğin 5 kademeli yolu: tek çizgi üstünde sandık düğümleri.
## Çizgi, kademe aralıklarıyla EŞİT bölünür (ilerleme her aralıkta kendi oranıyla dolar);
## böylece 12 ile 120 hedefleri aynı çizgide okunur kalır. Alınabilir düğüme dokunulursa `tier_pressed`.

signal tier_pressed(tier: int)

const NODE_RADIUS: float = 52.0
const ICON_PIXELS: float = 48.0
const LINE_HEIGHT: float = 12.0
const LABEL_SIZE: int = 32
const REWARD_SIZE: int = 26
const TRACK_HEIGHT: float = 250.0
const CLAIMED_ALPHA: float = 0.9
const PULSE_SECONDS: float = 0.9
const PULSE_AMOUNT: float = 0.07
const CHEST_ICON: String = "lucide/package"
const CHECK_ICON: String = "lucide/check"
const TRACK_COLOR: Color = Color("e6e2d5")
const LOCKED_DISC: Color = Color("e9e6dc")

var _targets: Array[int] = []
var _rewards: Array[int] = []
var _progress: int = 0
var _claimed: Array[bool] = []
var _tint: Color = UiKit.ACCENT
var _pulse: float = 0.0
var _tween: Tween = null
var _shown_fraction: float = 0.0
var _fraction_tween: Tween = null


func setup(targets: Array[int], reward_coins: Array[int], claimed: Array[bool], progress: int, tint: Color) -> void:
	_targets = targets
	_rewards = reward_coins
	_claimed = claimed
	_progress = progress
	_tint = tint
	custom_minimum_size = Vector2(0.0, TRACK_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shown_fraction = _fraction()
	if _claimable().size() > 0:
		_tween = create_tween().set_loops()
		_tween.tween_method(_set_pulse, 0.0, 1.0, PULSE_SECONDS)
		_tween.tween_method(_set_pulse, 1.0, 0.0, PULSE_SECONDS)


func _set_pulse(value: float) -> void:
	_pulse = value
	queue_redraw()


func _claimable() -> Array[int]:
	var result: Array[int] = []
	for tier: int in range(_targets.size()):
		if _progress >= _targets[tier] and not _claimed[tier]:
			result.append(tier)
	return result


## Çizginin dolu kısmı (0..1): kademeler eşit aralıklı.
func _fraction() -> float:
	var count: int = _targets.size()
	if count == 0:
		return 0.0
	var previous: int = 0
	for tier: int in range(count):
		if _progress < _targets[tier]:
			var span: int = maxi(_targets[tier] - previous, 1)
			return (float(tier) + float(_progress - previous) / float(span)) / float(count)
		previous = _targets[tier]
	return 1.0


func _origin_x() -> float:
	return NODE_RADIUS * 0.5


func _node_center(tier: int) -> Vector2:
	# Çizgi sıfır noktasından başlar; her düğüm kendi kademesinin SONUNDA, eşit aralıkla durur.
	var segment: float = (size.x - NODE_RADIUS - _origin_x()) / float(maxi(_targets.size(), 1))
	return Vector2(_origin_x() + segment * float(tier + 1), NODE_RADIUS + 6.0)


func _draw() -> void:
	var count: int = _targets.size()
	if count == 0:
		return
	var font: Font = get_theme_default_font()
	var y: float = NODE_RADIUS + 6.0
	var origin: float = _origin_x()
	var last_x: float = _node_center(count - 1).x
	var back: StyleBoxFlat = StyleBoxFlat.new()
	back.bg_color = TRACK_COLOR
	back.set_corner_radius_all(int(LINE_HEIGHT * 0.5))
	back.anti_aliasing = true
	draw_style_box(back, Rect2(Vector2(origin, y - LINE_HEIGHT * 0.5), Vector2(last_x - origin, LINE_HEIGHT)))
	var fill_x: float = origin + (last_x - origin) * _shown_fraction
	var front: StyleBoxFlat = StyleBoxFlat.new()
	front.bg_color = _tint
	front.set_corner_radius_all(int(LINE_HEIGHT * 0.5))
	front.anti_aliasing = true
	draw_style_box(front, Rect2(Vector2(origin, y - LINE_HEIGHT * 0.5), Vector2(maxf(fill_x - origin, LINE_HEIGHT), LINE_HEIGHT)))
	for tier: int in range(count):
		var center: Vector2 = _node_center(tier)
		var reached: bool = _progress >= _targets[tier]
		var claimed: bool = _claimed[tier]
		var disc: Color = LOCKED_DISC
		var tint: Color = UiKit.TEXT_MUTED
		var icon: String = CHEST_ICON
		var radius: float = NODE_RADIUS
		if claimed:
			disc = UiKit.ACCENT_SOFT
			tint = UiKit.ACCENT
			icon = CHECK_ICON
		elif reached:
			disc = UiKit.GOLD
			tint = Color.WHITE
			radius *= 1.0 + PULSE_AMOUNT * _pulse
		else:
			disc = Color("f1eee4")
		draw_circle(center, radius, disc, true, -1.0, true)
		var texture: Texture2D = Icons.texture(icon)
		if texture != null:
			var half: float = ICON_PIXELS * 0.5
			draw_texture_rect(texture, Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0), false, tint)
		var target_text: String = str(_targets[tier])
		var text_color: Color = UiKit.TEXT_MUTED if not reached else UiKit.TEXT
		draw_string(font, Vector2(center.x - 100.0, center.y + NODE_RADIUS + 46.0), target_text,
			HORIZONTAL_ALIGNMENT_CENTER, 200.0, LABEL_SIZE, text_color)
		draw_string(font, Vector2(center.x - 100.0, center.y + NODE_RADIUS + 88.0), "+%d" % _rewards[tier],
			HORIZONTAL_ALIGNMENT_CENTER, 200.0, REWARD_SIZE,
			UiKit.GOLD if not claimed else UiKit.TEXT_MUTED)


func _gui_input(event: InputEvent) -> void:
	var press: bool = event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if not press and not (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		return
	var at: Vector2 = (event as InputEventMouse).position if event is InputEventMouse \
		else (event as InputEventScreenTouch).position
	for tier: int in _claimable():
		if at.distance_to(_node_center(tier)) <= NODE_RADIUS * 1.4:
			tier_pressed.emit(tier)
			return


## Düğümün sayfaya göre merkezi (kutlama konumu için).
func node_global_center(tier: int) -> Vector2:
	return global_position + _node_center(tier)
