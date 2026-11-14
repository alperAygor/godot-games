class_name PrizDevice
extends RefCounted
## Bir cihaz. `type` cihaz kataloğundaki kimliktir (data/balance/devices.json), sahne modeli
## buna göre seçilir. `blocks` (yük) 1-5 blok. `slices` çalıştığı gün dilimlerinin bit maskesi
## (düz kipte her zaman dört dilim). `props` öğe bayrakları: {"needs_ground": true} gibi.

var id: String = ""
var type: String = ""
var blocks: int = 1
var room: String = ""
var slices: int = PrizSlice.ALL_MASK
var props: Dictionary = {}


func get_prop(key: String, fallback: Variant = null) -> Variant:
	return props.get(key, fallback)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"type": type,
		"load": blocks,
		"room": room,
		"slices": PrizSlice.ids_from_mask(slices),
		"props": props.duplicate(true),
	}


static func from_dict(d: Dictionary) -> PrizDevice:
	var device: PrizDevice = PrizDevice.new()
	device.id = PrizJson.get_str(d, "id")
	device.type = PrizJson.get_str(d, "type")
	device.blocks = PrizJson.get_int(d, "load", 1)
	device.room = PrizJson.get_str(d, "room")
	device.slices = PrizSlice.mask_from_ids(PrizJson.get_array(d, "slices"))
	device.props = PrizJson.normalize(PrizJson.get_dict(d, "props"))
	return device
