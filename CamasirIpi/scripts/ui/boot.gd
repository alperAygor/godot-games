extends Control

## Açılış: servisler hazır, kısa bir bekleme, menüye geçiş.
## Bekleme, "flash" hissini önler; 0.4 sn altına düşürmeyin.

const HOLD_SECONDS: float = 0.4


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.BOOT)
	await get_tree().create_timer(HOLD_SECONDS).timeout
	GameManager.goto_scene(&"game")
