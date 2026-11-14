class_name PrizHint
extends RefCounted
## Ödüllü reklam ipucu: bir cihaz ve onun doğru prizi.

## Takılı olmayan `device_id` cihazını `socket_id` prizine tak.
const PLACE: StringName = &"place"
## Mevcut plan hiçbir çözüme uzanamıyor: `device_id` yerinden çıkmalı. `socket_id` boş
## değilse cihazın gideceği doğru priz de odur.
const MOVE: StringName = &"move"
## Plan zaten tam ve geçerli; ipucu gerekmez.
const NONE: StringName = &"none"
## Seviyenin çözümü yok (yayındaki seviyelerde olmaz; testler garanti eder).
const UNSOLVABLE: StringName = &"unsolvable"

var kind: StringName = NONE
var device_id: String = ""
var socket_id: String = ""


static func make(hint_kind: StringName, device: String = "", socket: String = "") -> PrizHint:
	var h: PrizHint = PrizHint.new()
	h.kind = hint_kind
	h.device_id = device
	h.socket_id = socket
	return h
