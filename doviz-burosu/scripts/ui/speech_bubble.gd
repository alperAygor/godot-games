class_name SpeechBubble
extends PanelContainer
## Müşterinin konuşma balonu: yazı harf harf belirir, her iki harfte "ses" bipi çalar, konuşma bitince ağız kapanır.
## Dokununca yazı hemen tamamlanır. `label.text` her zaman TAM metindir (yalnızca görünen harf sayısı oynar).

signal finished

var label: Label
var typing := false
var voice := 0.5
var figure: CustomerFigure
var _tween: Tween


func _init() -> void:
	name = "SpeechBubble"
	theme_type_variation = &"BubblePanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	label = Label.new()
	label.name = "CustomerSpeech"
	label.theme_type_variation = &"BubbleLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


## Metni yazdırarak söyler. `voice_seed` müşteriye göre sabit bir ses tizliği verir.
func say(text: String, voice_seed: int) -> void:
	voice = float(Seed.fnv1a("voice|%d" % voice_seed) % 100) / 100.0
	label.text = text
	visible = true
	size = Vector2(custom_minimum_size.x, 0.0)  # önceki uzun metnin yüksekliği kalmasın
	reset_size.call_deferred()
	if _tween != null:
		_tween.kill()
	if Feel.instant or not is_inside_tree():
		label.visible_characters = -1
		typing = false
		return
	label.visible_characters = 0
	typing = true
	if figure != null:
		figure.set_talking(true)
	var count := text.length()
	_tween = create_tween()
	_tween.tween_method(_reveal, 0.0, float(count), maxf(0.5, count * 0.032))
	_tween.finished.connect(_done)


func hide_bubble() -> void:
	if _tween != null:
		_tween.kill()
	typing = false
	visible = false
	if figure != null:
		figure.set_talking(false)


func skip() -> void:
	if not typing:
		return
	if _tween != null:
		_tween.kill()
	_done()


var _last_blip := -1


func _reveal(position_value: float) -> void:
	var shown := int(position_value)
	label.visible_characters = shown
	if shown != _last_blip and shown % 2 == 0 and shown < label.text.length() and label.text[shown] != " ":
		_last_blip = shown
		Feel.blip(voice)


func _done() -> void:
	typing = false
	_last_blip = -1
	label.visible_characters = -1
	if figure != null:
		figure.set_talking(false)
	finished.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		skip()
