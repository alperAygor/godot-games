extends Control

## Ana menu. Geri tusu: cikis.

@onready var play_button: Button = %PlayButton
@onready var version_label: Label = %Version


func _ready() -> void:
	# Surum tek kaynaktan: project.godot (etiket elle guncellenmez).
	version_label.text = "v%s" % str(
		ProjectSettings.get_setting("application/config/version", "0.0.0"))
	play_button.pressed.connect(_on_play)
	GameManager.back_requested.connect(_on_back)


func _on_play() -> void:
	GameManager.goto_scene(&"game")


func _on_back() -> void:
	get_tree().quit()
