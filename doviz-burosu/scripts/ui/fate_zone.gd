class_name FateZone
extends PanelContainer
## Banknotun kaderini belirleyen bırakma bölgesi (kabul / iade / el koy).

signal dropped(note_index: int, fate: String)

const ZONE_STYLES := {
	Verdict.FATE_ACCEPT: &"ZoneAccept",
	Verdict.FATE_RETURN: &"ZoneReturn",
	Verdict.FATE_CONFISCATE: &"ZoneConfiscate",
}

var fate := ""
var _label: Label


func setup(zone_fate: String) -> void:
	fate = zone_fate
	theme_type_variation = ZONE_STYLES[zone_fate]
	custom_minimum_size = Vector2(0, 64)
	_label = Label.new()
	_label.text = tr("FATE_%s" % zone_fate.to_upper())
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_color", Color("F5EEDC"))
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and (data as Dictionary).has("note_index")


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	dropped.emit(int((data as Dictionary)["note_index"]), fate)
