class_name RetentionEntryRow
extends HBoxContainer

## Ana ekranın küçük giriş satırı: görevler, ödül yolu, haftalık etkinlik. Her düğmenin köşesinde
## alınacak bir şey varsa nokta yanar; seviye yetmeyen sayfa sönük görünür (açılınca kilit bilgisi çıkar).
## Rozetler `Progress.changed` ile tazelenir; satır silinince bağlantı kopar.

const DOT_SIZE: float = 22.0
const DOT_COLOR: Color = Color("f08a78")
const LOCKED_ICON: Color = Color(0.49, 0.52, 0.5, 0.55)
const ICONS: Array[String] = ["lucide/check", "lucide/trophy", "lucide/shirt"]
const KINDS: Array[String] = [RetentionHub.KIND_MISSIONS, RetentionHub.KIND_MILESTONES, RetentionHub.KIND_WEEKLY]

var _buttons: Array[UiIconButton] = []
var _dots: Array[Control] = []
var _connected: Node = null


func _ready() -> void:
	add_theme_constant_override("separation", 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for index: int in range(KINDS.size()):
		var button: UiIconButton = UiIconButton.new()
		button.setup(ICONS[index])
		button.pressed.connect(_on_pressed.bind(KINDS[index]))
		add_child(button)
		var dot: Panel = RetentionUi.dot(DOT_COLOR, DOT_SIZE)
		dot.position = Vector2(UiKit.MIN_TOUCH * 0.5 + UiIconButton.DISC_DIAMETER * 0.5 - DOT_SIZE, \
			(UiKit.MIN_TOUCH - UiIconButton.DISC_DIAMETER) * 0.5)
		button.add_child(dot)
		_buttons.append(button)
		_dots.append(dot)
	_connected = RetentionStore.progress()
	if _connected != null and _connected.has_signal("changed"):
		_connected.connect("changed", refresh)
	refresh()


func _exit_tree() -> void:
	if _connected != null and is_instance_valid(_connected) and _connected.is_connected("changed", refresh):
		_connected.disconnect("changed", refresh)


func refresh() -> void:
	for index: int in range(KINDS.size()):
		var kind: String = KINDS[index]
		_dots[index].visible = RetentionHub.badge_for(kind) > 0
		_buttons[index].icon_color = UiKit.TEXT if RetentionHub.is_unlocked(kind) else LOCKED_ICON
		_buttons[index].queue_redraw()


func _on_pressed(kind: String) -> void:
	RetentionHub.open_sheet(kind, get_parent() if get_parent() != null else self)
