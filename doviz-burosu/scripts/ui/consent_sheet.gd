class_name ConsentSheet
extends Control
## Gizlilik / onay penceresi: anonim kullanım verisi ve reklam kişiselleştirme izni. İlk açılışta ana menüde, sonradan
## Ayarlar > Gizlilik seçenekleri'nde gösterilir. Kararı Monetization.apply_consent uygular; burası yalnızca sorar.
## Reklam sağlayıcısının kendi onay formu (UMP; gereken bölgelerde) ayrıca çıkar ve bunun yerine geçmez.

signal decided(allowed: bool)


func _init() -> void:
	name = "ConsentSheet"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 50
	var dim := ColorRect.new()
	dim.color = UiKit.DIM_COLOR
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := UiKit.card("", &"FloatCard")
	box.get_meta("panel").custom_minimum_size.x = 600.0
	center.add_child(box.get_meta("panel"))
	box.add_child(UiKit.label(tr("CONSENT_TITLE"), &"SheetTitle", "ConsentTitle"))
	box.add_child(UiKit.wrapped(tr("CONSENT_TEXT"), &"GoalLabel", "ConsentText"))
	var accept := UiKit.button(tr("CONSENT_ACCEPT"), "ConsentAcceptButton", &"", 84.0)
	accept.pressed.connect(_decide.bind(true))
	box.add_child(accept)
	var decline := UiKit.button(tr("CONSENT_DECLINE"), "ConsentDeclineButton", &"GhostButton", 84.0)
	decline.pressed.connect(_decide.bind(false))
	box.add_child(decline)


func _decide(allowed: bool) -> void:
	Monetization.apply_consent(allowed)
	decided.emit(allowed)
	queue_free()
