class_name FakeAd
extends CanvasLayer
## Geliştirme sürümünün SAHTE reklam penceresi (gerçek SDK yerine). Ödüllü: "Ödülü al" ya da "İptal" (ödülsüz).
## Geçiş: "Kapat". Her sonuç `finished(rewarded)` ile bildirilir ve pencere kapanır.

signal finished(rewarded: bool)


func setup(title: String, rewarded: bool) -> void:
	layer = 100
	name = "FakeAd"
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.09, 0.07, 0.94)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	box.custom_minimum_size = Vector2(560, 0)
	center.add_child(box)
	var heading := UiKit.label("TEST REKLAMI", &"TitleLabel", "FakeAdTitle")
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", Color("F5EEDC"))
	box.add_child(heading)
	var note := UiKit.wrapped("%s\n(Gerçek reklam değil; yayın sürümünde AdMob gelir.)" % title, &"GoalLabel", "FakeAdNote")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Color("F5EEDC"))
	box.add_child(note)
	if rewarded:
		var give := UiKit.button("Ödülü al", "FakeAdRewardButton", &"", 92.0)
		give.pressed.connect(_finish.bind(true))
		box.add_child(give)
		var cancel := UiKit.button("İptal (ödülsüz)", "FakeAdCancelButton", &"GhostButton", 92.0)
		cancel.pressed.connect(_finish.bind(false))
		box.add_child(cancel)
	else:
		var close := UiKit.button("Kapat", "FakeAdCloseButton", &"", 92.0)
		close.pressed.connect(_finish.bind(false))
		box.add_child(close)


func _finish(rewarded: bool) -> void:
	finished.emit(rewarded)
	queue_free()
