class_name NoAdsProvider
extends AdsProvider
## Reklam göstermeyen güvenli varsayılan (yayın sürümünde eklenti yoksa, masaüstü release). Oyun bununla tam
## OYNANABİLİR; reklam düğmeleri gizli kalır, ödül asla verilmez.

func is_ready(_placement: int) -> bool:
	return false


func show(_placement: int) -> void:
	failed.emit("ads_disabled")
