class_name DocTile
extends DraggableItem
## Tezgâhtaki bir belge (kimlik ya da kaynak beyanı): özet gösterir, dokununca ayrıntı sayfası açılır.

signal tapped(kind: String)

const KIND_ID := "id"
const KIND_DECLARATION := "declaration"

var kind := ""


func setup(document_kind: String, title: String, line_one: String, line_two: String) -> void:
	kind = document_kind
	name = "DocTile_%s" % document_kind
	theme_type_variation = &"DocPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	for pair in [[title, &"DocTitle"], [line_one, &"DocLine"], [line_two, &"DocDetail"]]:
		var label := Label.new()
		label.text = pair[0]
		label.theme_type_variation = pair[1]
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(label)


func _on_tap() -> void:
	tapped.emit(kind)
