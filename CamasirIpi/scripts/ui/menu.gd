extends Control

## Ana menü. Geri tuşu: çıkış.

@onready var play_button: Button = %PlayButton


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.MENU)
	Icons.apply(play_button, "lucide/play", Color(0.08, 0.24, 0.15), 56)
	play_button.text = Loc.t("MENU_PLAY")
	(get_node("Center/Column/Hint") as Label).text = Loc.t("MENU_SKELETON")
	play_button.pressed.connect(_on_play)
	GameManager.back_requested.connect(_on_back)


func _on_play() -> void:
	AudioService.play("ui_tap")
	GameManager.start_game()


func _on_back() -> void:
	get_tree().quit()
