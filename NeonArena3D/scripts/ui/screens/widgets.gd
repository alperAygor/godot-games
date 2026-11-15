extends RefCounted
## Menü ekranlarının ortak çizim bileşenleri (menus.gd'den taşındı; davranış aynı).
## Kullanım: const W = preload("res://scripts/ui/screens/widgets.gd") -> W.CoreBadge.new(26)
##   TitleArt  ana menü başlığı     BuildStrip  kart şeridi (duraklatma / oyun sonu)   CardButton  kart seçimi kartı
##   CoreBadge çekirdek ikonu+miktar UpgradeTile atölye kutusu   StatBars  gemi özellikleri   ArrowButton  hangar oku

const KIT = preload("res://scripts/ui/ui_kit.gd")

class TitleArt extends Control:
	const LINE1 := "NEON"
	const LINE2 := "GRIDSTORM"
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
		draw_string_outline(f, Vector2(0, 84), LINE1, HORIZONTAL_ALIGNMENT_LEFT, -1, 96, 22, Color(cyan.r, cyan.g, cyan.b, 0.12 * flicker))
		draw_string_outline(f, Vector2(0, 84), LINE1, HORIZONTAL_ALIGNMENT_LEFT, -1, 96, 9, Color(cyan.r, cyan.g, cyan.b, 0.3 * flicker))
		draw_string(f, Vector2(0, 84), LINE1, HORIZONTAL_ALIGNMENT_LEFT, -1, 96, Color(0.86, 0.99, 1.0, 0.55 + 0.45 * flicker))
		# İkinci satır başlık genişliğine sığacak boyutta çizilir (ad değişirse yerleşim bozulmaz).
		var size2 := mini(96, int(96.0 * 532.0 / maxf(1.0, f.get_string_size(LINE2, HORIZONTAL_ALIGNMENT_LEFT, -1, 96).x)))
		var base2 := Vector2(-2, 98.0 + float(size2) * 0.86)
		draw_string_outline(f, base2, LINE2, HORIZONTAL_ALIGNMENT_LEFT, -1, size2, maxi(4, 22 * size2 / 96), Color(pink.r, pink.g, pink.b, 0.12))
		draw_string_outline(f, base2, LINE2, HORIZONTAL_ALIGNMENT_LEFT, -1, size2, maxi(2, 9 * size2 / 96), Color(pink.r, pink.g, pink.b, 0.32))
		draw_string(f, base2, LINE2, HORIZONTAL_ALIGNMENT_LEFT, -1, size2, Color(1.0, 0.9, 0.97))
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
