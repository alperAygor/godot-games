class_name BoosterBar
extends Control

## Güçlendirici çubuğu: üç yuvarlak, düz (çizgisiz) düğme + sayı rozeti. Kodla kurulur.
## Sayılar `Progress` autoload'undan okunur (`booster_count` / `use_booster`); autoload yoksa
## (başka bir iş kolunda yazılıyor) oturum boyunca her birinden OTURUM_YEDEK adet verilir.
## Kurallar `Boosters` (saf mantık) içindedir; bu sınıf yalnız gösterir ve sayar.

signal booster_pressed(id: String)

const PROGRESS_PATH: String = "/root/Progress"
const SESSION_FALLBACK: int = 2
## Görsel daire küçük (92 px), dokunma alanı 126 px: UiIconButton ile aynı ilke.
const BUTTON_SIZE: float = 92.0
const TOUCH_SIZE: float = UiKit.MIN_TOUCH
const BUTTON_GAP: float = 8.0
## Başparmak bölgesinde, sepet kuyruğunun altında durur (üstte başlık ve zincir göstergesi var).
## Değer dairelerin MERKEZ çizgisidir (1858): dokunma alanı bunun etrafında ortalanır.
const BAR_CENTER_Y: float = 1858.0
const BADGE_SIZE: float = 40.0
const BADGE_FONT: int = UiKit.TYPE_MICRO
const BADGE_OFFSET_RATIO: float = 0.37
const ICON_RATIO: float = 0.3
const ICON_WIDTH: float = 6.0
const AD_GLYPH_RATIO: float = 0.42
const FILL: Color = Color(1.0, 1.0, 1.0, 0.82)
const FILL_ARMED: Color = UiKit.ACCENT
const INK: Color = UiKit.TEXT
const INK_ARMED: Color = Color.WHITE
## Sayı rozeti sakin: koyu mürekkep zemin, beyaz rakam (uyarı kırmızısı değil). Sıfır: sönük gri.
const BADGE_COLOR: Color = UiKit.TEXT
const BADGE_EMPTY_COLOR: Color = Color(0.49, 0.52, 0.5, 0.55)
## Sıfırken "reklam izle" durumu: sıcak sarı zemin + oynat işareti.
const BADGE_AD_COLOR: Color = UiKit.GOLD
const DISABLED_ALPHA: float = 0.45
const PRESS_SCALE: float = UiTokens.MOTION_PRESS_SCALE
const PRESS_SECONDS: float = UiTokens.MOTION_PRESS_SECONDS
const RELEASE_SECONDS: float = UiTokens.MOTION_RELEASE_SECONDS

## Sıfır adetli güçlendiriciye basılınca (yalnız `ad_enabled` açıkken) reklam izleme isteği.
signal ad_requested(id: String)

## Açık olursa sıfır adet "reklam izle" durumuna geçer (dokunulabilir, oynat işaretli rozet).
## Varsayılan kapalı: oyun tarafı bağlanana dek sıfır sönük kalır (davranış değişmez).
var ad_enabled: bool = false

## Oturumluk yedek sayılar (autoload yokken seviyeler arasında korunur).
static var _session: Dictionary = {}

var _buttons: Dictionary = {}
var _badges: Dictionary = {}
var _armed: String = ""


func setup(screen_width: float) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var total: float = TOUCH_SIZE * float(Boosters.IDS.size()) + BUTTON_GAP * float(Boosters.IDS.size() - 1)
	position = Vector2((screen_width - total) * 0.5, BAR_CENTER_Y - TOUCH_SIZE * 0.5)
	size = Vector2(total, TOUCH_SIZE)
	for index: int in range(Boosters.IDS.size()):
		var id: String = Boosters.IDS[index]
		var button: BoosterButton = BoosterButton.new()
		button.booster = id
		button.draw_disc = true
		button.disc_diameter = BUTTON_SIZE
		button.custom_minimum_size = Vector2(TOUCH_SIZE, TOUCH_SIZE)
		button.size = Vector2(TOUCH_SIZE, TOUCH_SIZE)
		button.pivot_offset = button.size * 0.5
		button.position = Vector2(float(index) * (TOUCH_SIZE + BUTTON_GAP), 0.0)
		button.focus_mode = Control.FOCUS_NONE
		button.flat = true
		_style(button)
		button.pressed.connect(_on_pressed.bind(id))
		button.button_down.connect(_press.bind(button, PRESS_SCALE, PRESS_SECONDS))
		button.button_up.connect(_press.bind(button, 1.0, RELEASE_SECONDS))
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
		# Reklam durumu: adet sıfırken (ve oyun tarafı izin verdiyse) düğme dokunulabilir kalır.
		var ad_mode: bool = ad_enabled and left <= 0
		button.ad_mode = ad_mode
		button.disabled = not enabled and _armed != id and not ad_mode
		button.modulate.a = 1.0 if enabled or _armed == id or ad_mode else DISABLED_ALPHA
		button.armed = _armed == id
		button.badge_color = BADGE_AD_COLOR if ad_mode else (BADGE_COLOR if left > 0 else BADGE_EMPTY_COLOR)
		var badge: Label = _badges[id] as Label
		badge.text = str(left)
		badge.visible = not ad_mode
		button.queue_redraw()


func set_armed(id: String) -> void:
	_armed = id
	_restyle_armed()


func armed() -> String:
	return _armed


func _restyle_armed() -> void:
	for id: String in Boosters.IDS:
		var button: BoosterButton = _buttons[id] as BoosterButton
		button.armed = _armed == id
		button.queue_redraw()


func _on_pressed(id: String) -> void:
	UiKit.tap_sound()
	if ad_enabled and count(id) <= 0:
		ad_requested.emit(id)
		return
	booster_pressed.emit(id)


func _press(button: Control, target: float, seconds: float) -> void:
	var squash: Tween = button.create_tween()
	squash.tween_property(button, "scale", Vector2.ONE * target, seconds)\
		.set_trans(Tween.TRANS_BACK if target >= 1.0 else Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## Düğme çizimi `BoosterButton._draw`ta (daire + simge + rozet); stil kutuları boş kalır.
func _style(button: Button) -> void:
	var none: StyleBoxEmpty = StyleBoxEmpty.new()
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, none)


func _make_badge(button: BoosterButton) -> Label:
	var badge: Label = UiKit.numeric_label("0", BADGE_FONT, Color.WHITE)
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.size = Vector2(BADGE_SIZE, BADGE_SIZE)
	badge.position = button.badge_center() - badge.size * 0.5
	badge.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_child(badge)
	return badge


## Simgeleri yazı tipi yerine çizer (emoji/simge fontuna bağımlı olmasın).
class BoosterButton extends Button:
	var booster: String = ""
	var armed: bool = false
	var badge_color: Color = BoosterBar.BADGE_COLOR
	## Çubukta daire bu düğmenin kendisi çizer (dokunma alanı daireden büyük); mağaza simgesi çizmez.
	var draw_disc: bool = false
	var disc_diameter: float = 0.0
	var ad_mode: bool = false

	func _diameter() -> float:
		return disc_diameter if disc_diameter > 0.0 else size.x

	func badge_center() -> Vector2:
		var d: float = _diameter()
		return size * 0.5 + Vector2(d * BoosterBar.BADGE_OFFSET_RATIO, -d * BoosterBar.BADGE_OFFSET_RATIO)

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var d: float = _diameter()
		if draw_disc:
			draw_circle(center, d * 0.5, BoosterBar.FILL_ARMED if armed else BoosterBar.FILL, true, -1.0, true)
		draw_circle(badge_center(), BoosterBar.BADGE_SIZE * 0.5, badge_color, true, -1.0, true)
		if ad_mode:
			# Oynat işareti: "bir reklam izleyip kazan" (yazısız, sakin).
			var tip: float = BoosterBar.BADGE_SIZE * BoosterBar.AD_GLYPH_RATIO
			var at: Vector2 = badge_center()
			draw_colored_polygon(PackedVector2Array([at + Vector2(-tip * 0.5, -tip * 0.6),
				at + Vector2(tip * 0.7, 0.0), at + Vector2(-tip * 0.5, tip * 0.6)]), BoosterBar.INK)
		var r: float = d * BoosterBar.ICON_RATIO
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
