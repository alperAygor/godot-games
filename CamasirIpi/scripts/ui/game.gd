extends Node3D

## Yer tutucu oyun sahnesi. Gerçek oyun buraya gelir;
## iskelet yalnızca "başla -> bitir -> sonuç" akışını kanıtlar.

@onready var spinner: MeshInstance3D = %Spinner


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.GAME)
	(%SuccessButton as Button).pressed.connect(_on_finish.bind(0.0))
	(%DamageButton as Button).pressed.connect(_on_finish.bind(0.65))
	(%MenuButton as Button).pressed.connect(_on_menu)
	GameManager.back_requested.connect(_on_menu)


func _process(delta: float) -> void:
	spinner.rotate_y(delta * 0.9)


func _on_finish(damage: float) -> void:
	var base_fee: int = int(GameData.value("balance", "base_fee", 100))
	var result: Dictionary = RunScoring.compute(damage, base_fee)
	result["success"] = damage < 1.0
	AudioService.play("ui_tap")
	GameManager.finish_run(result)


func _on_menu() -> void:
	GameManager.goto_scene(&"menu")
