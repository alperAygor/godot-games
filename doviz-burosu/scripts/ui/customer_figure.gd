class_name CustomerFigure
extends Control
## Gişenin ardındaki müşteri: omuzlar + palto + kafa (FaceView). Yüz kimliğinden palto rengi türer.
## `walk_in` kapıdan yürüyerek gelir (adım sallantısı + ayak sesi), `walk_out` yürüyüp gider; `talk` ağzı oynatır.

const COATS: Array[Color] = [Color("5B6B5E"), Color("6B5A4A"), Color("4A5668"), Color("7A4A4A"), Color("3F3F46"), Color("8A7B5A")]
const SIZE := Vector2(260, 240)
const HEAD := 120.0
const K := HEAD / 150.0  # çizim ölçeği

var face: FaceView
var coat := COATS[0]
var _tween: Tween
var _talk_tween: Tween
## Yerleşik (durma) konumu; walk_in/out bunun etrafında oynar.
var rest_x := 0.0


func _init() -> void:
	name = "CustomerFigure"
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	face = FaceView.new()
	face.caption = false
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.setup(0, "?", HEAD)
	face.position = Vector2((SIZE.x - HEAD) / 2.0, 16.0)
	add_child(face)


func dress(face_id: int, holder_name: String) -> void:
	face.setup(face_id, holder_name, HEAD)
	face.position = Vector2((SIZE.x - HEAD) / 2.0, 16.0)
	coat = COATS[Seed.fnv1a("coat|%d" % face_id) % COATS.size()]
	queue_redraw()


func _draw() -> void:
	var cx := SIZE.x / 2.0
	var neck_y := 16.0 + HEAD * 0.9
	# Boyun ve omuzlar (palto)
	draw_rect(Rect2(cx - 18, neck_y - 8, 36, 28), face_skin().darkened(0.12))
	var shoulders := PackedVector2Array([Vector2(cx - 32, neck_y + 10), Vector2(cx - 120, neck_y + 32), Vector2(cx - 134, SIZE.y), Vector2(cx + 134, SIZE.y), Vector2(cx + 120, neck_y + 32), Vector2(cx + 32, neck_y + 10)])
	draw_colored_polygon(shoulders, coat.darkened(0.25))
	draw_polyline(shoulders, Color(0, 0, 0, 0.55), 3.0)
	# Yaka ve gömlek
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 32, neck_y + 10), Vector2(cx + 32, neck_y + 10), Vector2(cx, neck_y + 78)]), Color("D8D2C0"))
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 32, neck_y + 10), Vector2(cx - 5, neck_y + 18), Vector2(cx - 48, neck_y + 72), Vector2(cx - 78, neck_y + 32)]), coat)
	draw_colored_polygon(PackedVector2Array([Vector2(cx + 32, neck_y + 10), Vector2(cx + 5, neck_y + 18), Vector2(cx + 48, neck_y + 72), Vector2(cx + 78, neck_y + 32)]), coat)
	if Seed.fnv1a("tie|%d" % face.face_id) % 3 != 0:
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 6, neck_y + 18), Vector2(cx + 6, neck_y + 18), Vector2(cx + 9, neck_y + 72), Vector2(cx, neck_y + 84), Vector2(cx - 9, neck_y + 72)]), Color("7A2E2A"))
	# Tezgâhın önünde kalan alt kısım karanlık
	draw_rect(Rect2(0, SIZE.y - 56, SIZE.x, 56), Color(0, 0, 0, 0.25))


func face_skin() -> Color:
	return FaceView.SKINS[int(FaceView.traits(face.face_id)["skin"])]


## Kapıdan (sağdan) yürüyüp durma noktasına gelir; adım sesi ve sallantı. `then` varış sonrası çağrılır.
func walk_in(rest: float, then: Callable) -> void:
	rest_x = rest
	visible = true
	modulate.a = 1.0
	if Feel.instant or not is_inside_tree():
		position.x = rest
		then.call()
		return
	if _tween != null:
		_tween.kill()
	position.x = rest + 400.0
	Feel.sfx("footsteps")
	_tween = create_tween()
	_tween.tween_property(self, "position:x", rest, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var bob := create_tween().set_loops(4)
	bob.tween_property(self, "rotation", 0.018, 0.14)
	bob.tween_property(self, "rotation", -0.018, 0.14)
	bob.finished.connect(func() -> void: rotation = 0.0)
	_tween.finished.connect(then)


## Yürüyüp sola gider ve kaybolur.
func walk_out() -> void:
	if Feel.instant or not is_inside_tree() or not visible:
		visible = false
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position:x", rest_x - 420.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.6).set_delay(0.3)
	_tween.finished.connect(func() -> void: visible = false)


func set_talking(on: bool) -> void:
	if _talk_tween != null:
		_talk_tween.kill()
	face.mouth_open = 0.0
	if not on or Feel.instant or not is_inside_tree():
		return
	_talk_tween = create_tween().set_loops()
	_talk_tween.tween_property(face, "mouth_open", 1.0, 0.09)
	_talk_tween.tween_property(face, "mouth_open", 0.2, 0.09)
