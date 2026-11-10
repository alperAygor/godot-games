extends Control

## Ana menu. Geri tusu: cikis.

@onready var play_button: Button = %PlayButton
@onready var upgrades_button: Button = %UpgradesButton
@onready var currency_label: Label = %Currency
@onready var version_label: Label = %Version


func _ready() -> void:
	# Surum tek kaynaktan: project.godot (etiket elle guncellenmez).
	version_label.text = "v%s" % str(
		ProjectSettings.get_setting("application/config/version", "0.0.0"))
	play_button.pressed.connect(_on_play)
	upgrades_button.pressed.connect(_on_upgrades)
	GameManager.back_requested.connect(_on_back)
	GameManager.currency_changed.connect(_on_currency_changed)
	_on_currency_changed(GameManager.profile.currency)


func _on_play() -> void:
	GameManager.goto_scene(&"game")


func _on_upgrades() -> void:
	GameManager.goto_scene(&"upgrades")


func _on_currency_changed(amount: int) -> void:
	currency_label.text = "Para: %d" % amount


func _on_back() -> void:
	get_tree().quit()
