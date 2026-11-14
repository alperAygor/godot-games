class_name BoothView
extends Control
## Gişe sahnesi: arka duvar, pencere ve ardındaki koridor, müşteri figürü, konuşma balonu, isim plakası.
## Katman sırası: arka plan (_draw) -> müşteri (kırpılı pencere) -> çerçeve+cam -> balon -> isim plakası -> uyarı fişi/duyuru katmanı.

signal customer_arrived

var figure: CustomerFigure
var bubble: SpeechBubble
var plate_label: Label
## Uyarı fişi ve gün ortası duyurusu bu katmana eklenir.
var overlay: Control

var _host: Control
var _frame: BoothFrame
var _plate: PanelContainer
var _window := Rect2()
var _lamp_glow: Texture2D = Glow.texture(Color(1.0, 0.82, 0.45), 0.2)


func _init() -> void:
	name = "BoothView"
	custom_minimum_size = Vector2(0, 380)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host = Control.new()
	_host.name = "WindowHost"
	_host.clip_contents = true
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)
	figure = CustomerFigure.new()
	_host.add_child(figure)
	figure.visible = false
	_frame = BoothFrame.new()
	add_child(_frame)
	bubble = SpeechBubble.new()
	bubble.figure = figure
	bubble.visible = false
	add_child(bubble)
	_plate = PanelContainer.new()
	_plate.theme_type_variation = &"PlatePanel"
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate_label = Label.new()
	plate_label.name = "CustomerName"
	plate_label.theme_type_variation = &"PlateLabel"
	plate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate.add_child(plate_label)
	add_child(_plate)
	overlay = Control.new()
	overlay.name = "BoothOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	_window = Rect2(44.0, 30.0, size.x - 88.0, size.y - 128.0)
	_host.position = _window.position
	_host.size = _window.size
	figure.position.y = _window.size.y - CustomerFigure.SIZE.y + 4.0
	figure.rest_x = _window.size.x * 0.66 - CustomerFigure.SIZE.x / 2.0
	if not figure.visible:
		figure.position.x = figure.rest_x
	_frame.position = Vector2.ZERO
	_frame.size = size
	_frame.window = _window
	bubble.custom_minimum_size.x = minf(_window.size.x * 0.5, 330.0)
	bubble.position = _window.position + Vector2(18.0, 14.0)
	_plate.custom_minimum_size.x = 300.0
	_plate.size = Vector2(300.0, 0.0)
	_plate.position = Vector2((size.x - 300.0) / 2.0, _window.end.y + 26.0)
	queue_redraw()


## Müşteriyi getirir: kapıdan yürür, durunca balon konuşmaya başlar.
func bring_customer(face_id: int, holder_name: String, text: String) -> void:
	for attempt in 4:  # ilk kare: yerleşim henüz hesaplanmadıysa bir kare bekle
		if size.x >= 100.0 or not is_inside_tree():
			break
		await get_tree().process_frame
	figure.dress(face_id, holder_name)
	plate_label.text = holder_name
	_plate.visible = true
	bubble.hide_bubble()
	bubble.size = Vector2(bubble.custom_minimum_size.x, 0.0)
	figure.walk_in(figure.rest_x, func() -> void:
		bubble.say(text, face_id)
		customer_arrived.emit())


func send_customer_away() -> void:
	bubble.hide_bubble()
	figure.walk_out()
	plate_label.text = ""
	_plate.visible = false


func clear_customer() -> void:
	bubble.hide_bubble()
	figure.visible = false
	plate_label.text = ""
	_plate.visible = false


func _draw() -> void:
	# Duvar: koyu yeşilimsi gri, alt tarafa doğru kararır; sıva lekeleri.
	draw_rect(Rect2(Vector2.ZERO, size), Color("2A322F"))
	draw_rect(Rect2(0, size.y * 0.55, size.x, size.y * 0.45), Color("222927"))
	var rng := Seed.rng("booth-wall")
	for i in 26:
		var at := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		draw_circle(at, rng.randf_range(8.0, 34.0), Color(0, 0, 0, 0.04))
	for i in 9:
		var x := rng.randf() * size.x
		draw_line(Vector2(x, 0), Vector2(x + rng.randf_range(-6, 6), rng.randf_range(30, 120)), Color(0, 0, 0, 0.12), 1.0)
	# Pencerenin ardı: koridor — uzaktaki lamba ve zemin
	if _window.size.x > 0.0:
		draw_rect(_window, Color("101514"))
		draw_rect(Rect2(_window.position.x, _window.position.y, _window.size.x, _window.size.y * 0.5), Color("1B2522"))
		draw_rect(Rect2(_window.position.x, _window.end.y - 40.0, _window.size.x, 40.0), Color("0C100F"))
		var lamp := Vector2(_window.position.x + _window.size.x * 0.2, _window.position.y + 18.0)
		draw_texture_rect(_lamp_glow, Rect2(lamp - Vector2(100, 100), Vector2(200, 200)), false)
		draw_circle(lamp, 8.0, Color("FFE9B0"))
		draw_rect(Rect2(_window.position.x + _window.size.x * 0.82, _window.position.y + 36.0, 54.0, _window.size.y - 76.0), Color("172120"))
		draw_rect(Rect2(_window.position.x + _window.size.x * 0.82, _window.position.y + 36.0, 54.0, _window.size.y - 76.0), Color("33413C"), false, 2.0)
