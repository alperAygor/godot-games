class_name Hud
extends CanvasLayer

## HUD yalnızca gösterir: GameController her fizik karesinde 0..100 yüzdeyi
## `set_*` ile iter. Hesap `scripts/core/` sınıflarındadır (ARCHITECTURE §6).

const MIN_PERCENT: float = 0.0
const MAX_PERCENT: float = 100.0

@onready var _cargo_bar: ProgressBar = $Root/TopPanel/Bars/CargoHealthBar
@onready var _battery_bar: ProgressBar = $Root/TopPanel/Bars/BatteryBar


func set_cargo_health(percent: float) -> void:
	_cargo_bar.value = clampf(percent, MIN_PERCENT, MAX_PERCENT)


func set_battery(percent: float) -> void:
	_battery_bar.value = clampf(percent, MIN_PERCENT, MAX_PERCENT)
