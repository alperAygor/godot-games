class_name GameBar
extends HBoxContainer

## Oyun içi alt çubuk (başparmak bölgesi, büyük 120 px diskler / 144 px dokunma): baştan başlat (BASILI TUT: yanlışlıkla
## basılamaz, aralarında ekstra boşluk var), geri al (basılı tutunca tekrarlar), ipucu, atla.
## İpucu ve atla birer ödüllü reklamdır: köşelerinde küçük, sakin bir video işareti taşırlar (alarm rozeti değil);
## ilk 3 seviyede hiç görünmezler. Düğmeler yalnız sinyal verir; reklam ve oturum mantığı Game sahnesindedir.

signal undo_pressed
signal restart_pressed
## Restart kısa dokunuşla yapılmaya çalışıldı (Game "basılı tut" ipucunu gösterir).
signal restart_tapped
signal hint_pressed
signal skip_pressed

const GAP: int = UiTokens.SIZE_BAR_GAP
## Baştan başlat ile geri al arası ek ayrım (yanlış basışı önler).
const RESTART_EXTRA_GAP: int = UiTokens.SPACE_XL
const BADGE_DIAMETER: float = 44.0
const BADGE_ICON: float = float(UiTokens.ICON_BADGE)
## Rozetin düğme merkezine göre kayması (diskin sağ-üst kenarı).
const BADGE_OFFSET: Vector2 = Vector2(48.0, -48.0)
const BUSY_ALPHA: float = 0.4

var _undo: UiIconButton = null
var _restart: UiIconButton = null
var _hint: UiIconButton = null
var _skip: UiIconButton = null


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", GAP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_restart = _make("RestartButton", "lucide/rotate-ccw", false)
	_restart.set_hold(UiIconButton.Hold.CONFIRM)
	_restart.confirmed.connect(restart_pressed.emit)
	_restart.released_early.connect(restart_tapped.emit)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(RESTART_EXTRA_GAP, 0.0)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(spacer)
	_undo = _make("UndoButton", "lucide/undo-2", false)
	_undo.set_hold(UiIconButton.Hold.REPEAT)
	_undo.pressed.connect(undo_pressed.emit)
	_undo.repeated.connect(undo_pressed.emit)
	_hint = _make("HintButton", "lucide/lightbulb", true)
	_hint.pressed.connect(hint_pressed.emit)
	_skip = _make("SkipButton", "lucide/skip-forward", true)
	_skip.pressed.connect(skip_pressed.emit)
	set_undo_enabled(false)


func _make(node_name: String, icon_name: String, rewarded: bool) -> UiIconButton:
	var button: UiIconButton = UiIconButton.new()
	button.name = node_name
	button.setup(icon_name, false, true)
	if rewarded:
		button.disc_color = UiKit.ACCENT_SOFT
		button.icon_color = UiKit.ACCENT
		button.add_child(_badge())
	add_child(button)
	return button


## Küçük video işareti: beyaz zemin üstünde yumuşak yeşil glif (ödüllü reklam olduğunu sakince söyler).
func _badge() -> Control:
	var badge: Panel = Panel.new()
	badge.name = "AdBadge"
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = UiKit.SHEET
	box.set_corner_radius_all(int(BADGE_DIAMETER * 0.5))
	box.anti_aliasing = true
	badge.add_theme_stylebox_override("panel", box)
	badge.size = Vector2(BADGE_DIAMETER, BADGE_DIAMETER)
	badge.position = Vector2(UiIconButton.BIG_TOUCH, UiIconButton.BIG_TOUCH) * 0.5 + BADGE_OFFSET - badge.size * 0.5
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: TextureRect = UiKit.tinted_icon("lucide/video", BADGE_ICON, UiKit.ACCENT)
	icon.position = (badge.size - Vector2(BADGE_ICON, BADGE_ICON)) * 0.5
	icon.size = Vector2(BADGE_ICON, BADGE_ICON)
	badge.add_child(icon)
	return badge


## İpucu ve atla düğmeleri yalnız `from_level` ve sonrasında görünür.
func set_rewarded_visible(visible_now: bool) -> void:
	_hint.visible = visible_now
	_skip.visible = visible_now


func rewarded_visible() -> bool:
	return _hint.visible


func set_undo_enabled(enabled: bool) -> void:
	_undo.disabled = not enabled
	_undo.modulate.a = 1.0 if enabled else BUSY_ALPHA


func set_restart_enabled(enabled: bool) -> void:
	_restart.disabled = not enabled
	_restart.modulate.a = 1.0 if enabled else BUSY_ALPHA


## İpucu gösterilirken (ya da reklam beklenirken) kapalı.
func set_hint_enabled(enabled: bool) -> void:
	_hint.disabled = not enabled
	_hint.modulate.a = 1.0 if enabled else BUSY_ALPHA


func set_skip_enabled(enabled: bool) -> void:
	_skip.disabled = not enabled
	_skip.modulate.a = 1.0 if enabled else BUSY_ALPHA


func hint_enabled() -> bool:
	return not _hint.disabled


func undo_enabled() -> bool:
	return not _undo.disabled
