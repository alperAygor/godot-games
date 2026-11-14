class_name PrizEvent
extends RefCounted
## `PrizBoard.start_day()` olay kaydı. Sahne bunları sırayla canlandırır.
## Kullanılmayan alanlar varsayılan değerde kalır (slice -1, kimlik "").

## Gün başlar. Alan yok.
const DAY_START: StringName = &"day_start"
## Dilim başlar: slice.
const SLICE_BEGIN: StringName = &"slice_begin"
## Önceki dilimde çalışan cihaz bu dilimde susar: slice, device_id.
const DEVICE_OFF: StringName = &"device_off"
## Cihaz bu dilimde çalışmaya başlar: slice, device_id.
const DEVICE_ON: StringName = &"device_on"
## Hattın bu dilimdeki yükü: slice, line_id, blocks, capacity, fill.
const LINE_LOAD: StringName = &"line_load"
## Hat sınıra yakın ama taşmıyor (fill >= PrizBoard.NEAR_LIMIT_FILL): slice, line_id, fill.
const LINE_NEAR_LIMIT: StringName = &"line_near_limit"
## Hat taştı, sigorta attı: slice, line_id, blocks, capacity, fill, rights (kalan hak).
const FUSE_BLOWN: StringName = &"fuse_blown"
## Hak kaldı, plana dönülür (plan korunur): rights.
const BACK_TO_PLANNING: StringName = &"back_to_planning"
## Hak bitti, seviye kaybedildi: rights (0).
const LOSE: StringName = &"lose"
## Dört dilim sorunsuz geçti. Alan yok.
const DAY_SURVIVED: StringName = &"day_survived"
## Seviye kazanıldı. Alan yok.
const WIN: StringName = &"win"

var type: StringName = &""
var slice: int = -1
var line_id: String = ""
var device_id: String = ""
var blocks: int = 0
var capacity: int = 0
var fill: float = 0.0
var rights: int = -1


static func make(event_type: StringName, at_slice: int = -1) -> PrizEvent:
	var e: PrizEvent = PrizEvent.new()
	e.type = event_type
	e.slice = at_slice
	return e


func _to_string() -> String:
	return "%s(s=%d l=%s d=%s %d/%d r=%d)" % [type, slice, line_id, device_id, blocks, capacity, rights]
