class_name PrizSocket
extends RefCounted
## Bir priz noktası. `seats` > 1 ise çoklu priz (uzatma) demektir; hepsi aynı hatta yük bindirir.
## `anchor` sahnedeki yer tutucunun adıdır ("<oda>_<sıra>", ör. "kitchen_2").
## `props` öğe bayrakları: {"grounded": true}, {"timer": 1} (dilim kaydırma) gibi.
## Kural betikleri prizi yalnız hat, oda ve props üzerinden okur (kimlik ya da anchor değil);
## çözücü bu sayede eş prizleri tek sınıfta toplar.

var id: String = ""
var line: String = ""
var room: String = ""
var anchor: String = ""
var seats: int = 1
var props: Dictionary = {}


func get_prop(key: String, fallback: Variant = null) -> Variant:
	return props.get(key, fallback)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"line": line,
		"room": room,
		"anchor": anchor,
		"seats": seats,
		"props": props.duplicate(true),
	}


static func from_dict(d: Dictionary) -> PrizSocket:
	var socket: PrizSocket = PrizSocket.new()
	socket.id = PrizJson.get_str(d, "id")
	socket.line = PrizJson.get_str(d, "line")
	socket.room = PrizJson.get_str(d, "room")
	socket.anchor = PrizJson.get_str(d, "anchor")
	socket.seats = PrizJson.get_int(d, "seats", 1)
	socket.props = PrizJson.normalize(PrizJson.get_dict(d, "props"))
	return socket
