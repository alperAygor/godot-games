class_name BoosterBar
extends Control

## Güçlendirici çubuğu: üç yuvarlak, düz (çizgisiz) düğme + sayı rozeti. Kodla kurulur.
## Sayılar `Progress` autoload'undan okunur (`booster_count` / `use_booster`); autoload yoksa
## (başka bir iş kolunda yazılıyor) oturum boyunca her birinden OTURUM_YEDEK adet verilir.
## Kurallar `Boosters` (saf mantık) içindedir; bu sınıf yalnız gösterir ve sayar.

signal booster_pressed(id: String)

const PROGRESS_PATH: String = "/root/Progress"
const SESSION_FALLBACK: int = 2
const BUTTON_SIZE: float = 92.0
const BUTTON_GAP: float = 36.0
## Başparmak bölgesinde, sepet kuyruğunun altında durur (üstte başlık ve zincir göstergesi var).
const BAR_Y: float = 1812.0
const BADGE_SIZE: float = 40.0
const BADGE_FONT: int = 24
const ICON_RATIO: float = 0.3
const ICON_WIDTH: float = 6.0
const FILL: Color = Color(1.0, 1.0, 1.0, 0.82)
const FILL_PRESSED: Color = Color(0.93, 0.95, 0.97, 0.9)
const FILL_ARMED: Color = Color("2ec4a6")
const INK: Color = Color("2a2f3d")
const INK_ARMED: Color = Color.WHITE
const BADGE_COLOR: Color = Color("e5484d")
const BADGE_EMPTY_COLOR: Color = Color("9aa3af")
const DISABLED_ALPHA: float = 0.45
const PRESS_SCALE: float = 0.9
const PRESS_SECONDS: float = 0.08
const RELEASE_SECONDS: float = 0.22

## Oturumluk yedek sayılar (autoload yokken seviyeler arasında korunur).
static var _session: Dictionary = {}

var _buttons: Dictionary = {}
var _badges: Dictionary = {}
var _armed: String = ""


func setup(screen_width: float) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var total: float = BUTTON_SIZE * float(Boosters.IDS.size()) + BUTTON_GAP * float(Boosters.IDS.size() - 1)
	position = Vector2((screen_width - total) * 0.5, BAR_Y)
	size = Vector2(total, BUTTON_SIZE)
	for index: int in range(Boosters.IDS.size()):
		var id: String = Boosters.IDS[index]
		var button: BoosterButton = BoosterButton.new()
		button.booster = id
		button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
		button.size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
		button.pivot_offset = button.size * 0.5
		button.position = Vector2(float(index) * (BUTTON_SIZE + BUTTON_GAP), 0.0)
		button.focus_mode = Control.FOCUS_NONE
		_style(button)
		button.pressed.connect(_on_pressed.bind(id))
		add_child(button)
		_buttons[id] = button
		_badges[id] = _make_badge(button)


func count(id: String) -> int:
	var progress: Node = get_node_or_null(PROGRESS_PATH)
	if progress != null and progress.has_method("booster_count"):
		return int(progress.call("booster_count", id))
	return int(_session.get(id, SESSION_FALLBACK))


## Bir adet harcar; yoksa false.
func spend(id: String) -> bool:
	var progress: Node = get_node_or_null(PROGRESS_PATH)
	if progress != null and progress.has_method("use_booster"):
		return bool(progress.call("use_booster", id))
	var left: int = count(id)
	if left <= 0:
		return false
	_session[id] = left - 1
	return true


## `usable`: kimlik -> şu an kullanılabilir mi (kural). Açılmamış olanlar gizlenir.
func refresh(level: int, usable: Dictionary) -> void:
	for id: String in Boosters.IDS:
		var button: BoosterButton = _buttons[id] as BoosterButton
		button.visible = Boosters.is_unlocked(id, level)
		var left: int = count(id)
		var enabled: bool = bool(usable.get(id, false)) and left > 0
		button.disabled = not enabled and _armed != id
		button.modulate.a = 1.0 if enabled or _armed == id else DISABLED_ALPHA
		button.armed = _armed == id
		button.queue_redraw()
		var badge: Label = _badges[id] as Label
		badge.text = str(left)
		button.badge_color = BADGE_COLOR if left > 0 else BADGE_EMPTY_COLOR
	_restyle_armed()


func set_armed(id: String) -> void:
	_armed = id
	_restyle_armed()


func armed() -> String:
	return _armed


func _restyle_armed() -> void:
	for id: String in Boosters.IDS:
		var button: BoosterButton = _buttons[id] as BoosterButton
		var fill: Color = FILL_ARMED if _armed == id else FILL
		for state: String in ["normal", "hover", "disabled", "focus"]:
			(button.get_theme_stylebox(state) as StyleBoxFlat).bg_color = fill
		button.armed = _armed == id
		button.queue_redraw()


func _on_pressed(id: String) -> void:
	var button: BoosterButton = _buttons[id] as BoosterButton
	var squash: Tween = button.create_tween()
	squash.tween_property(button, "scale", Vector2.ONE * PRESS_SCALE, PRESS_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	squash.tween_property(button, "scale", Vector2.ONE, RELEASE_SECONDS)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioService.play_pitched("ui_soft", 1.0, -4.0)
	booster_pressed.emit(id)


func _style(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = FILL_PRESSED if state == "pressed" else FILL
		box.set_corner_radius_all(int(BUTTON_SIZE * 0.5))
		box.anti_aliasing = true
		button.add_theme_stylebox_override(state, box)


func _make_badge(button: Button) -> Label:
	var badge: Label = Label.new()
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.size = Vector2(BADGE_SIZE, BADGE_SIZE)
	badge.position = Vector2(BUTTON_SIZE - BADGE_SIZE * 0.8, -BADGE_SIZE * 0.2)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_font_size_override("font_size", BADGE_FONT)
	badge.add_theme_color_override("font_color", Color.WHITE)
	# Daire düğmenin `_draw`unda çizilir: Label kutusu yazı yüksekliğiyle uzayıp hap şekli alıyordu.
	badge.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_child(badge)
	return badge


## Simgeleri yazı tipi yerine çizer (emoji/simge fontuna bağımlı olmasın).
class BoosterButton extends Button:
	var booster: String = ""
	var armed: bool = false
	var badge_color: Color = BoosterBar.BADGE_COLOR

	func _draw() -> void:
		var half: float = BoosterBar.BADGE_SIZE * 0.5
		draw_circle(Vector2(BoosterBar.BUTTON_SIZE - BoosterBar.BADGE_SIZE * 0.8 + half,
			-BoosterBar.BADGE_SIZE * 0.2 + half), half, badge_color, true, -1.0, true)
		var center: Vector2 = size * 0.5
		var r: float = size.x * BoosterBar.ICON_RATIO
		var ink: Color = BoosterBar.INK_ARMED if armed else BoosterBar.INK
		var w: float = BoosterBar.ICON_WIDTH
		match booster:
			Boosters.UNDO:
				# Geri dönen ok: üstte açık yay + sol uçta ok başı.
				draw_arc(center, r, deg_to_rad(200.0), deg_to_rad(470.0), 32, ink, w, true)
				var tip: Vector2 = center + Vector2(cos(deg_to_rad(200.0)), sin(deg_to_rad(200.0))) * r
				draw_colored_polygon(PackedVector2Array([tip + Vector2(-r * 0.42, -r * 0.05),
					tip + Vector2(r * 0.32, -r * 0.2), tip + Vector2(-r * 0.05, r * 0.42)]), ink)
			Boosters.PIN_REMOVER:
				# Mandal: iki uzun kol + ortada yay halkası; yukarı doğru çıkış oku.
				for side: float in [-1.0, 1.0]:
					draw_line(center + Vector2(side * r * 0.22, -r * 0.55), center + Vector2(side * r * 0.32, r * 1.0), ink, w, true)
				draw_circle(center + Vector2(0.0, r * 0.15), r * 0.22, ink, false, w * 0.7, true)
				draw_line(center + Vector2(0.0, -r * 0.7), center + Vector2(0.0, -r * 1.15), ink, w * 0.8, true)
				draw_colored_polygon(PackedVector2Array([center + Vector2(-r * 0.25, -r * 0.95),
					center + Vector2(r * 0.25, -r * 0.95), center + Vector2(0.0, -r * 1.3)]), ink)
			Boosters.EXTRA_SLOT:
				# Askı (kanca + üçgen gövde) ve sol üstte artı; rozet sağ üstte kalır.
				var neck: Vector2 = center + Vector2(r * 0.15, -r * 0.05)
				draw_arc(center + Vector2(r * 0.15, -r * 0.5), r * 0.26, deg_to_rad(160.0), deg_to_rad(440.0), 24, ink, w, true)
				draw_line(center + Vector2(r * 0.15, -r * 0.24), neck, ink, w, true)
				draw_polyline(PackedVector2Array([neck, center + Vector2(-r * 0.85, r * 0.65),
					center + Vector2(r * 1.15, r * 0.65), neck]), ink, w, true)
				var plus: Vector2 = center + Vector2(-r * 0.8, -r * 0.6)
				draw_line(plus + Vector2(-r * 0.28, 0.0), plus + Vector2(r * 0.28, 0.0), ink, w, true)
				draw_line(plus + Vector2(0.0, -r * 0.28), plus + Vector2(0.0, r * 0.28), ink, w, true)
