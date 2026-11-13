extends Control

## Sonuç ekranı: `GameManager.last_result` sözlüğünü gösterir.

@onready var title_label: Label = %Title
@onready var stars_label: Label = %Stars
@onready var detail_label: Label = %Detail


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.RESULT)
	var result: Dictionary = GameManager.last_result
	var stars: int = int(result.get("stars", 0))
	var fee: int = int(result.get("fee", 0))
	var damage: float = float(result.get("damage", 0.0))

	title_label.text = Loc.t("RESULT_DONE") if stars > 0 else Loc.t("RESULT_FAILED")
	stars_label.text = Loc.f("RESULT_STARS", [stars])
	detail_label.text = Loc.f("RESULT_DETAIL", [int(roundf(damage * 100.0)), fee])

	(%RetryButton as Button).text = Loc.t("RESULT_RETRY")
	(%MenuButton as Button).text = Loc.t("RESULT_MENU")
	if stars > 0:
		AudioService.play("success")

	(%RetryButton as Button).pressed.connect(_on_retry)
	(%MenuButton as Button).pressed.connect(_on_menu)
	GameManager.back_requested.connect(_on_menu)


func _on_retry() -> void:
	GameManager.start_game()


func _on_menu() -> void:
	GameManager.goto_scene(&"menu")
