class_name UiSfx
extends RefCounted

## UI tıklama sesini tek yerden bağlar (ARCHITECTURE.md §5.6).
##
## Sahneler düğme başına `AudioService.play("ui_tap")` çağırmaz; `bind()` ağaçtaki
## tüm düğmelere bağlanır. Dinamik üretilen satır/kart düğmeleri için `bind()`
## üretimden SONRA çağrılmalıdır. Autoload kimliği `-s` probunda derlenmediği
## için servise `/root/...` yoluyla erişilir (GOTCHAS.md #2).


## Ağaçtaki tüm `BaseButton` düğmelerine tıklama sesi bağlar; yinelenen
## bağlamayı `is_connected` engeller.
static func bind(root: Node) -> void:
	if root is BaseButton:
		bind_button(root as BaseButton)
	for child: Node in root.get_children():
		bind(child)


static func bind_button(button: BaseButton) -> void:
	if not button.pressed.is_connected(_on_pressed):
		button.pressed.connect(_on_pressed)
	# F7.6b: basışta küçülme geri bildirimi tek yerden; sahne kodu tekrar etmez.
	UiMotion.press_feedback(button)


static func _on_pressed() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var audio: Node = tree.root.get_node_or_null("/root/AudioService")
	if audio != null and audio.has_method("play"):
		audio.call("play", "ui_tap")
