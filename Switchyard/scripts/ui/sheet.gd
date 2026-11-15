class_name Sheet
extends Control

## Yeniden kullanılabilir alt sayfa: yumuşak karartma + aşağıdan yükselen krem kart.
## Giriş: solma + yükselme (Motion.OVERLAY_*). Çıkış: kısa solma.
## `pause_tree` açıksa sayfa açıkken oyun durur; sayfa kapanınca/silinince devam eder.
## Sayfa süreç kipi ALWAYS: oyun duraklatılmışken de animasyonları ve dokunuşu işler.

signal closed

const CARD_SIDE_GAP: float = UiKit.SPACE_XL
const EXIT_SECONDS: float = 0.22
## Çıkış yükselme mesafesi: girişin yarısı (kapanış girişten daha sakin ve kısa).
const EXIT_RISE_RATIO: float = 0.5

var dismiss_on_dim: bool = false
var _pause_tree: bool = false
var _dim: ColorRect = null
var _rise: Control = null
var _card: PanelContainer = null
var _content: VBoxContainer = null
var _closing: bool = false
var _bottom_gap: float = 0.0


## Boş sayfayı kurar ve `parent` altına ekler; içerik `content()` ile doldurulur,
## sonra `play_intro()` çağrılır.
func build(parent: Node, pause_tree: bool) -> void:
	_pause_tree = pause_tree
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = UiKit.DIM
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.gui_input.connect(_on_dim_input)
	add_child(_dim)
	# Kart bir kapsayıcı içinde: kapsayıcıyı kaydırmak çapa/yerleşimi bozmadan yükselme verir.
	_rise = Control.new()
	_rise.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rise)
	_card = PanelContainer.new()
	_card.theme_type_variation = &"SheetPanel"
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_rise.add_child(_card)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 0)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(_content)
	var viewport_size: Vector2 = parent.get_viewport().get_visible_rect().size \
		if parent.is_inside_tree() else Vector2(1080.0, 1920.0)
	_bottom_gap = maxf(UiKit.safe_insets(viewport_size).w, UiKit.MIN_BOTTOM_MARGIN)
	# Alt kenara yapışmaz: kart yan ve alt boşlukla yüzer, içerik büyüdükçe yukarı uzar.
	_card.anchor_left = 0.0
	_card.anchor_right = 1.0
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.offset_left = CARD_SIDE_GAP
	_card.offset_right = -CARD_SIDE_GAP
	_card.offset_bottom = -_bottom_gap
	_card.offset_top = -_bottom_gap
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	parent.add_child(self)
	if _pause_tree:
		get_tree().paused = true


func content() -> VBoxContainer:
	return _content


## Standart sayfa anatomisi (bkz. docs/UI_GUIDE.md): başlık -> içerik -> tek birincil eylem.
## Başlık her sayfada aynı boy ve renkte; alt boşluk SPACE_LG.
func add_title(text: String) -> Label:
	var title: Label = UiKit.wrap_label(text, UiKit.TITLE_SIZE)
	_content.add_child(title)
	_content.add_child(UiKit.spacer(UiKit.SPACE_LG))
	return title


func add_gap(height: float) -> void:
	_content.add_child(UiKit.spacer(height))


## Sayfanın alt eylemi (başparmak bölgesi: içeriğin en altı). `primary` dolu yeşil, değilse sakin ikincil.
func add_action(text: String, primary: bool, icon_name: String = "") -> Button:
	var node: Button = UiKit.button(text, &"" if primary else &"SecondaryButton", icon_name,
		UiKit.HEIGHT_PRIMARY if primary else UiKit.HEIGHT_SECONDARY)
	_content.add_child(node)
	return node


func card() -> PanelContainer:
	return _card


func play_intro() -> void:
	modulate.a = 0.0
	_rise.position.y = Motion.OVERLAY_RISE_DISTANCE
	var intro: Tween = create_tween().set_parallel(true)
	intro.tween_property(self, "modulate:a", 1.0, Motion.OVERLAY_FADE_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	intro.tween_property(_rise, "position:y", 0.0, Motion.OVERLAY_RISE_SECONDS)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Yumuşakça kapanır, sonra silinir. Oyun bu sayfa yüzünden durmuşsa devam ettirir.
func close() -> void:
	if _closing:
		return
	_closing = true
	_release_pause()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outro: Tween = create_tween().set_parallel(true)
	outro.tween_property(self, "modulate:a", 0.0, EXIT_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	outro.tween_property(_rise, "position:y", Motion.OVERLAY_RISE_DISTANCE * EXIT_RISE_RATIO, EXIT_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	outro.chain().tween_callback(_finish_close)


func _finish_close() -> void:
	closed.emit()
	queue_free()


func _release_pause() -> void:
	if _pause_tree and is_inside_tree():
		get_tree().paused = false
		_pause_tree = false


func _exit_tree() -> void:
	# Dışarıdan (ör. `_hide_overlay`) silinse bile oyun donuk kalmasın.
	_release_pause()


func _on_dim_input(event: InputEvent) -> void:
	if not dismiss_on_dim:
		return
	var pressed: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if pressed:
		close()
