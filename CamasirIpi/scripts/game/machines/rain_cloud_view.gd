class_name RainCloudView
extends Node2D

## Yağmur bulutu: sıradaki yağışın ipinin üstünde yavaşça süzülür, gövdesinde kalan hamle yazar;
## o ipe yumuşak bir gölge düşer (oyuncu hangi ipin ıslanacağını önceden görür). Yağınca ipin
## üstünden damlalar dökülür. Kural `LaundryBoard`'dadır; bu sınıf yalnız gösterir. Düğümler bir
## kez kurulur; kare başına yalnız süzülme konumu yazılır.

const CLOUD_PATH: String = "res://assets/sprites/critters/cloud.png"
const DROP_PATH: String = "res://assets/sprites/critters/drop.png"
const CLOUD_WIDTH: float = 330.0
## Bulut ipin bu kadar üstünde (ip aralığına oran) ve yatay süzülme genliği/hızı.
const HOVER_RATIO: float = 0.32
const DRIFT_RATIO: float = 0.3
const DRIFT_SPEED: float = 0.35
const BOB_AMOUNT: float = 6.0
const BOB_SPEED: float = 1.3
const CLOUD_ALPHA: float = 0.95
const Z_INDEX: int = 85
const SHADOW_Z: int = 40
const SHADOW_COLOR: Color = Color(0.16, 0.22, 0.36, 0.3)
const SHADOW_HEIGHT_RATIO: float = 0.95
const FONT_SIZE: int = 54
const INK: Color = Color("4a5568")
const URGENT_INK: Color = Color("3e8ef7")
const MOVE_SECONDS: float = 0.8
const FADE_SECONDS: float = 0.5
const DROP_COUNT: int = 46
const DROP_LIFETIME: float = 0.75
const DROP_SPEED: float = 520.0
const POUR_SECONDS: float = 0.7

var _cloud: Sprite2D = null
var _label: Label = null
var _shadow: ShadowBand = null
var _drops: CPUParticles2D = null
var _anchor: Vector2 = Vector2.ZERO
var _center_x: float = 540.0
var _drift: float = 0.0
var _time: float = 0.0
var _move: Tween = null
var _spacing: float = 200.0
var _shown_line: int = LaundryBoard.EMPTY


## `board_width`: iplerin genişliği; `spacing`: ip aralığı (bulut ve gölge buna göre).
func setup(board_width: float, center_x: float, spacing: float) -> void:
	_center_x = center_x
	_spacing = spacing
	_drift = board_width * DRIFT_RATIO
	_shadow = ShadowBand.new()
	_shadow.size = Vector2(board_width, spacing * SHADOW_HEIGHT_RATIO)
	_shadow.modulate = SHADOW_COLOR
	_shadow.z_index = SHADOW_Z
	_shadow.visible = false
	add_child(_shadow)
	var cloud_texture: Texture2D = load(CLOUD_PATH) as Texture2D
	_cloud = Sprite2D.new()
	_cloud.texture = cloud_texture
	_cloud.scale = Vector2.ONE * (CLOUD_WIDTH / cloud_texture.get_size().x)
	_cloud.z_index = Z_INDEX
	_cloud.modulate.a = 0.0
	add_child(_cloud)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", INK)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size = Vector2(CLOUD_WIDTH * 0.5, FONT_SIZE * 1.4)
	_label.position = Vector2(-CLOUD_WIDTH * 0.25, -FONT_SIZE * 0.6)
	_label.z_index = Z_INDEX + 1
	_label.modulate.a = 0.0
	add_child(_label)
	_drops = CPUParticles2D.new()
	_drops.one_shot = true
	_drops.emitting = false
	_drops.amount = DROP_COUNT
	_drops.lifetime = DROP_LIFETIME
	_drops.explosiveness = 0.15
	_drops.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_drops.emission_rect_extents = Vector2(board_width * 0.5, 6.0)
	_drops.direction = Vector2.DOWN
	_drops.spread = 3.0
	_drops.gravity = Vector2(0.0, 600.0)
	_drops.initial_velocity_min = DROP_SPEED * 0.8
	_drops.initial_velocity_max = DROP_SPEED
	if ResourceLoader.exists(DROP_PATH):
		_drops.texture = load(DROP_PATH) as Texture2D
		_drops.scale_amount_min = 0.35
		_drops.scale_amount_max = 0.55
	_drops.z_index = Z_INDEX
	add_child(_drops)
	set_process(false)


## Sıradaki yağış: bulut ipin üstüne süzülür, ip gölgelenir. `left` = kalan hamle (yağmur yoksa -1).
func show_next(line: int, line_y: float, left: int, board_left: float) -> void:
	if left <= 0 or line == LaundryBoard.EMPTY:
		hide_cloud()
		return
	_label.text = str(left)
	_label.add_theme_color_override("font_color", URGENT_INK if left == 1 else INK)
	if line == _shown_line:
		return
	_shown_line = line
	var target: Vector2 = Vector2(_center_x, line_y - _spacing * HOVER_RATIO)
	_shadow.position = Vector2(board_left, line_y - _spacing * 0.08)
	_shadow.visible = true
	set_process(true)
	if _move != null:
		_move.kill()
	_move = create_tween().set_parallel(true)
	if _cloud.modulate.a < 0.05:
		_anchor = target + Vector2(0.0, -_spacing)
	_move.tween_property(self, "_anchor", target, MOVE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_move.tween_property(_cloud, "modulate:a", CLOUD_ALPHA, FADE_SECONDS)
	_move.tween_property(_label, "modulate:a", 1.0, FADE_SECONDS)
	_move.tween_property(_shadow, "modulate:a", SHADOW_COLOR.a, FADE_SECONDS).from(0.0)


## Yağdı: ipin üstünden damlalar dökülür; bulut sonraki adıma geçene dek gölge kalkar.
func pour(line_y: float) -> void:
	_drops.position = Vector2(_center_x, line_y - _spacing * 0.15)
	_drops.restart()
	_drops.emitting = true
	_shown_line = LaundryBoard.EMPTY
	_shadow.visible = false


func hide_cloud() -> void:
	_shown_line = LaundryBoard.EMPTY
	_shadow.visible = false
	if _cloud.modulate.a <= 0.0:
		set_process(false)
		return
	if _move != null:
		_move.kill()
	_move = create_tween().set_parallel(true)
	_move.tween_property(_cloud, "modulate:a", 0.0, FADE_SECONDS)
	_move.tween_property(_label, "modulate:a", 0.0, FADE_SECONDS)
	_move.tween_property(self, "_anchor", _anchor + Vector2(0.0, -_spacing * 0.5), FADE_SECONDS)


## Hafif süzülme ve inip kalkma: bulut aynı çamaşırı sürekli örtmesin.
func _process(delta: float) -> void:
	_time += delta
	var at: Vector2 = _anchor + Vector2(_drift * sin(_time * DRIFT_SPEED), BOB_AMOUNT * sin(_time * BOB_SPEED))
	_cloud.position = at
	_label.position = at + Vector2(-CLOUD_WIDTH * 0.25, -FONT_SIZE * 0.45)


## İpin gölgesi: kenarları yumuşak yatay bant (birkaç şerit; yalnız kurulumda çizilir).
class ShadowBand extends Node2D:
	const STRIPES: int = 16
	var size: Vector2 = Vector2(800.0, 150.0)

	func _draw() -> void:
		var step: float = size.y / float(STRIPES)
		for index: int in range(STRIPES):
			var middle: float = absf((float(index) + 0.5) / float(STRIPES) - 0.5) * 2.0
			var alpha: float = clampf(1.0 - middle * middle, 0.0, 1.0)
			draw_rect(Rect2(0.0, step * float(index), size.x, step + 0.5), Color(1.0, 1.0, 1.0, alpha))
