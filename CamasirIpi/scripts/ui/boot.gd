extends Control

## Açılış: servisler hazır, kısa bir bekleme, ana ekrana (ilk açılışta oyuna) geçiş.
## Bekleme, "flash" hissini önler; 0.4 sn altına düşürmeyin.

const HOLD_SECONDS: float = 0.4


func _ready() -> void:
	GameManager.set_phase(GameManager.Phase.BOOT)
	await get_tree().create_timer(HOLD_SECONDS).timeout
	# Kayıtlı ses/müzik ayarı ilk sahneden önce uygulanır; ilk açılış menüsüz doğrudan oyuna girer.
	UiData.apply_audio_settings()
	GameManager.goto_scene(&"game" if UiData.consume_first_launch() else &"home")
