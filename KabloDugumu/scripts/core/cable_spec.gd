class_name CableSpec
extends RefCounted

## Bir kablonun saf verisi. Sahne bilmez; KnotLevel uretir, gameplay tuketir.
## Koordinatlar pano uzayindadir (metre, pano duzlemi z~0.055).

var index: int = 0
var color_id: StringName = &"red"
var color: Color = Color(1.0, 0.33, 0.4, 1.0)
var voltage: int = 220
var source: Vector3 = Vector3.ZERO
var socket: Vector3 = Vector3.ZERO
var socket_index: int = 0
var plug_rest: Vector3 = Vector3.ZERO
## Baslangic halat egrisi, kaynaktan fise; uzunlugu length'e esit olmali.
var points: PackedVector3Array = PackedVector3Array()
## Halatin toplam uzunlugu (metre). Kendi prizine ulasmaya yetmelidir.
var length: float = 1.0
