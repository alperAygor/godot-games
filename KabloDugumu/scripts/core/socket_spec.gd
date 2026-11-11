class_name SocketSpec
extends RefCounted

## Alttaki priz seridindeki tek priz. Renk eslesmesi buradan denetlenir.

var index: int = 0
var color_id: StringName = &"red"
var color: Color = Color(1.0, 0.33, 0.4, 1.0)
var voltage: int = 220
var position: Vector3 = Vector3.ZERO
## locked_socket modifier'i: priz kapakli baslar, fis 0.6 sn tutulunca acilir.
var locked: bool = false
