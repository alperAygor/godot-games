extends Control
## Menü ekranları: ana menü, ayarlar, nasıl oynanır, duraklatma, kart seçimi, oyun sonu.
## Hepsi gerçek Control düğümleri: fare, dokunmatik, klavye ve Android geri tuşuyla çalışır.

signal play_pressed
signal resume_pressed
signal restart_pressed
signal menu_pressed
signal pause_requested
signal card_picked(index: int)
signal reroll_pressed
signal quality_changed
signal ship_preview(id: String)

const KIT = preload("res://scripts/ui/ui_kit.gd")
const VERSION := "v1.2"

# --- Küçük çizim bileşenleri ------------------------------------------------------
class TitleArt extends Control:
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(540, 196)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var f := KIT.title()
		var flicker := 1.0
		if fmod(_t, 5.3) > 5.12 or (fmod(_t, 7.9) > 7.6 and fmod(_t, 0.12) > 0.06):
			flicker = 0.55
		var cyan := Color(KIT.CYAN, flicker)
		var pink := KIT.MAGENTA
		draw_string_outline(f, Vector2(0, 84), "NEON", HORIZONTAL_ALIGNMENT_LEFT, -1, 96, 22, Color(cyan.r, cyan.g, cyan.b, 0.12 * flicker))
		draw_string_outline(f, Vector2(0, 84), "NEON", HORIZONTAL_ALIGNMENT_LEFT, -1, 96, 9, Color(cyan.r, cyan.g, cyan.b, 0.3 * flicker))
		draw_string(f, Vector2(0, 84), "NEON", HORIZONTAL_ALIGNMENT_LEFT, -1, 96, Color(0.86, 0.99, 1.0, 0.55 + 0.45 * flicker))
		draw_string_outline(f, Vector2(-6, 172), "ARENA", HORIZONTAL_ALIGNMENT_LEFT, -1, 96, 22, Color(pink.r, pink.g, pink.b, 0.12))
		draw_string_outline(f, Vector2(-6, 172), "ARENA", HORIZONTAL_ALIGNMENT_LEFT, -1, 96, 9, Color(pink.r, pink.g, pink.b, 0.32))
		draw_string(f, Vector2(-6, 172), "ARENA", HORIZONTAL_ALIGNMENT_LEFT, -1, 96, Color(1.0, 0.9, 0.97))
		var w := f.get_string_size("ARENA", HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x
		var tag := Rect2(w + 10, 108, 78, 44)
		draw_rect(tag, Color(KIT.GOLD, 0.95), true)
		draw_string(KIT.bold(), Vector2(tag.position.x, tag.position.y + 33), "3D", HORIZONTAL_ALIGNMENT_CENTER, tag.size.x, 30, Color(0.05, 0.04, 0.1))
		var sweep := fmod(_t * 0.5, 1.0)
		draw_line(Vector2(0, 190), Vector2(540, 190), Color(KIT.CYAN, 0.25), 2.0)
		draw_line(Vector2(540 * sweep - 60, 190), Vector2(540 * sweep, 190), Color(1, 1, 1, 0.9), 2.0)

class BuildStrip extends Control:
	var items: Array = []

	func set_items(list: Array) -> void:
		items = list
		custom_minimum_size = Vector2(maxf(1.0, float(mini(items.size(), 12))) * 50.0, 52.0 if not items.is_empty() else 0.0)
		visible = not items.is_empty()
		queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var n := mini(items.size(), 12)
		var x0 := (size.x - float(n) * 50.0) * 0.5
		for i in n:
			var card: Dictionary = items[i]["card"]
			var c: Color = KIT.TIER_COLOR.get(str(card.get("tier", "common")), KIT.CYAN)
			var center := Vector2(x0 + 25.0 + float(i) * 50.0, 24.0)
			draw_circle(center, 21.0, Color(c.r * 0.14, c.g * 0.14, c.b * 0.14, 0.9))
			draw_arc(center, 21.0, 0.0, TAU, 28, Color(c, 0.8), 1.6, true)
			KIT.icon(self, str(card.get("icon", "damage")), center, 11.0, c)
			var count := int(items[i]["count"])
			if count > 1:
				draw_circle(center + Vector2(15, 15), 9.0, Color(0.02, 0.03, 0.06, 0.95))
				draw_string(KIT.bold(), center + Vector2(6, 20), str(count), HORIZONTAL_ALIGNMENT_CENTER, 18, 12, Color(1, 1, 1))

class CardButton extends BaseButton:
	var card: Dictionary = {}
	var owned := 0
	var key_hint := ""
	var _hover := 0.0
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(292, 392)
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _process(delta: float) -> void:
		_t += delta
		var target := 1.0 if (is_hovered() or has_focus() or button_pressed) else 0.0
		_hover = lerpf(_hover, target, clampf(delta * 14.0, 0.0, 1.0))
		pivot_offset = size * 0.5
		scale = Vector2.ONE * (1.0 + 0.045 * _hover - (0.03 if is_pressed() else 0.0))
		queue_redraw()

	func _draw() -> void:
		var tier := str(card.get("tier", "common"))
		var c: Color = KIT.TIER_COLOR.get(tier, KIT.CYAN)
		var rect := Rect2(Vector2.ZERO, size)
		for i in 3:
			draw_rect(rect.grow(4.0 + float(i) * 5.0), Color(c, (0.05 + 0.09 * _hover) / float(i + 1)), true)
		draw_rect(rect, Color(0.025, 0.04, 0.085, 0.97), true)
		draw_rect(Rect2(0, 0, size.x, 150), Color(c.r * 0.13, c.g * 0.13, c.b * 0.13, 0.9), true)
		draw_rect(rect, Color(c, 0.6 + 0.4 * _hover), false, 2.0 + 1.5 * _hover)
		draw_rect(Rect2(0, 0, size.x, 6), c, true)
		# Köşe işaretleri
		for corner in [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, size.y), Vector2(size.x, size.y)]:
			var sx := 1.0 if corner.x == 0.0 else -1.0
			var sy := 1.0 if corner.y == 0.0 else -1.0
			draw_line(corner + Vector2(sx * 8, sy * 8), corner + Vector2(sx * 26, sy * 8), Color(1, 1, 1, 0.5), 1.5)
			draw_line(corner + Vector2(sx * 8, sy * 8), corner + Vector2(sx * 8, sy * 26), Color(1, 1, 1, 0.5), 1.5)
		draw_string(KIT.bold(), Vector2(0, 34), tr(str(KIT.TIER_NAME.get(tier, ""))), HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(c, 0.95))
		if tier == "synergy":
			# Kenarda dönen ışık + birleşen iki kartın ikonları
			var per := 2.0 * (size.x + size.y)
			var p := fmod(_t * 420.0, per)
			var pt := Vector2(p, 0) if p < size.x else (Vector2(size.x, p - size.x) if p < size.x + size.y else (Vector2(size.x - (p - size.x - size.y), size.y) if p < 2.0 * size.x + size.y else Vector2(0, size.y - (p - 2.0 * size.x - size.y))))
			draw_circle(pt, 7.0, Color(1, 1, 1, 0.9))
			draw_circle(pt, 16.0, Color(c, 0.25))
			var reqs: Array = card.get("requires", [])
			for k in reqs.size():
				var rc := GameData.card_by_id(str(reqs[k]))
				var at := Vector2(size.x * 0.5 + (float(k) - 0.5) * 150.0, 29.0)
				draw_circle(at, 14.0, Color(0.03, 0.05, 0.1, 0.95))
				draw_arc(at, 14.0, 0.0, TAU, 24, Color(c, 0.8), 1.5, true)
				KIT.icon(self, str(rc.get("icon", "damage")), at, 7.5, Color(1, 1, 1, 0.9))
		var ic := Vector2(size.x * 0.5, 94)
		var bob := sin(_t * 2.0) * 2.0
		draw_circle(ic + Vector2(0, bob), 44.0, Color(c.r * 0.2, c.g * 0.2, c.b * 0.2, 0.9))
		draw_arc(ic + Vector2(0, bob), 44.0, 0.0, TAU, 40, Color(c, 0.9), 2.0, true)
		draw_arc(ic + Vector2(0, bob), 50.0, _t, _t + PI * 0.6, 16, Color(c, 0.5), 2.0, true)
		draw_arc(ic + Vector2(0, bob), 50.0, _t + PI, _t + PI * 1.6, 16, Color(c, 0.5), 2.0, true)
		KIT.icon(self, str(card.get("icon", "damage")), ic + Vector2(0, bob), 24.0, c.lerp(Color(1, 1, 1), 0.35))
		draw_string(KIT.title(), Vector2(6, 196), tr(str(card.get("name", ""))), HORIZONTAL_ALIGNMENT_CENTER, size.x - 12, 21, Color(1, 1, 1))
		draw_line(Vector2(size.x * 0.5 - 40, 212), Vector2(size.x * 0.5 + 40, 212), Color(c, 0.7), 2.0)
		draw_multiline_string(KIT.font(), Vector2(24, 248), tr(str(card.get("desc", ""))), HORIZONTAL_ALIGNMENT_CENTER, size.x - 48, 18, 4, Color(0.8, 0.9, 1.0))
		var foot := tr("YENİ") if owned <= 0 else tr("SAHİP ×%d") % owned
		draw_string(KIT.bold(), Vector2(0, size.y - 22), foot, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(KIT.GOLD if owned <= 0 else KIT.DIM, 0.95))
		if key_hint != "":
			draw_rect(Rect2(14, size.y - 44, 30, 30), Color(c, 0.18), true)
			draw_rect(Rect2(14, size.y - 44, 30, 30), Color(c, 0.8), false, 1.5)
			draw_string(KIT.bold(), Vector2(14, size.y - 22), key_hint, HORIZONTAL_ALIGNMENT_CENTER, 30, 17, Color(1, 1, 1))

class CoreBadge extends Control:
	## Çekirdek ikonu + miktar. Değişince küçük bir "pop" yapar.
	var amount := 0
	var prefix := ""
	var size_px := 24
	var color := KIT.GOLD
	var _pop := 0.0
	var _shown := 0.0

	func _init(px := 24) -> void:
		size_px = px
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_resize()

	func set_amount(value: int, animate := true) -> void:
		if value != amount and animate:
			_pop = 1.0
		amount = value
		if not animate:
			_shown = float(value)
		_resize()

	func _text() -> String:
		return prefix + KIT.fmt(int(round(_shown)))

	func _resize() -> void:
		var w := KIT.bold().get_string_size(prefix + KIT.fmt(amount), HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		custom_minimum_size = Vector2(w + float(size_px) * 1.5 + 6.0, float(size_px) * 1.45)

	func _process(delta: float) -> void:
		_pop = maxf(0.0, _pop - delta * 3.0)
		_shown = lerpf(_shown, float(amount), clampf(delta * 8.0, 0.0, 1.0))
		if absf(_shown - float(amount)) < 0.5:
			_shown = float(amount)
		queue_redraw()

	func _draw() -> void:
		var h := size.y
		var r := float(size_px) * 0.55 * (1.0 + 0.25 * _pop)
		KIT.icon(self, "core", Vector2(r + 2.0, h * 0.5), r, color.lerp(Color(1, 1, 1), _pop * 0.5))
		draw_string(KIT.bold(), Vector2(float(size_px) * 1.3 + 6.0, h * 0.5 + float(size_px) * 0.36), _text(), HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color.lerp(Color(1, 1, 1), _pop * 0.6))

class UpgradeTile extends BaseButton:
	## Atölye yükseltme kutusu: ikon, ad, açıklama, seviye çubukları, fiyat.
	var def: Dictionary = {}
	var _hover := 0.0
	var _flash := 0.0
	var _shake := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(372, 128)
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func bump(ok: bool) -> void:
		if ok:
			_flash = 1.0
		else:
			_shake = 1.0

	func _process(delta: float) -> void:
		var target := 1.0 if (is_hovered() or has_focus()) else 0.0
		_hover = lerpf(_hover, target, clampf(delta * 14.0, 0.0, 1.0))
		_flash = maxf(0.0, _flash - delta * 2.5)
		_shake = maxf(0.0, _shake - delta * 4.0)
		pivot_offset = size * 0.5
		scale = Vector2.ONE * (1.0 + 0.025 * _hover - (0.02 if is_pressed() else 0.0))
		position.x += 0.0
		queue_redraw()

	func _draw() -> void:
		var meta: MetaProgress = Settings.meta
		var id := str(def.get("id", ""))
		var lv := meta.level(id)
		var mx := meta.max_level(id)
		var cost := meta.next_cost(id)
		var maxed := cost < 0
		var afford := not maxed and meta.cores >= cost
		var accent := KIT.GOLD if maxed else (KIT.CYAN if afford else Color(0.45, 0.52, 0.66))
		var ofs := Vector2(sin(_shake * 40.0) * 6.0 * _shake, 0.0)
		var rect := Rect2(ofs, size)
		draw_rect(rect.grow(4.0), Color(accent, 0.05 + 0.1 * _hover + 0.3 * _flash), true)
		draw_rect(rect, Color(0.025, 0.04, 0.085, 0.95), true)
		draw_rect(Rect2(ofs, Vector2(6, size.y)), accent, true)
		draw_rect(rect, Color(accent, 0.45 + 0.45 * _hover), false, 1.5 + _hover)
		var ic := ofs + Vector2(56, size.y * 0.5)
		draw_circle(ic, 36.0, Color(accent.r * 0.16, accent.g * 0.16, accent.b * 0.16, 0.95))
		draw_arc(ic, 36.0, 0.0, TAU, 36, Color(accent, 0.85), 2.0, true)
		KIT.icon(self, str(def.get("icon", "damage")), ic, 19.0, accent.lerp(Color(1, 1, 1), 0.3))
		draw_string(KIT.bold(), ofs + Vector2(108, 34), tr(str(def.get("name", ""))), HORIZONTAL_ALIGNMENT_LEFT, size.x - 120, 18, Color(1, 1, 1))
		draw_multiline_string(KIT.font(), ofs + Vector2(108, 58), tr(str(def.get("desc", ""))), HORIZONTAL_ALIGNMENT_LEFT, size.x - 122, 14, 2, Color(0.72, 0.84, 1.0))
		for i in mx:
			var pip := Rect2(ofs + Vector2(108 + i * 26, size.y - 26), Vector2(21, 8))
			draw_rect(pip, Color(accent, 0.95) if i < lv else Color(0.12, 0.17, 0.27, 0.95), true)
		if maxed:
			draw_string(KIT.bold(), ofs + Vector2(0, size.y - 16), tr("MAKS"), HORIZONTAL_ALIGNMENT_RIGHT, size.x - 16, 17, KIT.GOLD)
		else:
			var txt := KIT.fmt(cost)
			var tw := KIT.bold().get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
			var tc := KIT.GOLD if afford else Color(1.0, 0.42, 0.48, 0.9)
			draw_string(KIT.bold(), ofs + Vector2(size.x - 16 - tw, size.y - 15), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, tc)
			KIT.icon(self, "core", ofs + Vector2(size.x - 30 - tw, size.y - 22), 10.0, tc)

class StatBars extends Control:
	## Gemi özellikleri: 4 satır, 5'er dilim.
	var bars: Dictionary = {}
	var color := KIT.CYAN
	const ROWS := [["armor", "ZIRH"], ["speed", "HIZ"], ["power", "GÜÇ"], ["range", "MENZİL"]]

	func _init() -> void:
		custom_minimum_size = Vector2(440, 128)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		for r in ROWS.size():
			var y := 6.0 + float(r) * 31.0
			draw_string(KIT.bold(), Vector2(0, y + 17), tr(ROWS[r][1]), HORIZONTAL_ALIGNMENT_LEFT, 120, 15, KIT.DIM)
			var value := int(bars.get(ROWS[r][0], 0))
			for i in 5:
				var cell := Rect2(130 + i * 60, y + 4, 52, 14)
				var on := i < value
				draw_colored_polygon(PackedVector2Array([cell.position + Vector2(6, 0), cell.position + Vector2(cell.size.x, 0), cell.end - Vector2(6, 0), cell.position + Vector2(0, cell.size.y)]),
					Color(color, 0.95) if on else Color(0.12, 0.17, 0.27, 0.95))

class ArrowButton extends BaseButton:
	var dir := 1
	var color := KIT.CYAN
	var _hover := 0.0

	func _init(direction := 1) -> void:
		dir = direction
		custom_minimum_size = Vector2(70, 64)
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _process(delta: float) -> void:
		_hover = lerpf(_hover, 1.0 if (is_hovered() or has_focus()) else 0.0, clampf(delta * 14.0, 0.0, 1.0))
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color(color.r * 0.12, color.g * 0.12, color.b * 0.12, 0.85 + 0.1 * _hover), true)
		draw_rect(r, Color(color, 0.5 + 0.5 * _hover), false, 2.0)
		var c := size * 0.5 + Vector2(-4.0 * dir if is_pressed() else 0.0, 0)
		var s := 13.0
		draw_polyline(PackedVector2Array([c + Vector2(-s * 0.5 * dir, -s), c + Vector2(s * 0.5 * dir, 0), c + Vector2(-s * 0.5 * dir, s)]), Color(1, 1, 1, 0.75 + 0.25 * _hover), 4.0, true)

# --- Durum -----------------------------------------------------------------------
var current := ""
var in_game := false
var _screens: Dictionary = {}
var _return_to := "main"
var _fade: ColorRect
var _margin := Vector4(28, 20, 28, 20)
var _focus: Dictionary = {}

var _stat_labels: Dictionary = {}
var _card_row: HBoxContainer
var _card_title: Label
var _reroll: Button
var _card_buttons: Array = []
var _pause_info: Label
var _pause_build: BuildStrip
var _over_title: Label
var _over_record: Label
var _over_score: Label
var _over_stats: Dictionary = {}
var _over_build: BuildStrip
var _over_target := 0
var _over_shown := 0.0
var _quality_button: Button
var _setting_nodes: Dictionary = {}
var _main_column: VBoxContainer
var _pause_args: Array = []
var _main_cores: CoreBadge
var _shop_cores: CoreBadge
var _shop_tiles: Array = []
var _over_cores: CoreBadge
var _over_total: Label
var _notice: Label
var _hangar_index := 0
var _hangar_name: Label
var _hangar_weapon: Label
var _hangar_desc: Label
var _hangar_bars: StatBars
var _hangar_action: Button
var _hangar_page: Label
var _hangar_cores: CoreBadge

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_all()
	_fade = ColorRect.new()
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	get_tree().set_quit_on_go_back(false)
	I18n.language_changed.connect(_rebuild)

func _build_all() -> void:
	_build_main()
	_build_hangar()
	_build_workshop()
	_build_settings()
	_build_howto()
	_build_pause()
	_build_cards()
	_build_gameover()

func _rebuild() -> void:
	## Dil değişince tüm ekranlar yeni dilde yeniden kurulur; bulunulan ekran korunur.
	var keep := current
	var back_to := _return_to
	for key in _screens:
		(_screens[key] as Control).queue_free()
	_screens.clear()
	_focus.clear()
	_setting_nodes.clear()
	_stat_labels.clear()
	_over_stats.clear()
	_card_buttons.clear()
	_shop_tiles.clear()
	_build_all()
	move_child(_fade, get_child_count() - 1)
	_return_to = back_to
	if not _pause_args.is_empty():
		show_pause(_pause_args[0], _pause_args[1], _pause_args[2], _pause_args[3])
	if keep == "main":
		show_main()
	elif keep != "":
		if keep == "settings":
			_refresh_settings()
		show_screen(keep)
	else:
		hide_all()

func set_margins(m: Vector4) -> void:
	_margin = m
	if _main_column != null:
		_main_column.offset_left = m.x + 56.0
		_main_column.offset_right = m.x + 56.0 + 560.0

func _process(delta: float) -> void:
	var vp := get_viewport_rect().size
	if size != vp:
		size = vp
		position = Vector2.ZERO
	if current == "gameover" and _over_score != null:
		_over_shown = lerpf(_over_shown, float(_over_target), clampf(delta * 3.5, 0.0, 1.0))
		if absf(_over_shown - float(_over_target)) < 1.0:
			_over_shown = float(_over_target)
		_over_score.text = KIT.fmt(int(round(_over_shown)))

# --- Ekran yönetimi ---------------------------------------------------------------
func _screen(id: String, dim: float) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	if dim > 0.0:
		var shade := ColorRect.new()
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		shade.color = Color(KIT.BG, dim)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(shade)
	_screens[id] = root
	return root

func _center(root: Control) -> CenterContainer:
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	return c

func show_screen(id: String) -> void:
	for key in _screens:
		(_screens[key] as Control).visible = key == id
	current = id
	if id == "":
		return
	var root: Control = _screens[id]
	root.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.16)
	if not Settings.touch and _focus.has(id):
		(_focus[id] as Control).grab_focus.call_deferred()

func hide_all() -> void:
	show_screen("")

func flash(color := Color(1, 1, 1), peak := 0.5, time := 0.5) -> void:
	_fade.color = Color(color, peak)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func fade_through(callback: Callable, time := 0.28) -> void:
	## Karart → geri çağır → aç. Harita geçişinde kullanılır.
	var tw := create_tween()
	tw.tween_property(_fade, "color", Color(0, 0, 0, 1), time)
	tw.tween_callback(callback)
	tw.tween_interval(0.08)
	tw.tween_property(_fade, "color", Color(0, 0, 0, 0), time * 1.4)

func _side_shade(strength: float) -> TextureRect:
	## Soldan sağa yumuşak kararma: menü metni okunur, 3B sahne sağda görünür kalır.
	var grad := Gradient.new()
	grad.set_color(0, Color(KIT.BG, strength))
	grad.set_color(1, Color(KIT.BG, 0.0))
	grad.set_offset(0, 0.12)
	grad.set_offset(1, 0.7)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 4
	var shade := TextureRect.new()
	shade.texture = tex
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return shade

# --- Ana menü ---------------------------------------------------------------------
func _build_main() -> void:
	var root := _screen("main", 0.0)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_side_shade(0.92))

	_main_column = VBoxContainer.new()
	_main_column.anchor_top = 0.0
	_main_column.anchor_bottom = 1.0
	_main_column.offset_left = _margin.x + 56.0
	_main_column.offset_right = _margin.x + 616.0
	_main_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_main_column.add_theme_constant_override("separation", 12)
	root.add_child(_main_column)
	_main_column.add_child(TitleArt.new())
	_main_column.add_child(KIT.label(tr("hayatta kal  ·  güçlen  ·  sektörleri temizle"), 17, KIT.DIM))
	_main_column.add_child(KIT.spacer(14))
	var play := KIT.button(tr("OYNA"), KIT.CYAN, Vector2(360, 78), 32, true)
	play.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	play.pressed.connect(func(): play_pressed.emit())
	_main_column.add_child(play)
	_focus["main"] = play
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var hangar := KIT.button(tr("HANGAR"), KIT.GREEN, Vector2(174, 58), 20)
	hangar.pressed.connect(func(): open_sub("hangar", "main"))
	row.add_child(hangar)
	var shop := KIT.button(tr("ATÖLYE"), KIT.GOLD, Vector2(174, 58), 20)
	shop.pressed.connect(func(): open_sub("workshop", "main"))
	row.add_child(shop)
	_main_column.add_child(row)
	var how := KIT.button(tr("NASIL OYNANIR"), KIT.VIOLET, Vector2(360, 54), 20)
	how.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	how.pressed.connect(func(): open_sub("howto", "main"))
	_main_column.add_child(how)
	var settings := KIT.button(tr("AYARLAR"), KIT.VIOLET, Vector2(360, 54), 20)
	settings.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	settings.pressed.connect(func(): open_sub("settings", "main"))
	_main_column.add_child(settings)
	if not OS.has_feature("mobile"):
		var quit := KIT.button(tr("ÇIKIŞ"), Color(0.6, 0.66, 0.78), Vector2(360, 48), 18)
		quit.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		quit.pressed.connect(func(): get_tree().quit())
		_main_column.add_child(quit)

	var stats := KIT.panel(KIT.CYAN, 20.0)
	stats.anchor_left = 1.0
	stats.anchor_right = 1.0
	stats.anchor_top = 1.0
	stats.anchor_bottom = 1.0
	stats.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	stats.grow_vertical = Control.GROW_DIRECTION_BEGIN
	stats.offset_right = -_margin.z - 28.0
	stats.offset_bottom = -_margin.w - 28.0
	root.add_child(stats)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 6)
	stats.add_child(grid)
	for entry in [["best", tr("REKOR"), KIT.GOLD], ["best_wave", tr("EN İYİ DALGA"), KIT.CYAN], ["kills", tr("TOPLAM AVLANAN"), KIT.CYAN], ["runs", tr("KOŞU"), KIT.CYAN]]:
		grid.add_child(KIT.label(entry[1], 14, KIT.DIM))
		var value := KIT.label("0", 20, entry[2], KIT.bold(), HORIZONTAL_ALIGNMENT_RIGHT)
		value.custom_minimum_size = Vector2(110, 0)
		grid.add_child(value)
		_stat_labels[entry[0]] = value

	_main_cores = CoreBadge.new(26)
	_main_cores.anchor_left = 1.0
	_main_cores.anchor_right = 1.0
	_main_cores.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_main_cores.offset_right = -_margin.z - 30.0
	_main_cores.offset_top = _margin.y + 24.0
	root.add_child(_main_cores)
	_notice = KIT.label("", 17, KIT.GOLD, KIT.bold(), HORIZONTAL_ALIGNMENT_RIGHT)
	_notice.anchor_left = 0.5
	_notice.anchor_right = 1.0
	_notice.offset_right = -_margin.z - 30.0
	_notice.offset_top = _margin.y + 66.0
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.modulate.a = 0.0
	root.add_child(_notice)

	var version := KIT.label(VERSION, 13, Color(KIT.DIM, 0.6))
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.offset_left = _margin.x + 58.0
	version.offset_top = -_margin.w - 16.0
	root.add_child(version)

func show_main() -> void:
	(_stat_labels["best"] as Label).text = KIT.fmt(Settings.best)
	(_stat_labels["best_wave"] as Label).text = str(Settings.best_wave)
	(_stat_labels["kills"] as Label).text = KIT.fmt(Settings.total_kills)
	(_stat_labels["runs"] as Label).text = str(Settings.runs)
	_main_cores.set_amount(Settings.meta.cores, false)
	var bonus := Settings.take_welcome()
	if bonus > 0:
		notify(tr("HOŞ GELDİN BONUSU: +%d ÇEKİRDEK — ATÖLYE'de harca") % bonus)
	show_screen("main")

func open_sub(id: String, from: String) -> void:
	_return_to = from
	if id == "settings":
		_refresh_settings()
	elif id == "workshop":
		_refresh_shop(false)
	elif id == "hangar":
		var ids := _ship_ids()
		_hangar_index = maxi(0, ids.find(Settings.meta.ship))
		_refresh_hangar(false)
	show_screen(id)

func _back() -> void:
	Sound.play("ui_back")
	if current == "hangar":
		ship_preview.emit(Settings.meta.ship)
	if _return_to == "main":
		show_main()
	else:
		show_screen(_return_to)

func notify(text: String, duration := 3.2) -> void:
	## Ana menü üstünde kısa duyuru (bonus, açılan gemi vb.).
	if _notice == null:
		return
	_notice.text = text
	var tw := _notice.create_tween()
	tw.tween_property(_notice, "modulate:a", 1.0, 0.25)
	tw.tween_interval(duration)
	tw.tween_property(_notice, "modulate:a", 0.0, 0.6)

# --- Hangar -----------------------------------------------------------------------
func _ship_ids() -> Array:
	var ids: Array = []
	for def in GameData.ships:
		ids.append(str(def.get("id", "")))
	return ids

func _build_hangar() -> void:
	var root := _screen("hangar", 0.0)
	root.add_child(_side_shade(0.95))
	var col := VBoxContainer.new()
	col.anchor_bottom = 1.0
	col.offset_left = _margin.x + 56.0
	col.offset_right = _margin.x + 600.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	root.add_child(col)
	var head := KIT.label(tr("HANGAR"), 20, KIT.GREEN, KIT.bold())
	col.add_child(head)
	_hangar_name = KIT.label("", 58, Color(1, 1, 1), KIT.title())
	_hangar_name.add_theme_constant_override("outline_size", 12)
	col.add_child(_hangar_name)
	_hangar_weapon = KIT.label("", 18, KIT.GOLD, KIT.bold())
	col.add_child(_hangar_weapon)
	_hangar_desc = KIT.label("", 17, KIT.TEXT)
	_hangar_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hangar_desc.custom_minimum_size = Vector2(520, 50)
	col.add_child(_hangar_desc)
	col.add_child(KIT.spacer(4))
	_hangar_bars = StatBars.new()
	col.add_child(_hangar_bars)
	col.add_child(KIT.spacer(6))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var prev := ArrowButton.new(-1)
	prev.pressed.connect(func(): _hangar_step(-1))
	row.add_child(prev)
	_hangar_action = KIT.button("", KIT.GREEN, Vector2(330, 64), 21, true)
	_hangar_action.pressed.connect(_hangar_act)
	row.add_child(_hangar_action)
	var next := ArrowButton.new(1)
	next.pressed.connect(func(): _hangar_step(1))
	row.add_child(next)
	col.add_child(row)
	_hangar_page = KIT.label("", 15, KIT.DIM, null, HORIZONTAL_ALIGNMENT_CENTER)
	_hangar_page.custom_minimum_size = Vector2(496, 0)
	_hangar_page.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(_hangar_page)
	col.add_child(KIT.spacer(4))
	var back := KIT.button(tr("GERİ"), Color(0.6, 0.66, 0.78), Vector2(240, 54), 20)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_back)
	col.add_child(back)
	_focus["hangar"] = _hangar_action
	_hangar_cores = CoreBadge.new(26)
	_hangar_cores.anchor_left = 1.0
	_hangar_cores.anchor_right = 1.0
	_hangar_cores.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hangar_cores.offset_right = -_margin.z - 30.0
	_hangar_cores.offset_top = _margin.y + 24.0
	root.add_child(_hangar_cores)

func _hangar_step(delta: int) -> void:
	var ids := _ship_ids()
	if ids.is_empty():
		return
	_hangar_index = posmod(_hangar_index + delta, ids.size())
	Sound.play("ui_toggle")
	_refresh_hangar()

func _refresh_hangar(animate := true) -> void:
	var ids := _ship_ids()
	if ids.is_empty():
		return
	var meta: MetaProgress = Settings.meta
	var id: String = ids[_hangar_index]
	var def := meta.ship_def(id)
	var color := Color.from_string(str(def.get("color", "#5ce1ff")), KIT.CYAN)
	_hangar_name.text = tr(str(def.get("name", "")))
	_hangar_name.add_theme_color_override("font_color", color.lerp(Color(1, 1, 1), 0.35))
	_hangar_name.add_theme_color_override("font_outline_color", Color(color, 0.3))
	_hangar_weapon.text = tr("SİLAH: %s") % tr(str(def.get("weapon_name", "")))
	_hangar_desc.text = tr(str(def.get("desc", "")))
	_hangar_bars.bars = def.get("bars", {})
	_hangar_bars.color = color
	_hangar_bars.queue_redraw()
	_hangar_page.text = "%d / %d" % [_hangar_index + 1, ids.size()]
	_hangar_cores.set_amount(meta.cores, animate)
	if meta.ship == id:
		_hangar_action.text = tr("SEÇİLİ")
		_hangar_action.disabled = true
	elif meta.owns_ship(id):
		_hangar_action.text = tr("SEÇ")
		_hangar_action.disabled = false
	else:
		_hangar_action.text = tr("%s ÇEKİRDEKLE AÇ") % KIT.fmt(meta.ship_cost(id))
		_hangar_action.disabled = false
	ship_preview.emit(id)

func _hangar_act() -> void:
	var ids := _ship_ids()
	var id: String = ids[_hangar_index]
	var meta: MetaProgress = Settings.meta
	if meta.owns_ship(id):
		meta.select_ship(id)
		Settings.save()
		Sound.play("card_pick")
	elif meta.buy_ship(id):
		meta.select_ship(id)
		Settings.save()
		Sound.play("purchase")
		flash(Color.from_string(str(meta.ship_def(id).get("color", "#ffffff")), Color.WHITE), 0.35, 0.5)
	else:
		Sound.play("deny")
		_hangar_cores.set_amount(meta.cores)
		var tw := _hangar_action.create_tween()
		for k in 3:
			tw.tween_property(_hangar_action, "position:x", _hangar_action.position.x + 8.0, 0.04)
			tw.tween_property(_hangar_action, "position:x", _hangar_action.position.x - 8.0, 0.04)
		tw.tween_property(_hangar_action, "position:x", _hangar_action.position.x, 0.04)
		return
	_refresh_hangar()
	if _main_cores != null:
		_main_cores.set_amount(meta.cores, false)

# --- Atölye -----------------------------------------------------------------------
func _build_workshop() -> void:
	var root := _screen("workshop", 0.86)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_center(root).add_child(box)
	box.add_child(KIT.heading(tr("ATÖLYE"), 42, KIT.GOLD))
	box.add_child(KIT.label(tr("çekirdeklerle kalıcı yükseltmeler al — her koşuda geçerli"), 16, KIT.DIM, null, HORIZONTAL_ALIGNMENT_CENTER))
	_shop_cores = CoreBadge.new(26)
	_shop_cores.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_shop_cores)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	for def in GameData.upgrades:
		var tile := UpgradeTile.new()
		tile.def = def
		var id := str(def.get("id", ""))
		tile.pressed.connect(func(): _buy_upgrade(id, tile))
		if not Settings.touch:
			tile.mouse_entered.connect(func(): Sound.play("ui_hover"))
		grid.add_child(tile)
		_shop_tiles.append(tile)
	var back := KIT.button(tr("GERİ"), KIT.GOLD, Vector2(240, 56), 22, true)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_back)
	box.add_child(back)
	_focus["workshop"] = _shop_tiles[0] if not _shop_tiles.is_empty() else back

func _refresh_shop(animate := true) -> void:
	if _shop_cores != null:
		_shop_cores.set_amount(Settings.meta.cores, animate)
	if _main_cores != null:
		_main_cores.set_amount(Settings.meta.cores, false)
	for tile in _shop_tiles:
		(tile as Control).queue_redraw()

func _buy_upgrade(id: String, tile: UpgradeTile) -> void:
	if Settings.meta.buy(id):
		Settings.save()
		Sound.play("purchase")
		tile.bump(true)
	else:
		Sound.play("deny")
		tile.bump(false)
	_refresh_shop()

# --- Ayarlar ----------------------------------------------------------------------
func _row(parent: VBoxContainer, title: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	var l := KIT.label(title, 20, KIT.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(250, 0)
	row.add_child(l)
	control.size_flags_horizontal = Control.SIZE_SHRINK_END
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(control)
	parent.add_child(row)

func _add_toggle(parent: VBoxContainer, title: String, key: String, accent := KIT.CYAN) -> void:
	var b := KIT.toggle(bool(Settings.get(key)), accent)
	b.toggled.connect(func(on: bool):
		Settings.set_value(key, on)
		KIT.restyle_toggle(b, on, accent)
		Sound.play("ui_toggle"))
	KIT.restyle_toggle(b, bool(Settings.get(key)), accent)
	_setting_nodes[key] = b
	_row(parent, title, b)

func _build_settings() -> void:
	var root := _screen("settings", 0.78)
	var panel := KIT.panel(KIT.CYAN, 30.0)
	_center(root).add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(580, 0)
	panel.add_child(box)
	box.add_child(KIT.heading(tr("AYARLAR"), 38))
	box.add_child(KIT.spacer(4))
	var music := KIT.slider(Settings.music, KIT.CYAN)
	music.value_changed.connect(func(v: float): Settings.set_value("music", v))
	_setting_nodes["music"] = music
	_row(box, tr("MÜZİK"), music)
	var sfx := KIT.slider(Settings.sfx, KIT.MAGENTA)
	sfx.value_changed.connect(func(v: float):
		Settings.set_value("sfx", v)
		Sound.play("ui_toggle"))
	_setting_nodes["sfx"] = sfx
	_row(box, tr("EFEKTLER"), sfx)
	_add_toggle(box, tr("OTOMATİK ATEŞ"), "auto_fire")
	if Settings.touch:
		_add_toggle(box, tr("TİTREŞİM"), "vibration")
	_add_toggle(box, tr("EKRAN SARSINTISI"), "shake")
	_quality_button = KIT.button(tr(Settings.QUALITY_NAMES[Settings.quality]), KIT.GOLD, Vector2(170, 50), 20)
	_quality_button.pressed.connect(func():
		Settings.set_value("quality", (Settings.quality + 1) % 3)
		_quality_button.text = tr(Settings.QUALITY_NAMES[Settings.quality])
		quality_changed.emit())
	_row(box, tr("GRAFİK KALİTESİ"), _quality_button)
	_add_toggle(box, tr("FPS GÖSTER"), "show_fps")
	var lang := KIT.button(str(I18n.NAMES.get(Settings.language, "TÜRKÇE")), KIT.GREEN, Vector2(170, 50), 20)
	lang.pressed.connect(func(): I18n.set_language(I18n.next_language()))
	_row(box, tr("DİL / LANGUAGE"), lang)
	box.add_child(KIT.spacer(6))
	var back := KIT.button(tr("GERİ"), KIT.CYAN, Vector2(240, 58), 22, true)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_back)
	box.add_child(back)
	_focus["settings"] = back

func _refresh_settings() -> void:
	(_setting_nodes["music"] as HSlider).set_value_no_signal(Settings.music)
	(_setting_nodes["sfx"] as HSlider).set_value_no_signal(Settings.sfx)
	for key in ["auto_fire", "vibration", "shake", "show_fps"]:
		if _setting_nodes.has(key):
			var b: Button = _setting_nodes[key]
			b.set_pressed_no_signal(bool(Settings.get(key)))
			KIT.restyle_toggle(b, bool(Settings.get(key)))
	_quality_button.text = tr(Settings.QUALITY_NAMES[Settings.quality])

# --- Nasıl oynanır ----------------------------------------------------------------
func _build_howto() -> void:
	var root := _screen("howto", 0.8)
	var panel := KIT.panel(KIT.VIOLET, 30.0)
	_center(root).add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size = Vector2(760, 0)
	panel.add_child(box)
	box.add_child(KIT.heading(tr("NASIL OYNANIR"), 36, KIT.VIOLET))
	box.add_child(KIT.spacer(2))
	var controls: Array = []
	if Settings.touch:
		controls = [
			[tr("SOL ÇUBUK"), tr("hareket et")],
			[tr("SAĞ ÇUBUK"), tr("nişan al ve ateş et (boşken otomatik nişan)")],
			[tr("ATIL"), tr("kısa süre dokunulmaz ol, mermilerin içinden geç")],
			[tr("NOVA"), tr("dolunca: çevredeki düşmanları ve mermileri sil")],
		]
	else:
		controls = [
			[tr("WASD / OKLAR"), tr("hareket et")],
			[tr("FARE + SOL TIK"), tr("nişan al ve ateş et")],
			[tr("BOŞLUK / SHIFT"), tr("atıl: kısa süre dokunulmaz ol")],
			[tr("Q / SAĞ TIK"), tr("NOVA: çevredeki düşmanları ve mermileri sil")],
			["1 · 2 · 3", tr("kart seç      ESC duraklat      M sessiz")],
		]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 9)
	box.add_child(grid)
	for entry in controls:
		grid.add_child(KIT.label(entry[0], 18, KIT.CYAN, KIT.bold()))
		grid.add_child(KIT.label(entry[1], 18, KIT.TEXT))
	box.add_child(KIT.spacer(6))
	var tips := [
		tr("Düşman öldür, kombo büyüsün: puan ve XP katlanır."),
		tr("Seviye atlayınca 3 karttan birini seç; kartlar koşu boyunca kalıcıdır."),
		tr("Her 5. dalgada boss gelir. Yenersen yeni sektöre geçersin."),
		tr("Altın parlayan ELİT düşmanlar güçlüdür ama mutlaka ganimet bırakır."),
		tr("Uyumlu iki kartı birlikte alınca güçlü bir SİNERJİ kartı açılır."),
		tr("Yeşil can, sarı aşırı yük, mavi kalkan: yanından geçmen yeter."),
	]
	for tip in tips:
		var l := KIT.label("•  " + tip, 16, KIT.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(740, 0)
		box.add_child(l)
	box.add_child(KIT.spacer(6))
	var back := KIT.button(tr("ANLADIM"), KIT.VIOLET, Vector2(240, 58), 22, true)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_back)
	box.add_child(back)
	_focus["howto"] = back

# --- Duraklatma -------------------------------------------------------------------
func _build_pause() -> void:
	var root := _screen("pause", 0.72)
	var panel := KIT.panel(KIT.CYAN, 30.0)
	_center(root).add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.custom_minimum_size = Vector2(400, 0)
	panel.add_child(box)
	box.add_child(KIT.heading(tr("DURAKLATILDI"), 36))
	_pause_info = KIT.label("", 16, KIT.DIM, null, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_pause_info)
	_pause_build = BuildStrip.new()
	_pause_build.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_pause_build)
	box.add_child(KIT.spacer(4))
	var resume := KIT.button(tr("DEVAM ET"), KIT.CYAN, Vector2(360, 66), 26, true)
	resume.pressed.connect(func(): resume_pressed.emit())
	box.add_child(resume)
	_focus["pause"] = resume
	var restart := KIT.button(tr("YENİDEN BAŞLA"), KIT.VIOLET, Vector2(360, 56), 20)
	restart.pressed.connect(func(): restart_pressed.emit())
	box.add_child(restart)
	var settings := KIT.button(tr("AYARLAR"), KIT.VIOLET, Vector2(360, 56), 20)
	settings.pressed.connect(func(): open_sub("settings", "pause"))
	box.add_child(settings)
	var menu := KIT.button(tr("ANA MENÜ"), Color(0.6, 0.66, 0.78), Vector2(360, 56), 20)
	menu.pressed.connect(func(): menu_pressed.emit())
	box.add_child(menu)

func show_pause(wave: int, level: int, score: int, build: Array) -> void:
	_pause_args = [wave, level, score, build]
	_pause_info.text = tr("DALGA %d   ·   SEVİYE %d   ·   %s PUAN") % [wave, level, KIT.fmt(score)]
	_pause_build.set_items(build)
	if current != "settings":
		show_screen("pause")

# --- Kart seçimi ------------------------------------------------------------------
func _build_cards() -> void:
	var root := _screen("cards", 0.8)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_center(root).add_child(box)
	_card_title = KIT.heading(tr("SEVİYE ATLADIN"), 46, KIT.GOLD)
	box.add_child(_card_title)
	box.add_child(KIT.label(tr("bir yükseltme seç"), 18, KIT.DIM, null, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(KIT.spacer(10))
	_card_row = HBoxContainer.new()
	_card_row.add_theme_constant_override("separation", 30)
	_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_card_row)
	box.add_child(KIT.spacer(12))
	_reroll = KIT.button(tr("YENİLE"), KIT.GOLD, Vector2(250, 52), 19)
	_reroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reroll.pressed.connect(func(): reroll_pressed.emit())
	box.add_child(_reroll)

func show_cards(cards: Array, level: int, rerolls: int, counts: Dictionary) -> void:
	for child in _card_row.get_children():
		child.queue_free()
	_card_buttons.clear()
	_card_title.text = tr("SEVİYE %d") % level
	for i in cards.size():
		var card: Dictionary = cards[i]
		var b := CardButton.new()
		b.card = card
		b.owned = int(counts.get(str(card.get("id", "")), 0))
		b.key_hint = "" if Settings.touch else str(i + 1)
		var index := i
		b.pressed.connect(func(): card_picked.emit(index))
		if not Settings.touch:
			b.mouse_entered.connect(func(): Sound.play("ui_hover"))
		_card_row.add_child(b)
		_card_buttons.append(b)
		b.modulate.a = 0.0
		b.disabled = true
		var tw := b.create_tween()
		tw.tween_interval(0.07 * float(i))
		tw.tween_property(b, "modulate:a", 1.0, 0.22)
		tw.tween_interval(0.12)
		tw.tween_callback(func(): b.disabled = false)
	_reroll.text = tr("YENİLE  (%d)") % rerolls
	_reroll.disabled = rerolls <= 0
	_reroll.visible = true
	show_screen("cards")

# --- Oyun sonu --------------------------------------------------------------------
func _stat_cell(grid: GridContainer, key: String, title: String) -> void:
	var cell := VBoxContainer.new()
	cell.custom_minimum_size = Vector2(170, 0)
	cell.add_theme_constant_override("separation", 0)
	var value := KIT.label("0", 28, Color(1, 1, 1), KIT.bold(), HORIZONTAL_ALIGNMENT_CENTER)
	cell.add_child(value)
	cell.add_child(KIT.label(title, 13, KIT.DIM, null, HORIZONTAL_ALIGNMENT_CENTER))
	grid.add_child(cell)
	_over_stats[key] = value

func _build_gameover() -> void:
	var root := _screen("gameover", 0.74)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_center(root).add_child(box)
	_over_title = KIT.heading(tr("OYUN BİTTİ"), 62, KIT.RED)
	box.add_child(_over_title)
	_over_record = KIT.label("", 20, KIT.GOLD, KIT.bold(), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_over_record)
	_over_score = KIT.label("0", 68, Color(1, 1, 1), KIT.title(), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_over_score)
	box.add_child(KIT.label(tr("PUAN"), 14, KIT.DIM, null, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(KIT.spacer(8))
	var panel := KIT.panel(KIT.RED, 18.0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	panel.add_child(grid)
	_stat_cell(grid, "wave", tr("DALGA"))
	_stat_cell(grid, "level", tr("SEVİYE"))
	_stat_cell(grid, "kills", tr("AVLANAN"))
	_stat_cell(grid, "combo", tr("EN İYİ KOMBO"))
	_stat_cell(grid, "time", tr("SÜRE"))
	var reward_row := HBoxContainer.new()
	reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_row.add_theme_constant_override("separation", 18)
	_over_cores = CoreBadge.new(26)
	_over_cores.prefix = "+"
	reward_row.add_child(_over_cores)
	_over_total = KIT.label("", 16, KIT.DIM)
	_over_total.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reward_row.add_child(_over_total)
	box.add_child(KIT.spacer(2))
	box.add_child(reward_row)
	_over_build = BuildStrip.new()
	_over_build.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_over_build)
	box.add_child(KIT.spacer(10))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	box.add_child(row)
	var again := KIT.button(tr("TEKRAR OYNA"), KIT.CYAN, Vector2(320, 70), 26, true)
	again.pressed.connect(func(): restart_pressed.emit())
	row.add_child(again)
	_focus["gameover"] = again
	var menu := KIT.button(tr("ANA MENÜ"), Color(0.6, 0.66, 0.78), Vector2(240, 70), 22)
	menu.pressed.connect(func(): menu_pressed.emit())
	row.add_child(menu)

func show_gameover(stats: Dictionary, build: Array) -> void:
	var record := bool(stats.get("record", false))
	_over_record.text = tr("YENİ REKOR!") if record else tr("REKOR  %s") % KIT.fmt(int(stats.get("best", 0)))
	_over_record.add_theme_color_override("font_color", KIT.GOLD if record else KIT.DIM)
	_over_target = int(stats.get("score", 0))
	_over_shown = 0.0
	(_over_stats["wave"] as Label).text = str(int(stats.get("wave", 1)))
	(_over_stats["level"] as Label).text = str(int(stats.get("level", 1)))
	(_over_stats["kills"] as Label).text = KIT.fmt(int(stats.get("kills", 0)))
	(_over_stats["combo"] as Label).text = str(int(stats.get("combo", 0)))
	(_over_stats["time"] as Label).text = KIT.fmt_time(float(stats.get("time", 0.0)))
	_over_cores.set_amount(0, false)
	_over_cores.set_amount(int(stats.get("cores", 0)))
	_over_total.text = tr("ÇEKİRDEK KAZANDIN  ·  toplam %s") % KIT.fmt(int(stats.get("total_cores", 0)))
	_over_build.set_items(build)
	show_screen("gameover")

# --- Girdi ------------------------------------------------------------------------
func _go_back() -> void:
	match current:
		"settings", "howto", "workshop", "hangar":
			_back()
		"pause":
			resume_pressed.emit()
		"main":
			if OS.has_feature("mobile"):
				get_tree().quit()
		"gameover":
			menu_pressed.emit()
		"":
			if in_game:
				pause_requested.emit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_go_back()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if current == "cards":
			var idx := -1
			match key.physical_keycode:
				KEY_1, KEY_KP_1: idx = 0
				KEY_2, KEY_KP_2: idx = 1
				KEY_3, KEY_KP_3: idx = 2
			if idx >= 0 and idx < _card_buttons.size():
				Sound.play("ui_click")
				card_picked.emit(idx)
				get_viewport().set_input_as_handled()
		elif current == "hangar" and key.physical_keycode in [KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D]:
			_hangar_step(-1 if key.physical_keycode in [KEY_LEFT, KEY_A] else 1)
			get_viewport().set_input_as_handled()
		elif current == "gameover" and key.physical_keycode == KEY_R:
			restart_pressed.emit()
			get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()
	elif what == NOTIFICATION_APPLICATION_PAUSED or (what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile")):
		if in_game and current == "":
			pause_requested.emit()
