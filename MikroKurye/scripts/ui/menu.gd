extends Control

## Ana menü: Oyna -> sipariş seçimi, Garaj -> yükseltmeler. Geri tuşu: çıkış.

const PLAY_ICON_SIZE: int = 56
const GARAGE_ICON_SIZE: int = 48
const ON_PRIMARY: Color = Color(0.08, 0.24, 0.15)
const ON_SECONDARY: Color = Color(0.29, 0.20, 0.09)

@onready var play_button: Button = %PlayButton
@onready var garage_button: Button = %GarageButton
@onready var hint_label: Label = %Hint


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.MENU)
	play_button.text = UiStrings.MENU_PLAY
	garage_button.text = UiStrings.MENU_GARAGE
	hint_label.text = UiStrings.MENU_HINT
	Icons.apply(play_button, "lucide/play", ON_PRIMARY, PLAY_ICON_SIZE)
	Icons.apply(garage_button, "lucide/truck", ON_SECONDARY, GARAGE_ICON_SIZE)
	play_button.pressed.connect(_on_play)
	garage_button.pressed.connect(_on_garage)
	GameManager.back_requested.connect(_on_back)


func _on_play() -> void:
	AudioService.play("ui_tap")
	GameManager.goto_scene(&"order")


func _on_garage() -> void:
	AudioService.play("ui_tap")
	GameManager.goto_scene(&"garage")


func _on_back() -> void:
	get_tree().quit()
