class_name UiMotion
extends RefCounted

## UI mikro-etkileşimleri: basışta küçülme, kart girişi, ekran solması.
## Juice (scripts/core) 3D/2D ilkellerini sunar; bu katman UI sahne ritmini kurar.
## Hepsi Tween tabanlı ve kısa süreli — oyun hissini bozmadan geri bildirim verir.

const PRESS_SCALE: float = 0.96
const PRESS_SPRING: float = 0.14
const FADE_IN_SECONDS: float = 0.18
const STAGGER_PER_ITEM: float = 0.04


## Basılıyken anında 0.96'ya küçül, bırakınca geri yaylan. Hover'dan bağımsız.
static func press_feedback(button: BaseButton) -> void:
	if button.button_down.is_connected(_on_down.bind(button)):
		return
	button.button_down.connect(_on_down.bind(button))
	button.button_up.connect(_on_up.bind(button))


static func _on_down(button: Control) -> void:
	button.pivot_offset = button.size * 0.5
	button.scale = Vector2.ONE * PRESS_SCALE


static func _on_up(button: Control) -> void:
	button.pivot_offset = button.size * 0.5
	var tween: Tween = button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, PRESS_SPRING) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Ekran kökünün yumuşak girişi (hızlı fade; geçiş hissi verir).
static func fade_in(node: CanvasItem, duration: float = FADE_IN_SECONDS) -> void:
	node.modulate.a = 0.0
	var tween: Tween = node.create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Kartların kademeli belirmesi: önce şeffaf + küçük, sırayla pop.
## Konteyner çocuklarında `position` güvenilmez; ölçek+alfa kullanılır.
static func stagger_pop(nodes: Array[Control]) -> void:
	var index: int = 0
	for node: Control in nodes:
		node.pivot_offset = node.size * 0.5
		node.modulate.a = 0.0
		node.scale = Vector2.ONE * 0.92
		_animate_in(node, float(index) * STAGGER_PER_ITEM)
		index += 1


static func _animate_in(node: Control, delay: float) -> void:
	var tween: Tween = node.create_tween()
	tween.tween_interval(delay)
	tween.set_parallel(true)
	tween.tween_property(node, "modulate:a", 1.0, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "scale", Vector2.ONE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
