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
	var gold: int = int(result.get("gold", 0))
	var scrap: int = int(result.get("scrap", 0))

	title_label.text = "Teslimat Tamamlandı" if stars > 0 else "Teslimat Hasarlı"
	stars_label.text = "Yıldız: %d / 3" % stars
	# `fee` eski sonuçlarla uyum için korunur; yeni akışta gold ile aynıdır.
	detail_label.text = "Hasar: %%%d    Ücret: %d\nAltın: %d    Hurda: %d" % [
		int(roundf(damage * 100.0)), fee, gold, scrap]

	if stars > 0:
		AudioService.play("success")

	(%RetryButton as Button).pressed.connect(_on_retry)
	(%MenuButton as Button).pressed.connect(_on_menu)
	GameManager.back_requested.connect(_on_menu)


func _on_retry() -> void:
	GameManager.start_game()


func _on_menu() -> void:
	GameManager.goto_scene(&"menu")
