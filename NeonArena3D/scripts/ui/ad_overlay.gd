class_name AdOverlay
extends Control
## Reklam akışının tam ekran katmanı (menülerin ÜSTÜNDE, duraklatma sırasında da çalışır):
##  * teklif: "İZLE VE CANLAN" + kısa geri sayım halkası + açık VAZGEÇ düğmesi (süre bitince de vazgeçilmiş sayılır),
##  * perde: reklam gösterilirken tıklamaları yutan loş katman (gerçek SDK reklamı bunun üstüne biner).
## Mantık burada değil: yalnız `accepted` / `declined` sinyalleri; karar `MonetizationHooks`ta. Geri sayım gerçek zamanla
## akar (Engine.time_scale'den bağımsız) ve `advance(dt)` ile elle de ilerletilebilir (probe).

const KIT = preload("res://scripts/ui/ui_kit.gd")

signal accepted
signal declined

var countdown: AdFlow.Countdown
var offer_visible := false
var veil_visible := false
var accept_button: Button
var decline_button: Button
var _offer: Control
var _offer_title: Label
var _offer_sub: Label
var _veil_label: Label
var _veil: Control
var _number: Label
var _ring: Control
var _last_us := 0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_offer()
	_build_veil()
	set_process(false)


func _build_offer() -> void:
	_offer = Control.new()
	_offer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_offer.mouse_filter = Control.MOUSE_FILTER_STOP
	_offer.visible = false
	add_child(_offer)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(KIT.BG, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offer.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offer.add_child(center)
	var panel := KIT.panel(KIT.GOLD, 26.0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(440, 0)
	panel.add_child(box)
	_offer_title = KIT.heading("", 40, KIT.GOLD)
	box.add_child(_offer_title)
	_offer_sub = KIT.label("", 16, KIT.DIM, null, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_offer_sub)
	var ring_holder := CenterContainer.new()
	ring_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(ring_holder)
	_ring = Control.new()
	_ring.custom_minimum_size = Vector2(110, 110)
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	ring_holder.add_child(_ring)
	_number = KIT.label("5", 56, Color(1, 1, 1), KIT.title(), HORIZONTAL_ALIGNMENT_CENTER)
	_number.set_anchors_preset(Control.PRESET_FULL_RECT)
	_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ring.add_child(_number)
	accept_button = KIT.button("", KIT.GOLD, Vector2(400, 70), 26, true)
	accept_button.pressed.connect(_on_accept)
	box.add_child(accept_button)
	decline_button = KIT.button("", Color(0.6, 0.66, 0.78), Vector2(400, 56), 20)
	decline_button.pressed.connect(_on_decline)
	box.add_child(decline_button)


func _build_veil() -> void:
	_veil = ColorRect.new()
	(_veil as ColorRect).color = Color(KIT.BG, 0.86)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	_veil.visible = false
	add_child(_veil)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.add_child(center)
	_veil_label = KIT.heading("", 34, KIT.DIM)
	center.add_child(_veil_label)


func _draw_ring() -> void:
	var c := _ring.size * 0.5
	var r := minf(c.x, c.y) - 6.0
	_ring.draw_arc(c, r, 0.0, TAU, 64, Color(KIT.GOLD, 0.18), 6.0, true)
	if countdown != null:
		var f := countdown.fraction()
		if f > 0.0:
			_ring.draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * f, 64, KIT.GOLD, 6.0, true)


## Teklifi açar (geri sayım `seconds`). Düğmeler kilitsizdir; kısa bir an yanlış dokunuşa karşı koruma YOK: karar açık ve
## geri alınabilir bir şey değil, ama kazara kabul de zararsızdır (kısa reklam).
func show_offer(seconds: float) -> void:
	## Metinler her açılışta çevrilir: dil değişince katman yeniden kurulmak zorunda kalmaz.
	_offer_title.text = tr("DEVAM ET?")
	_offer_sub.text = tr("kısa bir reklam izle, yarı canla devam et")
	accept_button.text = tr("İZLE VE CANLAN")
	decline_button.text = tr("VAZGEÇ")
	countdown = AdFlow.Countdown.new(seconds)
	offer_visible = true
	veil_visible = false
	_veil.visible = false
	_offer.visible = true
	visible = true
	accept_button.disabled = false
	decline_button.disabled = false
	_refresh()
	_last_us = Time.get_ticks_usec()
	set_process(true)
	if not Settings.touch:
		accept_button.grab_focus.call_deferred()


func show_veil() -> void:
	_veil_label.text = tr("REKLAM")
	offer_visible = false
	_offer.visible = false
	veil_visible = true
	_veil.visible = true
	visible = true
	set_process(false)


func hide_overlay() -> void:
	offer_visible = false
	veil_visible = false
	_offer.visible = false
	_veil.visible = false
	visible = false
	set_process(false)


func advance(delta: float) -> void:
	## Geri sayımı ilerletir; süre bitince VAZGEÇ sayılır.
	if not offer_visible or countdown == null:
		return
	var expired := countdown.tick(delta)
	_refresh()
	if expired:
		_decline()


func _process(_delta: float) -> void:
	if not offer_visible:
		return
	var now := Time.get_ticks_usec()
	var real := float(now - _last_us) / 1000000.0
	_last_us = now
	advance(real)


func _refresh() -> void:
	if countdown != null:
		_number.text = str(countdown.seconds_left())
	_ring.queue_redraw()


func _on_accept() -> void:
	if not offer_visible:
		return
	offer_visible = false
	_offer.visible = false
	set_process(false)
	accepted.emit()


func _on_decline() -> void:
	_decline()


func _decline() -> void:
	if not offer_visible:
		return
	hide_overlay()
	declined.emit()


func _unhandled_input(event: InputEvent) -> void:
	if offer_visible and (event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel")):
		get_viewport().set_input_as_handled()
		_decline()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and offer_visible:
		_decline()
