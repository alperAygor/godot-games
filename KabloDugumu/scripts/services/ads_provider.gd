class_name AdsProvider
extends RefCounted

## Reklam SDK'sının tek sınırı. `AdManager` dışında hiçbir script bunu import etmez.
## Somut uygulamalar (mock, AdMob) yalnızca bu arayüzü genişletir.

signal shown()
signal rewarded()
signal dismissed()
signal failed(reason: String)


func initialize() -> void:
	pass


func is_ready(_placement: int) -> bool:
	return false


func show(_placement: int) -> void:
	failed.emit("not_implemented")
