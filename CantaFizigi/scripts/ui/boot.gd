extends Control

## Acilis: servisler hazir, kisa bekleme, menuye gecis.
## Bekleme "flash" hissini onler; 0.4 sn altina dusurmeyin.

const HOLD_SECONDS: float = 0.4


func _ready() -> void:
	await get_tree().create_timer(HOLD_SECONDS).timeout
	GameManager.goto_scene(&"menu")
