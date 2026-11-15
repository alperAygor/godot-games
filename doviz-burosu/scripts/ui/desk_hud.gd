class_name DeskHud
extends RefCounted
## Masanın üst bilgi çubuğu: gün (ya da mod adı), saat, hata sayacı ("Hata 0/2"), günün kazancı (modlarda puan).

var day_label: Label
var clock_label: Label
var mistake_label: Label
var pay_label: Label


func build() -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"BoothHud"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	day_label = UiKit.label("", &"HudMuted", "DayLabel")
	clock_label = UiKit.label("09:00", &"HudClock", "ClockLabel")
	mistake_label = UiKit.label("", &"HudLabel", "MistakeLabel")
	pay_label = UiKit.label("", &"HudPay", "PayLabel")
	for label in [day_label, clock_label, mistake_label, pay_label]:
		row.add_child(label)
	clock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return panel


func set_day(career: Career) -> void:
	day_label.text = tr(str(GameSession.mode.hud()["title_key"])) if GameSession.mode != null else tr("DESK_DAY") % career.day


func sync(shift: Shift) -> void:
	clock_label.text = shift.clock_text()
	var free_mistakes := int(shift.ctx.balance["shift"]["free_mistakes"])
	var made := int(shift.stats["mistake_transactions"])
	var free_left := maxi(0, free_mistakes - made)
	mistake_label.text = tr("DESK_MISTAKES") % [made, free_mistakes]
	mistake_label.modulate = Color(1, 1, 1) if free_left > 0 else Color(0.85, 0.25, 0.25)
	pay_label.text = UiKit.money(int(shift.report()["net_minor"]), "PL")
	if GameSession.mode != null:
		var hud := GameSession.mode.hud()
		mistake_label.text = tr(str(hud["status_key"])) % int(hud["status_arg"])
		mistake_label.modulate = Color(1, 1, 1)
		pay_label.text = tr("MODE_SCORE") % int(hud["score"])
