class_name LevelRoot
extends Node3D

## Seviye kendi başına çalışabilir; tur durumu ve robot GameController'a aittir.
## Başlangıç, kontrol noktaları ve teslimat alanı alt düğümlerde bulunabilir.
@export var level_id: String = "desk_01"


## Altın kutu grubu sahne yüklenirken hazır olmalı: GameController olmadan
## (level_probe) da seviye kendi içinde tutarlı kalır.
func _ready() -> void:
	var box: Node = find_child("GoldenBox", true, false)
	if box != null and not box.is_in_group("golden_box"):
		box.add_to_group("golden_box")
