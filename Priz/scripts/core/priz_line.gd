class_name PrizLine
extends RefCounted
## Bir elektrik hattı. `capacity` taban kapasitedir (blok); öğeler dilime göre değiştirebilir
## (bkz. PrizBoard.line_capacity). `props` öğe parametrelerini taşır, ör.
## {"old_cable": 1}, {"solar": 2}, {"neighbour": [0, 2, 1, 0]}, {"off_slice": "night"}.

var id: String = ""
var color: String = ""
var shape: String = ""
var capacity: int = 0
var props: Dictionary = {}


func get_prop(key: String, fallback: Variant = null) -> Variant:
	return props.get(key, fallback)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"color": color,
		"shape": shape,
		"capacity": capacity,
		"props": props.duplicate(true),
	}


static func from_dict(d: Dictionary) -> PrizLine:
	var line: PrizLine = PrizLine.new()
	line.id = PrizJson.get_str(d, "id")
	line.color = PrizJson.get_str(d, "color")
	line.shape = PrizJson.get_str(d, "shape")
	line.capacity = PrizJson.get_int(d, "capacity")
	line.props = PrizJson.normalize(PrizJson.get_dict(d, "props"))
	return line
